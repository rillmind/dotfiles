import QtQuick
import Quickshell
import Quickshell.Io

// FanManager.qml – fala com o g15-daemon (serviço do g15-control-center, em ~/git) pelo socket dele.
// Lê temperatura, RPM, boost e modo a cada 2 s enquanto o painel está aberto.
// O daemon guarda as escolhas sozinho, e o app original continua funcionando junto.
//
// Regras herdadas do daemon/app:
// - escolher Silencioso, Balanceado ou Performance zera os boosts manuais;
// - os boosts só voltam ao reiniciar no modo Personalizado, por isso mexer neles muda o modo;
// - com o G-Mode ligado, modos e boosts ficam travados (como no app).
//
// Precisa do socat. Também responde por IPC:
// quickshell ipc call fans <menu|closeMenu|status|setMode|setBoost|toggleGMode>
Scope {
    id: mgr
    readonly property string socketPath: "/tmp/g15-daemon.sock"
    readonly property var modes: ["Silencioso", "Balanceado", "Performance"]
    readonly property string customMode: "Personalizado"

    property bool watching: false     // ligado pelo shell.qml enquanto o painel está aberto
    property bool loaded: false       // já recebeu dados do daemon ao menos uma vez
    property bool offline: false      // o daemon não respondeu
    property string errorText: ""

    property int cpuTemp: 0
    property int gpuTemp: 0
    property int cpuRpm: 0
    property int gpuRpm: 0
    property int cpuBoost: 0
    property int gpuBoost: 0
    property string mode: ""
    property bool gMode: false

    signal menuRequested()
    signal menuCloseRequested()

    IpcHandler {
        target: "fans"
        function menu(): void { mgr.menuRequested() }
        function closeMenu(): void { mgr.menuCloseRequested() }
        function status(): string {
            return JSON.stringify({ loaded: mgr.loaded, offline: mgr.offline, error: mgr.errorText, mode: mgr.mode, gMode: mgr.gMode,
                                    cpu: { temp: mgr.cpuTemp, rpm: mgr.cpuRpm, boost: mgr.cpuBoost },
                                    gpu: { temp: mgr.gpuTemp, rpm: mgr.gpuRpm, boost: mgr.gpuBoost } })
        }
        function setMode(name: string): void { mgr.setMode(name) }
        function setBoost(fan: int, percent: int): void { mgr.setBoost(fan, percent) }
        function toggleGMode(): void { mgr.toggleGMode() }
    }

    // ── Comandos ───────────────────────────────────────────
    function setMode(name) {
        if (!loaded || gMode || modes.indexOf(name) === -1 || name === mode) return
        errorText = ""
        mode = name
        cpuBoost = 0; gpuBoost = 0
        send({ action: "set_power_mode", mode: name })
        refresh()
    }

    // fan: 1 = CPU, 2 = GPU
    function setBoost(fan, percent) {
        if (!loaded || gMode || (fan !== 1 && fan !== 2)) return
        var pct = Math.max(0, Math.min(100, Math.round(percent)))
        errorText = ""
        if (mode !== customMode) {
            mode = customMode
            send({ action: "set_power_mode", mode: customMode })
        }
        if (fan === 1) cpuBoost = pct; else gpuBoost = pct
        send({ action: "set_fan_boost", fan_id: fan, percentage: pct })
        refresh()
    }

    function toggleGMode() {
        if (!loaded) return
        errorText = ""
        send({ action: "toggle_g_mode" })
        refresh()
    }

    function refresh() { send({ action: "get_all_data" }) }

    // ── Fila: uma conexão por pedido, na ordem em que foram feitos ──
    property var queue: []
    property var current: null

    function send(request) {
        queue.push(request)
        pump()
    }

    function pump() {
        if (current || queue.length === 0) return
        current = queue.shift()
        rpc.command = ["sh", "-c", 'printf %s "$1" | socat -t 3 - "UNIX-CONNECT:$2"', "sh", JSON.stringify(current), socketPath]
        rpc.running = true
    }

    function handleResponse(text) {
        var request = current
        if (text.trim() === "") { offline = true; return }
        offline = false
        var response
        try { response = JSON.parse(text) } catch (e) { errorText = "Resposta inválida do g15-daemon"; return }
        if (response.status !== "success") {
            if (request.action !== "get_all_data") errorText = "O g15-daemon não aplicou a mudança"
            return
        }
        // uma leitura antiga não pode desfazer na tela uma mudança que ainda está na fila
        if (request.action === "get_all_data" && queue.length === 0) applyData(response.data)
    }

    function applyData(d) {
        cpuTemp = d.temps.cpu_temp
        gpuTemp = d.temps.gpu_temp
        cpuRpm = d.fans.fan1_rpm
        gpuRpm = d.fans.fan2_rpm
        cpuBoost = d.fans.fan1_boost
        gpuBoost = d.fans.fan2_boost
        mode = d.power.current_mode
        gMode = d.power.g_mode
        loaded = true
    }

    Process {
        id: rpc
        stdout: StdioCollector { onStreamFinished: mgr.handleResponse(text) }
        onExited: Qt.callLater(() => { mgr.current = null; mgr.pump() })
    }

    Timer {
        interval: 2000
        repeat: true
        running: mgr.watching
        triggeredOnStart: true
        onTriggered: if (!mgr.current && mgr.queue.length === 0) mgr.refresh()
    }
}
