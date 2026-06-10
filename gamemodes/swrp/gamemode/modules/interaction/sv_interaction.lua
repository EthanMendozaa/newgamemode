--[[----------------------------------------------------------------------------
	Interaction module (server) — the authoritative request engine.

	SWRP.Interaction.Send{
	    type     = "battalion_invite",     -- dedupe key component
	    from     = officerPly or nil,      -- nil = system-initiated
	    to       = targetPly,              -- required, must be valid player
	    title    = "Battalion invite",
	    text     = "...",                  -- shown on the target's prompt
	    expires  = 30,                     -- seconds (server-authoritative)
	    validate = function() ... end,     -- re-run at ACCEPT time; return ok, reason
	    onAccept = function( req ) end,
	    onDeny   = function( req ) end,
	    onExpire = function( req ) end,
	} -> id or nil, reason

	Security model (invariant 3):
	  • validate() runs at send AND at accept — state may have changed between.
	  • Expiry is enforced here with CurTime deadlines; late/forged client
	    responses are dropped.
	  • Only the target player may respond to a request.
	  • One pending request per (type, from, to) — no prompt spam.
	  • Either party disconnecting expires the request.
------------------------------------------------------------------------------]]

local Interaction = SWRP.Interaction
local log         = SWRP.Logger( "Interaction" )

local pending = {}   -- id -> request
local dedupe  = {}   -- "type|fromId|toId" -> id
local nextId  = 0

local function plyKey( ply )
	if not IsValid( ply ) then return "system" end
	return ply:SteamID64() or ( "BOT_" .. ply:EntIndex() )
end

local function cleanup( req )
	pending[ req.id ] = nil
	dedupe[ req.key ] = nil
	timer.Remove( "SWRP.Interaction." .. req.id )
end

local function dismissClient( req )
	if IsValid( req.to ) then
		SWRP.Net.Send( "swrp.interaction.dismiss", req.to, { id = req.id } )
	end
end

local function finish( req, result, fn )
	cleanup( req )
	if fn then SWRP.Util.SafeCall( fn, req ) end
	hook.Run( "SWRP.InteractionResolved", req, result )
end

function Interaction.Send( req )
	if not istable( req ) or not isstring( req.type ) then
		return nil, "invalid request"
	end
	if not ( IsValid( req.to ) and req.to:IsPlayer() ) then
		return nil, "invalid target"
	end

	req.expires = req.expires or 30
	req.key     = req.type .. "|" .. plyKey( req.from ) .. "|" .. plyKey( req.to )

	if dedupe[ req.key ] then
		return nil, "a request of this type is already pending"
	end

	-- Validation at SEND time.
	if req.validate then
		local ok, reason = req.validate()
		if not ok then return nil, reason or "not allowed" end
	end

	nextId = nextId + 1
	req.id       = nextId
	req.deadline = CurTime() + req.expires

	pending[ req.id ]  = req
	dedupe[ req.key ]  = req.id

	SWRP.Net.Send( "swrp.interaction.prompt", req.to, {
		id      = req.id,
		title   = req.title or "Request",
		text    = req.text or "",
		expires = req.expires,
	} )

	timer.Create( "SWRP.Interaction." .. req.id, req.expires + 0.5, 1, function()
		local r = pending[ req.id ]
		if not r then return end
		dismissClient( r )
		finish( r, "expired", r.onExpire )
	end )

	return req.id
end

function Interaction.Respond( ply, id, accept )
	local req = pending[ id ]
	if not req then return end

	-- Only the target may answer, and only before the server deadline.
	if ply ~= req.to then
		log.Warn( "%s answered request #%d addressed to someone else — dropped", ply:Nick(), id )
		return
	end
	if CurTime() > req.deadline then
		finish( req, "expired", req.onExpire )
		return
	end

	if not accept then
		finish( req, "denied", req.onDeny )
		return
	end

	-- Validation at ACCEPT time — state may have changed since send.
	if req.validate then
		local ok, reason = req.validate()
		if not ok then
			log.Info( "request #%d (%s) invalidated at accept: %s", id, req.type, reason or "?" )
			finish( req, "invalidated", req.onDeny )
			return
		end
	end

	finish( req, "accepted", req.onAccept )
end

-- Either party leaving expires their pending requests. Collect first, then
-- finish: finish() fires SWRP.InteractionResolved, whose listeners may add new
-- pending entries — inserting during pairs() traversal is undefined behavior.
hook.Add( "PlayerDisconnected", "SWRP.Interaction.Disconnect", function( ply )
	local expired = {}
	for _, req in pairs( pending ) do
		if req.to == ply or req.from == ply then
			expired[ #expired + 1 ] = req
		end
	end
	for _, req in ipairs( expired ) do
		dismissClient( req )
		finish( req, "expired", req.onExpire )
	end
end )
