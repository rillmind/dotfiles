// quickshell-apps – menu de apps em tela cheia, igual à grade do GNOME (com Blur my Shell): papel de
// parede desfocado, busca no topo, páginas de ícones e dock embaixo. Sem prévias de workspaces.
// Instância própria, separada dos temas,
// mas segue as cores da paleta ativa.
//
//   apps.sh iniciar   sobe a instância (autostart do Hyprland); apps.sh toggle  abre/fecha (Super+A)
//
// Teclado: digitar filtra, setas andam, PageUp/PageDown trocam de página, Enter abre, Esc fecha.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    property bool aberto: false
    property string busca: ""
    property int sel: 0
    property bool mostrarSel: false   // o realce só aparece depois de usar o teclado
    readonly property string fonte: "Adwaita Sans"

    // ── Papel de parede do tema ativo (gravado pelo aparencia.sh) ────────────────────────
    readonly property string estado: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"
    property string wallpaper: ""
    FileView {
        path: root.estado + "/aparencia/wallpaper-atual"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.wallpaper = text().trim()
    }

    // ── Paleta ativa (idem): tinge o véu, a busca, a dock, o realce e os pontinhos ───────
    property string paleta: "gruvbox-escuro"
    FileView {
        path: root.estado + "/aparencia/paleta"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.paleta = text().trim()
    }
    readonly property var paletas: ({
        "gruvbox-escuro":   { fundo: "#1d2021", sup: "#3c3836", texto: "#ebdbb2", sub: "#a89984", destaque: "#fe8019", veu: 0.55 },
        "gruvbox-claro":    { fundo: "#fbf1c7", sup: "#ebdbb2", texto: "#3c3836", sub: "#665c54", destaque: "#af3a03", veu: 0.72 },
        "catppuccin-mocha": { fundo: "#1e1e2e", sup: "#313244", texto: "#cdd6f4", sub: "#a6adc8", destaque: "#cba6f7", veu: 0.55 }
    })
    readonly property var c: paletas[paleta] || paletas["gruvbox-escuro"]

    // ── Apps ─────────────────────────────────────────────────────────────────────────────
    // todos os .desktop, menos os NoDisplay (que nem o GNOME mostra), em ordem alfabética
    readonly property var todos: [...DesktopEntries.applications.values].filter(e => !e.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))
    function pontos(q, e) {
        var n = e.name.toLowerCase()
        if (n.startsWith(q)) return 4
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 3
        if (n.includes(q)) return 2
        return [e.genericName, e.id, (e.keywords || []).join(" "), e.comment].join(" ").toLowerCase().includes(q) ? 1 : 0
    }
    readonly property var lista: {
        var q = busca.trim().toLowerCase()
        if (q === "") return todos
        return todos.map(e => ({ e: e, p: pontos(q, e) })).filter(x => x.p > 0)
            .sort((a, b) => b.p - a.p).map(x => x.e)
    }

    // ── Dock: os 6 mais usados (contados pelo launcher) + os abertos ─────────────────────
    property var uso: ({})
    FileView {
        path: root.estado + "/launcher-usage.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.uso = JSON.parse(text()) } catch (e) { root.uso = {} } }
    }
    readonly property var fixos: todos.filter(e => (uso[e.id] || 0) > 0)
        .sort((a, b) => uso[b.id] - uso[a.id]).slice(0, 6)
    readonly property var janelas: {
        var m = {}
        for (var t of ToplevelManager.toplevels.values) {
            var e = DesktopEntries.heuristicLookup(t.appId)
            if (e && !m[e.id]) m[e.id] = { e: e, t: t }
        }
        return m
    }
    readonly property var abertosExtras: Object.values(janelas).map(x => x.e).filter(e => !fixos.some(f => f.id === e.id))
    readonly property var dock: [...fixos, ...(fixos.length && abertosExtras.length ? [null] : []), ...abertosExtras]

    function abrir() {
        var m = Hyprland.focusedMonitor
        var tela = Quickshell.screens.find(s => m && s.name === m.name)
        if (tela) janela.screen = tela
        campo.text = ""
        sel = 0
        mostrarSel = false
        paginas.irPara(0, true)
        aberto = true
        campo.forceActiveFocus()
    }
    function fechar() { aberto = false }
    function lancar(e) { if (e) { e.execute(); fechar() } }
    function daDock(e) {
        var j = janelas[e.id]
        if (j) { fechar(); j.t.activate() } else lancar(e)
    }
    function mover(d) {
        if (!lista.length) return
        // a primeira seta só mostra o realce no primeiro app
        if (mostrarSel) sel = Math.max(0, Math.min(lista.length - 1, sel + d))
        mostrarSel = true
        paginas.irPara(Math.floor(sel / paginas.porPagina), false)
    }

    IpcHandler {
        target: "apps"
        function toggle(): void { root.aberto ? root.fechar() : root.abrir() }
        function abrir(): void { root.abrir() }
        function fechar(): void { root.fechar() }
        function buscar(texto: string): void { if (!root.aberto) root.abrir(); campo.text = texto }
        function pagina(n: int): void { paginas.irPara(n, false) }
    }

    // Ícone do app. Carga síncrona (thread principal): a assíncrona de ícones do tema já derrubou o
    // quickshell (ver tema.sh). Sem ícone: quadrado com a inicial.
    component Icone: Item {
        id: ic
        required property var app
        readonly property string caminho: app && app.icon ? Quickshell.iconPath(app.icon, true) : ""
        Image {
            anchors.fill: parent
            sourceSize: Qt.size(128, 128)
            fillMode: Image.PreserveAspectFit
            asynchronous: false
            smooth: true; mipmap: true
            source: ic.caminho
        }
        Rectangle {
            anchors.fill: parent
            visible: ic.caminho === ""
            radius: width / 5
            color: root.c.sup
            Text {
                anchors.centerIn: parent
                text: ic.app ? ic.app.name.charAt(0).toUpperCase() : ""
                font { family: root.fonte; pixelSize: ic.width * 0.5; bold: true }
                color: root.c.destaque
            }
        }
    }

    // Uma página: 8x4 apps a partir de `inicio` na lista recebida.
    component Pagina: Item {
        id: pag
        required property int inicio
        required property var apps
        width: paginas.width
        height: paginas.height
        MouseArea { anchors.fill: parent; onClicked: root.fechar() }
        Grid {
            columns: paginas.colunas
            x: (pag.width - paginas.colunas * paginas.celW) / 2
            Repeater {
                model: pag.apps.slice(pag.inicio, pag.inicio + paginas.porPagina)
                Item {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool atual: root.mostrarSel && root.sel === pag.inicio + index
                    width: paginas.celW
                    height: paginas.celH
                    Rectangle {
                        anchors.centerIn: parent
                        width: 150 * janela.u
                        height: 156 * janela.u
                        radius: 16 * janela.u
                        color: root.c.destaque
                        opacity: mouse.pressed ? 0.35 : item.atual ? 0.28 : mouse.containsMouse ? 0.18 : 0
                    }
                    Icone {
                        id: icone
                        app: item.modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 36 * janela.u
                        width: 92 * janela.u
                        height: width
                    }
                    Text {
                        anchors { top: icone.bottom; topMargin: 10 * janela.u; horizontalCenter: parent.horizontalCenter }
                        width: 136 * janela.u
                        horizontalAlignment: Text.AlignHCenter
                        text: item.modelData.name
                        font { family: root.fonte; pixelSize: 14.5 * janela.u }
                        color: root.c.texto
                        elide: Text.ElideRight
                    }
                    Rectangle {   // pontinho: app aberto
                        visible: root.janelas[item.modelData.id] !== undefined
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 166 * janela.u
                        width: 5 * janela.u; height: width; radius: width / 2
                        color: root.c.destaque
                    }
                    MouseArea {
                        id: mouse
                        anchors.centerIn: parent
                        width: 150 * janela.u
                        height: 156 * janela.u
                        hoverEnabled: true
                        onClicked: root.lancar(item.modelData)
                    }
                }
            }
        }
    }

    PanelWindow {
        id: janela
        visible: root.aberto || fundo.opacity > 0
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-apps"
        WlrLayershell.keyboardFocus: root.aberto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        readonly property real u: Math.min(width / 1920, height / 1080)   // medidas para 1920x1080

        Item {
            id: fundo
            anchors.fill: parent
            opacity: root.aberto ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Rectangle { anchors.fill: parent; color: root.c.fundo }
            // papel de parede reduzido e desfocado
            Image {
                id: papel
                anchors.fill: parent
                sourceSize.width: 480
                fillMode: Image.PreserveAspectCrop
                source: root.wallpaper ? "file://" + root.wallpaper.split("/").map(encodeURIComponent).join("/") : ""
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: papel
                autoPaddingEnabled: false
                blurEnabled: true
                blur: 1
                blurMax: 64
                blurMultiplier: 1.5
            }
            Rectangle { anchors.fill: parent; color: root.c.fundo; opacity: root.c.veu }
            MouseArea { anchors.fill: parent; onClicked: root.fechar() }
            // troca de página: dois dedos para os lados (ou para cima/baixo) e roda do mouse
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                orientation: Qt.Horizontal
                onWheel: event => gesto.rolar(event)
            }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                orientation: Qt.Vertical
                onWheel: event => gesto.rolar(event)
            }
            // um gesto = uma página: soma o movimento até o limiar e só libera depois de uma pausa
            Timer {
                id: gesto
                property real soma: 0
                property bool trocou: false
                interval: 150
                onTriggered: { soma = 0; trocou = false }
                function rolar(event) {
                    var x = event.angleDelta.x, y = event.angleDelta.y
                    restart()
                    if (trocou) return
                    soma += Math.abs(x) > Math.abs(y) ? x : y
                    if (Math.abs(soma) < 60) return
                    trocou = true
                    paginas.irPara(paginas.currentIndex + (soma < 0 ? 1 : -1), false)
                }
            }
        }

        Item {
            id: conteudo
            anchors.fill: parent
            opacity: fundo.opacity
            scale: 0.95 + 0.05 * fundo.opacity

            // ── Busca ──────────────────────────────────────────────────────────────────
            Rectangle {
                id: caixa
                anchors.horizontalCenter: parent.horizontalCenter
                y: 41 * janela.u
                width: 320 * janela.u
                height: 34 * janela.u
                radius: height / 2
                color: Qt.alpha(root.c.sup, 0.9)
                border.width: campo.text !== "" ? 2 : 1
                border.color: campo.text !== "" ? root.c.destaque : Qt.alpha(root.c.texto, 0.12)
                MouseArea { anchors.fill: parent; onClicked: campo.forceActiveFocus() }

                Text {
                    id: lupa
                    x: 14 * janela.u
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 * janela.u }
                    color: root.c.destaque
                }
                TextInput {
                    id: campo
                    anchors { left: lupa.right; leftMargin: 12 * janela.u; right: parent.right; rightMargin: 14 * janela.u; verticalCenter: parent.verticalCenter }
                    font { family: root.fonte; pixelSize: 15 * janela.u }
                    color: root.c.texto
                    clip: true
                    focus: true
                    cursorVisible: text !== ""
                    onTextChanged: {
                        root.busca = text
                        root.sel = 0
                        root.mostrarSel = text !== ""
                        paginas.irPara(0, true)
                    }
                    Text {
                        visible: campo.text === ""
                        text: "Digite para pesquisar"
                        font: campo.font
                        color: root.c.sub
                    }
                    Keys.onPressed: event => {
                        var k = event.key, c = paginas.colunas
                        if (k === Qt.Key_Escape) { if (text !== "") text = ""; else root.fechar() }
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) { if (root.mostrarSel) root.lancar(root.lista[root.sel]) }
                        else if (k === Qt.Key_Right || k === Qt.Key_Tab) root.mover(1)
                        else if (k === Qt.Key_Left || k === Qt.Key_Backtab) root.mover(-1)
                        else if (k === Qt.Key_Down) root.mover(c)
                        else if (k === Qt.Key_Up) root.mover(-c)
                        else if (k === Qt.Key_PageDown || k === Qt.Key_PageUp) {
                            paginas.irPara(paginas.currentIndex + (k === Qt.Key_PageDown ? 1 : -1), false)
                            root.sel = paginas.currentIndex * paginas.porPagina
                        }
                        else return
                        event.accepted = true
                    }
                }
            }

            // ── Páginas ────────────────────────────────────────────────────────────────
            Item {
                id: paginas
                readonly property int colunas: 8
                readonly property int linhas: 4
                readonly property int porPagina: colunas * linhas
                readonly property real celW: 190 * janela.u
                readonly property real celH: 200 * janela.u
                readonly property int count: Math.ceil(root.lista.length / porPagina)
                property int currentIndex: 0
                property bool animar: true
                function irPara(n, jaJa) {
                    animar = !jaJa
                    currentIndex = Math.max(0, Math.min(count - 1, n))
                }
                anchors { left: parent.left; right: parent.right }
                y: 105 * janela.u
                height: linhas * celH

                // a lista completa fica sempre montada (escondida na busca): os ícones carregam no
                // login, e abrir o menu não espera por eles
                Row {
                    visible: root.busca.trim() === ""
                    x: -paginas.currentIndex * paginas.width
                    Behavior on x { enabled: root.aberto && paginas.animar; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Repeater {
                        model: Math.ceil(root.todos.length / paginas.porPagina)
                        Pagina { required property int index; inicio: index * paginas.porPagina; apps: root.todos }
                    }
                }
                // resultados da busca: só a página atual
                Loader {
                    active: root.busca.trim() !== ""
                    sourceComponent: Pagina { inicio: paginas.currentIndex * paginas.porPagina; apps: root.lista }
                }
            }

            Text {
                anchors.centerIn: paginas
                visible: root.lista.length === 0
                text: "Nenhum resultado"
                font { family: root.fonte; pixelSize: 22 * janela.u }
                color: root.c.sub
            }

            Row {   // indicador de páginas
                anchors { horizontalCenter: parent.horizontalCenter; bottom: barra.top; bottomMargin: 12 * janela.u }
                visible: paginas.count > 1
                Repeater {
                    model: paginas.count
                    Item {
                        required property int index
                        width: 26 * janela.u; height: 22 * janela.u
                        Rectangle {
                            anchors.centerIn: parent
                            width: 9 * janela.u; height: width; radius: width / 2
                            color: root.c.destaque
                            opacity: parent.index === paginas.currentIndex ? 1 : 0.35
                        }
                        MouseArea { anchors.fill: parent; onClicked: paginas.irPara(parent.index, false) }
                    }
                }
            }

            // ── Dock ───────────────────────────────────────────────────────────────────
            Rectangle {
                id: barra
                visible: root.dock.length > 0
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 15 * janela.u }
                width: itens.width + 20 * janela.u
                height: 90 * janela.u
                radius: 22 * janela.u
                color: Qt.alpha(root.c.sup, 0.6)
                MouseArea { anchors.fill: parent }   // clique entre os ícones não fecha
                Row {
                    id: itens
                    anchors.centerIn: parent
                    Repeater {
                        model: root.dock
                        Item {
                            id: d
                            required property var modelData
                            width: (modelData ? 77 : 17) * janela.u
                            height: 76 * janela.u
                            Rectangle {
                                visible: !d.modelData
                                anchors.centerIn: parent
                                width: 1; height: 56 * janela.u
                                color: Qt.alpha(root.c.texto, 0.25)
                            }
                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 2
                                radius: 14 * janela.u
                                color: root.c.destaque
                                opacity: dm.containsMouse ? 0.14 : 0
                            }
                            Icone {
                                visible: !!d.modelData
                                app: d.modelData
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -3 * janela.u
                                width: 54 * janela.u
                                height: width
                            }
                            Rectangle {
                                visible: !!d.modelData && root.janelas[d.modelData.id] !== undefined
                                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 3 * janela.u }
                                width: 5 * janela.u; height: width; radius: width / 2
                                color: root.c.destaque
                            }
                            MouseArea {
                                id: dm
                                anchors.fill: parent
                                enabled: !!d.modelData
                                hoverEnabled: true
                                onClicked: root.daDock(d.modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}
