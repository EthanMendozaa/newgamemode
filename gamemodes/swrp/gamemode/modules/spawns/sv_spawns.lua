--[[----------------------------------------------------------------------------
	Spawns module (server) — apply battalion spawn points + authoring helper.
------------------------------------------------------------------------------]]

local Spawns    = SWRP.Spawns
local Character = SWRP.Character
local Commands  = SWRP.Commands

hook.Add( "PlayerSpawn", "SWRP.Spawns.Position", function( ply )
	local rec = Character.GetRecord( ply )
	if not rec then return end

	local point = Spawns.GetFor( rec.battalion_id )
	if not point then return end   -- no config for this battalion/map: map default

	-- Next tick: after the engine has placed the player at a default point.
	timer.Simple( 0, function()
		if not IsValid( ply ) or not ply:Alive() then return end
		ply:SetPos( point.pos )
		ply:SetEyeAngles( point.ang )
	end )
end )

-- Staff helper: stand where the spawn should be, run !addspawn <battalion>,
-- paste the printed line into swrp_customthings/spawns.lua.
Commands.Register( "addspawn", {
	description = "STAFF: print a config line for a battalion spawn at your position",
	playerOnly  = true,
	handler = function( ply, args )
		if not ply:IsSuperAdmin() then
			Commands.Reply( ply, "Staff only" )
			return
		end

		local battalion = SWRP.Hierarchy.FindBattalion( table.concat( args, " " ) )
		if not battalion then
			Commands.Reply( ply, "Unknown battalion — usage: !addspawn 501st" )
			return
		end

		local pos = ply:GetPos()
		local ang = ply:EyeAngles()
		local line = string.format(
			'SWRP.addBattalionSpawn( "%s", BATTALION_%s, Vector( %d, %d, %d ), Angle( 0, %d, 0 ) )',
			game.GetMap(), string.upper( SWRP.Hierarchy.Slug( battalion.name ) ),
			pos.x, pos.y, pos.z, ang.yaw )

		Commands.Reply( ply, "Add to swrp_customthings/spawns.lua:" )
		Commands.Reply( ply, line )
		print( "[SWRP:Spawns] " .. line )   -- also in console for easy copying
	end,
} )
