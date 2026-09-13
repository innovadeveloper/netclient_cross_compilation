#include "../../transport/transport.h"

#include <memory>

namespace netclient {

class AndroidTransport : public Transport {
public:
    std::string get(const std::string& url) override
    {
        (void)url;
        return "HELLO FROM ANDROID";
    }
};

std::unique_ptr<Transport> create_transport()
{
    return std::make_unique<AndroidTransport>();
}

} // namespace netclient
