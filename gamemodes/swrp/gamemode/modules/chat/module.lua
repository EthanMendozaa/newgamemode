--[[----------------------------------------------------------------------------
	Chat — channels + rendering (build inventory #12).

	All player text routes server-side (PlayerSay -> net), so the server
	decides who hears what:

	  local   default speech, proximity-limited
	  radio   battalion comms (/r or the team-chat key) — battalion members only
	  ooc     out-of-character, global (/ooc)
	  me      emotes, proximity (/me salutes)

	Channel verbs are registered through the command registry, so they share
	the !/ prefix namespace with every other command.
------------------------------------------------------------------------------]]

MODULE.Name    = "Chat"
MODULE.Version = "1.0.0"
MODULE.Depends = { "hierarchy", "character", "ui" }
