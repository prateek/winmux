"""Shared Notes body for staging and striking; no separate strike state to get stale."""
import html
from html.parser import HTMLParser
from pathlib import Path
import subprocess
import sys


class Strikes(HTMLParser):
    def __init__(self):
        super().__init__()
        self.stack = []
        self.text = []

    def handle_starttag(self, tag, attrs):
        marked = tag in ('strike', 's', 'del') or 'line-through' in (dict(attrs).get('style') or '')
        self.stack.append((tag, marked))

    def handle_endtag(self, tag):
        for i in range(len(self.stack) - 1, -1, -1):
            if self.stack[i][0] == tag:
                del self.stack[i:]
                break

    def handle_data(self, data):
        if any(marked for _, marked in self.stack):
            self.text.append(data)


def note_body(lines, action, previous):
    strikes = Strikes()
    strikes.feed(previous)
    struck_text = ''.join(strikes.text)
    parts = ['<h1>Grievances</h1>']
    for n, line in enumerate(lines, 1):
        text = html.escape(line)
        if action != 'reset' and (str(n) == action or line in struck_text):
            text = '<strike>' + text + '</strike>'
        if n > 1:
            parts.append('<div><br></div>')
        parts.append('<div>' + text + '</div>')
    return ''.join(parts)


def notes(script, *args):
    return subprocess.run(['osascript', '-e', script, *args], check=True,
                          capture_output=True, text=True).stdout.strip()


def main():
    args = sys.argv[1:]
    if not args or args[0] not in ['reset', '1', '2', '3', '4', '5'] or args[1:] not in ([], ['--html']):
        sys.exit('usage: strike <1..5|reset>')
    action = args[0]
    target = 'note "Grievances" of folder "Notes" of account "On My Mac"'
    try:
        previous = '' if action == 'reset' else notes('tell application "Notes" to get body of ' + target)
    except subprocess.CalledProcessError:
        sys.exit('strike: no Grievances note in Notes; stage the desk with stage-desk.sh first')
    body = note_body(Path(__file__).with_name('grievance-lines.txt').read_text().splitlines(), action, previous)
    if args[1:]:
        print(body)
        return
    notes('''on run argv
 tell application "Notes"
  set targetNote to note "Grievances" of folder "Notes" of account "On My Mac"
  set body of targetNote to item 1 of argv
  show targetNote
  activate
  return body of targetNote
 end tell
end run''', body)
    print(notes('tell application "Notes" to get body of ' + target))


if __name__ == '__main__':
    main()
