import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "."

// ControlCenter.qml – painel de wifi/volume/bateria aberto pela barra.
// Topo: círculo de status (NetworkStatusWidget) + resumo. Depois: volume ao vivo (PipeWire) com
// escolha da saída, Wi-Fi com lista de redes (nmcli) e bateria detalhada.
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
    property color colText: "#cdd6f4"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colMauve: "#cba6f7"
    property color colBarBg: "#1e1e2e"
    property color colDanger: "#f38ba8"
    property color colSub: "#a6adc8"
    property color colGreen: "#a6e3a1"
    signal requestSetVolume(int level)
    signal requestToggleMute()
    signal requestRefresh()

    // o painel pede foco de teclado só enquanto a senha do wifi está sendo digitada
    readonly property bool wantsKeyboard: passwordSsid !== ""

    implicitWidth: 340
    implicitHeight: mainCol.implicitHeight + 28
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
    property bool wifiListOpen: false
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
    }
    Component.onCompleted: { radioProc.running = true; knownProc.running = true }
    onVisibleChanged: if (visible) { radioProc.running = true; if (wifiListOpen) scanWifi() } else { passwordSsid = ""; wifiMessage = "" }

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

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        // ── Resumo: círculo + 3 linhas ─────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            NetworkStatusWidget {
                widgetSize: 72
                primaryColor: rootCC.colMauve
                backgroundColor: rootCC.colBarBg
                surfaceColor: rootCC.colSurface0
                borderColor: rootCC.colSurface0
                textColor: rootCC.colText
                state: rootCC.networkType === "disconnected" ? "disconnected" : "connected"
                volumeLevel: rootCC.volumeLevel
                volumeMuted: rootCC.volumeMuted
                batteryCapacity: rootCC.batteryCapacity
                batteryCharging: rootCC.batteryCharging
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Repeater {
                    model: [
                        { icon: rootCC.networkType === "wifi" ? rootCC.wifiIconFor(rootCC.networkSignal) : rootCC.networkType === "ethernet" ? "" : "󰤭",
                          text: rootCC.networkType === "wifi" ? rootCC.networkSsid : rootCC.networkType === "ethernet" ? "Ethernet" : "Desconectado",
                          danger: rootCC.networkType === "disconnected" },
                        { icon: rootCC.volumeMuted ? "󰝟" : "󰕾",
                          text: rootCC.volumeMuted ? "Mudo" : rootCC.volumeLevel + "% · " + rootCC.sinkName(rootCC.sink),
                          danger: rootCC.volumeMuted },
                        { icon: rootCC.batteryCharging ? "󰂄" : "󰁹",
                          text: rootCC.batteryCapacity + "%" + (rootCC.batteryTimeText ? " · " + rootCC.batteryTimeText : ""),
                          danger: rootCC.batteryCapacity <= 15 && !rootCC.batteryCharging }
                    ]
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            text: modelData.icon
                            color: modelData.danger ? rootCC.colDanger : rootCC.colMauve
                            font.family: rootCC.fontFamily; font.pixelSize: 14
                            Layout.preferredWidth: 18
                        }
                        Text {
                            text: modelData.text
                            color: modelData.danger ? rootCC.colDanger : rootCC.colText
                            font.family: rootCC.fontFamily; font.pixelSize: 12; font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }

        Divider {}

        // ── Wi-Fi ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { text: "WI-FI"; Layout.fillWidth: true }
                Switch { checked: rootCC.wifiEnabled; onToggled: rootCC.setWifiEnabled(!rootCC.wifiEnabled) }
            }
            // rede atual
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: rootCC.networkType === "wifi" ? rootCC.wifiIconFor(rootCC.networkSignal) : rootCC.networkType === "ethernet" ? "" : "󰤭"
                    color: rootCC.networkType === "disconnected" ? rootCC.colDanger : rootCC.colMauve
                    font.family: rootCC.fontFamily; font.pixelSize: 18
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: rootCC.networkType === "wifi" ? rootCC.networkSsid : rootCC.networkType === "ethernet" ? "Ethernet" : "Desconectado"
                        color: rootCC.colText
                        font.family: rootCC.fontFamily; font.pixelSize: 13; font.bold: true
                        elide: Text.ElideRight; Layout.fillWidth: true
                    }
                    Text {
                        visible: text !== ""
                        text: [rootCC.networkType === "wifi" ? "sinal " + rootCC.networkSignal + "%" : "", rootCC.networkIp].filter(s => s).join(" · ")
                        color: rootCC.colSub
                        font.family: rootCC.fontFamily; font.pixelSize: 11
                    }
                }
                // abrir/fechar lista de redes
                Rectangle {
                    visible: rootCC.wifiEnabled
                    implicitWidth: listBtnText.implicitWidth + 18; implicitHeight: 26; radius: 8
                    color: listBtnMouse.containsMouse ? rootCC.colSurface1 : rootCC.colSurface0
                    Text {
                        id: listBtnText
                        anchors.centerIn: parent
                        text: rootCC.wifiListOpen ? "Ocultar redes" : "Trocar rede"
                        color: rootCC.colText
                        font.family: rootCC.fontFamily; font.pixelSize: 11
                    }
                    MouseArea {
                        id: listBtnMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { rootCC.wifiListOpen = !rootCC.wifiListOpen; if (rootCC.wifiListOpen) rootCC.scanWifi() }
                    }
                }
            }
            // lista de redes
            ColumnLayout {
                visible: rootCC.wifiListOpen && rootCC.wifiEnabled
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

        Divider {}

        // ── Volume ─────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            SectionTitle { text: "SOM" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                // botão de mudo
                Rectangle {
                    implicitWidth: 32; implicitHeight: 32; radius: 10
                    color: muteMouse.containsMouse ? rootCC.colSurface1 : rootCC.colSurface0
                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                        text: rootCC.volumeMuted ? "󰝟" : rootCC.volumeLevel < 33 ? "󰕿" : rootCC.volumeLevel < 66 ? "󰖀" : "󰕾"
                        color: rootCC.volumeMuted ? rootCC.colDanger : rootCC.colText
                        font.family: rootCC.fontFamily; font.pixelSize: 16
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
                // slider (arrastar ou rolar) – escreve direto no PipeWire, sem atraso
                Item {
                    id: slider
                    Layout.fillWidth: true
                    implicitHeight: 32
                    readonly property real value: Math.min(1, rootCC.volumeLevel / 100)
                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 8; radius: 4
                        color: rootCC.colSurface0
                        Rectangle {
                            width: Math.max(height, parent.width * slider.value); height: parent.height; radius: 4
                            color: rootCC.volumeMuted ? rootCC.colSurface1 : rootCC.colMauve
                        }
                    }
                    Rectangle {
                        width: 16; height: 16; radius: 8
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
                Text {
                    text: rootCC.volumeLevel + "%"
                    color: rootCC.colText
                    font.family: rootCC.fontFamily; font.pixelSize: 12; font.bold: true
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 40
                }
            }
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

        Divider {}

        // ── Bateria ────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            SectionTitle { text: "BATERIA" }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: rootCC.batteryCapacity + "%"
                    color: rootCC.batteryCapacity <= 15 && !rootCC.batteryCharging ? rootCC.colDanger : rootCC.colText
                    font.family: rootCC.fontFamily; font.pixelSize: 20; font.bold: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: (rootCC.batteryCharging ? "󱐋 " : "") + rootCC.batteryStatusPt(rootCC.batteryStatus)
                        color: rootCC.batteryCharging ? rootCC.colGreen : rootCC.colText
                        font.family: rootCC.fontFamily; font.pixelSize: 12; font.bold: true
                    }
                    Text {
                        visible: text !== ""
                        text: [rootCC.batteryTimeText, rootCC.batteryRate > 0.1 ? rootCC.batteryRate.toFixed(1) + " W" : ""].filter(s => s).join(" · ")
                        color: rootCC.colSub
                        font.family: rootCC.fontFamily; font.pixelSize: 11
                    }
                }
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
}
