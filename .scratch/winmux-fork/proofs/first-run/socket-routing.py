"""Exercise server routing that the normal CLI parses locally."""
import os
import json
import socket
import struct
import subprocess


def socket_path():
    if 'CS_DARWIN_USER_TEMP_DIR' in os.confstr_names:
        base = os.confstr('CS_DARWIN_USER_TEMP_DIR')
    else:
        base = subprocess.check_output(['getconf', 'DARWIN_USER_TEMP_DIR'], text=True).strip()
    if not base:
        raise RuntimeError('DARWIN_USER_TEMP_DIR returned no directory')
    return os.path.join(base, 'com.zimengxiong.winmux.debug', 'winmux.sock')


def receive(connection, count):
    data = b""
    while len(data) < count:
        chunk = connection.recv(count - len(data))
        if not chunk:
            raise RuntimeError("server closed before its response")
        data += chunk
    return data


for arguments in [[], ["workspace", "--help"], ["workspace", "--bad-flag"],
                  ["subscribe", "--help"], ["subscribe", "--bad-flag"],
                  ["subscribe", "--all"]]:
    with socket.socket(socket.AF_UNIX) as connection:
        connection.settimeout(5)
        connection.connect(socket_path())
        payload = json.dumps(dict(args=arguments, stdin="", windowId=None, workspace=None)).encode()
        connection.sendall(struct.pack("=I", len(payload)) + payload)
        size, = struct.unpack("=I", receive(connection, 4))
        answer = json.loads(receive(connection, size))
        print("REQUEST", json.dumps(arguments))
        print(json.dumps(answer, indent=2))
        assert answer["serverVersionAndHash"]
        if "--help" in arguments:
            assert answer["exitCode"] == 0 and "USAGE" in answer["stdout"]
        elif "--bad-flag" in arguments:
            assert answer["exitCode"] != 0 and "waiting" not in answer["stderr"]
        elif arguments:
            assert answer["exitCode"] == 1 and "waiting" in answer["stderr"]
