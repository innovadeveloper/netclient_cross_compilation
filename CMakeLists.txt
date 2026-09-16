cmake_minimum_required(VERSION 3.20)
project(sample LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(sample SHARED src/sample.cpp)

target_include_directories(sample
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
)

find_package(CURL CONFIG REQUIRED)
find_package(eclipse-paho-mqtt-c CONFIG REQUIRED)
find_package(Libwebsockets CONFIG REQUIRED)


target_sources(sample PRIVATE src/websocket/lws_websocket_client.cpp)
target_link_libraries(sample PRIVATE websockets)

if(APPLE)
    message(STATUS "sample: backend macos")
    target_sources(sample PRIVATE src/platform/macos/transport_macos.cpp)
elseif(ANDROID)
    message(STATUS "sample: backend android")
    target_sources(sample PRIVATE src/platform/android/transport_android.cpp)
else()
    message(FATAL_ERROR "sample: plataforma no soportada")
endif()

add_executable(sample_test main.cpp)
target_link_libraries(sample_test PRIVATE 
    sample
    CURL::libcurl
    eclipse-paho-mqtt-c::paho-mqtt3as-static
    websockets)