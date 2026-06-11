--[[----------------------------------------------------------------------------
	Admin module (shared) — net contracts for the Staff menu tab.

	Clients send INTENTS; every handler re-gates on IsSuperAdmin server-side
	(the client-side tab gating is cosmetic only).
------------------------------------------------------------------------------]]

SWRP.Admin = SWRP.Admin or {}

-- Edit one field of an online player's record.
SWRP.Net.Register( "swrp.admin.edit", {
	from      = "client",
	rateLimit = { times = 10, seconds = 10 },
	schema    = {
		{ name = "target", type = "string", max = 64 },
		{ name = "field",  type = "string", oneOf = { "battalion", "rank", "designation", "name" } },
		{ name = "value",  type = "string", max = 64 },
	},
	onReceive = function( ply, data )
		if SERVER then SWRP.Admin.HandleEdit( ply, data.target, data.field, data.value ) end
	end,
} )

-- Recent audit log entries for the Staff tab.
SWRP.Net.Register( "swrp.admin.audit_request", {
	from      = "client",
	rateLimit = { times = 6, seconds = 10 },
	schema    = {},
	onReceive = function( ply )
		if SERVER then SWRP.Admin.SendAudit( ply ) end
	end,
} )

SWRP.Net.Register( "swrp.admin.audit", {
	from   = "server",
	schema = {
		{ name = "rows", type = "table" },
	},
	onReceive = function( _, data )
		if CLIENT and SWRP.Admin.OnAudit then SWRP.Admin.OnAudit( data.rows ) end
	end,
} )
