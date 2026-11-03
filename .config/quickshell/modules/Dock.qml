import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

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

    // menu do botão direito (um só, reposicionado no ícone clicado)
    property bool menuOpen: false
    property Item menuItem: null
    property string menuAddress: ""
    property string menuAppId: ""
    property string menuTitle: ""

    function dispatchOn(lua) { Hyprland.dispatch(lua.replace("%W", '"address:' + menuAddress + '"')) }
    function openMenu(item, address, appId, title) {
        menuItem = item; menuAddress = address; menuAppId = appId; menuTitle = title
        menuOpen = true
    }

    // ícone real do app (tema de ícones via .desktop); "" se não achar
    function appIconPath(appId) {
        if (!appId) return ""
        var entry = DesktopEntries.heuristicLookup(appId)
        var name = (entry && entry.icon) ? entry.icon : appId
        return Quickshell.iconPath(name, true)
    }

    // fallback em Nerd Font: mesmo mapeamento da barra superior (shell.qml:getAppIcon)
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

    // o respiro em volta fica por conta do fundo (shell.qml), aqui só o tamanho dos ícones
    implicitHeight: 64
    implicitWidth: sortedToplevels.length === 0 ? 64 : dockRow.implicitWidth

    RowLayout {
        id: dockRow
        anchors.centerIn: parent
        spacing: 6
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
                property string _iconPath: dockRoot.appIconPath(_appId)
                Layout.preferredWidth: 64
                Layout.preferredHeight: 64
                radius: 14
                color: hovered ? "#45475a" : "#313244"
                border.color: isActive ? "#cba6f7" : "transparent"
                border.width: isActive ? 2 : 0
                // scale hover OSX
                property bool hovered: false
                scale: hovered ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 120 } }

                IconImage {
                    visible: dockItem._iconPath !== ""
                    anchors.centerIn: parent
                    implicitSize: 44
                    source: dockItem._iconPath
                }

                Text {
                    visible: dockItem._iconPath === ""
                    // centraliza pelo próprio glifo (Nerd Font desalinha com anchors.centerIn)
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: dockRoot.appIcon(_appId, _title)
                    color: isActive ? "#cba6f7" : "#cdd6f4"
                    font.family: dockRoot.fontFamily
                    font.pixelSize: 32
                    font.bold: true
                }

                // indicador dot para janela ativa/foco
                Rectangle {
                    visible: isActive
                    width: 4; height: 4; radius: 2
                    color: "#cba6f7"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 2
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: 2
                    onEntered: dockItem.hovered = true
                    onExited: dockItem.hovered = false
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button !== Qt.LeftButton) return
                        var addr = modelData.address
                        var addrStr = (typeof addr === "string" && addr.indexOf("0x") === 0) ? addr : "0x" + addr.toString(16)
                        var ws = modelData.workspace ? (modelData.workspace.id !== undefined ? modelData.workspace.id : modelData.workspace) : null
                        // se janela está em outro workspace, troca antes de focar
                        if (ws) Hyprland.dispatch('hl.dsp.focus({ workspace = "' + ws + '" })')
                        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + addrStr + '" })')
                        dockRoot.requestFocusClient(addrStr)
                        // fallback via activate para toplevels
                        if (modelData.activate && typeof addr !== "string") { try { modelData.activate() } catch(e) {} }
                    }
                    onPressed: mouse => {
                        var addr = modelData.address
                        var addrStr = (typeof addr === "string" && addr.indexOf("0x") === 0) ? addr : "0x" + addr.toString(16)
                        if (mouse.button === Qt.RightButton) {
                            dockRoot.openMenu(dockItem, addrStr, dockItem._appId, dockItem._title)
                        } else if (mouse.button === Qt.MiddleButton) {
                            Hyprland.dispatch('hl.dsp.window.close({ window = "address:' + addrStr + '" })')
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

    // ── Menu do botão direito ──────────────────────────────
    component MenuEntry: Rectangle {
        id: entry
        property string label: ""
        property string icon: ""
        property color tint: "#cdd6f4"
        signal activated()
        Layout.fillWidth: true
        implicitHeight: 30
        radius: 8
        color: entryMouse.containsMouse ? "#45475a" : "transparent"
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10
            Text { text: entry.icon; color: entry.tint; font.family: dockRoot.fontFamily; font.pixelSize: 14 }
            Text { text: entry.label; color: entry.tint; font.family: dockRoot.fontFamily; font.pixelSize: 13; Layout.fillWidth: true }
        }
        MouseArea {
            id: entryMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { entry.activated(); dockRoot.menuOpen = false }
        }
    }

    PopupWindow {
        id: dockMenu
        visible: dockRoot.menuOpen && dockRoot.menuItem !== null
        anchor.item: dockRoot.menuItem
        anchor.edges: Edges.Top
        anchor.gravity: Edges.Top
        anchor.margins.top: -8
        implicitWidth: 230
        implicitHeight: menuCol.implicitHeight + 16
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: "#F21e1e2e"
            border.color: "#45475a"
            border.width: 1

            ColumnLayout {
                id: menuCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 2

                Text {
                    text: dockRoot.menuTitle
                    color: "#a6adc8"
                    font.family: dockRoot.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.bottomMargin: 4
                }

                MenuEntry { icon: "󰁔"; label: "Focar"; onActivated: dockRoot.dispatchOn('hl.dsp.focus({ window = %W })') }
                MenuEntry {
                    icon: ""; label: "Nova janela"
                    visible: DesktopEntries.heuristicLookup(dockRoot.menuAppId) !== null
                    onActivated: { var e = DesktopEntries.heuristicLookup(dockRoot.menuAppId); if (e) e.execute() }
                }
                MenuEntry { icon: "󰖲"; label: "Flutuar / encaixar"; onActivated: dockRoot.dispatchOn('hl.dsp.window.float({ window = %W, action = "toggle" })') }
                MenuEntry { icon: "󰐃"; label: "Fixar em todos os workspaces"; onActivated: dockRoot.dispatchOn('hl.dsp.window.pin({ window = %W, action = "toggle" })') }
                MenuEntry { icon: "󰊓"; label: "Tela cheia"; onActivated: dockRoot.dispatchOn('hl.dsp.window.fullscreen({ window = %W, mode = "fullscreen" })') }

                Text {
                    text: "Mover para o workspace"
                    color: "#a6adc8"
                    font.family: dockRoot.fontFamily
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
                            radius: 7
                            color: wsMouse.containsMouse ? "#cba6f7" : "#313244"
                            Text {
                                anchors.centerIn: parent
                                text: index + 1
                                color: wsMouse.containsMouse ? "#1e1e2e" : "#cdd6f4"
                                font.family: dockRoot.fontFamily
                                font.pixelSize: 12
                            }
                            MouseArea {
                                id: wsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    dockRoot.dispatchOn('hl.dsp.window.move({ window = %W, workspace = "' + (index + 1) + '", follow = false })')
                                    dockRoot.menuOpen = false
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: "#45475a"; Layout.topMargin: 2; Layout.bottomMargin: 2 }

                MenuEntry { icon: "󰅖"; label: "Fechar"; onActivated: dockRoot.dispatchOn('hl.dsp.window.close({ window = %W })') }
                MenuEntry { icon: "󰚌"; label: "Forçar fechamento"; tint: "#f38ba8"; onActivated: dockRoot.dispatchOn('hl.dsp.window.kill({ window = %W })') }
            }
        }
    }

    // fecha o menu ao clicar fora dele
    HyprlandFocusGrab {
        windows: [dockMenu]
        active: dockMenu.visible
        onCleared: dockRoot.menuOpen = false
    }
}
