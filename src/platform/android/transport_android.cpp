#include "../../transport/transport.h"

#include <openssl/evp.h>
#include <openssl/opensslv.h>

#include <memory>
#include <sstream>
#include <iomanip>

namespace netclient {

static std::string sha256_hex(const std::string& input)
{
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digest_len = 0;

    EVP_MD_CTX* ctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(ctx, EVP_sha256(), nullptr);
    EVP_DigestUpdate(ctx, input.data(), input.size());
    EVP_DigestFinal_ex(ctx, digest, &digest_len);
    EVP_MD_CTX_free(ctx);

    std::ostringstream oss;
    for (unsigned int i = 0; i < digest_len; ++i)
        oss << std::hex << std::setw(2) << std::setfill('0') << (int)digest[i];
    return oss.str();
}

class AndroidTransport : public Transport {
public:
    std::string get(const std::string& url) override
    {
        std::string hash = sha256_hex(url);
        std::ostringstream result;
        result << "[Android] OpenSSL " << OPENSSL_VERSION_TEXT
               << " | SHA-256(" << url << ") = " << hash;
        return result.str();
    }
};

std::unique_ptr<Transport> create_transport()
{
    return std::make_unique<AndroidTransport>();
}

} // namespace netclient
