--[[----------------------------------------------------------------------------
	SWRP config — lore characters & commanders (named slots, §3.7)

	Single-occupancy identities. One person holds each at a time (DB-enforced,
	race-safe across servers). The COMMANDER (commander = true, max one per
	battalion) sits above the rank ladder with every battalion permission and
	is granted by staff; other lore characters are offered by officers with
	can_offer_lore (!offerlore <player> <name>). Slots free automatically when
	the holder leaves the battalion. !lore lists your battalion's slots.

	nameFormat replaces the standard name entirely. Tokens: {battalion} {rank}
	{classTag} {designation} {name} — {name} is the LORE character's name.
------------------------------------------------------------------------------]]

-- Placeholder commander so the system is testable — rename/replace for your
-- server's lore.
LORE_APPO = SWRP.createLoreCharacter( BATTALION_501ST, "Appo", {
	commander  = true,
	tag        = "CDR",
	nameFormat = "{battalion} {rank} 1119 {name}",
	class      = CLASS_RIFLEMAN,
	health     = 150,
	armor      = 100,
	addWeapons = { "weapon_357" },
} )

--[[ A non-commander lore character looks like:

LORE_JESSE = SWRP.createLoreCharacter( BATTALION_501ST, "Jesse", {
	rank       = "SGT",                        -- fixed ladder rank (tag/name/index)
	nameFormat = "{battalion} {rank} 5597 {name}",
	class      = CLASS_MEDIC,
	models     = { "models/player/..." },      -- bespoke model
} )

]]
