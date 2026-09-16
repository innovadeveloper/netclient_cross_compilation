# CROSS COMPILATION

### MAC OS

Descargar y descomprimir el repositorio 'tar -xzvf netclient.tar.gz'

```bash
% tree .. -I build-android -I build
..
├── CMakeLists.txt
├── assets
│   └── documentation
│       ├── compilation.md
│       └── setup.md
├── include
│   └── netclient
│       └── client.h
├── main.cpp
└── src
    ├── client.cpp
    ├── platform
    │   ├── android
    │   │   └── transport_android.cpp
    │   ├── esp32
    │   │   └── transport_esp32.cpp
    │   └── macos
    │       └── transport_macos.cpp
    └── transport
        └── transport.h

11 directories, 10 files
```

Luego crea cada archivo con el contenido exacto que te mostré arriba (te resumo la lista para que no se te pase ninguno):

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



```bash
tar -xzvf netclient.tar.gz
cd netclient
mkdir build && cd build
cmake ..
cmake --build .
./netclient_test
```

Deberías ver:
```
-- netclient: compilando backend MACOS
Respuesta: HELLO FROM MAC
```


### ANDROID

**0 Busqueda de la ubicación NDK instalada..**

 % find /opt/homebrew ~/Library -maxdepth 5 -type d -name "ndk" 2>/dev/null

   /opt/homebrew/share/android-commandlinetools/ndk

% find /opt/homebrew ~/Library -maxdepth 7 -name "ndk-build" -type f 2>/dev/null
   /opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/build/ndk-build
   /opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125/ndk-build


**1. Configura las variables de entorno para el NDK:**

```bash
export ANDROID_NDK=/opt/homebrew/share/android-commandlinetools/ndk/26.1.10909125
```

**2. Crea un build folder separado para Android** (no mezclar con el build de macOS):

```bash
cd ~/netclient   # o donde hayas descomprimido el tar.gz
mkdir build-android && cd build-android
```

**3. Configura CMake usando el toolchain del NDK:**

```bash
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-24
```

---

**1. Confirma que tu teléfono está autorizado:**
```bash
adb devices
```


**2. Empuja el binario al dispositivo:**
```bash
adb push netclient_test /data/local/tmp/
adb push libnetclient.so /data/local/tmp/
```

**3. Dale permisos de ejecución y corre:**
```bash
adb shell chmod +x /data/local/tmp/netclient_test
adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=. ./netclient_test"
```

```
Respuesta: HELLO FROM ANDROID
```


### (Forma 1) ESP32 Copia de librerías no compilada en proyecto de platformio 

Perfecto. Vamos paso a paso — este es el más distinto de los tres.

**1. Crea el proyecto PlatformIO** (ejecuta esto fuera de la carpeta `netclient`, como proyecto hermano):

```bash
cd ~/Documents/Projects/C++Projects
mkdir esp32-project
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


**3. Integra `netclient` como librería local.** Crea la carpeta y copia los archivos comunes + el transport de ESP32 (no el de macOS ni Android):

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

Nota importante: en `client.cpp`, el `#include "transport/transport.h"` debe seguir resolviendo bien dentro de esta nueva ubicación — PlatformIO añade automáticamente `lib/netclient/src` a los include paths cuando detecta la estructura de librería, así que debería funcionar sin tocar nada. Sin embargo se deberá modificar algunos imports como '#include "../../transport/transport.h"' por '#include "./transport/transport.h"' en caso q no se enlacen bien.

**4. Reemplaza `src/main.cpp`** (el que generó `pio project init`) por esto:

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

```sh
pio project init --board esp32dev
```

---

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
build_unflags = -std=gnu++11
build_flags = -std=gnu++17
```

```
pio device list
     /dev/cu.usbserial-02CKLZTD   (CP2104 USB to UART Bridge)
```


```bash
pio run
```

Si compila limpio esta vez, subimos el firmware con:

```bash
pio run --target upload --upload-port /dev/cu.usbserial-02CKLZTD
```

Y para ver la salida por Serial:

```bash
pio device monitor --port /dev/cu.usbserial-02CKLZTD --baud 115200
```

Corre el `pio run` primero y confírmame que compiló bien antes de pasar al upload.


---

### (Forma 2) ESP32 Distribución de librería no compilada en platformio

Excelente pregunta — y es justo el problema de mantenimiento que quieres resolver antes de que el proyecto crezca. Copiar archivos a mano funciona para probar, pero significa que si cambias `client.h` tienes que acordarte de sincronizarlo en 3 lugares. Vamos a arreglarlo con una sola fuente de verdad.

**La solución: PlatformIO soporta referenciar una carpeta externa sin copiarla**, usando `symlink://` en `lib_deps`. Así el proyecto ESP32 apunta directo a tu `netclient/` original.

**1. Añade un `library.json` en la raíz de `netclient/`** (esto le dice a PlatformIO qué archivos usar y cuáles ignorar):Réplica este archivo en tu `netclient/` real (en tu Mac), en la raíz, junto al `CMakeLists.txt`.

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

**2. Borra la copia manual dentro del proyecto PlatformIO:**

```bash
cd ~/Documents/Projects/C++Projects/esp32-project
rm -rf lib/netclient
```

**3. En `platformio.ini`, agrega `lib_deps` apuntando a la carpeta real con `symlink://`:**

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

(ajusta la ruta relativa `../netclient` según dónde esté una carpeta respecto a la otra — por lo que vimos antes, ambas están bajo `~/Documents/Projects/C++Projects/`, así que `../netclient` debería ser correcto).

**4. Limpia el caché de build viejo y recompila:**

```bash
pio run --target clean
pio run
```

PlatformIO va a crear un **symlink real** dentro de `.pio/libdeps/`, no una copia — así que cualquier cambio que hagas en `~/netclient/include/netclient/client.h` se refleja automáticamente la próxima vez que compiles ESP32, sin volver a copiar nada.

`pio run` —  el `srcFilter` debe estar excluyendo correctamente `platform/macos` y `platform/android`, y solo compilando `platform/esp32/transport_esp32.cpp` junto con `client.cpp`.

---




¿Seguimos ahora sí compilando el `.a` real de `netclient` para ESP32 (manteniendo C++ puro), y de paso documentamos en un `README` estos requisitos de compatibilidad para que no se te olviden más adelante?



### ThroubleShooting esp32



Aquí es donde la teoría se vuelve concreta. Vamos por los dos escenarios.

#### Escenario A: alguien más usa tu librería en su propio proyecto ESP32

Como no vas a controlar su toolchain, necesitas que **fijen exactamente los mismos parámetros que tú usaste al compilar tu `.a`**. Si no coinciden, el resultado no es un error claro de compilación — puede ser corrupción de memoria silenciosa, mucho peor.

Lo que debe coincidir exactamente entre tu build y la del consumidor:

| Parámetro | Por qué importa | Dónde se fija |
|---|---|---|
| **Versión del toolchain Xtensa** | El compilador genera código/ABI ligeramente distinto entre versiones (`toolchain-xtensa-esp32 @ 8.4.0` en tu caso) | `platform = espressif32@6.12.0` fijado en `platformio.ini` (no dejarlo flotante) |
| **Versión del framework Arduino-ESP32** | Cambia el layout de structs internas del core, headers de `HTTPClient`/`WiFi` que tu Transport usa | Mismo `platform` pin, ya que el framework viene empaquetado con él |
| **Flag `-std=gnu++17`** | Si el consumidor compila con `gnu++11` (el default), symbols de tu `.a` que usan features de C++17 no resuelven, o peor, ABI de STL difiere | Debe copiar tu mismo `build_flags`/`build_unflags` |
| **RTTI y excepciones habilitadas/deshabilitadas** | Arduino-ESP32 por defecto trae excepciones deshabilitadas en algunos casos; si tu `.a` se compiló asumiendo excepciones activas y el consumidor las tiene off, el linker puede fallar o el runtime crashear | Revisar `-fno-exceptions` / `-fno-rtti` en ambos lados |
| **Variante de chip (ESP32 vs S3 vs C3)** | Arquitecturas de CPU distintas (Xtensa LX6 vs LX7 vs RISC-V) — binarios completamente incompatibles | Necesitas un `.a` por variante, claramente etiquetado |

**Checklist práctico que le entregarías al consumidor** (además del `.a` y el header):## 


#### Escenario B: tú integras la librería en un proyecto ESP32 tuyo ya iniciado
  

**Escenario B** (tú integras en tu proyecto viejo): el proyecto viejo **ya tiene su propia configuración congelada** desde el día que lo creaste con `pio project init`. Tu librería `netclient` fue compilada con *otra* configuración (la que armamos hoy). Antes de copiar el `.a` adentro, tienes que comparar ambas configuraciones y decidir cuál gana.

**Paso 1: mira qué tiene tu proyecto viejo, literal**

Supongamos que tu proyecto viejo se llama `mi-proyecto-rfid`. Entra ahí y abre su `platformio.ini`:

```bash
cd ~/Documents/Projects/mi-proyecto-rfid
cat platformio.ini
```

Puede que veas algo así (proyecto de hace meses, sin tocar):

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
```

Fíjate: **no dice qué versión de `espressif32`** usa. Eso significa que se instaló la versión más reciente disponible *el día que corriste `pio project init` por primera vez* — que puede ser una versión completamente distinta a la `6.12.0` que quedó registrada en el proyecto donde compilamos `netclient` hoy.

**Paso 2: descubre qué versión tiene realmente instalada ese proyecto viejo**

```bash
cd ~/Documents/Projects/mi-proyecto-rfid
pio pkg list
```

Esto te muestra algo como:
```
espressif32 @ 6.5.0
```

Compáralo contra lo que salió en tu `pio run` de hoy en el proyecto `esp32-project`:
```
PLATFORM: Espressif 32 (6.12.0) > Espressif ESP32 Dev Module
```

**Ya viste la primera discrepancia real:** `6.5.0` vs `6.12.0`. Diferentes versiones de toolchain Xtensa, posiblemente diferente versión del core Arduino-ESP32.

**Paso 3: también revisa si tiene flags de C++ definidos**

```bash
grep -i "std\|build_flags\|build_unflags" platformio.ini
```

Si no sale nada, el proyecto viejo compila en el default de esa versión de plataforma (probablemente `gnu++11`, como nos pasó a nosotros con el error de `make_unique`).

**Paso 4: ahora decides — ¿actualizas el proyecto viejo, o recompilas la librería?**

Aquí hay dos caminos honestos, sin atajo mágico:

**Opción 1 — Actualizar el proyecto viejo para que coincida con `netclient`:**
```bash
cd ~/Documents/Projects/mi-proyecto-rfid
pio pkg update
```
Esto sube `espressif32` a la última versión disponible (probablemente la misma `6.12.0` que ya tenemos). Luego editas su `platformio.ini` para agregar los mismos flags:
```ini
build_unflags = -std=gnu++11
build_flags = -std=gnu++17
```
**Riesgo:** si el proyecto viejo tiene 3 meses de código ya funcionando, actualizar el core de Arduino-ESP32 puede introducir cambios que rompan algo que ya tenías funcionando (deprecaciones, cambios de firma en alguna función del core). Tendrías que volver a probar todo el proyecto, no solo la parte nueva.

**Opción 2 — Recompilar `netclient.a` contra la versión vieja del proyecto:**
En vez de tocar el proyecto viejo, vas a la carpeta de `netclient` y compilas de nuevo, pero fijando la plataforma a la versión vieja:
```ini
platform = espressif32@6.5.0
```
**Ventaja:** no arriesgas romper nada del proyecto que ya funcionaba. **Desventaja:** ahora tienes dos versiones distintas del `.a` dando vueltas (una para cada proyecto), lo cual es justo el tipo de complejidad que quieres evitar a largo plazo.

## ¿Qué pasa si simplemente ignoras todo esto y copias el `.a` sin revisar nada?

Dos posibles resultados, y el segundo es el peligroso:

1. **Falla al compilar** (el bueno): el linker se queja de símbolos no encontrados, tipo `undefined reference to std::__cxx11::...`. Molesto, pero al menos te avisa.
2. **Compila y linkea sin error, pero se comporta mal en runtime** (el malo): si las diferencias son sutiles (misma versión de C++ pero distinta versión menor de libstdc++ interna), el programa puede compilar perfecto y luego corromper memoria o crashear de forma intermitente — el peor tipo de bug, porque no apunta directo al problema real.


