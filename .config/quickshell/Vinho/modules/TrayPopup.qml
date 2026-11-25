import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "."

// TrayPopup.qml – menuzinho da bandeja, aberto pela setinha da barra.
// Esquerdo: ação do app · direito: menu dele · meio: ação secundária.
Rectangle {
    id: tray
    property var barWindow: null        // os menus saem da barra: continuam abertos se este popup fechar
    signal dismissed()
    readonly property int colunas: Math.max(1, Math.min(6, SystemTray.items.values.length))
    implicitWidth: SystemTray.items.values.length ? colunas * 34 + 16 : vazio.implicitWidth + 28
    implicitHeight: Math.max(1, Math.ceil(SystemTray.items.values.length / 6)) * 34 + 12
    color: Theme.bg
    border.color: Theme.frame
    border.width: 2
    Text {
        id: vazio
        anchors.centerIn: parent
        visible: SystemTray.items.values.length === 0
        text: "bandeja vazia"
        color: Theme.gray
        font.family: Theme.font; font.pixelSize: 13
    }
    Grid {
        anchors.centerIn: parent
        columns: tray.colunas
        Repeater {
            model: SystemTray.items
            Rectangle {
                id: it
                required property var modelData
                width: 34; height: 34
                color: m.containsMouse ? Theme.surface0 : "transparent"
                // ícone que o tema de ícones não tem: inicial do app no lugar
                readonly property string icone: it.modelData.icon
                readonly property string nomeIcone: icone.startsWith("image://icon/") ? icone.substring(13).split("?")[0] : ""
                readonly property bool falta: icone === "" || (nomeIcone !== "" && icone.indexOf("?") < 0 && Quickshell.iconPath(nomeIcone, true) === "")
                IconImage { anchors.centerIn: parent; implicitSize: 18; visible: !it.falta; source: it.falta ? "" : it.icone }
                Text {
                    anchors.centerIn: parent
                    visible: it.falta
                    text: (it.modelData.title || it.modelData.id || "?").charAt(0).toUpperCase()
                    color: Theme.accent
                    font.family: Theme.font; font.pixelSize: 15; font.bold: true
                }
                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        var t = it.modelData
                        if (mouse.button === Qt.MiddleButton) t.secondaryActivate()
                        else if (mouse.button === Qt.RightButton || t.onlyMenu) { if (t.hasMenu) t.display(tray.barWindow, tray.barWindow.width - 220, 0) }
                        else { t.activate(); tray.dismissed() }
                    }
                    onWheel: w => it.modelData.scroll(w.angleDelta.y, false)
                }
            }
        }
    }
}
