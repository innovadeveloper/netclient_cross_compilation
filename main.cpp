#include <curl/curl.h>
#include <iostream>
#include <memory>
#include <string>
#include <stdexcept>
#include "MQTTClient.h"


#include <libwebsockets.h>
#include <iostream>
#include <string>
#include <cstring>
#include <csignal>

#include <deque>
#include <mutex>
#include <string>
#include <thread>
#include <chrono>

static std::deque<std::string> g_send_queue;
static std::mutex g_send_mutex;

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



// Variable global para controlar el bucle de eventos
static volatile int force_exit = 0;
static struct lws *client_wsi = nullptr;

// Estructura para almacenar el mensaje a enviar
struct per_session_data {
    char send_buffer[LWS_PRE + 512];
    size_t send_len = 0;
};

void sendMessage(const std::string& msg) {
    std::lock_guard<std::mutex> lock(g_send_mutex);
    g_send_queue.push_back(msg);
    // Despertar el bucle para que procese el envío
    if (client_wsi) {
        lws_callback_on_writable(client_wsi);
    }
}

// Callback: Aquí se manejan todos los eventos del WebSocket
static int callback_ws(struct lws *wsi, enum lws_callback_reasons reason,
                       void *user, void *in, size_t len) {
    struct per_session_data *pss = (struct per_session_data *)user;

    switch (reason) {
        case LWS_CALLBACK_CLIENT_ESTABLISHED:
            std::cout << "[CLIENT] Conectado al servidor WebSocket." << std::endl;
            // Ya no enviamos hardcodeado. Opcionalmente encolamos un "hello".
            // sendMessage(R"({"type":"hello","device":"SM-A127M"})");
            break;

        case LWS_CALLBACK_CLIENT_WRITEABLE:
        {
            std::string msg;
            {
                std::lock_guard<std::mutex> lock(g_send_mutex);
                if (g_send_queue.empty()) break;
                msg = g_send_queue.front();
                g_send_queue.pop_front();
            }

            if (msg.size() > 512) {
                std::cerr << "[ERROR] Mensaje demasiado grande\n";
                break;
            }

            std::memcpy(pss->send_buffer + LWS_PRE, msg.data(), msg.size());
            pss->send_len = msg.size();

            int bytes_sent = lws_write(wsi,
                                    (unsigned char*)pss->send_buffer + LWS_PRE,
                                    pss->send_len,
                                    LWS_WRITE_TEXT);
            if (bytes_sent < (int)pss->send_len) {
                std::cerr << "[ERROR] Fallo al enviar\n";
                return -1;
            }
            std::cout << "[CLIENT] Enviado: " << msg << "\n";
            pss->send_len = 0;

            // Si quedan mensajes, pedir otra vuelta de escritura
            {
                std::lock_guard<std::mutex> lock(g_send_mutex);
                if (!g_send_queue.empty()) {
                    lws_callback_on_writable(wsi);
                }
            }
            break;
        }

        // 3. Hemos recibido datos del servidor
        case LWS_CALLBACK_CLIENT_RECEIVE:
            std::cout << "[CLIENT] Mensaje recibido: " 
                      << std::string((const char *)in, len) << std::endl;
            break;

        // 4. La conexión se ha cerrado
        case LWS_CALLBACK_CLIENT_CLOSED:
            std::cout << "[CLIENT] Conexión cerrada." << std::endl;
            client_wsi = nullptr;
            force_exit = 1;
            break;

        // 5. Error de conexión
        case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
            std::cerr << "[ERROR] Error de conexión: " 
                      << (in ? (const char *)in : "Desconocido") << std::endl;
            client_wsi = nullptr;
            force_exit = 1;
            break;

        default:
            break;
    }
    return 0;
}

// Lista de protocolos soportados
static const struct lws_protocols protocols[] = {
    {
        "my-protocol",       // Nombre del protocolo
        callback_ws,         // Función de callback
        sizeof(struct per_session_data),
        0,
    },
    { NULL, NULL, 0, 0 }     // Terminador de la lista
};

void connectToWebsocket() {
    // 1. Configuración del contexto
    struct lws_context_creation_info info;
    std::memset(&info, 0, sizeof(info));
    info.port = CONTEXT_PORT_NO_LISTEN; // No queremos escuchar, solo conectar
    info.protocols = protocols;
    info.gid = -1;
    info.uid = -1;

    // Creamos el contexto de libwebsockets
    struct lws_context *context = lws_create_context(&info);
    if (!context) {
        std::cerr << "[ERROR] Fallo al crear el contexto de libwebsockets." << std::endl;
        return;
    }

    // ws://ws.unidades-v2.abexacloud.com?deviceModel=SM-A127M
    // 2. Configuración de la conexión al servidor
    struct lws_client_connect_info ccinfo;
    std::memset(&ccinfo, 0, sizeof(ccinfo));
    ccinfo.context = context;
    ccinfo.address = "ws.unidades-v2.abexacloud.com"; // URL de ejemplo (público)
    ccinfo.port = 80;                     // Puerto para wss
    ccinfo.path = "/?deviceModel=SM-A127M";                     // Ruta
    ccinfo.host = ccinfo.address;          // Host
    ccinfo.origin = ccinfo.address;        // Origin
    ccinfo.protocol = protocols[0].name;   // Protocolo
    // ccinfo.ssl_connection = LCCSCF_USE_SSL; // Habilitamos SSL/TLS para wss://

    // Iniciamos la conexión
    client_wsi = lws_client_connect_via_info(&ccinfo);
    if (!client_wsi) {
        std::cerr << "[ERROR] Fallo al iniciar la conexión." << std::endl;
        lws_context_destroy(context);
        return;
    }

    // 3. Bucle de eventos principal
    while (!force_exit && client_wsi) {
        // lws_service procesa los eventos de la red (no bloqueante)
        lws_service(context, 0);
    }

    // 4. Limpieza
    lws_context_destroy(context);
    std::cout << "[CLIENT] Programa finalizado." << std::endl;
    // return 0;
}


int main() {
    curl_global_init(CURL_GLOBAL_DEFAULT);

    try {
        ClienteHttp cliente;
        std::string respuesta = cliente.get("https://minio.abexacloud.com/login");
        std::cout << "Cuerpo de la respuesta:\n" << respuesta << "\n";
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
    }

    // Lanza el WebSocket en un hilo aparte
    std::thread ws_thread(connectToWebsocket);
    ws_thread.detach();

    // Espera un poco a que conecte
    std::this_thread::sleep_for(std::chrono::seconds(2));

    // Envía lo que quieras, cuando quieras
    sendMessage("2|1~-11.935210|-77.054820|1000|0|usuario@beex");
    std::this_thread::sleep_for(std::chrono::seconds(1));
    sendMessage("2|1~-11.935210|-77.054820|1000|0|usuario@sampleeee");

    // ... deja correr o termina cuando quieras
    std::this_thread::sleep_for(std::chrono::seconds(5));

    curl_global_cleanup();
    return 0;
}


// ---

