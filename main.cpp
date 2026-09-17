#include <curl/curl.h>
#include <iostream>
#include <memory>
#include <string>
#include <stdexcept>
#include "MQTTClient.h"

#include <thread>
#include <chrono>

#include "system_sora/websocket/websocket_client_factory.h"

// CAs de Let's Encrypt embebidas en el binario (ISRG Root X1 + X2).
// Generado con: curl https://letsencrypt.org/certs/isrgrootx1.pem
//                     https://letsencrypt.org/certs/isrg-root-x2.pem

// # 1. Descargar los dos certificados raíz de Let's Encrypt
// curl -s https://letsencrypt.org/certs/isrgrootx1.pem > le_ca.pem
// curl -s https://letsencrypt.org/certs/isrg-root-x2.pem >> le_ca.pem

static const char kLetsEncryptCA[] = R"(
-----BEGIN CERTIFICATE-----
MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw
TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh
cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4
WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu
ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY
MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc
h77ct984kIxuPOZXoHj3dcKi/vVqbvYATyjb3miGbESTtrFj/RQSa78f0uoxmyF+
0TM8ukj13Xnfs7j/EvEhmkvBioZxaUpmZmyPfjxwv60pIgbz5MDmgK7iS4+3mX6U
A5/TR5d8mUgjU+g4rk8Kb4Mu0UlXjIB0ttov0DiNewNwIRt18jA8+o+u3dpjq+sW
T8KOEUt+zwvo/7V3LvSye0rgTBIlDHCNAymg4VMk7BPZ7hm/ELNKjD+Jo2FR3qyH
B5T0Y3HsLuJvW5iB4YlcNHlsdu87kGJ55tukmi8mxdAQ4Q7e2RCOFvu396j3x+UC
B5iPNgiV5+I3lg02dZ77DnKxHZu8A/lJBdiB3QW0KtZB6awBdpUKD9jf1b0SHzUv
KBds0pjBqAlkd25HN7rOrFleaJ1/ctaJxQZBKT5ZPt0m9STJEadao0xAH0ahmbWn
OlFuhjuefXKnEgV4We0+UXgVCwOPjdAvBbI+e0ocS3MFEvzG6uBQE3xDk3SzynTn
jh8BCNAw1FtxNrQHusEwMFxIt4I7mKZ9YIqioymCzLq9gwQbooMDQaHWBfEbwrbw
qHyGO0aoSCqI3Haadr8faqU9GY/rOPNk3sgrDQoo//fb4hVC1CLQJ13hef4Y53CI
rU7m2Ys6xt0nUW7/vGT1M0NPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBR5tFnme7bl5AFzgAiIyBpY9umbbjANBgkq
hkiG9w0BAQsFAAOCAgEAVR9YqbyyqFDQDLHYGmkgJykIrGF1XIpu+ILlaS/V9lZL
ubhzEFnTIZd+50xx+7LSYK05qAvqFyFWhfFQDlnrzuBZ6brJFe+GnY+EgPbk6ZGQ
3BebYhtF8GaV0nxvwuo77x/Py9auJ/GpsMiu/X1+mvoiBOv/2X/qkSsisRcOj/KK
NFtY2PwByVS5uCbMiogziUwthDyC3+6WVwW6LLv3xLfHTjuCvjHIInNzktHCgKQ5
ORAzI4JMPJ+GslWYHb4phowim57iaztXOoJwTdwJx4nLCgdNbOhdjsnvzqvHu7Ur
TkXWStAmzOVyyghqpZXjFaH3pO3JLF+l+/+sKAIuvtd7u+Nxe5AW0wdeRlN8NwdC
jNPElpzVmbUq4JUagEiuTDkHzsxHpFKVK7q4+63SM1N95R1NbdWhscdCb+ZAJzVc
oyi3B43njTOQ5yOf+1CceWxG1bQVs5ZufpsMljq4Ui0/1lvh+wjChP4kqKOJ2qxq
4RgqsahDYVvTH9w7jXbyLeiNdd8XM2w9U/t7y0Ff/9yi0GE44Za4rF2LN9d11TPA
mRGunUHBcnWEvgJBQl9nJEiU0Zsnvgc/ubhPgXRR4Xq37Z0j4r7g1SgEEzwxA57d
emyPxgcYxn/eR44/KJ4EBs+lVDR3veyJm+kXQ99b21/+jh5Xos1AnX5iItreGCc=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIICGzCCAaGgAwIBAgIQQdKd0XLq7qeAwSxs6S+HUjAKBggqhkjOPQQDAzBPMQsw
CQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJuZXQgU2VjdXJpdHkgUmVzZWFyY2gg
R3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBYMjAeFw0yMDA5MDQwMDAwMDBaFw00
MDA5MTcxNjAwMDBaME8xCzAJBgNVBAYTAlVTMSkwJwYDVQQKEyBJbnRlcm5ldCBT
ZWN1cml0eSBSZXNlYXJjaCBHcm91cDEVMBMGA1UEAxMMSVNSRyBSb290IFgyMHYw
EAYHKoZIzj0CAQYFK4EEACIDYgAEzZvVn4CDCuwJSvMWSj5cz3es3mcFDR0HttwW
+1qLFNvicWDEukWVEYmO6gbf9yoWHKS5xcUy4APgHoIYOIvXRdgKam7mAHf7AlF9
ItgKbppbd9/w+kHsOdx1ymgHDB/qo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0T
AQH/BAUwAwEB/zAdBgNVHQ4EFgQUfEKWrt5LSDv6kviejM9ti6lyN5UwCgYIKoZI
zj0EAwMDaAAwZQIwe3lORlCEwkSHRhtFcP9Ymd70/aTSVaYgLXTWNLxBo1BfASdW
tL4ndQavEi51mI38AjEAi/V3bNTIZargCyzuFJ0nN6T5U6VR5CmD1/iQMVtCnwr1
/q4AaOeMSQ+2b1tbFfLn
-----END CERTIFICATE-----
)";


size_t escribirRespuesta(void* datosRecibidos, size_t tamano, size_t nmemb, std::string* salida) {
    size_t bytesTotales = tamano * nmemb;
    salida->append(static_cast<char*>(datosRecibidos), bytesTotales);
    return bytesTotales;
}

class ClienteHttp {
public:
    ClienteHttp() : curl_(curl_easy_init(), curl_easy_cleanup) {
        if (!curl_) throw std::runtime_error("No se pudo inicializar libcurl");
    }

    std::string get(const std::string& url) {
        std::string respuesta;

        curl_blob caBlob{};
        caBlob.data  = const_cast<char*>(kLetsEncryptCA);
        caBlob.len   = sizeof(kLetsEncryptCA) - 1;
        caBlob.flags = CURL_BLOB_NOCOPY;

        curl_easy_setopt(curl_.get(), CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl_.get(), CURLOPT_WRITEFUNCTION, escribirRespuesta);
        curl_easy_setopt(curl_.get(), CURLOPT_WRITEDATA, &respuesta);
        curl_easy_setopt(curl_.get(), CURLOPT_USERAGENT, "roadmap-cpp/1.0");
        curl_easy_setopt(curl_.get(), CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl_.get(), CURLOPT_TIMEOUT, 10L);
        curl_easy_setopt(curl_.get(), CURLOPT_CAINFO_BLOB, &caBlob);

        CURLcode resultado = curl_easy_perform(curl_.get());
        if (resultado != CURLE_OK) {
            throw std::runtime_error(std::string("Error en la peticion: ") +
                                      curl_easy_strerror(resultado));
        }

        long codigoHttp = 0;
        curl_easy_getinfo(curl_.get(), CURLINFO_RESPONSE_CODE, &codigoHttp);
        std::cout << "  [HTTP " << codigoHttp << "] " << url << "\n";

        return respuesta;
    }

private:
    std::unique_ptr<CURL, decltype(&curl_easy_cleanup)> curl_;
};



int main() {
    curl_global_init(CURL_GLOBAL_DEFAULT);

    // try {
    //     ClienteHttp cliente;
    //     std::string respuesta = cliente.get("https://minio.abexacloud.com/login");
    //     std::cout << "Cuerpo de la respuesta:\n" << respuesta << "\n";
    // } catch (const std::exception& e) {
    //     std::cerr << "Error: " << e.what() << "\n";
    // }

    using system_sora::websocket::ConnectionState;

    auto ws = system_sora::websocket::createLwsWebSocketClient();

    ws->setOnMessage([](const std::string& msg) {
        std::cout << "[WS] Mensaje recibido: " << msg << std::endl;
    });

    ws->setOnStateChange([](ConnectionState state) {
        switch (state) {
            case ConnectionState::Connecting:   std::cout << "[WS] Conectando...\n"; break;
            case ConnectionState::Connected:    std::cout << "[WS] Conectado.\n"; break;
            case ConnectionState::Reconnecting: std::cout << "[WS] Reconectando...\n"; break;
            case ConnectionState::Disconnected: std::cout << "[WS] Desconectado.\n"; break;
            case ConnectionState::Failed:        std::cout << "[WS] Conexion fallida (se agotaron los reintentos).\n"; break;
        }
    });

    ws->setOnError([](const std::string& error) {
        std::cerr << "[WS][ERROR] " << error << std::endl;
    });

    ws->connect("ws://ws.unidades-v2.abexacloud.com/?deviceModel=SM-A127M");

    // Espera un poco a que conecte
    std::this_thread::sleep_for(std::chrono::seconds(2));

    // Envía lo que quieras, cuando quieras
    ws->send("2|1~-11.935210|-77.054820|1000|0|usuario@beex");
    std::this_thread::sleep_for(std::chrono::seconds(1));
    ws->send("2|1~-11.935210|-77.054820|1000|0|usuario@sampleeee");

    // ... deja correr o termina cuando quieras
    std::this_thread::sleep_for(std::chrono::seconds(5));

    ws->disconnect();

    curl_global_cleanup();
    return 0;
}


// ---

