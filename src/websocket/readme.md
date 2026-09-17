Vamos con el análisis completo. Es un archivo denso y bien escrito, así que lo desgloso por **capas**, de fuera hacia dentro.

## 1. Arquitectura general

```
IWebSocketClient (interfaz pura)
       ▲
LwsWebSocketClient (implementación con libwebsockets)
```

El patrón es **interfaz + implementación concreta**. Esto permite:

- **Mockear** en tests sin depender de libwebsockets.
- **Cambiar de backend** (por ejemplo, a Boost.Beast) sin tocar el resto del código.
- **Compilar rápido** los tests (sin compilar lws).

Equivalente Java: `interface WebSocketClient` + `class LwsWebSocketClient implements WebSocketClient`.

La factory:
```cpp
std::unique_ptr<IWebSocketClient> createLwsWebSocketClient() {
    return std::make_unique<LwsWebSocketClient>();
}
```

Devuelve `unique_ptr<IWebSocketClient>` → **dueño único** de la interfaz. Quien lo recibe decide cuándo destruirlo. RAII puro.

## 2. Ciclo de vida del objeto

```cpp
LwsWebSocketClient::LwsWebSocketClient() = default;

LwsWebSocketClient::~LwsWebSocketClient() {
    disconnect();
}
```

- Constructor **por defecto** (`= default`) → no hace nada especial.
- Destructor llama a `disconnect()` → **garantiza** que el hilo worker se une antes de que el objeto muera.

**Esto es crítico**: si el destructor no llamara a `disconnect()`, el `std::thread worker_` moriría sin unirse → **`std::terminate()`** (crash). Es un error clásico.

## 3. `parseUrl` — parsing manual de URL

```cpp
ParsedUrl LwsWebSocketClient::parseUrl(const std::string& url) {
    ParsedUrl result;
    std::string rest;

    if (url.rfind("wss://", 0) == 0) {
        result.use_ssl = true;
        result.port = 443;
        rest = url.substr(6);
    } else if (url.rfind("ws://", 0) == 0) {
        result.use_ssl = false;
        result.port = 80;
        rest = url.substr(5);
    } else {
        throw std::invalid_argument(...);
    }
    // ...
}
```

### Paso 1: detectar esquema
- `rfind("wss://", 0) == 0` → "empieza por `wss://`" (el idioma que ya vimos).
- `url.substr(6)` → quita `wss://` (6 chars).
- `url.substr(5)` → quita `ws://` (5 chars).

### Paso 2: separar host:port de path
```cpp
auto slashPos = rest.find('/');
std::string hostPort = (slashPos == npos) ? rest : rest.substr(0, slashPos);
result.path         = (slashPos == npos) ? "/"    : rest.substr(slashPos);
```
- Primer `/` separa `hostPort` de `path`.
- Sin `/` → todo es `hostPort`, `path = "/"` por defecto.

### Paso 3: separar host de port
```cpp
auto colonPos = hostPort.find(':');
if (colonPos == npos) {
    result.host = hostPort;
} else {
    result.host = hostPort.substr(0, colonPos);
    result.port = std::stoi(hostPort.substr(colonPos + 1));
}
```
- `hostPort = "example.com:8080"` → `host = "example.com"`, `port = 8080`.
- `hostPort = "example.com"` → `host = "example.com"`, `port` queda por defecto (443 o 80).

### Validación
```cpp
if (result.host.empty()) {
    throw std::invalid_argument("URL de WebSocket sin host: " + url);
}
```

### Puntos débiles de este parser

| Problema | Ejemplo | Por qué |
|---|---|---|
| **IPv6** | `ws://[::1]:8080/` | `find(':')` corta en el primer `:`, dentro de `[::1]` |
| **Userinfo** | `ws://user:pass@host/` | No se maneja `@` |
| **`stoi` puede lanzar** | `ws://host:abc/` | `std::stoi` lanza `std::invalid_argument` |
| **Puerto fuera de rango** | `ws://host:99999/` | `stoi` no valida rango, `port` es `int` |
| **Query string** | `ws://host/path?x=1` | No separa query de path |
| **Fragmento** | `ws://host/path#frag` | No separa fragmento |

Para producción, mejor usar una librería de URL (o `std::regex`, o Boost.URL). Pero para un caso simple está bien.

## 4. `connect` — arrancar el worker

```cpp
void LwsWebSocketClient::connect(const std::string& url) {
    disconnect();              // asegura que el hilo previo terminó

    parsed_ = parseUrl(url);
    stopRequested_ = false;
    connectionLost_ = false;
    reconnectAttempts_ = 0;

    setState(ConnectionState::Connecting);
    worker_ = std::thread(&LwsWebSocketClient::runLoop, this);
}
```

Paso a paso:

1. **`disconnect()`** primero → si había una conexión previa, la cierra y **une el hilo**.
2. **Parsear la URL** → si falla, lanza excepción (el hilo no se crea).
3. **Resetear flags** (`stopRequested_ = false`, etc.) → importante antes de arrancar.
4. **`setState(Connecting)`** → notifica al usuario.
5. **Crear el hilo** `worker_` que ejecuta `runLoop` en paralelo.

**Patrón**: `this` como argumento + método `&LwsWebSocketClient::runLoop`. El hilo ejecuta `runLoop()` sobre la instancia.

**Ojo**: `parsed_` se escribe **desde el hilo principal** y se lee **desde el worker**. Si `connect` se llama desde otro hilo o se llama dos veces, hay **data race**. Aquí se asume que `connect` es single-threaded.

## 5. `disconnect` — parar el worker con seguridad

```cpp
void LwsWebSocketClient::disconnect() {
    stopRequested_ = true;

    if (auto* ctx = context_.load()) {
        lws_cancel_service(ctx);
    }

    if (worker_.joinable() && std::this_thread::get_id() != worker_.get_id()) {
        worker_.join();
    }
}
```

Este es **el punto más delicado** de todo el archivo. Vamos por partes.

### `stopRequested_ = true`
Flag atómico que el worker consulta en sus bucles (`while (!stopRequested_)`). Ponerlo a `true` hace que el worker termine **en la siguiente iteración**.

### `lws_cancel_service(ctx)`
**Clave**: si el worker está **bloqueado dentro de `lws_service`**, no verá el flag hasta que `lws_service` retorne. `lws_cancel_service` **despierta** a `lws_service` desde fuera. Es la forma de "sacudirlo".

Sin esto, `disconnect` podría tardar **hasta el timeout de `lws_service`** (que aquí es 0, así que no bloquearía… pero es buena práctica).

### El check del `join`

```cpp
if (worker_.joinable() && std::this_thread::get_id() != worker_.get_id()) {
    worker_.join();
}
```

Dos protecciones:

1. **`worker_.joinable()`** → ¿hay un hilo para unir? Si `connect` nunca se llamó, o ya se unió, `joinable()` es `false`. Llamar a `join()` sin `joinable()` es **UB**.

2. **`std::this_thread::get_id() != worker_.get_id()`** → **evitar auto-join**. Si `disconnect()` se llama **desde el propio worker** (por ejemplo, desde un callback que decide parar), hacer `join()` sobre sí mismo → **deadlock**.

   Esta protección es **crítica**. Sin ella, si tu callback `onStateChange` llama a `disconnect()`, el programa se bloquea para siempre.

### ¿Por qué no se une si viene del worker?

Si el worker se une a sí mismo → deadlock. Pero entonces, ¿cómo se limpia el hilo? **No se limpia**. El `std::thread` queda `joinable()` pero no unido. Cuando el `LwsWebSocketClient` se destruya, el **destructor de `std::thread`** llamará a `std::terminate()` si sigue `joinable()`.

**Esto es un bug latente** si `disconnect` se llama desde el worker. La solución correcta sería:

```cpp
if (worker_.joinable()) {
    if (std::this_thread::get_id() == worker_.get_id()) {
        worker_.detach();   // ← dejar el hilo "suelto" (peligroso pero no crashea)
    } else {
        worker_.join();
    }
}
```

O rediseñar para que `disconnect` **nunca** se llame desde el worker (usar `std::async` o similar).

## 6. `send` — encolar un mensaje

```cpp
bool LwsWebSocketClient::send(const std::string& message) {
    if (state_.load() != ConnectionState::Connected) {
        return false;
    }
    {
        std::lock_guard<std::mutex> lock(sendMutex_);
        sendQueue_.push_back(message);
    }
    if (auto* wsi = wsi_.load()) {
        lws_callback_on_writable(wsi);
    }
    return true;
}
```

### Flujo

1. **Solo envía si `Connected`**. Si no, `return false`.
2. **Añade a `sendQueue_`** protegido por mutex.
3. **Le dice a libwebsockets**: "cuando puedas escribir, avísame" → `lws_callback_on_writable`.

El **worker** está en `lws_service(ctx, 0)`. Cuando lws detecta que el socket es escribible, dispara `LWS_CALLBACK_CLIENT_WRITEABLE` → el trampolín → saca de `sendQueue_` y hace `lws_write`.

### Por qué la cola

libwebsockets **no es thread-safe** para escribir desde otro hilo. La estrategia estándar:

- **Otros hilos** → meten mensajes en `sendQueue_` (con mutex).
- **Worker (lws thread)** → saca de `sendQueue_` y escribe con `lws_write`.

Así **solo el worker toca libwebsockets**, y la sincronización es vía mutex + cola.

### `lws_callback_on_writable`

Sin esto, libwebsockets **no** dispararía `WRITEABLE` hasta que tuviera algo que escribir. Es la forma de decirle: "tengo datos pendientes, despiértate para escribir".

### Race condition sutil

Entre `state_.load() != Connected` y el `push_back`, el estado podría cambiar a `Disconnected`. El mensaje quedaría encolado pero nunca se enviaría. En el peor caso, se pierde al limpiar la cola en `runLoop`:

```cpp
{
    std::lock_guard<std::mutex> lock(sendMutex_);
    sendQueue_.clear();
}
```

Es un **diseño "best effort"**: aceptable para un cliente que reconecta, pero no garantiza entrega.

## 7. Los setters de callbacks

```cpp
void LwsWebSocketClient::setOnMessage(MessageCallback callback) {
    std::lock_guard<std::mutex> lock(callbackMutex_);
    onMessage_ = std::move(callback);
}
```

- **`std::move`** → transfiere el callback (patrón sink argument que ya vimos).
- **`callbackMutex_`** → protege `onMessage_` porque se lee desde el worker y se escribe desde el hilo principal.

Mismo patrón para `setOnStateChange`, `setOnError`.

### `setState` y `notifyError` — invocación segura

```cpp
void LwsWebSocketClient::setState(ConnectionState newState) {
    state_ = newState;
    StateCallback cb;
    {
        std::lock_guard<std::mutex> lock(callbackMutex_);
        cb = onStateChange_;      // ← copia el callback
    }
    if (cb) cb(newState);          // ← lo invoca FUERA del lock
}
```

**Patrón importante**: copiar el callback **dentro del lock**, invocarlo **fuera**.

¿Por qué? Si invocas **dentro** del lock:

- El callback podría llamar a `setOnStateChange` → **deadlock** (intenta coger el mismo mutex).
- El callback podría llamar a `disconnect` → **deadlock** con otros mutex.

**Regla general**: nunca invoques código ajeno con un lock cogido. Copia lo que necesites, suelta el lock, invoca.

## 8. `nextBackoffMs` — backoff exponencial

```cpp
uint32_t LwsWebSocketClient::nextBackoffMs() {
    ReconnectPolicy policy = currentPolicy();
    double delay = policy.initial_delay_ms *
                   std::pow(policy.backoff_multiplier, reconnectAttempts_ - 1);
    delay = std::min<double>(delay, static_cast<double>(policy.max_delay_ms));
    return static_cast<uint32_t>(delay);
}
```

- **`initial_delay_ms * multiplier^(attempts-1)`** → crecimiento exponencial.
- **`min(delay, max_delay_ms)`** → tope superior.
- Ejemplo: `initial=500`, `multiplier=2`, `max=30000` → 500, 1000, 2000, 4000, 8000, 16000, 30000, 30000…
- El `-1` es porque `reconnectAttempts_` ya se incrementó **antes** de llamar.

### Detalle: `std::pow` devuelve `double`

Por eso hay que castear. Para exponentes enteros pequeños, podría usarse un bucle con multiplicación, pero `pow` es más claro.

## 9. `scheduleReconnectOrFail` — decidir si reconectar

```cpp
bool LwsWebSocketClient::scheduleReconnectOrFail() {
    ReconnectPolicy policy = currentPolicy();
    ++reconnectAttempts_;

    if (policy.max_attempts >= 0 && reconnectAttempts_ > policy.max_attempts) {
        setState(ConnectionState::Failed);
        notifyError("Se agotaron los intentos de reconexion (" + ... + ")");
        return false;
    }

    setState(ConnectionState::Reconnecting);
    uint32_t delay = nextBackoffMs();
    const uint32_t step = 100;
    for (uint32_t waited = 0; waited < delay && !stopRequested_; waited += step) {
        std::this_thread::sleep_for(std::chrono::milliseconds(std::min(step, delay - waited)));
    }
    return !stopRequested_;
}
```

### Detalle clave: sleep **interrumpible**

En lugar de:
```cpp
std::this_thread::sleep_for(std::chrono::milliseconds(delay));  // ❌ bloquea hasta delay
```

Hace:
```cpp
for (uint32_t waited = 0; waited < delay && !stopRequested_; waited += step) {
    sleep_for(min(step, delay - waited));
}
```

**¿Por qué?** Porque si `disconnect()` pone `stopRequested_ = true` durante el sleep, quieres que el worker **salga rápido**, no que espere los 30 segundos completos.

Con el bucle de 100 ms, el worker comprueba el flag cada 100 ms → respuesta rápida a `disconnect`.

**Es la misma técnica que `lws_cancel_service`** pero para el backoff.

## 10. `lwsCallbackTrampoline` — el callback

```cpp
int LwsWebSocketClient::lwsCallbackTrampoline(struct lws* wsi, enum lws_callback_reasons reason,
                                               void* user, void* in, size_t len) {
    auto* ctx = wsi ? lws_get_context(wsi) : nullptr;
    auto* self = ctx ? static_cast<LwsWebSocketClient*>(lws_context_user(ctx)) : nullptr;
    if (!self) return 0;

    auto* pss = static_cast<PerSessionData*>(user);

    switch (reason) {
        case LWS_CALLBACK_CLIENT_ESTABLISHED:
            self->reconnectAttempts_ = 0;   // ← reset al conectar
            self->setState(ConnectionState::Connected);
            break;
        // ...
    }
}
```

### El "trampolín"

- `lws_get_context(wsi)` → obtiene el `ctx`.
- `lws_context_user(ctx)` → obtiene el `void* user` que pasaste al crear el contexto → **`this`**.
- `static_cast<LwsWebSocketClient*>` → recupera la instancia.

**Nota**: aunque el método está declarado **miembro** de la clase (no `static`), libwebsockets lo trata como un puntero a función C. Esto **funciona** en la práctica porque:

- Los métodos no virtuales no usan `this` implícito si no tocan miembros → pero aquí **sí** tocan miembros.
- La dirección de un método miembro no es simplemente un puntero a función en C++ estándar, pero muchas implementaciones lo permiten.
- **Formalmente es UB**, pero funciona en GCC/Clang con este ABI.

La forma **correcta** sería declarar la función como **`static`** (sin `this`) y recuperar `self` con `lws_context_user`. Pero funciona así en la práctica.

### Manejo de `ESTABLISHED`

```cpp
case LWS_CALLBACK_CLIENT_ESTABLISHED:
    self->reconnectAttempts_ = 0;    // ← resetea contador
    self->setState(ConnectionState::Connected);
    break;
```

`reconnectAttempts_ = 0` → si la conexión se establece, resetea el backoff. Si se cae luego, vuelve a empezar desde `initial_delay_ms`.

### Manejo de `WRITEABLE`

```cpp
case LWS_CALLBACK_CLIENT_WRITEABLE: {
    std::string msg;
    {
        std::lock_guard<std::mutex> lock(self->sendMutex_);
        if (self->sendQueue_.empty()) break;
        msg = self->sendQueue_.front();   // ← copia el mensaje
    }

    const size_t capacity = sizeof(pss->send_buffer) - LWS_PRE;
    if (msg.size() > capacity) {
        self->notifyError("Mensaje demasiado grande...");
        std::lock_guard<std::mutex> lock(self->sendMutex_);
        self->sendQueue_.pop_front();
        break;
    }

    std::memcpy(pss->send_buffer + LWS_PRE, msg.data(), msg.size());
    int sent = lws_write(wsi, reinterpret_cast<unsigned char*>(pss->send_buffer) + LWS_PRE,
                          msg.size(), LWS_WRITE_TEXT);

    {
        std::lock_guard<std::mutex> lock(self->sendMutex_);
        if (!self->sendQueue_.empty()) self->sendQueue_.pop_front();
        if (!self->sendQueue_.empty()) lws_callback_on_writable(wsi);  // ← siguiente
    }

    if (sent < static_cast<int>(msg.size())) {
        self->notifyError("Fallo al escribir...");
        return -1;    // ← cierra la conexión
    }
    break;
}
```

Paso a paso:

1. **Copia el mensaje** fuera del lock (para no tenerlo cogido durante `lws_write`).
2. **Comprueba tamaño** contra `capacity = sizeof(send_buffer) - LWS_PRE`.
3. **Copia a `pss->send_buffer` con offset `LWS_PRE`**.
4. **`lws_write`** → escribe.
5. **`pop_front`** y si quedan más → `lws_callback_on_writable` para el siguiente.
6. **Comprueba si escribió todo** → si no, `return -1` (lws cierra).

### `LWS_PRE` — el detalle que confunde

`LWS_PRE` son bytes que libwebsockets necesita **antes** del payload para cabeceras internas. Por eso:

- El buffer tiene `sizeof(send_buffer)`.
- El payload va en `send_buffer + LWS_PRE`.
- El espacio útil es `sizeof(send_buffer) - LWS_PRE`.

Es como si reservaras "cabecera" antes del payload.

### Race condition sutil en `pop_front`

```cpp
{
    std::lock_guard<std::mutex> lock(self->sendMutex_);
    if (!self->sendQueue_.empty()) self->sendQueue_.pop_front();
}
```

Aquí se hace `pop_front` **después** del `lws_write`. El problema: si otro hilo llamó a `send` **entre** el `front()` y este `pop_front`, el mensaje nuevo se encola al final. El `pop_front` quita el **primero** (el que enviamos). Correcto.

Pero si otro hilo hizo `send` **y** se llamó a `lws_callback_on_writable` desde ahí, podría haber **doble notificación** → doble `WRITEABLE`. El siguiente `WRITEABLE` vería la cola vacía y saldría (`if (empty()) break`). Correcto pero ligeramente ineficiente.

### Manejo de `RECEIVE`

```cpp
case LWS_CALLBACK_CLIENT_RECEIVE: {
    std::string message(static_cast<const char*>(in), len);
    MessageCallback cb;
    {
        std::lock_guard<std::mutex> lock(self->callbackMutex_);
        cb = self->onMessage_;     // ← copia
    }
    if (cb) cb(message);            // ← invoca fuera del lock
    break;
}
```

- **Construye un `std::string`** desde `in` + `len`.
- **Copia el callback** fuera del lock.
- **Invoca**.

**Limitación**: si el frame es muy grande, llega **fragmentado**. Cada fragmento dispara un `RECEIVE`. El código **no reensambla** → podrías recibir mensajes partidos. Para WebSocket con frames pequeños (típico), no importa. Para frames grandes (>4096), sí.

### Manejo de `CLOSED` y `CONNECTION_ERROR`

```cpp
case LWS_CALLBACK_CLIENT_CLOSED:
    self->connectionLost_ = true;
    break;

case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
    std::string detail = in ? std::string(static_cast<const char*>(in), len) : "desconocido";
    self->notifyError("Error de conexion: " + detail);
    self->connectionLost_ = true;
    break;
```

- `CLOSED` → cierre normal → marca `connectionLost_`.
- `CONNECTION_ERROR` → error → notifica + marca.
- El `while` interno de `runLoop` ve `connectionLost_ = true` → sale → el externo reconecta.

## 11. `runLoop` — el corazón

Ya lo analizamos antes, pero repasemos con el contexto completo.

### Creación del contexto

```cpp
protocols_[0] = {"sample-ws-protocol", &LwsWebSocketClient::lwsCallbackTrampoline,
                  sizeof(PerSessionData), 4096, 0, nullptr, 0};
protocols_[1] = {nullptr, nullptr, 0, 0, 0, nullptr, 0};

struct lws_context_creation_info info;
std::memset(&info, 0, sizeof(info));
info.port = CONTEXT_PORT_NO_LISTEN;
info.protocols = protocols_;
info.gid = -1;
info.uid = -1;
info.user = this;    // ← el "pegamento"
```

- `protocols_` → array de protocolos (nombre, callback, tamaño por sesión, buffer).
- `protocols_[1]` → terminador (todo ceros).
- `info.user = this` → **crítico** para que el trampolín recupere la instancia.
- `CONTEXT_PORT_NO_LISTEN` → modo cliente (no servidor).
- `LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT` → inicializa SSL si `wss://`.

### El bucle externo (reconexión)

```cpp
while (!stopRequested_) {
    setState(ConnectionState::Connecting);
    connectionLost_ = false;

    // ... crear conexión ...

    while (!stopRequested_ && wsi_.load() && !connectionLost_) {
        lws_service(ctx, 0);
    }

    wsi_ = nullptr;
    { std::lock_guard<std::mutex> lock(sendMutex_); sendQueue_.clear(); }

    if (stopRequested_) break;
    if (!scheduleReconnectOrFail()) break;
}

lws_context_destroy(ctx);
context_ = nullptr;

if (state_.load() != ConnectionState::Failed) {
    setState(ConnectionState::Disconnected);
}
```

- `lws_service(ctx, 0)` → **el event loop real**.
- Timeout `0` → no bloquea → CPU alta si no hay eventos.
- Al salir del loop interno: limpia `wsi_`, limpia cola, decide reconectar o parar.
- Al salir del loop externo: destruye el contexto y pone estado `Disconnected` (salvo si `Failed`).

### Por qué el timeout `0`

- **Necesita reaccionar a `stopRequested_` rápido** → no puede bloquear.
- **Necesita reaccionar a `connectionLost_` rápido** → igual.
- **Necesita procesar `sendQueue_` cuando otro hilo hace `send`** → `lws_callback_on_writable` despierta lws.

**El problema**: `lws_service(ctx, 0)` en bucle **gira a 100% CPU** si no hay eventos. La solución correcta sería usar `lws_cancel_service(ctx)` desde otros hilos y un timeout mayor. Aquí se optó por `0` para simplicidad.

## 12. El patrón "trampolín" — resumen

```
[C++ object]  ←  this  ←  info.user  ←  guardado en lws_context
                                          │
                                          ▼
                              lws_context_user(ctx)  →  this
                                          │
                                          ▼
                     static_cast<LwsWebSocketClient*>(this)
                                          │
                                          ▼
                                self->setState(...)   ← método de instancia
```

Es el **puente** entre el callback C y tu objeto C++. Sin esto, no podrías acceder a miembros desde el callback.

## 13. Comparación con Java

| Concepto | Java | C++ (este código) |
|---|---|---|
| Interfaz | `interface WebSocketClient` | `IWebSocketClient` |
| Implementación | `class LwsWebSocketClient implements ...` | `class LwsWebSocketClient : public ...` |
| Factory | `WebSocketClientFactory.create()` | `createLwsWebSocketClient()` |
| Contexto global | `ExecutorService` / `Selector` | `lws_context*` |
| Conexión | `SocketChannel` | `lws*` (wsi) |
| Event loop | `selector.select()` en loop | `lws_service(ctx, 0)` en loop |
| Eventos | `ChannelHandler` / `SelectionKey` | `lws_callback_reasons` |
| Callbacks | `Consumer<String>` | `std::function<void(const std::string&)>` |
| Threading | `new Thread(runnable)` | `std::thread(&Clase::metodo, this)` |
| Sincronización | `synchronized` / `ReentrantLock` | `std::mutex` + `std::lock_guard` |
| Cerrar | `executor.shutdown()` | `stopRequested_ = true` + `join()` |
| Smart pointer | GC | `unique_ptr`, `shared_ptr` |
| RAII | `try-with-resources` | `lock_guard`, `unique_ptr`, destructores |

## 14. Bugs y mejoras potenciales

### Bugs latentes

1. **`disconnect` desde el worker** → si un callback llama a `disconnect`, el `join` se salta (por el check del thread id), pero el `std::thread` queda `joinable()` → **destructor de `std::thread` llama a `std::terminate()`**. Hay que hacer `detach()` en ese caso, o rediseñar.

2. **`stoi` puede lanzar** en `parseUrl` → si el puerto no es numérico, excepción no capturada.

3. **IPv6 no soportado** → `[::1]:8080` se parsea mal.

4. **Frames grandes partidos** → `RECEIVE` no reensambla fragmentos.

5. **Timeout 0** → CPU alta si el loop está inactivo.

6. **`wsi_ = wsi` en `runLoop` y `wsi_ = nullptr` al salir** → hay una ventana donde `send()` podría ver `wsi_` válido pero el socket está cerrándose. No es crítico (el `send` fallará), pero es mejorable.

7. **No hay `lws_cancel_service` en `connect`** → si el worker está dormido en backoff y se llama a `connect` de nuevo, el worker tarda en reaccionar.

### Mejoras

1. **`std::condition_variable`** en lugar del bucle de 100 ms → más eficiente y reactivo.
2. **Parseo de URL robusto** → `std::regex` o Boost.URL.
3. **Reensamblado de frames** → usar `lws_is_final_fragment()`.
4. **Timeout no-cero en `lws_service`** + `lws_cancel_service` desde otros hilos.
5. **`std::atomic<bool>` explícito** para `connectionLost_` si no lo es ya.
6. **Logger** en lugar de `notifyError` para diagnóstico.
7. **`static` en el trampolín** (formalmente correcto).

## 15. Resumen final

| Aspecto | Detalle |
|---|---|
| **Arquitectura** | Interfaz + implementación + factory |
| **Threading** | Worker thread + `atomic` flags + `mutex` para cola y callbacks |
| **RAII** | Destructor llama a `disconnect()`, `lock_guard`, `unique_ptr` |
| **Event loop** | `lws_service(ctx, 0)` en bucle + reconexión externa |
| **Trampolín** | `info.user = this` + `lws_context_user` para recuperar la instancia |
| **Backoff** | Exponencial con tope, sleep interrumpible cada 100 ms |
| **Thread-safety** | `atomic` para flags, `mutex` para cola y callbacks |
| **Callbacks** | Copiar dentro del lock, invocar fuera |
| **Comunicación worker↔otros** | `sendQueue_` + `lws_callback_on_writable` |
| **Cancelación** | `stopRequested_` + `lws_cancel_service` |
| **Puente C↔C++** | `info.user`, `lws_context_user`, `static_cast` |
| **Puntos débiles** | IPv6, frames grandes, `stoi`, timeout 0, `disconnect` desde worker |

**Frase para recordar:**
> Este archivo es **el patrón canónico** de cómo envolver una librería C de red en C++ moderno:
> - **Interfaz** para desacoplar.
> - **Worker thread** con event loop.
> - **Callbacks seguros** con copia fuera del lock.
> - **Trampolín** para conectar el callback C con la instancia C++.
> - **RAII** para todo (destructor, mutex, smart pointers).
> - **Cola + `lws_callback_on_writable`** para enviar desde otros hilos.
>
> Una vez entiendes este patrón, entenderás cualquier cliente de red C envuelto en C++ (MQTT, HTTP, TCP, etc.).