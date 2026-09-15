import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Rectangle {
    id: rootCC
    property int volumeLevel: 35
    property bool volumeMuted: false
    property string networkIcon: "󰤭 "
    property string networkTooltip: "Desconectado"
    property string batteryIcon: " "
    property int batteryCapacity: 100
    property string batteryStatus: "Not charging"
    property bool batteryCharging: false
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSurface0: "#313244"
    property color colMauve: "#cba6f7"
    property color colBarBg: "#1e1e2e"
    signal requestSetVolume(int level)
    signal requestToggleMute()
    signal requestRefresh()

    width: 520
    height: 140
    radius: 12
    color: colBarBg
    border.color: colSurface0
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        // ── Volume ── lado a lado
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Text {
                    text: volumeMuted ? " " : (volumeLevel < 33 ? " " : " ")
                    color: colText
                    font.family: fontFamily
                    font.pixelSize: 18
                    font.bold: true
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: "Volume"
                    color: colText
                    font.family: fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    opacity: 0.85
                    Layout.fillWidth: true
                }
                Text {
                    text: volumeMuted ? "Mudo" : volumeLevel + "%"
                    color: colText
                    font.family: fontFamily
                    font.pixelSize: 12
                    font.bold: true
                }
            }
            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 22
                radius: 6
                color: volumeMuted ? colMauve : colSurface0
                Layout.alignment: Qt.AlignHCenter
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
                    onClicked: rootCC.requestToggleMute()
                }
            }
            Rectangle {
                id: track
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 4
                color: colSurface0
                Layout.topMargin: 4
                property real ratio: Math.max(0, Math.min(1, volumeLevel / 100.0))
                Rectangle { height: parent.height; radius: parent.radius; width: parent.width * track.ratio; color: colMauve }
                Rectangle {
                    width: 14; height: 14; radius: 8
                    color: colText; border.color: colMauve; border.width: 2
                    x: Math.max(0, Math.min(track.width - width, track.width * track.ratio - width/2))
                    anchors.verticalCenter: parent.verticalCenter
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onPressed: updatePos(mouse.x)
                    onPositionChanged: if (pressed) updatePos(mouse.x)
                    function updatePos(x) {
                        var r = Math.max(0, Math.min(1, x / track.width))
                        rootCC.requestSetVolume(Math.round(r * 100))
                    }
                }
            }
        }

        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: colSurface0; opacity: 0.6 }

        // ── WiFi ──
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            Text {
                text: networkIcon
                color: networkTooltip === "Desconectado" ? "#f38ba8" : colText
                font.family: fontFamily; font.pixelSize: 20; font.bold: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: networkTooltip === "Desconectado" || networkTooltip === "" ? "Desconectado" : networkTooltip
                color: colText; font.family: fontFamily; font.pixelSize: 12; font.bold: true
                elide: Text.ElideRight; Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: networkIcon === "󰤨 " ? "Wi-Fi" : networkIcon === " " ? "Ethernet" : "Sem internet"
                color: colText; font.family: fontFamily; font.pixelSize: 10; opacity: 0.7
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                Layout.preferredWidth: 62; Layout.preferredHeight: 22; radius: 6
                color: colSurface0
                Layout.alignment: Qt.AlignHCenter
                Text {
                    anchors.centerIn: parent
                    text: "Atualizar"
                    color: colText; font.family: fontFamily; font.pixelSize: 11; font.bold: true
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rootCC.requestRefresh() }
            }
        }

        Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: colSurface0; opacity: 0.6 }

        // ── Bateria ── apenas 1 raio
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                Text {
                    // ícone base sem raio – raio único fica no Text separado à direita
                    text: batteryIcon.replace("󱐋", "").trim()
                    color: batteryCharging ? colMauve : colText
                    font.family: fontFamily; font.pixelSize: 20; font.bold: true
                }
                Text {
                    text: batteryCharging ? "󱐋" : ""
                    color: colMauve; font.family: fontFamily; font.pixelSize: 16; font.bold: true
                    visible: batteryCharging
                }
            }
            Text {
                text: batteryCapacity + "%"
                color: colText; font.family: fontFamily; font.pixelSize: 14; font.bold: true
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
            Text {
                text: batteryStatus
                color: colText; font.family: fontFamily; font.pixelSize: 10; opacity: 0.7
                Layout.alignment: Qt.AlignHCenter
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
    }
}
