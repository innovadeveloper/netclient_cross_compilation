# Avoid multiple calls to find_package to append duplicated properties to the targets
include_guard()########### VARIABLES #######################################################################
#############################################################################################
set(paho-mqtt-c_FRAMEWORKS_FOUND_DEBUG "") # Will be filled later
conan_find_apple_frameworks(paho-mqtt-c_FRAMEWORKS_FOUND_DEBUG "${paho-mqtt-c_FRAMEWORKS_DEBUG}" "${paho-mqtt-c_FRAMEWORK_DIRS_DEBUG}")

set(paho-mqtt-c_LIBRARIES_TARGETS "") # Will be filled later


######## Create an interface target to contain all the dependencies (frameworks, system and conan deps)
if(NOT TARGET paho-mqtt-c_DEPS_TARGET)
    add_library(paho-mqtt-c_DEPS_TARGET INTERFACE IMPORTED)
endif()

set_property(TARGET paho-mqtt-c_DEPS_TARGET
             APPEND PROPERTY INTERFACE_LINK_LIBRARIES
             $<$<CONFIG:Debug>:${paho-mqtt-c_FRAMEWORKS_FOUND_DEBUG}>
             $<$<CONFIG:Debug>:${paho-mqtt-c_SYSTEM_LIBS_DEBUG}>
             $<$<CONFIG:Debug>:openssl::openssl>)

####### Find the libraries declared in cpp_info.libs, create an IMPORTED target for each one and link the
####### paho-mqtt-c_DEPS_TARGET to all of them
conan_package_library_targets("${paho-mqtt-c_LIBS_DEBUG}"    # libraries
                              "${paho-mqtt-c_LIB_DIRS_DEBUG}" # package_libdir
                              "${paho-mqtt-c_BIN_DIRS_DEBUG}" # package_bindir
                              "${paho-mqtt-c_LIBRARY_TYPE_DEBUG}"
                              "${paho-mqtt-c_IS_HOST_WINDOWS_DEBUG}"
                              paho-mqtt-c_DEPS_TARGET
                              paho-mqtt-c_LIBRARIES_TARGETS  # out_libraries_targets
                              "_DEBUG"
                              "paho-mqtt-c"    # package_name
                              "${paho-mqtt-c_NO_SONAME_MODE_DEBUG}")  # soname

# FIXME: What is the result of this for multi-config? All configs adding themselves to path?
set(CMAKE_MODULE_PATH ${paho-mqtt-c_BUILD_DIRS_DEBUG} ${CMAKE_MODULE_PATH})

########## COMPONENTS TARGET PROPERTIES Debug ########################################

    ########## COMPONENT eclipse-paho-mqtt-c::paho-mqtt3as-static #############

        set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_FOUND_DEBUG "")
        conan_find_apple_frameworks(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_FOUND_DEBUG "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_DEBUG}" "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORK_DIRS_DEBUG}")

        set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARIES_TARGETS "")

        ######## Create an interface target to contain all the dependencies (frameworks, system and conan deps)
        if(NOT TARGET paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET)
            add_library(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET INTERFACE IMPORTED)
        endif()

        set_property(TARGET paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET
                     APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_FOUND_DEBUG}>
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_SYSTEM_LIBS_DEBUG}>
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPENDENCIES_DEBUG}>
                     )

        ####### Find the libraries declared in cpp_info.component["xxx"].libs,
        ####### create an IMPORTED target for each one and link the 'paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET' to all of them
        conan_package_library_targets("${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBS_DEBUG}"
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIB_DIRS_DEBUG}"
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_BIN_DIRS_DEBUG}" # package_bindir
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARY_TYPE_DEBUG}"
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_IS_HOST_WINDOWS_DEBUG}"
                              paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET
                              paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARIES_TARGETS
                              "_DEBUG"
                              "paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static"
                              "${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_NO_SONAME_MODE_DEBUG}")


        ########## TARGET PROPERTIES #####################################
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static
                     APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_OBJECTS_DEBUG}>
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARIES_TARGETS}>
                     )

        if("${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBS_DEBUG}" STREQUAL "")
            # If the component is not declaring any "cpp_info.components['foo'].libs" the system, frameworks etc are not
            # linked to the imported targets and we need to do it to the global target
            set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static
                         APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                         paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPS_TARGET)
        endif()

        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_LINK_OPTIONS
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LINKER_FLAGS_DEBUG}>)
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_INCLUDE_DIRS_DEBUG}>)
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_LINK_DIRECTORIES
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIB_DIRS_DEBUG}>)
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_DEFINITIONS_DEBUG}>)
        set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_COMPILE_OPTIONS
                     $<$<CONFIG:Debug>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_OPTIONS_DEBUG}>)


    ########## AGGREGATED GLOBAL TARGET WITH THE COMPONENTS #####################
    set_property(TARGET eclipse-paho-mqtt-c::paho-mqtt3as-static APPEND PROPERTY INTERFACE_LINK_LIBRARIES eclipse-paho-mqtt-c::paho-mqtt3as-static)

########## For the modules (FindXXX)
set(paho-mqtt-c_LIBRARIES_DEBUG eclipse-paho-mqtt-c::paho-mqtt3as-static)
