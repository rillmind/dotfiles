// Tela de bloqueio (instância própria do quickshell, separada da barra; abra com bloquear.sh).
// Relógio no centro, data pequena embaixo e, ao digitar, um anel no estilo do swaylock: um arco acende
// num ponto aleatório a cada tecla (vermelho ao apagar), verde verificando, vermelho errou, amarelo
// limpou ou Caps Lock. Cores e papel de parede seguem o tema ativo (~/.local/state/quickshell/aparencia).
// Teste sem bloquear de verdade: BLOQUEIO_TESTE=1 quickshell -p <esta pasta>  (fecha sozinho em 15 s).
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root
    readonly property bool teste: Quickshell.env("BLOQUEIO_TESTE") === "1" || demo
    readonly property bool demo: Quickshell.env("BLOQUEIO_TESTE") === "demo"   // teste que digita sozinho
    readonly property string estadoDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/aparencia"
    readonly property string marca: Quickshell.env("XDG_RUNTIME_DIR") + "/quickshell-bloqueio.ativo"

    // ── Tema ───────────────────────────────────────────────
    property string paleta: "gruvbox-escuro"
    property string wallpaper: ""
    FileView { path: root.estadoDir + "/paleta"; blockLoading: true; printErrors: false; onLoaded: root.paleta = text().trim() }
    FileView { path: root.estadoDir + "/wallpaper-atual"; blockLoading: true; printErrors: false; onLoaded: root.wallpaper = text().trim() }
    readonly property var paletas: ({
        "gruvbox-escuro":   { fundo: "#1d2021", texto: "#ebdbb2", sub: "#a89984", anel: "#3c3836", tecla: "#fe8019", apagar: "#fb4934", ver: "#b8bb26", errado: "#fb4934", limpo: "#fabd2f" },
        "gruvbox-claro":    { fundo: "#fbf1c7", texto: "#3c3836", sub: "#7c6f64", anel: "#ebdbb2", tecla: "#af3a03", apagar: "#9d0006", ver: "#79740e", errado: "#9d0006", limpo: "#b57614" },
        "catppuccin-mocha": { fundo: "#1e1e2e", texto: "#cdd6f4", sub: "#a6adc8", anel: "#313244", tecla: "#cba6f7", apagar: "#f38ba8", ver: "#a6e3a1", errado: "#f38ba8", limpo: "#fab387" }
    })
    readonly property var c: paletas[paleta] || paletas["gruvbox-escuro"]
    readonly property string fonte: "JetBrainsMono Nerd Font"

    // ── Estado (compartilhado entre os monitores) ──────────
    property string senha: ""
    property string estado: "ocioso"        // ocioso | digitando | verificando | errado | limpo
    property int falhas: 0
    property bool caps: false
    property string mensagem: ""
    property real hlAngulo: 0
    property bool hlApagar: false
    property bool hlVisivel: false

    readonly property bool anelVisivel: senha.length > 0 || estado === "verificando" || estado === "errado" || estado === "limpo"
    readonly property color corAnel: estado === "verificando" ? c.ver
                                   : estado === "errado" ? c.errado
                                   : estado === "limpo" || caps ? c.limpo
                                   : c.anel

    property date agora: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.agora = new Date() }
    readonly property string hora: Qt.formatTime(agora, "hh:mm")
    readonly property string data: {
        var dias = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]
        var meses = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
        return dias[agora.getDay()] + ", " + agora.getDate() + " de " + meses[agora.getMonth()]
    }

    // volta para "digitando"/"ocioso" depois de mostrar errado/limpo
    Timer { id: estadoTimer; interval: 1500; onTriggered: if (root.estado !== "verificando") root.estado = root.senha.length ? "digitando" : "ocioso" }
    Timer { id: hlTimer; interval: 1500; onTriggered: root.hlVisivel = false }
    function mostrar(e) { estado = e; estadoTimer.restart() }
    function destacar(apagar) { hlAngulo = Math.random() * 360; hlApagar = apagar; hlVisivel = true; hlTimer.restart() }

    // Caps Lock: lido do LED do teclado a cada tecla
    Process {
        id: capsProc
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -rn | head -1"]
        stdout: StdioCollector { onStreamFinished: root.caps = text.trim() !== "" && text.trim() !== "0" }
    }
    Timer { id: capsTimer; interval: 120; onTriggered: if (!capsProc.running) capsProc.running = true }
    Component.onCompleted: capsProc.running = true

    function tecla(event) {
        event.accepted = true
        var k = event.key
        var mods = event.modifiers
        if (k === Qt.Key_CapsLock) { capsTimer.restart(); return }
        if (estado === "verificando") return
        if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            enviar()
        } else if (k === Qt.Key_Escape || ((mods & Qt.ControlModifier) && k === Qt.Key_U)) {
            if (senha.length) { senha = ""; mostrar("limpo") }
        } else if (k === Qt.Key_Backspace) {
            if (senha.length) {
                senha = (mods & Qt.ControlModifier) ? "" : senha.slice(0, -1)
                destacar(true)
                if (!senha.length) mostrar("limpo")
            }
        } else if (event.text.length && event.text.charCodeAt(0) >= 32
                   && !(mods & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            senha += event.text
            mensagem = ""
            estado = "digitando"
            destacar(false)
        }
        capsTimer.restart()
    }

    function enviar() {
        if (!senha.length) return
        estado = "verificando"
        if (teste) { testeTimer.restart(); return }
        if (!pam.start()) falhou("Não consegui falar com o PAM")
    }
    function falhou(msg) {
        senha = ""
        falhas++
        if (msg) mensagem = msg
        mostrar("errado")
    }
    function desbloquear() {
        estado = "ocioso"
        lock.locked = false
        Qt.callLater(Qt.quit)
    }
    Timer { id: testeTimer; interval: 900; onTriggered: root.falhou("") }   // no teste, toda senha "erra"

    PamContext {
        id: pam
        config: "swaylock"          // /etc/pam.d/swaylock (inclui o login)
        onPamMessage: {
            if (responseRequired) respond(root.senha)
            else if (messageIsError) root.mensagem = message
        }
        onCompleted: result => {
            if (result === PamResult.Success) root.desbloquear()
            else root.falhou(result === PamResult.MaxTries ? "Tentativas demais" : "")
        }
        onError: root.falhou("Erro no PAM")
    }

    // ── Bloqueio de verdade ────────────────────────────────
    WlSessionLock {
        id: lock
        locked: !root.teste
        onSecureChanged: if (secure) marcaProc.running = true    // avisa o bloquear.sh que a tela já travou
        WlSessionLockSurface {
            color: root.c.fundo
            Tela { anchors.fill: parent }
        }
    }
    Process { id: marcaProc; command: ["touch", root.marca] }

    // ── Modo de teste: janela por cima de tudo, sem travar ─
    Variants {
        model: root.teste ? Quickshell.screens : []
        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: root.c.fundo
            Tela { anchors.fill: parent }
        }
    }
    Timer { running: root.teste; interval: 15000; onTriggered: Qt.quit() }
    // demo: digita 3 letras em 2 s e manda Enter em 5 s (a senha "erra")
    Timer { running: root.demo; interval: 2000; onTriggered: { for (var ch of "abc") root.tecla({ key: 0, text: ch, modifiers: 0, accepted: false }) } }
    Timer { running: root.demo; interval: 5000; onTriggered: root.tecla({ key: Qt.Key_Return, text: "", modifiers: 0, accepted: false }) }

    // ── Desenho de uma tela ────────────────────────────────
    component Tela: Item {
        id: tela
        focus: true
        Keys.onPressed: event => root.tecla(event)
        Component.onCompleted: forceActiveFocus()

        Image {
            anchors.fill: parent
            visible: status === Image.Ready
            source: root.wallpaper ? "file://" + root.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: tela.width
            sourceSize.height: tela.height
        }
        Rectangle { anchors.fill: parent; color: root.c.fundo; opacity: 0.55 }

        // relógio e data, centrados na tela
        Column {
            id: relogio
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hora
                color: root.c.texto
                font.family: root.fonte; font.pixelSize: 112; font.weight: Font.Light
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.data
                color: root.c.sub
                font.family: root.fonte; font.pixelSize: 13; font.letterSpacing: 0.5
            }
        }

        // anel de digitação, logo abaixo da data
        Item {
            id: anel
            readonly property real raio: 26
            readonly property real grossura: 5
            width: raio * 2 + grossura; height: width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: relogio.bottom
            anchors.topMargin: 36
            opacity: root.anelVisivel ? 1 : 0
            scale: root.anelVisivel ? 1 : 0.85
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Rectangle {   // miolo
                anchors.centerIn: parent
                width: anel.raio * 2 - anel.grossura; height: width; radius: width / 2
                color: root.c.fundo
                opacity: 0.8
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.corAnel
                    strokeWidth: anel.grossura
                    fillColor: "transparent"
                    PathAngleArc { centerX: anel.width / 2; centerY: anel.height / 2; radiusX: anel.raio; radiusY: anel.raio; startAngle: 0; sweepAngle: 360 }
                }
            }
            Shape {   // destaque da tecla
                anchors.fill: parent
                visible: root.hlVisivel && root.estado !== "verificando" && root.estado !== "errado"
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: root.hlApagar ? root.c.apagar : root.c.tecla
                    strokeWidth: anel.grossura
                    fillColor: "transparent"
                    capStyle: ShapePath.FlatCap
                    PathAngleArc { centerX: anel.width / 2; centerY: anel.height / 2; radiusX: anel.raio; radiusY: anel.raio; startAngle: root.hlAngulo; sweepAngle: 60 }
                }
            }
            Text {   // tentativas erradas
                anchors.centerIn: parent
                visible: root.falhas > 0
                text: root.falhas
                color: root.estado === "errado" ? root.c.errado : root.c.sub
                font.family: root.fonte; font.pixelSize: 13; font.bold: true
            }
        }

        // Caps Lock / mensagem do PAM, embaixo do anel
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: anel.bottom
            anchors.topMargin: 12
            opacity: anel.opacity
            text: root.mensagem !== "" ? root.mensagem : root.caps ? "Caps Lock" : ""
            color: root.mensagem !== "" ? root.c.errado : root.c.limpo
            font.family: root.fonte; font.pixelSize: 11
        }
    }
}
