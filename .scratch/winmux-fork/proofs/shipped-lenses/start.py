"""Start only the guest debug build with isolated config and state."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

home = Path.home()
tree = Path(os.environ.get('WINMUX_TREE', home / 'winmux'))
name = sys.argv[1]
root = home / 'demo' / ('issue-66-' + name)
config = root / 'config'
config.mkdir(parents=True, exist_ok=True)
if name != 'fresh':
    target = config / 'winmux'
    target.mkdir(exist_ok=True)
    shutil.copy(home / 'proof-66' / ('pictures.ncl' if name == 'pictures' else 'opt-in.ncl' if name.startswith('opt-in') else 'import-only.ncl'), target / 'winmux.ncl')
subprocess.run(['pkill', '-x', 'WinMuxApp'], check=False)
time.sleep(1)
env = dict(os.environ, XDG_CONFIG_HOME=str(config), XDG_STATE_HOME=str(root / 'state'),
           WINMUX_NICKEL_HELPER=str(tree / 'nickel-helper/target/release/winmux-nickel'))
with (root / 'winmux.log').open('w') as log:
    subprocess.Popen([str(tree / '.build/debug/WinMuxApp')], env=env, stdout=log, stderr=log, stdin=subprocess.DEVNULL, start_new_session=True)
time.sleep(8)
subprocess.run([str(tree / '.build/debug/winmux'), 'config', 'status'], check=True)
# Prime both workspace snapshots before any picture.
for workspace in ['2', '1']:
    subprocess.run([str(tree / '.build/debug/winmux'), 'workspace', workspace], check=True)
    time.sleep(1)
