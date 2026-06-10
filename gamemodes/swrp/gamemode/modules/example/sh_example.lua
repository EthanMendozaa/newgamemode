--[[----------------------------------------------------------------------------
	Example module body (shared).

	During load, `MODULE` points at this module's table (seeded by the loader,
	populated by module.lua). Files load by realm prefix: this sh_ file runs on
	BOTH realms, sv_example.lua server-only, cl_example.lua client-only.

	This also serves as a live self-test of the net wrapper: a validated,
	rate-limited client->server "ping" the server answers with a "pong".
	Trigger it in-game with the `swrp_example_ping` console command.
------------------------------------------------------------------------------]]

local log = SWRP.Logger( "Example" )

-- Proof-of-load: confirms realm-aware inclusion and the MODULE handle work.
log.Info( "module body running on %s", SWRP.Realm )

-- React to a finished boot without touching core. Every core mutation will
-- fire an `SWRP.*` hook like this; modules subscribe instead of editing core.
hook.Add( "SWRP.Loaded", "SWRP.Example.Ready", function()
	log.Info( "module ready" )
end )

--------------------------------------------------------------------------------
-- Net wrapper self-test (delete with the rest of this template module)
--------------------------------------------------------------------------------

-- client -> server. Payload is validated and rate-limited automatically.
SWRP.Net.Register( "swrp.example.ping", {
	from      = "client",
	rateLimit = { times = 3, seconds = 5 },
	schema    = {
		{ name = "message", type = "string", max = 128 },
	},
	onReceive = function( ply, data )
		log.Info( "ping from %s: %q", IsValid( ply ) and ply:Nick() or "?", data.message )
		SWRP.Net.Send( "swrp.example.pong", ply, {
			message = "pong: " .. data.message,
		} )
	end,
} )

-- server -> client. No rate limit (server is trusted); payload still validated.
SWRP.Net.Register( "swrp.example.pong", {
	from   = "server",
	schema = {
		{ name = "message", type = "string", max = 160 },
	},
	onReceive = function( _, data )
		log.Info( "server replied: %q", data.message )
	end,
} )
