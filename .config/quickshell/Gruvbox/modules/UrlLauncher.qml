import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "."

// UrlLauncher.qml – launcher no estilo barra de endereço de navegador: desce uma barra fina no topo,
// na largura toda da tela, e os apps aparecem como sugestões de pesquisa logo abaixo.
// Sem nada digitado, a barra mostra a janela em foco como se fosse a página aberta (ícone = favicon,
// título = URL). Mesmas funções do launcher do Catppuccin: busca aproximada, mais usados primeiro nos resultados,
// calculadora ("=2*3") e comandos do sistema (">" lista todos).
// Teclas: Ctrl+N / ↓ desce, Ctrl+P / ↑ sobe, Tab completa, Enter abre, Esc fecha.
Scope {
    id: launcher
    property bool open: false
    // janela em foco (vem do shell.qml)
    property string windowTitle: ""
    property string windowClass: ""
    // medidas do contorno da tela (shell.qml): o launcher é a faixa de cima dele crescendo
    property int leftInset: 46        // largura da barra lateral
    property int frameWidth: 14
    property int cornerRadius: 16
    // hora: só aparece aqui (com o launcher aberto); clique abre o calendário
    property string clockTooltip: ""     // dia da semana, semana e feriados (vem do shell.qml)
    signal calendarRequested()
    property date now: new Date()
    Timer { interval: 1000; running: launcher.open; repeat: true; triggeredOnStart: true; onTriggered: launcher.now = new Date() }
    readonly property string clockText: {
        var d = now
        var wd = ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"][d.getDay()]
        var mo = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"][d.getMonth()]
        return wd + ", " + d.getDate() + " " + mo + "  " + Qt.formatTime(d, "hh:mm")
    }

    function toggle() { open ? close() : show("") }
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

    // ── Uso dos apps (mesmo arquivo do Catppuccin) ─────────
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
    readonly property int rowHeight: 40
    property int selected: 0
    property string confirmKey: ""

    function score(q, text) {
        if (!text) return -1
        var t = text.toLowerCase()
        if (t === q) return 120
        if (t.startsWith(q)) return 100
        var idx = t.indexOf(q)
        if (idx > 0 && /[\s\-_.]/.test(t[idx - 1])) return 85
        if (idx >= 0) return 65
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
        { key: "lock",     title: "Bloquear tela", glyph: "󰌾", words: "bloquear lock tela swaylock",            cmd: ["swaylock"],                             confirm: false },
        { key: "suspend",  title: "Suspender",     glyph: "󰒲", words: "suspender suspend dormir sleep",          cmd: ["systemctl", "suspend"],                 confirm: false },
        { key: "logout",   title: "Sair da sessão", glyph: "󰍃", words: "sair logout log off encerrar sessão exit", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"], confirm: true },
        { key: "reboot",   title: "Reiniciar",     glyph: "󰜉", words: "reiniciar reboot restart",                cmd: ["systemctl", "reboot"],                  confirm: true },
        { key: "poweroff", title: "Desligar",      glyph: "󰐥", words: "desligar shutdown poweroff power off",    cmd: ["systemctl", "poweroff"],                confirm: true }
    ]

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

        if (q.startsWith("=")) {
            var r = calc(q.substring(1))
            out.push({ kind: "calc", title: r === null ? "Expressão inválida" : "= " + String(r).replace(".", ","),
                       subtitle: r === null ? "use números e + − × ÷ ^ ( )" : "Enter copia o resultado", glyph: "󰃬", value: r === null ? "" : String(r) })
            return out
        }

        var sysOnly = q.startsWith(">")
        var sq = sysOnly ? q.substring(1).trim() : q
        var sys = []
        for (var c of systemCommands) {
            var s = sq === "" ? (sysOnly ? 50 : -1) : Math.max(score(sq, c.title), score(sq, c.words) - 10)
            if (s >= (sysOnly ? 0 : 60)) sys.push({ kind: "sys", title: c.title, subtitle: c.confirm ? "pede confirmação" : "", glyph: c.glyph, cmd: c.cmd, confirm: c.confirm, key: c.key, score: s })
        }
        if (sysOnly) return sys

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
        if (q === "") return []   // sem nada digitado, só a barra (sem lista de mais usados)
        out = apps.slice(0, 40)
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

    // destaca o trecho digitado no nome, como as sugestões do navegador
    function esc(t) { return t.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    function highlight(title) {
        var q = query.trim().toLowerCase()
        if (q.startsWith(">")) q = q.substring(1).trim()
        var i = q && !q.startsWith("=") ? title.toLowerCase().indexOf(q) : -1
        if (i < 0) return esc(title)
        return esc(title.substring(0, i)) + "<b><font color='" + Theme.accent + "'>" + esc(title.substring(i, i + q.length)) + "</font></b>" + esc(title.substring(i + q.length))
    }
    function tagFor(item) { return item.kind === "app" ? "App" : item.kind === "sys" ? "Sistema" : "Calculadora" }

    readonly property string favicon: {
        if (!windowClass) return ""
        var entry = DesktopEntries.heuristicLookup(windowClass)
        return Quickshell.iconPath(entry && entry.icon ? entry.icon : windowClass, true)
    }

    // ── Janela ─────────────────────────────────────────────
    PanelWindow {
        id: win
        readonly property int barHeight: 46
        // continua mapeada enquanto a animação de saída roda
        property bool mapped: false
        visible: mapped
        Timer { id: unmapTimer; interval: 240; onTriggered: if (!launcher.open) win.mapped = false }
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-launcher"
        anchors { top: true; left: true; right: true }
        implicitHeight: barHeight + launcher.cornerRadius + dropFull
        color: "transparent"
        // só a faixa e a aba recebem clique; o resto da janela é transparente para as janelas de baixo
        mask: Region { item: strip; Region { item: dropClip } }

        // 0 = fechado (faixa com a grossura normal do contorno), 1 = aberto (faixa com a altura do
        // launcher, a mesma de antes); a faixa cresce em vez de algo deslizar por cima
        property real progress: launcher.open ? 1 : 0
        Behavior on progress { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        readonly property real stripH: launcher.frameWidth + (barHeight - launcher.frameWidth) * progress
        readonly property real dropFull: launcher.query.trim() === "" ? 0 : dropCol.implicitHeight + 14

        HyprlandFocusGrab {
            windows: [win]
            active: launcher.open
            onCleared: launcher.close()
        }
        Connections {
            target: launcher
            function onOpenChanged() {
                if (!launcher.open) { unmapTimer.restart(); return }
                win.mapped = true
                search.text = launcher.initialText
                search.cursorPosition = search.text.length
                search.forceActiveFocus()
            }
        }

        PopupWindow {
            id: clockTip
            visible: clockMouse.containsMouse && launcher.open && launcher.clockTooltip !== ""
            anchor.window: win
            anchor.rect.x: win.width - launcher.frameWidth - 8
            anchor.rect.y: win.barHeight + 6
            anchor.rect.width: 1
            anchor.rect.height: 1
            anchor.edges: Edges.Bottom | Edges.Right
            anchor.gravity: Edges.Bottom | Edges.Left
            implicitWidth: clockTipText.implicitWidth + 24
            implicitHeight: 30
            color: "transparent"
            Rectangle {
                anchors.fill: parent
                color: Theme.bg
                radius: 6
                border.color: Theme.surface1
                border.width: 1
                Text {
                    id: clockTipText
                    anchors.centerIn: parent
                    text: launcher.clockTooltip
                    color: Theme.fg
                    font.family: Theme.font; font.pixelSize: 12; font.bold: true
                }
            }
        }

        // canto côncavo (área das janelas "recortada" na faixa); mirrored = canto do lado direito
        component Concave: Shape {
            property real r: launcher.cornerRadius
            property bool mirrored: false
            width: r; height: r
            preferredRendererType: Shape.CurveRenderer
            transform: Scale { xScale: mirrored ? -1 : 1; origin.x: r / 2 }
            ShapePath {
                fillColor: Theme.bgHard
                strokeWidth: -1
                startX: 0; startY: 0
                PathLine { x: r; y: 0 }
                PathArc { x: 0; y: r; radiusX: r; radiusY: r; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: 0 }
            }
        }

        // ── Faixa de cima do contorno, crescida ─────────────
        Rectangle {
            id: strip
            x: launcher.leftInset
            width: win.width - launcher.leftInset
            height: win.stripH
            color: Theme.bgHard
            clip: true

            // conteúdo desce junto com a faixa
            Item {
                id: barContent
                width: parent.width
                height: win.barHeight
                y: win.stripH - win.barHeight
                opacity: win.progress

                RowLayout {
                    id: barRow
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: launcher.frameWidth + 6
                    spacing: 10

                    // campo de endereço
                    Rectangle {
                        id: omnibox
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: 16
                        color: Theme.surface0
                        border.color: search.activeFocus ? Theme.accent : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 4
                            spacing: 10
                            // "favicon": o app em foco sem busca; com busca, o tipo de busca
                            Item {
                                implicitWidth: 18; implicitHeight: 18
                                IconImage {
                                    id: fav
                                    anchors.fill: parent
                                    visible: launcher.query === "" && launcher.favicon !== "" && status === Image.Ready
                                    source: launcher.query === "" ? launcher.favicon : ""
                                    asynchronous: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !fav.visible
                                    text: launcher.query.startsWith("=") ? "󰃬" : launcher.query.startsWith(">") ? "󰐥" : "󰍉"
                                    color: Theme.sub
                                    font.family: Theme.font; font.pixelSize: 15
                                }
                            }
                            Item {
                                Layout.fillWidth: true
                                implicitHeight: search.implicitHeight
                                TextInput {
                                    id: search
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: Theme.fg
                                    selectionColor: Theme.accent
                                    selectedTextColor: Theme.onAccent
                                    font.family: Theme.font; font.pixelSize: 15
                                    clip: true
                                    focus: true
                                    onTextChanged: launcher.query = text
                                    Keys.onPressed: event => {
                                        var ctrl = event.modifiers & Qt.ControlModifier
                                        var cur = launcher.results[launcher.selected]
                                        if (event.key === Qt.Key_Escape) { launcher.close(); event.accepted = true }
                                        else if ((ctrl && event.key === Qt.Key_N) || event.key === Qt.Key_Down) { launcher.move(1); event.accepted = true }
                                        else if ((ctrl && event.key === Qt.Key_P) || event.key === Qt.Key_Up) { launcher.move(-1); event.accepted = true }
                                        else if (event.key === Qt.Key_Tab) {
                                            // completa com o nome da sugestão selecionada
                                            if (cur && cur.kind === "app") { search.text = cur.title; search.cursorPosition = search.text.length }
                                            event.accepted = true
                                        }
                                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { launcher.activate(cur); event.accepted = true }
                                    }
                                }
                                // placeholder: o título da janela em foco, como a URL da página aberta
                                Text {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: search.text === ""
                                    text: launcher.windowTitle !== "" ? launcher.windowTitle : "Pesquisar apps  ·  = calcular  ·  > sistema"
                                    color: Theme.sub
                                    elide: Text.ElideRight
                                    font.family: Theme.font; font.pixelSize: 15
                                }
                            }
                            // data e hora dentro da barra de busca, no canto direito (fundo só no hover)
                            Rectangle {
                                id: clockBox
                                implicitWidth: clockLabel.implicitWidth + 18
                                implicitHeight: 24
                                radius: 12
                                color: clockMouse.containsMouse ? Theme.surface1 : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text {
                                    id: clockLabel
                                    anchors.centerIn: parent
                                    text: launcher.clockText
                                    color: Theme.fg
                                    font.family: Theme.font; font.pixelSize: 14; font.bold: true
                                }
                                MouseArea {
                                    id: clockMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { launcher.close(); launcher.calendarRequested() }
                                }
                            }
                        }
                    }
                }
            }
        }
        // cantos da área das janelas, descendo com a faixa e com as sugestões
        Concave { x: launcher.leftInset; y: win.stripH + dropClip.height }
        Concave { x: win.width - launcher.frameWidth - r; y: win.stripH + dropClip.height; mirrored: true }

        // ── Sugestões: a faixa continua descendo na largura toda, da barra lateral ao contorno ──
        readonly property real dropX: launcher.leftInset
        readonly property real dropW: win.width - launcher.leftInset - launcher.frameWidth
        Item {
            id: dropClip
            x: win.dropX
            y: win.stripH
            width: win.dropW
            height: win.dropFull * win.progress
            clip: true
            Rectangle {
                id: drop
                anchors.bottom: parent.bottom
                width: parent.width
                height: win.dropFull
                color: Theme.bgHard

                ColumnLayout {
                    id: dropCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    spacing: 0

                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(contentHeight, launcher.maxRows * launcher.rowHeight)
                        visible: count > 0
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
                            readonly property bool needsConfirm: modelData.kind === "sys" && launcher.confirmKey === modelData.key
                            width: list.width
                            height: launcher.rowHeight
                            radius: 6
                            color: isSel ? (needsConfirm ? Qt.alpha(Theme.red, 0.2) : Theme.surface0) : rowMouse.containsMouse ? Theme.tile : "transparent"

                            // barra de seleção à esquerda
                            Rectangle {
                                visible: row.isSel
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3; height: parent.height - 14; radius: 2
                                color: row.needsConfirm ? Theme.red : Theme.accent
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 12
                                spacing: 12
                                Item {
                                    implicitWidth: 24; implicitHeight: 24
                                    IconImage {
                                        id: appIcon
                                        anchors.fill: parent
                                        visible: row.modelData.kind === "app" && status === Image.Ready
                                        source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.entry.icon, true) : ""
                                        asynchronous: true
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !appIcon.visible
                                        text: row.modelData.kind === "app" ? "󰣆" : row.modelData.glyph
                                        color: row.modelData.kind === "sys" && row.modelData.confirm ? Theme.yellow : Theme.accent
                                        font.family: Theme.font; font.pixelSize: 18
                                    }
                                }
                                // nome — descrição (como "termo — Pesquisar com…")
                                Text {
                                    Layout.fillWidth: true
                                    textFormat: Text.StyledText
                                    text: launcher.highlight(row.modelData.title)
                                          + (row.needsConfirm ? "<font color='" + Theme.red + "'>  —  Enter de novo para confirmar</font>"
                                             : row.modelData.subtitle ? "<font color='" + Theme.sub + "'>  —  " + launcher.esc(row.modelData.subtitle) + "</font>" : "")
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                    font.family: Theme.font; font.pixelSize: 14
                                }
                                Rectangle {
                                    implicitWidth: tag.implicitWidth + 14; implicitHeight: 20; radius: 4
                                    color: row.isSel ? Theme.surface1 : Theme.surface0
                                    Text {
                                        id: tag
                                        anchors.centerIn: parent
                                        text: launcher.tagFor(row.modelData)
                                        color: Theme.sub
                                        font.family: Theme.font; font.pixelSize: 10
                                    }
                                }
                                Text {
                                    visible: row.isSel
                                    text: "󰌑"
                                    color: Theme.sub
                                    font.family: Theme.font; font.pixelSize: 15
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
                        text: "Nenhuma sugestão para “" + launcher.query + "”"
                        color: Theme.sub
                        font.family: Theme.font; font.pixelSize: 13
                        Layout.leftMargin: 10; Layout.topMargin: 6; Layout.bottomMargin: 6
                    }
                }
            }
        }
    }
}
