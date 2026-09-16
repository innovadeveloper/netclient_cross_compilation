#include "lws_websocket_client.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstring>
#include <stdexcept>

#include "sample/websocket/websocket_client_factory.h"

namespace sample::websocket {

std::unique_ptr<IWebSocketClient> createLwsWebSocketClient() {
    return std::make_unique<LwsWebSocketClient>();
}

LwsWebSocketClient::LwsWebSocketClient() = default;

LwsWebSocketClient::~LwsWebSocketClient() {
    disconnect();
}

LwsWebSocketClient::ParsedUrl LwsWebSocketClient::parseUrl(const std::string& url) {
    ParsedUrl result;
    std::string rest;

    if (url.rfind("wss://", 0) == 0) {
        result.use_ssl = true;
        result.port = 443;
        rest = url.substr(6);
    } else if (url.rfind("ws://", 0) == 0) {
        result.use_ssl = false;
        result.port = 80;
        rest = url.substr(5);
    } else {
        throw std::invalid_argument("URL de WebSocket invalida (usa ws:// o wss://): " + url);
    }

    auto slashPos = rest.find('/');
    std::string hostPort = (slashPos == std::string::npos) ? rest : rest.substr(0, slashPos);
    result.path = (slashPos == std::string::npos) ? "/" : rest.substr(slashPos);

    auto colonPos = hostPort.find(':');
    if (colonPos == std::string::npos) {
        result.host = hostPort;
    } else {
        result.host = hostPort.substr(0, colonPos);
        result.port = std::stoi(hostPort.substr(colonPos + 1));
    }

    if (result.host.empty()) {
        throw std::invalid_argument("URL de WebSocket sin host: " + url);
    }

    return result;
}

void LwsWebSocketClient::connect(const std::string& url) {
    disconnect(); // asegura que cualquier hilo/contexto previo haya terminado

    parsed_ = parseUrl(url);
    stopRequested_ = false;
    connectionLost_ = false;
    reconnectAttempts_ = 0;

    setState(ConnectionState::Connecting);
    worker_ = std::thread(&LwsWebSocketClient::runLoop, this);
}

void LwsWebSocketClient::disconnect() {
    stopRequested_ = true;

    if (auto* ctx = context_.load()) {
        lws_cancel_service(ctx);
    }

    if (worker_.joinable() && std::this_thread::get_id() != worker_.get_id()) {
        worker_.join();
    }
}

bool LwsWebSocketClient::send(const std::string& message) {
    if (state_.load() != ConnectionState::Connected) {
        return false;
    }
    {
        std::lock_guard<std::mutex> lock(sendMutex_);
        sendQueue_.push_back(message);
    }
    if (auto* wsi = wsi_.load()) {
        lws_callback_on_writable(wsi);
    }
    return true;
}

void LwsWebSocketClient::setOnMessage(MessageCallback callback) {
    std::lock_guard<std::mutex> lock(callbackMutex_);
    onMessage_ = std::move(callback);
}

void LwsWebSocketClient::setOnStateChange(StateCallback callback) {
    std::lock_guard<std::mutex> lock(callbackMutex_);
    onStateChange_ = std::move(callback);
}

void LwsWebSocketClient::setOnError(ErrorCallback callback) {
    std::lock_guard<std::mutex> lock(callbackMutex_);
    onError_ = std::move(callback);
}

void LwsWebSocketClient::setReconnectPolicy(const ReconnectPolicy& policy) {
    std::lock_guard<std::mutex> lock(policyMutex_);
    policy_ = policy;
}

ReconnectPolicy LwsWebSocketClient::currentPolicy() {
    std::lock_guard<std::mutex> lock(policyMutex_);
    return policy_;
}

ConnectionState LwsWebSocketClient::state() const {
    return state_.load();
}

void LwsWebSocketClient::setState(ConnectionState newState) {
    state_ = newState;
    StateCallback cb;
    {
        std::lock_guard<std::mutex> lock(callbackMutex_);
        cb = onStateChange_;
    }
    if (cb) cb(newState);
}

void LwsWebSocketClient::notifyError(const std::string& message) {
    ErrorCallback cb;
    {
        std::lock_guard<std::mutex> lock(callbackMutex_);
        cb = onError_;
    }
    if (cb) cb(message);
}

uint32_t LwsWebSocketClient::nextBackoffMs() {
    ReconnectPolicy policy = currentPolicy();
    double delay = policy.initial_delay_ms *
                   std::pow(policy.backoff_multiplier, reconnectAttempts_ - 1);
    delay = std::min<double>(delay, static_cast<double>(policy.max_delay_ms));
    return static_cast<uint32_t>(delay);
}

bool LwsWebSocketClient::scheduleReconnectOrFail() {
    ReconnectPolicy policy = currentPolicy();
    ++reconnectAttempts_;

    if (policy.max_attempts >= 0 && reconnectAttempts_ > policy.max_attempts) {
        setState(ConnectionState::Failed);
        notifyError("Se agotaron los intentos de reconexion (" +
                    std::to_string(policy.max_attempts) + ")");
        return false;
    }

    setState(ConnectionState::Reconnecting);
    uint32_t delay = nextBackoffMs();
    const uint32_t step = 100;
    for (uint32_t waited = 0; waited < delay && !stopRequested_; waited += step) {
        std::this_thread::sleep_for(std::chrono::milliseconds(std::min(step, delay - waited)));
    }
    return !stopRequested_;
}

int LwsWebSocketClient::lwsCallbackTrampoline(struct lws* wsi, enum lws_callback_reasons reason,
                                               void* user, void* in, size_t len) {
    auto* ctx = wsi ? lws_get_context(wsi) : nullptr;
    auto* self = ctx ? static_cast<LwsWebSocketClient*>(lws_context_user(ctx)) : nullptr;
    if (!self) return 0;

    auto* pss = static_cast<PerSessionData*>(user);

    switch (reason) {
        case LWS_CALLBACK_CLIENT_ESTABLISHED:
            self->reconnectAttempts_ = 0;
            self->setState(ConnectionState::Connected);
            break;

        case LWS_CALLBACK_CLIENT_WRITEABLE: {
            std::string msg;
            {
                std::lock_guard<std::mutex> lock(self->sendMutex_);
                if (self->sendQueue_.empty()) break;
                msg = self->sendQueue_.front();
            }

            const size_t capacity = sizeof(pss->send_buffer) - LWS_PRE;
            if (msg.size() > capacity) {
                self->notifyError("Mensaje demasiado grande, se descarta (" +
                                   std::to_string(msg.size()) + " bytes)");
                std::lock_guard<std::mutex> lock(self->sendMutex_);
                self->sendQueue_.pop_front();
                break;
            }

            std::memcpy(pss->send_buffer + LWS_PRE, msg.data(), msg.size());
            int sent = lws_write(wsi, reinterpret_cast<unsigned char*>(pss->send_buffer) + LWS_PRE,
                                  msg.size(), LWS_WRITE_TEXT);

            {
                std::lock_guard<std::mutex> lock(self->sendMutex_);
                if (!self->sendQueue_.empty()) self->sendQueue_.pop_front();
                if (!self->sendQueue_.empty()) lws_callback_on_writable(wsi);
            }

            if (sent < static_cast<int>(msg.size())) {
                self->notifyError("Fallo al escribir en el socket WebSocket");
                return -1;
            }
            break;
        }

        case LWS_CALLBACK_CLIENT_RECEIVE: {
            std::string message(static_cast<const char*>(in), len);
            MessageCallback cb;
            {
                std::lock_guard<std::mutex> lock(self->callbackMutex_);
                cb = self->onMessage_;
            }
            if (cb) cb(message);
            break;
        }

        case LWS_CALLBACK_CLIENT_CLOSED:
            self->connectionLost_ = true;
            break;

        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR: {
            std::string detail = in ? std::string(static_cast<const char*>(in), len) : "desconocido";
            self->notifyError("Error de conexion: " + detail);
            self->connectionLost_ = true;
            break;
        }

        default:
            break;
    }
    return 0;
}

void LwsWebSocketClient::runLoop() {
    protocols_[0] = {"sample-ws-protocol", &LwsWebSocketClient::lwsCallbackTrampoline,
                      sizeof(PerSessionData), 4096, 0, nullptr, 0};
    protocols_[1] = {nullptr, nullptr, 0, 0, 0, nullptr, 0};

    struct lws_context_creation_info info;
    std::memset(&info, 0, sizeof(info));
    info.port = CONTEXT_PORT_NO_LISTEN;
    info.protocols = protocols_;
    info.gid = -1;
    info.uid = -1;
    info.user = this;
    if (parsed_.use_ssl) {
        info.options |= LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT;
    }

    struct lws_context* ctx = lws_create_context(&info);
    if (!ctx) {
        setState(ConnectionState::Failed);
        notifyError("No se pudo crear el contexto de libwebsockets");
        return;
    }
    context_ = ctx;

    while (!stopRequested_) {
        setState(ConnectionState::Connecting);
        connectionLost_ = false;

        struct lws_client_connect_info ccinfo;
        std::memset(&ccinfo, 0, sizeof(ccinfo));
        ccinfo.context = ctx;
        ccinfo.address = parsed_.host.c_str();
        ccinfo.port = parsed_.port;
        ccinfo.path = parsed_.path.c_str();
        ccinfo.host = ccinfo.address;
        ccinfo.origin = ccinfo.address;
        ccinfo.protocol = protocols_[0].name;
        ccinfo.ssl_connection = parsed_.use_ssl ? LCCSCF_USE_SSL : 0;

        struct lws* wsi = lws_client_connect_via_info(&ccinfo);
        wsi_ = wsi;

        if (!wsi) {
            notifyError("No se pudo iniciar la conexion WebSocket");
            if (!scheduleReconnectOrFail()) break;
            continue;
        }

        while (!stopRequested_ && wsi_.load() && !connectionLost_) {
            lws_service(ctx, 0);
        }

        wsi_ = nullptr;
        {
            std::lock_guard<std::mutex> lock(sendMutex_);
            sendQueue_.clear();
        }

        if (stopRequested_) break;

        if (!scheduleReconnectOrFail()) break;
    }

    lws_context_destroy(ctx);
    context_ = nullptr;

    if (state_.load() != ConnectionState::Failed) {
        setState(ConnectionState::Disconnected);
    }
}

} // namespace sample::websocket
