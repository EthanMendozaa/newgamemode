--[[----------------------------------------------------------------------------
	Admin — staff tools, separate from the RP hierarchy (plan §3.4: server
	staff ≠ RP authority).

	Record-editing ops behind one gated table, exposed two ways: chat/console
	commands (!setrank etc.) and the F4 Staff tab (record editor + audit log
	viewer). Plus swrp_bots for stress testing.
------------------------------------------------------------------------------]]

MODULE.Name    = "Admin"
MODULE.Version = "1.1.0"
MODULE.Depends = { "hierarchy", "character", "audit", "ui" }
