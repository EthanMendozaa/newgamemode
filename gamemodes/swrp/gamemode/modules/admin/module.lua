--[[----------------------------------------------------------------------------
	Admin — staff tools, separate from the RP hierarchy (plan §3.4: server
	staff ≠ RP authority).

	Phase 2 ships the record-editing commands (setrank/setbattalion/
	setdesignation/setname/record) — enough to bootstrap the first officers and
	test everything. The full suite (log viewer UI, record editor UI) is
	Phase 4.
------------------------------------------------------------------------------]]

MODULE.Name    = "Admin"
MODULE.Version = "1.0.0"
MODULE.Depends = { "hierarchy", "character", "audit" }
