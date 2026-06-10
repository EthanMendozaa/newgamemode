--[[----------------------------------------------------------------------------
	HUD — Phase 1 identity rendering: HUD plate, overhead tags, scoreboard,
	chat names. Everything reads derived identity via SWRP.Character
	accessors and pulls every visual from SWRP.Theme (owned by the ui
	module, invariant 7).
------------------------------------------------------------------------------]]

MODULE.Name    = "HUD"
MODULE.Version = "1.1.0"
MODULE.Depends = { "hierarchy", "character", "ui" }
