import QtQuick
import QtQuick.Layouts
import Quickshell.Io

// Conteúdo do popup de volume – sem janela, apenas retângulo estilizado
// Espera propriedades do root: volumeLevel, volumeMuted, fontFamily, colText etc sendo passadas via parent
Rectangle {
    id: container
    // será instanciado dentro de um PopupWindow – tamanho fixo
    property int volumeLevel: 35
    property bool volumeMuted: false
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colMauve: "#cba6f7"
    property color colBarBg: "#1e1e2e"
    signal requestSetVolume(int level) // 0-100
    signal requestToggleMute()
    signal requestVolumeRefresh()

    width: 320
    height: 110
    radius: 8
    color: colBarBg
    border.color: colSurface0
    border.width: 1

    Process {
        id: setVolProc
    }
    Process {
        id: toggleMuteProc
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: volumeMuted ? " " : (volumeLevel < 33 ? " " : " ")
                color: colText
                font.family: fontFamily
                font.pixelSize: 20
                font.bold: true
            }
            Text {
                text: volumeMuted ? "Mudo" : volumeLevel + "%"
                color: colText
                font.family: fontFamily
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }
            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 26
                radius: 6
                color: volumeMuted ? colMauve : colSurface0
                Text {
                    anchors.centerIn: parent
                    text: volumeMuted ? "Mutado" : "Som"
                    color: volumeMuted ? colSurface0 : colText
                    font.family: fontFamily
                    font.pixelSize: 11
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: container.requestToggleMute()
                }
            }
        }

        // Slider custom (sem QtQuick.Controls para compatibilidade)
        Rectangle {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 8
            radius: 4
            color: colSurface0

            property real ratio: volumeLevel / 100.0

            Rectangle {
                id: fill
                height: parent.height
                radius: parent.radius
                width: parent.width * track.ratio
                color: colMauve
            }
            Rectangle {
                id: handle
                width: 16
                height: 16
                radius: 8
                color: colText
                border.color: colMauve
                border.width: 2
                x: Math.max(0, Math.min(track.width - width, track.width * track.ratio - width/2))
                anchors.verticalCenter: parent.verticalCenter
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPressed: updatePos(mouse.x)
                onPositionChanged: if (pressed) updatePos(mouse.x)
                onClicked: updatePos(mouse.x)
                function updatePos(x) {
                    var r = Math.max(0, Math.min(1, x / track.width))
                    var lvl = Math.round(r * 100)
                    container.requestSetVolume(lvl)
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: "0%"; color: colText; font.family: fontFamily; font.pixelSize: 10; opacity: 0.7 }
            Item { Layout.fillWidth: true }
            Text { text: "100%"; color: colText; font.family: fontFamily; font.pixelSize: 10; opacity: 0.7 }
        }
    }
}
