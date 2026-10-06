# Open with Prateek: questions and checks that wait on him

Every question the relay cannot settle and every check only Prateek can make is a child of this issue. It is the one list he reads. Closing a child is his answer.

## Child issues

{{CHILDREN}}

## What goes here

- **A question.** A product decision that no issue settles and that the driver did not take under the relay's merge gate, or took and expects to be reversed. One child per question. It states the context, the choices, the driver's recommendation, and which issue builds on the answer.
- **A check.** Something that needs an installed build, a real keyboard, a second display, a real sleep, wake or unlock, or his daily machine. Checks are lines in **Prateek's checks on an installed build and real hardware**, not issues of their own.

## What does not go here

- **A defect.** It is a child of the build umbrella, with a draft, and the relay builds it.
- **A decision the relay made** that the driver does not expect to be reversed. It is listed in its pull request under **Decisions the relay made** and is final unless Prateek says otherwise. It is not carried from brief to brief.

## How it is kept

- The driver's Land step files each new question as a child and adds each new check as a line, before the handoff.
- A handoff brief links this issue and lists nothing from it.
- A build issue that depends on an open question here is labelled `blocked on Prateek` and names the question. The relay skips it.
- Prateek answers on the child. Whoever reads the answer next acts on it: amends a draft, files a build issue, or does nothing, and then closes the child.
- A child's body is its draft in `.scratch/winmux-fork/build/` only when it has one. A question filed by a driver at Land has no draft.
