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
local Config    = SWRP.Config

--------------------------------------------------------------------------------
-- Flood control
--
-- The engine throttles normal say, but the channel verbs are also reachable
-- through concommands (swrp_r etc.), which the engine does NOT throttle —
-- and every message fans out O(players). One limiter covers every path.
--------------------------------------------------------------------------------

local chatRate = {}
local RATE_TIMES, RATE_WINDOW = 8, 5

local function withinRate( ply )
	local sid = ply:SteamID64() or ( "BOT_" .. ply:EntIndex() )
	local now = CurTime()
	local st  = chatRate[ sid ]

	if not st or ( now - st.windowStart ) > RATE_WINDOW then
		chatRate[ sid ] = { windowStart = now, count = 1 }
		return true
	end

	st.count = st.count + 1
	return st.count <= RATE_TIMES
end

hook.Add( "PlayerDisconnected", "SWRP.Chat.RateCleanup", function( ply )
	chatRate[ ply:SteamID64() or ( "BOT_" .. ply:EntIndex() ) ] = nil
end )

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
	if text == "" then
		SWRP.UI.Notify( ply, false, "Nothing to send — add a message" )
		return
	end
	text = string.sub( text, 1, 300 )

	if not withinRate( ply ) then return end

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
	-- The !/ prefix namespace belongs to the command registry. Known commands
	-- are passed through (the registry's own hook handles them in either hook
	-- order); UNKNOWN prefixed text must not fall through to the engine — base
	-- PlayerSay would broadcast it globally, bypassing proximity.
	local cmd = string.match( text, "^[!/](%w+)" )
	if cmd and Commands.GetAll()[ string.lower( cmd ) ] then return end

	if string.match( text, "^[!/]" ) then
		if Config.Get( "chat_strict_commands", true ) then
			Commands.Reply( ply, "Unknown command — try !help" )
			return ""
		end
		return   -- permissive mode: other addons may consume it
	end

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
