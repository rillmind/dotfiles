pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Theme.qml – paleta Gruvbox (escuro/claro) usada por todo o tema. O modo fica salvo em
// ~/.local/state/quickshell/gruvbox-modo e muda ao vivo: card Modo na central, Super+Shift+L ou
// `tema.sh ipc gruvbox modo`.
Singleton {
    id: theme

    property bool light: false
    // troca o modo e leva para os outros apps (bordas, terminal, nvim, GTK, wallpaper: ver aparencia.sh)
    function toggle() {
        light = !light
        modeFile.setText(light ? "claro" : "escuro")
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/aparencia.sh", "aplicar", light ? "gruvbox-claro" : "gruvbox-escuro"])
    }

    FileView {
        id: modeFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/gruvbox-modo"
        printErrors: false   // só existe depois da primeira troca
        onLoaded: theme.light = text().trim() === "claro"
    }
    IpcHandler {
        target: "gruvbox"
        function modo(): void { theme.toggle() }
        function claro(): void { if (!theme.light) theme.toggle() }
        function escuro(): void { if (theme.light) theme.toggle() }
    }

    // ── Fundos ─────────────────────────────────────────────
    readonly property color bgHard:   light ? "#f9f5d7" : "#1d2021"   // barra lateral
    readonly property color bg:       light ? "#fbf1c7" : "#282828"   // painéis
    readonly property color tile:     light ? "#f2e5bc" : "#32302f"   // cards dentro dos painéis
    readonly property color surface0: light ? "#ebdbb2" : "#3c3836"
    readonly property color surface1: light ? "#d5c4a1" : "#504945"
    readonly property color surface2: light ? "#bdae93" : "#665c54"
    // ── Texto ──────────────────────────────────────────────
    readonly property color fg:       light ? "#3c3836" : "#ebdbb2"
    readonly property color sub:      light ? "#7c6f64" : "#a89984"
    readonly property color gray:     "#928374"
    // ── Cores ──────────────────────────────────────────────
    readonly property color red:      light ? "#9d0006" : "#fb4934"
    readonly property color green:    light ? "#79740e" : "#b8bb26"
    readonly property color yellow:   light ? "#b57614" : "#fabd2f"
    readonly property color blue:     light ? "#076678" : "#83a598"
    readonly property color purple:   light ? "#8f3f71" : "#d3869b"
    readonly property color aqua:     light ? "#427b58" : "#8ec07c"
    readonly property color orange:   light ? "#af3a03" : "#fe8019"
    // destaque do tema (workspace ativo, seleção, barras)
    readonly property color accent:   orange
    // texto em cima do destaque
    readonly property color onAccent: light ? "#fbf1c7" : "#1d2021"

    readonly property string font: "JetBrainsMono Nerd Font"
}
