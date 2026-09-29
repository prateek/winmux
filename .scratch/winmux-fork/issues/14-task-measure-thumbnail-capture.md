# Task: measure thumbnail capture on Prateek's machine

Type: task
Status: open

## Question

Is capture-at-park-time good enough for grid thumbnails? With Prateek's real window set (about 50 windows), measure ScreenCaptureKit one-shot capture latency, cold and warm. Check whether Chrome, Electron apps and Safari keep painting a parked (off-screen) window once its one visible pixel is covered, or whether their captured content goes stale or blank. A small throwaway Swift harness is enough; the agent can drive it (AFK), and Prateek only needs to grant Screen Recording.
