########### AGGREGATED COMPONENTS AND DEPENDENCIES FOR THE MULTI CONFIG #####################
#############################################################################################

list(APPEND paho-mqtt-c_COMPONENT_NAMES eclipse-paho-mqtt-c::paho-mqtt3as-static)
list(REMOVE_DUPLICATES paho-mqtt-c_COMPONENT_NAMES)
if(DEFINED paho-mqtt-c_FIND_DEPENDENCY_NAMES)
  list(APPEND paho-mqtt-c_FIND_DEPENDENCY_NAMES OpenSSL)
  list(REMOVE_DUPLICATES paho-mqtt-c_FIND_DEPENDENCY_NAMES)
else()
  set(paho-mqtt-c_FIND_DEPENDENCY_NAMES OpenSSL)
endif()
set(OpenSSL_FIND_MODE "NO_MODULE")

########### VARIABLES #######################################################################
#############################################################################################
set(paho-mqtt-c_PACKAGE_FOLDER_RELEASE "/Users/kenny/.conan2/p/b/paho-afee0ab2964a4/p")
set(paho-mqtt-c_BUILD_MODULES_PATHS_RELEASE )


set(paho-mqtt-c_INCLUDE_DIRS_RELEASE "${paho-mqtt-c_PACKAGE_FOLDER_RELEASE}/include")
set(paho-mqtt-c_RES_DIRS_RELEASE )
set(paho-mqtt-c_DEFINITIONS_RELEASE )
set(paho-mqtt-c_SHARED_LINK_FLAGS_RELEASE )
set(paho-mqtt-c_EXE_LINK_FLAGS_RELEASE )
set(paho-mqtt-c_OBJECTS_RELEASE )
set(paho-mqtt-c_COMPILE_DEFINITIONS_RELEASE )
set(paho-mqtt-c_COMPILE_OPTIONS_C_RELEASE )
set(paho-mqtt-c_COMPILE_OPTIONS_CXX_RELEASE )
set(paho-mqtt-c_LIB_DIRS_RELEASE "${paho-mqtt-c_PACKAGE_FOLDER_RELEASE}/lib")
set(paho-mqtt-c_BIN_DIRS_RELEASE )
set(paho-mqtt-c_LIBRARY_TYPE_RELEASE STATIC)
set(paho-mqtt-c_IS_HOST_WINDOWS_RELEASE 0)
set(paho-mqtt-c_LIBS_RELEASE paho-mqtt3as)
set(paho-mqtt-c_SYSTEM_LIBS_RELEASE c)
set(paho-mqtt-c_FRAMEWORK_DIRS_RELEASE )
set(paho-mqtt-c_FRAMEWORKS_RELEASE )
set(paho-mqtt-c_BUILD_DIRS_RELEASE )
set(paho-mqtt-c_NO_SONAME_MODE_RELEASE FALSE)


# COMPOUND VARIABLES
set(paho-mqtt-c_COMPILE_OPTIONS_RELEASE
    "$<$<COMPILE_LANGUAGE:CXX>:${paho-mqtt-c_COMPILE_OPTIONS_CXX_RELEASE}>"
    "$<$<COMPILE_LANGUAGE:C>:${paho-mqtt-c_COMPILE_OPTIONS_C_RELEASE}>")
set(paho-mqtt-c_LINKER_FLAGS_RELEASE
    "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,SHARED_LIBRARY>:${paho-mqtt-c_SHARED_LINK_FLAGS_RELEASE}>"
    "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,MODULE_LIBRARY>:${paho-mqtt-c_SHARED_LINK_FLAGS_RELEASE}>"
    "$<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>:${paho-mqtt-c_EXE_LINK_FLAGS_RELEASE}>")


set(paho-mqtt-c_COMPONENTS_RELEASE eclipse-paho-mqtt-c::paho-mqtt3as-static)
########### COMPONENT eclipse-paho-mqtt-c::paho-mqtt3as-static VARIABLES ############################################

set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_INCLUDE_DIRS_RELEASE "${paho-mqtt-c_PACKAGE_FOLDER_RELEASE}/include")
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIB_DIRS_RELEASE "${paho-mqtt-c_PACKAGE_FOLDER_RELEASE}/lib")
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_BIN_DIRS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBRARY_TYPE_RELEASE STATIC)
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_IS_HOST_WINDOWS_RELEASE 0)
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_RES_DIRS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEFINITIONS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_OBJECTS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_DEFINITIONS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_OPTIONS_C_RELEASE "")
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_OPTIONS_CXX_RELEASE "")
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LIBS_RELEASE paho-mqtt3as)
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_SYSTEM_LIBS_RELEASE c)
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORK_DIRS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_FRAMEWORKS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_DEPENDENCIES_RELEASE openssl::openssl)
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_SHARED_LINK_FLAGS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_EXE_LINK_FLAGS_RELEASE )
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_NO_SONAME_MODE_RELEASE FALSE)

# COMPOUND VARIABLES
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_LINKER_FLAGS_RELEASE
        $<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,SHARED_LIBRARY>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_SHARED_LINK_FLAGS_RELEASE}>
        $<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,MODULE_LIBRARY>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_SHARED_LINK_FLAGS_RELEASE}>
        $<$<STREQUAL:$<TARGET_PROPERTY:TYPE>,EXECUTABLE>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_EXE_LINK_FLAGS_RELEASE}>
)
set(paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_OPTIONS_RELEASE
    "$<$<COMPILE_LANGUAGE:CXX>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_OPTIONS_CXX_RELEASE}>"
    "$<$<COMPILE_LANGUAGE:C>:${paho-mqtt-c_eclipse-paho-mqtt-c_paho-mqtt3as-static_COMPILE_OPTIONS_C_RELEASE}>")