# netclient — Laboratorio de Compilación Cruzada

Guía de referencia para compilar la librería `netclient` (arquitectura
`Client` → `Transport` intercambiable) en macOS, Android y ESP32, incluyendo
las tres formas de consumir la librería en ESP32 y consideraciones de
compatibilidad para distribución.

---

## 0. Prerrequisitos por plataforma

| Plataforma | Herramientas necesarias |
|---|---|
| macOS | Xcode Command Line Tools (`clang`), CMake |
| Android | Android NDK + CMake (vía `android-commandlinetools` o Android Studio) |
| ESP32 | PlatformIO, framework **Arduino** (no ESP-IDF) |

---

## 1. macOS

### 1.1 Descomprimir el proyecto

```bash
tar -xzvf netclient.tar.gz
```

### 1.2 Estructura del proyecto

```bash
tree .. -I build-android -I build
```

```
..
├── CMakeLists.txt
├── assets
│   └── documentation
│       ├── compilation.md
│       └── setup.md
├── include
│   └── netclient
│       └── client.h
├── main.cpp
└── src
    ├── client.cpp
    ├── platform
    │   ├── android
    │   │   └── transport_android.cpp
    │   ├── esp32
    │   │   └── transport_esp32.cpp
    │   └── macos
    │       └── transport_macos.cpp
    └── transport
        └── transport.h

11 directories, 10 files
```

### 1.3 Archivos y su contenido

| Archivo | Contenido |
|---|---|
| `include/netclient/client.h` | header público de `Client` |
| `src/transport/transport.h` | interfaz abstracta `Transport` |
| `src/client.cpp` | implementación de `Client::get()` |
| `src/platform/macos/transport_macos.cpp` | `MacTransport` → `"HELLO FROM MAC"` |
| `src/platform/android/transport_android.cpp` | `AndroidTransport` → `"HELLO FROM ANDROID"` |
| `src/platform/esp32/transport_esp32.cpp` | `Esp32Transport` → `"HELLO FROM ESP32"` |
| `CMakeLists.txt` | selecciona backend según `APPLE`/`ANDROID` |
| `main.cpp` | programa de prueba |

### 1.4 Compilar y probar

```bash
cd netclient
mkdir build && cd build
cmake ..
cmake --build .
./netclient_test
```

**Salida esperada:**
```
-- netclient: compilando backend MACOS
Respuesta: HELLO FROM MAC
```

---

## 2. Android

### 2.1 Localizar el NDK instalado

```bash
find /opt/homebrew ~/Library -maxdepth 5 -type d -name "ndk" 2>/dev/null
```
```
/opt/homebrew/share/android-commandlinetools/ndk
```

```bash
find /opt/homebrew ~/Library -maxdepth 7 -name "ndk-build" -type f 2>/dev/null
```
```
/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/build/ndk-build
/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/ndk-build
```

### 2.2 Configurar la variable de entorno del NDK

```bash
export ANDROID_NDK=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125
```

### 2.3 Crear un build folder separado (no mezclar con el de macOS)

```bash
cd ~/netclient   # o donde hayas descomprimido el tar.gz
# mkdir build-android && cd build-android
conan install . \
  --profile android_armv8 \
  --output-folder=build-android \
  --build=missing
```

### 2.4 Configurar CMake con el toolchain del NDK

```bash
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24 \
```

### 2.5 Compilar

```bash
cmake --build .
```

Esto genera `libnetclient.so` y `netclient_test`, ambos ARM64 — **no ejecutables
en la terminal de tu Mac**, solo en Android.

#### 2.5.1 Identificar los compilados 

```bash

NDK=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125; 
R=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf; 
B=/Users/kenny/Projects/sample/build-android; 

echo "=== libsample.so ==="; 
$R -d $B/libsample.so | awk '/NEEDED/ {print $NF}'; 
echo ""; echo "=== sample_test ==="; 
$R -d $B/sample_test | awk '/NEEDED/ {print $NF}'

  # === libsample.so ===
  # [libm.so]
  # [libc++_shared.so]
  # [libdl.so]
  # [libc.so]

  # === sample_test ===
  # [libsample.so]
  # [libc.so]
  # [libm.so]
  # [libc++_shared.so]
  # [libdl.so]


  # NDK=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125
  # LIBCXX=$NDK/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so

  # /opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so

  # adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=. ./sample_test"
  # adb push sample_test /data/local/tmp/
  # curl -o /tmp/cacert.pem https://curl.se/ca/cacert.pem
  # adb push /tmp/cacert.pem /data/local/tmp/cacert.pem
```

### 2.6 Probar en un dispositivo físico

**Confirma que tu teléfono está autorizado:**
```bash
adb devices
```

**Empuja el binario al dispositivo:**
```bash
adb push netclient_test /data/local/tmp/
adb push libnetclient.so /data/local/tmp/
adb push /opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/toolchains/llvm/prebuilt/darwin-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so /data/local/tmp/
```

**Dale permisos de ejecución y corre:**
```bash
adb shell chmod +x /data/local/tmp/netclient_test
adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=. ./netclient_test"
```

**Salida esperada:**
```
Respuesta: HELLO FROM ANDROID
```

> `LD_LIBRARY_PATH=.` es necesario porque `netclient_test` está linkeado
> dinámicamente contra `libnetclient.so`, y Android no busca en
> `/data/local/tmp` por defecto para librerías compartidas.

> **Nota:** esta prueba con `adb shell` valida la librería nativa de forma
> aislada, sin necesidad de JNI. JNI solo entra cuando se quiere invocar la
> librería desde una app Java/Kotlin real — es una capa de interoperabilidad
> aparte, no parte de la validación del binario en sí.

---

## 3. ESP32 (framework Arduino, vía PlatformIO)

Hay tres formas de consumir `netclient` en un proyecto ESP32, de menor a mayor
madurez:

- **Forma 1** — copia manual del código fuente (rápida, pero hay que
  sincronizar a mano si cambia la librería).
- **Forma 2** — symlink al código fuente (una sola fuente de verdad, sigue
  requiriendo compilar desde código fuente).
- **Forma 3** — binario precompilado `.a` (protege el código fuente, ideal
  para distribuir a terceros o congelar una versión).

### 3.1 Crear el proyecto PlatformIO

```bash
cd ~/Documents/Projects/C++Projects
mkdir esp32-project
cd esp32-project
pio project init --board esp32dev
```

Esto genera:
```
esp32-project/
├── platformio.ini
├── lib/
├── src/
└── include/
```

### 3.2 Configurar `platformio.ini`

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
build_unflags = -std=gnu++11
build_flags = -std=gnu++17
```

> `build_unflags`/`build_flags` son obligatorios: Arduino-ESP32 compila por
> defecto en `gnu++11`, y `std::make_unique` (usado en `create_transport()`)
> requiere C++14 o superior.

### 3.3 Reemplazar `src/main.cpp`

```cpp
#include <Arduino.h>
#include <netclient/client.h>

void setup() {
    Serial.begin(115200);
    delay(1000); // dar tiempo a que el monitor serial se conecte

    netclient::Client client;
    std::string response = client.get("http://example.com");

    Serial.print("Respuesta: ");
    Serial.println(response.c_str());
}

void loop() {
    // nada por ahora
}
```

---

### Forma 1 — Copia manual del código fuente

Copia los archivos comunes + el transport de ESP32 (no el de macOS ni Android):

```bash
mkdir -p lib/netclient/src/transport
mkdir -p lib/netclient/include/netclient

cp ~/Documents/Projects/C++Projects/netclient/include/netclient/client.h \
   lib/netclient/include/netclient/

cp ~/Documents/Projects/C++Projects/netclient/src/client.cpp \
   lib/netclient/src/

cp ~/Documents/Projects/C++Projects/netclient/src/transport/transport.h \
   lib/netclient/src/transport/

cp ~/Documents/Projects/C++Projects/netclient/src/platform/esp32/transport_esp32.cpp \
   lib/netclient/src/
```

> PlatformIO añade automáticamente `lib/netclient/src` a los include paths.
> Si los includes relativos no enlazan bien, ajusta por ejemplo
> `#include "../../transport/transport.h"` a `#include "./transport/transport.h"`
> según la profundidad real de la copia.

**Localizar el puerto serial de la placa:**
```bash
pio device list
```
```
/dev/cu.usbserial-02CKLZTD   (CP2104 USB to UART Bridge)
```

**Compilar:**
```bash
pio run
```

**Subir el firmware:**
```bash
pio run --target upload --upload-port /dev/cu.usbserial-02CKLZTD
```

**Ver la salida por Serial:**
```bash
pio device monitor --port /dev/cu.usbserial-02CKLZTD --baud 115200
```

**Salida esperada:**
```
Respuesta: HELLO FROM ESP32
```

---

### Forma 2 — Symlink a una sola fuente de verdad

Evita copiar archivos a mano y sincronizarlos manualmente cada vez que cambia
la librería.

**1. Añadir `library.json` en la raíz de `netclient/`:**

```json
{
  "name": "netclient",
  "version": "0.1.0",
  "description": "Cliente HTTP multiplataforma con transporte intercambiable",
  "build": {
    "srcDir": "src",
    "includeDir": "include",
    "srcFilter": [
      "+<*.cpp>",
      "-<platform/macos>",
      "-<platform/android>",
      "+<platform/esp32/*.cpp>"
    ]
  }
}
```

**2. Borrar la copia manual dentro del proyecto PlatformIO:**

```bash
cd ~/Documents/Projects/C++Projects/esp32-project
rm -rf lib/netclient
```

**3. Referenciar la carpeta real en `platformio.ini` con `symlink://`:**

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
build_unflags = -std=gnu++11
build_flags = -std=gnu++17
lib_deps =
    symlink://../netclient
```

(ajusta la ruta relativa `../netclient` según dónde esté una carpeta respecto
a la otra)

**4. Limpiar caché y recompilar:**

```bash
pio run --target clean
pio run
```

PlatformIO crea un **symlink real** dentro de `.pio/libdeps/`, no una copia —
cualquier cambio en `~/netclient/include/netclient/client.h` se refleja
automáticamente en la próxima compilación.

> Verifica en la salida de `pio run` que el `srcFilter` excluye
> correctamente `platform/macos` y `platform/android`, y solo compila
> `platform/esp32/transport_esp32.cpp` junto con `client.cpp`.

---

### Forma 3 — Binario precompilado (`.a`), para proteger el código fuente

Útil cuando se quiere distribuir la librería sin exponer `.cpp`/`transport.h`
internos — solo el header público y el binario.

**1. Compilar el `.a`** (con la Forma 2 ya configurada, para generar el binario):

```bash
pio run --target clean
pio run
```

El `.a` queda en:
```
.pio/build/esp32dev/lib*/libnetclient.a
```

**2. Confirmar que el `.a` contiene los símbolos esperados:**

```bash
nm -C .pio/build/esp32dev/lib*/libnetclient.a | grep Client
```

**3. Empaquetar solo header + binario (sin código fuente):**

```
dist/esp32/
├── include/netclient/client.h   ← API pública
└── lib/libnetclient.a           ← binario, sin .cpp
```

**4. Estructura para consumir el `.a` en otro proyecto:**

```
lib/netclient/
├── library.json
├── libnetclient.a
└── include
    └── netclient
        └── client.h
```

> ⚠️ El header debe ir **anidado** como `include/netclient/client.h` (no
> directo en `lib/netclient/client.h`), para que PlatformIO exponga el path
> tal como se usa en `#include <netclient/client.h>`.

`library.json` (solo metadata):
```json
{
  "name": "netclient",
  "version": "0.1.0"
}
```

**5. El paso que realmente resuelve el link — `-L`/`-l` manuales:**

PlatformIO no detecta automáticamente un `.a` precompilado dentro de `lib/`
para linkearlo; hay que indicárselo al linker explícitamente:

```ini
[env:esp32dev]
platform = espressif32@6.12.0
board = esp32dev
framework = arduino
monitor_speed = 115200
build_unflags = -std=gnu++11
build_flags =
    -std=gnu++17
    -L${PROJECT_DIR}/lib/netclient
    -lnetclient
```

- `platform` con versión fijada (`@6.12.0`) evita que otra versión del
  toolchain rompa el ABI de C++ del `.a`.
- `-std=gnu++17` debe coincidir con el estándar usado al compilar el `.a`.
- `-lnetclient` va **al final** de `build_flags`: los linkers GNU resuelven
  símbolos de izquierda a derecha, y PlatformIO coloca `build_flags` al final
  de la línea de link.

**6. Verificar:**

```bash
pio run --target clean
pio run
pio run --target upload --upload-port /dev/cu.usbserial-XXXX
pio device monitor --port /dev/cu.usbserial-XXXX --baud 115200
```

**Salida esperada:**
```
Respuesta: HELLO FROM ESP32
```

---

## 4. Consideraciones de compatibilidad (troubleshooting)

### Escenario A — Alguien más usa tu librería en su propio proyecto ESP32

Sin control sobre su toolchain, deben **fijar exactamente los mismos
parámetros** usados al compilar el `.a`. Si no coinciden, el resultado no
siempre es un error de compilación claro — puede ser corrupción de memoria
silenciosa.

| Parámetro | Por qué importa | Dónde se fija |
|---|---|---|
| Versión del toolchain Xtensa | El compilador genera código/ABI distinto entre versiones (`toolchain-xtensa-esp32 @ 8.4.0` en este caso) | `platform = espressif32@6.12.0` fijado en `platformio.ini`, nunca flotante |
| Versión del framework Arduino-ESP32 | Cambia el layout de structs internas del core y headers de `HTTPClient`/`WiFi` | Viene empaquetado junto con el `platform` pin |
| Flag `-std=gnu++17` | Si el consumidor compila con `gnu++11` (default), símbolos C++17 no resuelven, o el ABI de STL difiere | Debe copiar el mismo `build_flags`/`build_unflags` |
| RTTI y excepciones | Si el `.a` asume excepciones activas y el consumidor las tiene deshabilitadas, el linker puede fallar o el runtime crashear | Revisar `-fno-exceptions`/`-fno-rtti` en ambos lados |
| Variante de chip (ESP32 / S3 / C3) | Arquitecturas de CPU distintas (Xtensa LX6 vs LX7 vs RISC-V) — binarios incompatibles entre sí | Se necesita un `.a` por variante, claramente etiquetado |

**Checklist a entregar junto con el `.a` y el header:**

1. Fijar la misma versión de `platform` (nunca sin versión).
2. Copiar los mismos `build_flags`/`build_unflags`.
3. Confirmar la variante de chip exacta (un `.a` por variante).
4. Verificar flags de excepciones/RTTI.
5. Probar en un proyecto PlatformIO limpio antes de entregar.

### Escenario B — Integrar la librería en un proyecto ESP32 propio ya iniciado

El proyecto viejo tiene su configuración congelada desde el día que se creó
con `pio project init`; `netclient` fue compilada con otra configuración.
Hay que comparar ambas antes de copiar el `.a`.

**Paso 1 — revisar el `platformio.ini` del proyecto viejo:**

```bash
cd ~/Documents/Projects/mi-proyecto-rfid
cat platformio.ini
```

Si no especifica versión de `espressif32`, quedó fijada a lo que estaba
disponible el día de su creación — puede ser distinta a la actual.

**Paso 2 — descubrir la versión realmente instalada:**

```bash
cd ~/Documents/Projects/mi-proyecto-rfid
pio pkg list
```

Comparar contra la versión usada al compilar `netclient` (ej. `6.12.0` vs
`6.5.0` del proyecto viejo → toolchain y core distintos).

**Paso 3 — revisar si ya tiene flags de C++ definidos:**

```bash
grep -i "std\|build_flags\|build_unflags" platformio.ini
```

Si no aparece nada, compila en el default de esa versión (probablemente
`gnu++11`).

**Paso 4 — decidir entre dos caminos:**

- **Opción 1 — Actualizar el proyecto viejo:**
  ```bash
  cd ~/Documents/Projects/mi-proyecto-rfid
  pio pkg update
  ```
  Luego agregar los mismos flags:
  ```ini
  build_unflags = -std=gnu++11
  build_flags = -std=gnu++17
  ```
  Riesgo: puede introducir cambios del core Arduino-ESP32 que rompan código
  ya existente; requiere volver a probar todo el proyecto.

- **Opción 2 — Recompilar `netclient` contra la versión vieja:**
  ```ini
  platform = espressif32@6.5.0
  ```
  Ventaja: no se toca el proyecto que ya funcionaba. Desventaja: quedan dos
  versiones distintas del `.a` en paralelo.

**Qué pasa si se ignora todo esto y se copia el `.a` sin revisar:**

1. **Falla al compilar** (el escenario bueno): el linker se queja de símbolos
   no encontrados, tipo `undefined reference to std::__cxx11::...`.
2. **Compila y linkea sin error, pero falla en runtime** (el escenario malo):
   diferencias sutiles entre versiones menores de libstdc++ pueden corromper
   memoria o crashear de forma intermitente — el peor tipo de bug, porque no
   apunta directo al problema real.

---

## 5. Checklist rápido general

- [ ] `nm -C libnetclient.a | grep Client` muestra los símbolos esperados
- [ ] Header en `lib/netclient/include/netclient/client.h` (anidado, no directo)
- [ ] `platform` con versión fijada, igual a la usada al compilar el `.a`
- [ ] Mismo `-std=` en ambos lados (librería y proyecto consumidor)
- [ ] `-L${PROJECT_DIR}/lib/netclient -lnetclient` presente y al final de `build_flags`
- [ ] `pio run --target clean` antes de recompilar tras cualquier cambio de `platformio.ini`
- [ ] Un `.a` distinto por variante de chip (ESP32 / S3 / C3)



openssl s_client -connect https://api.github.com | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | base64


openssl s_client -connect api.github.com:443 </dev/null 2>/dev/null | \
    openssl x509 -pubkey -noout | \
    openssl pkey -pubin -outform der | \
    openssl dgst -sha256 -binary | base64