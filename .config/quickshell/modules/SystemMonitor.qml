import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// SystemMonitor.qml – painel aberto pela CPU/memória da barra.
// Anéis de CPU e RAM no topo (mesma linguagem do círculo do ControlCenter), depois CPU, memória,
// GPU, rede e os processos que mais usam CPU. Dados vêm de scripts/sys-info.sh via shell.qml.
Rectangle {
    id: rootSM
    property var info: null              // JSON do sys-info.sh
    property int cpuUsage: 0             // % calculado pela barra (/proc/stat)
    property var cpuHistory: []          // últimas amostras de cpuUsage
    property real rxRate: 0              // bytes/s
    property real txRate: 0
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colMauve: "#cba6f7"
    property color colBarBg: "#1e1e2e"
    property color colDanger: "#f38ba8"
    property color colSub: "#a6adc8"
    property color colGreen: "#a6e3a1"
    property color colBlue: "#89b4fa"
    property color colPeach: "#fab387"
    signal requestKill(int pid)
    signal requestOpenMonitor()

    implicitWidth: 360
    implicitHeight: mainCol.implicitHeight + 28
    radius: 16
    color: colBarBg
    border.color: colSurface0
    border.width: 1

    readonly property var gpu: info ? info.gpu : null
    readonly property real memUsedKb: info ? info.mem.total - info.mem.available : 0
    readonly property int memPct: info && info.mem.total > 0 ? Math.round(100 * memUsedKb / info.mem.total) : 0
    function gb(kb) { return (kb / 1048576).toFixed(1) }
    function rate(bps) {
        if (bps >= 1048576) return (bps / 1048576).toFixed(1) + " MB/s"
        if (bps >= 1024) return (bps / 1024).toFixed(0) + " KB/s"
        return Math.round(bps) + " B/s"
    }
    function tempColor(t) { return t >= 85 ? colDanger : t >= 70 ? colPeach : colText }

    // ── Componentes ────────────────────────────────────────
    component SectionTitle: Text {
        color: rootSM.colSub
        font.family: rootSM.fontFamily
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 0.5
    }
    component Divider: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: rootSM.colSurface0 }
    component Bar: Rectangle {
        property real value: 0           // 0..1
        property color fill: rootSM.colMauve
        Layout.fillWidth: true
        implicitHeight: 6; radius: 3
        color: rootSM.colSurface0
        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, parent.value)); height: parent.height; radius: 3
            color: parent.fill
            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
        }
    }
    component Stat: ColumnLayout {
        property string label: ""
        property string value: ""
        property color valueColor: rootSM.colText
        spacing: 0
        Text { text: parent.label; color: rootSM.colSub; font.family: rootSM.fontFamily; font.pixelSize: 10 }
        Text { text: parent.value; color: parent.valueColor; font.family: rootSM.fontFamily; font.pixelSize: 12; font.bold: true }
    }
    // anel 280° com valor no centro – mesmo desenho do NetworkStatusWidget
    component Ring: Item {
        id: ring
        property real value: 0           // 0..100
        property string label: ""
        property color fill: rootSM.colMauve
        implicitWidth: 76; implicitHeight: 76
        onValueChanged: canvas.requestPaint()
        onFillChanged: canvas.requestPaint()
        Canvas {
            id: canvas
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                var cx = width / 2, cy = height / 2, sw = 5, r = width / 2 - sw / 2 - 1
                var start = 130 * Math.PI / 180, span = 280 * Math.PI / 180
                ctx.lineCap = "round"; ctx.lineWidth = sw
                ctx.strokeStyle = "#45475a"
                ctx.beginPath(); ctx.arc(cx, cy, r, start, start + span, false); ctx.stroke()
                if (ring.value > 0) {
                    ctx.strokeStyle = ring.fill
                    ctx.beginPath(); ctx.arc(cx, cy, r, start, start + span * Math.min(1, ring.value / 100), false); ctx.stroke()
                }
            }
        }
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -4
            text: Math.round(ring.value) + "%"
            color: rootSM.colText
            font.family: rootSM.fontFamily; font.pixelSize: 15; font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: ring.label
            color: rootSM.colSub
            font.family: rootSM.fontFamily; font.pixelSize: 10; font.bold: true
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        // ── Resumo: anéis + gráfico de CPU ─────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Ring { value: rootSM.cpuUsage; label: "CPU"; fill: rootSM.cpuUsage >= 85 ? rootSM.colDanger : rootSM.colMauve }
            Ring { value: rootSM.memPct; label: "RAM"; fill: rootSM.memPct >= 85 ? rootSM.colDanger : rootSM.colBlue }
            // histórico de CPU (últimos ~60s)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Canvas {
                    id: spark
                    anchors.fill: parent
                    anchors.topMargin: 8; anchors.bottomMargin: 8
                    property var data: rootSM.cpuHistory
                    onDataChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var d = data || []
                        ctx.strokeStyle = "#45475a"; ctx.lineWidth = 1
                        ctx.beginPath(); ctx.moveTo(0, height - 0.5); ctx.lineTo(width, height - 0.5); ctx.stroke()
                        if (d.length < 2) return
                        var step = width / 59
                        var x0 = width - (d.length - 1) * step
                        ctx.beginPath()
                        for (var i = 0; i < d.length; i++) {
                            var x = x0 + i * step, y = height - (d[i] / 100) * height
                            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                        }
                        ctx.strokeStyle = "#cba6f7"; ctx.lineWidth = 1.5; ctx.stroke()
                        ctx.lineTo(width, height); ctx.lineTo(x0, height); ctx.closePath()
                        ctx.fillStyle = "rgba(203,166,247,0.15)"; ctx.fill()
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.top: parent.top
                    text: "CPU · 60s"
                    color: rootSM.colSub; font.family: rootSM.fontFamily; font.pixelSize: 9
                }
            }
        }

        Divider {}

        // ── CPU ────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { text: "CPU" }
                Text {
                    text: rootSM.info ? rootSM.info.cpu.name : ""
                    color: rootSM.colSub; font.family: rootSM.fontFamily; font.pixelSize: 10
                    elide: Text.ElideRight; Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 18
                Stat { label: "Uso"; value: rootSM.cpuUsage + "%" }
                Stat {
                    label: "Temperatura"
                    value: rootSM.info && rootSM.info.cpu.temp !== null ? rootSM.info.cpu.temp + "°C" : "—"
                    valueColor: rootSM.info && rootSM.info.cpu.temp !== null ? rootSM.tempColor(rootSM.info.cpu.temp) : rootSM.colText
                }
                Stat { label: "Frequência"; value: rootSM.info && rootSM.info.cpu.freq ? (rootSM.info.cpu.freq / 1000).toFixed(1) + " GHz" : "—" }
                Stat { label: "Carga (1m)"; value: rootSM.info ? rootSM.info.cpu.load[0].toFixed(2) : "—" }
            }
        }

        // ── Memória ────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { text: "MEMÓRIA"; Layout.fillWidth: true }
                Text {
                    text: rootSM.info ? rootSM.gb(rootSM.memUsedKb) + " / " + rootSM.gb(rootSM.info.mem.total) + " GB" : "—"
                    color: rootSM.colText; font.family: rootSM.fontFamily; font.pixelSize: 12; font.bold: true
                }
            }
            Bar { value: rootSM.memPct / 100; fill: rootSM.memPct >= 85 ? rootSM.colDanger : rootSM.colBlue }
            Text {
                visible: rootSM.info !== null && rootSM.info.mem.swapTotal > 0
                text: rootSM.info ? "Swap " + rootSM.gb(rootSM.info.mem.swapTotal - rootSM.info.mem.swapFree) + " / " + rootSM.gb(rootSM.info.mem.swapTotal) + " GB" : ""
                color: rootSM.colSub; font.family: rootSM.fontFamily; font.pixelSize: 10
            }
        }

        Divider {}

        // ── GPU ────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: rootSM.info !== null && rootSM.info.gpu !== null
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { text: "GPU" }
                Text {
                    text: rootSM.gpu && !rootSM.gpu.sleeping ? rootSM.gpu.name.replace("NVIDIA GeForce ", "") : "NVIDIA"
                    color: rootSM.colSub; font.family: rootSM.fontFamily; font.pixelSize: 10
                    elide: Text.ElideRight; Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                }
            }
            Text {
                visible: rootSM.gpu !== null && rootSM.gpu.sleeping === true
                text: "󰒲  Em repouso (desligada para economizar energia)"
                color: rootSM.colSub; font.family: rootSM.fontFamily; font.pixelSize: 11
            }
            ColumnLayout {
                visible: rootSM.gpu !== null && rootSM.gpu.sleeping === false
                Layout.fillWidth: true
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18
                    Stat { label: "Uso"; value: rootSM.gpu ? rootSM.gpu.util + "%" : "—" }
                    Stat { label: "VRAM"; value: rootSM.gpu ? (rootSM.gpu.memUsed / 1024).toFixed(1) + " / " + (rootSM.gpu.memTotal / 1024).toFixed(0) + " GB" : "—" }
                    Stat {
                        label: "Temperatura"
                        value: rootSM.gpu ? rootSM.gpu.temp + "°C" : "—"
                        valueColor: rootSM.gpu ? rootSM.tempColor(rootSM.gpu.temp) : rootSM.colText
                    }
                    Stat { label: "Consumo"; value: rootSM.gpu ? rootSM.gpu.power.toFixed(0) + " W" : "—" }
                }
                Bar { value: rootSM.gpu ? rootSM.gpu.util / 100 : 0; fill: rootSM.colGreen }
            }
        }

        Divider { visible: rootSM.info !== null && rootSM.info.gpu !== null }

        // ── Rede ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            SectionTitle { text: "REDE"; Layout.fillWidth: true }
            Text {
                text: "󰇚 " + rootSM.rate(rootSM.rxRate)
                color: rootSM.colGreen; font.family: rootSM.fontFamily; font.pixelSize: 12; font.bold: true
            }
            Text {
                text: "󰕒 " + rootSM.rate(rootSM.txRate)
                color: rootSM.colBlue; font.family: rootSM.fontFamily; font.pixelSize: 12; font.bold: true
            }
        }

        Divider {}

        // ── Processos ──────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                SectionTitle { text: "PROCESSOS"; Layout.fillWidth: true }
                Text { text: "CPU"; color: rootSM.colSub; font.family: rootSM.fontFamily; font.pixelSize: 10; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                Text { text: "RAM"; color: rootSM.colSub; font.family: rootSM.fontFamily; font.pixelSize: 10; Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight }
                Item { Layout.preferredWidth: 22 }
            }
            Repeater {
                model: rootSM.info ? rootSM.info.procs : []
                Rectangle {
                    id: procRow
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 26; radius: 7
                    color: procMouse.containsMouse ? rootSM.colSurface0 : "transparent"
                    MouseArea { id: procMouse; anchors.fill: parent; hoverEnabled: true }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 6; anchors.rightMargin: 2
                        spacing: 0
                        Text {
                            text: procRow.modelData.name
                            color: rootSM.colText; font.family: rootSM.fontFamily; font.pixelSize: 12
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                        Text {
                            // top mede % de um núcleo; divide pelo nº de threads para ficar igual à barra
                            text: (procRow.modelData.cpu / (rootSM.info ? rootSM.info.cpu.cores : 1)).toFixed(1) + "%"
                            color: rootSM.colText; font.family: rootSM.fontFamily; font.pixelSize: 11
                            Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: procRow.modelData.mem.toFixed(1) + "%"
                            color: rootSM.colText; font.family: rootSM.fontFamily; font.pixelSize: 11
                            Layout.preferredWidth: 44; horizontalAlignment: Text.AlignRight
                        }
                        // encerrar (SIGTERM) – aparece no hover
                        Rectangle {
                            Layout.preferredWidth: 22; Layout.preferredHeight: 22; Layout.leftMargin: 4
                            radius: 6
                            opacity: procMouse.containsMouse || killMouse.containsMouse ? 1 : 0
                            color: killMouse.containsMouse ? rootSM.colDanger : rootSM.colSurface1
                            Text {
                                anchors.centerIn: parent
                                text: "󰅖"
                                color: killMouse.containsMouse ? rootSM.colBarBg : rootSM.colText
                                font.family: rootSM.fontFamily; font.pixelSize: 11
                            }
                            MouseArea {
                                id: killMouse
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: rootSM.requestKill(procRow.modelData.pid)
                            }
                        }
                    }
                }
            }
        }

        // abrir monitor completo
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30; radius: 9
            color: openMouse.containsMouse ? rootSM.colSurface1 : rootSM.colSurface0
            Text {
                anchors.centerIn: parent
                text: "  Abrir Mission Center"
                color: rootSM.colText; font.family: rootSM.fontFamily; font.pixelSize: 11
            }
            MouseArea { id: openMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: rootSM.requestOpenMonitor() }
        }
    }
}
