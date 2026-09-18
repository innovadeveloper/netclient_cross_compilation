cmake_minimum_required(VERSION 3.20)
project(system_sora LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_library(system_sora_ws SHARED src/sample.cpp)

target_include_directories(system_sora_ws
    PUBLIC  ${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src
)

find_package(CURL CONFIG REQUIRED)
find_package(eclipse-paho-mqtt-c CONFIG REQUIRED)
find_package(Libwebsockets CONFIG REQUIRED)


target_sources(system_sora_ws PRIVATE src/websocket/lws_websocket_client.cpp)
target_link_libraries(system_sora_ws PRIVATE websockets)

if(APPLE)
    message(STATUS "system_sora_ws: backend macos")
    target_sources(system_sora_ws PRIVATE src/platform/macos/transport_macos.cpp)
elseif(ANDROID)
    message(STATUS "system_sora_ws: backend android")
    target_sources(system_sora_ws PRIVATE src/platform/android/transport_android.cpp)
else()
    message(FATAL_ERROR "system_sora_ws: plataforma no soportada")
endif()

add_executable(system_sora_ws_test main.cpp)
target_link_libraries(system_sora_ws_test PRIVATE
    system_sora_ws
    CURL::libcurl
    eclipse-paho-mqtt-c::paho-mqtt3as-static
    websockets)

find_package(Threads REQUIRED)
add_executable(event_loop_demo examples/event_loop_demo.cpp)
target_link_libraries(event_loop_demo PRIVATE Threads::Threads)