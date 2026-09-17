# WebSocket JNI — Distribución a Android

Documenta el proceso completo para compilar `libsystem_sora_ws` en C++, exponerla mediante JNI y consumirla como librería Android (`.aar`).

---

## Repositorios involucrados

| Repo | Rol |
|---|---|
| `netclient_cross_compilation` | C++ puro: interfaz, implementación lws, compilación cross-platform |
| `ws-mobile-library` (Android) | JNI bridge + wrapper Kotlin + empaquetado `.aar` |

---

## Parte 1 — Compilar `libsystem_sora_ws.so` para Android (ARM64)

### Prerrequisitos

- Conan 2.x instalado
- NDK 26.1.10909125 en `/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125`
- Perfil Conan `android_armv8` configurado en `~/.conan2/profiles/`

```ini
# ~/.conan2/profiles/android_armv8
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
```

### Compilación

```bash
# Desde la raíz de netclient_cross_compilation

# 1. Instalar dependencias para Android
conan install . --build=missing \
  -pr:h=android_armv8 \
  -pr:b=default \
  -s build_type=Debug

# 2. Configurar CMake con el toolchain de Conan
cmake -B build-android -S . \
  -DCMAKE_TOOLCHAIN_FILE=build-android/Debug/generators/conan_toolchain.cmake \
  -DCMAKE_BUILD_TYPE=Debug \
  -G Ninja

# 3. Compilar
cmake --build build-android

# Artefacto generado:
# build-android/libsystem_sora_ws.so
```

### Tamaño de buffer WebSocket

El buffer de envío y recepción está configurado en `src/websocket/lws_websocket_client.h`:

```cpp
static constexpr size_t kWsBufferSize = 65536;  // 64 KB
```

Ajustar este valor si se esperan payloads mayores.

### Recepción de mensajes fragmentados

lws puede entregar un mensaje WebSocket en múltiples callbacks si el payload supera el buffer interno o llega en varios frames TCP. La implementación acumula los fragmentos en `receiveBuffer_` y sólo dispara `onMessage` cuando `lws_is_final_fragment()` retorna `true`:

```cpp
case LWS_CALLBACK_CLIENT_RECEIVE: {
    self->receiveBuffer_.append(static_cast<const char*>(in), len);
    if (lws_is_final_fragment(wsi)) {
        if (cb) cb(self->receiveBuffer_);
        self->receiveBuffer_.clear();
    }
    break;
}
```

---

## Parte 2 — Estructura del repo Android (`ws-mobile-library`)

```
ws-mobile-library/
├── build.gradle.kts
└── src/main/
    ├── AndroidManifest.xml
    ├── cpp/
    │   ├── CMakeLists.txt
    │   ├── include/
    │   │   └── system_sora/
    │   │       └── websocket/
    │   │           ├── i_websocket_client.h
    │   │           └── websocket_client_factory.h
    │   ├── libs/
    │   │   └── arm64-v8a/
    │   │       └── libsystem_sora_ws.so        ← copiada desde netclient_cross_compilation
    │   └── websocket/
    │       └── jni_bridge_ws.cpp
    └── java/com/abexa/ws_mobile_library/websocket/
        ├── ClientWebSocket.kt
        └── WebSocketState.kt
```

---

## Parte 3 — Copiar artefactos al repo Android

Cada vez que se recompile `libsystem_sora_ws.so` en el repo C++:

```bash
# Copiar la .so compilada
cp build-android/libsystem_sora_ws.so \
   /path/to/ws-mobile-library/src/main/cpp/libs/arm64-v8a/libsystem_sora_ws.so

# Copiar los headers públicos (solo si cambiaron)
cp -r include/system_sora \
   /path/to/ws-mobile-library/src/main/cpp/include/system_sora
```

---

## Parte 4 — CMakeLists.txt del bridge JNI

```cmake
cmake_minimum_required(VERSION 3.22)
project(sora_jni)

# Lib precompilada — IMPORTED evita que Gradle la empaquete dos veces
add_library(system_sora_ws SHARED IMPORTED)
set_target_properties(system_sora_ws PROPERTIES
        IMPORTED_LOCATION ${CMAKE_SOURCE_DIR}/libs/${ANDROID_ABI}/libsystem_sora_ws.so)

# Bridge JNI
add_library(sora_jni SHARED websocket/jni_bridge_ws.cpp)

target_include_directories(sora_jni PRIVATE
        ${CMAKE_SOURCE_DIR}/include)

target_link_libraries(sora_jni
        system_sora_ws
        android
        log)
```

> **Importante:** no declarar `jniLibs.srcDirs` en `build.gradle.kts` apuntando a `cpp/libs/`.
> Al usar `IMPORTED`, CMake ya empaqueta la `.so` dentro del `.aar`. Declarar ambos produce el error:
> `2 files found with path 'lib/arm64-v8a/libsystem_sora_ws.so'`

---

## Parte 5 — build.gradle.kts

```kotlin
android {
    defaultConfig {
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
}
```

El NDK utilizado debe coincidir con el de compilación C++. Se declara en `local.properties` del proyecto raíz:

```properties
sdk.dir=/Users/kenny/Library/Android/sdk
ndk.dir=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125
```

---

## Parte 6 — JNI bridge (`jni_bridge_ws.cpp`)

### Patrón de diseño

Cada instancia de `ClientWebSocket` en Kotlin tiene un `nativeHandle: Long` que es un puntero a un `WsContext` en heap:

```cpp
struct WsContext {
    std::unique_ptr<IWebSocketClient> client;
    jobject javaObj;        // GlobalRef al objeto Kotlin
    jmethodID onMessageId;
    jmethodID onStateChangeId;
    jmethodID onErrorId;
};
```

### Callbacks entre hilos (C++ → Kotlin)

El hilo worker de lws no es un hilo Java. Para llamar métodos Kotlin desde él se usa `AttachCurrentThread` / `DetachCurrentThread`:

```cpp
static JavaVM* g_jvm = nullptr;

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
    g_jvm = vm;
    return JNI_VERSION_1_6;
}

static void withEnv(const std::function<void(JNIEnv*)>& fn) {
    JNIEnv* env = nullptr;
    bool attached = false;
    if (g_jvm->GetEnv((void**)&env, JNI_VERSION_1_6) == JNI_EDETACHED) {
        g_jvm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }
    if (env) fn(env);
    if (attached) g_jvm->DetachCurrentThread();
}
```

### Convención de nombres JNI

Los nombres de las funciones C siguen el patrón:
```
Java_<paquete_con_guiones_bajos>_<Clase>_<método>
```

Para el paquete `com.abexa.ws_mobile_library.websocket` y clase `ClientWebSocket`:
```
Java_com_abexa_ws_1mobile_1library_websocket_ClientWebSocket_nativeConnect
```

> Los guiones bajos en el nombre del paquete (`ws_mobile_library`) se escapan como `_1` en el nombre JNI.

---

## Parte 7 — Wrapper Kotlin (`ClientWebSocket.kt`)

```kotlin
class ClientWebSocket(private val listener: Listener) {

    interface Listener {
        fun onMessage(message: String)
        fun onStateChange(state: WebSocketState)
        fun onError(error: String)
    }

    private val nativeHandle: Long = nativeCreate()

    fun connect(url: String) = nativeConnect(nativeHandle, url)
    fun disconnect() = nativeDisconnect(nativeHandle)
    fun send(message: String): Boolean = nativeSend(nativeHandle, message)
    fun setReconnectPolicy(
        initialDelayMs: Int = 500,
        maxDelayMs: Int = 30000,
        backoffMultiplier: Double = 2.0,
        maxAttempts: Int = 10
    ) = nativeSetReconnectPolicy(nativeHandle, initialDelayMs, maxDelayMs, backoffMultiplier, maxAttempts)
    fun state(): WebSocketState = WebSocketState.entries[nativeState(nativeHandle)]
    fun destroy() = nativeDestroy(nativeHandle)

    // Llamados desde C++ en el hilo worker de lws
    private fun onMessageFromNative(message: String) = listener.onMessage(message)
    private fun onStateChangeFromNative(ordinal: Int) = listener.onStateChange(WebSocketState.entries[ordinal])
    private fun onErrorFromNative(error: String) = listener.onError(error)

    companion object {
        init { System.loadLibrary("sora_jni") }
    }
}
```

> Los callbacks (`onMessage`, `onStateChange`, `onError`) se entregan en el hilo C++ de lws, **no en el Main thread**. Si se necesita actualizar UI, usar `runOnUiThread {}` o `Handler(Looper.getMainLooper())`.

---

## Parte 8 — Uso desde una app Android

```kotlin
val ws = ClientWebSocket(object : ClientWebSocket.Listener {
    override fun onMessage(message: String) {
        Log.d("WS", "Mensaje: $message")
    }
    override fun onStateChange(state: WebSocketState) {
        Log.d("WS", "Estado: $state")
    }
    override fun onError(error: String) {
        Log.e("WS", "Error: $error")
    }
})

ws.connect("wss://tu-servidor.com/socket")
ws.send("hola")

// Al terminar:
ws.disconnect()
ws.destroy()
```

---

## Resumen del flujo completo

```
netclient_cross_compilation (C++)
  conan install -pr android_armv8
  cmake + ninja
        ↓
  libsystem_sora_ws.so  +  include/system_sora/
        ↓  cp
ws-mobile-library (Android)
  src/main/cpp/libs/arm64-v8a/libsystem_sora_ws.so
  src/main/cpp/include/system_sora/
        ↓  Android Studio Build
  jni_bridge_ws.cpp  →  libsora_jni.so
        ↓  empaquetado .aar
  ws-mobile-library-debug.aar
        ↓  implementation(...)
  app Android consumer
```
