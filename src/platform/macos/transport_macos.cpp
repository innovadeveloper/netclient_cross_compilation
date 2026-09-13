#include "../../transport/transport.h"

#include <memory>

namespace netclient {

class MacTransport : public Transport {
public:
    std::string get(const std::string& url) override
    {
        (void)url; // aún no usamos la URL, es solo prueba de arquitectura
        return "HELLO FROM MAC";
    }
};

std::unique_ptr<Transport> create_transport()
{
    return std::make_unique<MacTransport>();
}

} // namespace netclient
