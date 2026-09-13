cmake_minimum_required(VERSION 3.20)
project(netclient LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(netclient SHARED
    src/client.cpp
)

target_include_directories(netclient
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/src
)

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
    message(FATAL_ERROR "netclient: plataforma no soportada por este CMakeLists")
endif()

# --- Ejecutable de prueba (solo para probar la librería localmente) ---
add_executable(netclient_test main.cpp)
target_link_libraries(netclient_test PRIVATE netclient)
