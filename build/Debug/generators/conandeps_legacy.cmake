message(STATUS "Conan: Using CMakeDeps conandeps_legacy.cmake aggregator via include()")
message(STATUS "Conan: It is recommended to use explicit find_package() per dependency instead")

find_package(CURL)
find_package(eclipse-paho-mqtt-c)

set(CONANDEPS_LEGACY  CURL::libcurl  eclipse-paho-mqtt-c::paho-mqtt3as-static )