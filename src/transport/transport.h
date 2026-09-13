#pragma once

#include <string>

namespace netclient {

class Transport {
public:
    virtual ~Transport() = default;

    virtual std::string get(const std::string& url) = 0;
};

} // namespace netclient
