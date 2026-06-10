--[[----------------------------------------------------------------------------
	Battalion — delegated battalion management (build inventory #7).

	Officers run their own battalion through the menu's Battalion tab: invite
	(via the interaction framework), promote/demote/kick — online AND offline
	targets — all gated by Hierarchy.Can server-side, all audited. Zero staff
	involvement (design pillar 2).
------------------------------------------------------------------------------]]

MODULE.Name    = "Battalion"
MODULE.Version = "1.0.0"
MODULE.Depends = { "hierarchy", "character", "interaction", "audit", "ui" }
