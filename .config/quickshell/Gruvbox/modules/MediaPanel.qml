import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "."

// MediaPanel.qml – o que está tocando (Spotify, navegador…) via MPRIS: capa, música, progresso e
// controles. Aberto pelo ícone de música da barra lateral. Com vários players, setas trocam entre eles.
Rectangle {
    id: panel
    // player mostrado; o shell.qml escolhe o padrão (o que está tocando)
    property var player: null
    readonly property var players: Mpris.players.values

    implicitWidth: 340
    implicitHeight: col.implicitHeight + 28
    radius: 8
    color: Theme.bg
    border.color: Theme.surface0
    border.width: 1

    function fmt(sec) {
        if (!sec || sec < 0 || !isFinite(sec)) return "0:00"
        sec = Math.floor(sec)
        var m = Math.floor(sec / 60), s = sec % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }
    function cycle(delta) {
        if (players.length < 2) return
        var i = players.indexOf(player)
        player = players[(i + delta + players.length) % players.length]
    }

    // a posição do MPRIS não emite mudança sozinha
    Timer {
        interval: 1000; repeat: true
        running: panel.visible && !!panel.player && panel.player.isPlaying
        onTriggered: panel.player.positionChanged()
    }

    component CtrlButton: Rectangle {
        id: btn
        property string icon: ""
        property bool big: false
        property bool enabledBtn: true
        signal clicked()
        implicitWidth: big ? 44 : 34; implicitHeight: implicitWidth; radius: 6
        color: big ? Theme.accent : btnMouse.containsMouse ? Theme.surface1 : Theme.surface0
        opacity: enabledBtn ? 1 : 0.4
        Text {
            anchors.centerIn: parent
            text: btn.icon
            color: btn.big ? Theme.onAccent : Theme.fg
            font.family: Theme.font; font.pixelSize: btn.big ? 20 : 15
        }
        MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: btn.enabledBtn; onClicked: btn.clicked() }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        Text {
            visible: !panel.player
            text: "Nada tocando"
            color: Theme.sub
            font.family: Theme.font; font.pixelSize: 13
        }

        // cabeçalho: nome do player e troca entre players
        RowLayout {
            visible: !!panel.player
            Layout.fillWidth: true
            spacing: 6
            Text { text: "󰎆"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 14 }
            Text {
                text: panel.player ? (panel.player.identity || "Player").toUpperCase() : ""
                color: Theme.sub
                font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5
                Layout.fillWidth: true
            }
            Text {
                visible: panel.players.length > 1
                text: "󰅁"
                color: prevPl.containsMouse ? Theme.accent : Theme.sub
                font.family: Theme.font; font.pixelSize: 14
                MouseArea { id: prevPl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.cycle(-1) }
            }
            Text {
                visible: panel.players.length > 1
                text: (panel.players.indexOf(panel.player) + 1) + "/" + panel.players.length
                color: Theme.sub
                font.family: Theme.font; font.pixelSize: 11
            }
            Text {
                visible: panel.players.length > 1
                text: "󰅂"
                color: nextPl.containsMouse ? Theme.accent : Theme.sub
                font.family: Theme.font; font.pixelSize: 14
                MouseArea { id: nextPl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: panel.cycle(1) }
            }
        }

        // capa + música
        RowLayout {
            visible: !!panel.player
            Layout.fillWidth: true
            spacing: 12
            Rectangle {
                implicitWidth: 72; implicitHeight: 72; radius: 6
                color: Theme.surface0
                clip: true
                Image {
                    id: art
                    anchors.fill: parent
                    source: panel.player ? (panel.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !art.visible
                    text: "󰝚"
                    color: Theme.sub
                    font.family: Theme.font; font.pixelSize: 30
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: panel.player ? (panel.player.trackTitle || "Sem título") : ""
                    color: Theme.fg
                    font.family: Theme.font; font.pixelSize: 14; font.bold: true
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                    text: panel.player ? (panel.player.trackArtist || "") : ""
                    visible: text !== ""
                    color: Theme.sub
                    font.family: Theme.font; font.pixelSize: 12
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
                Text {
                    text: panel.player ? (panel.player.trackAlbum || "") : ""
                    visible: text !== ""
                    color: Theme.gray
                    font.family: Theme.font; font.pixelSize: 11
                    elide: Text.ElideRight; Layout.fillWidth: true
                }
            }
        }

        // progresso (clicar pula para o ponto)
        ColumnLayout {
            visible: !!panel.player && panel.player.lengthSupported && panel.player.length > 0
            Layout.fillWidth: true
            spacing: 4
            Item {
                Layout.fillWidth: true
                implicitHeight: 10
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 4; radius: 2
                    color: Theme.surface0
                    Rectangle {
                        width: panel.player && panel.player.length > 0 ? parent.width * Math.min(1, panel.player.position / panel.player.length) : 0
                        height: parent.height; radius: 2
                        color: Theme.accent
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !!panel.player && panel.player.canSeek
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: mouse => panel.player.position = panel.player.length * mouse.x / width
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: panel.fmt(panel.player ? panel.player.position : 0); color: Theme.sub; font.family: Theme.font; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: panel.fmt(panel.player ? panel.player.length : 0); color: Theme.sub; font.family: Theme.font; font.pixelSize: 10 }
            }
        }

        // controles
        RowLayout {
            visible: !!panel.player
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            CtrlButton {
                icon: "󰒮"
                enabledBtn: !!panel.player && panel.player.canGoPrevious
                onClicked: panel.player.previous()
            }
            CtrlButton {
                big: true
                icon: panel.player && panel.player.isPlaying ? "󰏤" : "󰐊"
                enabledBtn: !!panel.player && panel.player.canTogglePlaying
                onClicked: panel.player.togglePlaying()
            }
            CtrlButton {
                icon: "󰒭"
                enabledBtn: !!panel.player && panel.player.canGoNext
                onClicked: panel.player.next()
            }
        }
    }
}
