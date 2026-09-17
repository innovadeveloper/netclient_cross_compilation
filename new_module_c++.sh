#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
#  new_module_c++.sh  –  Generador de módulos C++ para VSCode
#  Sin dependencias externas: todas las plantillas viven en este fichero.
#
#  Uso:   ./new_module_c++.sh <nombre> [--type simple|cross] [--platforms ...]
#  Ayuda: ./new_module_c++.sh --help
#  Guía:  ./new_module_c++.sh --guide
# ═══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"


# ══════════════════════════════════════════════════════════════════════════════
#  SECCIÓN 1 ─ AYUDA Y GUÍA
# ══════════════════════════════════════════════════════════════════════════════

usage() {
    cat <<'HELP'

  Uso: new_module_c++.sh <nombre_modulo> [opciones]

  Opciones:
    --type simple        Ejecutable plano (default)
    --type cross         Librería con backends por plataforma
    --platforms p1,p2    Plataformas para --type cross
                         Disponibles: macos  linux  android  ios  windows
    --guide              Guía completa: build, debug, personalización
    -h, --help           Esta pantalla

  Ejemplos:
    ./new_module_c++.sh level4_threads
    ./new_module_c++.sh level5_http   --type cross --platforms macos,linux
    ./new_module_c++.sh netclient     --type cross --platforms macos,android,ios

HELP
    exit 1
}

guide() {
    cat <<'GUIDE'

╔══════════════════════════════════════════════════════════════════════════════╗
║               GUÍA  ─  new_module_c++.sh                                   ║
╚══════════════════════════════════════════════════════════════════════════════╝

▌ FLUJO RÁPIDO EN VSCODE
  1. Ejecuta el script → se crea la carpeta del módulo
  2. Abre esa carpeta en VSCode  (File › Open Folder…)
  3. Compila:  Run Task  ›  "<modulo>: cmake build"
  4. Depura:   Run & Debug  ›  "<modulo>: debug (conan+cmake)"

──────────────────────────────────────────────────────────────────────────────
▌ COMANDOS MANUALES  (ejecuta desde dentro de la carpeta del módulo)

  # 0. Configurar Conan (si no lo has hecho antes):
```bash
mkdir -p ~/.conan2/profiles
cat > ~/.conan2/profiles/default << 'EOF'
[settings]
arch=armv8
build_type=Release
compiler=apple-clang
compiler.cppstd=gnu17
compiler.libcxx=libc++
compiler.version=15
os=Macos
EOF

cat > ~/.conan2/profiles/android_armv8 << 'EOF'
[settings]
arch=armv8
build_type=Release
compiler=clang
compiler.cppstd=17
compiler.libcxx=c++_shared
compiler.version=17
os=Android
os.api_level=24

[conf]
tools.android:ndk_path=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125

[buildenv]
PATH+=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/bin
EOF


# Android desde Linux


1. Instalar NDK

# Descargar Android NDK (r26 o superior recomendado)
wget https://dl.google.com/android/repository/android-ndk-r26d-linux.zip
unzip android-ndk-r26d-linux.zip -d ~/android-ndk

2. Crear perfil Conan para Android

conan profile detect --name android-arm64

Edita ~/.conan2/profiles/android-arm64:
[settings]
os=Android
os.api_level=21
arch=armv8
compiler=clang
compiler.version=17
compiler.libcxx=c++_shared
build_type=Release

[conf]
tools.android:ndk_path=/home/kendall/android-ndk/android-ndk-r26d

```




```bash
conan profile list
conan profile show -pr=android_armv8
conan profile show -pr=default
```


# 1. Instalar dependencias (Conan):
conan install . --build=missing -s build_type=Debug

# 2. Configurar (CMake + Ninja):
cmake -B build -S . \
-DCMAKE_TOOLCHAIN_FILE=build/Debug/generators/conan_toolchain.cmake \
-DCMAKE_PREFIX_PATH=build/Debug/generators \
-DCMAKE_BUILD_TYPE=Debug -G Ninja

# 3. Compilar:
cmake --build build

# 4. Ejecutar:
./build/<nombre_modulo>

──────────────────────────────────────────────────────────────────────────────
▌ AÑADIR DEPENDENCIAS CONAN
  Edita conanfile.py en la función requirements():

    def requirements(self):
        self.requires("openssl/3.2.1")
        self.requires("fmt/10.2.1")

▌ CAMBIAR ESTÁNDAR C++
  Edita CMakeLists.txt:
    set(CMAKE_CXX_STANDARD 20)    ← cambia 17 → 20 o 23

──────────────────────────────────────────────────────────────────────────────
▌ PERSONALIZAR LAS PLANTILLAS
  No hay carpeta _template/: todo está en este script como funciones gen_*.
  Busca la función correspondiente al fichero que quieres modificar:

    gen_main_cpp()              →  main.cpp
    gen_cmake_simple()          →  CMakeLists.txt  (modo --type simple)
    gen_cmake_cross()           →  CMakeLists.txt  (modo --type cross)
    gen_conanfile()             →  conanfile.py
    gen_tasks_json()            →  .vscode/tasks.json
    gen_launch_json()           →  .vscode/launch.json
    gen_cpp_properties_json()   →  .vscode/c_cpp_properties.json

  Usa __MODULE_NAME__ como placeholder: el script lo sustituye por el nombre real.

──────────────────────────────────────────────────────────────────────────────
▌ ESTRUCTURA GENERADA  (--type simple)

  <modulo>/
  ├── main.cpp
  ├── CMakeLists.txt
  ├── conanfile.py
  ├── src/<modulo>.cpp
  ├── include/<modulo>/<modulo>.h
  └── .vscode/
      ├── tasks.json            ← conan install → cmake configure → cmake build
      ├── launch.json           ← debug normal + debug fast (sin reconfigurar)
      ├── settings.json
      └── c_cpp_properties.json

▌ ESTRUCTURA GENERADA  (--type cross --platforms macos,linux)

  <modulo>/
  ├── main.cpp
  ├── CMakeLists.txt            ← bloques if(APPLE) / if(UNIX AND NOT APPLE) / …
  ├── conanfile.py
  ├── src/
  │   ├── <modulo>.cpp
  │   ├── transport/transport.h     ← interfaz común entre plataformas
  │   └── platform/
  │       ├── macos/transport_macos.cpp
  │       └── linux/transport_linux.cpp
  ├── include/<modulo>/<modulo>.h
  └── .vscode/

GUIDE
    exit 0
}


# ══════════════════════════════════════════════════════════════════════════════
#  SECCIÓN 2 ─ ARGUMENTOS
# ══════════════════════════════════════════════════════════════════════════════

MODULE=""
TYPE="simple"
PLATFORMS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)   usage ;;
        --guide)     guide ;;
        --type)      TYPE="$2";      shift 2 ;;
        --platforms) PLATFORMS="$2"; shift 2 ;;
        -*)          echo "Opción desconocida: $1"; usage ;;
        *)           MODULE="$1"; shift ;;
    esac
done

[[ -z "$MODULE" ]] && { echo "Error: falta el nombre del módulo."; usage; }

DEST="$SCRIPT_DIR/$MODULE"
[[ -d "$DEST" ]] && { echo "Error: '$DEST' ya existe."; exit 1; }


# ══════════════════════════════════════════════════════════════════════════════
#  SECCIÓN 3 ─ PLANTILLAS
#
#  Cada función gen_* escribe un fichero en $DEST.
#  Edita el contenido del heredoc para personalizar la plantilla.
#  Usa __MODULE_NAME__ donde quieras que aparezca el nombre del módulo.
# ══════════════════════════════════════════════════════════════════════════════

# ─── main.cpp ────────────────────────────────────────────────────────────────
gen_main_cpp() {
    sed "s/__MODULE_NAME__/$MODULE/g" <<'EOF' > "$DEST/main.cpp"
#include <iostream>

int main() {
    std::cout << "__MODULE_NAME__ running\n";
    return 0;
}
EOF
}

# ─── CMakeLists.txt  (modo simple: produce un ejecutable) ────────────────────
gen_cmake_simple() {
    sed "s/__MODULE_NAME__/$MODULE/g" <<'EOF' > "$DEST/CMakeLists.txt"
cmake_minimum_required(VERSION 3.20)
project(__MODULE_NAME__ LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

add_executable(__MODULE_NAME__
    main.cpp
    src/__MODULE_NAME__.cpp
)

target_include_directories(__MODULE_NAME__ PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
EOF
}

# ─── CMakeLists.txt  (modo cross: librería + bloques por plataforma) ──────────
#     $1 = bloque if/elseif/endif generado en la sección 4
gen_cmake_cross() {
    local plat_block="$1"

    # Heredoc sin comillas: $MODULE y $plat_block se expanden.
    # Las variables CMake (${CMAKE_CURRENT_SOURCE_DIR}) van escapadas con \.
    cat > "$DEST/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.20)
project($MODULE LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library($MODULE SHARED src/${MODULE}.cpp)

target_include_directories($MODULE
    PUBLIC  \${CMAKE_CURRENT_SOURCE_DIR}/include
    PRIVATE \${CMAKE_CURRENT_SOURCE_DIR}/src
)

${plat_block}

add_executable(${MODULE}_test main.cpp)
target_link_libraries(${MODULE}_test PRIVATE $MODULE)
EOF
}

# ─── conanfile.py ────────────────────────────────────────────────────────────
gen_conanfile() {
    sed "s/__MODULE_NAME__/$MODULE/g" <<'EOF' > "$DEST/conanfile.py"
from conan import ConanFile
from conan.tools.cmake import CMakeToolchain, CMakeDeps, cmake_layout

class __MODULE_NAME__Conan(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeToolchain", "CMakeDeps"

    def requirements(self):
        pass  # añade dependencias: self.requires("openssl/3.2.1")

    def layout(self):
        cmake_layout(self)
EOF
}

# ─── .vscode/tasks.json ──────────────────────────────────────────────────────
gen_tasks_json() {
    sed "s/__MODULE_NAME__/$MODULE/g" <<'EOF' > "$DEST/.vscode/tasks.json"
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "__MODULE_NAME__: conan install",
            "type": "shell",
            "command": "conan install . --build=missing -s build_type=Debug",
            "options": { "cwd": "${workspaceFolder}" },
            "problemMatcher": [],
            "group": "build"
        },
        {
            "label": "__MODULE_NAME__: cmake configure",
            "type": "shell",
            "command": "rm -rf build/CMakeCache.txt build/CMakeFiles && cmake -B build -S . -DCMAKE_TOOLCHAIN_FILE=build/Debug/generators/conan_toolchain.cmake -DCMAKE_PREFIX_PATH=build/Debug/generators -DCMAKE_BUILD_TYPE=Debug -G Ninja",
            "options": { "cwd": "${workspaceFolder}" },
            "dependsOn": "__MODULE_NAME__: conan install",
            "problemMatcher": [],
            "group": "build"
        },
        {
            "label": "__MODULE_NAME__: cmake build",
            "type": "shell",
            "command": "cmake --build build",
            "options": { "cwd": "${workspaceFolder}" },
            "dependsOn": "__MODULE_NAME__: cmake configure",
            "problemMatcher": ["$gcc"],
            "group": { "kind": "build", "isDefault": false }
        },
        {
            "label": "__MODULE_NAME__: cmake build (fast)",
            "type": "shell",
            "command": "cmake --build build",
            "options": { "cwd": "${workspaceFolder}" },
            "problemMatcher": ["$gcc"],
            "group": { "kind": "build", "isDefault": false }
        }
    ]
}
EOF
}

# ─── .vscode/launch.json ─────────────────────────────────────────────────────
#     $1 = nombre del binario (p.ej. "my_module" o "my_module_test" en cross)
gen_launch_json() {
    local binary="$1"
    sed "s/__MODULE_NAME__/$MODULE/g; s/__BINARY__/$binary/g" <<'EOF' > "$DEST/.vscode/launch.json"
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "__MODULE_NAME__: debug (conan+cmake)",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/__BINARY__",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "lldb",
            "preLaunchTask": "__MODULE_NAME__: cmake build"
        },
        {
            "name": "__MODULE_NAME__: debug (fast, sin reconfigurar)",
            "type": "cppdbg",
            "request": "launch",
            "program": "${workspaceFolder}/build/__BINARY__",
            "args": [],
            "stopAtEntry": false,
            "cwd": "${workspaceFolder}",
            "environment": [],
            "externalConsole": false,
            "MIMode": "lldb",
            "preLaunchTask": "__MODULE_NAME__: cmake build (fast)"
        }
    ]
}
EOF
}

# ─── .vscode/c_cpp_properties.json ───────────────────────────────────────────
gen_cpp_properties_json() {
    cat <<'EOF' > "$DEST/.vscode/c_cpp_properties.json"
{
    "version": 4,
    "configurations": [
        {
            "name": "Mac",
            "includePath": [
                "${workspaceFolder}/**",
                "${env:HOME}/.conan2/p/**/include"
            ],
            "defines": [],
            "macFrameworkPath": [
                "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/System/Library/Frameworks"
            ],
            "compilerPath": "/usr/bin/clang++",
            "cStandard": "c17",
            "cppStandard": "c++17",
            "intelliSenseMode": "macos-clang-arm64",
            "compileCommands": "${workspaceFolder}/build/compile_commands.json",
            "configurationProvider": "ms-vscode.cmake-tools"
        }
    ]
}
EOF
}

# ─── .vscode/settings.json  (del módulo) ─────────────────────────────────────
gen_vscode_settings() {
    cat <<'EOF' > "$DEST/.vscode/settings.json"
{
    "cmake.sourceDirectory": "${workspaceFolder}"
}
EOF
}


# ══════════════════════════════════════════════════════════════════════════════
#  SECCIÓN 4 ─ LÓGICA PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════════

# Estructura de carpetas base
mkdir -p "$DEST"/{src,"include/$MODULE",.vscode}
touch "$DEST/src/$MODULE.cpp"
touch "$DEST/include/$MODULE/$MODULE.h"

# Ficheros comunes a ambos modos
gen_main_cpp
gen_conanfile
gen_tasks_json
gen_cpp_properties_json
gen_vscode_settings

# Actualiza settings.json en la raíz del workspace (apunta CMake al módulo activo)
printf '{\n    "cmake.sourceDirectory": "${workspaceFolder}/%s"\n}\n' "$MODULE" \
    > "$SCRIPT_DIR/.vscode/settings.json"

# ─── modo simple ──────────────────────────────────────────────────────────────
if [[ "$TYPE" == "simple" ]]; then

    gen_cmake_simple
    gen_launch_json "$MODULE"

# ─── modo cross ───────────────────────────────────────────────────────────────
elif [[ "$TYPE" == "cross" ]]; then

    IFS=',' read -ra PLAT_LIST <<< "${PLATFORMS:-macos}"

    # Ficheros de implementación por plataforma
    for plat in "${PLAT_LIST[@]}"; do
        mkdir -p "$DEST/src/platform/$plat"
        cat > "$DEST/src/platform/$plat/transport_${plat}.cpp" <<CPPEOF
#include "../../transport/transport.h"

// Implementación del transporte para ${plat}
namespace ${MODULE} {

void platform_init() {
    // TODO: inicialización específica de ${plat}
}

} // namespace ${MODULE}
CPPEOF
    done

    # Interfaz común de transporte
    mkdir -p "$DEST/src/transport"
    cat > "$DEST/src/transport/transport.h" <<HEOF
#pragma once

namespace ${MODULE} {
    void platform_init();
} // namespace ${MODULE}
HEOF

    # Construye el bloque CMake if/elseif/endif para cada plataforma
    plat_block=""
    first=true
    for plat in "${PLAT_LIST[@]}"; do
        case "$plat" in
            macos)   cond="APPLE" ;;
            android) cond="ANDROID" ;;
            ios)     cond="IOS" ;;
            linux)   cond="UNIX AND NOT APPLE AND NOT ANDROID" ;;
            windows) cond="WIN32" ;;
            *)       cond="FALSE" ;;
        esac
        if $first; then
            plat_block+="if(${cond})"$'\n'
            first=false
        else
            plat_block+="elseif(${cond})"$'\n'
        fi
        plat_block+="    message(STATUS \"${MODULE}: backend ${plat}\")"$'\n'
        plat_block+="    target_sources(${MODULE} PRIVATE src/platform/${plat}/transport_${plat}.cpp)"$'\n'
    done
    plat_block+="else()"$'\n'
    plat_block+="    message(FATAL_ERROR \"${MODULE}: plataforma no soportada\")"$'\n'
    plat_block+="endif()"

    gen_cmake_cross "$plat_block"
    gen_launch_json "${MODULE}_test"

else
    echo "Error: --type debe ser 'simple' o 'cross'."
    exit 1
fi


# ══════════════════════════════════════════════════════════════════════════════
#  SECCIÓN 5 ─ RESUMEN
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "  ✓ Módulo '$MODULE' creado en $DEST"
echo ""
if [[ "$TYPE" == "cross" ]]; then
    echo "  Tipo: cross  |  Plataformas: ${PLATFORMS:-macos}"
    echo "  Implementa los TODO en: src/platform/<plat>/transport_<plat>.cpp"
    echo ""
fi
echo "  VSCode  →  Run Task    › '$MODULE: cmake build'"
echo "          →  Run & Debug › '$MODULE: debug (conan+cmake)'"
echo ""
echo "  ¿Olvidaste algo?  ./new_module_c++.sh --guide"
echo ""
