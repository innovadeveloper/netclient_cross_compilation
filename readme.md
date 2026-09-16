```sh

brew install autoconf automake libtool

Paso 1 — Instalar dependencias con el perfil Android:
cd /Users/kenny/Projects/sample
conan install . \
  --profile android_armv8 \
  --output-folder=build-android \
  --build=missing

Esto descarga/compila CURL y paho-mqtt compilados para arm64-android y genera los CMake files en build-android/Release/generators/ (el perfil tiene build_type=Release).

Paso 2 — Configurar CMake apuntando a esos generadores:

export ANDROID_NDK=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125


cmake -S . -B build-android \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
  -DCMAKE_PREFIX_PATH=$(pwd)/build-android/Release/generators \
  -DCMAKE_BUILD_TYPE=Release

Paso 3 — Compilar:
cmake --build build-android

---

ThroubleShooting 

Error 001 : Eror de construcción (Add the installation prefix of "XYZ" to CMAKE_PREFIX_PATH ....)

rm -rf /Users/kenny/Projects/sample/build-android/CMakeCache.txt \
       /Users/kenny/Projects/sample/build-android/CMakeFiles

```