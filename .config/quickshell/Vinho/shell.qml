//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "modules/holidays.js" as Holidays
import qs.modules

// Tema Vinho: barra inferior só de texto, quadrada, com launcher, notificações e painéis próprios.
// Feito para rodar num PC recém-instalado: só precisa do quickshell (janela, volume, bateria, mídia e
// bandeja vêm da API dele; rede usa o nmcli, que já vem no Fedora). Cores em modules/Theme.qml.
ShellRoot {
    id: root
    readonly property int barHeight: 26
    readonly property int popupGap: 4

    // Hyprland com config em Lua (>= 0.57) ou .conf: muda a sintaxe dos comandos
    FileView { id: luaFile; path: Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"; blockLoading: true; printErrors: false }
    readonly property bool lua: luaFile.text() !== ""
    function irPara(ws) { Hyprland.dispatch(lua ? 'hl.dsp.focus({ workspace = "' + ws + '" })' : "workspace " + ws) }

    // ── Popups: um por vez, na tela da barra clicada ───────
    property string popup: ""        // "" | cc | sm | cal | media | notif | tray
    property string ccPage: ""
    property string ccItem: ""       // item da barra que abriu a central (fica realçado)
    onPopupChanged: if (popup !== "cc") ccItem = ""
    // clicar em qualquer utilidade da barra abre a central na tela principal; de novo, fecha
    function toggleCentral(item, screenName) {
        togglePopup("cc", screenName, "")
        ccItem = popup === "cc" ? item : ""
    }
    property string popupScreen: ""
    readonly property string focusedScreen: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : Quickshell.screens[0].name
    signal panelPageRequested(string page)
    function togglePopup(name, screenName, page) {
        var p = page || ""
        if (popup === name && popupScreen === screenName && (name !== "cc" || p === "" || ccPage === p)) { popup = ""; return }
        popupScreen = screenName
        popup = name
        if (name === "cc") { ccPage = p; panelPageRequested(p) }
    }
    function openPanel(page) { popupScreen = focusedScreen; popup = "cc"; ccPage = page; panelPageRequested(page) }
    IpcHandler {
        target: "panel"
        function open(page: string): void { root.openPanel(page) }
        function close(): void { root.popup = "" }
        function calendario(): void { root.togglePopup("cal", root.focusedScreen) }
        function central(item: string): void { root.toggleCentral(item, root.focusedScreen) }
        function popup(nome: string): void { root.togglePopup(nome, root.focusedScreen) }
    }

    // ── CPU e memória ──────────────────────────────────────
    property int cpuUsage: 0
    property int memUsage: 0
    property var cpuHistory: []
    property real _idle: 0
    property real _total: 0
    Process {
        id: statProc
        command: ["awk", '/^cpu /{t=0; for(i=2;i<=9;i++) t+=$i; printf "%d %d ", $5+$6, t} /^MemTotal:/{m=$2} /^MemAvailable:/{printf "%d\\n", 100*(m-$2)/m}', "/proc/stat", "/proc/meminfo"]
        stdout: SplitParser {
            onRead: data => {
                var f = data.trim().split(" ").map(Number)
                if (f.length < 3) return
                if (root._total > 0 && f[1] > root._total) root.cpuUsage = Math.round(100 * (1 - (f[0] - root._idle) / (f[1] - root._total)))
                root._idle = f[0]; root._total = f[1]; root.memUsage = f[2]
                var h = root.cpuHistory.slice(-59); h.push(root.cpuUsage); root.cpuHistory = h
            }
        }
    }
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true; onTriggered: statProc.running = true }

    // ── Painel do sistema: só coleta enquanto aberto ───────
    property var sysInfo: null
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
                    var j = JSON.parse(data), now = Date.now()
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
        running: root.popup === "sm"
        onTriggered: if (!sysInfoProc.running) sysInfoProc.running = true
        onRunningChanged: if (!running) { root._lastRx = -1; root.netRxRate = 0; root.netTxRate = 0 }
    }

    // ── Rede ───────────────────────────────────────────────
    property string networkType: "disconnected"   // wifi | ethernet | disconnected
    property string networkSsid: ""
    property int networkSignal: 0
    property string networkIp: ""
    readonly property string networkIcon: networkType === "ethernet" ? "󰈀" : networkType !== "wifi" ? "󰤭"
        : networkSignal >= 80 ? "󰤨" : networkSignal >= 60 ? "󰤥" : networkSignal >= 40 ? "󰤢" : networkSignal >= 20 ? "󰤟" : "󰤯"
    Process {
        id: netProc
        command: [Quickshell.shellDir + "/scripts/net-info.sh"]
        stdout: SplitParser {
            onRead: data => {
                var f = (data || "").trim().split("|")
                if (f[0] === "") return
                root.networkType = f[0]; root.networkSsid = f[1] || ""; root.networkSignal = parseInt(f[2]) || 0; root.networkIp = f[3] || ""
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: netProc.running = true }

    // ── Volume (PipeWire) ──────────────────────────────────
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var pwSink: Pipewire.defaultAudioSink
    readonly property bool pwReady: pwSink !== null && pwSink.ready && pwSink.audio !== null
    readonly property int volumeLevel: pwReady ? Math.round(pwSink.audio.volume * 100) : 0
    readonly property bool volumeMuted: pwReady && pwSink.audio.muted
    function setVolume(level) { if (pwReady) pwSink.audio.volume = Math.max(0, Math.min(100, level)) / 100 }
    function toggleMute() { if (pwReady) pwSink.audio.muted = !pwSink.audio.muted }
    // barrinha só para mudanças reais feitas fora da central (não ao iniciar nem ao trocar a saída)
    property var osdSink: null
    property string osdKey: ""
    function syncOsd() {
        if (!pwReady) return
        var k = volumeLevel + "/" + volumeMuted
        if (osdSink === pwSink && osdKey !== k && popup !== "cc") volumeOsd.show(volumeLevel, volumeMuted)
        osdSink = pwSink; osdKey = k
    }
    onVolumeLevelChanged: Qt.callLater(syncOsd)
    onVolumeMutedChanged: Qt.callLater(syncOsd)
    onPwReadyChanged: Qt.callLater(syncOsd)

    // ── Bateria (UPower) ───────────────────────────────────
    readonly property var upDev: UPower.displayDevice
    readonly property bool hasBattery: upDev && upDev.ready && upDev.isPresent && upDev.isLaptopBattery
    readonly property int batteryCapacity: hasBattery ? Math.round(upDev.percentage * 100) : 100
    readonly property string batteryStatus: !hasBattery ? "Not charging" : upDev.state === UPowerDeviceState.Charging ? "Charging"
        : upDev.state === UPowerDeviceState.Discharging ? "Discharging" : upDev.state === UPowerDeviceState.FullyCharged ? "Full" : "Not charging"
    readonly property bool batteryCharging: batteryStatus === "Charging" || batteryStatus === "Full"
    readonly property bool onAc: hasBattery && batteryStatus !== "Discharging"
    readonly property real batteryRate: hasBattery ? Math.abs(upDev.changeRate) : 0
    readonly property string batteryIcon: (batteryCharging ? ["󰢟", "󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
        : ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"])[Math.max(0, Math.min(10, Math.round(batteryCapacity / 10)))]
    function formatDuration(sec) {
        var h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60)
        return h > 0 ? h + "h" + (m < 10 ? "0" : "") + m : m + " min"
    }
    readonly property string batteryTimeText: !hasBattery ? ""
        : batteryStatus === "Charging" && upDev.timeToFull > 0 ? formatDuration(upDev.timeToFull) + " para carregar"
        : batteryStatus === "Discharging" && upDev.timeToEmpty > 0 ? formatDuration(upDev.timeToEmpty) + " restantes" : ""

    // ── Mídia ──────────────────────────────────────────────
    readonly property var players: Mpris.players.values
    readonly property var activePlayer: players.find(p => p.isPlaying) ?? players[0] ?? null

    // ── Módulos ────────────────────────────────────────────
    Launcher {
        id: appLauncher
        lua: root.lua
        onPanelRequested: page => {
            if (page === "calendario") root.togglePopup("cal", root.focusedScreen)
            else if (page === "notificacoes") root.togglePopup("notif", root.focusedScreen)
            else root.openPanel(page)
        }
    }
    VolumeOsd { id: volumeOsd; fontFamily: Theme.font }
    DisplayManager {
        id: displayManager
        fontFamily: Theme.font
        onPendingChanged: if (pending) root.popup = ""
        onMenuRequested: root.openPanel("displays")
        onMenuCloseRequested: root.popup = ""
    }
    FanManager {
        id: fanManager
        watching: root.popup === "cc"
        onMenuRequested: root.openPanel("fans")
        onMenuCloseRequested: root.popup = ""
    }
    BluetoothManager {
        id: bluetoothManager
        fontFamily: Theme.font
        onMenuRequested: root.openPanel("bluetooth")
        onMenuCloseRequested: root.popup = ""
    }
    Notifications {
        id: notifs
        bottomMargin: root.barHeight + root.popupGap
        rightMargin: root.popupGap
        centerOpen: root.popup === "notif"
        onCenterToggleRequested: root.togglePopup("notif", root.focusedScreen)
    }
    AppMenu { id: appMenu }

    // o quickshell pode abrir antes de receber a lista do Hyprland: pede de novo
    Component.onCompleted: { Hyprland.refreshMonitors(); Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels() }
    Timer { interval: 1500; running: true; onTriggered: { Hyprland.refreshMonitors(); Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels() } }

    // trocar de workspace fecha os popups
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.popup = ""; appMenu.open = false }
    }

    // ── Popups, colados acima da barra, à direita ──────────
    component BarPopup: PanelWindow {
        id: pop
        property var modelData
        property string name: ""
        screen: modelData
        visible: root.popup === name && root.popupScreen === modelData.name
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors { right: true; bottom: true }
        margins { right: root.popupGap; bottom: root.barHeight + root.popupGap }
        color: "transparent"
        HyprlandFocusGrab {
            windows: [pop]
            active: pop.visible
            onCleared: if (root.popup === pop.name) root.popup = ""
        }
    }
    Variants {
        model: Quickshell.screens
        BarPopup {
            id: ccWindow
            name: "cc"
            WlrLayershell.keyboardFocus: cc.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None   // senha do wifi
            implicitWidth: cc.implicitWidth
            implicitHeight: cc.implicitHeight
            ControlCenter {
                id: cc
                anchors.fill: parent
                networkType: root.networkType
                networkSsid: root.networkSsid
                networkSignal: root.networkSignal
                networkIp: root.networkIp
                networkIcon: root.networkIcon
                networkTooltip: root.networkType === "wifi" ? (root.networkSsid || "Wi-Fi") : root.networkType === "ethernet" ? "Ethernet" : "Desconectado"
                batteryTimeText: root.batteryTimeText
                batteryRate: root.batteryRate
                batteryIcon: root.batteryIcon
                batteryCapacity: root.batteryCapacity
                batteryStatus: root.batteryStatus
                batteryCharging: root.batteryCharging
                volumeLevel: root.volumeLevel
                volumeMuted: root.volumeMuted
                cpuUsage: root.cpuUsage
                memUsage: root.memUsage
                displays: displayManager
                fans: fanManager
                bluetooth: bluetoothManager
                fontFamily: Theme.font
                onRequestSetVolume: lvl => root.setVolume(lvl)
                onRequestToggleMute: root.toggleMute()
                onRequestRefresh: netProc.running = true
                onRequestSystemMonitor: root.togglePopup("sm", ccWindow.modelData.name)
                onPageChanged: if (ccWindow.visible) root.ccPage = page
            }
            Connections {
                target: root
                function onPanelPageRequested(page) { if (root.popupScreen === ccWindow.modelData.name) cc.page = page }
            }
        }
    }
    Variants {
        model: Quickshell.screens
        BarPopup {
            id: calWindow
            name: "cal"
            implicitWidth: cal.implicitWidth
            implicitHeight: cal.implicitHeight
            onVisibleChanged: if (visible) cal.goToday()
            CalendarWidget { id: cal; anchors.fill: parent; fontFamily: Theme.font }
        }
    }
    Variants {
        model: Quickshell.screens
        BarPopup {
            name: "sm"
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
                onRequestKill: pid => { Quickshell.execDetached(["kill", String(pid)]); sysInfoProc.running = true }
                onRequestOpenMonitor: {
                    Quickshell.execDetached(["sh", "-c", "flatpak info io.missioncenter.MissionCenter >/dev/null 2>&1 && exec flatpak run io.missioncenter.MissionCenter; exec ghostty -e top"])
                    root.popup = ""
                }
            }
        }
    }
    Variants {
        model: Quickshell.screens
        BarPopup {
            name: "media"
            implicitWidth: media.implicitWidth
            implicitHeight: media.implicitHeight
            onVisibleChanged: if (visible) media.player = root.activePlayer
            MediaPanel { id: media; anchors.fill: parent }
        }
    }
    Variants {
        model: Quickshell.screens
        BarPopup {
            name: "notif"
            implicitWidth: notifCenter.implicitWidth
            implicitHeight: notifCenter.implicitHeight
            NotificationCenter { id: notifCenter; anchors.fill: parent; service: notifs }
        }
    }

    // ── Tooltip (guarda só janela e posição, nunca o item: âncora nula derruba o quickshell) ──
    property string barHover: ""
    property var hoverWindow: null
    property real hoverX: 0
    function hover(name, item) {
        hoverWindow = item.QsWindow.window
        hoverX = item.mapToItem(null, item.width / 2, 0).x
        barHover = name
    }
    function unhover(name) { if (barHover === name) barHover = "" }
    property date clockNow: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.clockNow = new Date() }
    function tooltipText() {
        var h = barHover
        if (h === "cpu") return "direito: processos e gráfico"
        if (h === "mem") return "direito: processos e gráfico"
        if (h === "net") return networkType === "wifi" ? networkSsid + " · sinal " + networkSignal + "%" + (networkIp ? " · " + networkIp : "")
                              : networkType === "ethernet" ? "cabo" + (networkIp ? " · " + networkIp : "") : "sem conexão"
        if (h === "vol") return (pwSink ? (pwSink.nickname || pwSink.description || "") + " · " : "") + "rolar ajusta · direito silencia"
        if (h === "batt") return batteryCapacity + "% · " + (batteryStatus === "Charging" ? "carregando" : batteryStatus === "Discharging" ? "descarregando" : batteryStatus === "Full" ? "carga completa" : "na tomada")
                              + (batteryTimeText ? " · " + batteryTimeText : "")
        if (h === "media") return activePlayer ? (activePlayer.trackTitle || "sem título") + (activePlayer.trackArtist ? " · " + activePlayer.trackArtist : "") + " · direito pausa · rolar troca" : ""
        if (h === "notif") return (notifs.dnd ? "não perturbe ligado · " : "") + "direito: não perturbe · meio: limpar"
        if (h === "clock") {
            var d = clockNow, hoje = Holidays.holidayOn(d), prox = Holidays.upcoming(d, 1)[0]
            return Qt.locale("pt_BR").toString(d, "dddd, d 'de' MMMM") + " · semana " + Holidays.isoWeek(d)
                 + (hoje ? " · feriado: " + hoje.name : prox ? " · " + Qt.formatDate(prox.date, "dd/MM") + " " + prox.name : "")
        }
        return ""
    }

    // ── Barra ──────────────────────────────────────────────
    // um item de texto da direita, com o "|" depois dele
    component Info: Item {
        id: info
        property string name: ""
        property string text: ""
        property color tint: Theme.soft
        property bool sep: true
        property bool aberto: false
        signal clicked(var mouse)
        signal wheel(int dir)
        implicitWidth: label.implicitWidth + 8 + (sep ? barra.implicitWidth : 0)
        implicitHeight: root.barHeight
        Rectangle {
            width: label.implicitWidth + 8; height: parent.height
            color: info.aberto ? Theme.selection : im.containsMouse ? Theme.surface0 : "transparent"
        }
        Text {
            id: label
            x: 4
            anchors.verticalCenter: parent.verticalCenter
            text: info.text
            color: info.aberto || im.containsMouse ? Theme.bright : info.tint
            font.family: Theme.font; font.pixelSize: 14
        }
        Text {
            id: barra
            visible: info.sep
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: "|"
            color: Theme.soft
            font.family: Theme.font; font.pixelSize: 14
        }
        MouseArea {
            id: im
            width: label.implicitWidth + 8; height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onEntered: root.hover(info.name, label)
            onExited: root.unhover(info.name)
            onClicked: mouse => info.clicked(mouse)
            onWheel: w => info.wheel(w.angleDelta.y > 0 ? 1 : w.angleDelta.y < 0 ? -1 : 0)
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: barWindow
            property var modelData
            readonly property string scr: modelData.name
            screen: modelData
            anchors { bottom: true; left: true; right: true }
            implicitHeight: root.barHeight
            color: Theme.bg

            PopupWindow {
                id: tooltip
                visible: root.barHover !== "" && root.hoverWindow === barWindow && tip.text !== "" && root.popup === "" && !appMenu.open
                anchor.window: barWindow
                anchor.rect.x: root.hoverX
                anchor.rect.y: -root.popupGap
                anchor.rect.width: 1
                anchor.rect.height: 1
                anchor.edges: Edges.Top
                anchor.gravity: Edges.Top
                implicitWidth: tip.implicitWidth + 20
                implicitHeight: 26
                color: "transparent"
                onVisibleChanged: if (visible) anchor.updateAnchor()
                Connections { target: root; function onHoverXChanged() { if (tooltip.visible) tooltip.anchor.updateAnchor() } }
                Rectangle {
                    anchors.fill: parent
                    color: Theme.tile
                    border.color: Theme.frame
                    border.width: 1
                    Text { id: tip; anchors.centerIn: parent; text: root.tooltipText(); color: Theme.fg; font.family: Theme.font; font.pixelSize: 12 }
                }
            }
            MouseArea { anchors.fill: parent; onClicked: root.popup = "" }

            // workspaces colados no canto + título da janela
            Row {
                id: wsRow
                height: parent.height
                Repeater {
                    model: 10
                    Rectangle {
                        id: wsItem
                        required property int index
                        readonly property int n: index + 1
                        readonly property var ws: Hyprland.workspaces.values.find(w => w.id === n) ?? null
                        readonly property bool active: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === n
                        visible: ws !== null || active
                        width: wsText.implicitWidth + 18
                        height: wsRow.height
                        color: active ? Theme.frame : ws && ws.urgent ? Theme.yellow : wsm.containsMouse ? Theme.surface0 : "transparent"
                        Text {
                            id: wsText
                            anchors.centerIn: parent
                            text: wsItem.n
                            color: wsItem.active ? Theme.bright : wsItem.ws && wsItem.ws.urgent ? Theme.bg : wsm.containsMouse ? Theme.fg : Theme.sub
                            font.family: Theme.font; font.pixelSize: 14; font.bold: wsItem.active
                        }
                        MouseArea {
                            id: wsm
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.irPara(wsItem.n)
                        }
                    }
                }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    property double ultimo: 0
                    onWheel: e => {
                        if (Math.abs(e.angleDelta.y) < 15 || Date.now() - ultimo < 150) return
                        ultimo = Date.now()
                        root.irPara(e.angleDelta.y > 0 ? "e-1" : "e+1")
                    }
                }
            }
            Text {
                id: title
                // só na tela em que a janela está; workspace vazio não tem título
                readonly property var tl: ToplevelManager.activeToplevel
                readonly property bool aqui: tl !== null && tl.activated && tl.screens.some(x => x.name === barWindow.scr)
                anchors { left: wsRow.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
                width: Math.min(implicitWidth, Math.max(0, infoRow.x - wsRow.width - 24))
                text: aqui && tl.title ? "| " + tl.title : ""
                textFormat: Text.PlainText
                color: tm.containsMouse ? Theme.bright : Theme.soft
                font.family: Theme.font; font.pixelSize: 14
                elide: Text.ElideRight
                MouseArea {
                    id: tm
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: title.aqui && root.lua
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var h = Hyprland.toplevels.values.find(x => x.wayland === title.tl) ?? Hyprland.activeToplevel
                        if (!h) return
                        appMenu.openFor(barWindow, wsRow.width + 4, h.address.startsWith("0x") ? h.address : "0x" + h.address, title.tl.appId, title.tl.title)
                    }
                }
            }

            Row {
                id: infoRow
                anchors.right: parent.right
                height: parent.height
                Info {
                    name: "media"
                    visible: root.activePlayer !== null
                    text: visible ? (root.activePlayer.isPlaying ? "▶ " : "‖ ") + (root.activePlayer.trackTitle || root.activePlayer.identity || "").slice(0, 28) : ""
                    aberto: root.popup === "media" && root.popupScreen === barWindow.scr
                    onClicked: m => {
                        var p = root.activePlayer
                        if (m.button === Qt.RightButton) { if (p.canTogglePlaying) p.togglePlaying() }
                        else if (m.button === Qt.MiddleButton) { if (p.canGoNext) p.next() }
                        else root.togglePopup("media", barWindow.scr)
                    }
                    onWheel: d => { var p = root.activePlayer; if (d > 0 && p.canGoPrevious) p.previous(); else if (d < 0 && p.canGoNext) p.next() }
                }
                Info {
                    name: "notif"
                    text: notifs.dnd ? "silêncio" : notifs.unread > 0 ? "avisos " + notifs.unread : "avisos"
                    tint: notifs.dnd ? Theme.gray : notifs.unread > 0 ? Theme.yellow : Theme.soft
                    aberto: root.popup === "notif" && root.popupScreen === barWindow.scr
                    onClicked: m => {
                        if (m.button === Qt.RightButton) notifs.setDnd(!notifs.dnd)
                        else if (m.button === Qt.MiddleButton) notifs.clearAll()
                        else root.togglePopup("notif", barWindow.scr)
                    }
                }
                Info {
                    name: "cpu"
                    text: "cpu " + root.cpuUsage + "%"
                    tint: root.cpuUsage >= 90 ? Theme.red : Theme.soft
                    aberto: (root.popup === "sm" || (root.popup === "cc" && root.ccItem === "cpu")) && root.popupScreen === barWindow.scr
                    onClicked: m => { if (m.button === Qt.LeftButton) root.toggleCentral("cpu", barWindow.scr); else root.togglePopup("sm", barWindow.scr) }
                }
                Info {
                    name: "mem"
                    text: "mem " + root.memUsage + "%"
                    tint: root.memUsage >= 90 ? Theme.red : Theme.soft
                    aberto: root.popup === "cc" && root.ccItem === "mem" && root.popupScreen === barWindow.scr
                    onClicked: m => { if (m.button === Qt.LeftButton) root.toggleCentral("mem", barWindow.scr); else root.togglePopup("sm", barWindow.scr) }
                }
                Info {
                    name: "net"
                    text: root.networkType === "wifi" ? "wifi " + root.networkSignal + "%" : root.networkType === "ethernet" ? "cabo" : "sem rede"
                    tint: root.networkType === "disconnected" ? Theme.gray : Theme.soft
                    aberto: root.popup === "cc" && root.ccItem === "net" && root.popupScreen === barWindow.scr
                    onClicked: m => { if (m.button === Qt.LeftButton) root.toggleCentral("net", barWindow.scr); else root.togglePopup("cc", barWindow.scr, "network") }
                }
                Info {
                    name: "vol"
                    visible: root.pwReady
                    text: root.volumeMuted ? "mudo" : "vol " + root.volumeLevel + "%"
                    tint: root.volumeMuted ? Theme.gray : Theme.soft
                    aberto: root.popup === "cc" && root.ccItem === "vol" && root.popupScreen === barWindow.scr
                    onClicked: m => { if (m.button === Qt.LeftButton) root.toggleCentral("vol", barWindow.scr); else root.toggleMute() }
                    onWheel: d => root.setVolume(root.volumeLevel + d * 5)
                }
                Info {
                    name: "batt"
                    visible: root.hasBattery
                    text: "bat " + root.batteryCapacity + "%" + (root.onAc ? "+" : "")
                    tint: root.onAc ? Theme.green : root.batteryCapacity <= 10 ? Theme.red : root.batteryCapacity <= 25 ? Theme.yellow : Theme.soft
                    aberto: root.popup === "cc" && root.ccItem === "batt" && root.popupScreen === barWindow.scr
                    onClicked: m => { if (m.button === Qt.LeftButton) root.toggleCentral("batt", barWindow.scr); else root.togglePopup("cc", barWindow.scr, "battery") }
                }
                Info {
                    name: "clock"
                    text: Qt.formatDateTime(root.clockNow, "dd/MM HH:mm")
                    tint: Theme.fg
                    sep: false
                    aberto: root.popup === "cal" && root.popupScreen === barWindow.scr
                    onClicked: m => { if (m.button === Qt.LeftButton) root.togglePopup("cal", barWindow.scr); else root.togglePopup("cc", barWindow.scr, "") }
                }
                Info {
                    name: "tray"
                    text: "▲"
                    tint: Theme.sub
                    sep: false
                    aberto: root.popup === "tray" && root.popupScreen === barWindow.scr
                    onClicked: m => { if (m.button === Qt.RightButton) appLauncher.show(">"); else root.togglePopup("tray", barWindow.scr) }
                }
            }
            BarPopup {
                modelData: barWindow.modelData
                name: "tray"
                implicitWidth: tray.implicitWidth
                implicitHeight: tray.implicitHeight
                TrayPopup { id: tray; anchors.fill: parent; barWindow: barWindow; onDismissed: root.popup = "" }
            }
        }
    }
}
