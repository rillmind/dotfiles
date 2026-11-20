// quickshell-apps – menu de apps em tela cheia (estilo GNOME) com fundo desfocado. Instância própria,
// separada dos temas: funciona em qualquer tema e segue a paleta ativa (aparencia.sh).
//
//   apps.sh iniciar   sobe a instância (exec-once do Hyprland); apps.sh toggle  abre/fecha (Super+A)
//
// Só apps: sem workspaces nem janelas. O desfoque vem da layer rule "quickshell-apps" no hyprland.lua.
// Teclado: digitar filtra, setas andam na grade, Enter abre, Esc fecha.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

ShellRoot {
    id: root

    property bool aberto: false
    property string busca: ""

    // ── Tema (o mesmo arquivo que o aparencia.sh grava a cada troca) ──────────────────────
    property string paleta: "gruvbox-escuro"
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/aparencia/paleta"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.paleta = text().trim()
    }
    readonly property var paletas: ({
        "gruvbox-escuro":   { fundo: "#1d2021", sup: "#3c3836", texto: "#ebdbb2", sub: "#a89984", destaque: "#fe8019" },
        "gruvbox-claro":    { fundo: "#fbf1c7", sup: "#ebdbb2", texto: "#3c3836", sub: "#7c6f64", destaque: "#af3a03" },
        "catppuccin-mocha": { fundo: "#1e1e2e", sup: "#313244", texto: "#cdd6f4", sub: "#a6adc8", destaque: "#cba6f7" }
    })
    readonly property var c: paletas[paleta] || paletas["gruvbox-escuro"]
    readonly property string fonte: "JetBrainsMono Nerd Font"

    // ── Apps ─────────────────────────────────────────────────────────────────────────────
    // todos os .desktop instalados (sistema, ~/.local e flatpak), menos os NoDisplay (ajudantes
    // que nem o GNOME mostra); em ordem alfabética
    readonly property var todos: {
        var l = []
        for (var e of DesktopEntries.applications.values) if (!e.noDisplay) l.push(e)
        l.sort((a, b) => a.name.localeCompare(b.name))
        return l
    }
    function pontos(q, e) {
        var n = e.name.toLowerCase()
        if (n.startsWith(q)) return 4
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 3
        if (n.includes(q)) return 2
        var extra = [e.genericName, e.id, (e.keywords || []).join(" "), e.comment].join(" ").toLowerCase()
        return extra.includes(q) ? 1 : 0
    }
    readonly property var lista: {
        var q = busca.trim().toLowerCase()
        if (q === "") return todos
        var r = []
        for (var e of todos) { var p = pontos(q, e); if (p > 0) r.push({ e: e, p: p }) }
        r.sort((a, b) => b.p - a.p)   // sort estável: empate continua alfabético
        return r.map(x => x.e)
    }

    function abrir() {
        var m = Hyprland.focusedMonitor
        var tela = Quickshell.screens.find(s => m && s.name === m.name)
        if (tela) janela.screen = tela
        busca = ""
        aberto = true
    }
    function fechar() { aberto = false }
    function lancar(e) {
        if (!e) return
        e.execute()
        fechar()
    }

    IpcHandler {
        target: "apps"
        function toggle(): void { root.aberto ? root.fechar() : root.abrir() }
        function abrir(): void { root.abrir() }
        function fechar(): void { root.fechar() }
    }

    PanelWindow {
        id: janela
        visible: root.aberto || saida.running
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-apps"
        WlrLayershell.keyboardFocus: root.aberto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // véu escuro/claro por cima do desfoque; clicar fora dos ícones fecha
        Rectangle {
            id: veu
            anchors.fill: parent
            color: Qt.alpha(root.c.fundo, 0.6)
            opacity: root.aberto ? 1 : 0
            Behavior on opacity { NumberAnimation { id: saida; duration: 160; easing.type: Easing.OutCubic } }
            MouseArea { anchors.fill: parent; onClicked: root.fechar() }
        }

        Item {
            id: conteudo
            anchors.fill: parent
            opacity: veu.opacity
            scale: 0.96 + 0.04 * veu.opacity

            // ── Busca ──────────────────────────────────────────────────────────────────
            Rectangle {
                id: caixa
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round(parent.height * 0.08)
                width: Math.min(520, parent.width - 64)
                height: 46
                radius: height / 2
                color: Qt.alpha(root.c.sup, 0.85)
                border.width: campo.text !== "" ? 2 : 0
                border.color: root.c.destaque
                MouseArea { anchors.fill: parent; onClicked: campo.forceActiveFocus() }   // não fecha

                Text {
                    id: lupa
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font.family: root.fonte
                    font.pixelSize: 16
                    color: root.c.sub
                }
                Text {
                    anchors.left: lupa.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    visible: campo.text === ""
                    text: "Buscar apps"
                    font.family: root.fonte
                    font.pixelSize: 15
                    color: root.c.sub
                }
                TextInput {
                    id: campo
                    anchors.left: lupa.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: root.fonte
                    font.pixelSize: 15
                    color: root.c.texto
                    selectionColor: root.c.destaque
                    clip: true
                    focus: true
                    onTextChanged: { root.busca = text; grade.currentIndex = 0; grade.positionViewAtBeginning() }

                    Keys.onPressed: event => {
                        var k = event.key
                        if (k === Qt.Key_Escape) { if (text !== "") text = ""; else root.fechar() }
                        else if (k === Qt.Key_Return || k === Qt.Key_Enter) root.lancar(root.lista[grade.currentIndex])
                        else if (k === Qt.Key_Right) grade.moveCurrentIndexRight()
                        else if (k === Qt.Key_Left) grade.moveCurrentIndexLeft()
                        else if (k === Qt.Key_Down || k === Qt.Key_Tab) grade.moveCurrentIndexDown()
                        else if (k === Qt.Key_Up || k === Qt.Key_Backtab) grade.moveCurrentIndexUp()
                        else if (k === Qt.Key_PageDown) grade.currentIndex = Math.min(grade.count - 1, grade.currentIndex + grade.colunas * grade.linhas)
                        else if (k === Qt.Key_PageUp) grade.currentIndex = Math.max(0, grade.currentIndex - grade.colunas * grade.linhas)
                        else return
                        event.accepted = true
                    }
                }
            }

            // ── Grade de apps ──────────────────────────────────────────────────────────
            GridView {
                id: grade
                readonly property int celula: 148
                readonly property int colunas: Math.max(1, Math.min(8, Math.floor((parent.width - 160) / celula)))
                readonly property int linhas: Math.max(1, Math.floor(height / celula))
                anchors.top: caixa.bottom
                anchors.topMargin: 40
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 40
                anchors.horizontalCenter: parent.horizontalCenter
                width: colunas * celula
                cellWidth: celula
                cellHeight: celula
                clip: true
                model: root.lista
                keyNavigationWraps: false
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds
                // rolagem só com a roda/touchpad; arrastar não move a grade (clique abre o app)
                interactive: false
                WheelHandler {
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.pixelDelta.y
                        grade.contentY = Math.max(0, Math.min(grade.contentHeight - grade.height, grade.contentY - d))
                    }
                }

                delegate: Item {
                    id: item
                    required property var modelData
                    required property int index
                    readonly property bool atual: GridView.isCurrentItem && root.busca !== ""
                    width: grade.celula
                    height: grade.celula

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 18
                        color: mouse.containsMouse ? Qt.alpha(root.c.texto, 0.12)
                             : item.atual ? Qt.alpha(root.c.destaque, 0.22) : "transparent"
                        border.width: item.atual ? 2 : 0
                        border.color: root.c.destaque
                    }
                    // carga síncrona dos ícones (na thread principal): o carregamento assíncrono
                    // do Qt de ícones do tema já derrubou o quickshell (ver tema.sh)
                    readonly property string caminho: item.modelData.icon ? Quickshell.iconPath(item.modelData.icon, true) : ""
                    Image {
                        id: icone
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 22
                        width: 64; height: 64
                        sourceSize: Qt.size(128, 128)
                        asynchronous: false
                        smooth: true; mipmap: true
                        visible: item.caminho !== ""
                        source: item.caminho
                    }
                    // sem ícone (Icon= vazio ou fora do tema): quadrado com a inicial do app
                    Rectangle {
                        anchors.fill: icone
                        visible: item.caminho === ""
                        radius: 16
                        color: root.c.sup
                        border.width: 2
                        border.color: Qt.alpha(root.c.destaque, 0.6)
                        Text {
                            anchors.centerIn: parent
                            text: item.modelData.name.charAt(0).toUpperCase()
                            font.family: root.fonte
                            font.pixelSize: 30
                            font.bold: true
                            color: root.c.destaque
                        }
                    }
                    Text {
                        anchors.top: icone.bottom
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 20
                        horizontalAlignment: Text.AlignHCenter
                        text: item.modelData.name
                        font.family: root.fonte
                        font.pixelSize: 13
                        color: root.c.texto
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        anchors.margins: 6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lancar(item.modelData)
                    }
                }
            }

            Text {
                anchors.centerIn: grade
                visible: grade.count === 0
                text: "Nenhum app encontrado"
                font.family: root.fonte
                font.pixelSize: 16
                color: root.c.sub
            }
        }

        Connections {
            target: root
            function onAbertoChanged() { if (root.aberto) { campo.text = ""; campo.forceActiveFocus(); grade.currentIndex = 0; grade.positionViewAtBeginning() } }
        }
    }
}
