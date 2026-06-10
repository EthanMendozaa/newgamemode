--[[----------------------------------------------------------------------------
	SWRP config — rank ladders

	Ordered lowest -> highest. `tag` feeds the name format; `max` caps holders
	per battalion (DB/session-enforced in Phase 2); `permissions` gate
	hierarchy actions via Hierarchy.Can. Every entry is validated at load with
	friendly file:line errors — a bad entry is skipped, never a crash.

	RANKS_CLONE is shared by all clone battalions (locked decision). Add
	RANKS_NAVAL / RANKS_JEDI here the same way when those battalions exist.
------------------------------------------------------------------------------]]

RANKS_CLONE = SWRP.createRankLadder( "Clone", {
	{ name = "Private",             tag = "PVT" },
	{ name = "Private First Class", tag = "PFC" },
	{ name = "Specialist",          tag = "SPC" },
	{ name = "Corporal",            tag = "CPL" },
	{ name = "Sergeant",            tag = "SGT", permissions = {
		can_invite = true,
	} },
	{ name = "Staff Sergeant",      tag = "SSG", permissions = {
		can_invite = true,
	} },
	{ name = "Lieutenant",          tag = "LT",  max = 2, permissions = {
		can_invite = true, can_promote = true, can_kick = true,
	} },
	{ name = "Captain",             tag = "CPT", max = 1, permissions = {
		can_invite = true, can_promote = true, can_demote = true, can_kick = true,
		can_manage_classes = true, can_designate_trainers = true,
	} },
} )
