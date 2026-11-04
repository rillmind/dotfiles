import QtQuick
import QtQuick.Layouts

// DisplayMenu.qml – submenu de imagem do ControlCenter: ativar/desativar cada monitor conectado e
// escolher resolução e FPS. A lógica fica no DisplayManager, recebido em `manager`.
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

    spacing: 12
    onVisibleChanged: if (visible && manager) { manager.errorText = ""; manager.refresh() }

    component Chip: Rectangle {
        id: chip
        property string label: ""
        property bool selected: false
        signal clicked()
        implicitHeight: 26
        implicitWidth: chipText.implicitWidth + 16
        radius: 8
        color: selected ? menu.colMauve : chipMouse.containsMouse ? menu.colSurface1 : menu.colSurface0
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.selected ? menu.colBase : menu.colText
            font.family: menu.fontFamily; font.pixelSize: 11; font.bold: chip.selected
        }
        MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }
    component Label: Text {
        color: menu.colSub
        font.family: menu.fontFamily; font.pixelSize: 11; font.bold: true
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
            text: "Monitores"
            color: menu.colText
            font.family: menu.fontFamily; font.pixelSize: 14; font.bold: true
        }
    }

    Repeater {
        model: menu.manager ? menu.manager.monitors : []
        ColumnLayout {
            id: card
            required property var modelData
            readonly property var mon: modelData
            // só o último monitor ativo não pode ser desligado
            readonly property bool locked: !mon.disabled && menu.manager.activeCount <= 1
            property string selRes: mon.currentRes
            property string selRate: mon.currentRate
            readonly property var selMode: mon.modes.find(x => x.res === selRes)
            readonly property bool changed: selRes !== mon.currentRes || selRate !== mon.currentRate
            Layout.fillWidth: true
            spacing: 8

            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: menu.colSurface0 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: card.mon.name
                        color: card.mon.disabled ? menu.colSub : menu.colText
                        font.family: menu.fontFamily; font.pixelSize: 13; font.bold: true
                    }
                    Text {
                        text: card.mon.description
                        color: menu.colSub
                        font.family: menu.fontFamily; font.pixelSize: 10
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                Rectangle {
                    id: enableSwitch
                    readonly property bool on: !card.mon.disabled
                    implicitWidth: 38; implicitHeight: 22; radius: 11
                    opacity: card.locked ? 0.5 : 1
                    color: on ? menu.colMauve : menu.colSurface1
                    Rectangle {
                        width: 16; height: 16; radius: 8
                        y: 3
                        x: enableSwitch.on ? enableSwitch.width - width - 3 : 3
                        color: enableSwitch.on ? menu.colBase : menu.colText
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: card.locked ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                        onClicked: menu.manager.setEnabled(card.mon.name, card.mon.disabled)
                    }
                }
            }

            Text {
                visible: card.locked
                text: "É o único monitor ativo"
                color: menu.colSub
                font.family: menu.fontFamily; font.pixelSize: 10
            }

            Label { visible: !card.mon.disabled && card.mon.modes.length > 0; text: "RESOLUÇÃO" }
            Flow {
                visible: !card.mon.disabled
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: card.mon.modes
                    Chip {
                        required property var modelData
                        label: modelData.res
                        selected: card.selRes === modelData.res
                        onClicked: {
                            card.selRes = modelData.res
                            // na resolução atual mantém o FPS atual; nas outras sugere o maior
                            card.selRate = modelData.res === card.mon.currentRes ? card.mon.currentRate : modelData.rates[0]
                        }
                    }
                }
            }

            Label { visible: !card.mon.disabled && !!card.selMode; text: "FPS" }
            Flow {
                visible: !card.mon.disabled && !!card.selMode
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: card.selMode ? card.selMode.rates : []
                    Chip {
                        required property var modelData
                        label: modelData
                        selected: card.selRate === modelData
                        onClicked: card.selRate = modelData
                    }
                }
            }

            Rectangle {
                visible: !card.mon.disabled && card.changed
                Layout.fillWidth: true
                implicitHeight: 30; radius: 8
                color: menu.colMauve
                Text {
                    anchors.centerIn: parent
                    text: "Aplicar " + card.selRes + " a " + card.selRate + " Hz"
                    color: menu.colBase
                    font.family: menu.fontFamily; font.pixelSize: 12; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.manager.setMode(card.mon.name, card.selRes, card.selRate)
                }
            }
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
