import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "."

// NotificationCard.qml – uma notificação. Usado nos popups (dados da notificação viva, some sozinho)
// e na central (dados do histórico; ações só enquanto o app ainda mantém a notificação).
// Clique: ação padrão · direito: some do popup (na central, apaga) · meio: apaga.
Rectangle {
    id: card
    property var service: null
    property string notifKey: ""
    property bool popup: false
    // tamanho: os popups usam o dobro (Notifications.qml); a central fica no tamanho normal
    property real escala: 1
    readonly property real s: popup ? escala : 1
    // dados do histórico (central); no popup vêm da notificação viva
    property var entry: null

    readonly property var n: service ? service.liveFor(notifKey) : null
    readonly property string app: n ? n.appName : entry ? entry.app : ""
    readonly property string summary: n ? n.summary : entry ? entry.summary : ""
    readonly property string body: n ? n.body : entry ? entry.body : ""
    readonly property string icon: entry ? entry.icon : n && service ? service.iconFor(n) : ""
    readonly property string image: entry ? entry.image : n && service ? service.imageFor(n) : ""
    readonly property double time: entry ? entry.time : bornAt
    readonly property int urgency: n ? n.urgency : entry ? entry.urgency : NotificationUrgency.Normal
    readonly property bool critical: urgency === NotificationUrgency.Critical
    readonly property var actions: n ? n.actions.filter(a => a.identifier !== "default" && a.text !== "") : []
    property double bornAt: Date.now()
    property bool replyFocus: replyField.activeFocus

    // tempo na tela: crítica fica até fechar; senão o pedido pelo app ou 5 s
    readonly property int timeout: !popup || critical ? 0
                                   : n && n.expireTimeout > 0 ? n.expireTimeout   // já em ms
                                   : 5000

    implicitHeight: col.implicitHeight + 24 * s
    radius: 0
    color: popup ? Theme.bg : (cardMouse.containsMouse ? Theme.surface0 : Theme.tile)
    border.color: critical ? Theme.red : popup ? Theme.frame : "transparent"
    border.width: popup || critical ? 2 : 1

    // ── contagem regressiva (pausa com o mouse em cima) ────
    property real remaining: 1
    NumberAnimation on remaining {
        id: countdown
        running: card.timeout > 0
        paused: running && (cardMouse.containsMouse || card.replyFocus)
        from: 1; to: 0
        duration: Math.max(1, card.timeout)
        onFinished: if (card.service) card.service.hidePopup(card.notifKey)
    }

    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (!card.service) return
            if (mouse.button === Qt.MiddleButton || (mouse.button === Qt.RightButton && !card.popup)) card.service.remove(card.notifKey)
            else if (mouse.button === Qt.RightButton) card.service.hidePopup(card.notifKey)
            else card.service.activate(card.notifKey)
        }
    }

    RowLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12 * card.s
        spacing: 12 * card.s

        // imagem da notificação (capa, avatar) ou ícone do app
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40 * card.s; implicitHeight: 40 * card.s
            Image {
                id: img
                anchors.fill: parent
                source: card.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: card.image !== "" && status === Image.Ready
                layer.enabled: false
            }
            IconImage {
                id: ico
                anchors.fill: parent
                source: img.visible ? "" : card.icon
                visible: !img.visible && card.icon !== "" && status === Image.Ready
                asynchronous: true
            }
            // ícone pequeno do app sobre a imagem
            IconImage {
                visible: img.visible && card.icon !== ""
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -4 * card.s
                implicitSize: 18 * card.s
                source: img.visible ? card.icon : ""
            }
            Text {
                anchors.centerIn: parent
                visible: !img.visible && !ico.visible
                text: "󰂚"
                color: card.critical ? Theme.red : Theme.accent
                font.family: Theme.font; font.pixelSize: 26 * card.s
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3 * card.s

            RowLayout {
                Layout.fillWidth: true
                spacing: 6 * card.s
                Text {
                    text: card.app || "Notificação"
                    color: card.critical ? Theme.red : Theme.sub
                    font.family: Theme.font; font.pixelSize: 11 * card.s; font.bold: true
                    elide: Text.ElideRight
                    Layout.maximumWidth: 180 * card.s
                }
                Text {
                    text: "·  " + (card.service ? card.service.ago(card.time) : "")
                    color: Theme.gray
                    font.family: Theme.font; font.pixelSize: 11 * card.s
                }
                Item { Layout.fillWidth: true }
                // fechar (popup: some; central: apaga)
                Rectangle {
                    implicitWidth: 20 * card.s; implicitHeight: 20 * card.s; radius: 0
                    opacity: cardMouse.containsMouse || closeMouse.containsMouse ? 1 : 0
                    color: closeMouse.containsMouse ? Theme.surface1 : "transparent"
                    Text { anchors.centerIn: parent; text: "󰅖"; color: Theme.sub; font.family: Theme.font; font.pixelSize: 13 * card.s }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.popup ? card.service.hidePopup(card.notifKey) : card.service.remove(card.notifKey)
                    }
                }
            }
            Text {
                visible: text !== ""
                text: card.summary
                color: Theme.fg
                font.family: Theme.font; font.pixelSize: 13 * card.s; font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: text !== ""
                text: card.body
                textFormat: Text.StyledText
                color: Theme.sub
                linkColor: Theme.accent
                font.family: Theme.font; font.pixelSize: 12 * card.s
                wrapMode: Text.Wrap
                maximumLineCount: card.popup ? 4 : 3
                elide: Text.ElideRight
                Layout.fillWidth: true
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // botões de ação
            Flow {
                visible: card.actions.length > 0
                Layout.fillWidth: true
                Layout.topMargin: 6 * card.s
                spacing: 6 * card.s
                Repeater {
                    model: card.actions
                    Rectangle {
                        required property var modelData
                        implicitWidth: actText.implicitWidth + 20 * card.s; implicitHeight: 26 * card.s; radius: 0
                        color: actMouse.containsMouse ? Theme.accent : Theme.surface0
                        Text {
                            id: actText
                            anchors.centerIn: parent
                            text: modelData.text
                            color: actMouse.containsMouse ? Theme.onAccent : Theme.fg
                            font.family: Theme.font; font.pixelSize: 11 * card.s; font.bold: true
                        }
                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: card.service.invoke(card.notifKey, modelData)
                        }
                    }
                }
            }

            // resposta direta (mensageiros)
            Rectangle {
                visible: card.popup && !!card.n && card.n.hasInlineReply
                Layout.fillWidth: true
                Layout.topMargin: 6 * card.s
                implicitHeight: 28 * card.s; radius: 0
                color: Theme.surface0
                border.color: replyField.activeFocus ? Theme.accent : "transparent"
                TextInput {
                    id: replyField
                    anchors.fill: parent
                    anchors.leftMargin: 8 * card.s; anchors.rightMargin: 8 * card.s
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.fg
                    font.family: Theme.font; font.pixelSize: 12 * card.s
                    clip: true
                    onAccepted: if (text !== "" && card.n) { card.n.sendInlineReply(text); card.service.remove(card.notifKey) }
                    Keys.onEscapePressed: focus = false
                }
                Text {
                    visible: replyField.text === ""
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: 8 * card.s
                    text: card.n && card.n.inlineReplyPlaceholder ? card.n.inlineReplyPlaceholder : "Responder…"
                    color: Theme.gray
                    font.family: Theme.font; font.pixelSize: 12 * card.s
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: replyField.forceActiveFocus() }
            }
        }
    }

    // barra do tempo restante, na base
    Rectangle {
        visible: card.timeout > 0
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.bottomMargin: 1
        anchors.leftMargin: card.radius
        width: (parent.width - 2 * card.radius) * card.remaining
        height: 2
        radius: 0
        color: Qt.alpha(Theme.accent, 0.6)
    }
}
