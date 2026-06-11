--[[----------------------------------------------------------------------------
	Spawns — per-battalion spawn points (build inventory #13).

	Config-defined, map-keyed spawn positions; members spawn at their
	battalion's points (random among them), everyone else at map defaults.
	`!addspawn` prints a ready-to-paste config line for the spot you're
	standing on.
------------------------------------------------------------------------------]]

MODULE.Name    = "Spawns"
MODULE.Version = "1.0.0"
MODULE.Depends = { "hierarchy", "character" }
