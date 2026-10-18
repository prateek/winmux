"""Run unchanged socket routes against either running tree; no third-party packages."""
import getpass
import json
import socket
import struct


def receive(connection, size):
    data = b""
    while len(data) < size:
        chunk = connection.recv(size - len(data))
        assert chunk, "server closed before its response"
        data += chunk
    return data


def request(connection, args, incomplete=False):
    fields = dict(args=args, stdin="")
    if not incomplete:
        fields.update(windowId=None, workspace=None)
    payload = json.dumps(fields).encode()
    connection.sendall(struct.pack("=I", len(payload)) + payload)
    size, = struct.unpack("=I", receive(connection, 4))
    result = json.loads(receive(connection, size))
    result.pop("serverVersionAndHash")
    print(json.dumps(dict(args=args, incomplete=incomplete, answer=result), sort_keys=True))
    return result


with socket.socket(socket.AF_UNIX) as connection:
    connection.settimeout(10)
    connection.connect("/tmp/com.zimengxiong.winmux.debug-" + getpass.getuser() + ".sock")
    for args, code in [(["workspace", "--help"], 0), (["sections", "bad"], 2),
                       (["subscribe", "--help"], 0), (["subscribe", "--bad"], 1),
                       (["mode", "main"], 0)]:
        assert request(connection, args)["exitCode"] == code
    result = request(connection, ["mode", "main"], incomplete=True)
    assert result["exitCode"] == 0 and "incomplete JSON request" in result["stderr"]
    assert request(connection, ["enable", "off"])["exitCode"] == 0
    for args in [["workspace", "--help"], ["unknown"], ["workspace", "2"]]:
        result = request(connection, args)
        assert result["exitCode"] == 1 and "server is disabled" in result["stderr"]
    assert request(connection, ["enable", "on"])["exitCode"] == 0
