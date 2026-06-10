--[[----------------------------------------------------------------------------
	SWRP config — class templates (skillsets)

	A template defines a skillset ONCE; assignments.lua attaches it to
	battalions with per-battalion overrides. Weapons are placeholders (HL2)
	until a Star Wars weapon base is mounted — swap the class names, nothing
	else changes (the gamemode is content-agnostic).

	`nameTag` shows in derived names while the class is active (one class at a
	time, so it's unambiguous). `requiredCerts` is honored from day one in the
	schema; enforcement ships with the cert system (Phase 5).
------------------------------------------------------------------------------]]

CLASS_RIFLEMAN = SWRP.createClass( "Rifleman", {
	weapons = { "weapon_smg1", "weapon_pistol" },
	ammo    = { smg1 = 135, Pistol = 54 },
	health  = 100,
	armor   = 25,
} )

CLASS_MEDIC = SWRP.createClass( "Medic", {
	weapons = { "weapon_pistol", "weapon_medkit" },
	ammo    = { Pistol = 54 },
	health  = 100,
	armor   = 50,
	nameTag = "MED",
} )

CLASS_HEAVY = SWRP.createClass( "Heavy", {
	weapons = { "weapon_ar2", "weapon_pistol" },
	ammo    = { AR2 = 90, Pistol = 36 },
	health  = 150,
	armor   = 100,
	nameTag = "HVY",
} )
