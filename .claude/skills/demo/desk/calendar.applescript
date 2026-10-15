with timeout of 30 seconds
 tell application "Calendar"
  activate
  if not (exists calendar "Desk") then make new calendar with properties {name:"Desk"}
  set deskCalendar to calendar "Desk"
  delete every event of deskCalendar
  set dayStart to current date
  set time of dayStart to 0
  set titles to {"Standup (floating, do not tile)", "A meeting that could have been a window", "Display changes resolution for no reason", "Yell at the Dock"}
  set starts to {9 * hours, 11 * hours, 14 * hours, 16 * hours + 30 * minutes}
  repeat with i from 1 to 4
   set begins to current date
   set time of begins to item i of starts
   set duration to 1 * hours
   if i is 4 then set duration to 30 * minutes
   make new event at end of events of deskCalendar with properties {summary:item i of titles, start date:begins, end date:begins + duration}
  end repeat
  switch view to day view
  view calendar at dayStart
  set eventCount to count events of deskCalendar
 end tell
 delay 1
 tell application "System Events" to tell process "Calendar"
  if exists menu item "Show Calendar List" of menu "View" of menu bar 1 then
   click menu item "Show Calendar List" of menu "View" of menu bar 1
  end if
  delay 1
  set calendarRows to rows of outline 1 of scroll area 1 of splitter group 1 of splitter group 1 of window 1
  repeat with calendarRow in calendarRows
   set cell to UI element 1 of calendarRow
   if exists checkbox 1 of cell then
    set calendarName to name of cell
    if exists text field 1 of cell then set calendarName to value of text field 1 of cell
    set wanted to 0
    if calendarName is "Desk" then set wanted to 1
    if value of checkbox 1 of cell is not wanted then click checkbox 1 of cell
   end if
  end repeat
  click menu item "Hide Calendar List" of menu "View" of menu bar 1
 end tell
 return eventCount
end timeout
