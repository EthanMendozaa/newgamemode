--[[----------------------------------------------------------------------------
	Module manifest — runs on both realms BEFORE any module body, so the loader
	can resolve dependency order. Set metadata only here; no gameplay logic.

	This `example` module is a working template: copy the folder, rename it, and
	build. It is safe to delete once real modules exist.
------------------------------------------------------------------------------]]

MODULE.Name    = "Example"
MODULE.Version = "1.0.0"

-- Names of other modules this one needs loaded first (case-insensitive folder
-- names). The loader errors clearly and skips this module if any are missing.
MODULE.Depends = {}
