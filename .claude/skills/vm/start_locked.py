"""Carry a process-owned admission lock across exec; forks do not inherit it."""
import fcntl
import os
from pathlib import Path
import sys

home = Path(os.environ['TART_HOME'])
home.mkdir(parents=True, exist_ok=True)
fd = os.open(home / '.winmux-start.lock', os.O_CREAT | os.O_RDWR, 0o600)
if fd != 9:
    os.dup2(fd, 9)
    os.close(fd)
fcntl.lockf(9, fcntl.LOCK_EX)
os.set_inheritable(9, True)
os.execv('/bin/bash', ['bash', sys.argv[1], '--start-locked', *sys.argv[2:]])
