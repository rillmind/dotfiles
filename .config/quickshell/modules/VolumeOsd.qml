import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// VolumeOsd.qml – barrinha com o volume exato, mostrada por alguns instantes quando o volume muda
// fora do ControlCenter (teclas, scroll na barra, pactl...). Quem decide quando mostrar é o shell.qml.
// Não recebe foco nem cliques: a janela é só visual.
Scope {
    id: osd
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colMauve: "#cba6f7"
    property color colRed: "#f38ba8"

    property int level: 0
    property bool muted: false
    property bool shown: false

    function show(newLevel, newMuted) {
        level = newLevel
        muted = newMuted
        shown = true
        hideTimer.restart()
    }

    Timer { id: hideTimer; interval: 1500; onTriggered: osd.shown = false }

    PanelWindow {
        visible: osd.shown
        // aparece no monitor em foco
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-osd"
        anchors.bottom: true
        margins.bottom: 96   // acima da dock
        implicitWidth: 300
        implicitHeight: 44
        color: "transparent"
        mask: Region {}      // cliques passam direto

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#F21e1e2e"
            border.color: osd.colSurface1
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10
                Text {
                    text: osd.muted ? "󰝟" : osd.level < 33 ? "󰕿" : osd.level < 66 ? "󰖀" : "󰕾"
                    color: osd.muted ? osd.colRed : osd.colMauve
                    font.family: osd.fontFamily; font.pixelSize: 18
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    radius: 4
                    color: osd.colSurface0
                    Rectangle {
                        // acima de 100% (pactl permite) a barra fica cheia; o número continua exato
                        width: parent.width * Math.min(1, osd.level / 100)
                        height: parent.height
                        radius: 4
                        color: osd.muted ? osd.colSurface1 : osd.colMauve
                    }
                }
                Text {
                    text: osd.level + "%"
                    color: osd.muted ? osd.colRed : osd.colText
                    font.family: osd.fontFamily; font.pixelSize: 14; font.bold: true
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 44
                }
            }
        }
    }
}
