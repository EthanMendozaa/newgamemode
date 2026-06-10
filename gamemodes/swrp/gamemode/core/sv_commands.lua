--[[----------------------------------------------------------------------------
	SWRP — command registry (server only)

	One registration gives a command two entry points:
	  • chat:    !promote Para   (or /promote)
	  • console: swrp_promote Para

	Commands are INTENT entry points only — handlers must enforce their own
	authority (Hierarchy.Can for officer actions, IsSuperAdmin for staff), the
	same as any net message (invariant 3). The Phase 4 chat module extends this
	registry; it doesn't replace it.

	SWRP.Commands.Register( "promote", {
	    description = "Promote a battalion member",
	    playerOnly  = true,    -- reject server console as actor
	    handler     = function( ply, args ) ... end,
	} )
------------------------------------------------------------------------------]]

if not SERVER then return end

SWRP.Commands = SWRP.Commands or {}
local Commands = SWRP.Commands
local log      = SWRP.Logger( "Commands" )

local registry = {}

-- Feedback that works for both players (chat) and the server console (log).
function Commands.Reply( ply, msg )
	if IsValid( ply ) then
		ply:ChatPrint( "[SWRP] " .. msg )
	else
		log.Info( msg )
	end
end

function Commands.Register( name, def )
	name     = string.lower( name )
	def.name = name

	if registry[ name ] then
		log.Warn( "command '%s' re-registered", name )
	end
	registry[ name ] = def

	concommand.Add( "swrp_" .. name, function( ply, _, args )
		Commands.Run( ply, name, args or {} )
	end )
end

function Commands.GetAll()
	return registry
end

function Commands.Run( ply, name, args )
	local def = registry[ name ]
	if not def then return end

	if def.playerOnly and not IsValid( ply ) then
		log.Warn( "command '%s' must be run by a player, not the console", name )
		return
	end

	SWRP.Util.SafeCall( def.handler, ply, args )
end

hook.Add( "PlayerSay", "SWRP.Commands.Chat", function( ply, text )
	local cmd, rest = string.match( text, "^[!/](%w+)%s*(.*)$" )
	if not cmd then return end

	cmd = string.lower( cmd )
	if not registry[ cmd ] then return end   -- unknown: let other addons see it

	local args = {}
	for word in string.gmatch( rest, "%S+" ) do args[ #args + 1 ] = word end

	Commands.Run( ply, cmd, args )
	return ""   -- suppress the chat message
end )

Commands.Register( "help", {
	description = "List available commands",
	handler = function( ply )
		Commands.Reply( ply, "Commands (chat !cmd or console swrp_cmd):" )
		local names = {}
		for n in pairs( registry ) do names[ #names + 1 ] = n end
		table.sort( names )
		for _, n in ipairs( names ) do
			Commands.Reply( ply, "  !" .. n .. " — " .. ( registry[ n ].description or "" ) )
		end
	end,
} )
