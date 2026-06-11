--[[----------------------------------------------------------------------------
	Lore — named slots: lore characters & commanders (build inventory #8b, §3.7).

	Unique single-occupancy identities defined in config, occupancy in the DB
	(atomic claims, race-safe across servers). A commander is a lore slot with
	commander = true: a virtual rank ABOVE the battalion's ladder with every
	battalion permission. Offers flow through the interaction framework;
	slots free automatically on leaving the battalion.
------------------------------------------------------------------------------]]

MODULE.Name    = "Lore"
MODULE.Version = "1.0.0"
MODULE.Depends = { "hierarchy", "character", "class", "interaction", "audit", "ui" }
