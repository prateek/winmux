# Task: gesture probe on Prateek's Mac

Type: task
Status: open

## Question

A throwaway MultitouchSupport probe on Prateek's macOS 26.5 Mac should settle four facts before WinMux commits to in-app gestures. First, do contact frames arrive with Accessibility permission alone, or is Input Monitoring also needed? Second, does dropping DockSwipe events in a session tap stop the horizontal Space swipe, and does it stop vertical Mission Control and App Exposé? Third, what are the frame interval and the touch-to-Trigger latency? Fourth, do `defaults write` changes to the `Trackpad{Three,Four}Finger{Horiz,Vert}SwipeGesture` keys take effect without logging out? The agent builds and runs the probe; Prateek performs the swipes and grants permissions. See the gesture research for prior art (MIT code from aerospace-swipe and OpenMultitouchSupport is reusable).
