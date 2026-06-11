--[[----------------------------------------------------------------------------
	Chat module (server) — authoritative routing.

	PlayerSay suppresses the engine broadcast and re-sends through the net
	wrapper to exactly the players who should hear it. The !/ prefix namespace
	belongs to the command registry (which runs its own PlayerSay hook); this
	hook ignores prefixed text entirely, and the channel verbs (/r, /ooc, /me)
	are themselves registered commands.
------------------------------------------------------------------------------]]

local Chat      = SWRP.Chat
local Character = SWRP.Character
local Commands  = SWRP.Commands

--------------------------------------------------------------------------------
-- Routing
--------------------------------------------------------------------------------

local function recipients( ply, channel )
	local out = {}

	if channel == "ooc" then
		return player.GetAll()
	end

	if channel == "radio" then
		local rec = Character.GetRecord( ply )
		if not rec then return { ply } end
		for _, p in ipairs( player.GetAll() ) do
			local r = Character.GetRecord( p )
			if r and r.battalion_id == rec.battalion_id then
				out[ #out + 1 ] = p
			end
		end
		return out
	end

	-- local / me: proximity
	local range = ( Chat.Channels[ channel ] and Chat.Channels[ channel ].range or 600 ) ^ 2
	local pos   = ply:GetPos()
	for _, p in ipairs( player.GetAll() ) do
		if p:GetPos():DistToSqr( pos ) <= range then
			out[ #out + 1 ] = p
		end
	end
	return out
end

function Chat.Send( ply, channel, text )
	text = string.Trim( tostring( text or "" ) )
	if text == "" then return end
	text = string.sub( text, 1, 300 )

	-- Dead players may not use battalion comms.
	if channel == "radio" and not ply:Alive() then
		SWRP.UI.Notify( ply, false, "You cannot use comms while dead" )
		return
	end

	SWRP.Net.Send( "swrp.chat.msg", recipients( ply, channel ), {
		channel = channel,
		sender  = ply,
		text    = text,
		dead    = not ply:Alive(),
	} )

	hook.Run( "SWRP.ChatMessage", ply, channel, text )
end

--------------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------------

-- Default speech + team-chat key (= battalion radio).
hook.Add( "PlayerSay", "SWRP.Chat.Route", function( ply, text, teamChat )
	-- The command registry owns the !/ prefix namespace.
	if string.match( text, "^[!/]" ) then return end

	Chat.Send( ply, teamChat and "radio" or "local", text )
	return ""
end )

Commands.Register( "r", {
	description = "Battalion radio: /r <message>",
	playerOnly  = true,
	handler = function( ply, args )
		Chat.Send( ply, "radio", table.concat( args, " " ) )
	end,
} )

Commands.Register( "ooc", {
	description = "Out-of-character (global): /ooc <message>",
	playerOnly  = true,
	handler = function( ply, args )
		Chat.Send( ply, "ooc", table.concat( args, " " ) )
	end,
} )

Commands.Register( "me", {
	description = "Emote: /me <action>",
	playerOnly  = true,
	handler = function( ply, args )
		Chat.Send( ply, "me", table.concat( args, " " ) )
	end,
} )
