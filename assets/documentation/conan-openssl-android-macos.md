# Guía: C++ cross-platform con Conan + CMake (Android & macOS)

OpenSSL como caso de uso. ESP32 excluido de este POC.


## Índice

1. [Crear conanfile.py y agregar una librería](#1-crear-conanfilepy-y-agregar-una-librería)
2. [Integrar OpenSSL en CMakeLists.txt](#2-integrar-openssl-en-cmakeliststxt)
3. [Compilar para macOS](#3-compilar-para-macos)
4. [Compilar para Android](#4-compilar-para-android)
5. [Ejecutar el binario en macOS](#5-ejecutar-el-binario-en-macos)
6. [Probar en Android via ADB](#6-probar-en-android-via-adb)
7. [Próximos pasos — JNI](#7-próximos-pasos--jni)
8. [Troubleshooting](#8-troubleshooting)

---

## 1. Crear conanfile.py y agregar una librería

```python
from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMakeDeps, cmake_layout

class NetClientConan(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeToolchain", "CMakeDeps"

    def requirements(self):
        self.requires("openssl/3.2.1")   # agregar aquí más libs según se necesite

    def layout(self):
        cmake_layout(self)
```

Para agregar otra librería (ej. `libcurl`) basta con añadir otra línea:

```python
self.requires("libcurl/8.6.0")
```

Conan resuelve las dependencias transitivas automáticamente.

---

### Perfil android_armv8

El perfil host para Android (`~/.conan2/profiles/android_armv8`) debe verse así:

```ini
[settings]
arch=armv8
build_type=Release
compiler=clang
compiler.cppstd=17
compiler.libcxx=c++_shared
compiler.version=17
os=Android
os.api_level=24

[conf]
tools.android:ndk_path=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125

[buildenv]
PATH+=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/bin
```

---

## 2. Integrar OpenSSL en CMakeLists.txt

```cmake
find_package(OpenSSL REQUIRED)

add_library(netclient SHARED src/client.cpp)

target_link_libraries(netclient PRIVATE OpenSSL::SSL OpenSSL::Crypto)

if(ANDROID)
    target_sources(netclient PRIVATE src/platform/android/transport_android.cpp)
elseif(APPLE)
    target_sources(netclient PRIVATE src/platform/macos/transport_macos.cpp)
else()
    message(FATAL_ERROR "Plataforma no soportada (solo Android / macOS)")
endif()
```

### Usar OpenSSL en el código (EVP API — no usar funciones deprecadas)

```cpp
#include <openssl/evp.h>
#include <openssl/opensslv.h>

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
```

> **Nota:** Usar siempre la EVP API (`EVP_DigestInit_ex`, etc.). Las funciones directas como `SHA256()` están deprecadas en OpenSSL 3.x.

---

## 3. Compilar para macOS

```bash
# Paso 1 — instalar dependencias con Conan
conan install . -pr:h=default -pr:b=default --build=missing -of=build/macos

# Paso 2 — configurar CMake con el toolchain generado por Conan
cmake -S . -B build \
  -DCMAKE_TOOLCHAIN_FILE=build/macos/build/Release/generators/conan_toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release

# Paso 3 — compilar
cmake --build build --config Release
```

---

## 4. Compilar para Android desde mac os ARM64

> **Importante:** para Android siempre usar el toolchain de Conan, **nunca** el NDK directamente. El toolchain de Conan configura el NDK internamente Y provee OpenSSL cross-compilado para arm64.

```bash
# Paso 1 — instalar dependencias con Conan para arm64
conan install . -pr:h=android_armv8 -pr:b=default --build=missing -of=build/android

# Paso 2 — configurar CMake con el toolchain de Conan (no $ANDROID_NDK/...)
cmake -S . -B build-android \
  -DCMAKE_TOOLCHAIN_FILE=build/android/build/Release/generators/conan_toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release

# Paso 3 — compilar
cmake --build build-android --config Release
```

Artefactos generados:
```
build-android/
├── libnetclient.so    # librería compartida (OpenSSL linkeado estáticamente)
└── netclient_test     # ejecutable de prueba
```


## 4.2 Compilar para Android desde Linux x86

> **Importante:** para Android siempre usar el toolchain de Conan, **nunca** el NDK directamente. El toolchain de Conan configura el NDK internamente Y provee OpenSSL cross-compilado para arm64.

```bash
wget https://dl.google.com/android/repository/android-ndk-r26d-linux.zip
unzip android-ndk-r26d-linux.zip -d ~/android-ndk

cat > ~/.conan2/profiles/android-arm64 << 'EOF'
[settings]
os=Android
os.api_level=21
arch=armv8
compiler=clang
compiler.version=17
compiler.libcxx=c++_shared
build_type=Release

[conf]
# Ruta al Android NDK. Ajusta según tu máquina.
# - kendall: /home/kendall/android-ndk/android-ndk-r26d
# - serverdevops: /home/serverdevops/android-ndk/android-ndk-r26d
tools.android:ndk_path=/home/serverdevops/android-ndk/android-ndk-r26d
tools.build:compiler_executables={'c': '/home/serverdevops/android-ndk/android-ndk-r26d/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang', 'cpp':'/home/serverdevops/android-ndk/android-ndk-r26d/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android21-clang++'}
EOF


# Paso 1 — instalar dependencias con Conan para arm64
conan install . -pr:h=android-arm64 -pr:b=default --build=missing -of=build/android -o "logicalaccess/*:LLA_BUILD_PKCS"

# Paso 2 — configurar CMake con el toolchain de Conan (no $ANDROID_NDK/...)
cmake -S . -B build/android_build \
    -DCMAKE_TOOLCHAIN_FILE=build/android/build/Release/generators/conan_toolchain.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLA_BUILD_PKCS=OFF

# Paso 3 — compilar
cmake --build build/android_build --config Release
```

## 4.3 Compilar para Linux

```bash
# Paso 1 — instalar dependencias con Conan
conan install . -pr:h=default -pr:b=default --build=missing -of=build/linux

# Paso 2 — configurar CMake con el toolchain generado por Conan
cmake -S . -B build \
  -DCMAKE_TOOLCHAIN_FILE=build/linux/build/Release/generators/conan_toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Release

# Paso 3 — compilar
cmake --build build --config Release
```

---

## 5. Ejecutar el binario en macOS

```bash
cd build
./netclient_test
# Respuesta: [macOS] OpenSSL OpenSSL 3.x.x ... | SHA-256(http://example.com) = f0e6a6a9...
```

---

## 6. Probar en Android via ADB

### Identificar dependencias dinámicas del binario

```bash
NDK=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125
"$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf" \
  --dynamic build-android/netclient_test | grep NEEDED
```

Salida típica:
```
NEEDED  libnetclient.so
NEEDED  libm.so
NEEDED  libc++_shared.so
NEEDED  libdl.so
NEEDED  libc.so
```

`libm`, `libc`, `libdl` ya están en el dispositivo. Solo hay que subir 3 archivos.

### Subir archivos y ejecutar

```bash
# 1. Subir los 3 archivos necesarios
adb push build-android/netclient_test /data/local/tmp/
# adb push build-android/system_sora_ws_test /data/local/tmp/
adb push build-android/libnetclient.so /data/local/tmp/
# adb push build-android/libsystem_sora_ws.so /data/local/tmp/
adb push \
  /opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so \
  /data/local/tmp/

# 2. Dar permisos y ejecutar
adb shell "cd /data/local/tmp && chmod +x netclient_test && LD_LIBRARY_PATH=/data/local/tmp ./netclient_test"
# adb shell "cd /data/local/tmp && chmod +x system_sora_ws_test && LD_LIBRARY_PATH=/data/local/tmp ./system_sora_ws_test"
```

Salida esperada:
```
Respuesta: [Android] OpenSSL OpenSSL 3.2.1 30 Jan 2024 | SHA-256(http://example.com) = f0e6a6a9...
```

> **¿Por qué solo 3 archivos?** OpenSSL queda linkeado estáticamente dentro de `libnetclient.so` cuando Conan lo compila para Android. No hay `.so` de OpenSSL que subir.

---

## 7. Próximos pasos — JNI

Para integrar la librería en una app Android real se necesita una capa JNI.

### Archivos adicionales a crear

```
src/platform/android/
└── transport_android_jni.cpp    # wrapper JNI
```

```cpp
// transport_android_jni.cpp
#include <jni.h>
#include <netclient/client.h>

extern "C"
JNIEXPORT jstring JNICALL
Java_com_tupackage_NetClient_get(JNIEnv* env, jobject, jstring jurl)
{
    const char* url = env->GetStringUTFChars(jurl, nullptr);
    netclient::Client client;
    std::string result = client.get(url);
    env->ReleaseStringUTFChars(jurl, url);
    return env->NewStringUTF(result.c_str());
}
```

### Cambio en CMakeLists.txt

```cmake
if(ANDROID)
    target_sources(netclient PRIVATE
        src/platform/android/transport_android.cpp
        src/platform/android/transport_android_jni.cpp  # agregar
    )
```

### Estructura del APK

```
app/src/main/
└── jniLibs/
    └── arm64-v8a/
        ├── libnetclient.so      # tu librería
        └── libc++_shared.so     # runtime C++
```

### Desde Kotlin/Java

```kotlin
companion object {
    init { System.loadLibrary("netclient") }
}
external fun get(url: String): String
```

---

## 8. Troubleshooting

### `Could NOT find OpenSSL` al compilar para Android

```
CMake Error: Could NOT find OpenSSL (missing: OPENSSL_CRYPTO_LIBRARY OPENSSL_INCLUDE_DIR)
```

**Causa:** se usó el NDK toolchain directamente (`-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake`).

**Fix:** usar el toolchain generado por Conan:
```bash
-DCMAKE_TOOLCHAIN_FILE=build/android/build/Release/generators/conan_toolchain.cmake
```

---

### `Duplicate preset: "conan-release"`

```
CMake Error: Could not read presets: Duplicate preset: "conan-release"
```

**Causa:** `CMakeUserPresets.json` incluye dos presets con el mismo nombre (macos + android generan ambos `conan-release`).

**Fix:** no usar `cmake --preset conan-release`. Usar siempre `-S . -B <dir> -DCMAKE_TOOLCHAIN_FILE=...` explícitamente.

---

### El binario se ejecuta en ADB pero devuelve error de librería

```
CANNOT LINK EXECUTABLE: library "libc++_shared.so" not found
```

**Causa:** falta subir `libc++_shared.so` al dispositivo.

**Fix:**
```bash
adb push $NDK/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so /data/local/tmp/
adb shell "LD_LIBRARY_PATH=/data/local/tmp ./netclient_test"
```

---

### `conan install` falla con "package not found"

```
ERROR: Missing binary: openssl/3.2.1:...
```

**Causa:** falta el flag `--build=missing`. Conan requiere compilar el paquete para este perfil y no está en caché.

**Fix:**
```bash
conan install . -pr:h=android_armv8 -pr:b=default --build=missing -of=build/android
#                                                   ^^^^^^^^^^^^^^
```

---

### Warnings de Conan 1.x (no es un error)

```
WARN: deprecated: 'cpp_info.names' used in: openssl/3.2.1
WARN: deprecated: 'env_info' used in: openssl/3.2.1
```

**Causa:** la receta de `openssl/3.2.1` en Conan Center todavía usa APIs de Conan 1.x. No afecta el build.

**Fix:** ninguno necesario. Si molestan, actualizar a `openssl/3.3.x` cuando esté disponible en el perfil.

---

### `CONAN_TOOLCHAIN_INCLUDED` guard no funciona en Conan 2.x

Si en `CMakeLists.txt` se intenta detectar si se está usando el toolchain de Conan con:

```cmake
if(ANDROID AND NOT CONAN_TOOLCHAIN_INCLUDED)
    message(FATAL_ERROR "...")
endif()
```

Esto dispara **incluso usando el toolchain de Conan** porque Conan 2.x no define esa variable. Eliminar el guard; el propio `find_package(OpenSSL REQUIRED)` ya falla con mensaje suficientemente claro.

---

### Agregar una nueva librería (flujo completo)

1. Agregar en `conanfile.py`:
   ```python
   self.requires("libcurl/8.6.0")
   ```
2. Volver a ejecutar `conan install` para cada plataforma (con `--build=missing`).
3. En `CMakeLists.txt`, agregar el `find_package` y `target_link_libraries` correspondientes — CMakeDeps genera el `Find<Pkg>.cmake` automáticamente.
4. Reconfigurar y recompilar con CMake.
