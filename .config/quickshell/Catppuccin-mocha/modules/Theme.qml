pragma Singleton
import QtQuick
import Quickshell

// Theme.qml – paleta Catppuccin Mocha com os mesmos nomes do Theme.qml do Gruvbox, para os módulos
// compartilhados entre os temas (notificações) funcionarem nos dois sem mudança.
Singleton {
    readonly property bool light: false
    readonly property color bgHard:   "#181825"   // mantle
    readonly property color bg:       "#1e1e2e"   // base
    readonly property color tile:     "#27273a"
    readonly property color surface0: "#313244"
    readonly property color surface1: "#45475a"
    readonly property color surface2: "#585b70"
    readonly property color fg:       "#cdd6f4"
    readonly property color sub:      "#a6adc8"
    readonly property color gray:     "#7f849c"
    readonly property color red:      "#f38ba8"
    readonly property color green:    "#a6e3a1"
    readonly property color yellow:   "#f9e2af"
    readonly property color blue:     "#89b4fa"
    readonly property color purple:   "#cba6f7"
    readonly property color aqua:     "#94e2d5"
    readonly property color orange:   "#fab387"
    readonly property color accent:   purple       // mauve
    readonly property color onAccent: bg
    readonly property string font: "JetBrainsMono Nerd Font"
}
