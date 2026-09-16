# Load the debug and release variables
file(GLOB DATA_FILES "${CMAKE_CURRENT_LIST_DIR}/eclipse-paho-mqtt-c-*-data.cmake")

foreach(f ${DATA_FILES})
    include(${f})
endforeach()

# Create the targets for all the components
foreach(_COMPONENT ${paho-mqtt-c_COMPONENT_NAMES} )
    if(NOT TARGET ${_COMPONENT})
        add_library(${_COMPONENT} INTERFACE IMPORTED)
        message(${eclipse-paho-mqtt-c_MESSAGE_MODE} "Conan: Component target declared '${_COMPONENT}'")
    endif()
endforeach()

if(NOT TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static)
    add_library(eclipse-paho-mqtt-c::paho-mqtt3as-static INTERFACE IMPORTED)
    message(${eclipse-paho-mqtt-c_MESSAGE_MODE} "Conan: Target declared 'eclipse-paho-mqtt-c::paho-mqtt3as-static'")
endif()
# Load the debug and release library finders
file(GLOB CONFIG_FILES "${CMAKE_CURRENT_LIST_DIR}/eclipse-paho-mqtt-c-Target-*.cmake")

foreach(f ${CONFIG_FILES})
    include(${f})
endforeach()