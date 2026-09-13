#include <netclient/client.h>

#include "transport/transport.h"

#include <memory>

namespace netclient {

std::unique_ptr<Transport> create_transport();

Client::Client() = default;

std::string Client::get(const std::string& url)
{
    auto transport = create_transport();
    return transport->get(url);
}

} // namespace netclient
