# Avoid multiple calls to find_package to append duplicated properties to the targets
include_guard()########### VARIABLES #######################################################################
#############################################################################################
set(libwebsockets_FRAMEWORKS_FOUND_DEBUG "") # Will be filled later
conan_find_apple_frameworks(libwebsockets_FRAMEWORKS_FOUND_DEBUG "${libwebsockets_FRAMEWORKS_DEBUG}" "${libwebsockets_FRAMEWORK_DIRS_DEBUG}")

set(libwebsockets_LIBRARIES_TARGETS "") # Will be filled later


######## Create an interface target to contain all the dependencies (frameworks, system and conan deps)
if(NOT TARGET libwebsockets_DEPS_TARGET)
    add_library(libwebsockets_DEPS_TARGET INTERFACE IMPORTED)
endif()

set_property(TARGET libwebsockets_DEPS_TARGET
             APPEND PROPERTY INTERFACE_LINK_LIBRARIES
             $<$<CONFIG:Debug>:${libwebsockets_FRAMEWORKS_FOUND_DEBUG}>
             $<$<CONFIG:Debug>:${libwebsockets_SYSTEM_LIBS_DEBUG}>
             $<$<CONFIG:Debug>:openssl::openssl>)

####### Find the libraries declared in cpp_info.libs, create an IMPORTED target for each one and link the
####### libwebsockets_DEPS_TARGET to all of them
conan_package_library_targets("${libwebsockets_LIBS_DEBUG}"    # libraries
                              "${libwebsockets_LIB_DIRS_DEBUG}" # package_libdir
                              "${libwebsockets_BIN_DIRS_DEBUG}" # package_bindir
                              "${libwebsockets_LIBRARY_TYPE_DEBUG}"
                              "${libwebsockets_IS_HOST_WINDOWS_DEBUG}"
                              libwebsockets_DEPS_TARGET
                              libwebsockets_LIBRARIES_TARGETS  # out_libraries_targets
                              "_DEBUG"
                              "libwebsockets"    # package_name
                              "${libwebsockets_NO_SONAME_MODE_DEBUG}")  # soname

# FIXME: What is the result of this for multi-config? All configs adding themselves to path?
set(CMAKE_MODULE_PATH ${libwebsockets_BUILD_DIRS_DEBUG} ${CMAKE_MODULE_PATH})

########## COMPONENTS TARGET PROPERTIES Debug ########################################

    ########## COMPONENT websockets #############

        set(libwebsockets_websockets_FRAMEWORKS_FOUND_DEBUG "")
        conan_find_apple_frameworks(libwebsockets_websockets_FRAMEWORKS_FOUND_DEBUG "${libwebsockets_websockets_FRAMEWORKS_DEBUG}" "${libwebsockets_websockets_FRAMEWORK_DIRS_DEBUG}")

        set(libwebsockets_websockets_LIBRARIES_TARGETS "")

        ######## Create an interface target to contain all the dependencies (frameworks, system and conan deps)
        if(NOT TARGET libwebsockets_websockets_DEPS_TARGET)
            add_library(libwebsockets_websockets_DEPS_TARGET INTERFACE IMPORTED)
        endif()

        set_property(TARGET libwebsockets_websockets_DEPS_TARGET
                     APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_FRAMEWORKS_FOUND_DEBUG}>
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_SYSTEM_LIBS_DEBUG}>
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_DEPENDENCIES_DEBUG}>
                     )

        ####### Find the libraries declared in cpp_info.component["xxx"].libs,
        ####### create an IMPORTED target for each one and link the 'libwebsockets_websockets_DEPS_TARGET' to all of them
        conan_package_library_targets("${libwebsockets_websockets_LIBS_DEBUG}"
                              "${libwebsockets_websockets_LIB_DIRS_DEBUG}"
                              "${libwebsockets_websockets_BIN_DIRS_DEBUG}" # package_bindir
                              "${libwebsockets_websockets_LIBRARY_TYPE_DEBUG}"
                              "${libwebsockets_websockets_IS_HOST_WINDOWS_DEBUG}"
                              libwebsockets_websockets_DEPS_TARGET
                              libwebsockets_websockets_LIBRARIES_TARGETS
                              "_DEBUG"
                              "libwebsockets_websockets"
                              "${libwebsockets_websockets_NO_SONAME_MODE_DEBUG}")


        ########## TARGET PROPERTIES #####################################
        set_property(TARGET websockets
                     APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_OBJECTS_DEBUG}>
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_LIBRARIES_TARGETS}>
                     )

        if("${libwebsockets_websockets_LIBS_DEBUG}" STREQUAL "")
            # If the component is not declaring any "cpp_info.components['foo'].libs" the system, frameworks etc are not
            # linked to the imported targets and we need to do it to the global target
            set_property(TARGET websockets
                         APPEND PROPERTY INTERFACE_LINK_LIBRARIES
                         libwebsockets_websockets_DEPS_TARGET)
        endif()

        set_property(TARGET websockets APPEND PROPERTY INTERFACE_LINK_OPTIONS
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_LINKER_FLAGS_DEBUG}>)
        set_property(TARGET websockets APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_INCLUDE_DIRS_DEBUG}>)
        set_property(TARGET websockets APPEND PROPERTY INTERFACE_LINK_DIRECTORIES
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_LIB_DIRS_DEBUG}>)
        set_property(TARGET websockets APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_COMPILE_DEFINITIONS_DEBUG}>)
        set_property(TARGET websockets APPEND PROPERTY INTERFACE_COMPILE_OPTIONS
                     $<$<CONFIG:Debug>:${libwebsockets_websockets_COMPILE_OPTIONS_DEBUG}>)


    ########## AGGREGATED GLOBAL TARGET WITH THE COMPONENTS #####################
    set_property(TARGET websockets APPEND PROPERTY INTERFACE_LINK_LIBRARIES websockets)

########## For the modules (FindXXX)
set(libwebsockets_LIBRARIES_DEBUG websockets)
