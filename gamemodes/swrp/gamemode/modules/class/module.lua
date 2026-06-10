--[[----------------------------------------------------------------------------
	Class — combat identity (build inventory #8, plan §3.6).

	Templates define a skillset once (Rifleman, Medic, Heavy...); assignments
	attach them to battalions with overrides (models, slots, rank gates). A
	player's class_id references the ASSIGNMENT, so leaving a battalion
	automatically invalidates the class (repaired to the battalion default —
	no void states). Slot limits are session-based. Switching respawns.
------------------------------------------------------------------------------]]

MODULE.Name    = "Class"
MODULE.Version = "1.0.0"
MODULE.Depends = { "hierarchy", "character", "audit", "ui" }
