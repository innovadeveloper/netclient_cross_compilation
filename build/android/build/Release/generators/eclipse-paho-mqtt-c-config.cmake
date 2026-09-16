########## MACROS ###########################################################################
#############################################################################################

# Requires CMake > 3.15
if(${CMAKE_VERSION} VERSION_LESS "3.15")
    message(FATAL_ERROR "The 'CMakeDeps' generator only works with CMake >= 3.15")
endif()

if(eclipse-paho-mqtt-c_FIND_QUIETLY)
    set(eclipse-paho-mqtt-c_MESSAGE_MODE VERBOSE)
else()
    set(eclipse-paho-mqtt-c_MESSAGE_MODE STATUS)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/cmakedeps_macros.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/eclipse-paho-mqtt-cTargets.cmake)
include(CMakeFindDependencyMacro)

check_build_type_defined()

foreach(_DEPENDENCY ${paho-mqtt-c_FIND_DEPENDENCY_NAMES} )
    # Check that we have not already called a find_package with the transitive dependency
    if(NOT ${_DEPENDENCY}_FOUND)
        find_dependency(${_DEPENDENCY} REQUIRED ${${_DEPENDENCY}_FIND_MODE})
    endif()
endforeach()

set(eclipse-paho-mqtt-c_VERSION_STRING "1.3.16")
set(eclipse-paho-mqtt-c_INCLUDE_DIRS ${paho-mqtt-c_INCLUDE_DIRS_RELEASE} )
set(eclipse-paho-mqtt-c_INCLUDE_DIR ${paho-mqtt-c_INCLUDE_DIRS_RELEASE} )
set(eclipse-paho-mqtt-c_LIBRARIES ${paho-mqtt-c_LIBRARIES_RELEASE} )
set(eclipse-paho-mqtt-c_DEFINITIONS ${paho-mqtt-c_DEFINITIONS_RELEASE} )


# Definition of extra CMake variables from cmake_extra_variables


# Only the last installed configuration BUILD_MODULES are included to avoid the collision
foreach(_BUILD_MODULE ${paho-mqtt-c_BUILD_MODULES_PATHS_RELEASE} )
    message(${eclipse-paho-mqtt-c_MESSAGE_MODE} "Conan: Including build module from '${_BUILD_MODULE}'")
    include(${_BUILD_MODULE})
endforeach()


