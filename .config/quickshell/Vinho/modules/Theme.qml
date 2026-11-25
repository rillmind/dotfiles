pragma Singleton
import QtQuick
import Quickshell

// Theme.qml – paleta Vinho, com os mesmos nomes do Theme.qml do Gruvbox (módulos em comum).
// Tudo quadrado: os módulos deste tema usam radius 0. Paleta completa em ~/.config/vinho/CORES.md.
Singleton {
    readonly property bool light: false
    readonly property color bgHard:   "#15070d"
    readonly property color bg:       "#1c0b12"   // barra, painéis, launcher
    readonly property color tile:     "#28111a"
    readonly property color surface0: "#35151f"
    readonly property color surface1: "#4a1d2c"
    readonly property color surface2: "#5f2c3c"
    readonly property color selection: "#5a2236"
    readonly property color frame:    "#8c2f4b"   // molduras e workspace ativo
    readonly property color fg:       "#e8d5cf"
    readonly property color bright:   "#f6e9e2"
    readonly property color soft:     "#c9aaab"
    readonly property color sub:      "#b08d94"
    readonly property color gray:     "#8a646c"
    readonly property color red:      "#e0566f"
    readonly property color green:    "#a3ad7a"
    readonly property color yellow:   "#d9a862"
    readonly property color blue:     "#93a3c0"
    readonly property color purple:   "#c99ab8"
    readonly property color aqua:     "#8fb0a4"
    readonly property color orange:   "#d98968"
    readonly property color accent:   "#c4527a"
    readonly property color onAccent: bgHard
    readonly property string font: "JetBrainsMono Nerd Font"
}
