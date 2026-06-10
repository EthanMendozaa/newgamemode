--[[----------------------------------------------------------------------------
	SWRP — central net wrapper

	Every net message in the gamemode goes through here. Registering a message
	gives you, for free (plan §3.9 + invariant 3):
	  • automatic util.AddNetworkString
	  • a typed, declarative payload schema validated on receive
	  • per-player rate limiting on client->server messages (checked BEFORE the
	    payload is even parsed, so flooders are dropped as cheaply as possible)
	  • direction enforcement (a client->server message can't be sent the wrong
	    way, and the receive hook only attaches on the realm that receives it)

	Authority is server-side: clients send intents, the server validates the
	payload here and re-validates intent in the handler (Hierarchy.Can etc.).
	Invalid or rate-limited messages are dropped with a warning, never trusted.

	Register (shared — runs on both realms):
		SWRP.Net.Register( "swrp.battalion.invite", {
			from      = "client",                       -- "client" (c->s) or "server" (s->c)
			rateLimit = { times = 5, seconds = 10 },    -- per player, server-side only
			schema    = {
				{ name = "target",    type = "player" },
				{ name = "battalion", type = "string", max = 64 },
			},
			onReceive = function( ply, data )           -- server: ply = sender
				-- data.target, data.battalion already validated
			end,
		} )

	Send:
		client  ->  SWRP.Net.Send( name, data )
		server  ->  SWRP.Net.Send( name, targetsOrNil, data )  -- nil = broadcast
		server  ->  SWRP.Net.Broadcast( name, data )

	Custom field types can be added to SWRP.Net.Types by modules.
------------------------------------------------------------------------------]]

SWRP.Net = SWRP.Net or {}
local Net = SWRP.Net
local log = SWRP.Logger( "Net" )

--------------------------------------------------------------------------------
-- Field types
--
-- Each type knows how to read itself off the wire, write itself, and validate
-- a value. read/write receive the field definition so they can honour params
-- like `bits` (uint/int) or `max` (string length).
--------------------------------------------------------------------------------

local Types = {}
Net.Types = Types

Types.string = {
	read  = function( f )    return net.ReadString() end,
	write = function( v, f ) net.WriteString( v ) end,
	validate = function( v, f )
		if not isstring( v ) then return false, "expected string" end
		if f.max and #v > f.max then return false, "exceeds max length " .. f.max end
		if f.oneOf then
			for _, o in ipairs( f.oneOf ) do
				if v == o then return true end
			end
			return false, "not an allowed value"
		end
		return true
	end,
}

-- Structured payloads (rosters, lists): compressed JSON on the wire. Use for
-- on-demand data, not high-frequency traffic. Reads that fail to decompress
-- return nil and are dropped by validation.
Types.table = {
	read = function( f )
		local len = net.ReadUInt( 24 )
		if len == 0 then return {} end
		local raw  = net.ReadData( len )
		local json = util.Decompress( raw )
		if not json then return nil end
		return util.JSONToTable( json )
	end,
	write = function( v, f )
		local raw = util.Compress( util.TableToJSON( v or {} ) )
		net.WriteUInt( #raw, 24 )
		net.WriteData( raw, #raw )
	end,
	validate = function( v, f )
		if not istable( v ) then return false, "expected table" end
		return true
	end,
}

Types.uint = {
	read  = function( f )    return net.ReadUInt( f.bits or 32 ) end,
	write = function( v, f ) net.WriteUInt( v, f.bits or 32 ) end,
	validate = function( v, f )
		if not isnumber( v ) then return false, "expected number" end
		if v % 1 ~= 0        then return false, "must be an integer" end
		if v < 0             then return false, "must be >= 0" end
		local bits = f.bits or 32
		if v >= 2 ^ bits     then return false, "exceeds " .. bits .. "-bit range" end
		return true
	end,
}

Types.int = {
	read  = function( f )    return net.ReadInt( f.bits or 32 ) end,
	write = function( v, f ) net.WriteInt( v, f.bits or 32 ) end,
	validate = function( v, f )
		if not isnumber( v ) then return false, "expected number" end
		if v % 1 ~= 0        then return false, "must be an integer" end
		local bits  = f.bits or 32
		local limit = 2 ^ ( bits - 1 )
		if v < -limit or v >= limit then return false, "exceeds " .. bits .. "-bit signed range" end
		return true
	end,
}

Types.bool = {
	read  = function( f )    return net.ReadBool() end,
	write = function( v, f ) net.WriteBool( v and true or false ) end,
	validate = function( v, f )
		if not isbool( v ) then return false, "expected boolean" end
		return true
	end,
}

Types.entity = {
	read  = function( f )    return net.ReadEntity() end,
	write = function( v, f ) net.WriteEntity( v ) end,
	validate = function( v, f )
		if not IsValid( v ) then return false, "invalid entity" end
		return true
	end,
}

Types.player = {
	read  = function( f )    return net.ReadEntity() end,
	write = function( v, f ) net.WriteEntity( v ) end,
	validate = function( v, f )
		if not ( IsValid( v ) and v:IsPlayer() ) then return false, "expected valid player" end
		return true
	end,
}

--------------------------------------------------------------------------------
-- Schema helpers
--------------------------------------------------------------------------------

local function readSchema( cfg )
	local data = {}
	for _, f in ipairs( cfg.schema ) do
		data[ f.name ] = Types[ f.type ].read( f )
	end
	return data
end

local function validateSchema( cfg, data )
	for _, f in ipairs( cfg.schema ) do
		local ok, err = Types[ f.type ].validate( data[ f.name ], f )
		if not ok then
			return false, string.format( "field '%s': %s", f.name, err or "invalid" )
		end
	end
	return true
end

local function writeSchema( cfg, data )
	for _, f in ipairs( cfg.schema ) do
		Types[ f.type ].write( data[ f.name ], f )
	end
end

--------------------------------------------------------------------------------
-- Rate limiting (server-side, fixed window, per player per message)
--------------------------------------------------------------------------------

local rateState = {} -- [name][steamid64] = { count, windowStart }

local function withinRate( name, ply, limit )
	if not limit then return true end

	local sid = ply:SteamID64() or "unknown"
	rateState[ name ] = rateState[ name ] or {}

	local st  = rateState[ name ][ sid ]
	local now = CurTime()

	if not st or ( now - st.windowStart ) > limit.seconds then
		st = { count = 0, windowStart = now }
		rateState[ name ][ sid ] = st
	end

	st.count = st.count + 1
	return st.count <= limit.times
end

if SERVER then
	hook.Add( "PlayerDisconnected", "SWRP.Net.RateCleanup", function( ply )
		local sid = ply:SteamID64()
		if not sid then return end
		for _, perPlayer in pairs( rateState ) do perPlayer[ sid ] = nil end
	end )
end

--------------------------------------------------------------------------------
-- Registration
--------------------------------------------------------------------------------

local registry = {}

function Net.Register( name, cfg )
	if not isstring( name ) then error( "SWRP.Net.Register: name must be a string" ) end

	cfg        = cfg or {}
	cfg.from   = cfg.from or "client"
	cfg.schema = cfg.schema or {}

	if cfg.from ~= "client" and cfg.from ~= "server" then
		error( string.format( "SWRP.Net.Register '%s': from must be 'client' or 'server'", name ) )
	end

	-- Validate the schema definition itself at registration so typos surface at
	-- load, not at first send.
	for i, f in ipairs( cfg.schema ) do
		if not isstring( f.name ) then
			error( string.format( "SWRP.Net.Register '%s': schema[%d] missing a string 'name'", name, i ) )
		end
		if not Types[ f.type ] then
			error( string.format( "SWRP.Net.Register '%s': field '%s' has unknown type '%s'",
				name, f.name, tostring( f.type ) ) )
		end
	end

	-- Re-registration replaces the old config (hot-reload friendly), but is
	-- worth a note in console so accidental duplicates don't hide.
	if registry[ name ] then
		log.Info( "re-registered '%s'", name )
	end
	registry[ name ] = cfg

	if SERVER then util.AddNetworkString( name ) end

	-- A client->server message is received on the server, and vice versa. Only
	-- hook net.Receive on the realm that actually receives it.
	local receivedOnServer = ( cfg.from == "client" )
	local receiveHere      = ( receivedOnServer and SERVER ) or ( not receivedOnServer and CLIENT )

	if receiveHere then
		net.Receive( name, function( len, ply )
			-- Rate limit first: drop flooders before paying any parse cost.
			-- (Only untrusted client->server traffic is limited.)
			if receivedOnServer and IsValid( ply ) and not withinRate( name, ply, cfg.rateLimit ) then
				log.Warn( "rate limit hit on '%s' from %s", name, ply:Nick() )
				return
			end

			local data = readSchema( cfg )

			local ok, err = validateSchema( cfg, data )
			if not ok then
				local who = ( IsValid( ply ) and ( " from " .. ply:Nick() ) ) or ""
				log.Warn( "dropped '%s'%s: %s", name, who, err )
				return
			end

			if cfg.onReceive then
				SWRP.Util.SafeCall( cfg.onReceive, ply, data )
			end
		end )
	end
end

--------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------

-- Validate the outgoing payload against the schema before opening net.Start,
-- so a bad payload errors cleanly instead of writing a half-formed message.
local function prepareSend( name, data )
	local cfg = registry[ name ]
	if not cfg then error( "SWRP.Net.Send: unknown message '" .. tostring( name ) .. "'" ) end

	local ok, err = validateSchema( cfg, data or {} )
	if not ok then
		error( string.format( "SWRP.Net.Send '%s': %s", name, err ) )
	end

	return cfg
end

function Net.Send( name, a, b )
	if CLIENT then
		-- client -> server: Send( name, data )
		local cfg = prepareSend( name, a )
		if cfg.from ~= "client" then
			error( string.format( "SWRP.Net.Send '%s': not a client->server message", name ) )
		end

		net.Start( name )
		writeSchema( cfg, a or {} )
		net.SendToServer()
	else
		-- server -> client: Send( name, targetsOrNil, data )
		local targets, data = a, b
		local cfg = prepareSend( name, data )
		if cfg.from ~= "server" then
			error( string.format( "SWRP.Net.Send '%s': not a server->client message", name ) )
		end

		net.Start( name )
		writeSchema( cfg, data or {} )
		if targets == nil then net.Broadcast() else net.Send( targets ) end
	end
end

-- Server convenience: send to every client.
function Net.Broadcast( name, data )
	if not SERVER then error( "SWRP.Net.Broadcast is server-only" ) end
	Net.Send( name, nil, data )
end
