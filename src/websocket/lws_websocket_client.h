#pragma once

#include <atomic>
#include <deque>
#include <mutex>
#include <string>
#include <thread>

#include <libwebsockets.h>

#include "sample/websocket/i_websocket_client.h"

namespace sample::websocket {

// Implementacion concreta de IWebSocketClient sobre libwebsockets.
// Maneja su propio hilo de servicio y reintentos de conexion con backoff
// exponencial. No se expone en include/ a proposito: los consumidores solo
// deben conocer IWebSocketClient (ver websocket_client_factory.h).
class LwsWebSocketClient final : public IWebSocketClient {
public:
    LwsWebSocketClient();
    ~LwsWebSocketClient() override;

    LwsWebSocketClient(const LwsWebSocketClient&) = delete;
    LwsWebSocketClient& operator=(const LwsWebSocketClient&) = delete;

    void connect(const std::string& url) override;
    void disconnect() override;
    bool send(const std::string& message) override;

    void setOnMessage(MessageCallback callback) override;
    void setOnStateChange(StateCallback callback) override;
    void setOnError(ErrorCallback callback) override;

    void setReconnectPolicy(const ReconnectPolicy& policy) override;
    ConnectionState state() const override;

private:
    struct PerSessionData {
        char send_buffer[LWS_PRE + 4096];
    };

    struct ParsedUrl {
        bool use_ssl = false;
        std::string host;
        int port = 80;
        std::string path = "/";
    };

    static ParsedUrl parseUrl(const std::string& url);
    static int lwsCallbackTrampoline(struct lws* wsi, enum lws_callback_reasons reason,
                                      void* user, void* in, size_t len);

    void runLoop();
    void setState(ConnectionState newState);
    void notifyError(const std::string& message);
    bool scheduleReconnectOrFail();
    uint32_t nextBackoffMs();
    ReconnectPolicy currentPolicy();

    ParsedUrl parsed_;
    std::atomic<struct lws_context*> context_{nullptr};
    std::atomic<struct lws*> wsi_{nullptr};
    struct lws_protocols protocols_[2]{};

    std::thread worker_;
    std::atomic<bool> stopRequested_{false};
    std::atomic<bool> connectionLost_{false};
    std::atomic<ConnectionState> state_{ConnectionState::Disconnected};

    std::deque<std::string> sendQueue_;
    std::mutex sendMutex_;

    MessageCallback onMessage_;
    StateCallback onStateChange_;
    ErrorCallback onError_;
    std::mutex callbackMutex_;

    ReconnectPolicy policy_;
    std::mutex policyMutex_;
    int reconnectAttempts_ = 0;
};

} // namespace sample::websocket
