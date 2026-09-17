#pragma once

#include <memory>

#include "i_websocket_client.h"

namespace system_sora::websocket {

// Crea la implementación concreta basada en libwebsockets.
// El consumidor solo conoce IWebSocketClient (el contrato).
std::unique_ptr<IWebSocketClient> createLwsWebSocketClient();

} // namespace system_sora::websocket
