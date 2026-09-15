import QtQuick
import QtQuick.Layouts

Rectangle {
    id: rootCal
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: "#cdd6f4"
    property color colSurface0: "#313244"
    property color colSurface1: "#45475a"
    property color colMauve: "#cba6f7"
    property color colBarBg: "#1e1e2e"

    width: 340
    height: 380
    radius: 12
    color: colBarBg
    border.color: colSurface0
    border.width: 1

    // data atual atualizada a cada segundo
    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: rootCal.now = new Date() }

    // helpers
    function daysInMonth(y,m) { return new Date(y, m+1, 0).getDate() }
    function firstWeekday(y,m) { return new Date(y, m, 1).getDay() } // 0 dom
    // nomes pt-BR
    property var monthNames: ["Janeiro","Fevereiro","Março","Abril","Maio","Junho","Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"]
    property var weekNames: ["D","S","T","Q","Q","S","S"]

    // modelo: mês atual
    property int curYear: now.getFullYear()
    property int curMonth: now.getMonth()
    property int curDay: now.getDate()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── Header: data exata dd/mm/yyyy ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: Qt.formatDate(rootCal.now, "dd/MM/yyyy")
                color: colText
                font.family: fontFamily
                font.pixelSize: 22
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: Qt.formatDate(rootCal.now, "dddd")
                color: colText
                font.family: fontFamily
                font.pixelSize: 12
                opacity: 0.7
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                // capitalizar
            }
            // hora exata hh:mm:ss
            Text {
                id: timeText
                text: Qt.formatDateTime(rootCal.now, "hh:mm:ss")
                color: colMauve
                font.family: fontFamily
                font.pixelSize: 28
                font.bold: true
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: colSurface0; opacity: 0.6 }

        // ── Mês / Ano + navegação ──
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: monthNames[curMonth] + " " + curYear
                color: colText
                font.family: fontFamily
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }
            Rectangle {
                width: 28; height: 28; radius: 6; color: colSurface0
                Text { anchors.centerIn: parent; text: "‹"; color: colText; font.pixelSize: 16; font.bold: true }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (curMonth === 0) { curMonth = 11; curYear-- } else curMonth--
                    }
                }
            }
            Rectangle {
                width: 28; height: 28; radius: 6; color: colSurface0
                Text { anchors.centerIn: parent; text: "›"; color: colText; font.pixelSize: 16; font.bold: true }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (curMonth === 11) { curMonth = 0; curYear++ } else curMonth++
                    }
                }
            }
            Rectangle {
                width: 36; height: 28; radius: 6; color: colMauve
                Text { anchors.centerIn: parent; text: "Hoje"; color: colBarBg; font.family: fontFamily; font.pixelSize: 10; font.bold: true }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { curYear = now.getFullYear(); curMonth = now.getMonth() }
                }
            }
        }

        // ── Cabeçalho dias semana ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: weekNames
                Text {
                    text: modelData
                    color: colText; opacity: 0.6
                    font.family: fontFamily; font.pixelSize: 11; font.bold: true
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ── Grade dias ──
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            // espaços vazios antes do dia 1
            Repeater {
                model: firstWeekday(curYear, curMonth)
                Item { Layout.preferredWidth: 38; Layout.preferredHeight: 32 }
            }
            Repeater {
                model: daysInMonth(curYear, curMonth)
                Rectangle {
                    property int dayNum: index + 1
                    property bool isToday: curYear === now.getFullYear() && curMonth === now.getMonth() && dayNum === now.getDate()
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 32
                    Layout.fillWidth: true
                    radius: 6
                    color: isToday ? colMauve : (mouse.containsMouse ? colSurface1 : "transparent")
                    border.color: isToday ? colMauve : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: dayNum
                        color: isToday ? colBarBg : colText
                        font.family: fontFamily
                        font.pixelSize: 12
                        font.bold: isToday
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: colSurface0; opacity: 0.6; Layout.topMargin: 4 }

        Text {
            text: "Dia " + Qt.formatDate(now, "dd 'de' MMMM 'de' yyyy")
            color: colText; opacity: 0.6
            font.family: fontFamily; font.pixelSize: 10
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
