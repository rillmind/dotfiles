import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

// DisplayManager.qml – lista os monitores do Hyprland e aplica ativar/desativar, resolução e FPS.
// Vive no shell.qml (e não no ControlCenter) para sobreviver quando a tela do painel some ou muda.
//
// Toda mudança pede confirmação: sem resposta em 15 s ela é desfeita, porque um modo sem sinal
// deixaria a tela preta. Ao confirmar, a escolha é salva em ~/.local/state/hypr/monitors.lua,
// que o hyprland.lua carrega depois das próprias regras. Apague esse arquivo para voltar às
// regras do hyprland.lua.
//
// Também responde por IPC: quickshell ipc call monitors <menu|closeMenu|setMode|setEnabled|keep|revert>
Scope {
    id: mgr
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSub: "#a6adc8"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colMauve: "#cba6f7"
    property color colBase: "#1e1e2e"

    // [{ name, description, disabled, width, height, currentRes, currentRate, modes: [{ res, rates }], raw }]
    property var monitors: []
    readonly property int activeCount: monitors.filter(m => !m.disabled).length
    property string errorText: ""
    property var pending: null       // { next, prev, summary }: mudança aguardando confirmação
    property int countdown: 0
    readonly property int confirmSeconds: 15

    signal menuRequested()
    signal menuCloseRequested()

    IpcHandler {
        target: "monitors"
        function menu(): void { mgr.menuRequested() }
        function closeMenu(): void { mgr.menuCloseRequested() }
        function setMode(name: string, res: string, rate: string): void { mgr.setMode(name, res, rate) }
        function setEnabled(name: string, on: bool): void { mgr.setEnabled(name, on) }
        function keep(): void { mgr.keep() }
        function revert(): void { mgr.revert() }
    }

    // ── Leitura ────────────────────────────────────────────
    function refresh() { listProc.running = true }
    Process {
        id: listProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { mgr.monitors = JSON.parse(text).map(mgr.parseMonitor) }
                catch (e) { mgr.errorText = "Não foi possível ler os monitores" }
            }
        }
    }
    Component.onCompleted: refresh()
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event && event.name && event.name.indexOf("monitor") === 0) refreshTimer.restart()
        }
    }
    Timer { id: refreshTimer; interval: 300; onTriggered: mgr.refresh() }

    function parseMonitor(m) {
        // availableModes: "2560x1440@59.95Hz"; agrupa as taxas por resolução, maiores primeiro
        var byRes = {}
        for (var mode of (m.availableModes || [])) {
            var parts = mode.replace("Hz", "").split("@")
            if (parts.length !== 2) continue
            if (!byRes[parts[0]]) byRes[parts[0]] = []
            if (byRes[parts[0]].indexOf(parts[1]) === -1) byRes[parts[0]].push(parts[1])
        }
        var area = r => { var d = r.split("x"); return d[0] * d[1] }
        var modes = Object.keys(byRes)
            .sort((a, b) => area(b) - area(a))
            .map(r => ({ res: r, rates: byRes[r].sort((a, b) => b - a) }))

        var currentRes = m.width + "x" + m.height
        var current = modes.find(x => x.res === currentRes)
        // refreshRate vem com mais casas (59.951) do que availableModes (59.95): pega a mais próxima
        var currentRate = m.refreshRate.toFixed(2)
        if (current) currentRate = current.rates.reduce((best, r) => Math.abs(r - m.refreshRate) < Math.abs(best - m.refreshRate) ? r : best)

        return { name: m.name, description: (m.make + " " + m.model).trim(), disabled: m.disabled,
                 width: m.width, height: m.height, currentRes: currentRes, currentRate: currentRate,
                 modes: modes, raw: m }
    }
    function find(name) { return monitors.find(m => m.name === name) }

    // ── Regras do Hyprland ─────────────────────────────────
    // mesma escala por resolução usada no hyprland.lua: a área útil continua 1920x1080
    function scaleFor(height) { return height >= 2160 ? 2 : height >= 1440 ? 1.33 : 1 }

    function luaRule(spec) {
        if (spec.disabled) return "hl.monitor({ output = " + JSON.stringify(spec.output) + ", disabled = true })"
        // disabled = false é obrigatório: as regras se somam por saída, e um disabled = true anterior
        // (inclusive o do hyprland.lua) continuaria valendo
        return "hl.monitor({ output = " + JSON.stringify(spec.output) + ", disabled = false, mode = " + JSON.stringify(spec.mode)
            + ", position = " + JSON.stringify(spec.position) + ", scale = " + spec.scale
            + ", transform = " + spec.transform + " })"
    }
    function currentSpec(m) {
        if (m.disabled) return { output: m.name, disabled: true }
        return { output: m.name, mode: m.currentRes + "@" + m.currentRate, position: m.raw.x + "x" + m.raw.y,
                 scale: m.raw.scale, transform: m.raw.transform }
    }

    // ── Aplicar, confirmar, desfazer ───────────────────────
    function setMode(name, res, rate) {
        var m = find(name)
        if (!m || m.disabled || (res === m.currentRes && rate === m.currentRate)) return
        apply(m, { output: name, mode: res + "@" + rate, position: m.raw.x + "x" + m.raw.y,
                   scale: scaleFor(parseInt(res.split("x")[1])), transform: m.raw.transform },
              name + ": " + res + " a " + rate + " Hz")
    }
    function setEnabled(name, on) {
        var m = find(name)
        if (!m || on === !m.disabled) return
        if (!on) {
            if (activeCount <= 1) { errorText = "Não dá para desativar o único monitor ativo"; return }
            apply(m, { output: name, disabled: true }, name + " desativado")
            return
        }
        // volta no último modo conhecido, em uma posição livre (como faz o bind da tampa)
        apply(m, { output: name, mode: m.width > 0 ? m.currentRes + "@" + m.currentRate : "preferred", position: "auto",
                   scale: scaleFor(m.height), transform: m.raw.transform },
              name + " ativado")
    }
    function apply(m, next, summary) {
        if (pending) { errorText = "Confirme a mudança anterior primeiro"; return }
        errorText = ""
        pending = { next: next, prev: currentSpec(m), summary: summary }
        applyProc.command = ["hyprctl", "eval", luaRule(next)]
        applyProc.running = true
    }
    Process {
        id: applyProc
        stdout: StdioCollector { id: applyOut }
        onExited: code => {
            if (code !== 0) {
                mgr.errorText = applyOut.text.trim() || "O Hyprland recusou a mudança"
                mgr.pending = null
                return
            }
            mgr.countdown = mgr.confirmSeconds
            countdownTimer.restart()
            refreshTimer.restart()
        }
    }
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            mgr.countdown -= 1
            if (mgr.countdown <= 0) mgr.revert()
        }
    }
    function keep() {
        if (!pending) return
        countdownTimer.stop()
        persist(pending.next)
        pending = null
    }
    function revert() {
        if (!pending) return
        countdownTimer.stop()
        revertProc.command = ["hyprctl", "eval", luaRule(pending.prev)]
        revertProc.running = true
        pending = null
    }
    Process { id: revertProc; onExited: refreshTimer.restart() }

    // ── Persistência ───────────────────────────────────────
    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/hypr/monitors.lua"
    property string savedText: ""
    FileView {
        path: mgr.statePath
        printErrors: false   // o arquivo só existe depois da primeira confirmação
        onLoaded: mgr.savedText = text()
    }
    function persist(spec) {
        // uma linha por monitor: troca só a do monitor alterado
        var marker = "output = " + JSON.stringify(spec.output) + ","
        var lines = savedText.split("\n").filter(l => l.indexOf("hl.monitor(") === 0 && l.indexOf(marker) === -1)
        lines.push(luaRule(spec))
        savedText = "-- Gerado pelo menu de monitores do quickshell (modules/DisplayManager.qml).\n" + lines.join("\n") + "\n"
        saveProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "sh", statePath, savedText]
        saveProc.running = true
    }
    Process {
        id: saveProc
        onExited: code => { if (code !== 0) mgr.errorText = "Não foi possível salvar a escolha em " + mgr.statePath }
    }

    // ── Confirmação (em todas as telas: a do painel pode ter acabado de sumir) ─
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: mgr.pending !== null && countdownTimer.running
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "quickshell-monitor-confirm"
            // sem âncoras: o compositor centraliza a janela na tela
            implicitWidth: 400
            implicitHeight: confirmCol.implicitHeight + 32
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: "#F21e1e2e"
                border.color: mgr.colMauve
                border.width: 2

                ColumnLayout {
                    id: confirmCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 16
                    spacing: 12
                    Text {
                        text: "Manter esta configuração?"
                        color: mgr.colText
                        font.family: mgr.fontFamily; font.pixelSize: 15; font.bold: true
                    }
                    Text {
                        text: (mgr.pending ? mgr.pending.summary : "") + "\nDesfazendo em " + mgr.countdown + " s"
                        color: mgr.colSub
                        font.family: mgr.fontFamily; font.pixelSize: 12
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32; radius: 8
                            color: revertMouse.containsMouse ? mgr.colSurface1 : mgr.colSurface0
                            Text { anchors.centerIn: parent; text: "Desfazer"; color: mgr.colText; font.family: mgr.fontFamily; font.pixelSize: 12 }
                            MouseArea { id: revertMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: mgr.revert() }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32; radius: 8
                            color: mgr.colMauve
                            Text { anchors.centerIn: parent; text: "Manter"; color: mgr.colBase; font.family: mgr.fontFamily; font.pixelSize: 12; font.bold: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: mgr.keep() }
                        }
                    }
                }
            }
        }
    }
}
