import QtQuick
import QtQuick.Layouts
import "."

// DisplayMenu.qml – submenu de imagem do ControlCenter: ativar/desativar cada monitor conectado e
// escolher resolução, FPS e escala. A lógica fica no DisplayManager, recebido em `manager`.
ColumnLayout {
    id: menu
    property var manager: null
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: Theme.fg
    property color colSub: Theme.sub
    property color colSurface0: Theme.surface0
    property color colSurface1: Theme.surface1
    property color colMauve: Theme.accent
    property color colBase: Theme.bg
    property color colDanger: Theme.red
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
        radius: 0
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
            implicitWidth: 28; implicitHeight: 28; radius: 0
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
            property real selScale: mon.raw.scale
            property bool scalePicked: false   // depois de escolhida, a escala não muda ao trocar a resolução
            readonly property var selMode: mon.modes.find(x => x.res === selRes)
            readonly property var scaleChoices: menu.manager.scaleOptionsFor(selRes)
            readonly property bool changed: selRes !== mon.currentRes || selRate !== mon.currentRate
                                            || !menu.manager.sameScale(selScale, mon.raw.scale)
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
                    implicitWidth: 38; implicitHeight: 22; radius: 0
                    opacity: card.locked ? 0.5 : 1
                    color: on ? menu.colMauve : menu.colSurface1
                    Rectangle {
                        width: 16; height: 16; radius: 0
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
                            if (!card.scalePicked) card.selScale = menu.manager.suggestedScale(card.mon, modelData.res)
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

            Label {
                visible: !card.mon.disabled
                // a escala em uso pode não estar entre as opções, como a 1.33 das regras do Hyprland
                text: "ESCALA" + (menu.manager.scaleOptionsFor(card.mon.currentRes).some(s => menu.manager.sameScale(s, card.mon.raw.scale))
                                  ? "" : " · ATUAL " + menu.manager.formatScale(card.mon.raw.scale))
            }
            Flow {
                visible: !card.mon.disabled
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: card.scaleChoices
                    Chip {
                        required property var modelData
                        label: menu.manager.formatScale(modelData)
                        selected: menu.manager.sameScale(card.selScale, modelData)
                        onClicked: { card.selScale = modelData; card.scalePicked = true }
                    }
                }
            }

            // barra de 1 a 3: só para em escalas limpas da resolução escolhida, então não gera aviso.
            // No fim dela, a limpa mais próxima pode passar de 3, como a 3.2 de 2560x1440.
            RowLayout {
                visible: !card.mon.disabled
                Layout.fillWidth: true
                spacing: 10
                Item {
                    id: scaleSlider
                    readonly property real value: Math.max(0, Math.min(1, (card.selScale - 1) / 2))
                    Layout.fillWidth: true
                    implicitHeight: 22
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; height: 6; radius: 0
                        color: menu.colSurface0
                        Rectangle {
                            width: Math.max(height, parent.width * scaleSlider.value); height: parent.height; radius: 0
                            color: menu.colMauve
                        }
                    }
                    Rectangle {
                        width: 14; height: 14; radius: 0
                        anchors.verticalCenter: parent.verticalCenter
                        x: (scaleSlider.width - width) * scaleSlider.value
                        color: menu.colText
                        border.color: menu.colMauve; border.width: 2
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true; preventStealing: true; cursorShape: Qt.PointingHandCursor
                        function pick(mx) {
                            var fraction = Math.max(0, Math.min(1, mx / width))
                            card.selScale = menu.manager.nearestCleanScale(card.selRes, 1 + fraction * 2)
                            card.scalePicked = true
                        }
                        onPressed: mouse => pick(mouse.x)
                        onPositionChanged: mouse => { if (pressed) pick(mouse.x) }
                    }
                }
                Text {
                    text: menu.manager.formatScale(card.selScale) + "x"
                    color: menu.colText
                    font.family: menu.fontFamily; font.pixelSize: 11; font.bold: true
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 38
                }
            }

            Rectangle {
                visible: !card.mon.disabled && card.changed
                Layout.fillWidth: true
                implicitHeight: 30; radius: 0
                color: menu.colMauve
                Text {
                    anchors.centerIn: parent
                    text: "Aplicar " + card.selRes + " a " + card.selRate + " Hz · " + menu.manager.formatScale(card.selScale) + "x"
                    color: menu.colBase
                    font.family: menu.fontFamily; font.pixelSize: 12; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menu.manager.setMode(card.mon.name, card.selRes, card.selRate, card.selScale)
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
