-- Fill the apps that only take content by script.
tell application "Notes"
	tell account "On My Mac"
		repeat with n in (every note whose name is "Grievances" or name is "Soft language")
			delete n
		end repeat
		make new note at folder "Notes" with properties {name:"Soft language", body:"<h1>Soft language</h1><div>It is not “minimized”. It is hiding.</div><div><br></div><div>They don't say popup any more. It's an “accessory window”. Thirty years of progress and we added four syllables.</div><div><br></div><div>“Full screen.” It was already a screen. Now it's just greedy.</div>"}
		make new note at folder "Notes" with properties {name:"Grievances", body:"<h1>Grievances</h1><div>1. Alt-tab is a slot machine. I pulled it nine times and got Preview.</div><div><br></div><div>2. Every app thinks it deserves the whole screen. You are a calculator.</div><div><br></div><div>3. Nobody has ever wanted a minimized window to be “somewhere”.</div><div><br></div><div>4. A popup is not a window. It is a guy who walks into your house to tell you about a sale.</div><div><br></div><div>5. I own a monitor the width of a canoe and everything opens in the middle.</div>"}
	end tell
end tell
