########### AGGREGATED COMPONENTS AND DEPENDENCIES FOR THE MULTI CONFIG #####################
#############################################################################################

list(APPEND libwebsockets_COMPONENT_NAMES websockets)
list(REMOVE_DUPLICATES libwebsockets_COMPONENT_NAMES)
if(DEFINED libwebsockets_FIND_DEPENDENCY_NAMES)
  list(APPEND libwebsockets_FIND_DEPENDENCY_NAMES OpenSSL)
  list(REMOVE_DUPLICATES libwebsockets_FIND_DEPENDENCY_NAMES)
else()
  set(libwebsockets_FIND_DEPENDENCY_NAMES OpenSSL)
endif()
set(OpenSSL_FIND_MODE "NO_MODULE")

########### VARIABLES #######################################################################
#############################################################################################
set(libwebsockets_PACKAGE_FOLDER_RELEASE "/Users/kenny/.conan2/p/b/libweed99559db67fe/p")
set(libwebsockets_BUILD_MODULES_PATHS_RELEASE )


set(libwebsockets_INCLUDE_DIRS_RELEASE "${libwebsockets_PACKAGE_FOLDER_RELEASE}/include")
set(libwebsockets_RES_DIRS_RELEASE )
set(libwebsockets_DEFINITIONS_RELEASE )
set(libwebsockets_SHARED_LINK_FLAGS_RELEASE )
set(libwebsockets_EXE_LINK_FLAGS_RELEASE )
set(libwebsockets_OBJECTS_RELEASE )
set(libwebsockets_COMPILE_DEFINITIONS_RELEASE )
set(libwebsockets_COMPILE_OPTIONS_C_RELEASE )
set(libwebsockets_COMPILE_OPTIONS_CXX_RELEASE )
set(libwebsockets_LIB_DIRS_RELEASE "${libwebsockets_PACKAGE_FOLDER_RELEASE}/lib")
set(libwebsockets_BIN_DIRS_RELEASE )
set(libwebsockets_LIBRARY_TYPE_RELEASE STATIC)
set(libwebsockets_IS_HOST_WINDOWS_RELEASE 0)
set(libwebsockets_LIBS_RELEASE websockets)
set(libwebsockets_SYSTEM_LIBS_RELEASE )
set(libwebsockets_FRAMEWORK_DIRS_RELEASE )
set(libwebsockets_FRAMEWORKS_RELEASE )
set(libwebsockets_BUILD_DIRS_RELEASE "${libwebsockets_PACKAGE_FOLDER_RELEASE}/lib/cmake")
set(libwebsockets_NO_SONAME_MODE_RELEASE FALSE)


# COMPOUND VARIABLES
set(libwebsockets_COMPILE_OPTIONS_RELEASE
    "$<$<COMPILE_LANGUAGE:CXX>:${libwebsockets_COMPILE_OPTIONS_CXX_RELEASE}>"
    "$<$<COMPILE_LANGUAGE:C>:${libwebsockets_COMPILE_OPTIONS_C_RELEASE}>")
set(libwebsockets_LINKER_FLAGS_RELEASE
    "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,SHARED_LIBRARY>:${libwebsockets_SHARED_LINK_FLAGS_RELEASE}>"
    "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,MODULE_LIBRARY>:${libwebsockets_SHARED_LINK_FLAGS_RELEASE}>"
    "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>:${libwebsockets_EXE_LINK_FLAGS_RELEASE}>")


set(libwebsockets_COMPONENTS_RELEASE websockets)
########### COMPONENT websockets VARIABLES ############################################

set(libwebsockets_websockets_INCLUDE_DIRS_RELEASE "${libwebsockets_PACKAGE_FOLDER_RELEASE}/include")
set(libwebsockets_websockets_LIB_DIRS_RELEASE "${libwebsockets_PACKAGE_FOLDER_RELEASE}/lib")
set(libwebsockets_websockets_BIN_DIRS_RELEASE )
set(libwebsockets_websockets_LIBRARY_TYPE_RELEASE STATIC)
set(libwebsockets_websockets_IS_HOST_WINDOWS_RELEASE 0)
set(libwebsockets_websockets_RES_DIRS_RELEASE )
set(libwebsockets_websockets_DEFINITIONS_RELEASE )
set(libwebsockets_websockets_OBJECTS_RELEASE )
set(libwebsockets_websockets_COMPILE_DEFINITIONS_RELEASE )
set(libwebsockets_websockets_COMPILE_OPTIONS_C_RELEASE "")
set(libwebsockets_websockets_COMPILE_OPTIONS_CXX_RELEASE "")
set(libwebsockets_websockets_LIBS_RELEASE websockets)
set(libwebsockets_websockets_SYSTEM_LIBS_RELEASE )
set(libwebsockets_websockets_FRAMEWORK_DIRS_RELEASE )
set(libwebsockets_websockets_FRAMEWORKS_RELEASE )
set(libwebsockets_websockets_DEPENDENCIES_RELEASE openssl::openssl)
set(libwebsockets_websockets_SHARED_LINK_FLAGS_RELEASE )
set(libwebsockets_websockets_EXE_LINK_FLAGS_RELEASE )
set(libwebsockets_websockets_NO_SONAME_MODE_RELEASE FALSE)

# COMPOUND VARIABLES
set(libwebsockets_websockets_LINKER_FLAGS_RELEASE
        $<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,SHARED_LIBRARY>:${libwebsockets_websockets_SHARED_LINK_FLAGS_RELEASE}>
        $<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,MODULE_LIBRARY>:${libwebsockets_websockets_SHARED_LINK_FLAGS_RELEASE}>
        $<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>:${libwebsockets_websockets_EXE_LINK_FLAGS_RELEASE}>
)
set(libwebsockets_websockets_COMPILE_OPTIONS_RELEASE
    "$<$<COMPILE_LANGUAGE:CXX>:${libwebsockets_websockets_COMPILE_OPTIONS_CXX_RELEASE}>"
    "$<$<COMPILE_LANGUAGE:C>:${libwebsockets_websockets_COMPILE_OPTIONS_C_RELEASE}>")