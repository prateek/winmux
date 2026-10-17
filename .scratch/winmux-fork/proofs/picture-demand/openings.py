#!/usr/bin/env python3
import json, pathlib, sys, time
import run
build, trial = sys.argv[1:]
label = f'{build}-opening-{trial}'
run.stop()
run.raise_stage('Window 02')
time.sleep(.3)
run.raise_stage('Window 03')
time.sleep(.5)
app = run.start(build, label)
(run.OUT/(label+'-process.json')).write_text(json.dumps({'pid':app.pid,'build':build,'trial':trial}))
run.cli('agent','query','--path',str(run.OUT/(label+'-query.json')))
time.sleep(3)
run.prompts()
run.screenshot(label+'-idle')
steps = []
for index in range(5):
    steps += ['down:alt','tap:g','up:alt','wait:1','tap:escape','wait:1']
run.call([run.HOME/'desk/trace-film', label, '16', *steps])
run.prompts()
(run.OUT/(label+'.json')).write_text(run.cli('debug-lens-trace','--json','--last','5'))
(run.OUT/(label+'-end.txt')).write_text(run.cli('debug-lens-trace','--last','1')+'\n'+run.cli('list-windows','--all')+'\n'+run.cli('list-windows','--focused')+'\n'+run.cli('list-workspaces','--focused'))
run.screenshot(label+'-closed')
run.stop()
