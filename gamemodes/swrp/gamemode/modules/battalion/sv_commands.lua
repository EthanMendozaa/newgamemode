--[[----------------------------------------------------------------------------
	Battalion module (server) — officer chat/console commands.

	!promote / !demote / !kick / !invite <player> are alternate ENTRY POINTS to
	the exact same handlers the F4 menu uses — Hierarchy.Can, slot caps, audit,
	respawn rules all apply identically. No authority lives here.

	Commands target ONLINE players (found by name fragment or SteamID); offline
	members are managed through the F4 roster, which lists them.
------------------------------------------------------------------------------]]

local Battalion = SWRP.Battalion
local Character = SWRP.Character
local Commands  = SWRP.Commands
local Util      = SWRP.Util

local function findTargetRecord( ply, args )
	local target, err = Util.FindPlayer( args[ 1 ] or "" )
	if not target then
		Commands.Reply( ply, err )
		return nil
	end

	local rec = Character.GetRecord( target )
	if not rec then
		Commands.Reply( ply, target:Nick() .. " has no loaded character yet" )
		return nil
	end
	return target, rec
end

local function rankAction( action )
	return function( ply, args )
		local target, rec = findTargetRecord( ply, args )
		if not target then return end
		Battalion.HandleAction( ply, action, rec.id )
	end
end

Commands.Register( "promote", {
	description = "Promote a battalion member one rank (needs can_promote)",
	playerOnly  = true,
	handler     = rankAction( "promote" ),
} )

Commands.Register( "demote", {
	description = "Demote a battalion member one rank (needs can_demote)",
	playerOnly  = true,
	handler     = rankAction( "demote" ),
} )

Commands.Register( "kick", {
	description = "Remove a member from your battalion (needs can_kick)",
	playerOnly  = true,
	handler     = rankAction( "kick" ),
} )

Commands.Register( "invite", {
	description = "Invite a player to your battalion (needs can_invite)",
	playerOnly  = true,
	handler = function( ply, args )
		local target = findTargetRecord( ply, args )
		if not target then return end
		Battalion.HandleInvite( ply, target )
	end,
} )
