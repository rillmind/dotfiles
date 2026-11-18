import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "modules/holidays.js" as Holidays
import qs.modules

// Tema Gruvbox: barra lateral à esquerda (SO + workspaces no topo, apps do workspace atual no centro,
// utilidades + hora embaixo) e launcher estilo barra de endereço. Mesmas funções do Catppuccin-mocha.
// Cores e modo claro/escuro em modules/Theme.qml.
ShellRoot {
    id: root

    readonly property int barWidth: 46
    readonly property int popupGap: 8
    // contorno da tela (como o quadro do Zen): a barra lateral continua numa faixa fina no topo, na
    // direita e embaixo, e a área das janelas fica num recorte com os 4 cantos arredondados.
    // Fica abaixo das janelas; as janelas mantêm o gaps_out do Hyprland por dentro dele.
    readonly property int frameWidth: 14
    readonly property int cornerRadius: 16

    // ── Estado ─────────────────────────────────────────────
    property int cpuUsage: 0
    property int memUsage: 0
    property string hyprWindowTitle: ""
    property string hyprWindowClass: ""
    property string hyprWindowAddress: ""
    property string networkIcon: "󰤭"
    property string networkTooltip: ""
    property string networkType: "disconnected"   // wifi | ethernet | disconnected
    property string networkSsid: ""
    property int networkSignal: 0
    property string networkIp: ""
    property int volumeLevel: 35
    property bool volumeMuted: false
    property string pulseIcon: ""
    property int batteryCapacity: 100
    property string batteryStatus: "Not charging"
    property string batteryIcon: ""
    property bool batteryCharging: false
    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    // ícone da barra sob o mouse – mostra a tooltip ao lado dele
    property string barHover: ""
    // guarda só a janela e a altura (y) do ícone, nunca o item: um PopupWindow ancorado num item que
    // vira null (mouse saiu, app fechou, workspace mudou) derruba o Quickshell (PopupAnchor::onItemWindowChanged)
    property var hoverWindow: null
    property real hoverY: 0
    function hover(name, item) {
        hoverWindow = item.QsWindow.window
        hoverY = item.mapToItem(null, 0, item.height / 2).y
        barHover = name
    }
    function unhover(name) { if (barHover === name) barHover = "" }

    // ── Popups ─────────────────────────────────────────────
    property bool controlCenterVisible: false
    property bool sysMonVisible: false
    property bool calendarVisible: false
    property bool mediaVisible: false
    property bool notifVisible: false
    // um popup por vez, sempre na tela da barra clicada (ver comentário no Catppuccin-mocha/shell.qml)
    property string popupScreen: ""
    function closePopups() { controlCenterVisible = false; sysMonVisible = false; calendarVisible = false; mediaVisible = false; notifVisible = false }
    function togglePopup(name, screenName) {
        var wasOpen = name === "cc" ? controlCenterVisible : name === "sm" ? sysMonVisible : name === "cal" ? calendarVisible
                    : name === "notif" ? notifVisible : mediaVisible
        closePopups()
        if (wasOpen && popupScreen === screenName) return
        popupScreen = screenName
        if (name === "cc") controlCenterVisible = true
        else if (name === "sm") sysMonVisible = true
        else if (name === "cal") calendarVisible = true
        else if (name === "notif") notifVisible = true
        else mediaVisible = true
    }

    // ── Volume ao vivo via PipeWire ────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var pwSink: Pipewire.defaultAudioSink
    readonly property bool pwReady: pwSink !== null && pwSink.ready && pwSink.audio !== null
    function syncVolume() {
        if (!pwReady) return
        volumeLevel = Math.round(pwSink.audio.volume * 100)
        volumeMuted = pwSink.audio.muted
        updatePulseIcon()
        if (osdSink === pwSink && (osdLevel !== volumeLevel || osdMuted !== volumeMuted) && !controlCenterVisible)
            volumeOsd.show(volumeLevel, volumeMuted)
        osdSink = pwSink
        osdLevel = volumeLevel
        osdMuted = volumeMuted
    }
    property var osdSink: null
    property int osdLevel: -1
    property bool osdMuted: false
    onPwReadyChanged: syncVolume()
    onPwSinkChanged: syncVolume()
    Connections {
        target: root.pwReady ? root.pwSink.audio : null
        function onVolumeChanged() { root.syncVolume() }
        function onMutedChanged() { root.syncVolume() }
    }

    // ── Bateria: extras do UPower ──────────────────────────
    readonly property var upDev: UPower.displayDevice
    function formatDuration(sec) {
        if (!sec || sec <= 0) return ""
        var h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
        return h > 0 ? h + "h" + (m < 10 ? "0" : "") + m : m + " min"
    }
    readonly property string batteryTimeText: {
        if (!upDev || !upDev.ready) return ""
        if (batteryCharging && upDev.timeToFull > 0) return formatDuration(upDev.timeToFull) + " para carregar"
        if (batteryStatus === "Discharging" && upDev.timeToEmpty > 0) return formatDuration(upDev.timeToEmpty) + " restantes"
        return ""
    }
    readonly property real batteryRate: upDev && upDev.ready ? Math.abs(upDev.changeRate) : 0
    readonly property bool batteryLow: batteryCapacity <= 10 && !batteryCharging

    // ── Painel do sistema (CPU/RAM/GPU/rede/processos) ─────
    property var sysInfo: null
    property var cpuHistory: []
    property real netRxRate: 0
    property real netTxRate: 0
    property real _lastRx: -1
    property real _lastTx: -1
    property real _lastNetTime: 0
    Process {
        id: sysInfoProc
        command: [Quickshell.shellDir + "/scripts/sys-info.sh"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var j = JSON.parse(data)
                    var now = Date.now()
                    if (root._lastRx >= 0 && now > root._lastNetTime) {
                        var dt = (now - root._lastNetTime) / 1000
                        root.netRxRate = Math.max(0, (j.net.rx - root._lastRx) / dt)
                        root.netTxRate = Math.max(0, (j.net.tx - root._lastTx) / dt)
                    }
                    root._lastRx = j.net.rx; root._lastTx = j.net.tx; root._lastNetTime = now
                    root.sysInfo = j
                } catch (e) {}
            }
        }
    }
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.sysMonVisible
        onTriggered: if (!sysInfoProc.running) sysInfoProc.running = true
        onRunningChanged: if (!running) { root._lastRx = -1; root.netRxRate = 0; root.netTxRate = 0 }
    }
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: { var h = root.cpuHistory.slice(-59); h.push(root.cpuUsage); root.cpuHistory = h }
    }
    Process { id: killProc }
    Process { id: missionCenterProc; command: ["flatpak", "run", "io.missioncenter.MissionCenter"] }
    Process { id: pulsemixerProc; command: ["ghostty", "-e", "/bin/zsh", "-c", "pulsemixer"] }

    // ── Helpers ────────────────────────────────────────────
    function updatePulseIcon() {
        if (volumeMuted) pulseIcon = "󰝟"
        else if (volumeLevel <= 0) pulseIcon = "󰕿"
        else if (volumeLevel < 33) pulseIcon = "󰕿"
        else if (volumeLevel < 66) pulseIcon = "󰖀"
        else pulseIcon = "󰕾"
    }
    function updateBatteryIcon() {
        var levels = ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
        var charging = ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
        var i = Math.max(0, Math.min(10, Math.round(batteryCapacity / 10)))
        batteryIcon = batteryCharging ? charging[i] : levels[i]
    }
    // Nerd Font de reserva quando o app não tem ícone no tema de ícones
    function glyphFor(cls) {
        var c = (cls || "").toLowerCase()
        if (c.indexOf("ghostty") !== -1) return "󰆍"
        if (c.indexOf("zen") !== -1 || c.indexOf("firefox") !== -1 || c.indexOf("chrome") !== -1 || c.indexOf("chromium") !== -1) return "󰈹"
        if (c.indexOf("code") !== -1 || c.indexOf("codium") !== -1) return "󰨞"
        if (c.indexOf("spotify") !== -1) return "󰓇"
        if (c.indexOf("obsidian") !== -1) return "󰠮"
        if (c.indexOf("nautilus") !== -1 || c.indexOf("files") !== -1) return "󰉋"
        if (c.indexOf("steam") !== -1) return "󰓓"
        return "󰣆"
    }
    function appIconPath(cls) {
        if (!cls) return ""
        var entry = DesktopEntries.heuristicLookup(cls)
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : cls, true)
    }

    // ── Módulos ────────────────────────────────────────────
    UrlLauncher {
        id: appLauncher
        windowTitle: root.hyprWindowTitle
        windowClass: root.hyprWindowClass
        leftInset: root.barWidth
        frameWidth: root.frameWidth
        cornerRadius: root.cornerRadius
        clockTooltip: open ? root.clockTooltipText() : ""
        onCalendarRequested: root.togglePopup("cal", Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Quickshell.screens[0].name)
    }
    VolumeOsd { id: volumeOsd; fontFamily: Theme.font }
    DisplayManager {
        id: displayManager
        fontFamily: Theme.font
        onPendingChanged: if (pending) root.controlCenterVisible = false
        onMenuRequested: root.openPanel("displays")
        onMenuCloseRequested: root.controlCenterVisible = false
    }
    signal panelPageRequested(string page)
    function openPanel(page) {
        root.popupScreen = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Quickshell.screens[0].name
        root.calendarVisible = false; root.sysMonVisible = false; root.mediaVisible = false; root.notifVisible = false; root.controlCenterVisible = true
        root.panelPageRequested(page)
    }
    // quickshell ipc call panel open <""|network|sound|battery|displays|fans|bluetooth> · panel calendario
    IpcHandler {
        target: "panel"
        function open(page: string): void { root.openPanel(page) }
        function close(): void { root.controlCenterVisible = false }
        function calendario(): void { root.togglePopup("cal", Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Quickshell.screens[0].name) }
    }
    FanManager {
        id: fanManager
        watching: root.controlCenterVisible
        onMenuRequested: root.openPanel("fans")
        onMenuCloseRequested: root.controlCenterVisible = false
    }
    BluetoothManager {
        id: bluetoothManager
        fontFamily: Theme.font
        onMenuRequested: root.openPanel("bluetooth")
        onMenuCloseRequested: root.controlCenterVisible = false
    }
    // notificações (substituem o dunst): popups no canto superior direito, central pelo sino
    Notifications {
        id: notifs
        topMargin: root.frameWidth + root.popupGap
        rightMargin: root.frameWidth + root.popupGap
        centerOpen: root.notifVisible
        onCenterToggleRequested: root.togglePopup("notif", Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Quickshell.screens[0].name)
    }

    // ── Mídia (MPRIS) ──────────────────────────────────────
    readonly property var players: Mpris.players.values
    readonly property var activePlayer: players.find(p => p.isPlaying) ?? players[0] ?? null

    // ── Coleta (mesma do Catppuccin) ───────────────────────
    Process {
        id: windowProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '[.title // empty, .class // empty, .address // empty] | @tsv'"]
        stdout: SplitParser {
            onRead: data => {
                var t = (data || "").trim()
                if (!t) return
                windowProc.gotWindow = true
                var parts = t.split("\t")
                root.hyprWindowTitle = (parts[0] || "").trim()
                root.hyprWindowClass = (parts[1] || "").trim()
                root.hyprWindowAddress = (parts[2] || "").trim()
            }
        }
        // sem janela em foco o jq não imprime nada: limpa o título
        property bool gotWindow: false
        onStarted: gotWindow = false
        onExited: if (!gotWindow) { root.hyprWindowTitle = ""; root.hyprWindowClass = ""; root.hyprWindowAddress = "" }
        Component.onCompleted: running = true
    }
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var p = data.trim().split(/\s+/)
                var user = parseInt(p[1]) || 0, nice = parseInt(p[2]) || 0, sys = parseInt(p[3]) || 0
                var idle = parseInt(p[4]) || 0, iow = parseInt(p[5]) || 0, irq = parseInt(p[6]) || 0, sirq = parseInt(p[7]) || 0
                var total = user + nice + sys + idle + iow + irq + sirq
                var idleT = idle + iow
                if (root.lastCpuTotal > 0) {
                    var td = total - root.lastCpuTotal, id = idleT - root.lastCpuIdle
                    if (td > 0) root.cpuUsage = Math.round(100 * (td - id) / td)
                }
                root.lastCpuTotal = total; root.lastCpuIdle = idleT
            }
        }
    }
    Process {
        id: memProc
        command: ["sh", "-c", "free | awk '/Mem:/{printf \"%d\", $3/$2*100}'"]
        stdout: SplitParser { onRead: data => { if (data) root.memUsage = parseInt(data.trim()) || 0 } }
    }
    Process {
        id: netProc
        command: [Quickshell.shellDir + "/scripts/net-info.sh"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var f = data.trim().split("|")
                root.networkType = f[0]; root.networkSsid = f[1] || ""; root.networkSignal = parseInt(f[2]) || 0; root.networkIp = f[3] || ""
                if (root.networkType === "wifi") {
                    var s = root.networkSignal
                    root.networkIcon = s >= 80 ? "󰤨" : s >= 60 ? "󰤥" : s >= 40 ? "󰤢" : s >= 20 ? "󰤟" : "󰤯"
                    root.networkTooltip = root.networkSsid || "Wi-Fi"
                }
                else if (root.networkType === "ethernet") { root.networkIcon = "󰈀"; root.networkTooltip = "Ethernet" }
                else { root.networkIcon = "󰤭"; root.networkTooltip = "Desconectado" }
            }
        }
    }
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]
        stdout: SplitParser {
            onRead: data => {
                var m = (data || "").trim().match(/Volume:\s*([\d.]+)/)
                if (m) { root.volumeLevel = Math.round(parseFloat(m[1]) * 100); root.volumeMuted = data.indexOf("[MUTED]") !== -1; root.updatePulseIcon() }
            }
        }
    }
    Process {
        id: battProc
        command: ["sh", "-c", "cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); sta=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); echo \"$cap|$sta\""]
        stdout: SplitParser {
            onRead: data => {
                var t = (data || "").trim(); if (!t || t === "|") return
                var parts = t.split("|")
                var c = parseInt(parts[0]); if (!isNaN(c)) root.batteryCapacity = c
                root.batteryStatus = (parts[1] || "").trim()
                root.batteryCharging = root.batteryStatus === "Charging" || root.batteryStatus === "Full"
                root.updateBatteryIcon()
            }
        }
    }
    Process { id: setVolumeProc }
    Process { id: toggleMuteProc }
    // todas as janelas (a barra mostra só as do workspace atual)
    property var clients: []
    Process {
        id: clientsProc
        command: ["sh", "-c", "hyprctl clients -j 2>/dev/null | jq -c '[.[] | {address: .address, class: .class, title: .title, workspace: .workspace.id}]'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try { root.clients = JSON.parse(data.trim()) } catch (e) {}
            }
        }
    }
    readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property var workspaceClients: clients.filter(c => c.workspace === focusedWs)

    Timer { interval: 1000; running: true; repeat: true; onTriggered: { cpuProc.running = true; memProc.running = true; battProc.running = true } }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: netProc.running = true }
    Timer { interval: 2000; running: !root.pwReady; repeat: true; onTriggered: volProc.running = true }
    Timer { interval: 200; running: true; repeat: true; onTriggered: windowProc.running = true }
    Timer { interval: 500; running: true; repeat: true; onTriggered: clientsProc.running = true }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            windowProc.running = true; clientsProc.running = true
            try { if (event && event.name && event.name.indexOf("workspace") !== -1) { root.controlCenterVisible = false; root.calendarVisible = false } } catch (e) {}
        }
    }
    Component.onCompleted: { cpuProc.running = true; memProc.running = true; netProc.running = true; volProc.running = true; battProc.running = true; clientsProc.running = true; updatePulseIcon(); updateBatteryIcon() }

    function setVolume(level) {
        level = Math.max(0, Math.min(100, level))
        if (pwReady) { pwSink.audio.volume = level / 100; return }
        setVolumeProc.command = ["sh", "-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (level / 100).toFixed(2)]
        setVolumeProc.running = true
        refreshVolTimer.restart()
    }
    function toggleMute() {
        if (pwReady) { pwSink.audio.muted = !pwSink.audio.muted; return }
        toggleMuteProc.command = ["sh", "-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]
        toggleMuteProc.running = true
        refreshVolTimer.restart()
    }
    Timer { id: refreshVolTimer; interval: 250; repeat: false; onTriggered: volProc.running = true }

    // ── Popups: todos saem do pé da barra lateral, ao lado dela ─
    component SidePopup: PanelWindow {
        id: pop
        property var modelData
        property bool shown: false
        signal dismissed()
        screen: modelData
        visible: shown && root.popupScreen === modelData.name
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { left: true; bottom: true }
        margins { left: root.barWidth + root.popupGap; bottom: root.frameWidth + root.popupGap }
        color: "transparent"
        HyprlandFocusGrab {
            windows: [pop]
            active: pop.visible
            onCleared: pop.dismissed()
        }
    }

    Variants {
        model: Quickshell.screens
        SidePopup {
            id: ccWindow
            shown: root.controlCenterVisible
            onDismissed: root.controlCenterVisible = false
            // teclado só enquanto digita a senha do wifi
            WlrLayershell.keyboardFocus: cc.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            implicitWidth: cc.implicitWidth
            implicitHeight: cc.implicitHeight
            ControlCenter {
                id: cc
                anchors.fill: parent
                radius: 8
                networkType: root.networkType
                networkSsid: root.networkSsid
                networkSignal: root.networkSignal
                networkIp: root.networkIp
                batteryTimeText: root.batteryTimeText
                batteryRate: root.batteryRate
                volumeLevel: root.volumeLevel
                volumeMuted: root.volumeMuted
                networkIcon: root.networkIcon
                networkTooltip: root.networkTooltip
                batteryIcon: root.batteryIcon
                batteryCapacity: root.batteryCapacity
                batteryStatus: root.batteryStatus
                batteryCharging: root.batteryCharging
                displays: displayManager
                fans: fanManager
                bluetooth: bluetoothManager
                fontFamily: Theme.font
                onRequestSetVolume: lvl => root.setVolume(lvl)
                onRequestToggleMute: root.toggleMute()
                onRequestRefresh: { netProc.running = true; volProc.running = true; battProc.running = true }
                cpuUsage: root.cpuUsage
                memUsage: root.memUsage
                onRequestSystemMonitor: root.togglePopup("sm", ccWindow.modelData.name)
            }
            Connections {
                target: root
                function onPanelPageRequested(page) { if (root.popupScreen === ccWindow.modelData.name) cc.page = page }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        SidePopup {
            // abre pela hora do launcher: fica no canto superior direito, embaixo de onde a hora estava
            anchors { left: false; bottom: false; top: true; right: true }
            margins { left: 0; bottom: 0; top: root.frameWidth + root.popupGap; right: root.frameWidth + root.popupGap }
            shown: root.calendarVisible
            onDismissed: root.calendarVisible = false
            implicitWidth: cal.implicitWidth
            implicitHeight: cal.implicitHeight
            CalendarWidget {
                id: cal
                anchors.fill: parent
                fontFamily: Theme.font
                Connections {
                    target: root
                    function onCalendarVisibleChanged() { if (root.calendarVisible) cal.goToday() }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        SidePopup {
            shown: root.sysMonVisible
            onDismissed: root.sysMonVisible = false
            implicitWidth: sm.implicitWidth
            implicitHeight: sm.implicitHeight
            SystemMonitor {
                id: sm
                anchors.fill: parent
                info: root.sysInfo
                cpuUsage: root.cpuUsage
                cpuHistory: root.cpuHistory
                rxRate: root.netRxRate
                txRate: root.netTxRate
                fontFamily: Theme.font
                onRequestKill: pid => { killProc.command = ["kill", String(pid)]; killProc.running = true; sysInfoProc.running = true }
                onRequestOpenMonitor: { missionCenterProc.running = true; root.sysMonVisible = false }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        SidePopup {
            shown: root.mediaVisible
            onDismissed: root.mediaVisible = false
            implicitWidth: media.implicitWidth
            implicitHeight: media.implicitHeight
            MediaPanel {
                id: media
                anchors.fill: parent
                Connections {
                    target: root
                    function onMediaVisibleChanged() { if (root.mediaVisible) media.player = root.activePlayer }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        SidePopup {
            shown: root.notifVisible
            onDismissed: root.notifVisible = false
            implicitWidth: notifCenter.implicitWidth
            implicitHeight: notifCenter.implicitHeight
            NotificationCenter {
                id: notifCenter
                anchors.fill: parent
                service: notifs
            }
        }
    }

    // ── Tooltip ao lado do ícone sob o mouse ───────────────
    property date clockNow: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.clockNow = new Date() }
    function clockTooltipText() {
        var d = clockNow
        var wd = ["Domingo", "Segunda-feira", "Terça-feira", "Quarta-feira", "Quinta-feira", "Sexta-feira", "Sábado"][d.getDay()]
        var mo = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"][d.getMonth()]
        var txt = "󰃭  " + wd + ", " + d.getDate() + " de " + mo + "  ·  " + Qt.formatTime(d, "hh:mm") + "  ·  semana " + Holidays.isoWeek(d)
        var today = Holidays.holidayOn(d)
        if (today) return txt + "  ·  hoje é feriado: " + today.name
        var next = Holidays.upcoming(d, 1)[0]
        if (next) txt += "  ·  próximo feriado: " + Qt.formatDate(next.date, "dd/MM") + " " + next.name + " (" + Holidays.relative(next.daysUntil) + ")"
        return txt
    }
    function tooltipText() {
        var h = barHover
        if (h === "net") {
            if (networkType === "wifi") return "󰤨  " + networkSsid + "  ·  sinal " + networkSignal + "%" + (networkIp ? "  ·  " + networkIp : "")
            if (networkType === "ethernet") return "󰈀  Ethernet" + (networkIp ? "  ·  " + networkIp : "")
            return "󰤭  Sem conexão"
        }
        if (h === "vol") {
            var dev = pwSink ? (pwSink.nickname || pwSink.description || "") : ""
            return (volumeMuted ? "󰝟  Mudo" : "󰕾  " + volumeLevel + "%") + (dev ? "  ·  " + dev : "") + "   (rolar ajusta)"
        }
        if (h === "batt") {
            var st = batteryStatus === "Charging" ? "carregando" : batteryStatus === "Discharging" ? "descarregando" : batteryStatus === "Full" ? "carga completa" : batteryStatus.toLowerCase()
            return "󰁹  " + batteryCapacity + "%  ·  " + st + (batteryTimeText ? "  ·  " + batteryTimeText : "")
        }
        if (h === "media") {
            var p = activePlayer
            if (!p) return ""
            return (p.isPlaying ? "󰐊  " : "󰏤  ") + (p.trackTitle || "Sem título") + (p.trackArtist ? "  ·  " + p.trackArtist : "") + "   (direito: play/pause)"
        }
        if (h === "notif") {
            var parts = [notifs.unread > 0 ? notifs.unread + (notifs.unread === 1 ? " nova" : " novas") : "Notificações"]
            if (notifs.dnd) parts.push("não perturbe ligado")
            return "󰂚  " + parts.join("  ·  ") + "   (direito: não perturbe)"
        }
        if (h === "power") return "󰐥  Energia"
        if (h.startsWith("tray:")) return h.substring(5)
        return ""
    }
    readonly property bool anyPopup: controlCenterVisible || sysMonVisible || calendarVisible || mediaVisible || notifVisible
    AppMenu { id: appMenu }

    // ── Peças da barra ─────────────────────────────────────
    // ícone clicável da área de utilidades
    component BarIcon: Item {
        id: bi
        property string icon: ""
        property string hoverName: ""
        property color tint: Theme.fg
        property int size: 19
        property string label: ""          // número pequeno abaixo do ícone (CPU/RAM)
        signal clicked(var mouse)
        signal wheel(var wheel)
        Layout.preferredWidth: root.barWidth
        Layout.preferredHeight: label !== "" ? 42 : 32
        Rectangle {
            anchors.centerIn: parent
            width: 34; height: parent.height - 4; radius: 6
            color: biMouse.containsMouse ? Theme.surface0 : "transparent"
        }
        Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
                id: biIcon
                anchors.horizontalCenter: parent.horizontalCenter
                text: bi.icon
                color: biMouse.containsMouse ? Theme.accent : bi.tint
                font.family: Theme.font
                font.pixelSize: bi.size
            }
            Text {
                visible: bi.label !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: bi.label
                color: bi.tint
                font.family: Theme.font
                font.pixelSize: 10
                font.bold: true
            }
        }
        MouseArea {
            id: biMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onEntered: if (bi.hoverName) root.hover(bi.hoverName, bi)
            onExited: if (bi.hoverName) root.unhover(bi.hoverName)
            onClicked: mouse => bi.clicked(mouse)
            onWheel: wheel => bi.wheel(wheel)
        }
    }
    component Separator: Rectangle {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 6
        Layout.bottomMargin: 6
        implicitWidth: 22
        implicitHeight: 1
        color: Theme.surface1
    }

    // ── Contorno da tela ───────────────────────────────────
    // desenho: tela inteira menos um retângulo de cantos arredondados (a área das janelas)
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: frameWindow
            property var modelData
            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom          // por baixo das janelas, acima do papel de parede
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell-contorno"
            anchors { top: true; bottom: true; left: true; right: true }
            mask: Region {}                                 // não pega clique
            color: "transparent"

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    id: framePath
                    readonly property real w: frameWindow.width
                    readonly property real h: frameWindow.height
                    readonly property real x0: root.barWidth
                    readonly property real y0: root.frameWidth
                    readonly property real x1: w - root.frameWidth
                    readonly property real y1: h - root.frameWidth
                    readonly property real r: root.cornerRadius
                    fillColor: Theme.bgHard
                    fillRule: ShapePath.OddEvenFill
                    strokeWidth: -1
                    // borda de fora
                    startX: 0; startY: 0
                    PathLine { x: framePath.w; y: 0 }
                    PathLine { x: framePath.w; y: framePath.h }
                    PathLine { x: 0; y: framePath.h }
                    PathLine { x: 0; y: 0 }
                    // recorte das janelas, no sentido horário a partir do canto superior esquerdo
                    PathMove { x: framePath.x0 + framePath.r; y: framePath.y0 }
                    PathLine { x: framePath.x1 - framePath.r; y: framePath.y0 }
                    PathArc { x: framePath.x1; y: framePath.y0 + framePath.r; radiusX: framePath.r; radiusY: framePath.r }
                    PathLine { x: framePath.x1; y: framePath.y1 - framePath.r }
                    PathArc { x: framePath.x1 - framePath.r; y: framePath.y1; radiusX: framePath.r; radiusY: framePath.r }
                    PathLine { x: framePath.x0 + framePath.r; y: framePath.y1 }
                    PathArc { x: framePath.x0; y: framePath.y1 - framePath.r; radiusX: framePath.r; radiusY: framePath.r }
                    PathLine { x: framePath.x0; y: framePath.y0 + framePath.r }
                    PathArc { x: framePath.x0 + framePath.r; y: framePath.y0; radiusX: framePath.r; radiusY: framePath.r }
                }
            }
        }
    }
    // faixas invisíveis que só reservam o espaço do contorno (as janelas não entram nele)
    component FrameReserve: PanelWindow {
        property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-contorno"
        exclusiveZone: root.frameWidth
        implicitWidth: root.frameWidth
        implicitHeight: root.frameWidth
        mask: Region {}
        color: "transparent"
    }
    Variants { model: Quickshell.screens; FrameReserve { anchors { top: true; left: true; right: true } } }
    Variants { model: Quickshell.screens; FrameReserve { anchors { right: true; top: true; bottom: true } } }
    Variants { model: Quickshell.screens; FrameReserve { anchors { bottom: true; left: true; right: true } } }

    // ── Barra lateral ──────────────────────────────────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: barWindow
            property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true }
            implicitWidth: root.barWidth
            exclusiveZone: root.barWidth
            color: "transparent"

            // tooltip ao lado do ícone sob o mouse (ancorada na janela, ver root.hover)
            PopupWindow {
                id: tooltip
                visible: root.barHover !== "" && root.hoverWindow === barWindow && tipText.text !== "" && !root.anyPopup && !appMenu.open
                anchor.window: barWindow
                anchor.rect.x: root.barWidth + 6
                anchor.rect.y: root.hoverY
                anchor.rect.width: 1
                anchor.rect.height: 1
                anchor.edges: Edges.Right
                anchor.gravity: Edges.Right
                implicitWidth: tipText.implicitWidth + 24
                implicitHeight: 30
                color: "transparent"
                onVisibleChanged: if (visible) anchor.updateAnchor()
                Connections { target: root; function onHoverYChanged() { if (tooltip.visible) tooltip.anchor.updateAnchor() } }
                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    radius: 6
                    border.color: Theme.surface1
                    border.width: 1
                    Text {
                        id: tipText
                        anchors.centerIn: parent
                        text: root.tooltipText()
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            Rectangle {
                id: barBg
                width: root.barWidth
                height: parent.height
                color: Theme.bgHard

                // clique no fundo da barra fecha popups – atrás dos ícones
                MouseArea {
                    anchors.fill: parent
                    enabled: root.anyPopup
                    onClicked: root.closePopups()
                }

                // ── Topo: SO + workspaces ──────────────────
                ColumnLayout {
                    id: topCol
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 0
                    spacing: 4

                    BarIcon {
                        icon: ""   // logo do Fedora
                        size: 22
                        tint: Theme.accent
                        Layout.preferredHeight: 32
                        onClicked: appLauncher.toggle()
                    }
                    Separator {}
                    // workspaces 1..10 – só os que têm janelas e o ativo
                    ColumnLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8
                        Repeater {
                            model: 10
                            Rectangle {
                                required property int index
                                readonly property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1) ?? null
                                readonly property bool isActive: root.focusedWs === index + 1
                                visible: ws !== null || isActive
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 26
                                implicitHeight: 22
                                radius: 4
                                color: isActive ? Theme.accent : wsMouse.containsMouse ? Theme.surface1 : Theme.surface0
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: index + 1
                                    color: parent.isActive ? Theme.onAccent : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: 13
                                    font.bold: true
                                }
                                MouseArea {
                                    id: wsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (index + 1) + '" })')
                                }
                            }
                        }
                        WheelHandler {
                            onWheel: event => {
                                if (event.angleDelta.y > 0) Hyprland.dispatch('hl.dsp.focus({ workspace = "e-1" })')
                                else if (event.angleDelta.y < 0) Hyprland.dispatch('hl.dsp.focus({ workspace = "e+1" })')
                            }
                        }
                    }
                }

                // ── Centro: apps do workspace atual ────────
                Item {
                    anchors.top: topCol.bottom
                    anchors.bottom: bottomCol.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    clip: true

                    Column {
                        anchors.centerIn: parent
                        spacing: 4
                        Repeater {
                            model: root.workspaceClients
                            Item {
                                id: appItem
                                required property var modelData
                                readonly property bool isActive: modelData.address === root.hyprWindowAddress
                                readonly property string iconPath: root.appIconPath(modelData.class)
                                width: root.barWidth
                                height: 40
                                // indicador do app em foco, colado na borda
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 3
                                    height: appItem.isActive ? 22 : appMouse.containsMouse ? 10 : 0
                                    radius: 2
                                    color: Theme.accent
                                    Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 36; height: 36; radius: width / 2
                                    color: appItem.isActive ? Theme.surface0 : appMouse.containsMouse ? Theme.surface0 : "transparent"
                                }
                                IconImage {
                                    id: appIcon
                                    anchors.centerIn: parent
                                    implicitSize: 22   // cabe inteiro dentro do círculo
                                    source: appItem.iconPath
                                    visible: appItem.iconPath !== "" && status === Image.Ready
                                    scale: appMouse.pressed ? 0.9 : 1
                                    Behavior on scale { NumberAnimation { duration: 80 } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !appIcon.visible
                                    text: root.glyphFor(appItem.modelData.class)
                                    color: appItem.isActive ? Theme.accent : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: 20
                                }
                                MouseArea {
                                    id: appMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                    onClicked: mouse => {
                                        var a = appItem.modelData.address
                                        if (mouse.button === Qt.LeftButton) Hyprland.dispatch('hl.dsp.focus({ window = "address:' + a + '" })')
                                        else if (mouse.button === Qt.MiddleButton) Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + a + '" })')
                                        else appMenu.openFor(barWindow, appItem.mapToItem(null, 0, appItem.height / 2).y, a, appItem.modelData.class, appItem.modelData.title)
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Pé: mídia, bandeja, utilidades, hora, botões ─
                ColumnLayout {
                    id: bottomCol
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottomMargin: 0
                    spacing: 2

                    // player de mídia (só com algo aberto)
                    BarIcon {
                        visible: root.activePlayer !== null
                        hoverName: "media"
                        icon: root.activePlayer && root.activePlayer.isPlaying ? "󰎆" : "󰏤"
                        tint: root.activePlayer && root.activePlayer.isPlaying ? Theme.accent : Theme.sub
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) { if (root.activePlayer && root.activePlayer.canTogglePlaying) root.activePlayer.togglePlaying() }
                            else if (mouse.button === Qt.MiddleButton) { if (root.activePlayer && root.activePlayer.canGoNext) root.activePlayer.next() }
                            else root.togglePopup("media", barWindow.modelData.name)
                        }
                        onWheel: wheel => {
                            var p = root.activePlayer
                            if (!p) return
                            if (wheel.angleDelta.y > 0 && p.canGoPrevious) p.previous()
                            else if (wheel.angleDelta.y < 0 && p.canGoNext) p.next()
                        }
                    }

                    // bandeja do sistema
                    Repeater {
                        model: SystemTray.items
                        Item {
                            id: trayItem
                            required property var modelData
                            Layout.preferredWidth: root.barWidth
                            Layout.preferredHeight: 25
                            Rectangle {
                                anchors.centerIn: parent
                                width: 28; height: 23; radius: 6
                                color: trayMouse.containsMouse ? Theme.surface0 : "transparent"
                            }
                            IconImage {
                                anchors.centerIn: parent
                                implicitSize: 15
                                source: trayItem.modelData.icon
                            }
                            MouseArea {
                                id: trayMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                readonly property string tipName: "tray:" + (trayItem.modelData.tooltipTitle || trayItem.modelData.title || trayItem.modelData.id)
                                onEntered: root.hover(tipName, trayItem)
                                onExited: root.unhover(tipName)
                                onClicked: mouse => {
                                    var it = trayItem.modelData
                                    if (mouse.button === Qt.MiddleButton) it.secondaryActivate()
                                    else if (mouse.button === Qt.RightButton || it.onlyMenu) {
                                        // menu nativo posicionado pela janela da barra (sem ancorar no item, ver root.hover)
                                        if (it.hasMenu) { root.unhover(tipName); it.display(barWindow, root.barWidth + 6, trayItem.mapToItem(null, 0, 0).y) }
                                    }
                                    else it.activate()
                                }
                                onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
                            }
                        }
                    }

                    Separator { visible: root.activePlayer !== null || SystemTray.items.values.length > 0 }

                    BarIcon {
                        hoverName: "net"
                        icon: root.networkIcon
                        tint: root.networkType === "disconnected" ? Theme.red : Theme.fg
                        onClicked: root.togglePopup("cc", barWindow.modelData.name)
                    }
                    BarIcon {
                        hoverName: "vol"
                        icon: root.pulseIcon
                        tint: root.volumeMuted ? Theme.sub : Theme.fg
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) pulsemixerProc.running = true
                            else if (mouse.button === Qt.MiddleButton) root.toggleMute()
                            else root.togglePopup("cc", barWindow.modelData.name)
                        }
                        onWheel: wheel => root.setVolume(root.volumeLevel + (wheel.angleDelta.y > 0 ? 5 : -5))
                    }
                    BarIcon {
                        id: battIcon
                        hoverName: "batt"
                        icon: root.batteryIcon
                        tint: root.batteryCharging ? Theme.green : Theme.fg
                        onClicked: root.togglePopup("cc", barWindow.modelData.name)
                        // pisca em vermelho com bateria crítica
                        SequentialAnimation on tint {
                            loops: Animation.Infinite
                            running: root.batteryLow
                            ColorAnimation { to: Theme.red; duration: 500 }
                            ColorAnimation { to: Theme.fg; duration: 500 }
                        }
                    }

                    Separator {}

                    // notificações: número de novas embaixo; direito liga/desliga o não perturbe
                    BarIcon {
                        hoverName: "notif"
                        icon: notifs.dnd ? "󰂛" : notifs.unread > 0 ? "󰂞" : "󰂚"
                        label: notifs.unread > 0 ? String(notifs.unread) : ""
                        tint: notifs.dnd ? Theme.sub : notifs.unread > 0 ? Theme.accent : Theme.fg
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) notifs.setDnd(!notifs.dnd)
                            else if (mouse.button === Qt.MiddleButton) notifs.clearAll()
                            else root.togglePopup("notif", barWindow.modelData.name)
                        }
                    }
                    BarIcon {
                        hoverName: "power"
                        Layout.preferredHeight: 26
                        icon: "󰐥"
                        tint: Theme.red
                        onClicked: appLauncher.show(">")
                    }
                }
            }
        }
    }
}
