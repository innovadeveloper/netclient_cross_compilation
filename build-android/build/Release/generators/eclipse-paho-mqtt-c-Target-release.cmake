# Avoid multiple calls to find_package to append duplicated properties to the targets
include_guard()########### VARIABLES #######################################################################
#############################################################################################
set(paho-mqtt-c_FRAMEWORKS_FOUND_RELEASE "") # Will be filled later
conan_find_apple_frameworks(paho-mqtt-c_FRAMEWORKS_FOUND_RELEASE "${paho-mqtt-c_FRAMEWORKS_RELEASE}" "${paho-mqtt-c_FRAMEWORK_DIRS_RELEASE}")

set(paho-mqtt-c_LIBRARIES_TARGETS "") # Will be filled later


######## Create an interface target to contain all the dependencies (frameworks, system and conan deps)
if(NOT TARGET paho-mqtt-c_DEPS_TARGET)
    add_library(paho-mqtt-c_DEPS_TARGET INTERFACE IMPORTED)
endif()

set_property(TARGET paho-mqtt-c_DEPS_TARGET
             APPEND PROPERTY INTERFACE_LINK_LIBRARIES
             $<$<CONFIG:Release>:${paho-mqtt-c_FRAMEWORKS_FOUND_RELEASE}>
             $<$<CONFIG:Release>:${paho-mqtt-c_SYSTEM_LIBS_RELEASE}>
             $<$<CONFIG:Release>:openssl::openssl>)

####### Find the libraries declared in cpp_info.libs, create an IMPORTED target for each one and link the
####### paho-mqtt-c_DEPS_TARGET to all of them
conan_package_library_targets("${paho-mqtt-c_LIBS_RELEASE}"    # libraries
                              "${paho-mqtt-c_LIB_DIRS_RELEASE}" # package_libdir
                              "${paho-mqtt-c_BIN_DIRS_RELEASE}" # package_bindir
                              "${paho-mqtt-c_LIBRARY_TYPE_RELEASE}"
                              "${paho-mqtt-c_IS_HOST_WINDOWS_RELEASE}"
                              paho-mqtt-c_DEPS_TARGET
                              paho-mqtt-c_LIBRARIES_TARGETS  # out_libraries_targets
                              "_RELEASE"
                              "paho-mqtt-c"    # package_name
                              "${paho-mqtt-c_NO_SONAME_MODE_RELEASE}")  # soname

# FIXME: What is the result of this for multi-config? All configs adding themselves to path?
set(CMAKE_MODULE_PATH ${paho-mqtt-c_BUILD_DIRS_RELEASE} ${CMAKE_MODULE_PATH})

########## COMPONENTS TARGET PROPERTIES Release ########################################

    ########## COMPONENT eclipse-paho-mqtt-c::paho-mqtt3as-static #############

        set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_FOUND_RELEASE "")
        conan_find_apple_frameworks(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_FOUND_RELEASE "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_RELEASE}" "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORK_DIRS_RELEASE}")

        set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARIES_TARGETS "")

        ######## Create an interface target to contain all the dependencies (frameworks, system and conan deps)
        if(NOT TARGET paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET)
            add_library(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET INTERFACE IMPORTED)
        endif()

        set_property(TARGET paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET
                     APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_FOUND_RELEASE}>
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_SYSTEM_LIBS_RELEASE}>
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPENDENCIES_RELEASE}>
                     )

        ####### Find the libraries declared in cpp_info.component["xxx"].libs,
        ####### create an IMPORTED target for each one and link the 'paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET' to all of them
        conan_package_library_targets("${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBS_RELEASE}"
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIB_DIRS_RELEASE}"
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_BIN_DIRS_RELEASE}" # package_bindir
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARY_TYPE_RELEASE}"
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_IS_HOST_WINDOWS_RELEASE}"
                              paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET
                              paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARIES_TARGETS
                              "_RELEASE"
                              "paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static"
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_NO_SONAME_MODE_RELEASE}")


        ########## TARGET PROPERTIES #####################################
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static
                     APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_OBJECTS_RELEASE}>
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARIES_TARGETS}>
                     )

        if("${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBS_RELEASE}" STREQUAL "")
            # If the component is not declaring any "cpp_info.components['foo'].libs" the system, frameworks etc are not
            # linked to the imported targets and we need to do it to the global target
            set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static
                         APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                         paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET)
        endif()

        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_LINK_OPTIONS
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LINKER_FLAGS_RELEASE}>)
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_INCLUDE_DIRS_RELEASE}>)
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_LINK_DIRECTORIES
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIB_DIRS_RELEASE}>)
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_DEFINITIONS_RELEASE}>)
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_COMPILE_OPTIONS
                     $<$<CONFIG:Release>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_OPTIONS_RELEASE}>)


    ########## AGGREGATED GLOBAL TARGET WITH THE COMPONENTS #####################
    set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_LINK_LIBRARIES eclipse-paho-mqtt-c::paho-mqtt3as-static)

########## For the modules (FindXXX)
set(paho-mqtt-c_LIBRARIES_RELEASE eclipse-paho-mqtt-c::paho-mqtt3as-static)
