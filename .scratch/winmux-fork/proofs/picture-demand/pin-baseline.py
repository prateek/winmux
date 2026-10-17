from pathlib import Path
root=Path.home()
source=(root/'winmux/Sources/AppBundleTests/ThumbnailCaptureTest.swift').read_text()
name='    func testNoDemandKeepsTodaysCaptureSizeOutsideALens()'
start=source.index(name)
end=source.index('\n    func ',start+len(name))
method=source[start:end]
p=root/'winmux-base/Sources/AppBundleTests/ThumbnailCaptureTest.swift'
s=p.read_text()
if name not in s:
    s=s.replace('    func testSessionCounters',method+'\n\n    func testSessionCounters',1)
p.write_text(s)
