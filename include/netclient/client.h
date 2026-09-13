#pragma once

#include <string>

namespace netclient {

class Client {
public:
    Client();

    std::string get(const std::string& url);
};

} // namespace netclient
