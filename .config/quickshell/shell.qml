import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "modules/holidays.js" as Holidays

ShellRoot {
    id: root

    // ── Catppuccin Mocha (mocha.css) ───────────────────────
    property color colBase: "#1e1e2e"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colText: "#cdd6f4"
    property color colMauve: "#cba6f7"
    property color colRed: "#f38ba8"
    property color colOverlay0: "#6c7086"
    // waybar window bg rgba(30,30,46,0.7) → #B31e1e2e
    property color colBarBg: "#B31e1e2e"

    property string fontFamily: "JetBrainsMono Nerd Font"
    // waybar: 18px → solicitado 19px (OS 22)
    property int fontSize: 19
    property int fontSizeLauncher: 22
    property int fontSizeWorkspaces: 18

    // ── State ──────────────────────────────────────────────
    property int cpuUsage: 0
    property int memUsage: 0
    property string hyprWindowTitle: ""
    property string hyprWindowClass: ""
    property string hyprWindowIcon: " "
    property string networkIcon: "󰤭 "
    property string networkTooltip: ""
    property string networkType: "disconnected"   // wifi | ethernet | disconnected
    property string networkSsid: ""
    property int networkSignal: 0
    property string networkIp: ""
    property int volumeLevel: 35
    property bool volumeMuted: false
    property string pulseIcon: " "
    property int batteryCapacity: 100
    property string batteryStatus: "Not charging"
    property string batteryIcon: " "
    property bool batteryCharging: false

    property var lastCpuIdle: 0
    property var lastCpuTotal: 0

    // ── Dock state ─────────────────────────────────────────
    property bool dockHovered: false
    property bool dockVisible: false
    // ícone da barra sob o mouse ("net" | "vol" | "batt" | "") – mostra tooltip
    property string barHover: ""
    // dock sempre visível quando workspace atual está vazio
    property bool isWorkspaceEmpty: {
        if (!Hyprland || !Hyprland.focusedWorkspace) return false
        var fid = Hyprland.focusedWorkspace.id
        if (!root.dockClients || root.dockClients.length === 0) return true
        for (var i = 0; i < root.dockClients.length; i++) {
            if (root.dockClients[i].workspace === fid) return false
        }
        return true
    }

    // ── Control Center (único widget para wifi/volume/bateria) ─
    property bool controlCenterVisible: false
    property bool sysMonVisible: false
    property bool calendarVisible: false

    // ── Volume ao vivo via PipeWire ───────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var pwSink: Pipewire.defaultAudioSink
    readonly property bool pwReady: pwSink !== null && pwSink.ready && pwSink.audio !== null
    function syncVolume() {
        if (!pwReady) return
        volumeLevel = Math.round(pwSink.audio.volume * 100)
        volumeMuted = pwSink.audio.muted
        updatePulseIcon()
    }
    onPwReadyChanged: syncVolume()
    Connections {
        target: root.pwReady ? root.pwSink.audio : null
        function onVolumeChanged() { root.syncVolume() }
        function onMutedChanged() { root.syncVolume() }
    }

    // ── Bateria: extras do UPower (tempo restante, potência) ─
    readonly property var upDev: UPower.displayDevice
    function formatDuration(sec) {
        if (!sec || sec <= 0) return ""
        var h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
        return h > 0 ? h + "h" + (m < 10 ? "0" : "") + m : m + " min"
    }
    readonly property string batteryTimeText: {
        if (!upDev || !upDev.ready) return ""
        if (batteryCharging && upDev.timeToFull > 0) return formatDuration(upDev.timeToFull) + " para carregar"
        if (!batteryCharging && upDev.timeToEmpty > 0) return formatDuration(upDev.timeToEmpty) + " restantes"
        return ""
    }
    readonly property real batteryRate: upDev && upDev.ready ? Math.abs(upDev.changeRate) : 0

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
    // só coleta enquanto o painel está aberto ou o mouse está na CPU/memória
    Timer {
        interval: 2000; repeat: true; triggeredOnStart: true
        running: root.sysMonVisible || root.barHover === "cpu" || root.barHover === "mem"
        onTriggered: if (!sysInfoProc.running) sysInfoProc.running = true
        onRunningChanged: if (!running) { root._lastRx = -1; root.netRxRate = 0; root.netTxRate = 0 }
    }
    // histórico de uso de CPU (60 amostras de 1s) para o gráfico
    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: { var h = root.cpuHistory.slice(-59); h.push(root.cpuUsage); root.cpuHistory = h }
    }
    Process { id: killProc }
    Process { id: missionCenterProc; command: ["flatpak", "run", "io.missioncenter.MissionCenter"] }

    // ── Helpers ────────────────────────────────────────────
    function updatePulseIcon() {
        if (volumeMuted) { pulseIcon = " "; return }
        if (volumeLevel <= 0) pulseIcon = " "
        else if (volumeLevel < 33) pulseIcon = " "
        else if (volumeLevel < 66) pulseIcon = " "
        else pulseIcon = " "
    }
    function updateBatteryIcon() {
        var chargingMark = batteryCharging ? "󱐋" : ""
        var base = " "
        if (batteryCapacity >= 80) base = " "
        else if (batteryCapacity >= 60) base = " "
        else if (batteryCapacity >= 40) base = " "
        else if (batteryCapacity >= 15) base = " "
        else base = " "
        // waybar: format-charging "{icon}󱐋{capacity}%" , format "{icon}"
        // replicamos só ícone; percent no tooltip se warning/critical
        if (batteryCharging) batteryIcon = base + chargingMark
        else batteryIcon = base
    }
    function getAppIcon(cls) {
        if (!cls) return " "
        var c = cls.toLowerCase()
        if (c.indexOf("ghostty") !== -1) return " "
        if (c.indexOf("zen") !== -1 || c.indexOf("firefox") !== -1 || c.indexOf("chrome") !== -1 || c.indexOf("chromium") !== -1) return " "
        if (c.indexOf("code") !== -1 || c.indexOf("codium") !== -1) return " "
        if (c.indexOf("spotify") !== -1) return " "
        if (c.indexOf("zathura") !== -1) return " "
        if (c.indexOf("obsidian") !== -1) return " "
        if (c.indexOf("files") !== -1 || c.indexOf("nautilus") !== -1 || c.indexOf("cosmic-files") !== -1) return " "
        if (c.indexOf("missioncenter") !== -1 || c.indexOf("mission") !== -1) return " "
        if (c.indexOf("pavu") !== -1 || c.indexOf("pulsemixer") !== -1) return " "
        if (c.indexOf("dunst") !== -1) return " "
        if (c.indexOf("steam") !== -1) return " "
        return " "
    }

    // ── Processes ──────────────────────────────────────────
    // Launcher helper
    Process { id: launcherProc; command: ["wofi", "--show", "drun", "--columns", "1", "-I", "-s", "/home/raul/.config/wofi/style.css"] }
    Process { id: agsProc; command: ["ags", "toggle", "calendar"] }

    // Hypr window title + class + address (para ícone antes do título e dock highlight)
    property string hyprWindowAddress: ""
    Process {
        id: windowProc
        command: ["sh", "-c", "hyprctl activewindow -j | jq -r '[.title // empty, .class // empty, .address // empty] | @tsv'"]
        stdout: SplitParser {
            onRead: data => {
                if (data === null) return
                var t = data.trim()
                if (!t) return
                var parts = t.split("\t")
                hyprWindowTitle = (parts[0] || "").trim().substring(0,55)
                hyprWindowClass = (parts[1] || "").trim()
                hyprWindowIcon = getAppIcon(hyprWindowClass)
                hyprWindowAddress = (parts[2] || "").trim()
            }
        }
        Component.onCompleted: running = true
    }

    // CPU
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                var p = data.trim().split(/\s+/)
                var user=parseInt(p[1])||0, nice=parseInt(p[2])||0, sys=parseInt(p[3])||0
                var idle=parseInt(p[4])||0, iow=parseInt(p[5])||0, irq=parseInt(p[6])||0, sirq=parseInt(p[7])||0
                var total=user+nice+sys+idle+iow+irq+sirq
                var idleT=idle+iow
                if (root.lastCpuTotal>0) {
                    var td=total-root.lastCpuTotal, id=idleT-root.lastCpuIdle
                    if(td>0) root.cpuUsage=Math.round(100*(td-id)/td)
                }
                root.lastCpuTotal=total; root.lastCpuIdle=idleT
            }
        }
    }
    // Memory (waybar " {}%")
    Process {
        id: memProc
        command: ["sh", "-c", "free | awk '/Mem:/{printf \"%d\", $3/$2*100}'"]
        stdout: SplitParser { onRead: data => { if(data) memUsage=parseInt(data.trim())||0 } }
    }
    // Network – replica waybar: wifi 󰤨 / eth  / disc 󰤭 + tooltip SSID
    // igual wifiName.sh usa LANGUAGE=C (sem isso retorna sim/não e falha)
    Process {
        id: netProc
        // saída: tipo|ssid|sinal|ip (ver scripts/net-info.sh)
        command: [Quickshell.shellDir + "/scripts/net-info.sh"]
        stdout: SplitParser {
            onRead: data => {
                if(!data) return
                var f=data.trim().split("|")
                networkType=f[0]; networkSsid=f[1]||""; networkSignal=parseInt(f[2])||0; networkIp=f[3]||""
                if(networkType==="wifi"){
                    var s=networkSignal
                    networkIcon=(s>=80?"󰤨":s>=60?"󰤥":s>=40?"󰤢":s>=20?"󰤟":"󰤯")+" "
                    networkTooltip=networkSsid||"Wi-Fi"
                }
                else if(networkType==="ethernet"){ networkIcon=" "; networkTooltip="Ethernet" }
                else { networkIcon="󰤭 "; networkTooltip="Desconectado" }
            }
        }
    }
    // Pulseaudio – waybar pulseaudio format "{icon}" + muted " "
    Process {
        id: volProc
        command: ["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; cat /proc/asound/cards 2>/dev/null | head -1 >/dev/null; echo \"__END__\""]
        stdout: SplitParser {
            onRead: data => {
                if(!data || data.indexOf("__END__")!==-1) return
                if(!data) return
                var m=data.trim().match(/Volume:\s*([\d.]+)/)
                if(m){ volumeLevel=Math.round(parseFloat(m[1])*100); volumeMuted=data.indexOf("[MUTED]")!==-1; updatePulseIcon() }
            }
        }
    }
    // Battery – BAT0 ADP0, waybar icons ["","","","",""], charging 󱐋
    Process {
        id: battProc
        command: ["sh", "-c", "cap=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1); sta=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1); echo \"$cap|$sta\""]
        stdout: SplitParser {
            onRead: data => {
                if(!data) return
                var t=data.trim(); if(!t || t=="|") return
                var parts=t.split("|")
                var c=parseInt(parts[0]); if(!isNaN(c)) batteryCapacity=c
                batteryStatus=(parts[1]||"").trim()
                batteryCharging=(batteryStatus==="Charging" || batteryStatus==="Full")
                // plugged vs charging: waybar format-plugged same as charging
                if(batteryStatus==="Charging" || batteryStatus==="Full" || batteryStatus.indexOf("Charging")!==-1) batteryCharging=true
                else batteryCharging=false
                updateBatteryIcon()
            }
        }
    }
    Process { id: pulsemixerProc; command: ["ghostty", "-e", "/bin/zsh", "-c", "pulsemixer"] }
    Process { id: wifiClickProc; command: ["sh", "-c", "/home/raul/.config/waybar/wifiName.sh; nmcli dev wifi list 2>/dev/null | head -20"] }
    // Control Center actions
    Process { id: setVolumeProc }
    Process { id: toggleMuteProc }
    // Dock: todos os clientes (global, funciona mesmo em workspace vazio)
    property var dockClients: []
    Process {
        id: dockClientsProc
        command: ["sh", "-c", "hyprctl clients -j 2>/dev/null | jq -c '[.[] | {address: .address, class: .class, title: .title, workspace: .workspace.id}]'"]
        stdout: SplitParser {
            onRead: data => {
                if (!data) return
                try {
                    var arr = JSON.parse(data.trim())
                    // ordena por workspace id para dock
                    arr.sort(function(a,b){ return (a.workspace||99)-(b.workspace||99) })
                    root.dockClients = arr
                } catch(e) {}
            }
        }
    }

    // ── Timers (waybar intervals) ──────────────────────────
    Timer { interval: 1000; running: true; repeat: true; onTriggered: { cpuProc.running=true; memProc.running=true; battProc.running=true } } // cpu 1s mem 1s battery 1s
    Timer { interval: 5000; running: true; repeat: true; onTriggered: netProc.running=true }
    // fallback por polling só se o PipeWire não estiver disponível
    Timer { interval: 2000; running: !root.pwReady; repeat: true; onTriggered: volProc.running=true }
    Timer { interval: 200; running: true; repeat: true; onTriggered: { windowProc.running=true } }
    Timer { interval: 500; running: true; repeat: true; onTriggered: dockClientsProc.running=true }

    // Instant window/layout updates via Hyprland events
    Connections {
        target: Hyprland
        function onRawEvent(event){ windowProc.running=true; dockClientsProc.running=true }
    }

    Component.onCompleted: { cpuProc.running=true; memProc.running=true; netProc.running=true; volProc.running=true; battProc.running=true; dockClientsProc.running=true; updatePulseIcon(); updateBatteryIcon() }

    // ── Control Center popup overlay (único para wifi/volume/bateria) ─
    // Process já definidos acima controlam volume
    function setVolume(level) {
        level = Math.max(0, Math.min(100, level))
        if (pwReady) { pwSink.audio.volume = level / 100; return }
        setVolumeProc.command = ["sh","-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (level/100).toFixed(2)]
        setVolumeProc.running = true
        // refresh leitura canônica via volProc
        refreshVolTimer.restart()
    }
    function toggleMute() {
        if (pwReady) { pwSink.audio.muted = !pwSink.audio.muted; return }
        toggleMuteProc.command = ["sh","-c", "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"]
        toggleMuteProc.running = true
        refreshVolTimer.restart()
    }
    Timer { id: refreshVolTimer; interval: 250; repeat: false; onTriggered: volProc.running = true }

    // ── ControlCenter popup (abaixo da barra, não sobrepõe) ─
    // Criado antes da barra para stacking correto; margins.top compensa waybar (41) + bar (38) + gap 6 = 85 quando waybar ativo
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            screen: modelData
            id: ccWindow
            visible: root.controlCenterVisible
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            // teclado só enquanto digita a senha do wifi
            WlrLayershell.keyboardFocus: ccLoader.item && ccLoader.item.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            anchors { top: true; right: true }
            margins { top: 44; right: 8 }
            implicitWidth: ccLoader.item ? ccLoader.item.implicitWidth : 340
            implicitHeight: ccLoader.item ? ccLoader.item.implicitHeight : 200
            color: "transparent"
            // fecha ao clicar fora do painel
            HyprlandFocusGrab {
                windows: [ccWindow]
                active: ccWindow.visible
                onCleared: root.controlCenterVisible = false
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                Loader {
                    id: ccLoader
                    anchors.fill: parent
                    source: Qt.resolvedUrl("modules/ControlCenter.qml")
                    onLoaded: {
                        item.networkType = Qt.binding(function() { return root.networkType })
                        item.networkSsid = Qt.binding(function() { return root.networkSsid })
                        item.networkSignal = Qt.binding(function() { return root.networkSignal })
                        item.networkIp = Qt.binding(function() { return root.networkIp })
                        item.batteryTimeText = Qt.binding(function() { return root.batteryTimeText })
                        item.batteryRate = Qt.binding(function() { return root.batteryRate })
                        item.volumeLevel = Qt.binding(function() { return root.volumeLevel })
                        item.volumeMuted = Qt.binding(function() { return root.volumeMuted })
                        item.networkIcon = Qt.binding(function() { return root.networkIcon })
                        item.networkTooltip = Qt.binding(function() { return root.networkTooltip })
                        item.batteryIcon = Qt.binding(function() { return root.batteryIcon })
                        item.batteryCapacity = Qt.binding(function() { return root.batteryCapacity })
                        item.batteryStatus = Qt.binding(function() { return root.batteryStatus })
                        item.batteryCharging = Qt.binding(function() { return root.batteryCharging })
                        item.fontFamily = root.fontFamily
                        item.colText = root.colText
                        item.colSurface0 = root.colSurface0
                        item.colMauve = root.colMauve
                        item.colBarBg = root.colBase
                    }
                }
                Connections {
                    target: ccLoader.item
                    function onRequestSetVolume(lvl) { root.setVolume(lvl) }
                    function onRequestToggleMute() { root.toggleMute() }
                    function onRequestRefresh() { netProc.running = true; volProc.running = true; battProc.running = true }
                }
            }
        }
    }

    // ── Calendar popup (centro, abaixo da barra) ─
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            screen: modelData
            id: calWindow
            visible: root.calendarVisible
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true }
            margins { top: 44 }
            implicitWidth: calLoader.item ? calLoader.item.implicitWidth : 336
            implicitHeight: calLoader.item ? calLoader.item.implicitHeight : 420
            color: "transparent"
            HyprlandFocusGrab {
                windows: [calWindow]
                active: calWindow.visible
                onCleared: root.calendarVisible = false
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                Loader {
                    id: calLoader
                    anchors.fill: parent
                    Connections {
                        target: root
                        function onCalendarOpened() { if (calLoader.item) calLoader.item.goToday() }
                    }
                    source: Qt.resolvedUrl("modules/CalendarWidget.qml")
                    onLoaded: {
                        item.fontFamily = root.fontFamily
                        item.colText = root.colText
                        item.colSurface0 = root.colSurface0
                        item.colSurface1 = root.colSurface1
                        item.colMauve = root.colMauve
                        item.colBarBg = root.colBase
                    }
                }
            }
        }
    }

    // ── Painel do sistema (abre pela CPU/memória) ──────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: smWindow
            property var modelData
            screen: modelData
            visible: root.sysMonVisible
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; right: true }
            margins { top: 44; right: 8 }
            implicitWidth: smLoader.item ? smLoader.item.implicitWidth : 360
            implicitHeight: smLoader.item ? smLoader.item.implicitHeight : 300
            color: "transparent"
            HyprlandFocusGrab {
                windows: [smWindow]
                active: smWindow.visible
                onCleared: root.sysMonVisible = false
            }
            Loader {
                id: smLoader
                anchors.fill: parent
                source: Qt.resolvedUrl("modules/SystemMonitor.qml")
                onLoaded: {
                    item.info = Qt.binding(function() { return root.sysInfo })
                    item.cpuUsage = Qt.binding(function() { return root.cpuUsage })
                    item.cpuHistory = Qt.binding(function() { return root.cpuHistory })
                    item.rxRate = Qt.binding(function() { return root.netRxRate })
                    item.txRate = Qt.binding(function() { return root.netTxRate })
                    item.fontFamily = root.fontFamily
                    item.colBarBg = root.colBase
                }
            }
            Connections {
                target: smLoader.item
                function onRequestKill(pid) { killProc.command = ["kill", String(pid)]; killProc.running = true; sysInfoProc.running = true }
                function onRequestOpenMonitor() { missionCenterProc.running = true; root.sysMonVisible = false }
            }
        }
    }

    // calendário reabre sempre no mês atual
    onCalendarVisibleChanged: if (calendarVisible) calendarOpened()
    signal calendarOpened()

    // ── Tooltip do relógio ─────────────────────────────────
    property date clockNow: new Date()
    function clockTooltipText() {
        var d = clockNow
        var wd = ["Domingo","Segunda-feira","Terça-feira","Quarta-feira","Quinta-feira","Sexta-feira","Sábado"][d.getDay()]
        var mo = ["janeiro","fevereiro","março","abril","maio","junho","julho","agosto","setembro","outubro","novembro","dezembro"][d.getMonth()]
        var txt = "󰃭  " + wd + ", " + d.getDate() + " de " + mo + "  ·  semana " + Holidays.isoWeek(d)
        var today = Holidays.holidayOn(d)
        if (today) return txt + "  ·  hoje é feriado: " + today.name
        var next = Holidays.upcoming(d, 1)[0]
        if (next) txt += "  ·  próximo feriado: " + Qt.formatDate(next.date, "dd/MM") + " " + next.name + " (" + Holidays.relative(next.daysUntil) + ")"
        return txt
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.barHover === "clock" && !root.calendarVisible
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true }
            margins { top: 44 }
            implicitWidth: clockTip.implicitWidth + 24
            implicitHeight: 32
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                color: root.colBase
                radius: 10
                border.color: root.colSurface1
                border.width: 1
                Text {
                    id: clockTip
                    anchors.centerIn: parent
                    text: root.clockTooltipText()
                    color: root.colText
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }

    // ── Tooltip dos ícones da barra (wifi / volume / bateria) ─
    function barTooltipText() {
        if (barHover === "net") {
            if (networkType === "wifi") return "󰤨  " + networkSsid + "  ·  sinal " + networkSignal + "%" + (networkIp ? "  ·  " + networkIp : "")
            if (networkType === "ethernet") return "  Ethernet" + (networkIp ? "  ·  " + networkIp : "")
            return "󰤭  Sem conexão"
        }
        if (barHover === "vol") {
            var dev = pwSink ? (pwSink.nickname || pwSink.description || "") : ""
            return (volumeMuted ? "󰝟  Mudo" : "󰕾  " + volumeLevel + "%") + (dev ? "  ·  " + dev : "") + "   (rolar ajusta)"
        }
        if (barHover === "cpu") {
            var c = sysInfo ? sysInfo.cpu : null
            return "  CPU " + cpuUsage + "%" + (c && c.temp !== null ? "  ·  " + c.temp + "°C" : "") + (c && c.freq ? "  ·  " + (c.freq / 1000).toFixed(1) + " GHz" : "")
        }
        if (barHover === "mem") {
            if (!sysInfo) return "  RAM " + memUsage + "%"
            var m = sysInfo.mem, used = (m.total - m.available) / 1048576
            return "  RAM " + used.toFixed(1) + " / " + (m.total / 1048576).toFixed(1) + " GB  ·  " + memUsage + "%"
        }
        if (barHover === "batt") {
            var st = batteryStatus === "Charging" ? "carregando" : batteryStatus === "Discharging" ? "descarregando" : batteryStatus === "Full" ? "carga completa" : batteryStatus.toLowerCase()
            return "󰁹  " + batteryCapacity + "%  ·  " + st + (batteryTimeText ? "  ·  " + batteryTimeText : "")
        }
        return ""
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.barHover !== "" && root.barHover !== "clock" && !root.controlCenterVisible && !root.sysMonVisible
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; right: true }
            margins { top: 44; right: 8 }
            implicitWidth: tipText.implicitWidth + 24
            implicitHeight: 32
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                color: root.colBase
                radius: 10
                border.color: root.colSurface1
                border.width: 1
                Text {
                    id: tipText
                    anchors.centerIn: parent
                    text: root.barTooltipText()
                    color: root.colText
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }

    // ── Bar ────────────────────────────────────────────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: barWindow
            property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 38
            color: "transparent"
            // waybar: margin 0 10, bg rgba(30,30,46,0.7), no radius
            Rectangle {
                anchors.fill: parent
                color: root.colBarBg
                // ── Left / Center / Right ──────────────────
                // Left
                RowLayout {
                    id: leftRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 0
                    spacing: 7  // waybar spacing 7
                    // launcher – Fedora (era ) símbolo OS maior 32px que o resto 19px
                    Text {
                        text: " "
                        color: root.colText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSizeLauncher
                        font.bold: true
                        Layout.leftMargin: 15
                        Layout.rightMargin: -6
                        Layout.alignment: Qt.AlignVCenter
                        MouseArea { anchors.fill: parent; onClicked: launcherProc.running=true; cursorShape: Qt.PointingHandCursor }
                    }
                    // workspaces 1..10 – só mostra se tem janelas ou é o ativo (vazios ocultos)
                    RowLayout {
                        spacing: 0
                        Layout.leftMargin: 0
                        Repeater {
                            model: 10
                            Rectangle {
                                // waybar #workspaces button { padding 1px 5px; margin 0 5px; radius 5; bg surface0, active mauve }
                                property var ws: Hyprland.workspaces.values.find(w => w.id === index+1) ?? null
                                property bool isActive: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === (index+1)
                                property bool hasWindows: ws !== null
                                visible: hasWindows || isActive
                                Layout.preferredWidth: visible ? 22 : 0
                                Layout.preferredHeight: 22
                                Layout.leftMargin: visible ? 7 : 0
                                color: isActive ? root.colMauve : root.colSurface0
                                radius: 5
                                Text {
                                    anchors.centerIn: parent
                                    text: (index+1).toString()
                                    color: parent.isActive ? root.colSurface0 : root.colText
                                    font.family: root.fontFamily
                                    font.pixelSize: root.fontSizeWorkspaces
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Hyprland.dispatch('hl.dsp.focus({ workspace = "' + (index+1) + '" })')
                                }
                                // wheel: waybar on-scroll-up/down e+1/e-1
                                WheelHandler {
                                    onWheel: event => {
                                        if(event.angleDelta.y > 0) Hyprland.dispatch('hl.dsp.focus({ workspace = "e+1" })')
                                        else if(event.angleDelta.y < 0) Hyprland.dispatch('hl.dsp.focus({ workspace = "e-1" })')
                                    }
                                }
                            }
                        }
                    }
                    // window icon + title – ícone da janela em foco antes do título
                    RowLayout {
                        spacing: 6
                        Layout.leftMargin: 10
                        Layout.maximumWidth: 420
                        Text {
                            text: root.hyprWindowIcon
                            color: root.colMauve
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize
                            font.bold: true
                            visible: root.hyprWindowTitle.length > 0
                        }
                        Text {
                            text: root.hyprWindowTitle
                            color: root.colText
                            font.family: root.fontFamily
                            font.pixelSize: root.fontSize - 2
                            font.bold: true
                            Layout.maximumWidth: 380
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }
                }

                // Center – clock "Dia %d | %H:%M" (click abre calendário)
                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(new Date(), "'Dia' dd '|' hh:mm")
                    color: root.colText
                    font.family: root.fontFamily
                    font.pixelSize: root.fontSize
                    font.bold: true
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { root.clockNow = new Date(); root.barHover = "clock" }
                        onExited: if (root.barHover === "clock") root.barHover = ""
                        onClicked: {
                            root.calendarVisible = !root.calendarVisible
                            if (root.calendarVisible) { root.controlCenterVisible = false; root.sysMonVisible = false }
                        }
                    }
                    Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.text = Qt.formatDateTime(new Date(), "'Dia' dd '|' hh:mm") }
                }

                // Right – cpu, memory, |, network, pulseaudio, battery, blankSpace
                RowLayout {
                    id: rightRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: 8
                    spacing: 0

                    // cpu " {usage}% "
                    Text {
                        text: " " + root.cpuUsage + "% "
                        color: root.colText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        Layout.rightMargin: 4
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.barHover = "cpu"
                            onExited: if (root.barHover === "cpu") root.barHover = ""
                            onClicked: {
                                root.sysMonVisible = !root.sysMonVisible
                                if (root.sysMonVisible) { root.controlCenterVisible = false; root.calendarVisible = false }
                            }
                        }
                    }
                    // memory " {}%"
                    Text {
                        text: " " + root.memUsage + "%"
                        color: root.colText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        Layout.rightMargin: 6
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.barHover = "mem"
                            onExited: if (root.barHover === "mem") root.barHover = ""
                            onClicked: {
                                root.sysMonVisible = !root.sysMonVisible
                                if (root.sysMonVisible) { root.controlCenterVisible = false; root.calendarVisible = false }
                            }
                        }
                    }
                    // custom/bar " | "
                    Text {
                        text: " | "
                        color: root.colText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        Layout.rightMargin: 4
                        opacity: 0.9
                    }
                    // network 󰤨 /  / 󰤭  (click abre ControlCenter único)
                    Text {
                        id: networkText
                        text: root.networkIcon
                        color: root.colText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        Layout.rightMargin: 6
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.barHover = "net"
                            onExited: if (root.barHover === "net") root.barHover = ""
                            onClicked: {
                                root.controlCenterVisible = !root.controlCenterVisible
                                if (root.controlCenterVisible) { root.calendarVisible = false; root.sysMonVisible = false }
                            }
                        }
                    }
                    // pulseaudio "{icon}"  (click abre ControlCenter único; right-click pulsemixer)
                    Text {
                        id: volumeText
                        text: root.pulseIcon
                        color: (root.batteryCapacity <= 10 && !root.batteryCharging) ? "#f53c3c" : root.colText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        Layout.rightMargin: 10
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.barHover = "vol"
                            onExited: if (root.barHover === "vol") root.barHover = ""
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) pulsemixerProc.running = true
                                else {
                                    root.controlCenterVisible = !root.controlCenterVisible
                                    if (root.controlCenterVisible) { root.calendarVisible = false; root.sysMonVisible = false }
                                }
                            }
                            // scroll sobre ícone altera volume (waybar on-scroll?)
                            onWheel: wheel => root.setVolume(root.volumeLevel + (wheel.angleDelta.y > 0 ? 5 : -5))
                        }
                    }
                    // battery "{icon}" apenas ícone na barra (hover mostra %)
                    Text {
                        id: battText
                        text: root.batteryIcon
                        color: root.colText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        Layout.rightMargin: 4
                        SequentialAnimation on color {
                            loops: Animation.Infinite
                            running: root.batteryCapacity <= 10 && !root.batteryCharging
                            ColorAnimation { from: root.colText; to: "#f53c3c"; duration: 500 }
                            ColorAnimation { from: "#f53c3c"; to: root.colText; duration: 500 }
                        }
                        MouseArea {
                            id: battMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.barHover = "batt"
                            onExited: if (root.barHover === "batt") root.barHover = ""
                            onClicked: {
                                root.controlCenterVisible = !root.controlCenterVisible
                                if (root.controlCenterVisible) { root.calendarVisible = false; root.sysMonVisible = false }
                            }
                        }
                    }
                    // custom/blankSpace " "
                    Text { text: " "; color: root.colText; font.pixelSize: root.fontSize; Layout.rightMargin: 2 }
                }
                // clique no fundo da barra fecha popups (quando visíveis) – atrás dos ícones
                MouseArea {
                    anchors.fill: parent
                    enabled: root.controlCenterVisible || root.calendarVisible || root.sysMonVisible
                    z: -1
                    propagateComposedEvents: true
                    onClicked: { root.controlCenterVisible = false; root.calendarVisible = false; root.sysMonVisible = false }
                }
            }
        }
    }

    // ── Dock inferior OSX – vidro fosco catppuccin, auto-hide na borda inferior ─
    // esconde a dock quando o mouse não está nem na borda nem sobre ela
    property bool dockTriggerHovered: false
    property bool dockMenuOpen: false
    Timer {
        id: dockHideTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (!root.dockHovered && !root.dockTriggerHovered && !root.dockMenuOpen) root.dockVisible = false
        }
    }
    // trigger invisível de 2px na borda inferior: só mostra a dock quando o mouse quase encosta na borda
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            screen: modelData
            visible: true
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors { bottom: true; left: true; right: true }
            margins { bottom: 0; left: 0; right: 0 }
            implicitHeight: 2
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: { root.dockTriggerHovered = true; root.dockVisible = true; dockHideTimer.stop() }
                onExited: { root.dockTriggerHovered = false; dockHideTimer.restart() }
            }
        }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            screen: modelData
            // sem nenhum app aberto a dock não aparece; com apps: hover, menu aberto ou workspace vazio
            visible: root.dockClients.length > 0
                     && (root.dockVisible || root.dockHovered || root.dockMenuOpen || root.isWorkspaceEmpty)
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { bottom: true }
            margins { bottom: 8 }
            // responsiva: largura ajusta ao conteúdo (sem espaço vazio)
            // margem extra para o zoom dos ícones no hover não ser cortado
            implicitWidth: dockBg.implicitWidth + 16
            implicitHeight: dockBg.implicitHeight + 16
            color: "transparent"

            Rectangle {
                id: dockBg
                anchors.centerIn: parent
                // pouco respiro (6px) entre os ícones e a borda da dock
                implicitWidth: dockLoader.implicitWidth > 0 ? dockLoader.implicitWidth + 12 : 76
                implicitHeight: dockLoader.implicitHeight > 0 ? dockLoader.implicitHeight + 12 : 76
                width: implicitWidth
                height: implicitHeight
                radius: 20 // raio dos ícones (14) + respiro (6): cantos concêntricos
                color: "#A61e1e2e" // catppuccin mocha base com alpha para vidro fosco
                border.color: "#313244"
                border.width: 1
                // sombra sutil
                Loader {
                    id: dockLoader
                    anchors.centerIn: parent
                    source: Qt.resolvedUrl("modules/Dock.qml")
                    onLoaded: {
                        item.fontFamily = root.fontFamily
                        item.colText = root.colText
                        item.colMauve = root.colMauve
                        item.colSurface0 = root.colSurface0
                        // passa lista global de clientes para funcionar em workspace vazio
                        item.dockClients = Qt.binding(function(){ return root.dockClients })
                        item.activeWindowAddress = Qt.binding(function(){ return root.hyprWindowAddress })
                    }
                }
                Connections {
                    target: dockLoader.item
                    function onRequestFocusClient(addr) { Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addr + '" })') }
                    function onRequestCloseClient(addr) { Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + addr + '" })') }
                    function onMenuOpenChanged() {
                        root.dockMenuOpen = dockLoader.item.menuOpen
                        if (!root.dockMenuOpen) dockHideTimer.restart()
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                    onEntered: { root.dockHovered = true; root.dockVisible = true; dockHideTimer.stop() }
                    onExited: { root.dockHovered = false; dockHideTimer.restart() }
                }
            }
            // manter visível enquanto mouse na trigger inferior? já tratado
        }
    }

    // fecha popups ao mudar de workspace
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            try { if (event && event.name && event.name.indexOf("workspace") !== -1) { root.controlCenterVisible = false; root.calendarVisible = false } } catch(e) {}
        }
    }
}
