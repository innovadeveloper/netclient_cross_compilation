script_folder="/Users/kenny/Projects/C++Projects/netclient_cross_compilation/build/Debug/generators"
echo "echo Restoring environment" > "$script_folder/deactivate_conanrunenv-debug-armv8.sh"
for v in OPENSSL_MODULES
do
   is_defined="true"
   value=$(printenv $v) || is_defined="" || true
   if [ -n "$value" ] || [ -n "$is_defined" ]
   then
       echo export "$v='$value'" >> "$script_folder/deactivate_conanrunenv-debug-armv8.sh"
   else
       echo unset $v >> "$script_folder/deactivate_conanrunenv-debug-armv8.sh"
   fi
done

export OPENSSL_MODULES="/Users/kenny/.conan2/p/b/opens1cdd558f833a2/p/lib/ossl-modules"