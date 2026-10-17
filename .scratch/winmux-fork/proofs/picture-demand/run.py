#!/usr/bin/env python3
"""Same guest-side driver for the base and demand-sized builds."""
import json, os, pathlib, subprocess, sys, time
HOME = pathlib.Path.home()
OUT = HOME / 'takes'
ENV = dict(os.environ, PATH='/opt/homebrew/bin:' + os.environ['PATH'])

def call(args, **kw):
    return subprocess.run([str(a) for a in args], check=True, env=ENV, **kw)

def cli(*args):
    return call([HOME/'winmux/.build/debug/winmux', *args], capture_output=True, text=True).stdout

def keys(*steps):
    call([HOME/'desk/keys', str(time.time()), '/tmp/proof94-events.json', *steps], stdout=subprocess.DEVNULL)

def screenshot(name):
    call(['screencapture', '-x', OUT/(name+'.png')])

def stop():
    subprocess.run(['killall', 'WinMuxApp'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2)

def start(build, label):
    stop()
    tree = HOME / ('winmux-base' if build == 'base' else 'winmux')
    env = dict(ENV, XDG_CONFIG_HOME=str(HOME/'demo/94/config'), XDG_STATE_HOME=str(HOME/'demo/94/state'/label),
               WINMUX_NICKEL_HELPER=str(tree/'nickel-helper/target/release/winmux-nickel'))
    log = open(OUT/(label+'-app.log'), 'w')
    app = subprocess.Popen([str(tree/'.build/debug/WinMuxApp'), '--config-path', str(HOME/'proof94/winmux.ncl')], env=env, stdout=log, stderr=subprocess.STDOUT)
    time.sleep(8)
    if app.poll() is not None:
        raise RuntimeError('WinMux exited: '+(OUT/(label+'-app.log')).read_text()[-3000:])
    return app

def footprint(pid, path):
    result = call(['vmmap', '--summary', str(pid)], capture_output=True, text=True).stdout
    path.write_text(result)
    print(path.name, [line.strip() for line in result.splitlines() if 'Physical footprint' in line], flush=True)

def prompts():
    result = subprocess.run(['pgrep', '-x', 'UserNotificationCenter'], capture_output=True)
    if result.returncode == 0:
        screenshot('unexpected-prompt')
        raise RuntimeError('UserNotificationCenter visible: inspect before continuing')

stage_sequence = 0

def raise_stage(name):
    global stage_sequence
    stage_sequence += 1
    # Stage coalesces identical raw commands, so repeated raises need distinct trailing whitespace.
    pathlib.Path('/tmp/stage/command').write_text('raise '+name+'\n'*stage_sequence)

def focus_all(names, text=False):
    for name in names + names[:1]:
        raise_stage(name)
        time.sleep(.4)
    if text:
        call(['open', '-a', 'TextEdit'])
        time.sleep(1)
        raise_stage(names[0])
        time.sleep(1)

if __name__ == '__main__':
    build, scenario, run = sys.argv[1:]
    label = f'{build}-{scenario}-{run}'
    count = int(scenario)
    names = [f'Window {i:02}' for i in range(1, count+1)]
    app = start(build, label)
    phases = {'pid': app.pid, 'start': time.time()}
    # Floating snapshots can otherwise use the 800-by-600 fallback frame.
    cli('agent', 'query', '--path', str(OUT/(label+'-query.json')))
    time.sleep(3)
    prompts()
    focus_all(names)
    time.sleep(5)
    screenshot(label+'-outside')
    footprint(app.pid, OUT/(label+'-outside-memory.txt'))
    phases['gridStart'] = time.time()
    cli('lens', 'windows')
    time.sleep(8)
    prompts()
    screenshot(label+'-grid')
    footprint(app.pid, OUT/(label+'-grid-memory.txt'))
    (OUT/(label+'-trace.json')).write_text(cli('debug-lens-trace', '--json', '--last', '1'))
    phases['gridEnd'] = time.time()
    keys('tap:escape')
    time.sleep(5)
    screenshot(label+'-closed')
    footprint(app.pid, OUT/(label+'-closed-memory.txt'))
    phases['end'] = time.time()
    (OUT/(label+'-phases.json')).write_text(json.dumps(phases, indent=2))
    (OUT/(label+'-end.txt')).write_text(cli('debug-lens-trace','--last','1')+'\n'+cli('list-windows','--all')+'\n'+cli('list-windows','--focused')+'\n'+cli('list-workspaces','--focused'))
    stop()
