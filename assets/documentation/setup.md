# SETUP TOOL CHAINS

**1. macOS (nativo)**
```bash
xcode-select --install       # Clang + herramientas de compilación
brew install cmake
brew install curl             # normalmente ya está, pero mejor la versión de Homebrew con headers
```

**2. Android (NDK)**
```bash
# Solo para la sesión actual (temporal)
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export PATH=$JAVA_HOME/bin:$PATH
```

```bash
brew install --cask android-commandlinetools
```
Luego, desde `sdkmanager`, instalas el NDK y CMake integrados:
```bash
sdkmanager --install "ndk;26.1.10909125" "cmake;3.22.1" "platform-tools"
```
(la ruta típica del NDK queda en `~/Library/Android/sdk/ndk/<version>`)

**3. ESP32 (Arduino)**
Dos caminos, y te recomiendo **PlatformIO** en vez de Arduino IDE porque usa CMake-like project files y se integra mejor con tu librería C++ pura:
```bash
brew install platformio
```

---

## MAC OS
```sh
% cmake --version
cmake version 4.4.3

CMake suite maintained and supported by Kitware (kitware.com/cmake).

% clang --version
Apple clang version 15.0.0 (clang-1500.3.9.4)
Target: arm64-apple-darwin23.3.0
Thread model: posix
InstalledDir: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
```

---

## Android

# Tabla de valores actuales

## Componentes instalados

| Componente | Versión | Ruta completa | Estado |
|------------|---------|---------------|--------|
| **NDK** | `26.1.10909125` | `/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125` | ✅ Instalado |
| **CMake** | `3.22.1` | `/opt/homebrew/share/android-commandlinetools/cmake/3.22.1` | ✅ Instalado |
| **platform-tools (adb)** | `37.0.1` | `/opt/homebrew/share/android-commandlinetools/platform-tools/adb` | ✅ Instalado |

## SDK roots detectados

| SDK root | Ruta | Contenido | Origen |
|----------|------|-----------|--------|
| **Homebrew SDK** | `/opt/homebrew/share/android-commandlinetools/` | cmake, cmdline-tools, licenses, **ndk**, platform-tools | cask `android-commandlinetools` |
| **Android Studio SDK** | `~/Library/Android/sdk/` | build-tools, emulator, fonts, licenses, platform-tools, platforms, sources, system-images | Android Studio (sin ndk/cmake) |

## Binarios y sus rutas

| Binario | Ruta | Viene de |
|---------|------|----------|
| `sdkmanager` | `/opt/homebrew/bin/sdkmanager` → symlink a `/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin/sdkmanager` | Homebrew cask |
| `adb` | `/opt/homebrew/share/android-commandlinetools/platform-tools/adb` | SDK Homebrew |
| `ndk-build` | `/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/ndk-build` | SDK Homebrew |
| `cmake` (SDK) | `/opt/homebrew/share/android-commandlinetools/cmake/3.22.1/bin/cmake` | SDK Homebrew |

---

# Comandos para identificar ubicación del NDK

## 1. Listar NDKs instalados en cada SDK root

```bash
# SDK de Homebrew
ls /opt/homebrew/share/android-commandlinetools/ndk/

# SDK de Android Studio
ls ~/Library/Android/sdk/ndk/
```

## 2. Ver qué NDK está registrado por `sdkmanager`

```bash
sdkmanager --list_installed | grep -i ndk
```

## 3. Encontrar el NDK en todo el sistema

```bash
# Buscar carpeta "ndk" en rutas típicas
find /opt/homebrew ~/Library -maxdepth 5 -type d -name "ndk" 2>/dev/null

# Buscar una versión concreta
find /opt/homebrew ~/Library -maxdepth 6 -type d -name "26.1.10909125" 2>/dev/null
```

## 4. Encontrar el binario `ndk-build`

```bash
find /opt/homebrew ~/Library -maxdepth 7 -name "ndk-build" -type f 2>/dev/null
```