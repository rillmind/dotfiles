import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Wayland

// BluetoothManager.qml – estado e ações do menu de Bluetooth. O estado vem ao vivo do Quickshell.Bluetooth;
// o que ele não cobre fica em outros comandos:
// - pareamento com código: scripts/bt-agent.py, o agente que responde ao BlueZ;
// - nome do adaptador: busctl;
// - perfil de áudio: pactl;
// - bloqueio do rádio: rfkill.
//
// Também responde por IPC:
// quickshell ipc call bluetooth <menu|closeMenu|status|setEnabled|setScan|expand|action|answer>
Scope {
    id: mgr
    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool watching: false          // ligado pelo ControlCenter enquanto o submenu está aberto
    property string adapterPath: ""        // vazio: adaptador padrão do sistema
    property string message: ""
    property string expanded: ""           // endereço do aparelho aberto na lista
    property bool showUnnamed: false

    readonly property var adapters: Bluetooth.adapters.values
    readonly property var adapter: adapters.find(a => a.dbusPath === adapterPath) || Bluetooth.defaultAdapter
    readonly property bool enabled: !!adapter && adapter.enabled
    readonly property bool radioBlocked: !!adapter && adapter.state === BluetoothAdapterState.Blocked
    readonly property bool scanning: !!adapter && adapter.discovering

    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property int pairedCount: devices.filter(d => d.paired).length

    function isKnown(d) { return d.paired || d.connected || d.trusted || d.blocked }
    // sem nome, o BlueZ usa o endereço no lugar: quase sempre é um aparelho que ninguém reconhece
    function hasName(d) { return d.deviceName !== "" }
    readonly property int unnamedCount: devices.filter(d => !isKnown(d) && !hasName(d)).length
    readonly property var visibleDevices: {
        var rank = d => d.connected ? 0 : d.paired ? 1 : hasName(d) ? 2 : 3
        return devices.filter(d => showUnnamed || isKnown(d) || hasName(d))
                      .sort((a, b) => (rank(a) - rank(b)) || a.name.localeCompare(b.name))
    }

    signal menuRequested()
    signal menuCloseRequested()

    function findDevice(address) { return devices.find(d => d.address === address) || null }

    function typeLabel(icon) {
        if (icon.startsWith("audio-headset") || icon.startsWith("audio-headphones")) return "Fone de ouvido"
        if (icon.startsWith("audio")) return "Áudio"
        if (icon === "input-gaming") return "Controle"
        if (icon === "input-keyboard") return "Teclado"
        if (icon === "input-mouse") return "Mouse"
        if (icon === "input-tablet") return "Mesa digitalizadora"
        if (icon.startsWith("phone")) return "Celular"
        if (icon.startsWith("computer")) return "Computador"
        if (icon === "printer") return "Impressora"
        if (icon.startsWith("camera")) return "Câmera"
        return "Aparelho"
    }

    // ── Adaptador ──────────────────────────────────────────
    function setEnabled(on) {
        if (!adapter) return
        message = ""
        if (on && radioBlocked) { rfkillProc.running = true; return }
        adapter.enabled = on
    }
    Process {
        id: rfkillProc
        command: ["rfkill", "unblock", "bluetooth"]
        onExited: code => {
            if (code !== 0) mgr.message = "Não foi possível desbloquear o rádio"
            else if (mgr.adapter) mgr.adapter.enabled = true
        }
    }

    function renameAdapter(name) {
        name = name.trim()
        if (!adapter || name === "") return
        message = ""
        renameProc.command = ["busctl", "--system", "set-property", "org.bluez", adapter.dbusPath, "org.bluez.Adapter1", "Alias", "s", name]
        renameProc.running = true
    }
    Process {
        id: renameProc
        onExited: code => { if (code !== 0) mgr.message = "Não foi possível renomear o adaptador" }
    }

    // procurar atrapalha áudio e wifi, então para ao sair do menu e depois de um minuto
    function setScan(on) {
        if (!adapter) return
        if (on && !enabled) return
        adapter.discovering = on
        if (on) scanTimer.restart(); else scanTimer.stop()
    }
    Timer { id: scanTimer; interval: 60000; onTriggered: mgr.setScan(false) }
    onWatchingChanged: { if (enabled) setScan(watching) }
    onEnabledChanged: { if (enabled && watching) setScan(true) }

    // ── Aparelhos ──────────────────────────────────────────
    property var pairTarget: null
    property var connectTarget: null

    function pair(d) {
        message = "Pareando com " + d.name + "…"
        manualConnects[d.address] = true
        pairTarget = d
        d.pair()
    }
    function finishPair() {
        var d = pairTarget
        pairTarget = null
        if (!d) return
        if (d.paired) {
            d.trusted = true
            connectDevice(d)
        } else {
            message = "Não foi possível parear com " + d.name
            delete manualConnects[d.address]
        }
    }
    Connections {
        target: mgr.pairTarget
        function onPairingChanged() { if (mgr.pairTarget && !mgr.pairTarget.pairing) mgr.finishPair() }
    }

    function connectDevice(d) {
        message = "Conectando a " + d.name + "…"
        manualConnects[d.address] = true
        connectTarget = d
        d.connect()
    }
    Connections {
        target: mgr.connectTarget
        function onStateChanged() {
            var d = mgr.connectTarget
            if (d.state === BluetoothDeviceState.Connected) {
                mgr.message = ""
                mgr.connectTarget = null
            } else if (d.state === BluetoothDeviceState.Disconnected) {
                mgr.message = "Não foi possível conectar a " + d.name + ". Ele está ligado e por perto?"
                delete mgr.manualConnects[d.address]
                mgr.connectTarget = null
            }
        }
    }
    function disconnectDevice(d) {
        message = ""
        if (connectTarget === d) connectTarget = null
        d.disconnect()
    }
    function forget(d) {
        message = ""
        if (expanded === d.address) expanded = ""
        if (connectTarget === d) connectTarget = null
        if (pairTarget === d) pairTarget = null
        d.forget()
    }

    // ── Aviso de conexão automática ────────────────────────
    // só para aparelho visto desconectado que conectou sem ter sido pedido pelo menu
    property var manualConnects: ({})      // endereços com conexão pedida pelo menu, ainda sem resultado
    property var lastConnected: ({})       // endereço → estava conectado
    property bool settled: false           // ao iniciar, o estado dos aparelhos ainda está chegando
    Timer { interval: 3000; running: true; onTriggered: mgr.settled = true }
    property string toastText: ""
    Timer { id: toastTimer; interval: 2500; onTriggered: mgr.toastText = "" }
    function showToast(text) { toastText = text; toastTimer.restart() }

    onConnectedDevicesChanged: {
        var next = {}
        for (var d of devices) {
            next[d.address] = d.connected
            if (!d.connected || lastConnected[d.address] !== false) continue
            if (manualConnects[d.address]) delete manualConnects[d.address]
            else if (settled) showToast(d.name + " conectado")
        }
        lastConnected = next
    }

    PanelWindow {
        visible: mgr.toastText !== ""
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-bluetooth-toast"
        anchors.top: true
        margins.top: 44      // logo abaixo da barra
        implicitWidth: toastRow.implicitWidth + 24
        implicitHeight: 28
        color: "transparent"
        mask: Region {}      // cliques passam direto

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#E61e1e2e"
            border.color: "#45475a"
            border.width: 1
            Row {
                id: toastRow
                anchors.centerIn: parent
                spacing: 6
                Text { text: "󰂱"; color: "#cba6f7"; font.family: mgr.fontFamily; font.pixelSize: 12 }
                Text { text: mgr.toastText; color: "#cdd6f4"; font.family: mgr.fontFamily; font.pixelSize: 11 }
            }
        }
    }

    // ── Pedidos do agente de pareamento ────────────────────
    property bool agentReady: false
    property var requests: []
    readonly property var request: requests.length > 0 ? requests[0] : null
    property var display: null             // código que precisa ser digitado no outro aparelho

    function answer(accept, value) {
        if (!request) return
        agent.write(JSON.stringify({ id: request.id, accept: accept, value: value || "" }) + "\n")
        requests = requests.slice(1)
    }
    function handleAgent(line) {
        var m
        try { m = JSON.parse(line) } catch (e) { return }
        if (m.type === "ready") {
            agentReady = true
        } else if (m.type === "request") {
            requests = requests.concat([m])
            menuRequested()
        } else if (m.type === "display") {
            display = m
            displayTimer.restart()
            menuRequested()
        } else if (m.type === "cancel") {
            requests = []
            display = null
        }
    }
    Timer { id: displayTimer; interval: 60000; onTriggered: mgr.display = null }
    onPairTargetChanged: if (!pairTarget) display = null

    Process {
        id: agent
        command: [Quickshell.shellDir + "/scripts/bt-agent.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser { onRead: line => mgr.handleAgent(line) }
        onExited: {
            mgr.agentReady = false
            mgr.requests = []
            mgr.display = null
            agentRestart.restart()
        }
    }
    Timer { id: agentRestart; interval: 5000; onTriggered: agent.running = true }

    // ── Perfil de áudio ────────────────────────────────────
    property var cards: ({})               // bluez_card.XX_XX → { active, profiles: [{ name, label }] }

    // o rótulo sai do nome do perfil: o pactl em JSON troca descrições acentuadas por "(null)"
    function profileLabel(name) {
        var m = /^(a2dp-sink|headset-head-unit)(?:-(.+))?$/.exec(name)
        if (!m) return name
        return (m[1] === "a2dp-sink" ? "Música" : "Chamadas") + " · " + (m[2] ? m[2].toUpperCase().replace(/_/g, "-") : "padrão")
    }
    function cardFor(address) { return cards["bluez_card." + address.replace(/:/g, "_")] || null }
    function setProfile(address, profile) {
        cardSetProc.command = ["pactl", "set-card-profile", "bluez_card." + address.replace(/:/g, "_"), profile]
        cardSetProc.running = true
    }
    Process {
        id: cardsProc
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list
                try { list = JSON.parse(text) } catch (e) { return }
                var next = {}
                for (var c of list) {
                    if (!c.name.startsWith("bluez_card.")) continue
                    var profiles = []
                    for (var name in c.profiles) {
                        if (name !== "off" && c.profiles[name].available)
                            profiles.push({ name: name, label: mgr.profileLabel(name) })
                    }
                    next[c.name] = { active: c.active_profile, profiles: profiles }
                }
                mgr.cards = next
            }
        }
    }
    Process {
        id: cardSetProc
        onExited: code => {
            if (code !== 0) mgr.message = "Não foi possível mudar o perfil de áudio"
            cardsProc.running = true
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: mgr.watching && mgr.connectedDevices.length > 0
        triggeredOnStart: true
        onTriggered: cardsProc.running = true
    }

    IpcHandler {
        target: "bluetooth"
        function menu(): void { mgr.menuRequested() }
        function closeMenu(): void { mgr.menuCloseRequested() }
        function status(): string {
            return JSON.stringify({
                adapter: mgr.adapter ? { id: mgr.adapter.adapterId, name: mgr.adapter.name, enabled: mgr.adapter.enabled,
                                         state: BluetoothAdapterState.toString(mgr.adapter.state), discoverable: mgr.adapter.discoverable,
                                         discoverableTimeout: mgr.adapter.discoverableTimeout, pairable: mgr.adapter.pairable,
                                         pairableTimeout: mgr.adapter.pairableTimeout, scanning: mgr.adapter.discovering } : null,
                agentReady: mgr.agentReady, request: mgr.request, display: mgr.display, message: mgr.message,
                devices: mgr.devices.map(d => ({ address: d.address, name: d.name, connected: d.connected, paired: d.paired,
                                                 trusted: d.trusted, blocked: d.blocked, wakeAllowed: d.wakeAllowed,
                                                 state: BluetoothDeviceState.toString(d.state), icon: d.icon,
                                                 battery: d.batteryAvailable ? Math.round(d.battery * 100) : null }))
            })
        }
        function setEnabled(on: bool): void { mgr.setEnabled(on) }
        function setScan(on: bool): void { mgr.setScan(on) }
        function expand(address: string): void { mgr.expanded = address; mgr.menuRequested() }
        // action: connect, disconnect, pair, forget, trust, untrust, block, unblock
        function action(address: string, name: string): void {
            var d = mgr.findDevice(address)
            if (!d) return
            if (name === "connect") mgr.connectDevice(d)
            else if (name === "disconnect") mgr.disconnectDevice(d)
            else if (name === "pair") mgr.pair(d)
            else if (name === "forget") mgr.forget(d)
            else if (name === "trust") d.trusted = true
            else if (name === "untrust") d.trusted = false
            else if (name === "block") d.blocked = true
            else if (name === "unblock") d.blocked = false
        }
        function answer(accept: bool, value: string): void { mgr.answer(accept, value) }
    }
}
