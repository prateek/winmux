from pathlib import Path
p = Path.home()/'winmux-base/Sources/AppBundle/lens/ThumbnailCache.swift'
s = p.read_text()
s = s.replace('lensLog.debug("thumbnail start id=\\(id) in-flight=\\(self.gate.inFlight)")', 'lensLog.debug("thumbnail start id=\\(id) frame=\\(String(describing: frame), privacy: .public) demand=none size=\\(String(describing: size), privacy: .public) in-flight=\\(self.gate.inFlight)")')
s = s.replace('if image != nil { statistics?.completedCapture() }',
    'if let image { lensLog.debug("thumbnail captured id=\\(id) pixels=\\(image.width)x\\(image.height)"); statistics?.completedCapture() }')
p.write_text(s)
