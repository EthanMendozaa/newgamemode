--[[----------------------------------------------------------------------------
	SWRP — server bootstrap

	GMod only auto-runs init.lua (server) and cl_init.lua (client) for a gamemode.
	This file stays deliberately thin: flag the client files for download, then
	run the shared bootstrap. All real load logic lives in shared.lua and
	core/sh_modules.lua so it executes identically on both realms.
------------------------------------------------------------------------------]]

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )
