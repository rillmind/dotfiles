import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Wayland

Item {
    id: dockRoot
    // vidro fosco catppuccin – fundo único vem do PanelWindow em shell.qml; aqui só layout transparente
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colMauve: "#cba6f7"
    property color colSurface0: "#313244"

    // dockClients global (via hyprctl) – funciona mesmo em workspace vazio
    property var dockClients: []
    property string activeWindowAddress: ""
    // lista de janelas via Hyprland + ToplevelManager (fallback)
    signal requestFocus(var toplevel)
    signal requestClose(var toplevel)
    signal requestFocusClient(string address)
    signal requestCloseClient(string address)

    // exatamente mesmo mapeamento da barra superior (shell.qml:getAppIcon)
    function appIcon(appId, title) {
        var raw = (appId || "") + " " + (title || "")
        var s = raw.toLowerCase()
        // ghostty pode vir como com.mitchellh.ghostty, Ghostty, etc.
        if (s.indexOf("ghostty") !== -1 || s.indexOf("mitchellh") !== -1) return ""
        if (s.indexOf("zen") !== -1 || s.indexOf("firefox") !== -1 || s.indexOf("chrome") !== -1 || s.indexOf("chromium") !== -1) return ""
        if (s.indexOf("code") !== -1 || s.indexOf("codium") !== -1) return ""
        if (s.indexOf("spotify") !== -1) return ""
        if (s.indexOf("zathura") !== -1) return ""
        if (s.indexOf("obsidian") !== -1) return ""
        if (s.indexOf("nautilus") !== -1 || s.indexOf("cosmic-files") !== -1 || s.indexOf("files") !== -1) return ""
        if (s.indexOf("steam") !== -1) return ""
        if (s.indexOf("mission") !== -1) return ""
        if (s.indexOf("pavu") !== -1 || s.indexOf("pulsemixer") !== -1) return ""
        // fallback tenta pelo title se appId vazio (ex: ghostty title "t" não ajuda, mas mantém genérico)
        return ""
    }

    // ordenação por workspace (1→10) – reflete onde a janela está, não ordem de abertura
    property int _toplevelCount: {
        try { if (Hyprland && Hyprland.toplevels) { if (Hyprland.toplevels.values) return Hyprland.toplevels.values.length; return Hyprland.toplevels.length } } catch(e) {}
        return 0
    }
    property int _dockClientsCount: dockClients ? dockClients.length : 0
    property var sortedToplevels: {
        var _ = _toplevelCount
        var __ = _dockClientsCount
        // dockClients global tem prioridade (funciona em workspace vazio)
        if (dockClients && dockClients.length > 0) {
            try {
                return dockClients.map(function(c){
                    return { address: c.address, appId: c.class, title: c.title, workspace: { id: c.workspace }, activated: c.address === activeWindowAddress }
                })
            } catch(e) { return dockClients }
        }
        var src = null
        try {
            if (Hyprland && Hyprland.toplevels) {
                src = Hyprland.toplevels.values ? Hyprland.toplevels.values : Hyprland.toplevels
            } else if (typeof ToplevelManager !== "undefined" && ToplevelManager.toplevels) {
                src = ToplevelManager.toplevels.values ? ToplevelManager.toplevels.values : ToplevelManager.toplevels
            }
        } catch(e) {}
        var list = []
        try { if (src) list = Array.from(src); } catch(e) { try { list = [...src] } catch(e2) { list = [] } }
        try {
            list.sort(function(a,b){
                var wa = 99, wb = 99
                try { wa = (a.workspace && a.workspace.id) ? a.workspace.id : (a.workspaceId !== undefined ? a.workspaceId : (a.address !== undefined ? parseInt(a.address) % 10 : 99)) } catch(e) { wa = 99 }
                try { wb = (b.workspace && b.workspace.id) ? b.workspace.id : (b.workspaceId !== undefined ? b.workspaceId : (b.address !== undefined ? parseInt(b.address) % 10 : 99)) } catch(e) { wb = 99 }
                if (wa !== wb) return wa - wb
                // tie: ordena por address (aprox ordem abertura)
                try { return a.address - b.address } catch(e) { return 0 }
            })
        } catch(e) {}
        return list
    }

    implicitHeight: 80
    implicitWidth: Math.max(200, Math.min(900, dockRow.implicitWidth + 16))

    RowLayout {
        id: dockRow
        anchors.centerIn: parent
        spacing: 8
        // Hyprland toplevels ordenados por workspace – ícone exato da janela (mesmo mapeamento da barra superior)
        // funciona mesmo em workspace vazio porque usa dockClients global (hyprctl)
        Repeater {
            model: dockRoot.sortedToplevels
            Rectangle {
                id: dockItem
                // dockClients usa .class/.title, HyprlandToplevel usa .appId/.title – normaliza
                property string _appId: modelData.class !== undefined ? modelData.class : (modelData.appId || "")
                property string _title: modelData.title || ""
                property bool isActive: (modelData.address && dockRoot.activeWindowAddress && modelData.address === dockRoot.activeWindowAddress) || modelData.activated
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: 14
                color: isActive ? "#cba6f7" : "#313244"
                border.color: isActive ? "#cba6f7" : "transparent"
                border.width: isActive ? 2 : 0
                // scale hover OSX
                property bool hovered: false
                scale: hovered ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: dockRoot.appIcon(_appId, _title)
                    color: isActive ? "#1e1e2e" : "#cdd6f4"
                    font.family: dockRoot.fontFamily
                    font.pixelSize: 30
                    font.bold: true
                }

                // indicador dot para janela ativa/foco
                Rectangle {
                    visible: isActive
                    width: 4; height: 4; radius: 2
                    color: "#1e1e2e"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: dockItem.hovered = true
                    onExited: dockItem.hovered = false
                    onClicked: {
                        var addr = modelData.address
                        // dockClients address já vem como "0x..." string, HyprlandToplevel address é número
                        if (typeof addr === "string" && addr.indexOf("0x") === 0) {
                            // dockClients: dispara via shell signal para garantir
                            Hyprland.dispatch("focuswindow address:" + addr)
                            dockRoot.requestFocusClient(addr)
                        } else if (modelData.activated) {
                            Hyprland.dispatch("focuswindow address:0x" + addr.toString(16))
                        } else {
                            if (modelData.activate) modelData.activate()
                            else Hyprland.dispatch("focuswindow address:0x" + addr.toString(16))
                        }
                    }
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onPressed: mouse => {
                        var addr = modelData.address
                        var addrStr = (typeof addr === "string" && addr.indexOf("0x") === 0) ? addr : "0x" + addr.toString(16)
                        if (mouse.button === Qt.RightButton) {
                            Hyprland.dispatch("closewindow address:" + addrStr)
                            dockRoot.requestCloseClient(addrStr)
                        } else if (mouse.button === Qt.MiddleButton) {
                            Hyprland.dispatch("closewindow address:" + addrStr)
                            dockRoot.requestCloseClient(addrStr)
                        }
                    }
                }
            }
        }

        // fallback quando não há toplevels (mostra placeholder)
        Text {
            visible: dockRoot.sortedToplevels.length === 0
            text: "—"
            color: "#cdd6f4"
            font.family: dockRoot.fontFamily
            font.pixelSize: 14
            opacity: 0.4
            Layout.alignment: Qt.AlignVCenter
        }

        // fallback via ToplevelManager já incluso em sortedToplevels; Repeater extra removido
        Repeater {
            model: 0
            Rectangle {
                Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 12
                color: modelData.activated ? "#cba6f7" : "#313244"
                Text {
                    anchors.centerIn: parent
                    text: dockRoot.appIcon(modelData.appId, modelData.title)
                    color: modelData.activated ? "#1e1e2e" : "#cdd6f4"
                    font.family: dockRoot.fontFamily; font.pixelSize: 22; font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.scale = 1.12
                    onExited: parent.scale = 1.0
                    onClicked: modelData.activate ? modelData.activate() : null
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    // tooltip título ao hover
    // (simples, mostra title da janela hovered - usamos o último hovered)
}
