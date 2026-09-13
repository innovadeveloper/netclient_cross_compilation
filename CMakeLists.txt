cmake_minimum_required(VERSION 3.20)
project(netclient LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# POC: solo Android y macOS. ESP32 excluido (no pasa por Conan/CMake).
#
# Android: OpenSSL viene cross-compilado desde Conan. Usar siempre el toolchain de Conan:
#   cmake -S . -B build-android \
#     -DCMAKE_TOOLCHAIN_FILE=build/android/build/Release/generators/conan_toolchain.cmake \
#     -DCMAKE_BUILD_TYPE=Release
# El NDK toolchain directo NO provee OpenSSL para arm64.
find_package(OpenSSL REQUIRED)

add_library(netclient SHARED
    src/client.cpp
)

target_include_directories(netclient
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(netclient PRIVATE OpenSSL::SSL OpenSSL::Crypto)

if(ANDROID)
    message(STATUS "netclient: compilando backend ANDROID")
    target_sources(netclient PRIVATE
        src/platform/android/transport_android.cpp
    )
elseif(APPLE)
    message(STATUS "netclient: compilando backend MACOS")
    target_sources(netclient PRIVATE
        src/platform/macos/transport_macos.cpp
    )
else()
    # esp32 y otras plataformas embebidas no están en scope de este POC
    message(FATAL_ERROR "netclient: plataforma no soportada (solo Android / macOS)")
endif()

# --- Ejecutable de prueba (solo para probar la librería localmente) ---
add_executable(netclient_test main.cpp)
target_link_libraries(netclient_test PRIVATE netclient)
