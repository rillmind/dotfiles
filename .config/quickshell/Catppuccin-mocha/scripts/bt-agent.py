#!/usr/bin/python3
"""Agente de pareamento do BlueZ para o menu de Bluetooth do quickshell.

O BlueZ só consegue parear aparelhos que pedem código se houver um agente registrado, e nesta sessão
(Hyprland) não existe outro. Este processo responde ao BlueZ repassando cada pedido ao
BluetoothManager.qml, que mostra o pedido na tela.

Protocolo, uma mensagem JSON por linha:
  stdout: {"type": "ready"}
          {"type": "request", "id": 1, "kind": "confirm|authorize|service|pin|passkey",
           "name": "...", "address": "...", "code": "123456", "service": "uuid"}
          {"type": "display", "name": "...", "address": "...", "code": "123456"}
          {"type": "cancel"}
  stdin:  {"id": 1, "accept": true, "value": "1234"}

Aparelho já pareado que reconecta não vira pedido: AuthorizeService é aprovado aqui mesmo, sem abrir o
menu. Aparelho desconhecido continua precisando de resposta.

Fecha sozinho quando o stdin termina, ou seja, quando o quickshell sai.
"""
import json
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

BLUEZ = "org.bluez"
AGENT_PATH = "/org/quickshell/BtAgent"
CAPABILITY = "KeyboardDisplay"
INTROSPECTION = """
<node><interface name="org.bluez.Agent1">
  <method name="Release"/>
  <method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
  <method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
  <method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
  <method name="DisplayPasskey">
    <arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/>
  </method>
  <method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
  <method name="RequestAuthorization"><arg type="o" direction="in"/></method>
  <method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
  <method name="Cancel"/>
</interface></node>
"""


def emit(message):
    print(json.dumps(message), flush=True)


class Agent:
    def __init__(self, loop):
        self.loop = loop
        self.bus = Gio.bus_get_sync(Gio.BusType.SYSTEM)
        self.pending = {}  # id -> (invocation, kind)
        self.next_id = 1
        node = Gio.DBusNodeInfo.new_for_xml(INTROSPECTION)
        self.bus.register_object(AGENT_PATH, node.interfaces[0], self.on_call)
        # registra de novo sempre que o bluetoothd (re)aparece no barramento
        Gio.bus_watch_name_on_connection(self.bus, BLUEZ, Gio.BusNameWatcherFlags.NONE, self.on_bluez, None)

    def on_bluez(self, _bus, _name, _owner):
        self.manager_call("RegisterAgent", GLib.Variant("(os)", (AGENT_PATH, CAPABILITY)))
        self.manager_call("RequestDefaultAgent", GLib.Variant("(o)", (AGENT_PATH,)))
        emit({"type": "ready"})

    def manager_call(self, method, args):
        try:
            self.bus.call_sync(BLUEZ, "/org/bluez", "org.bluez.AgentManager1", method, args, None,
                               Gio.DBusCallFlags.NONE, -1, None)
        except GLib.Error as error:
            # já registrado depois de um reinício do agente: não é problema
            if "AlreadyExists" not in error.message:
                print(f"bt-agent: {method}: {error.message}", file=sys.stderr, flush=True)

    def device_info(self, path):
        try:
            result = self.bus.call_sync(BLUEZ, path, "org.freedesktop.DBus.Properties", "GetAll",
                                        GLib.Variant("(s)", ("org.bluez.Device1",)), None,
                                        Gio.DBusCallFlags.NONE, 2000, None)
            props = result.unpack()[0]
            return {"name": props.get("Alias", ""), "address": props.get("Address", ""), "paired": props.get("Paired", False)}
        except GLib.Error:
            return {"name": "", "address": "", "paired": False}

    def ask(self, invocation, kind, device, **extra):
        request_id = self.next_id
        self.next_id += 1
        self.pending[request_id] = (invocation, kind)
        emit({"type": "request", "id": request_id, "kind": kind, **self.device_info(device), **extra})

    def on_call(self, _bus, _sender, _path, _iface, method, params, invocation):
        args = params.unpack()
        if method == "RequestConfirmation":
            self.ask(invocation, "confirm", args[0], code=f"{args[1]:06d}")
        elif method == "RequestAuthorization":
            self.ask(invocation, "authorize", args[0])
        elif method == "AuthorizeService":
            if self.device_info(args[0])["paired"]:
                invocation.return_value(None)
            else:
                self.ask(invocation, "service", args[0], service=args[1])
        elif method == "RequestPinCode":
            self.ask(invocation, "pin", args[0])
        elif method == "RequestPasskey":
            self.ask(invocation, "passkey", args[0])
        elif method == "DisplayPinCode":
            emit({"type": "display", **self.device_info(args[0]), "code": args[1]})
            invocation.return_value(None)
        elif method == "DisplayPasskey":
            emit({"type": "display", **self.device_info(args[0]), "code": f"{args[1]:06d}"})
            invocation.return_value(None)
        elif method == "Cancel":
            for pending, _kind in self.pending.values():
                pending.return_dbus_error("org.bluez.Error.Canceled", "Cancelado")
            self.pending.clear()
            emit({"type": "cancel"})
            invocation.return_value(None)
        else:  # Release
            invocation.return_value(None)

    def answer(self, line):
        try:
            message = json.loads(line)
            invocation, kind = self.pending.pop(message["id"])
        except (ValueError, KeyError, TypeError):
            return
        if not message.get("accept"):
            invocation.return_dbus_error("org.bluez.Error.Rejected", "Recusado")
            return
        value = str(message.get("value", ""))
        if kind == "pin":
            if 1 <= len(value) <= 16:
                invocation.return_value(GLib.Variant("(s)", (value,)))
            else:
                invocation.return_dbus_error("org.bluez.Error.Rejected", "PIN inválido")
        elif kind == "passkey":
            if value.isdigit() and int(value) <= 999999:
                invocation.return_value(GLib.Variant("(u)", (int(value),)))
            else:
                invocation.return_dbus_error("org.bluez.Error.Rejected", "Código inválido")
        else:
            invocation.return_value(None)

    def on_stdin(self, channel, condition):
        if condition & GLib.IO_IN:
            status, line, _length, _end = channel.read_line()
            if status == GLib.IOStatus.NORMAL:
                self.answer(line)
                return True
            if status == GLib.IOStatus.AGAIN:
                return True
        self.loop.quit()
        return False


def main():
    loop = GLib.MainLoop()
    agent = Agent(loop)
    channel = GLib.IOChannel.unix_new(sys.stdin.fileno())
    GLib.io_add_watch(channel, GLib.PRIORITY_DEFAULT, GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, agent.on_stdin)
    try:
        loop.run()
    finally:
        agent.manager_call("UnregisterAgent", GLib.Variant("(o)", (AGENT_PATH,)))


if __name__ == "__main__":
    main()
