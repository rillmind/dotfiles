import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "."

// Notifications.qml – servidor de notificações (substitui o dunst) + popups no canto superior direito.
// O histórico fica em ~/.local/state/quickshell/notificacoes.json (comum aos temas) e aparece na
// central (NotificationCenter.qml). "Não perturbe" segura os popups, menos os críticos.
// Mesmo arquivo nos dois temas: as cores vêm do Theme.qml de cada um.
// IPC: tema.sh ipc notificacoes <naoPerturbe|limpar|central>
Scope {
    id: svc

    // posição dos popups (cada tema ajusta no shell.qml)
    property int topMargin: 8
    property int rightMargin: 8
    readonly property int popupWidth: 380
    readonly property int maxHistory: 50

    property bool centerOpen: false
    property int unread: 0
    onCenterOpenChanged: if (centerOpen) unread = 0
    signal centerToggleRequested()

    // ── Não perturbe (salvo) ───────────────────────────────
    property bool dnd: false
    function setDnd(on) { dnd = on; dndFile.setText(on ? "1" : "0") }
    FileView {
        id: dndFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/nao-perturbe"
        printErrors: false
        onLoaded: svc.dnd = text().trim() === "1"
    }

    IpcHandler {
        target: "notificacoes"
        function naoPerturbe(): void { svc.setDnd(!svc.dnd) }
        function limpar(): void { svc.clearAll() }
        function central(): void { svc.centerToggleRequested() }
    }

    // ── Notificações vivas ─────────────────────────────────
    // chave própria (a numeração do servidor recomeça a cada início e colidiria com o histórico salvo)
    property var live: ({})          // chave → Notification
    property int liveRev: 0          // muda quando `live` muda (o objeto em si não avisa)
    function liveFor(key) { return liveRev >= 0 ? (live[key] || null) : null }
    property int _seq: 0

    ListModel { id: popupModel }      // { key }
    ListModel { id: historyModel }    // { key, app, summary, body, icon, image, time, urgency }
    readonly property alias popups: popupModel
    readonly property alias history: historyModel

    function iconFor(n) {
        var i = n.appIcon || ""
        if (i.startsWith("/")) return "file://" + i
        if (i.startsWith("file:") || i.startsWith("image:")) return i
        if (i !== "") { var p = Quickshell.iconPath(i, true); if (p) return p }
        var e = n.desktopEntry ? DesktopEntries.byId(n.desktopEntry) : null
        if (!e && n.appName) e = DesktopEntries.heuristicLookup(n.appName)
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : ""
    }
    function imageFor(n) {
        var i = n.image || ""
        return i.startsWith("/") ? "file://" + i : i
    }
    function indexIn(model, key) {
        for (var i = 0; i < model.count; i++) if (model.get(i).key === key) return i
        return -1
    }

    NotificationServer {
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: true

        onNotification: n => {
            n.tracked = true
            var key = Date.now() + "-" + (++svc._seq)
            svc.live[key] = n
            svc.liveRev++
            n.closed.connect(function () {
                delete svc.live[key]
                svc.liveRev++
                var p = svc.indexIn(popupModel, key)
                if (p >= 0) popupModel.remove(p)
            })
            if (!n.transient) {
                historyModel.insert(0, {
                    key: key, app: n.appName || "", summary: n.summary || "", body: n.body || "",
                    icon: svc.iconFor(n), image: svc.imageFor(n), time: Date.now(), urgency: n.urgency
                })
                while (historyModel.count > svc.maxHistory) {
                    var old = historyModel.get(historyModel.count - 1).key
                    if (svc.live[old]) svc.live[old].dismiss()
                    historyModel.remove(historyModel.count - 1)
                }
                svc.saveHistory()
                if (!svc.centerOpen) svc.unread++
            }
            if (!svc.dnd || n.urgency === NotificationUrgency.Critical) popupModel.insert(0, { key: key })
        }
    }

    // ── Ações ──────────────────────────────────────────────
    function hidePopup(key) { var p = indexIn(popupModel, key); if (p >= 0) popupModel.remove(p) }
    // tira de tudo e avisa o app
    function remove(key) {
        var n = live[key]
        hidePopup(key)
        var h = indexIn(historyModel, key)
        if (h >= 0) historyModel.remove(h)
        if (n) n.dismiss()
        saveHistory()
    }
    function clearAll() {
        for (var k in live) live[k].dismiss()
        popupModel.clear()
        historyModel.clear()
        unread = 0
        saveHistory()
    }
    function invoke(key, action) {
        var n = live[key]
        if (!n) return
        action.invoke()
        if (!n.resident) remove(key)
    }
    // clique no corpo: ação padrão, se houver
    function activate(key) {
        var n = live[key]
        if (n) {
            var def = n.actions.find(a => a.identifier === "default")
            if (def) { invoke(key, def); return }
        }
        hidePopup(key)
    }

    // ── Histórico salvo ────────────────────────────────────
    FileView {
        id: historyFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell/notificacoes.json"
        printErrors: false
        onLoaded: {
            try {
                var arr = JSON.parse(text()) || []
                historyModel.clear()
                for (var e of arr) historyModel.append(e)
            } catch (e) {}
        }
    }
    function saveHistory() {
        var arr = []
        for (var i = 0; i < historyModel.count; i++) {
            var e = historyModel.get(i)
            arr.push({ key: e.key, app: e.app, summary: e.summary, body: e.body, icon: e.icon, image: e.image, time: e.time, urgency: e.urgency })
        }
        historyFile.setText(JSON.stringify(arr))
    }

    // tempo relativo ("há 5 min"), atualizado a cada 30 s
    property double now: Date.now()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: svc.now = Date.now() }
    function ago(t) {
        var s = Math.max(0, (now - t) / 1000)
        if (s < 60) return "agora"
        if (s < 3600) return "há " + Math.floor(s / 60) + " min"
        if (s < 86400) return "há " + Math.floor(s / 3600) + " h"
        if (s < 172800) return "ontem"
        return Qt.formatDate(new Date(t), "dd/MM")
    }

    // ── Popups ─────────────────────────────────────────────
    PanelWindow {
        id: win
        visible: popupModel.count > 0
        screen: Quickshell.screens.find(s => Hyprland.focusedMonitor && s.name === Hyprland.focusedMonitor.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: replyFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell-notifications"
        property bool replyFocus: false
        anchors { top: true; right: true }
        margins { top: svc.topMargin; right: svc.rightMargin }
        implicitWidth: svc.popupWidth
        implicitHeight: Math.max(1, list.contentHeight)
        color: "transparent"

        ListView {
            id: list
            anchors.fill: parent
            interactive: false
            spacing: 8
            model: popupModel
            add: Transition {
                NumberAnimation { property: "x"; from: svc.popupWidth; to: 0; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 180 }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 150 }
            }
            // garante opacidade 1 se a entrada foi interrompida por outra notificação chegando
            displaced: Transition {
                NumberAnimation { property: "y"; duration: 180; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; to: 1; duration: 120 }
                NumberAnimation { property: "x"; to: 0; duration: 120 }
            }

            delegate: NotificationCard {
                required property string key
                width: svc.popupWidth
                service: svc
                notifKey: key
                popup: true
                onReplyFocusChanged: win.replyFocus = replyFocus
            }
        }
    }
}
