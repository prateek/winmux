set grievanceBody to do shell script "python3 " & quoted form of ((system attribute "HOME") & "/desk/grievances.py") & " reset --html"
-- Fill the apps that only take content by script.
tell application "Notes"
	tell account "On My Mac"
		try
			delete (every note whose name is "Grievances")
			delete (every note whose name is "Soft language")
		end try
		make new note at folder "Notes" with properties {name:"Soft language", body:"<h1>Soft language</h1><div>It is not “minimized”. It is hiding.</div><div><br></div><div>They don't say popup any more. It's an “accessory window”. Thirty years of progress and we added four syllables.</div><div><br></div><div>“Full screen.” It was already a screen. Now it's just greedy.</div>"}
		make new note at folder "Notes" with properties {name:"Grievances", body:grievanceBody}
	end tell
end tell
