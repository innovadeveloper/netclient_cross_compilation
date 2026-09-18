// Demo educativo: 3 estrategias de "event loop" y su costo de CPU.
//
//   1) busy loop   -> gira sin parar comprobando condiciones. Máximo consumo de CPU.
//   2) sleep loop  -> hace polling pero duerme un poco en cada vuelta. Consumo bajo/medio.
//   3) cv loop     -> duerme en std::condition_variable::wait y solo despierta cuando
//                     alguien le notifica un evento real. Consumo ~0% en reposo.
//
// Corren en FASES SECUENCIALES (una a la vez), no simultáneas: primero solo el
// busy loop, luego solo el sleep loop, luego solo el cv loop (+ su productor de
// eventos). Así, mientras cada fase corre, el %CPU que reportan `top`/`ps` para
// el PROCESO COMPLETO ya te dice el costo de ESE loop en particular, sin
// necesitar ninguna vista "por hilo" (el `top` de macOS moderno, a diferencia
// del BSD top clásico, NO tiene el comando interactivo `H` para eso).
//
// Uso:
//   ./event_loop_demo [seg_busy] [seg_sleep] [seg_cv]
//   (por defecto 25s cada fase; sube el número para tener más tiempo de sobra)
//
// Cómo observar el consumo de CPU en macOS mientras corre (elige una o combina):
//
//   A) Snapshot puntual del proceso:
//        ps -o pid,%cpu,%mem,time,comm -p <PID>
//
//   B) Log continuo NO interactivo (no depende de teclas, se puede redirigir a
//      un archivo o ver directo en consola porque top lo va imprimiendo solo):
//        top -pid <PID> -l 0 -s 2 -stats pid,command,cpu,time
//        # -l 0   -> modo logging infinito (no espera teclas)
//        # -s 2   -> refresca cada 2s
//        # Para guardarlo y además verlo en vivo:
//        top -pid <PID> -l 0 -s 2 -stats pid,command,cpu,time | tee /tmp/cpu_log.txt
//
//   C) Costo POR HILO (con nombre, gracias a pthread_setname_np): como `top` no
//      desglosa por hilo en macOS moderno, usa `sample`, que sí lo hace y es
//      100% consola:
//        sample <PID> 5 -file /tmp/evloop_sample.txt
//        grep -A1 "Thread_.*evloop" /tmp/evloop_sample.txt
//      El número de muestras junto al nombre del hilo es proporcional al tiempo
//      que ese hilo estuvo activo en ese intervalo (p.ej. "1732 Thread_xxx:
//      evloop-busy" ejecutando busyLoopWorker == estuvo el 100% del muestreo
//      corriendo; "evloop-cv" bloqueado en __psynch_cvwait == 0% de CPU real).
//
//   D) Vista gráfica por hilo (la más clara si tienes Xcode): Instruments >
//      plantilla "Time Profiler", apuntando al PID.
//
// El programa además imprime un "latido" cada 2s con el contador de
// iteraciones de la fase activa, para que veas en la MISMA consola que el
// trabajo avanza sin necesitar una segunda terminal.

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstdlib>
#include <ctime>
#include <iostream>
#include <mutex>
#include <queue>
#include <thread>
#include <unistd.h>

#if defined(__APPLE__)
#include <pthread.h>
#endif

namespace {

// En macOS, pthread_setname_np solo puede nombrar el hilo que la invoca (sin
// pasar pthread_t). En Linux sí acepta (pthread_t, nombre) y con límite de 16
// bytes incluyendo el '\0'.
void nombrarHiloActual(const char* nombre) {
#if defined(__APPLE__)
    pthread_setname_np(nombre);
#elif defined(__linux__)
    pthread_setname_np(pthread_self(), nombre);
#else
    (void)nombre;
#endif
}

std::string horaActual() {
    std::time_t t = std::time(nullptr);
    char buf[16];
    std::strftime(buf, sizeof(buf), "%H:%M:%S", std::localtime(&t));
    return std::string(buf);
}

// --- 1) Busy loop -------------------------------------------------------
// No cede la CPU jamás mientras `running` sea true: satura un core al 100%.
void busyLoopWorker(std::atomic<bool>& running, std::atomic<std::uint64_t>& iteraciones) {
    nombrarHiloActual("evloop-busy");
    while (running.load(std::memory_order_relaxed)) {
        iteraciones.fetch_add(1, std::memory_order_relaxed);
        // "Trabajo" simulado: nada. Un busy loop real spinea sobre un flag/cola
        // lock-free esperando el próximo dato a procesar.
    }
}

// --- 2) Sleep loop --------------------------------------------------------
// Hace polling, pero cede la CPU en cada vuelta. Baja el consumo a costa de
// introducir hasta `intervalo` de latencia antes de notar un cambio.
void sleepLoopWorker(std::atomic<bool>& running, std::atomic<std::uint64_t>& iteraciones,
                      std::chrono::milliseconds intervalo) {
    nombrarHiloActual("evloop-sleep");
    while (running.load(std::memory_order_relaxed)) {
        iteraciones.fetch_add(1, std::memory_order_relaxed);
        // Aquí iría el "chequeo" (revisar una cola, un socket no bloqueante, etc).
        std::this_thread::sleep_for(intervalo);
    }
}

// --- 3) Event-driven loop con std::condition_variable ---------------------
// No hace polling: el hilo queda bloqueado (0% CPU) hasta que otro hilo mete un
// evento en la cola y llama notify_one/notify_all. Es el patrón real detrás de
// la mayoría de los event loops "de verdad" (libuv, epoll+wrapper, etc), salvo
// que aquí la "fuente de eventos" es software (la cv) y no el kernel.
void cvLoopWorker(std::mutex& mutex, std::condition_variable& cv, std::queue<int>& eventos,
                   std::atomic<bool>& running, std::atomic<std::uint64_t>& eventosProcesados) {
    nombrarHiloActual("evloop-cv");
    while (true) {
        std::unique_lock<std::mutex> lock(mutex);
        cv.wait(lock, [&] { return !eventos.empty() || !running.load(); });

        if (!running.load() && eventos.empty()) {
            break;  // nos pidieron parar y no queda nada pendiente por procesar
        }

        while (!eventos.empty()) {
            eventos.pop();
            eventosProcesados.fetch_add(1, std::memory_order_relaxed);
        }
    }
}

// Imprime un latido cada 2s durante `duracion`, mostrando el contador que se
// le pase. Corre en el hilo principal (no crea hilos extra) para no ensuciar
// la medición de CPU de la fase.
void esperarConLatido(std::chrono::seconds duracion, const char* etiqueta,
                       std::atomic<std::uint64_t>& contador) {
    auto inicio = std::chrono::steady_clock::now();
    auto fin = inicio + duracion;
    while (std::chrono::steady_clock::now() < fin) {
        std::this_thread::sleep_for(std::chrono::seconds(2));
        auto transcurrido = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::steady_clock::now() - inicio).count();
        std::cout << "  [" << horaActual() << "] " << etiqueta << " activo hace " << transcurrido
                  << "s -> contador=" << contador.load() << "\n";
    }
}

}  // namespace

int main(int argc, char** argv) {
    int segBusy = 25;
    int segSleep = 25;
    int segCv = 25;
    if (argc > 1) segBusy = std::atoi(argv[1]);
    if (argc > 2) segSleep = std::atoi(argv[2]);
    if (argc > 3) segCv = std::atoi(argv[3]);
    if (segBusy <= 0) segBusy = 25;
    if (segSleep <= 0) segSleep = 25;
    if (segCv <= 0) segCv = 25;

    const pid_t pid = getpid();

    std::cout << "=== Demo: busy loop vs sleep loop vs condition_variable loop ===\n";
    std::cout << "PID de este proceso: " << pid << "\n";
    std::cout << "Fase 1 (busy):  " << segBusy << "s\n";
    std::cout << "Fase 2 (sleep): " << segSleep << "s\n";
    std::cout << "Fase 3 (cv):    " << segCv << "s\n\n";
    std::cout << "En OTRA terminal, para ver el %CPU del proceso en vivo y sin teclas:\n";
    std::cout << "  top -pid " << pid << " -l 0 -s 2 -stats pid,command,cpu,time\n";
    std::cout << "Para ver el costo POR HILO (top no lo desglosa en macOS moderno):\n";
    std::cout << "  sample " << pid << " 5 -file /tmp/evloop_sample.txt\n";
    std::cout << "  grep -A1 'Thread_.*evloop' /tmp/evloop_sample.txt\n\n";

    std::atomic<bool> running{true};

    std::atomic<std::uint64_t> busyIteraciones{0};
    std::atomic<std::uint64_t> sleepIteraciones{0};
    std::atomic<std::uint64_t> cvEventosProcesados{0};

    std::mutex cvMutex;
    std::condition_variable cv;
    std::queue<int> eventos;

    // --- Fase 1: solo busy loop -------------------------------------------
    std::cout << "[" << horaActual() << "] >>> FASE 1: busy loop (deberias ver ~100% CPU de un core)\n";
    running.store(true, std::memory_order_relaxed);
    std::thread busyThread(busyLoopWorker, std::ref(running), std::ref(busyIteraciones));
    esperarConLatido(std::chrono::seconds(segBusy), "busy", busyIteraciones);
    running.store(false, std::memory_order_relaxed);
    busyThread.join();
    std::cout << "[" << horaActual() << "] <<< FIN FASE 1. iteraciones=" << busyIteraciones.load() << "\n\n";

    // --- Fase 2: solo sleep loop -------------------------------------------
    std::cout << "[" << horaActual() << "] >>> FASE 2: sleep loop (CPU baja, deberia verse un % pequeño)\n";
    running.store(true, std::memory_order_relaxed);
    std::thread sleepThread(sleepLoopWorker, std::ref(running), std::ref(sleepIteraciones),
                             std::chrono::milliseconds(10));
    esperarConLatido(std::chrono::seconds(segSleep), "sleep", sleepIteraciones);
    running.store(false, std::memory_order_relaxed);
    sleepThread.join();
    std::cout << "[" << horaActual() << "] <<< FIN FASE 2. iteraciones=" << sleepIteraciones.load() << "\n\n";

    // --- Fase 3: solo cv loop (+ productor de eventos) ----------------------
    std::cout << "[" << horaActual() << "] >>> FASE 3: condition_variable loop (CPU ~0% entre eventos)\n";
    running.store(true, std::memory_order_relaxed);
    std::thread cvThread(cvLoopWorker, std::ref(cvMutex), std::ref(cv), std::ref(eventos),
                          std::ref(running), std::ref(cvEventosProcesados));
    std::thread productorThread([&] {
        nombrarHiloActual("evloop-producer");
        int siguienteEvento = 0;
        while (running.load(std::memory_order_relaxed)) {
            std::this_thread::sleep_for(std::chrono::milliseconds(800));
            if (!running.load(std::memory_order_relaxed)) break;
            {
                std::lock_guard<std::mutex> lock(cvMutex);
                eventos.push(siguienteEvento++);
            }
            cv.notify_one();
        }
    });
    esperarConLatido(std::chrono::seconds(segCv), "cv", cvEventosProcesados);
    running.store(false, std::memory_order_relaxed);
    cv.notify_all();  // despierta al hilo cv para que vea running == false y termine
    cvThread.join();
    productorThread.join();
    std::cout << "[" << horaActual() << "] <<< FIN FASE 3. eventos procesados=" << cvEventosProcesados.load()
              << "\n\n";

    std::cout << "=== Resumen ===\n";
    std::cout << "busy loop  -> iteraciones: " << busyIteraciones.load()
              << " (spinea sin parar; acapara un core entero, ~100% CPU)\n";
    std::cout << "sleep loop -> iteraciones: " << sleepIteraciones.load()
              << " (una vuelta cada ~10ms; CPU baja pero > 0%)\n";
    std::cout << "cv loop    -> eventos procesados: " << cvEventosProcesados.load()
              << " (solo trabaja cuando llega un evento real; CPU ~0% en reposo)\n";

    return 0;
}
