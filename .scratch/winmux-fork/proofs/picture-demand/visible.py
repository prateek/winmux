#!/usr/bin/env python3
import json, pathlib, sys, time
import run
build = sys.argv[1]
label = build+'-text'
app=run.start(build,label)
run.call(['open','-a','TextEdit',run.HOME/'proof94/Reading.txt'])
time.sleep(3)
run.call([run.HOME/'proof94/resize-text'])
time.sleep(2)
run.cli('agent','query','--path',str(run.OUT/(label+'-query.json')))
time.sleep(3)
windows=run.cli('list-windows','--all','--json')
(run.OUT/(label+'-windows.json')).write_text(windows)
print(windows,flush=True)
run.focus_all(['Window 01','Window 02'],text=True)
time.sleep(5)
run.prompts()
pathlib.Path('/tmp/stage/command').write_text('raise Window 02\n')
time.sleep(1)
run.cli('lens','windows')
time.sleep(6)
run.screenshot(label+'-grid')
(run.OUT/(label+'-trace.json')).write_text(run.cli('debug-lens-trace','--json','--last','1'))
run.keys('tap:escape','wait:1')
time.sleep(3)
(run.OUT/(label+'-end.txt')).write_text(run.cli('debug-lens-trace','--last','1')+'\n'+run.cli('list-windows','--all'))
run.screenshot(label+'-closed')
run.stop()
