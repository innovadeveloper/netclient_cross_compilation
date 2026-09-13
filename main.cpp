#include <netclient/client.h>
#include <iostream>

int main()
{
    netclient::Client client;
    std::string response = client.get("http://example.com");

    std::cout << "Respuesta: " << response << std::endl;
    return 0;
}
