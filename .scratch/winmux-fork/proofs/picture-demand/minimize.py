#!/usr/bin/env python3
import time
import run
app = run.start('branch', 'final-minimize')
run.prompts()
(run.OUT/'minimize-query.json').unlink(missing_ok=True)
run.cli('agent', 'query', '--path', str(run.OUT/'minimize-query.json'))
time.sleep(3)
run.focus_all(['Window 01', 'Window 02', 'Window 03'])
time.sleep(5)
run.cli('lens', 'windows')
time.sleep(6)
run.screenshot('minimize-before')
run.keys('tap:escape', 'wait:1')
time.sleep(3)
run.raise_stage('Window 01')
time.sleep(2)
run.cli('macos-native-minimize')
time.sleep(3)
run.screenshot('minimize-after')
(run.OUT/'minimize-after.txt').write_text(run.cli('list-windows', '--all')+'\n'+run.cli('debug-lens-trace','--last','1'))
result=run.call([run.HOME/'proof94/native-minimize'],capture_output=True,text=True).stdout
assert 'true' in result,result
(run.OUT/'minimize-native-after.txt').write_text(result)
run.call([run.HOME/'proof94/native-minimize','--restore'])
time.sleep(3)
run.screenshot('minimize-restored')
result=run.call([run.HOME/'proof94/native-minimize'],capture_output=True,text=True).stdout
assert 'false' in result,result
(run.OUT/'minimize-native-restored.txt').write_text(result)
(run.OUT/'minimize-restored.txt').write_text(run.cli('list-windows','--all')+'\n'+run.cli('list-windows','--focused'))
run.stop()
