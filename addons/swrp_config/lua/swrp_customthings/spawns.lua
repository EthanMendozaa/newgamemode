--[[----------------------------------------------------------------------------
	SWRP config — battalion spawn points (map-keyed)

	Members spawn at a random one of their battalion's points on the current
	map; battalions with no points here use the map's default spawns.

	Easiest authoring: stand on the spot in-game and run
	    !addspawn 501st
	(staff) — it prints a ready-to-paste line for this file. Reload with
	`swrp_reload_config`.
------------------------------------------------------------------------------]]

--[[ Examples (use !addspawn to generate real ones for your map):

SWRP.addBattalionSpawn( "gm_construct", BATTALION_501ST,
	Vector( 980, -829, -79 ), Angle( 0, 90, 0 ) )

SWRP.addBattalionSpawn( "gm_construct", BATTALION_501ST,
	Vector( 1040, -829, -79 ), Angle( 0, 90, 0 ) )

SWRP.addBattalionSpawn( "gm_construct", BATTALION_UNASSIGNED,
	Vector( -1000, -400, -79 ), Angle( 0, 0, 0 ) )

]]
