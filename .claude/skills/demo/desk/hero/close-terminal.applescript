tell application "System Events"
  tell process "Ghostty"
    repeat with w in windows
      if (count of sheets of w) > 0 then
        click button "Close" of sheet 1 of w
      end if
    end repeat
  end tell
end tell
