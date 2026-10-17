#!/usr/bin/env python3
import pathlib, subprocess, sys, time
import run
run.stop()
subprocess.run(['killall','stage'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(2)
count=int(sys.argv[1])
subprocess.Popen([str(run.HOME/'proof94/stage'), *[f'Window {i:02}' for i in range(1,count+1)]],
    stdout=open('/tmp/stage94.log','w'), stderr=subprocess.STDOUT, start_new_session=True)
time.sleep(3)
