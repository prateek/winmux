"""Guest-only Firefox Marionette driver. The profile is task-owned, never a real profile."""
import json
import socket
import sys


def receive(connection):
    length = b""
    while not length.endswith(b":"):
        length += connection.recv(1)
    remaining = int(length[:-1])
    payload = b""
    while len(payload) < remaining:
        payload += connection.recv(remaining - len(payload))
    return json.loads(payload)


with socket.create_connection(("127.0.0.1", 2828), timeout=30) as connection:
    receive(connection)
    serial = 0

    def command(name, parameters):
        global serial
        serial += 1
        payload = json.dumps([0, serial, name, parameters]).encode()
        connection.sendall(str(len(payload)).encode() + b":" + payload)
        response = receive(connection)
        if response[2]:
            raise RuntimeError(response[2])
        return response[3]

    command("WebDriver:NewSession", {"capabilities": {}})
    try:
        command("Marionette:SetContext", {"value": sys.argv[1]})
        with open(sys.argv[2]) as source:
            script = source.read()
        result = command("WebDriver:ExecuteAsyncScript" if "--async" in sys.argv else "WebDriver:ExecuteScript", {
            "script": script, "args": [], "newSandbox": True,
            "sandbox": "default", "line": 1, "filename": "extension-capture.js",
        })
        print(json.dumps(result, indent=2))
    finally:
        command("WebDriver:DeleteSession", {})
