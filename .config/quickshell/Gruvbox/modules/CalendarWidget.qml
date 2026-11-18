import QtQuick
import QtQuick.Layouts
import "holidays.js" as Holidays
import "."

// CalendarWidget.qml – relógio grande, mês com dias vizinhos, feriados nacionais e próximos feriados.
// Navegação: setas, rolagem do mouse sobre a grade, clique no nome do mês volta para hoje.
Rectangle {
    id: rootCal
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: Theme.fg
    property color colSurface0: Theme.surface0
    property color colSurface1: Theme.surface1
    property color colMauve: Theme.accent
    property color colBarBg: Theme.bg
    property color colSub: Theme.sub
    property color colPeach: Theme.yellow
    property color colRed: Theme.red

    implicitWidth: 336
    implicitHeight: mainCol.implicitHeight + 32
    radius: 16
    color: colBarBg
    border.color: colSurface0
    border.width: 1

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: rootCal.now = new Date() }

    readonly property var monthNames: ["Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"]
    readonly property var weekNames: ["Dom","Seg","Ter","Qua","Qui","Sex","Sáb"]
    readonly property var weekdayLong: ["Domingo","Segunda-feira","Terça-feira","Quarta-feira","Quinta-feira","Sexta-feira","Sábado"]

    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()
    function goToday() { viewYear = now.getFullYear(); viewMonth = now.getMonth() }
    function shiftMonth(n) {
        var d = new Date(viewYear, viewMonth + n, 1)
        viewYear = d.getFullYear(); viewMonth = d.getMonth()
    }

    // 42 células (6 semanas) começando no domingo antes do dia 1
    readonly property var cells: {
        var first = new Date(viewYear, viewMonth, 1)
        var start = new Date(viewYear, viewMonth, 1 - first.getDay())
        var list = []
        for (var i = 0; i < 42; i++) list.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
        return list
    }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }

    // dia sob o mouse (mostra o feriado no rodapé)
    property var hoveredDay: null
    readonly property var upcoming: Holidays.upcoming(now, 3)

    ColumnLayout {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 14

        // ── Relógio + data ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            RowLayout {
                spacing: 2
                Text {
                    text: Qt.formatTime(rootCal.now, "hh:mm")
                    color: rootCal.colMauve
                    font.family: rootCal.fontFamily; font.pixelSize: 40; font.bold: true
                }
                Text {
                    text: Qt.formatTime(rootCal.now, "ss")
                    color: rootCal.colSub
                    font.family: rootCal.fontFamily; font.pixelSize: 14; font.bold: true
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 8
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: rootCal.weekdayLong[rootCal.now.getDay()]
                    color: rootCal.colText
                    font.family: rootCal.fontFamily; font.pixelSize: 14; font.bold: true
                }
                Text {
                    text: rootCal.now.getDate() + " de " + rootCal.monthNames[rootCal.now.getMonth()].toLowerCase() + " de " + rootCal.now.getFullYear()
                    color: rootCal.colSub
                    font.family: rootCal.fontFamily; font.pixelSize: 11
                }
                Text {
                    text: "Semana " + Holidays.isoWeek(rootCal.now) + " · dia " + Holidays.dayOfYear(rootCal.now) + "/" + Holidays.daysInYear(rootCal.now.getFullYear())
                    color: rootCal.colSub
                    font.family: rootCal.fontFamily; font.pixelSize: 10
                }
            }
        }

        // ── Mês + navegação ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: rootCal.monthNames[rootCal.viewMonth] + " " + rootCal.viewYear
                color: titleMouse.containsMouse ? rootCal.colMauve : rootCal.colText
                font.family: rootCal.fontFamily; font.pixelSize: 15; font.bold: true
                Layout.fillWidth: true
                MouseArea {
                    id: titleMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: rootCal.goToday()
                }
            }
            Repeater {
                model: [{ icon: "", step: -1 }, { icon: "", step: 1 }]
                Rectangle {
                    required property var modelData
                    implicitWidth: 28; implicitHeight: 28; radius: 8
                    color: navMouse.containsMouse ? rootCal.colSurface1 : rootCal.colSurface0
                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: rootCal.colText
                        font.family: rootCal.fontFamily; font.pixelSize: 12
                    }
                    MouseArea {
                        id: navMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: rootCal.shiftMonth(modelData.step)
                    }
                }
            }
        }

        // ── Grade ──────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            RowLayout {
                Layout.fillWidth: true
                spacing: 0
                Repeater {
                    model: rootCal.weekNames
                    Text {
                        required property var modelData
                        required property int index
                        text: modelData
                        color: index === 0 || index === 6 ? rootCal.colPeach : rootCal.colSub
                        opacity: 0.85
                        font.family: rootCal.fontFamily; font.pixelSize: 10; font.bold: true
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
            GridLayout {
                id: grid
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 2
                Repeater {
                    model: rootCal.cells
                    Item {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool inMonth: modelData.getMonth() === rootCal.viewMonth
                        readonly property bool isToday: rootCal.sameDay(modelData, rootCal.now)
                        readonly property bool weekend: index % 7 === 0 || index % 7 === 6
                        readonly property var holiday: Holidays.holidayOn(modelData)
                        Layout.fillWidth: true
                        implicitHeight: 36
                        Rectangle {
                            anchors.centerIn: parent
                            width: 34; height: 34; radius: 17
                            color: cell.isToday ? rootCal.colMauve : dayMouse.containsMouse ? rootCal.colSurface1 : "transparent"
                            border.color: cell.holiday && !cell.isToday ? rootCal.colPeach : "transparent"
                            border.width: 1
                        }
                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.getDate()
                            color: cell.isToday ? rootCal.colBarBg
                                 : cell.holiday ? rootCal.colPeach
                                 : cell.weekend ? Qt.lighter(rootCal.colSub, 1.1)
                                 : rootCal.colText
                            opacity: cell.inMonth ? 1 : 0.3
                            font.family: rootCal.fontFamily; font.pixelSize: 12
                            font.bold: cell.isToday || cell.holiday !== null
                        }
                        MouseArea {
                            id: dayMouse
                            anchors.fill: parent; hoverEnabled: true
                            onEntered: rootCal.hoveredDay = cell.modelData
                            onExited: if (rootCal.hoveredDay === cell.modelData) rootCal.hoveredDay = null
                            onClicked: if (!cell.inMonth) rootCal.shiftMonth(cell.modelData < new Date(rootCal.viewYear, rootCal.viewMonth, 1) ? -1 : 1)
                        }
                    }
                }
            }
            // rolar sobre a grade troca o mês
            WheelHandler {
                target: null
                onWheel: event => rootCal.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: rootCal.colSurface0 }

        // ── Rodapé: dia sob o mouse ou próximos feriados ───
        ColumnLayout {
            Layout.fillWidth: true
            // altura fixa: o painel não muda de tamanho ao passar o mouse nos dias
            Layout.preferredHeight: 78
            Layout.alignment: Qt.AlignTop
            spacing: 4
            readonly property var hovered: rootCal.hoveredDay
            readonly property var hoveredHoliday: hovered ? Holidays.holidayOn(hovered) : null

            Text {
                text: parent.hovered ? rootCal.weekdayLong[parent.hovered.getDay()] + ", " + parent.hovered.getDate() + " de " + rootCal.monthNames[parent.hovered.getMonth()].toLowerCase()
                                     : "PRÓXIMOS FERIADOS"
                color: rootCal.colSub
                font.family: rootCal.fontFamily; font.pixelSize: parent.hovered ? 11 : 10; font.bold: true
                font.letterSpacing: parent.hovered ? 0 : 0.5
            }
            Text {
                visible: parent.hovered !== null
                text: parent.hoveredHoliday ? "󰃰  " + parent.hoveredHoliday.name + (parent.hoveredHoliday.optional ? " (ponto facultativo)" : "") : "Sem feriado"
                color: parent.hoveredHoliday ? rootCal.colPeach : rootCal.colSub
                font.family: rootCal.fontFamily; font.pixelSize: 12
            }
            Repeater {
                model: parent.hovered ? [] : rootCal.upcoming
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        text: Qt.formatDate(modelData.date, "dd/MM")
                        color: rootCal.colPeach
                        font.family: rootCal.fontFamily; font.pixelSize: 12; font.bold: true
                    }
                    Text {
                        text: modelData.name + (modelData.optional ? " *" : "")
                        color: rootCal.colText
                        font.family: rootCal.fontFamily; font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: Holidays.relative(modelData.daysUntil)
                        color: rootCal.colSub
                        font.family: rootCal.fontFamily; font.pixelSize: 10
                    }
                }
            }
        }
    }
}
