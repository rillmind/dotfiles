import QtQuick

// NetworkStatusWidget.qml
// Widget circular isolado: container + wifi Nerd Font exata " " + anel de bateria 280° + 4 dots volume
// - Anel 280° = 180° topo + 50° cada lateral, gap 80° no centro-em baixo livre para volume
// - 4 dots embaixo: 1 dot = 25% volume (lit: volume >= (i+1)*25) esq→dir, tangenciam anel na mesma linha
// - Wifi central Nerd Font " " (2 caracteres, ocupa 2 cols) mauve completo quando conectado max
// Reutilizável: widgetSize grande (ControlCenter) ou compacto (barra futura)
// Catppuccin Mocha – remainder overlay1 #7f849c para ver o que falta (fundo bateria/volume/wifi)
//
Item {
    id: root

    // ── API pública ──────────────────────────────────────────────
    property int widgetSize: 84                  // diâmetro do círculo externo
    property color primaryColor: "#cba6f7"       // Catppuccin mauve (wifi/bateria cheia)
    property color backgroundColor: "#1e1e2e"    // base
    property color surfaceColor: "#313244"       // surface0 (fallback)
    property color remainderColor: "#7f849c"     // overlay1 – fundo de tudo (bateria/volume/wifi remainder)
    property color borderColor: "#7f849c"
    property color textColor: "#cdd6f4"
    property string state: "connected"           // scanning | connected | disconnected (wifi)
    property int volumeLevel: 35                 // 0..100 – usado para 4 dots (threshold 25%)
    property bool volumeMuted: false
    property int batteryCapacity: 100            // 0..100 – usado para anel 280°
    property bool batteryCharging: false
    property int animationDuration: 1200

    // tamanho dos dots de volume
    property int dotSize: Math.max(5, Math.round(widgetSize * 0.095))
    // espessura do anel de bateria
    property real ringStroke: Math.max(3, widgetSize * 0.045)
    // gap embaixo para volume – 80° dá mais espaço pros 4 dots
    property real gapDeg: 80
    // arco total bateria
    property real batteryArcDeg: 360 - gapDeg // 280

    width: widgetSize
    height: widgetSize

    // raio do anel (centralizado, na borda interna)
    property real ringRadius: widgetSize / 2 - ringStroke / 2 - 0.5

    // ── Container circular (fundo) ─────────────────────────────────
    Rectangle {
        id: circle
        anchors.centerIn: parent
        width: root.widgetSize
        height: root.widgetSize
        radius: root.widgetSize / 2
        color: root.backgroundColor
        border.color: root.borderColor
        border.width: 1.2

        // ── Anel de bateria 280° (Canvas) ──────────────────────────
        // 280° = 180 topo + 50 esq + 50 dir, gap 80° embaixo centrado no sul (90°).
        // Canvas 0° = leste, cresce horário. Gap: 50°→130° (centro 90°).
        // Start = 130° (fim do gap), span 280° até 50°+360°.
        Canvas {
            id: batteryRing
            anchors.centerIn: parent
            width: root.widgetSize
            height: root.widgetSize
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            property color trackColor: root.remainderColor
            property color fillColor: {
                if (root.batteryCapacity >= 100) return root.primaryColor // 100% sempre mauve, não verde
                if (root.batteryCharging) return root.primaryColor
                if (root.batteryCapacity <= 15) return "#f38ba8"
                if (root.batteryCapacity <= 40) return "#fab387"
                return "#a6e3a1"
            }
            onFillColorChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2
                var cy = height / 2
                var r = root.ringRadius
                var sw = root.ringStroke
                var gapStartDeg = 90 - root.gapDeg/2 // 50
                var gapEndDeg   = 90 + root.gapDeg/2 // 130
                var battStartDeg = gapEndDeg // 130
                var battSpanDeg = root.batteryArcDeg // 280
                var battEndDeg = battStartDeg + (root.batteryCapacity / 100) * battSpanDeg
                // trilho 280° remainder claro
                ctx.strokeStyle = trackColor
                ctx.lineWidth = sw
                ctx.lineCap = "round"
                ctx.beginPath()
                ctx.arc(cx, cy, r, battStartDeg * Math.PI/180, (battStartDeg + battSpanDeg) * Math.PI/180, false)
                ctx.stroke()
                // progresso bateria
                if (root.batteryCapacity > 0) {
                    ctx.strokeStyle = fillColor
                    ctx.lineWidth = sw
                    ctx.lineCap = "round"
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, battStartDeg * Math.PI/180, battEndDeg * Math.PI/180, false)
                    ctx.stroke()
                }
                if (root.batteryCapacity > 0 && root.batteryCapacity < 100) {
                    var ang = battEndDeg * Math.PI/180
                    var px = cx + r * Math.cos(ang)
                    var py = cy + r * Math.sin(ang)
                    ctx.fillStyle = fillColor
                    ctx.beginPath()
                    ctx.arc(px, py, sw * 0.42, 0, Math.PI*2)
                    ctx.fill()
                }
            }
            Component.onCompleted: requestPaint()
            Connections {
                target: root
                function onBatteryCapacityChanged() { batteryRing.requestPaint() }
                function onBatteryChargingChanged() { batteryRing.requestPaint() }
                function onWidgetSizeChanged() { batteryRing.requestPaint() }
            }
        }

        // ── Ícone WiFi centralizado – Nerd Font exata " " (2 caracteres) ─
        Text {
            id: wifiIcon
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -root.widgetSize * 0.015
            text: " " // exata Nerd Font, ocupa 2 caracteres
            color: root.state === "disconnected" ? "#f38ba8" : root.primaryColor // mauve completo quando conectado max
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(root.widgetSize * 0.386)
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // ── 4 dots de volume embaixo, tangenciam anel na mesma linha ─
        // Cada dot = threshold 25%: lit se volumeLevel >= (index+1)*25, esq→dir
        // Gap bateria↔dots aumentado: margem 16° cada lado (vs 10°), gap entre dots tb 16°
        // Posição: sobre a mesma circunferência do anel (R = ringRadius), tangenciam
        Item {
            id: volumeDots
            anchors.fill: parent
            property real gapStartDeg: 90 - root.gapDeg/2 // 50
            property real gapSpanDeg: root.gapDeg // 80
            Repeater {
                model: 4
                Rectangle {
                    id: vdot
                    width: root.dotSize
                    height: root.dotSize
                    radius: root.dotSize/2
                    property int idx: index
                    property int threshold: (index+1)*25
                    property bool lit: !root.volumeMuted && root.volumeLevel >= threshold
                    color: lit ? root.primaryColor : root.remainderColor
                    opacity: lit ? 1.0 : 0.85
                    scale: lit ? 1.0 : 0.92
                    border.color: lit ? root.primaryColor : "transparent"
                    border.width: 0
                    // margem 16°: gapEnd - (i+1)/5*gapSpan → i0 114° esq ... i3 66° dir, gap anel→dot = 16°
                    property real thetaDeg: volumeDots.gapStartDeg + volumeDots.gapSpanDeg - ( (idx+1)/5 * volumeDots.gapSpanDeg )
                    property real thetaRad: thetaDeg * Math.PI/180
                    // tangenciam anel: mesmo raio do anel, na mesma linha do que sobra da bateria
                    x: root.widgetSize/2 + root.ringRadius * Math.cos(thetaRad) - width/2
                    y: root.widgetSize/2 + root.ringRadius * Math.sin(thetaRad) - height/2
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }

        Rectangle {
            visible: root.state === "disconnected"
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: "#f38ba8"
            border.width: 1.0
            opacity: 0.55
        }
    }
}
