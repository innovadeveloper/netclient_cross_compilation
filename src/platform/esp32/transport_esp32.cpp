#include "../../transport/transport.h"

#include <memory>

namespace netclient {

class Esp32Transport : public Transport {
public:
    std::string get(const std::string& url) override
    {
        (void)url;
        return "HELLO FROM ESP32";
    }
};

std::unique_ptr<Transport> create_transport()
{
    return std::make_unique<Esp32Transport>();
}

} // namespace netclient
