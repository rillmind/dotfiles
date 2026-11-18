import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "."

// ControlCenter.qml – painel aberto pela barra. A tela principal é uma grade em que toda seção segue
// a mesma estrutura (Tile): ícone, nome, seta do submenu, valor, detalhe e barra. Clicar em qualquer parte
// do card abre o submenu, escolhido pela propriedade `page`; só o controle de volume fica por cima disso.
Rectangle {
    id: rootCC
    // ── Estado vindo do shell.qml ──────────────────────────
    property int volumeLevel: 35
    property bool volumeMuted: false
    property string networkIcon: "󰤭 "
    property string networkTooltip: "Desconectado"
    property string networkType: "disconnected"   // wifi | ethernet | disconnected
    property string networkSsid: ""
    property int networkSignal: 0
    property string networkIp: ""
    property string batteryIcon: " "
    property int batteryCapacity: 100
    property string batteryStatus: "Not charging"
    property bool batteryCharging: false
    property string batteryTimeText: ""          // ex: "2h10 restantes"
    property real batteryRate: 0                 // W
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: Theme.fg
    property color colSurface0: Theme.surface0
    property color colSurface1: Theme.surface1
    property color colMauve: Theme.accent
    property color colBarBg: Theme.bg
    property color colDanger: Theme.red
    property color colSub: Theme.sub
    property color colGreen: Theme.green
    property color colTile: Theme.tile
    signal requestSetVolume(int level)
    signal requestToggleMute()
    signal requestRefresh()
    // card do sistema: abre o painel com gráfico de CPU, memória e processos
    property int cpuUsage: 0
    property int memUsage: 0
    signal requestSystemMonitor()

    // submenu aberto: "" (tela principal), network, sound, battery, displays, fans ou bluetooth
    property string page: ""
    property var displays: null
    property var fans: null
    property var bluetooth: null
    onPageChanged: {
        if (page === "network" && wifiEnabled) scanWifi()
        if (bluetooth) bluetooth.watching = page === "bluetooth"
    }

    // o painel pede foco de teclado só enquanto a senha do wifi está sendo digitada
    readonly property bool wantsKeyboard: passwordSsid !== "" || bluetoothMenu.wantsKeyboard

    implicitWidth: 340
    readonly property Item currentPage: page === "network" ? networkPage : page === "sound" ? soundPage : page === "battery" ? batteryPage
                                       : page === "displays" ? displayMenu : page === "fans" ? fanMenu
                                       : page === "bluetooth" ? bluetoothMenu : homePage
    implicitHeight: currentPage.implicitHeight + 28
    radius: 16
    color: colBarBg
    border.color: colSurface0
    border.width: 1

    function batteryStatusPt(s) {
        if (s === "Charging") return "Carregando"
        if (s === "Discharging") return "Descarregando"
        if (s === "Full") return "Carga completa"
        if (s === "Not charging") return "Conectado, sem carregar"
        return s
    }
    function batteryDetail() {
        if (batteryTimeText) return batteryTimeText
        return batteryStatus === "Not charging" ? "Sem carregar" : batteryStatusPt(batteryStatus)
    }
    readonly property var activeMonitors: displays ? displays.monitors.filter(m => !m.disabled) : []
    function monitorsDetail() {
        if (activeMonitors.length !== 1) return activeMonitors.map(m => m.name).join(" · ")
        return activeMonitors[0].currentRes + " · " + Math.round(activeMonitors[0].currentRate) + " Hz"
    }
    function wifiIconFor(signal) {
        if (signal >= 80) return "󰤨"
        if (signal >= 60) return "󰤥"
        if (signal >= 40) return "󰤢"
        if (signal >= 20) return "󰤟"
        return "󰤯"
    }

    // ── PipeWire: volume e saídas ao vivo ─────────────────
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    PwObjectTracker { objects: rootCC.sinks }
    function sinkName(n) { return n ? (n.nickname || n.description || n.name) : "—" }
    function setVolumeFraction(f) {
        f = Math.max(0, Math.min(1, f))
        if (sink && sink.audio) {
            sink.audio.volume = f
            if (sink.audio.muted && f > 0) sink.audio.muted = false
        } else {
            requestSetVolume(Math.round(f * 100))
        }
    }

    // ── Wi-Fi via nmcli ────────────────────────────────────
    property bool wifiEnabled: true
    property var wifiNetworks: []        // [{ ssid, signal, secure, inUse, known }]
    property var knownConnections: []
    property bool wifiScanning: false
    property string passwordSsid: ""     // rede aguardando senha
    property string wifiMessage: ""

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser { onRead: data => rootCC.wifiEnabled = data.trim() === "enabled" }
    }
    Process { id: radioSetProc; onExited: { radioProc.running = true; rootCC.requestRefresh() } }
    Process {
        id: knownProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]
        property var acc: []
        stdout: SplitParser {
            onRead: data => {
                var i = data.lastIndexOf(":")
                if (i > 0 && data.substring(i + 1).indexOf("wireless") !== -1)
                    knownProc.acc.push(data.substring(0, i).replace(/\\:/g, ":"))
            }
        }
        onStarted: acc = []
        onExited: rootCC.knownConnections = acc
    }
    Process {
        id: scanProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "auto"]
        environment: ({ LANGUAGE: "C", LC_ALL: "C" })
        property var acc: []
        stdout: SplitParser {
            onRead: data => {
                // campos separados por ":" (":" dentro do SSID vem escapado como "\:")
                var f = data.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"))
                if (f.length < 4 || f[1] === "") return
                scanProc.acc.push({ inUse: f[0] === "*", ssid: f[1], signal: parseInt(f[2]) || 0, secure: f[3] !== "" && f[3] !== "--" })
            }
        }
        onStarted: { acc = []; rootCC.wifiScanning = true }
        onExited: {
            // uma entrada por SSID (a de sinal mais forte), conectada primeiro
            var best = {}
            for (var n of acc) {
                if (!best[n.ssid] || n.inUse || (!best[n.ssid].inUse && n.signal > best[n.ssid].signal)) best[n.ssid] = n
            }
            var list = Object.values(best)
            for (var x of list) x.known = rootCC.knownConnections.indexOf(x.ssid) !== -1
            list.sort((a, b) => (b.inUse - a.inUse) || (b.known - a.known) || (b.signal - a.signal))
            rootCC.wifiNetworks = list
            rootCC.wifiScanning = false
        }
    }
    Process {
        id: connectProc
        property string target: ""
        stderr: SplitParser { onRead: data => { if (data.trim()) rootCC.wifiMessage = data.trim() } }
        onExited: (code) => {
            if (code === 0) { rootCC.wifiMessage = "Conectado a " + target; rootCC.passwordSsid = "" }
            else if (rootCC.wifiMessage === "") rootCC.wifiMessage = "Não foi possível conectar a " + target
            rootCC.requestRefresh()
            knownProc.running = true
            scanProc.running = true
        }
    }
    function scanWifi() { knownProc.running = true; scanProc.running = true }
    function connectTo(net, password) {
        wifiMessage = "Conectando a " + net.ssid + "…"
        connectProc.target = net.ssid
        if (net.known && !password) connectProc.command = ["nmcli", "connection", "up", "id", net.ssid]
        else if (password) connectProc.command = ["nmcli", "device", "wifi", "connect", net.ssid, "password", password]
        else connectProc.command = ["nmcli", "device", "wifi", "connect", net.ssid]
        connectProc.running = true
    }
    function setWifiEnabled(on) {
        radioSetProc.command = ["nmcli", "radio", "wifi", on ? "on" : "off"]
        radioSetProc.running = true
        wifiEnabled = on
        if (on && page === "network") scanWifi()
    }
    Component.onCompleted: { radioProc.running = true; knownProc.running = true }
    onVisibleChanged: if (visible) radioProc.running = true; else { passwordSsid = ""; wifiMessage = ""; page = "" }

    // ── Componentes visuais reutilizados ───────────────────
    component SectionTitle: Text {
        color: rootCC.colSub
        font.family: rootCC.fontFamily
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 0.5
    }
    component Divider: Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: rootCC.colSurface0
    }
    component Switch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled()
        implicitWidth: 38; implicitHeight: 22; radius: 11
        color: checked ? rootCC.colMauve : rootCC.colSurface1
        Behavior on color { ColorAnimation { duration: 150 } }
        Rectangle {
            width: 16; height: 16; radius: 8
            y: 3
            x: sw.checked ? sw.width - width - 3 : 3
            color: sw.checked ? rootCC.colBarBg : rootCC.colText
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
    }

    // Seção da tela principal. Toda seção usa este componente, para ficarem iguais.
    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property string value: ""
        property string detail: ""
        property string target: ""     // submenu aberto pelo botão
        property bool danger: false
        property color meterColor: rootCC.colMauve
        property var meter: []         // uma barra por item, cada uma de 0 a 1
        property var action: null      // se definido, o clique roda isto em vez de abrir um submenu
        property string arrow: "󰅂"
        default property alias extra: extraSlot.data
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 100
        implicitHeight: tileCol.implicitHeight + 20
        radius: 12
        color: tileMouse.containsMouse ? rootCC.colSurface0 : rootCC.colTile
        // o card inteiro abre o submenu; fica atrás do conteúdo para o volume continuar recebendo o clique
        MouseArea {
            id: tileMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: tile.action ? tile.action() : rootCC.page = tile.target
        }
        ColumnLayout {
            id: tileCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: tile.icon; color: rootCC.colMauve; font.family: rootCC.fontFamily; font.pixelSize: 16 }
                SectionTitle { text: tile.title; elide: Text.ElideRight; Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: 28; implicitHeight: 28; radius: 8
                    color: tileMouse.containsMouse ? rootCC.colSurface1 : rootCC.colSurface0
                    Text { anchors.centerIn: parent; text: tile.arrow; color: rootCC.colText; font.family: rootCC.fontFamily; font.pixelSize: 14 }
                }
            }
            Text {
                text: tile.value
                color: tile.danger ? rootCC.colDanger : rootCC.colText
                font.family: rootCC.fontFamily; font.pixelSize: 13; font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: tile.detail
                color: rootCC.colSub
                font.family: rootCC.fontFamily; font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            RowLayout {
                visible: tile.meter.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 4
                Repeater {
                    model: tile.meter
                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 6; radius: 3
                        color: rootCC.colSurface0
                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, parent.modelData)); height: parent.height; radius: 3
                            color: tile.meterColor
                        }
                    }
                }
            }
            ColumnLayout { id: extraSlot; visible: children.length > 0; Layout.fillWidth: true; spacing: 0 }
        }
    }

    // controle de volume (arrastar ou rolar): escreve direto no PipeWire, sem atraso
    component VolumeSlider: Item {
        id: slider
        readonly property real value: Math.min(1, rootCC.volumeLevel / 100)
        Layout.fillWidth: true
        implicitHeight: 22
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: rootCC.colSurface0
            Rectangle {
                width: Math.max(height, parent.width * slider.value); height: parent.height; radius: 3
                color: rootCC.volumeMuted ? rootCC.colSurface1 : rootCC.colMauve
            }
        }
        Rectangle {
            width: 14; height: 14; radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: (slider.width - width) * slider.value
            color: rootCC.colText
            border.color: rootCC.colMauve; border.width: 2
            scale: sliderMouse.pressed || sliderMouse.containsMouse ? 1.15 : 1.0
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
        MouseArea {
            id: sliderMouse
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            function apply(mx) { rootCC.setVolumeFraction(mx / width) }
            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x) }
            onWheel: wheel => rootCC.setVolumeFraction(slider.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    // cabeçalho dos submenus, igual ao de Monitores e Ventoinhas
    component SubHeader: RowLayout {
        id: subHeader
        property string title: ""
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            implicitWidth: 28; implicitHeight: 28; radius: 8
            color: backMouse.containsMouse ? rootCC.colSurface1 : rootCC.colSurface0
            Text { anchors.centerIn: parent; text: "󰁍"; color: rootCC.colText; font.family: rootCC.fontFamily; font.pixelSize: 14 }
            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rootCC.page = "" }
        }
        Text {
            text: subHeader.title
            color: rootCC.colText
            font.family: rootCC.fontFamily; font.pixelSize: 14; font.bold: true
        }
    }

    // nome e valor em uma linha dos submenus
    component InfoRow: RowLayout {
        id: infoRow
        property string label: ""
        property string value: ""
        visible: value !== ""
        Layout.fillWidth: true
        spacing: 12
        Text { text: infoRow.label; color: rootCC.colSub; font.family: rootCC.fontFamily; font.pixelSize: 11 }
        Text {
            text: infoRow.value
            color: rootCC.colText
            font.family: rootCC.fontFamily; font.pixelSize: 11; font.bold: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    DisplayMenu {
        id: displayMenu
        visible: rootCC.page === "displays"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        manager: rootCC.displays
        fontFamily: rootCC.fontFamily
        colText: rootCC.colText
        colSub: rootCC.colSub
        colSurface0: rootCC.colSurface0
        colSurface1: rootCC.colSurface1
        colMauve: rootCC.colMauve
        colBase: rootCC.colBarBg
        colDanger: rootCC.colDanger
        onBack: rootCC.page = ""
    }

    FanMenu {
        id: fanMenu
        visible: rootCC.page === "fans"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        manager: rootCC.fans
        fontFamily: rootCC.fontFamily
        colText: rootCC.colText
        colSub: rootCC.colSub
        colSurface0: rootCC.colSurface0
        colSurface1: rootCC.colSurface1
        colMauve: rootCC.colMauve
        colBase: rootCC.colBarBg
        colDanger: rootCC.colDanger
        onBack: rootCC.page = ""
    }

    BluetoothMenu {
        id: bluetoothMenu
        visible: rootCC.page === "bluetooth"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        manager: rootCC.bluetooth
        fontFamily: rootCC.fontFamily
        colText: rootCC.colText
        colSub: rootCC.colSub
        colSurface0: rootCC.colSurface0
        colSurface1: rootCC.colSurface1
        colMauve: rootCC.colMauve
        colBase: rootCC.colBarBg
        colDanger: rootCC.colDanger
        colTile: rootCC.colTile
        onBack: rootCC.page = ""
    }

    // ── Tela principal ─────────────────────────────────────
    GridLayout {
        id: homePage
        visible: rootCC.page === ""
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        columns: 2
        columnSpacing: 10
        rowSpacing: 10
        uniformCellWidths: true
        uniformCellHeights: true

        Tile {
            target: "network"
            title: "REDE"
            icon: rootCC.networkType === "wifi" ? rootCC.wifiIconFor(rootCC.networkSignal) : rootCC.networkType === "ethernet" ? "" : "󰤭"
            value: rootCC.networkType === "wifi" ? rootCC.networkSsid : rootCC.networkType === "ethernet" ? "Ethernet" : "Desconectado"
            detail: rootCC.networkType === "wifi" ? "sinal " + rootCC.networkSignal + "%" : rootCC.networkType === "ethernet" ? rootCC.networkIp : "Sem conexão"
            danger: rootCC.networkType === "disconnected"
            meter: [rootCC.networkType === "wifi" ? rootCC.networkSignal / 100 : rootCC.networkType === "ethernet" ? 1 : 0]
        }
        Tile {
            target: "battery"
            title: "BATERIA"
            icon: rootCC.batteryCharging ? "󰂄" : "󰁹"
            value: rootCC.batteryCapacity + "%"
            detail: rootCC.batteryDetail()
            danger: rootCC.batteryCapacity <= 15 && !rootCC.batteryCharging
            meter: [rootCC.batteryCapacity / 100]
            meterColor: danger ? rootCC.colDanger : rootCC.batteryCharging ? rootCC.colGreen : rootCC.colMauve
        }
        Tile {
            target: "sound"
            title: "SOM"
            icon: rootCC.volumeMuted ? "󰝟" : "󰕾"
            value: rootCC.volumeMuted ? "Mudo" : rootCC.volumeLevel + "%"
            detail: rootCC.sinkName(rootCC.sink)
            danger: rootCC.volumeMuted
            VolumeSlider {}
        }
        Tile {
            target: "displays"
            title: "MONITORES"
            icon: "󰍹"
            value: rootCC.activeMonitors.length + " de " + (rootCC.displays ? rootCC.displays.monitors.length : 0) + " ativos"
            detail: rootCC.monitorsDetail()
            meter: rootCC.displays ? rootCC.displays.monitors.map(m => m.disabled ? 0 : 1) : []
        }
        Tile {
            readonly property bool ready: !!rootCC.fans && rootCC.fans.loaded && !rootCC.fans.offline
            target: "fans"
            title: "VENTOINHAS"
            icon: "󰈐"
            value: ready ? rootCC.fans.cpuTemp + " °C · " + rootCC.fans.gpuTemp + " °C" : "—"
            detail: !ready ? (rootCC.fans && rootCC.fans.offline ? "Indisponível" : "Carregando") : rootCC.fans.gMode ? "G-Mode ligado" : rootCC.fans.mode
            danger: !!rootCC.fans && rootCC.fans.offline
            meter: !ready ? [0, 0]
                   : rootCC.fans.fansLocked ? [Math.min(1, rootCC.fans.cpuRpm / rootCC.fans.maxRpm), Math.min(1, rootCC.fans.gpuRpm / rootCC.fans.maxRpm)]
                   : [rootCC.fans.cpuBoost / 100, rootCC.fans.gpuBoost / 100]
        }
        Tile {
            readonly property var connected: rootCC.bluetooth ? rootCC.bluetooth.connectedDevices : []
            readonly property var withBattery: connected.filter(d => d.batteryAvailable)
            readonly property bool on: !!rootCC.bluetooth && rootCC.bluetooth.enabled
            target: "bluetooth"
            title: "BLUETOOTH"
            icon: !on ? "󰂲" : connected.length > 0 ? "󰂱" : "󰂯"
            value: !rootCC.bluetooth || !rootCC.bluetooth.adapter ? "Sem adaptador" : !on ? "Desligado"
                   : connected.length > 0 ? connected.map(d => d.name).join(" · ") : "Ligado"
            detail: !on ? "" : connected.length > 0
                    ? (withBattery.length > 0 ? "bateria " + withBattery.map(d => Math.round(d.battery * 100) + "%").join(" · ") : connected.length + (connected.length === 1 ? " conectado" : " conectados"))
                    : rootCC.bluetooth.pairedCount + (rootCC.bluetooth.pairedCount === 1 ? " pareado" : " pareados")
            meter: withBattery.map(d => d.battery)
        }
        // troca a config inteira do quickshell (ver ../../tema.sh); o processo atual é encerrado pelo script
        Tile {
            title: "SISTEMA"
            icon: "󰍛"
            value: "CPU " + rootCC.cpuUsage + "% · RAM " + rootCC.memUsage + "%"
            detail: "Processos e gráfico"
            danger: rootCC.cpuUsage >= 85 || rootCC.memUsage >= 85
            meter: [rootCC.cpuUsage / 100, rootCC.memUsage / 100]
            meterColor: danger ? rootCC.colDanger : rootCC.colMauve
            action: () => rootCC.requestSystemMonitor()
        }
        // modo claro/escuro do Gruvbox (antes era um botão na barra)
        Tile {
            title: "MODO"
            icon: Theme.light ? "󰖙" : "󰖔"
            arrow: "󰔎"
            value: Theme.light ? "Claro" : "Escuro"
            detail: Theme.light ? "Mudar para o escuro" : "Mudar para o claro"
            action: () => Theme.toggle()
        }
        Tile {
            Layout.columnSpan: 2
            title: "TEMA"
            icon: "󰏘"
            arrow: "󰑓"
            value: Theme.light ? "Gruvbox claro" : "Gruvbox escuro"
            detail: "Clique para trocar para o Catppuccin"
            action: () => Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/tema.sh", "trocar"])
        }
    }

    // ── Rede ───────────────────────────────────────────────
    ColumnLayout {
        id: networkPage
        visible: rootCC.page === "network"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        SubHeader { title: "Rede" }
        Divider {}
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "Wi-Fi"
                    color: rootCC.colText
                    font.family: rootCC.fontFamily; font.pixelSize: 12; font.bold: true
                    Layout.fillWidth: true
                }
                Text {
                    text: rootCC.wifiEnabled ? "Ligado" : "Desligado"
                    color: rootCC.colSub
                    font.family: rootCC.fontFamily; font.pixelSize: 10
                }
            }
            Switch { checked: rootCC.wifiEnabled; onToggled: rootCC.setWifiEnabled(!rootCC.wifiEnabled) }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            InfoRow { label: "Conexão"; value: rootCC.networkType === "wifi" ? rootCC.networkSsid : rootCC.networkType === "ethernet" ? "Ethernet" : "Desconectado" }
            InfoRow { label: "Sinal"; value: rootCC.networkType === "wifi" ? rootCC.networkSignal + "%" : "" }
            InfoRow { label: "IP"; value: rootCC.networkIp }
        }
        Divider { visible: rootCC.wifiEnabled }
        SectionTitle { visible: rootCC.wifiEnabled; text: "REDES" }
        // lista de redes
        ColumnLayout {
            visible: rootCC.wifiEnabled
            Layout.fillWidth: true
            spacing: 2
            Text {
                visible: rootCC.wifiScanning && rootCC.wifiNetworks.length === 0
                text: "Procurando redes…"
                color: rootCC.colSub; font.family: rootCC.fontFamily; font.pixelSize: 11
            }
            Repeater {
                model: rootCC.wifiNetworks.slice(0, 8)
                ColumnLayout {
                    id: netRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 4
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 32; radius: 8
                        color: netMouse.containsMouse && !netRow.modelData.inUse ? rootCC.colSurface0 : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 8
                            Text {
                                text: rootCC.wifiIconFor(netRow.modelData.signal)
                                color: netRow.modelData.inUse ? rootCC.colMauve : rootCC.colText
                                font.family: rootCC.fontFamily; font.pixelSize: 14
                            }
                            Text {
                                text: netRow.modelData.ssid
                                color: netRow.modelData.inUse ? rootCC.colMauve : rootCC.colText
                                font.family: rootCC.fontFamily; font.pixelSize: 12; font.bold: netRow.modelData.inUse
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                            Text {
                                text: netRow.modelData.inUse ? "conectado" : netRow.modelData.known ? "salva" : ""
                                color: rootCC.colSub; font.family: rootCC.fontFamily; font.pixelSize: 10
                            }
                            Text {
                                visible: netRow.modelData.secure
                                text: "󰌾"
                                color: rootCC.colSub; font.family: rootCC.fontFamily; font.pixelSize: 11
                            }
                        }
                        MouseArea {
                            id: netMouse
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: netRow.modelData.inUse ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onClicked: {
                                var n = netRow.modelData
                                if (n.inUse) return
                                if (n.secure && !n.known) { rootCC.passwordSsid = n.ssid; pwField.text = ""; pwField.forceActiveFocus() }
                                else rootCC.connectTo(n, "")
                            }
                        }
                    }
                    // senha (só para redes novas protegidas)
                    RowLayout {
                        visible: rootCC.passwordSsid === netRow.modelData.ssid
                        Layout.fillWidth: true
                        Layout.leftMargin: 8; Layout.rightMargin: 8
                        spacing: 6
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28; radius: 8
                            color: rootCC.colSurface0
                            border.color: pwField.activeFocus ? rootCC.colMauve : "transparent"
                            TextInput {
                                id: pwField
                                anchors.fill: parent
                                anchors.leftMargin: 8; anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: rootCC.colText
                                font.family: rootCC.fontFamily; font.pixelSize: 12
                                clip: true
                                onAccepted: rootCC.connectTo(netRow.modelData, text)
                                Keys.onEscapePressed: rootCC.passwordSsid = ""
                            }
                            Text {
                                visible: pwField.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left; anchors.leftMargin: 8
                                text: "Senha"
                                color: rootCC.colSub; font.family: rootCC.fontFamily; font.pixelSize: 12
                            }
                        }
                        Rectangle {
                            implicitWidth: 64; implicitHeight: 28; radius: 8
                            color: rootCC.colMauve
                            Text { anchors.centerIn: parent; text: "Conectar"; color: rootCC.colBarBg; font.family: rootCC.fontFamily; font.pixelSize: 11; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rootCC.connectTo(netRow.modelData, pwField.text) }
                        }
                    }
                }
            }
            Text {
                visible: rootCC.wifiMessage !== ""
                text: rootCC.wifiMessage
                color: rootCC.colSub
                font.family: rootCC.fontFamily; font.pixelSize: 10
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.leftMargin: 8
            }
        }
    }

    // ── Som ────────────────────────────────────────────────
    ColumnLayout {
        id: soundPage
        visible: rootCC.page === "sound"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        SubHeader { title: "Som" }
        Divider {}
        SectionTitle { text: "VOLUME" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Rectangle {
                implicitWidth: 28; implicitHeight: 28; radius: 8
                color: muteMouse.containsMouse ? rootCC.colSurface1 : rootCC.colSurface0
                Text {
                    anchors.centerIn: parent
                    text: rootCC.volumeMuted ? "󰝟" : rootCC.volumeLevel < 33 ? "󰕿" : rootCC.volumeLevel < 66 ? "󰖀" : "󰕾"
                    color: rootCC.volumeMuted ? rootCC.colDanger : rootCC.colText
                    font.family: rootCC.fontFamily; font.pixelSize: 14
                }
                MouseArea {
                    id: muteMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (rootCC.sink && rootCC.sink.audio) rootCC.sink.audio.muted = !rootCC.sink.audio.muted
                        else rootCC.requestToggleMute()
                    }
                }
            }
            VolumeSlider {}
            Text {
                text: rootCC.volumeLevel + "%"
                color: rootCC.colText
                font.family: rootCC.fontFamily; font.pixelSize: 12; font.bold: true
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 40
            }
        }
        Divider { visible: rootCC.sinks.length > 1 }
        SectionTitle { visible: rootCC.sinks.length > 1; text: "SAÍDA" }
        // saídas de áudio
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: rootCC.sinks.length > 1
            Repeater {
                model: rootCC.sinks
                Rectangle {
                    required property var modelData
                    readonly property bool current: rootCC.sink === modelData
                    implicitHeight: 26
                    implicitWidth: Math.min(300, sinkLabel.implicitWidth + 20)
                    radius: 8
                    color: current ? rootCC.colMauve : sinkMouse.containsMouse ? rootCC.colSurface1 : rootCC.colSurface0
                    Text {
                        id: sinkLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 280)
                        elide: Text.ElideRight
                        text: rootCC.sinkName(modelData)
                        color: parent.current ? rootCC.colBarBg : rootCC.colText
                        font.family: rootCC.fontFamily; font.pixelSize: 11
                    }
                    MouseArea {
                        id: sinkMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }
        }
    }

    // ── Bateria ────────────────────────────────────────────
    ColumnLayout {
        id: batteryPage
        visible: rootCC.page === "battery"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        SubHeader { title: "Bateria" }
        Divider {}
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            InfoRow { label: "Carga"; value: rootCC.batteryCapacity + "%" }
            InfoRow { label: "Estado"; value: rootCC.batteryStatusPt(rootCC.batteryStatus) }
            InfoRow { label: "Tempo"; value: rootCC.batteryTimeText }
            InfoRow { label: "Consumo"; value: rootCC.batteryRate > 0.1 ? rootCC.batteryRate.toFixed(1) + " W" : "" }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 6; radius: 3
            color: rootCC.colSurface0
            Rectangle {
                width: parent.width * rootCC.batteryCapacity / 100; height: parent.height; radius: 3
                color: rootCC.batteryCapacity <= 15 && !rootCC.batteryCharging ? rootCC.colDanger : rootCC.batteryCharging ? rootCC.colGreen : rootCC.colMauve
            }
        }
    }
}
