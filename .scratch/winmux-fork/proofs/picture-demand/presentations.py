#!/usr/bin/env python3
import json, pathlib, time
import run
app=run.start('branch','presentations')
run.cli('agent','query','--path',str(run.OUT/'presentations-query.json'))
time.sleep(3)
run.focus_all(['Window 01','Window 02'],text=True)
time.sleep(5)
for presentation, command in [('list',['lens','windows','--presentation','list','--tile','picture']),
                               ('miniatures',['lens','overview'])]:
    run.prompts()
    run.cli(*command)
    time.sleep(6)
    run.screenshot('branch-'+presentation)
    trace=run.cli('debug-lens-trace','--json','--last','1')
    (run.OUT/(presentation+'-trace.json')).write_text(trace)
    # Lists start in Search, whose first Escape only ends Search.
    run.keys('tap:escape','wait:.3','tap:escape','wait:1')
    time.sleep(3)
    run.screenshot('branch-'+presentation+'-closed')
    (run.OUT/(presentation+'-end.txt')).write_text(run.cli('debug-lens-trace','--last','1')+'\n'+run.cli('list-windows','--all'))
run.focus_all(['Window 02','Window 01'],text=True)
time.sleep(5)
run.screenshot('branch-focus-after-close')
(run.OUT/'focus-after-close.txt').write_text(run.cli('debug-lens-trace','--last','1')+'\n'+run.cli('list-windows','--focused')+'\n'+run.cli('list-workspaces','--focused'))
# Park the full-width controlled window after a small departure capture, then show it Frozen.
windows=json.loads(run.cli('list-windows','--all','--json'))
print(windows,flush=True)
window=next(w for w in windows if w['window-title']=='Window 01')
run.cli('move-node-to-workspace','2','--window-id',str(window['window-id']))
time.sleep(5)
run.cli('lens','windows')
time.sleep(6)
run.screenshot('branch-frozen-before-selection')
(run.OUT/'frozen-trace-before.json').write_text(run.cli('debug-lens-trace','--json','--last','1'))
trace=json.loads(run.cli('debug-lens-trace','--json','--last','1'))
for _ in range(3):
    if trace[0]['session']['selectedId'] == window['window-id']: break
    run.keys('tap:right','wait:1')
    time.sleep(1)
    trace=json.loads(run.cli('debug-lens-trace','--json','--last','1'))
assert trace[0]['session']['selectedId'] == window['window-id'], trace
run.screenshot('branch-frozen')
(run.OUT/'frozen-trace.json').write_text(json.dumps(trace,indent=2))
run.keys('tap:escape','wait:1')
time.sleep(3)
(run.OUT/'frozen-end.txt').write_text(run.cli('debug-lens-trace','--last','1')+'\n'+run.cli('list-windows','--all')+'\n'+run.cli('list-workspaces','--focused'))
run.stop()
