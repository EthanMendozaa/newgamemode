--[[----------------------------------------------------------------------------
	Character — the single source of truth (invariant 1).

	One persistent record per player; name, battalion, rank, model are DERIVED
	from it via Recompute and never set directly. Owns the characters DB table,
	record load/create on join, write-through mutations, and the designation
	picker flow.
------------------------------------------------------------------------------]]

MODULE.Name    = "Character"
MODULE.Version = "1.0.0"
MODULE.Depends = { "hierarchy" }
