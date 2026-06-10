--[[----------------------------------------------------------------------------
	Hierarchy — battalions, rank ladders, and the permission gate.

	Owns the shared registries that config's create* calls populate, and
	Hierarchy.Can — the single security-critical permission check every
	interactive system consumes (invariant 3).
------------------------------------------------------------------------------]]

MODULE.Name    = "Hierarchy"
MODULE.Version = "1.0.0"
MODULE.Depends = {}
