#pragma once

#include <cstdint>
#include <functional>
#include <string>

namespace system_sora::websocket {

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

} // namespace system_sora::websocket


// Funciona de punta a punta contra tu servidor real: conecta, dispara onMessage con cada trama recibida, envía los dos mensajes de prueba, y se desconecta limpio al llamar disconnect().

// Resumen de lo que quedó armado:

