**No, `libwebsockets` no maneja la reconexión automática de forma "sencilla" con un simple flag**, al menos no en su modo de bajo nivel (lowlevel), que es el que estás usando.

Según la documentación y los issues del proyecto, **la reconexión es responsabilidad de la aplicación** en la API lowlevel.

###  ¿Qué significa esto?

Cuando usas `lws_client_connect_via_info()` y la conexión falla o se cierra, el objeto `wsi` (WebSocket Instance) que representa esa conexión **se destruye**. Si quieres reconectar, tu código debe crear un **nuevo `wsi`** desde cero, con todos los parámetros de conexión de nuevo.

No hay una función mágica como `lws_set_auto_reconnect(wsi, true)`.

### ¿Qué SÍ ofrece `libwebsockets` para ayudarte?

Aunque no haga la reconexión por ti, **sí te da las herramientas para que tú la implementes de forma robusta**:

**1. Política de reintentos (`lws_retry_bo_t`)**

Puedes configurar una estructura `lws_retry_bo_t` que define la política de backoff (retrasos entre reintentos), jitter (aleatoriedad para evitar sincronización masiva de clientes), y la detección de conexiones "muertas" mediante PING/PONG.

```c
static const uint32_t backoff_ms[] = { 1000, 2000, 3000, 4000, 5000 };
static const lws_retry_bo_t retry = {
    .retry_ms_table = backoff_ms,
    .retry_ms_table_count = 5,
    .conceal_count = 5,
    .secs_since_valid_ping = 3,   // PING tras 3s sin actividad
    .secs_since_valid_hangup = 10, // Cuelga si no hay respuesta en 10s
    .jitter_percent = 20,
};
```

Esta estructura **no reconecta sola**, pero se la pasas a `lws_client_connect_via_info` en el campo `.retry_and_idle_policy`, y libwebsockets la usa para **detectar cuándo la conexión está muerta** y **programar el siguiente intento** cuando tú lo pidas.

**2. Función de scheduling (`lws_retry_sul_schedule`)**

Puedes usar `lws_retry_sul_schedule()` para programar el siguiente intento de conexión usando la política de backoff definida, sin tener que calcular los delays manualmente.

### El problema común: reutilizar `context` y `wsi`

Mucha gente intenta llamar a `lws_client_connect_via_info()` **dentro del callback `LWS_CALLBACK_WSI_DESTROY`** (cuando el `wsi` se está destruyendo). Esto **no es seguro** y causa crashes porque el contexto del `wsi` está en proceso de limpieza.

**La forma correcta** es usar un **callback diferido** (como `lws_sul` o `lws_timed_callback_vh_protocol`) para programar la reconexión **después** de que el `wsi` haya sido destruido completamente.

### La alternativa "fácil": Secure Streams

Si no quieres implementar toda la lógica de reconexión tú mismo, `libwebsockets` tiene un **nivel superior llamado Secure Streams**. En este modo, tu app maneja un objeto de "endpoint" que **sobrevive a las conexiones individuales** y **reconecta automáticamente** según las reglas definidas en su configuración JSON.

La contrapartida es que Secure Streams es una API más compleja y con más abstracciones que la lowlevel que estás usando ahora.

### 🎯 Resumen para tu caso

| Aspecto | Respuesta |
|---|---|
| ¿Flag para auto-reconectar? | ❌ No en lowlevel |
| ¿Detección de conexión muerta? | ✅ Sí, con `lws_retry_bo_t` |
| ¿Scheduling de reintentos? | ✅ Sí, con `lws_retry_sul_schedule` |
| ¿Reconexión automática real? | ✅ Solo en **Secure Streams** |
| ¿Tu responsabilidad? | 🔧 Implementar la lógica de reconexión |

Para tu cliente de telemetría, tendrás que desarrollar la validación de reconexión usando `lws_retry_bo_t` + un callback diferido que reintente la conexión. Si quieres, te puedo mostrar cómo se vería esa lógica aplicada a tu código actual.