#pragma once

#include <memory>

#include "i_websocket_client.h"

namespace sample::websocket {

// Crea la implementación concreta basada en libwebsockets.
// El consumidor solo conoce IWebSocketClient (el contrato).
std::unique_ptr<IWebSocketClient> createLwsWebSocketClient();

} // namespace sample::websocket
