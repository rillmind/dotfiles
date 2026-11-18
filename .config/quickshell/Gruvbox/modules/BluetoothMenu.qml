import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import "."

// BluetoothMenu.qml – submenu de Bluetooth do ControlCenter: liga e desliga, opções do adaptador, pedidos
// de pareamento e a lista de aparelhos, cada um com as suas opções. A lógica fica no BluetoothManager.
ColumnLayout {
    id: menu
    property var manager: null
    property string fontFamily: "JetBrainsMono Nerd Font"
    property color colText: Theme.fg
    property color colSub: Theme.sub
    property color colSurface0: Theme.surface0
    property color colSurface1: Theme.surface1
    property color colMauve: Theme.accent
    property color colBase: Theme.bg
    property color colDanger: Theme.red
    property color colTile: Theme.tile
    signal back()

    readonly property var adapter: manager ? manager.adapter : null
    readonly property bool powered: !!manager && manager.enabled
    readonly property var request: manager ? manager.request : null
    readonly property bool typingCode: !!request && (request.kind === "pin" || request.kind === "passkey")
    property bool adapterOpen: false
    property string renaming: ""           // "adapter" ou o endereço do aparelho sendo renomeado
    // o painel só pede foco de teclado enquanto há um campo de texto aberto
    readonly property bool wantsKeyboard: typingCode || renaming !== ""

    onVisibleChanged: if (!visible) { renaming = ""; adapterOpen = false }

    spacing: 12

    function iconFor(icon) {
        if (icon.startsWith("audio-headset") || icon.startsWith("audio-headphones")) return "󰋋"
        if (icon.startsWith("audio")) return "󰓃"
        if (icon === "input-gaming") return "󰊗"
        if (icon === "input-keyboard") return "󰌌"
        if (icon === "input-mouse") return "󰍽"
        if (icon.startsWith("phone")) return "󰏲"
        if (icon.startsWith("computer")) return "󰟀"
        return "󰂯"
    }
    function statusOf(d) {
        if (d.state === BluetoothDeviceState.Connecting) return "conectando…"
        if (d.state === BluetoothDeviceState.Disconnecting) return "desconectando…"
        if (d.pairing) return "pareando…"
        if (d.blocked) return "bloqueado"
        if (d.connected) return d.batteryAvailable ? "conectado · " + Math.round(d.battery * 100) + "%" : "conectado"
        if (d.paired) return "pareado"
        return ""
    }
    function serviceLabel(uuid) {
        var known = { "0000110a": "enviar áudio", "0000110b": "receber áudio", "0000110c": "controle de mídia", "0000110e": "controle de mídia",
                      "0000111e": "chamadas", "0000111f": "chamadas", "00001105": "enviar arquivos", "00001124": "teclado ou mouse" }
        return known[String(uuid).substring(0, 8)] || uuid
    }

    component Label: Text {
        color: menu.colSub
        font.family: menu.fontFamily; font.pixelSize: 11; font.bold: true
    }
    component Divider: Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: menu.colSurface0 }

    component Btn: Rectangle {
        id: btn
        property string label: ""
        property bool primary: false
        property bool danger: false
        property bool active: true
        signal clicked()
        implicitWidth: btnText.implicitWidth + 16; implicitHeight: 26; radius: 8
        opacity: active ? 1 : 0.5
        color: primary ? menu.colMauve : danger ? menu.colDanger : btnMouse.containsMouse && active ? menu.colSurface1 : menu.colSurface0
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.primary || btn.danger ? menu.colBase : menu.colText
            font.family: menu.fontFamily; font.pixelSize: 11; font.bold: btn.primary || btn.danger
        }
        MouseArea {
            id: btnMouse
            anchors.fill: parent; hoverEnabled: true
            enabled: btn.active
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }

    component Toggle: Rectangle {
        id: toggle
        property bool checked: false
        signal toggled()
        implicitWidth: 38; implicitHeight: 22; radius: 11
        color: checked ? menu.colMauve : menu.colSurface1
        Rectangle {
            width: 16; height: 16; radius: 8
            y: 3
            x: toggle.checked ? toggle.width - width - 3 : 3
            color: toggle.checked ? menu.colBase : menu.colText
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: toggle.toggled() }
    }

    component SwitchRow: RowLayout {
        id: switchRow
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled()
        Layout.fillWidth: true
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: switchRow.title
                Layout.fillWidth: true
                color: menu.colText
                font.family: menu.fontFamily; font.pixelSize: 12; font.bold: true
            }
            Text {
                visible: text !== ""
                text: switchRow.subtitle
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: menu.colSub
                font.family: menu.fontFamily; font.pixelSize: 10
            }
        }
        Toggle { checked: switchRow.checked; onToggled: switchRow.toggled() }
    }

    component Info: RowLayout {
        id: info
        property string label: ""
        property string value: ""
        visible: value !== ""
        Layout.fillWidth: true
        spacing: 12
        Text { text: info.label; color: menu.colSub; font.family: menu.fontFamily; font.pixelSize: 11 }
        Text {
            text: info.value
            color: menu.colText
            font.family: menu.fontFamily; font.pixelSize: 11
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }

    // tempo que o adaptador fica visível ou pareável; 0 é sem limite
    component TimeoutChips: RowLayout {
        id: chips
        property int value: 0
        signal picked(int seconds)
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: [{ label: "1 min", seconds: 60 }, { label: "3 min", seconds: 180 }, { label: "10 min", seconds: 600 }, { label: "Sempre", seconds: 0 }]
            Rectangle {
                id: chip
                required property var modelData
                readonly property bool selected: chips.value === modelData.seconds
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 24; radius: 8
                color: selected ? menu.colMauve : chipMouse.containsMouse ? menu.colSurface1 : menu.colSurface0
                Text {
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chip.selected ? menu.colBase : menu.colText
                    font.family: menu.fontFamily; font.pixelSize: 10; font.bold: chip.selected
                }
                MouseArea {
                    id: chipMouse
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chips.picked(chip.modelData.seconds)
                }
            }
        }
    }

    // campo de texto de uma linha: Enter confirma, Esc cancela
    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string placeholder: ""
        property int maximumLength: 248
        property var validator: null
        signal accepted()
        signal cancelled()
        function focusInput() { input.forceActiveFocus() }
        Layout.fillWidth: true
        implicitHeight: 28; radius: 8
        color: menu.colSurface0
        border.color: input.activeFocus ? menu.colMauve : "transparent"
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 8; anchors.rightMargin: 8
            verticalAlignment: TextInput.AlignVCenter
            color: menu.colText
            font.family: menu.fontFamily; font.pixelSize: 12
            clip: true
            maximumLength: field.maximumLength
            validator: field.validator
            onAccepted: field.accepted()
            Keys.onEscapePressed: field.cancelled()
        }
        Text {
            visible: input.text === ""
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 8
            text: field.placeholder
            color: menu.colSub
            font.family: menu.fontFamily; font.pixelSize: 12
        }
    }

    // nome com o botão de editar; renameKey identifica qual campo está aberto
    component NameRow: ColumnLayout {
        id: nameRow
        property string renameKey: ""
        property string value: ""
        readonly property bool editing: menu.renaming === renameKey
        signal saved(string name)
        Layout.fillWidth: true
        spacing: 6
        onEditingChanged: if (editing) { nameField.text = value; Qt.callLater(nameField.focusInput) }
        RowLayout {
            visible: !nameRow.editing
            Layout.fillWidth: true
            spacing: 8
            Text { text: "Nome"; color: menu.colSub; font.family: menu.fontFamily; font.pixelSize: 11 }
            Text {
                text: nameRow.value
                color: menu.colText
                font.family: menu.fontFamily; font.pixelSize: 11
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Btn { label: "󰏫"; onClicked: menu.renaming = nameRow.renameKey }
        }
        RowLayout {
            visible: nameRow.editing
            Layout.fillWidth: true
            spacing: 6
            Field {
                id: nameField
                placeholder: "Nome"
                onAccepted: saveName.clicked()
                onCancelled: menu.renaming = ""
            }
            Btn {
                id: saveName
                primary: true
                label: "Salvar"
                onClicked: {
                    if (nameField.text.trim() !== "") nameRow.saved(nameField.text.trim())
                    menu.renaming = ""
                }
            }
        }
    }

    // cabeçalho com voltar
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Rectangle {
            implicitWidth: 28; implicitHeight: 28; radius: 8
            color: backMouse.containsMouse ? menu.colSurface1 : menu.colSurface0
            Text { anchors.centerIn: parent; text: "󰁍"; color: menu.colText; font.family: menu.fontFamily; font.pixelSize: 14 }
            MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menu.back() }
        }
        Text {
            text: "Bluetooth"
            color: menu.colText
            font.family: menu.fontFamily; font.pixelSize: 14; font.bold: true
        }
    }

    Divider {}

    Text {
        visible: !menu.adapter
        text: "Nenhum adaptador Bluetooth encontrado"
        color: menu.colDanger
        font.family: menu.fontFamily; font.pixelSize: 11
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    // ── Liga e desliga ─────────────────────────────────────
    SwitchRow {
        visible: !!menu.adapter
        title: "Bluetooth"
        subtitle: !menu.manager ? "" : menu.manager.radioBlocked ? "Rádio bloqueado (rfkill): ligar desbloqueia"
                  : !menu.powered ? "Desligado"
                  : menu.manager.connectedDevices.length > 0 ? menu.manager.connectedDevices.length + (menu.manager.connectedDevices.length === 1 ? " aparelho conectado" : " aparelhos conectados")
                  : "Ligado"
        checked: menu.powered
        onToggled: menu.manager.setEnabled(!menu.powered)
    }

    // ── Pedido de pareamento ───────────────────────────────
    Rectangle {
        visible: !!menu.request
        Layout.fillWidth: true
        implicitHeight: requestCol.implicitHeight + 20
        radius: 12
        color: menu.colTile
        border.color: menu.colMauve
        ColumnLayout {
            id: requestCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 10
            spacing: 8
            Text {
                text: menu.request ? (menu.request.name || menu.request.address) : ""
                color: menu.colText
                font.family: menu.fontFamily; font.pixelSize: 12; font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: !menu.request ? ""
                      : menu.request.kind === "confirm" ? "Confira se este código aparece nos dois aparelhos:"
                      : menu.request.kind === "authorize" ? "Quer parear com este aparelho?"
                      : menu.request.kind === "service" ? "Quer permitir: " + menu.serviceLabel(menu.request.service) + "?"
                      : menu.request.kind === "pin" ? "Digite o PIN deste aparelho:"
                      : "Digite o código mostrado no aparelho:"
                color: menu.colSub
                font.family: menu.fontFamily; font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                visible: !!menu.request && menu.request.kind === "confirm"
                text: menu.request && menu.request.code ? menu.request.code : ""
                color: menu.colMauve
                font.family: menu.fontFamily; font.pixelSize: 20; font.bold: true; font.letterSpacing: 2
                Layout.alignment: Qt.AlignHCenter
            }
            Field {
                id: codeField
                visible: menu.typingCode
                placeholder: menu.request && menu.request.kind === "pin" ? "PIN" : "Código"
                maximumLength: menu.request && menu.request.kind === "pin" ? 16 : 6
                validator: menu.request && menu.request.kind === "passkey" ? passkeyValidator : null
                onVisibleChanged: if (visible) { text = ""; Qt.callLater(focusInput) }
                onAccepted: acceptRequest.clicked()
                onCancelled: menu.manager.answer(false, "")
                IntValidator { id: passkeyValidator; bottom: 0; top: 999999 }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Item { Layout.fillWidth: true }
                Btn { label: "Recusar"; onClicked: menu.manager.answer(false, "") }
                Btn {
                    id: acceptRequest
                    primary: true
                    active: !menu.typingCode || codeField.text !== ""
                    label: menu.request && menu.request.kind === "confirm" ? "Confirmar" : menu.typingCode ? "Enviar" : "Permitir"
                    onClicked: { if (active) menu.manager.answer(true, codeField.text) }
                }
            }
        }
    }

    // código para digitar no outro aparelho
    Rectangle {
        visible: !!menu.manager && !!menu.manager.display
        Layout.fillWidth: true
        implicitHeight: displayCol.implicitHeight + 20
        radius: 12
        color: menu.colTile
        border.color: menu.colMauve
        ColumnLayout {
            id: displayCol
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 10
            spacing: 6
            Text {
                text: menu.manager && menu.manager.display ? "Digite este código em " + (menu.manager.display.name || menu.manager.display.address) + ":" : ""
                color: menu.colSub
                font.family: menu.fontFamily; font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
            Text {
                text: menu.manager && menu.manager.display ? menu.manager.display.code : ""
                color: menu.colMauve
                font.family: menu.fontFamily; font.pixelSize: 20; font.bold: true; font.letterSpacing: 2
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // ── Opções do adaptador ────────────────────────────────
    ColumnLayout {
        visible: menu.powered
        Layout.fillWidth: true
        spacing: 10
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 28; radius: 8
            color: adapterMouse.containsMouse ? menu.colSurface0 : "transparent"
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Label { text: "ESTE COMPUTADOR"; Layout.fillWidth: true; Layout.leftMargin: 4 }
                Text {
                    text: menu.adapter ? menu.adapter.name : ""
                    color: menu.colSub
                    font.family: menu.fontFamily; font.pixelSize: 11
                }
                Text {
                    text: menu.adapterOpen ? "󰅀" : "󰅂"
                    color: menu.colText
                    font.family: menu.fontFamily; font.pixelSize: 14
                    Layout.rightMargin: 4
                }
            }
            MouseArea {
                id: adapterMouse
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menu.adapterOpen = !menu.adapterOpen
            }
        }
        ColumnLayout {
            visible: menu.adapterOpen
            Layout.fillWidth: true
            spacing: 10
            // só com mais de um adaptador
            RowLayout {
                visible: !!menu.manager && menu.manager.adapters.length > 1
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: menu.manager ? menu.manager.adapters : []
                    Btn {
                        required property var modelData
                        Layout.fillWidth: true
                        label: modelData.adapterId
                        primary: menu.adapter === modelData
                        onClicked: menu.manager.adapterPath = modelData.dbusPath
                    }
                }
            }
            NameRow {
                renameKey: "adapter"
                value: menu.adapter ? menu.adapter.name : ""
                onSaved: name => menu.manager.renameAdapter(name)
            }
            Info { label: "Adaptador"; value: menu.adapter ? menu.adapter.adapterId : "" }
            SwitchRow {
                title: "Visível"
                subtitle: "Outros aparelhos encontram este computador"
                checked: !!menu.adapter && menu.adapter.discoverable
                onToggled: menu.adapter.discoverable = !menu.adapter.discoverable
            }
            TimeoutChips {
                value: menu.adapter ? menu.adapter.discoverableTimeout : 0
                onPicked: seconds => menu.adapter.discoverableTimeout = seconds
            }
            SwitchRow {
                title: "Aceitar pareamento"
                subtitle: "Outros aparelhos podem pedir para parear"
                checked: !!menu.adapter && menu.adapter.pairable
                onToggled: menu.adapter.pairable = !menu.adapter.pairable
            }
            TimeoutChips {
                value: menu.adapter ? menu.adapter.pairableTimeout : 0
                onPicked: seconds => menu.adapter.pairableTimeout = seconds
            }
            Text {
                visible: !!menu.manager && !menu.manager.agentReady
                text: "O agente de pareamento não está rodando: aparelhos que pedem código não vão parear."
                color: menu.colDanger
                font.family: menu.fontFamily; font.pixelSize: 10
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    Divider { visible: menu.powered }

    // ── Aparelhos ──────────────────────────────────────────
    RowLayout {
        visible: menu.powered
        Layout.fillWidth: true
        spacing: 8
        Label { text: "APARELHOS"; Layout.fillWidth: true }
        Btn {
            label: menu.manager && menu.manager.scanning ? "Procurando… parar" : "Procurar"
            onClicked: menu.manager.setScan(!menu.manager.scanning)
        }
    }

    Text {
        visible: menu.powered && !!menu.manager && menu.manager.visibleDevices.length === 0
        text: menu.manager && menu.manager.scanning ? "Procurando aparelhos…" : "Nenhum aparelho"
        color: menu.colSub
        font.family: menu.fontFamily; font.pixelSize: 11
    }

    Flickable {
        id: deviceFlick
        visible: menu.powered && !!menu.manager && menu.manager.visibleDevices.length > 0
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 400)
        contentWidth: width
        contentHeight: deviceList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: deviceList
            width: deviceFlick.width
            spacing: 2
            Repeater {
                // ScriptModel mantém os itens ao reordenar: um aparelho novo na busca não apaga o que está sendo digitado
                model: ScriptModel { values: menu.manager ? menu.manager.visibleDevices : [] }
                ColumnLayout {
                    id: row
                    required property var modelData
                    readonly property bool open: menu.manager.expanded === modelData.address
                    readonly property var card: open && modelData.connected ? menu.manager.cardFor(modelData.address) : null
                    property bool confirmingForget: false
                    Layout.fillWidth: true
                    spacing: 4
                    onOpenChanged: confirmingForget = false

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34; radius: 8
                        color: rowMouse.containsMouse || row.open ? menu.colSurface0 : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8; anchors.rightMargin: 8
                            spacing: 8
                            Text {
                                text: menu.iconFor(row.modelData.icon)
                                color: row.modelData.connected ? menu.colMauve : menu.colText
                                font.family: menu.fontFamily; font.pixelSize: 15
                            }
                            Text {
                                text: row.modelData.name
                                color: row.modelData.connected ? menu.colMauve : menu.colText
                                font.family: menu.fontFamily; font.pixelSize: 12; font.bold: row.modelData.connected
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: menu.statusOf(row.modelData)
                                color: row.modelData.blocked ? menu.colDanger : menu.colSub
                                font.family: menu.fontFamily; font.pixelSize: 10
                            }
                            Text {
                                text: row.open ? "󰅀" : "󰅂"
                                color: menu.colSub
                                font.family: menu.fontFamily; font.pixelSize: 13
                            }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: menu.manager.expanded = row.open ? "" : row.modelData.address
                        }
                    }

                    // opções do aparelho
                    ColumnLayout {
                        visible: row.open
                        Layout.fillWidth: true
                        Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.bottomMargin: 8; Layout.topMargin: 4
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Btn {
                                visible: row.modelData.paired && !row.modelData.connected
                                primary: true
                                active: !row.modelData.blocked && row.modelData.state === BluetoothDeviceState.Disconnected
                                label: row.modelData.state === BluetoothDeviceState.Connecting ? "Conectando…" : "Conectar"
                                onClicked: menu.manager.connectDevice(row.modelData)
                            }
                            Btn {
                                visible: row.modelData.connected
                                label: "Desconectar"
                                onClicked: menu.manager.disconnectDevice(row.modelData)
                            }
                            Btn {
                                visible: !row.modelData.paired && !row.modelData.pairing
                                primary: true
                                active: !row.modelData.blocked
                                label: "Parear"
                                onClicked: menu.manager.pair(row.modelData)
                            }
                            Btn {
                                visible: row.modelData.pairing
                                label: "Cancelar pareamento"
                                onClicked: row.modelData.cancelPair()
                            }
                            Item { Layout.fillWidth: true }
                            Btn {
                                visible: row.modelData.paired || row.modelData.trusted || row.modelData.blocked
                                danger: row.confirmingForget
                                label: row.confirmingForget ? "Confirmar" : "Esquecer"
                                onClicked: {
                                    if (row.confirmingForget) menu.manager.forget(row.modelData)
                                    else row.confirmingForget = true
                                }
                            }
                        }

                        NameRow {
                            renameKey: row.modelData.address
                            value: row.modelData.name
                            onSaved: name => row.modelData.name = name
                        }
                        Info { label: "Nome original"; value: row.modelData.deviceName !== row.modelData.name ? row.modelData.deviceName : "" }
                        Info { label: "Endereço"; value: row.modelData.address }
                        Info { label: "Tipo"; value: menu.manager.typeLabel(row.modelData.icon) }
                        Info { label: "Bateria"; value: row.modelData.batteryAvailable ? Math.round(row.modelData.battery * 100) + "%" : "" }

                        SwitchRow {
                            title: "Confiável"
                            subtitle: "Conecta sem pedir permissão"
                            checked: row.modelData.trusted
                            onToggled: row.modelData.trusted = !row.modelData.trusted
                        }
                        SwitchRow {
                            title: "Bloqueado"
                            subtitle: "Recusa conexões deste aparelho"
                            checked: row.modelData.blocked
                            onToggled: row.modelData.blocked = !row.modelData.blocked
                        }
                        SwitchRow {
                            visible: row.modelData.icon.startsWith("input") || row.modelData.wakeAllowed
                            title: "Acordar o computador"
                            subtitle: "Este aparelho pode tirar o computador da suspensão"
                            checked: row.modelData.wakeAllowed
                            onToggled: row.modelData.wakeAllowed = !row.modelData.wakeAllowed
                        }

                        // perfil de áudio, com o aparelho conectado
                        Label { visible: !!row.card && row.card.profiles.length > 0; text: "PERFIL DE ÁUDIO" }
                        Flow {
                            visible: !!row.card && row.card.profiles.length > 0
                            Layout.fillWidth: true
                            spacing: 4
                            Repeater {
                                model: row.card ? row.card.profiles : []
                                Btn {
                                    required property var modelData
                                    label: modelData.label
                                    primary: row.card && row.card.active === modelData.name
                                    onClicked: menu.manager.setProfile(row.modelData.address, modelData.name)
                                }
                            }
                        }
                    }
                }
            }

            Btn {
                visible: !!menu.manager && (menu.manager.unnamedCount > 0 || menu.manager.showUnnamed)
                Layout.topMargin: 6
                label: menu.manager && menu.manager.showUnnamed ? "Esconder aparelhos sem nome" : "Mostrar " + (menu.manager ? menu.manager.unnamedCount : 0) + " sem nome"
                onClicked: menu.manager.showUnnamed = !menu.manager.showUnnamed
            }
        }
    }

    Text {
        visible: !!menu.manager && menu.manager.message !== ""
        text: menu.manager ? menu.manager.message : ""
        color: menu.colSub
        font.family: menu.fontFamily; font.pixelSize: 10
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
}
