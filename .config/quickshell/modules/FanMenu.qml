import QtQuick
import QtQuick.Layouts

// FanMenu.qml – submenu de ventoinhas do ControlCenter: modo de energia, G-Mode, temperatura, RPM e
// boost de cada ventoinha. A lógica fica no FanManager, recebido em `manager`.
ColumnLayout {
    id: menu
    property var manager: null
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSub: "#a6adc8"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colMauve: "#cba6f7"
    property color colBase: "#1e1e2e"
    property color colDanger: "#f38ba8"
    signal back()

    readonly property bool locked: !!manager && manager.gMode

    spacing: 12

    component Label: Text {
        color: menu.colSub
        font.family: menu.fontFamily; font.pixelSize: 11; font.bold: true
    }
    component Divider: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: menu.colSurface0 }

    component FanControl: ColumnLayout {
        id: fan
        property string title: ""
        property int fanId: 1
        property int temp: 0
        property int rpm: 0
        property int boost: 0
        // enquanto arrasta ou rola, mostra o valor escolhido em vez do que o daemon informa
        property bool editing: false
        property int draft: 0
        readonly property int shown: editing ? draft : boost
        Layout.fillWidth: true
        spacing: 2

        function commit() {
            editing = false
            if (draft !== boost) menu.manager.setBoost(fanId, draft)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: fan.title
                color: menu.colText
                font.family: menu.fontFamily; font.pixelSize: 12; font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: fan.temp + " °C · " + fan.rpm + " RPM"
                color: menu.colSub
                font.family: menu.fontFamily; font.pixelSize: 11
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Item {
                id: slider
                Layout.fillWidth: true
                implicitHeight: 28
                opacity: menu.locked ? 0.5 : 1
                readonly property real value: fan.shown / 100
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 8; radius: 4
                    color: menu.colSurface0
                    Rectangle {
                        width: Math.max(height, parent.width * slider.value); height: parent.height; radius: 4
                        color: menu.colMauve
                    }
                }
                Rectangle {
                    width: 16; height: 16; radius: 8
                    anchors.verticalCenter: parent.verticalCenter
                    x: (slider.width - width) * slider.value
                    color: menu.colText
                    border.color: menu.colMauve; border.width: 2
                }
                // o boost só é enviado ao soltar: o daemon limita os pedidos por segundo
                MouseArea {
                    anchors.fill: parent
                    enabled: !menu.locked
                    cursorShape: Qt.PointingHandCursor
                    function pick(mx) { fan.draft = Math.max(0, Math.min(100, Math.round(mx / width * 100))) }
                    onPressed: mouse => { fan.editing = true; pick(mouse.x) }
                    onPositionChanged: mouse => { if (pressed) pick(mouse.x) }
                    onReleased: fan.commit()
                    onCanceled: fan.editing = false
                    onWheel: wheel => {
                        fan.draft = Math.max(0, Math.min(100, fan.shown + (wheel.angleDelta.y > 0 ? 5 : -5)))
                        fan.editing = true
                        wheelCommit.restart()
                    }
                }
                Timer { id: wheelCommit; interval: 400; onTriggered: fan.commit() }
            }
            Text {
                text: fan.shown + "%"
                color: menu.colText
                font.family: menu.fontFamily; font.pixelSize: 12; font.bold: true
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 40
            }
        }
    }

    // cabeçalho com voltar
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            implicitWidth: 28; implicitHeight: 28; radius: 8
            color: backMouse.containsMouse ? menu.colSurface1 : menu.colSurface0
            Text { anchors.centerIn: parent; text: "󰁍"; color: menu.colText; font.family: menu.fontFamily; font.pixelSize: 14 }
            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menu.back() }
        }
        Text {
            text: "Ventoinhas"
            color: menu.colText
            font.family: menu.fontFamily; font.pixelSize: 14; font.bold: true
        }
    }

    Text {
        visible: !!menu.manager && menu.manager.offline
        text: "O serviço g15-daemon não está respondendo"
        color: menu.colDanger
        font.family: menu.fontFamily; font.pixelSize: 11
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    ColumnLayout {
        visible: !!menu.manager && menu.manager.loaded
        Layout.fillWidth: true
        spacing: 12

        Divider {}

        // ── Modo de energia ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Label { text: "MODO"; Layout.fillWidth: true }
            Text {
                text: menu.manager ? menu.manager.mode : ""
                color: menu.colText
                font.family: menu.fontFamily; font.pixelSize: 11
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            opacity: menu.locked ? 0.5 : 1
            Repeater {
                model: menu.manager ? menu.manager.modes : []
                Rectangle {
                    id: chip
                    required property string modelData
                    readonly property bool selected: menu.manager.mode === modelData
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 8
                    color: selected ? menu.colMauve : chipMouse.containsMouse && !menu.locked ? menu.colSurface1 : menu.colSurface0
                    Text {
                        anchors.centerIn: parent
                        text: chip.modelData
                        color: chip.selected ? menu.colBase : menu.colText
                        font.family: menu.fontFamily; font.pixelSize: 11; font.bold: chip.selected
                    }
                    MouseArea {
                        id: chipMouse
                        anchors.fill: parent; hoverEnabled: true
                        enabled: !menu.locked
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.manager.setMode(chip.modelData)
                    }
                }
            }
        }

        // ── G-Mode ─────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: "G-Mode"
                    Layout.fillWidth: true
                    color: menu.colText
                    font.family: menu.fontFamily; font.pixelSize: 12; font.bold: true
                }
                Text {
                    text: menu.locked ? "Desligue para mudar o resto" : "Também muda com a tecla F9"
                    color: menu.colSub
                    font.family: menu.fontFamily; font.pixelSize: 10
                }
            }
            Rectangle {
                id: gSwitch
                readonly property bool on: menu.locked
                implicitWidth: 38; implicitHeight: 22; radius: 11
                color: on ? menu.colMauve : menu.colSurface1
                Rectangle {
                    width: 16; height: 16; radius: 8
                    y: 3
                    x: gSwitch.on ? gSwitch.width - width - 3 : 3
                    color: gSwitch.on ? menu.colBase : menu.colText
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.manager.toggleGMode()
                }
            }
        }

        Divider {}

        // ── Ventoinhas ─────────────────────────────────────
        FanControl {
            title: "CPU"
            fanId: 1
            temp: menu.manager ? menu.manager.cpuTemp : 0
            rpm: menu.manager ? menu.manager.cpuRpm : 0
            boost: menu.manager ? menu.manager.cpuBoost : 0
        }
        FanControl {
            title: "GPU"
            fanId: 2
            temp: menu.manager ? menu.manager.gpuTemp : 0
            rpm: menu.manager ? menu.manager.gpuRpm : 0
            boost: menu.manager ? menu.manager.gpuBoost : 0
        }
    }

    Text {
        visible: !!menu.manager && menu.manager.errorText !== ""
        text: menu.manager ? menu.manager.errorText : ""
        color: menu.colDanger
        font.family: menu.fontFamily; font.pixelSize: 11
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
