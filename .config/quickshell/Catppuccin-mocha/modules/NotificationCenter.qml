import QtQuick
import QtQuick.Layouts
import Quickshell
import "."

// NotificationCenter.qml – histórico de notificações, aberto pelo sino da barra:
// não perturbe, limpar tudo e a lista (mais novas em cima).
Rectangle {
    id: center
    property var service: null

    implicitWidth: 400
    implicitHeight: col.implicitHeight + 28
    radius: 8
    color: Theme.bg
    border.color: Theme.surface0
    border.width: 1

    component HeaderButton: Rectangle {
        id: hb
        property string icon: ""
        property string label: ""
        property bool active: false
        signal clicked()
        implicitWidth: hbRow.implicitWidth + 16; implicitHeight: 26; radius: 5
        color: active ? Theme.accent : hbMouse.containsMouse ? Theme.surface1 : Theme.surface0
        RowLayout {
            id: hbRow
            anchors.centerIn: parent
            spacing: 6
            Text { text: hb.icon; color: hb.active ? Theme.onAccent : Theme.fg; font.family: Theme.font; font.pixelSize: 13 }
            Text { text: hb.label; color: hb.active ? Theme.onAccent : Theme.fg; font.family: Theme.font; font.pixelSize: 11; font.bold: true }
        }
        MouseArea { id: hbMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: hb.clicked() }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "󰂚"; color: Theme.accent; font.family: Theme.font; font.pixelSize: 16 }
            Text {
                text: "NOTIFICAÇÕES" + (center.service && center.service.history.count > 0 ? "  ·  " + center.service.history.count : "")
                color: Theme.sub
                font.family: Theme.font; font.pixelSize: 11; font.bold: true; font.letterSpacing: 0.5
                Layout.fillWidth: true
            }
            HeaderButton {
                icon: center.service && center.service.dnd ? "󰂛" : "󰂚"
                label: "Não perturbe"
                active: !!center.service && center.service.dnd
                onClicked: center.service.setDnd(!center.service.dnd)
            }
            HeaderButton {
                visible: !!center.service && center.service.history.count > 0
                icon: "󰃢"
                label: "Limpar"
                onClicked: center.service.clearAll()
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surface0 }

        // vazio
        ColumnLayout {
            visible: !center.service || center.service.history.count === 0
            Layout.fillWidth: true
            Layout.topMargin: 18
            Layout.bottomMargin: 18
            spacing: 6
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: center.service && center.service.dnd ? "󰂛" : "󰂜"
                color: Theme.surface2
                font.family: Theme.font; font.pixelSize: 40
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: center.service && center.service.dnd ? "Não perturbe ligado" : "Nada por aqui"
                color: Theme.sub
                font.family: Theme.font; font.pixelSize: 12
            }
        }

        ListView {
            id: list
            visible: count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 560)
            clip: true
            spacing: 6
            boundsBehavior: Flickable.StopAtBounds
            model: center.service ? center.service.history : null
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 150 } }
            displaced: Transition { NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic } }
            delegate: NotificationCard {
                required property var model
                width: list.width
                service: center.service
                notifKey: model.key
                entry: model
            }
        }

        Text {
            visible: !!center.service && center.service.dnd && center.service.history.count > 0
            text: "Não perturbe ligado: só notificações críticas aparecem na tela"
            color: Theme.gray
            font.family: Theme.font; font.pixelSize: 10
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
