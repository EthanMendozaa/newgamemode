--[[----------------------------------------------------------------------------
	SWRP config — battalion definitions

	Each battalion returns a handle stored in an easy-name global
	(BATTALION_501ST). Exactly one battalion must set `default = true` — new
	and kicked players land there (no void states, invariant 2).

	Models are placeholders (HL2 citizens) until a Star Wars content pack is
	mounted — swap the paths, nothing else changes. `defaultClass` (required)
	is the class members hold by default — set on join, the no-void fallback
	when a class is lost; it may never be slot-limited or rank-gated.
------------------------------------------------------------------------------]]

BATTALION_UNASSIGNED = SWRP.createBattalion( "Unassigned", {
	tag          = "UNA",
	color        = Color( 150, 150, 150 ),
	ranks        = RANKS_CLONE,
	models       = { "models/player/group01/male_02.mdl" },
	defaultClass = CLASS_RIFLEMAN,
	default      = true,             -- the no-void fallback battalion
} )

BATTALION_501ST = SWRP.createBattalion( "501st Legion", {
	tag    = "501st",
	color  = Color( 65, 105, 225 ),
	ranks  = RANKS_CLONE,
	models = {
		"models/player/group03/male_02.mdl",
		"models/player/group03/male_07.mdl",
	},
	defaultClass = CLASS_RIFLEMAN,
} )
