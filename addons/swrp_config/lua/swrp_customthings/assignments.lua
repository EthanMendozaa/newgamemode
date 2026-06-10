--[[----------------------------------------------------------------------------
	SWRP config — class assignments

	Attach templates to battalions with overrides. A player's class references
	the ASSIGNMENT (not the template), so leaving the battalion invalidates it
	automatically. Shared classes = one template, many assignments.

	Slot limits (`max`) are session-based — freed on disconnect. `minRank`
	takes a rank tag, name, or ladder index. `exclusive = true` reserves a
	template for one battalion (validated at load).
------------------------------------------------------------------------------]]

-- Default classes (battalions.lua sets defaultClass = CLASS_RIFLEMAN) are
-- auto-assigned if omitted, but explicit keeps intent obvious.
SWRP.assignClass( BATTALION_UNASSIGNED, CLASS_RIFLEMAN )
SWRP.assignClass( BATTALION_501ST,      CLASS_RIFLEMAN )

SWRP.assignClass( BATTALION_501ST, CLASS_MEDIC, {
	name    = "501st Medic",
	max     = 4,          -- session slots
	minRank = "SPC",      -- Specialist+
} )

SWRP.assignClass( BATTALION_501ST, CLASS_HEAVY, {
	name    = "501st Heavy",
	max     = 2,
	minRank = "SGT",
} )
