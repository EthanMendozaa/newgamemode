--[[----------------------------------------------------------------------------
	Battalion module (shared) — net contracts.

	Clients only ever send INTENTS (invariant 3): "promote this record id".
	The server resolves the target (online or offline), re-checks Hierarchy.Can,
	enforces rank slot caps from the DB, applies, audits, and pushes a fresh
	roster. Roster data flows on demand (plan §3.9), never per-tick.
------------------------------------------------------------------------------]]

SWRP.Battalion = SWRP.Battalion or {}

-- Client asks for its battalion's roster (on-demand, e.g. opening the tab).
SWRP.Net.Register( "swrp.battalion.roster_request", {
	from      = "client",
	rateLimit = { times = 10, seconds = 10 },
	schema    = {},
	onReceive = function( ply )
		if SERVER then SWRP.Battalion.SendRoster( ply ) end
	end,
} )

-- Roster payload: { battalion_id, rows = { { id, name, rank_id, designation, lore_id, online }, ... } }
SWRP.Net.Register( "swrp.battalion.roster", {
	from   = "server",
	schema = {
		{ name = "data", type = "table" },
	},
	onReceive = function( _, payload )
		if CLIENT then SWRP.Battalion.OnRoster( payload.data ) end
	end,
} )

-- Rank actions against a roster entry (record id — works for offline targets).
SWRP.Net.Register( "swrp.battalion.action", {
	from      = "client",
	rateLimit = { times = 10, seconds = 10 },
	schema    = {
		{ name = "action", type = "string", oneOf = { "promote", "demote", "kick" } },
		{ name = "target", type = "string", max = 32 },
	},
	onReceive = function( ply, data )
		if SERVER then SWRP.Battalion.HandleAction( ply, data.action, data.target ) end
	end,
} )

-- Invite an online player (flows through the interaction framework).
SWRP.Net.Register( "swrp.battalion.invite", {
	from      = "client",
	rateLimit = { times = 5, seconds = 10 },
	schema    = {
		{ name = "target", type = "player" },
	},
	onReceive = function( ply, data )
		if SERVER then SWRP.Battalion.HandleInvite( ply, data.target ) end
	end,
} )

-- Action feedback uses the gamemode-wide swrp.ui.notice channel (ui module).
