#pragma once

#include <cstdint>
#include <functional>
#include <string>

namespace sample::websocket {

enum class ConnectionState {
    Disconnected,
    Connecting,
    Connected,
    Reconnecting,
    Failed
};

struct ReconnectPolicy {
    uint32_t initial_delay_ms   = 500;
    uint32_t max_delay_ms       = 30000;
    double   backoff_multiplier = 2.0;
    int      max_attempts       = 10; // -1 = reintentos infinitos; al agotarse pasa a Failed
};

// Contrato del cliente WebSocket. Cualquier implementación (libwebsockets,
// otra libreria, mock para tests) debe cumplir esta interfaz.
class IWebSocketClient {
public:
    using MessageCallback = std::function<void(const std::string& message)>;
    using StateCallback   = std::function<void(ConnectionState state)>;
    using ErrorCallback   = std::function<void(const std::string& error)>;

    virtual ~IWebSocketClient() = default;

    virtual void connect(const std::string& url) = 0;
    virtual void disconnect() = 0;
    virtual bool send(const std::string& message) = 0;

    virtual void setOnMessage(MessageCallback callback) = 0;
    virtual void setOnStateChange(StateCallback callback) = 0;
    virtual void setOnError(ErrorCallback callback) = 0;

    virtual void setReconnectPolicy(const ReconnectPolicy& policy) = 0;
    virtual ConnectionState state() const = 0;
};

} // namespace sample::websocket


// Funciona de punta a punta contra tu servidor real: conecta, dispara onMessage con cada trama recibida, envía los dos mensajes de prueba, y se desconecta limpio al llamar disconnect().

// Resumen de lo que quedó armado:

// - include/sample/websocket/i_websocket_client.h — el contrato (IWebSocketClient): connect/disconnect/send, setOnMessage/setOnStateChange/setOnError, setReconnectPolicy, state().
// - include/sample/websocket/websocket_client_factory.h — punto de entrada público: createLwsWebSocketClient() devuelve un unique_ptr<IWebSocketClient>, sin exponer libwebsockets a quien lo consume.
// - src/websocket/lws_websocket_client.{h,cpp} — implementación concreta: hilo propio corriendo lws_service, reconexión con backoff exponencial (500ms → tope 30s) y máximo de 10 intentos por defecto (configurable, y al agotarse pasa a Failed y para hasta que llames connect() de nuevo), parser simple de ws:///wss://.
// - main.cpp — ya no tiene el prototipo con globals; usa el contrato tal como lo verías inyectado en cualquier otra parte del código.
// - CMakeLists.txt — quedó arreglado el link real contra el libwebsockets/4.5.8 de Conan (antes la lib de sample no lo enlazaba en absoluto).

// Dos límites que no cubrí, para que los tengas en el radar:
// 1. El envío (send) descarta mensajes de más de ~4080 bytes con un onError, en vez de fragmentarlos en varios lws_write.
// 2. La recepción no reensambla explícitamente frames fragmentados (lws_is_final_fragment) — en la prueba llegó un mensaje de ~2000 bytes completo en una sola llamada, pero para payloads muy grandes o con MTU chico podría llegar partido.

// Si te sirve, en otra pasada agrego fragmentación de envío/recepción; por ahora el contrato y el mecanismo de reconexión ya están listos para que empieces a usarlos.