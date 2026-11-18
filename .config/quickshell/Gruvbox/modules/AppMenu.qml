import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "."

// AppMenu.qml – menu do botão direito nos ícones de apps da barra lateral (as mesmas ações da dock
// do Catppuccin). Um só menu, reposicionado ao lado do ícone clicado.
Item {
    id: menu
    property bool open: false
    // janela da barra + altura do ícone (nunca o item em si: se ele sumir com o menu aberto, o anchor
    // vira null e o Quickshell cai)
    property var window: null
    property real anchorY: 0
    property string address: ""
    property string appId: ""
    property string title: ""

    function openFor(win, y, addr, id, t) { window = win; anchorY = y; address = addr; appId = id; title = t; open = true; popup.anchor.updateAnchor() }
    function dispatchOn(lua) { Hyprland.dispatch(lua.replace("%W", '"address:' + address + '"')) }

    component MenuEntry: Rectangle {
        id: entry
        property string label: ""
        property string icon: ""
        property color tint: Theme.fg
        signal activated()
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 6
        color: entryMouse.containsMouse ? Theme.surface0 : "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            Text { text: entry.icon; color: entry.tint; font.family: Theme.font; font.pixelSize: 14 }
            Text { text: entry.label; color: entry.tint; font.family: Theme.font; font.pixelSize: 13; Layout.fillWidth: true }
        }
        MouseArea {
            id: entryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { entry.activated(); menu.open = false }
        }
    }

    PopupWindow {
        id: popup
        visible: menu.open && menu.window !== null
        anchor.window: menu.window
        anchor.rect.x: menu.window ? menu.window.width + 6 : 0
        anchor.rect.y: menu.anchorY
        anchor.rect.width: 1
        anchor.rect.height: 1
        anchor.edges: Edges.Right
        anchor.gravity: Edges.Right
        implicitWidth: 240
        implicitHeight: col.implicitHeight + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: Theme.bg
            border.color: Theme.surface1
            border.width: 1

            ColumnLayout {
                id: col
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                Text {
                    text: menu.title
                    color: Theme.sub
                    font.family: Theme.font
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.bottomMargin: 4
                }

                MenuEntry { icon: "󰁔"; label: "Focar"; onActivated: menu.dispatchOn('hl.dsp.focus({ window = %W })') }
                MenuEntry {
                    icon: "󰐕"; label: "Nova janela"
                    visible: DesktopEntries.heuristicLookup(menu.appId) !== null
                    onActivated: { var e = DesktopEntries.heuristicLookup(menu.appId); if (e) e.execute() }
                }
                MenuEntry { icon: "󰖲"; label: "Flutuar / encaixar"; onActivated: menu.dispatchOn('hl.dsp.window.float({ window = %W, action = "toggle" })') }
                MenuEntry { icon: "󰐃"; label: "Fixar em todos os workspaces"; onActivated: menu.dispatchOn('hl.dsp.window.pin({ window = %W, action = "toggle" })') }
                MenuEntry { icon: "󰊓"; label: "Tela cheia"; onActivated: menu.dispatchOn('hl.dsp.window.fullscreen({ window = %W, mode = "fullscreen" })') }

                Text {
                    text: "Mover para o workspace"
                    color: Theme.sub
                    font.family: Theme.font
                    font.pixelSize: 12
                    Layout.leftMargin: 10
                    Layout.topMargin: 6
                }
                GridLayout {
                    columns: 5
                    rowSpacing: 4
                    columnSpacing: 4
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6
                    Layout.bottomMargin: 4
                    Repeater {
                        model: 10
                        Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: 26
                            radius: 5
                            color: wsMouse.containsMouse ? Theme.accent : Theme.surface0
                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                color: wsMouse.containsMouse ? Theme.onAccent : Theme.fg
                                font.family: Theme.font
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    menu.dispatchOn('hl.dsp.window.move({ window = %W, workspace = "' + (index + 1) + '", follow = false })')
                                    menu.open = false
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0; Layout.topMargin: 2; Layout.bottomMargin: 2 }

                MenuEntry { icon: "󰅖"; label: "Fechar"; onActivated: menu.dispatchOn('hl.dsp.window.close({ window = %W })') }
                MenuEntry { icon: "󰚌"; label: "Forçar fechamento"; tint: Theme.red; onActivated: menu.dispatchOn('hl.dsp.window.kill({ window = %W })') }
            }
        }
    }

    // fecha ao clicar fora
    HyprlandFocusGrab {
        windows: [popup]
        active: popup.visible
        onCleared: menu.open = false
    }
}
