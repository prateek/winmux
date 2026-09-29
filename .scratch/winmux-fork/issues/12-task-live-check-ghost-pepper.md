# Task: live check of Ghost Pepper's windows under WinMux

Type: task
Status: open

## Question

With WinMux running, what does it actually see of Ghost Pepper (`com.github.matthartman.ghostpepper`)? Before and after clicking its menu-bar item, capture `winmux debug-windows` and `winmux list-windows --all`. Record whether its window is registered only after the app has been frontmost, and its subrole, window level, close-button presence and WinMux classification. This is HITL where it needs Prateek to open Ghost Pepper's window. It confirms or refutes the 'registered only after frontmost' claim before the defaults for floating and Accessory app windows are decided.
