import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

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

    // ── Control Center (único widget para wifi/volume/bateria) ─
    property bool controlCenterVisible: false
    property bool calendarVisible: false

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
        command: ["sh", "-c", "ssid=$(LANGUAGE=C nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '$1==\"yes\"{print $2; exit}'); if [ -n \"$ssid\" ]; then echo \"wifi:$ssid\"; elif LANGUAGE=C nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q 'wifi:connected'; then echo \"wifi:Wi-Fi\"; elif LANGUAGE=C nmcli -t -f TYPE,STATE dev 2>/dev/null | grep -q 'ethernet:connected'; then echo \"ethernet:\"; else echo \"disconnected:\"; fi"]
        stdout: SplitParser {
            onRead: data => {
                if(!data) return
                var d=data.trim()
                if(d.startsWith("wifi:")){ networkIcon="󰤨 "; networkTooltip=d.substring(5) }
                else if(d.startsWith("ethernet")){ networkIcon=" "; networkTooltip="Ethernet" }
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
    Timer { interval: 2000; running: true; repeat: true; onTriggered: volProc.running=true }
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
        setVolumeProc.command = ["sh","-c", "wpctl set-volume @DEFAULT_AUDIO_SINK@ " + (level/100).toFixed(2)]
        setVolumeProc.running = true
        // refresh leitura canônica via volProc
        refreshVolTimer.restart()
    }
    function toggleMute() {
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
            visible: root.controlCenterVisible
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true; right: true }
            margins { top: 44; right: 8 }
            implicitWidth: 540
            implicitHeight: 160
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: root.controlCenterVisible = false
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                Loader {
                    id: ccLoader
                    anchors.centerIn: parent
                    width: 520; height: 140
                    source: Qt.resolvedUrl("modules/ControlCenter.qml")
                    onLoaded: {
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
            visible: root.calendarVisible
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { top: true }
            margins { top: 44 }
            implicitWidth: 360
            implicitHeight: 400
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                onClicked: root.calendarVisible = false
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                Loader {
                    id: calLoader
                    anchors.centerIn: parent
                    width: 340; height: 380
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
                                    onClicked: Hyprland.dispatch("workspace " + (index+1))
                                }
                                // wheel: waybar on-scroll-up/down e+1/e-1
                                WheelHandler {
                                    onWheel: event => {
                                        if(event.angleDelta.y > 0) Hyprland.dispatch("workspace e+1")
                                        else if(event.angleDelta.y < 0) Hyprland.dispatch("workspace e-1")
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
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.calendarVisible = !root.calendarVisible
                            if (root.calendarVisible) root.controlCenterVisible = false
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
                    }
                    // memory " {}%"
                    Text {
                        text: " " + root.memUsage + "%"
                        color: root.colText
                        font.family: root.fontFamily
                        font.pixelSize: root.fontSize
                        font.bold: true
                        Layout.rightMargin: 6
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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.controlCenterVisible = !root.controlCenterVisible
                                if (root.controlCenterVisible) root.calendarVisible = false
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
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) pulsemixerProc.running = true
                                else {
                                    root.controlCenterVisible = !root.controlCenterVisible
                                    if (root.controlCenterVisible) root.calendarVisible = false
                                }
                            }
                            // scroll sobre ícone altera volume (waybar on-scroll?)
                            onWheel: wheel => {
                                if (wheel.angleDelta.y > 0) setVolumeProc.command = ["sh","-c","wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && wpctl get-volume @DEFAULT_AUDIO_SINK@"]; else setVolumeProc.command = ["sh","-c","wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && wpctl get-volume @DEFAULT_AUDIO_SINK@"]; setVolumeProc.running = true
                            }
                        }
                    }
                    // battery "{icon}" apenas ícone na barra (sem %)
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
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.controlCenterVisible = !root.controlCenterVisible
                                if (root.controlCenterVisible) root.calendarVisible = false
                            }
                        }
                    }
                    // custom/blankSpace " "
                    Text { text: " "; color: root.colText; font.pixelSize: root.fontSize; Layout.rightMargin: 2 }
                }
                // clique no fundo da barra fecha popups (quando visíveis) – atrás dos ícones
                MouseArea {
                    anchors.fill: parent
                    enabled: root.controlCenterVisible || root.calendarVisible
                    z: -1
                    propagateComposedEvents: true
                    onClicked: { root.controlCenterVisible = false; root.calendarVisible = false }
                }
            }
        }
    }

    // ── Dock inferior OSX – vidro fosco catppuccin, auto-hide na borda inferior ─
    // trigger invisível 12px na borda inferior para mostrar a dock (funciona mesmo em workspace vazio)
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
            implicitHeight: 12
            color: "transparent"
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: root.dockVisible = true
            }
        }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            property var modelData
            screen: modelData
            // dock só aparece quando hover na borda ou na própria dock
            visible: root.dockVisible || root.dockHovered
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors { bottom: true }
            margins { bottom: 8 }
            implicitWidth: 700
            implicitHeight: 88
            color: "transparent"
            // auto-hide timer
            Timer {
                id: dockHideTimer
                interval: 250
                repeat: false
                onTriggered: {
                    if (!root.dockHovered) root.dockVisible = false
                }
            }
            onVisibleChanged: {
                if (visible) dockHideTimer.stop()
                else dockHideTimer.stop()
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 16, dockLoader.implicitWidth + 16)
                height: 80
                radius: 18
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
                    function onRequestFocusClient(addr) { Hyprland.dispatch("focuswindow address:" + addr) }
                    function onRequestCloseClient(addr) { Hyprland.dispatch("closewindow address:" + addr) }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: { root.dockHovered = true; root.dockVisible = true; dockHideTimer.stop() }
                    onExited: { root.dockHovered = false; dockHideTimer.restart() }
                    // clique no fundo da dock não fecha, apenas consome
                    onClicked: mouse.accepted = true
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
