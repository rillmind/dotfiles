import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "."

// Launcher.qml – lançador do Vinho: só texto, quadrado, no centro da tela.
// Busca aproximada por nome, nome genérico, palavras-chave e id, sem diferenciar maiúsculas nem acentos,
// com os mais usados primeiro; "=2*3" calcula (Enter copia) e ">" lista os comandos do sistema.
// Teclas: Ctrl+N/↓/Tab desce, Ctrl+P/↑/Shift+Tab sobe, PageUp/PageDown, Ctrl+U limpa, Enter abre, Esc fecha.
Scope {
    id: launcher
    property bool open: false
    property bool lua: true                  // o Hyprland usa config em Lua (muda o comando de sair)
    signal panelRequested(string page)       // "" abre a central; "calendario" e "notificacoes" também valem

    function toggle() { open ? close() : show("") }
    property string initialText: ""
    function show(prefix) { initialText = prefix || ""; query = initialText; selected = 0; confirmKey = ""; open = true }
    function close() { open = false }

    IpcHandler {
        target: "launcher"
        function toggle(): void { launcher.toggle() }
        function open(): void { launcher.show("") }
        function power(): void { launcher.open ? launcher.close() : launcher.show(">") }
        function close(): void { launcher.close() }
        function buscar(texto: string): void { launcher.show(texto) }
    }

    // ── Uso dos apps (arquivo comum aos temas) ─────────────
    property var usage: ({})
    FileView {
        id: usageFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/launcher-usage.json"
        printErrors: false
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
    readonly property int maxRows: 8
    readonly property int rowHeight: 34
    property int selected: 0
    property string confirmKey: ""

    function norm(t) { return (t || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "") }
    // começo > início de palavra > contém > subsequência
    // solta = aceita letras em ordem com buracos (só no nome: nas palavras-chave acha de tudo)
    function score(q, text, solta) {
        var t = norm(text)
        if (t === "") return -1
        if (t === q) return 120
        if (t.startsWith(q)) return 100
        var idx = t.indexOf(q)
        if (idx > 0 && /[\s\-_.]/.test(t[idx - 1])) return 85
        if (idx >= 0) return 65
        if (!solta) return -1
        var ti = 0, gaps = 0, last = -1
        for (var qi = 0; qi < q.length; qi++) {
            var found = t.indexOf(q[qi], ti)
            if (found < 0) return -1
            if (last >= 0) gaps += found - last - 1
            last = found; ti = found + 1
        }
        return Math.max(1, 40 - gaps)
    }
    readonly property string qsDir: Quickshell.env("HOME") + "/.config/quickshell"
    readonly property var systemCommands: [
        { key: "lock",     title: "Bloquear",        words: "lock tela trancar",               cmd: [Quickshell.env("HOME") + "/.config/quickshell-bloqueio/bloquear.sh"] },
        { key: "suspend",  title: "Suspender",       words: "suspend dormir sleep",            cmd: ["systemctl", "suspend"] },
        { key: "logout",   title: "Sair",            words: "logout encerrar sessao exit",     cmd: ["hyprctl", "dispatch", lua ? "hl.dsp.exit()" : "exit"], confirm: true },
        { key: "reboot",   title: "Reiniciar",       words: "reboot restart",                  cmd: ["systemctl", "reboot"], confirm: true },
        { key: "poweroff", title: "Desligar",        words: "shutdown poweroff",               cmd: ["systemctl", "poweroff"], confirm: true },
        { key: "central",  title: "Central",         words: "painel controle control center",  panel: "" },
        { key: "rede",     title: "Rede",            words: "wifi internet network",           panel: "network" },
        { key: "som",      title: "Som",             words: "volume audio sound",              panel: "sound" },
        { key: "bt",       title: "Bluetooth",       words: "fone",                            panel: "bluetooth" },
        { key: "telas",    title: "Telas",           words: "monitor display resolucao",       panel: "displays" },
        { key: "notif",    title: "Notificações",    words: "avisos",                          panel: "notificacoes" },
        { key: "cal",      title: "Calendário",      words: "data feriado",                    panel: "calendario" },
        { key: "tema",     title: "Trocar tema",     words: "aparencia theme",                 cmd: [qsDir + "/tema.sh", "trocar"] },
        { key: "fundo",    title: "Papel de parede", words: "wallpaper imagem",                cmd: [qsDir + "/aparencia.sh", "wallpaper"] }
    ]
    // calculadora segura: só números, operadores e parênteses
    function calc(expr) {
        expr = expr.replace(/,/g, ".").replace(/\^/g, "**").trim()
        if (expr === "" || !/^[0-9+\-*/%().\s]+$/.test(expr)) return null
        try {
            var v = Function('"use strict"; return (' + expr + ')')()
            return typeof v !== "number" || !isFinite(v) ? null : Math.round(v * 1e10) / 1e10
        } catch (e) { return null }
    }

    readonly property var results: {
        var q = norm(query.trim())
        if (q.startsWith("=")) {
            var r = calc(q.substring(1))
            return [{ kind: "calc", title: r === null ? "expressão inválida" : "= " + String(r).replace(".", ","),
                      subtitle: r === null ? "+ - * / ^ % ( )" : "Enter copia", value: r === null ? "" : String(r) }]
        }
        var sysOnly = q.startsWith(">")
        var sq = sysOnly ? q.substring(1).trim() : q
        var sys = []
        for (var c of systemCommands) {
            var s = sq === "" ? (sysOnly ? 50 : -1) : Math.max(score(sq, c.title, true), score(sq, c.words) - 10)
            if (s >= (sysOnly ? 1 : 60)) sys.push({ kind: "sys", title: c.title, subtitle: c.panel !== undefined ? "painel" : "sistema", command: c, score: s })
        }
        if (sysOnly) return sq === "" ? sys : sys.sort((a, b) => b.score - a.score)

        var apps = []
        for (var e of DesktopEntries.applications.values) {
            if (e.noDisplay) continue
            var base = 0
            if (q !== "") {
                base = Math.max(score(q, e.name, true), score(q, e.genericName) - 15, score(q, (e.keywords || []).join(" ")) - 20, score(q, e.id) - 25)
                if (base < 0) continue
            }
            var used = usage[e.id] || 0
            apps.push({ kind: "app", title: e.name, subtitle: e.genericName || "", entry: e, score: base + Math.min(30, used * 3), used: used })
        }
        apps.sort((a, b) => (b.score - a.score) || (b.used - a.used) || a.title.localeCompare(b.title))
        if (q === "") return apps
        var out = apps.slice(0, 40)
        for (var x of sys) {
            var pos = out.findIndex(a => a.score < x.score)
            out.splice(pos < 0 ? out.length : pos, 0, x)
        }
        return out
    }
    onResultsChanged: if (selected >= results.length) selected = Math.max(0, results.length - 1)
    onQueryChanged: { selected = 0; confirmKey = "" }

    function activate(item) {
        if (!item) return
        if (item.kind === "app") {
            bumpUsage(item.entry.id)
            if (item.entry.runInTerminal) Quickshell.execDetached(["ghostty", "-e", ...item.entry.command])
            else item.entry.execute()
        } else if (item.kind === "calc") {
            if (item.value === "") return
            Quickshell.clipboardText = item.value
        } else {
            var c = item.command
            if (c.confirm && confirmKey !== c.key) { confirmKey = c.key; return }
            if (c.panel !== undefined) { close(); panelRequested(c.panel); return }
            Quickshell.execDetached(c.cmd)
        }
        close()
    }
    function move(d, wrap) {
        var n = results.length
        if (n === 0) return
        selected = wrap ? (selected + d + n) % n : Math.max(0, Math.min(n - 1, selected + d))
        confirmKey = ""
    }
    function escapeHtml(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    // trecho que casou em dourado (só quando é contínuo)
    function realce(title) {
        var q = norm(query.trim()).replace(/^>\s*/, ""), t = norm(title)
        var i = q === "" || t.length !== title.length ? -1 : t.indexOf(q)
        if (i < 0) return escapeHtml(title)
        return escapeHtml(title.slice(0, i)) + '<font color="' + Theme.yellow + '">' + escapeHtml(title.slice(i, i + q.length)) + "</font>" + escapeHtml(title.slice(i + q.length))
    }

    PanelWindow {
        id: win
        visible: launcher.open
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "quickshell-launcher"
        implicitWidth: 520
        implicitHeight: 64 + launcher.maxRows * launcher.rowHeight
        color: "transparent"
        HyprlandFocusGrab {
            windows: [win]
            active: win.visible
            onCleared: launcher.close()
        }
        onVisibleChanged: if (visible) { search.text = launcher.initialText; search.cursorPosition = search.text.length; search.forceActiveFocus(); list.positionViewAtBeginning() }

        Rectangle {
            anchors.fill: parent
            color: Theme.bg
            border.color: Theme.frame
            border.width: 2

            RowLayout {
                id: head
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 14; rightMargin: 14 }
                height: 32
                spacing: 10
                Text {
                    text: launcher.query.startsWith("=") ? "=" : ">"
                    color: Theme.accent
                    font.family: Theme.font; font.pixelSize: 17; font.bold: true
                }
                TextInput {
                    id: search
                    Layout.fillWidth: true
                    color: Theme.fg
                    selectionColor: Theme.frame
                    selectedTextColor: Theme.bright
                    font.family: Theme.font; font.pixelSize: 16
                    clip: true
                    focus: true
                    onTextChanged: launcher.query = text
                    Keys.onPressed: event => {
                        var k = event.key, ctrl = event.modifiers & Qt.ControlModifier
                        if (k === Qt.Key_Escape) launcher.close()
                        else if ((ctrl && k === Qt.Key_N) || k === Qt.Key_Down || k === Qt.Key_Tab) launcher.move(1, true)
                        else if ((ctrl && k === Qt.Key_P) || k === Qt.Key_Up || k === Qt.Key_Backtab) launcher.move(-1, true)
                        else if (k === Qt.Key_PageDown) launcher.move(launcher.maxRows, false)
                        else if (k === Qt.Key_PageUp) launcher.move(-launcher.maxRows, false)
                        else if (ctrl && k === Qt.Key_U) text = ""
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) launcher.activate(launcher.results[launcher.selected])
                        else return
                        event.accepted = true
                    }
                    Text {
                        visible: search.text === ""
                        text: "apps   = conta   > sistema"
                        color: Theme.gray
                        font: search.font
                    }
                }
                Text {
                    text: list.count
                    color: Theme.gray
                    font.family: Theme.font; font.pixelSize: 13
                }
            }

            ListView {
                id: list
                anchors { left: parent.left; right: parent.right; top: head.bottom; margins: 12; topMargin: 8 }
                height: launcher.maxRows * launcher.rowHeight
                clip: true
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
                    readonly property bool confirming: isSel && modelData.kind === "sys" && launcher.confirmKey === modelData.command.key
                    width: list.width
                    height: launcher.rowHeight
                    color: confirming ? Theme.frame : isSel ? Theme.selection : rowMouse.containsMouse ? Theme.surface0 : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12
                        Text {
                            text: launcher.realce(row.modelData.title)
                            textFormat: Text.StyledText
                            color: row.isSel ? Theme.bright : Theme.soft
                            font.family: Theme.font; font.pixelSize: 16
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: row.confirming ? "Enter de novo para confirmar" : row.modelData.subtitle
                            color: row.confirming ? Theme.bright : Theme.gray
                            font.family: Theme.font; font.pixelSize: 12
                            elide: Text.ElideRight
                            Layout.maximumWidth: 230
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
                anchors.centerIn: list
                visible: list.count === 0
                text: "nada encontrado"
                color: Theme.gray
                font.family: Theme.font; font.pixelSize: 15
            }
        }
    }
}
