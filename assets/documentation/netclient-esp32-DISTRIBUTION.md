# netclient — compilar y distribuir el binario `.a` para ESP32

Guía práctica del proceso real que funcionó: compilar `netclient` como librería
precompilada (`.a`) para ESP32 y consumirla en un proyecto PlatformIO sin exponer
el código fuente.

---

## 1. Compilar el `.a`

Con `netclient` referenciado en un proyecto PlatformIO vía `lib_deps = symlink://../netclient`
(código fuente completo, para generar el binario):

```bash
pio run --target clean
pio run
```

El `.a` queda en:
```
.pio/build/esp32dev/lib*/libnetclient.a
```

Confirma que el `.a` no está vacío ni corrupto:
```bash
nm -C .pio/build/esp32dev/lib*/libnetclient.a | grep Client
```
Deberías ver los símbolos de `netclient::Client::Client()` y `::get(...)`.

---

## 2. Empaquetar para distribuir (sin código fuente)

Copia solo el header público + el `.a` a una carpeta limpia:

```
dist/esp32/
├── include/netclient/client.h   ← API pública
└── lib/libnetclient.a           ← binario, sin .cpp
```

**Nunca incluyas** `transport.h`, `client.cpp`, ni las implementaciones internas.

---

## 3. Integrar el `.a` en un proyecto consumidor

Estructura dentro del proyecto PlatformIO que va a usar la librería:

```
lib/netclient/
├── library.json
├── libnetclient.a
└── include
    └── netclient
        └── client.h
```

⚠️ **Detalle clave**: el header debe ir anidado como `include/netclient/client.h`
(no directo en `lib/netclient/client.h`), porque así PlatformIO expone el path
`netclient/client.h` tal como se usa en el `#include <netclient/client.h>`.

`library.json` (solo metadata, sin flags especiales):
```json
{
  "name": "netclient",
  "version": "0.1.0"
}
```

---

## 4. El paso que realmente resuelve el link: `-L` / `-l` manuales

PlatformIO **no detecta automáticamente** un `.a` precompilado dentro de `lib/` —
solo compila código fuente. Sin este paso, el build compila bien pero falla el
link con `undefined reference to netclient::Client::...`.

En `platformio.ini` del proyecto consumidor:

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

Puntos que importan:
- **`platform` con versión fijada** (`@6.12.0`) — evita que otra versión del
  toolchain rompa el ABI de C++ del `.a`.
- **`-std=gnu++17`** debe coincidir con el estándar usado al compilar el `.a`.
- **`-lnetclient` al final** de `build_flags` — los linkers GNU resuelven símbolos
  de izquierda a derecha, y PlatformIO coloca `build_flags` al final de la línea
  de link, así que este orden es el que permite resolver las referencias pendientes.

---

## 5. Verificar

```bash
pio run --target clean
pio run
pio run --target upload --upload-port /dev/cu.usbserial-XXXX
pio device monitor --port /dev/cu.usbserial-XXXX --baud 115200
```

Salida esperada:
```
Respuesta: HELLO FROM ESP32
```

---

## Checklist rápido si vuelve a fallar

- [ ] `nm -C libnetclient.a | grep Client` muestra los símbolos esperados
- [ ] Header en `lib/netclient/include/netclient/client.h` (anidado, no directo)
- [ ] `platform` con versión fijada, igual a la usada al compilar el `.a`
- [ ] Mismo `-std=` en ambos lados
- [ ] `-L${PROJECT_DIR}/lib/netclient -lnetclient` presente y al final de `build_flags`
- [ ] `pio run --target clean` antes de recompilar tras cualquier cambio de `platformio.ini`
