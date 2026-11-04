import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets

// Launcher.qml – lançador de apps no estilo da barra/dock.
// Abre com `quickshell ipc call launcher toggle` (ALT+Espaço no Hyprland) ou pelo ícone do Fedora.
// Busca aproximada por nome/nome genérico/palavras-chave, apps mais usados primeiro,
// calculadora ("=2*3") e comandos do sistema (">" lista todos).
// Teclas: Ctrl+N / ↓ desce, Ctrl+P / ↑ sobe, Enter abre, Esc fecha.
Scope {
    id: launcher
    property bool open: false
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSub: "#a6adc8"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colMauve: "#cba6f7"
    property color colBase: "#1e1e2e"
    property color colRed: "#f38ba8"
    property color colPeach: "#fab387"

    function toggle() { open ? close() : show("") }
    // prefix: texto inicial da busca (">" abre direto nos comandos do sistema)
    property string initialText: ""
    function show(prefix) { initialText = prefix || ""; query = initialText; selected = 0; confirmKey = ""; open = true }
    function close() { open = false }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle() }
        function open(): void { launcher.show("") }
        function power(): void { launcher.show(">") }
        function close(): void { launcher.close() }
    }

    // ── Uso dos apps (para ordenar os mais abertos primeiro) ─
    property var usage: ({})
    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher-usage.json")
        printErrors: false   // o arquivo só existe depois do primeiro app aberto
        onLoaded: { try { launcher.usage = JSON.parse(text()) || {} } catch (e) { launcher.usage = {} } }
    }
    function bumpUsage(id) {
        var u = Object.assign({}, usage)
        u[id] = (u[id] || 0) + 1
        usage = u
        usageFile.setText(JSON.stringify(u))
    }

    // ── Busca ──────────────────────────────────────────────
    property string query: ""
    readonly property int maxRows: 5     // linhas visíveis na lista
    readonly property int rowHeight: 52
    property int selected: 0
    property string confirmKey: ""       // comando do sistema aguardando confirmação

    // pontuação aproximada: começo > início de palavra > contém > subsequência
    function score(q, text) {
        if (!text) return -1
        var t = text.toLowerCase()
        if (t === q) return 120
        if (t.startsWith(q)) return 100
        var idx = t.indexOf(q)
        if (idx > 0 && /[\s\-_.]/.test(t[idx - 1])) return 85
        if (idx >= 0) return 65
        // subsequência: todas as letras em ordem, penaliza buracos
        var ti = 0, gaps = 0, last = -1
        for (var qi = 0; qi < q.length; qi++) {
            var found = t.indexOf(q[qi], ti)
            if (found < 0) return -1
            if (last >= 0) gaps += found - last - 1
            last = found; ti = found + 1
        }
        return Math.max(1, 40 - gaps)
    }

    readonly property var systemCommands: [
        { key: "lock",     title: "Bloquear tela",     glyph: "󰌾", words: "bloquear lock tela swaylock",            cmd: ["swaylock"],                             confirm: false },
        { key: "suspend",  title: "Suspender",         glyph: "󰒲", words: "suspender suspend dormir sleep",          cmd: ["systemctl", "suspend"],                 confirm: false },
        { key: "logout",   title: "Sair do Hyprland",  glyph: "󰍃", words: "sair logout encerrar sessão exit",        cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"], confirm: true },
        { key: "reboot",   title: "Reiniciar",         glyph: "󰜉", words: "reiniciar reboot restart",                cmd: ["systemctl", "reboot"],                  confirm: true },
        { key: "poweroff", title: "Desligar",          glyph: "󰐥", words: "desligar shutdown poweroff power off",    cmd: ["systemctl", "poweroff"],                confirm: true }
    ]

    // calculadora segura: só números, operadores e parênteses
    function calc(expr) {
        expr = expr.replace(/,/g, ".").replace(/\^/g, "**").trim()
        if (expr === "" || !/^[0-9+\-*/%().\s*]+$/.test(expr)) return null
        try {
            var v = Function('"use strict"; return (' + expr + ')')()
            if (typeof v !== "number" || !isFinite(v)) return null
            return Math.round(v * 1e10) / 1e10
        } catch (e) { return null }
    }

    readonly property var results: {
        var q = query.trim().toLowerCase()
        var out = []

        // calculadora
        if (q.startsWith("=")) {
            var r = calc(q.substring(1))
            out.push({ kind: "calc", title: r === null ? "Expressão inválida" : "= " + String(r).replace(".", ","),
                       subtitle: r === null ? "Use números e + − × ÷ ^ ( )" : "Enter copia o resultado", glyph: "󰃬", value: r === null ? "" : String(r) })
            return out
        }

        // comandos do sistema
        var sysOnly = q.startsWith(">")
        var sq = sysOnly ? q.substring(1).trim() : q
        var sys = []
        for (var c of systemCommands) {
            var s = sq === "" ? (sysOnly ? 50 : -1) : Math.max(score(sq, c.title), score(sq, c.words) - 10)
            if (s >= (sysOnly ? 0 : 60)) sys.push({ kind: "sys", title: c.title, subtitle: c.confirm ? "Comando do sistema · pede confirmação" : "Comando do sistema", glyph: c.glyph, cmd: c.cmd, confirm: c.confirm, key: c.key, score: s })
        }
        if (sysOnly) return sys

        // apps
        var apps = []
        for (var e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            var base
            if (q === "") base = 0
            else {
                base = Math.max(score(q, e.name), score(q, e.genericName) - 15, score(q, (e.keywords || []).join(" ")) - 20, score(q, e.id) - 25)
                if (base < 0) continue
            }
            var used = usage[e.id] || 0
            apps.push({ kind: "app", title: e.name, subtitle: e.genericName || e.comment || "", entry: e, score: base + Math.min(30, used * 3), used: used })
        }
        apps.sort((a, b) => (b.score - a.score) || (b.used - a.used) || a.title.localeCompare(b.title))
        if (q === "") {
            // sem busca: só os mais usados (ou os primeiros em ordem alfabética, enquanto não há histórico)
            var top = apps.filter(a => a.used > 0)
            return (top.length > 0 ? top : apps).slice(0, launcher.maxRows)
        }
        out = apps.slice(0, 40)
        // comandos do sistema aparecem depois dos apps (a não ser que batam melhor)
        for (var x of sys) {
            var pos = out.findIndex(a => a.score < x.score)
            out.splice(pos < 0 ? out.length : pos, 0, x)
        }
        return out
    }
    onResultsChanged: if (selected >= results.length) selected = Math.max(0, results.length - 1)
    onQueryChanged: { selected = 0; confirmKey = "" }

    Process { id: runProc }
    function activate(item) {
        if (!item) return
        if (item.kind === "app") {
            bumpUsage(item.entry.id)
            item.entry.execute()
            close()
        } else if (item.kind === "calc") {
            if (item.value === "") return
            runProc.command = ["wl-copy", item.value]
            runProc.running = true
            close()
        } else if (item.kind === "sys") {
            if (item.confirm && confirmKey !== item.key) { confirmKey = item.key; return }
            runProc.command = item.cmd
            runProc.running = true
            close()
        }
    }
    function move(delta) {
        if (results.length === 0) return
        selected = (selected + delta + results.length) % results.length
        confirmKey = ""
    }

    // ── Janela ─────────────────────────────────────────────
    PanelWindow {
        id: win
        visible: launcher.open
        // abre no monitor em foco
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"
        // sem âncoras: o compositor centraliza a janela na tela
        implicitWidth: 580
        implicitHeight: panel.implicitHeight
        color: "transparent"

        HyprlandFocusGrab {
            windows: [win]
            active: win.visible
            onCleared: launcher.close()
        }
        onVisibleChanged: if (visible) { search.text = launcher.initialText; search.cursorPosition = search.text.length; search.forceActiveFocus() }

        Rectangle {
            id: panel
            anchors.left: parent.left
            anchors.right: parent.right
            implicitHeight: col.implicitHeight + 20
            radius: 16
            color: "#F21e1e2e"
            border.color: launcher.colMauve
            border.width: 2

            ColumnLayout {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 6

                // campo de busca
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 42
                    radius: 10
                    color: launcher.colSurface0
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 8
                        Text {
                            text: launcher.query.startsWith("=") ? "󰃬" : launcher.query.startsWith(">") ? "" : ""
                            color: launcher.colMauve
                            font.family: launcher.fontFamily; font.pixelSize: 22
                        }
                        TextInput {
                            id: search
                            Layout.fillWidth: true
                            color: launcher.colText
                            selectionColor: launcher.colMauve
                            selectedTextColor: launcher.colBase
                            font.family: launcher.fontFamily; font.pixelSize: 20
                            clip: true
                            focus: true
                            onTextChanged: launcher.query = text
                            Keys.onPressed: event => {
                                var ctrl = event.modifiers & Qt.ControlModifier
                                if (event.key === Qt.Key_Escape) { launcher.close(); event.accepted = true }
                                else if ((ctrl && event.key === Qt.Key_N) || event.key === Qt.Key_Down) { launcher.move(1); event.accepted = true }
                                else if ((ctrl && event.key === Qt.Key_P) || event.key === Qt.Key_Up) { launcher.move(-1); event.accepted = true }
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { launcher.activate(launcher.results[launcher.selected]); event.accepted = true }
                            }
                        }
                    }
                }

                // resultados
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, launcher.maxRows * (launcher.rowHeight + spacing))
                    visible: count > 0
                    clip: true
                    spacing: 2
                    model: launcher.results
                    currentIndex: launcher.selected
                    highlightMoveDuration: 0
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        required property int index
                        readonly property bool isSel: index === launcher.selected
                        readonly property bool needsConfirm: modelData.kind === "sys" && launcher.confirmKey === modelData.key
                        width: list.width
                        height: launcher.rowHeight
                        radius: 10
                        color: isSel ? (needsConfirm ? Qt.rgba(0.95, 0.55, 0.66, 0.25) : launcher.colSurface1) : rowMouse.containsMouse ? launcher.colSurface0 : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 12
                            // ícone do app ou glifo
                            Item {
                                implicitWidth: 32; implicitHeight: 32
                                IconImage {
                                    id: appIcon
                                    anchors.fill: parent
                                    visible: row.modelData.kind === "app" && status === Image.Ready
                                    source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.entry.icon, true) : ""
                                    asynchronous: true
                                }
                                Text {
                                    anchors.fill: parent
                                    visible: !appIcon.visible
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                    text: row.modelData.kind === "app" ? "" : row.modelData.glyph
                                    color: row.modelData.kind === "sys" && row.modelData.confirm ? launcher.colPeach : launcher.colMauve
                                    font.family: launcher.fontFamily; font.pixelSize: 24
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: row.modelData.title
                                    color: launcher.colText
                                    font.family: launcher.fontFamily; font.pixelSize: 19; font.bold: row.isSel
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    visible: row.needsConfirm
                                    text: "Pressione Enter de novo para confirmar"
                                    color: launcher.colRed
                                    font.family: launcher.fontFamily; font.pixelSize: 16
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                            }
                            Text {
                                visible: row.isSel
                                text: "󰌑"
                                color: launcher.colSub
                                font.family: launcher.fontFamily; font.pixelSize: 20
                            }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { launcher.selected = row.index; launcher.activate(row.modelData) }
                        }
                    }
                }

                Text {
                    visible: list.count === 0
                    text: "Nada encontrado"
                    color: launcher.colSub
                    font.family: launcher.fontFamily; font.pixelSize: 18
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 4; Layout.bottomMargin: 6
                }
            }
        }
    }
}
