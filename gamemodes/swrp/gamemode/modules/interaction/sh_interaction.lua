--[[----------------------------------------------------------------------------
	Interaction module (shared) — net contracts + client prompt glue.

	The client is dumb on purpose: it renders the prompt and reports the
	button press. All state, expiry, and validation are server-side; a client
	answering after server-side expiry (or forging an id) is just dropped.
------------------------------------------------------------------------------]]

SWRP.Interaction = SWRP.Interaction or {}

SWRP.Net.Register( "swrp.interaction.prompt", {
	from   = "server",
	schema = {
		{ name = "id",      type = "uint" },
		{ name = "title",   type = "string", max = 48 },
		{ name = "text",    type = "string", max = 128 },
		{ name = "expires", type = "uint",   bits = 16 },
	},
	onReceive = function( _, data )
		if not CLIENT then return end
		SWRP.UI.Prompt( {
			id      = data.id,
			title   = data.title,
			text    = data.text,
			expires = data.expires,
			onAccept = function()
				SWRP.Net.Send( "swrp.interaction.respond", { id = data.id, accept = true } )
			end,
			onDeny = function()
				SWRP.Net.Send( "swrp.interaction.respond", { id = data.id, accept = false } )
			end,
			-- Expiry is server-authoritative; the client popup just closes.
		} )
	end,
} )

SWRP.Net.Register( "swrp.interaction.respond", {
	from      = "client",
	rateLimit = { times = 20, seconds = 10 },
	schema    = {
		{ name = "id",     type = "uint" },
		{ name = "accept", type = "bool" },
	},
	onReceive = function( ply, data )
		if SERVER then SWRP.Interaction.Respond( ply, data.id, data.accept ) end
	end,
} )

SWRP.Net.Register( "swrp.interaction.dismiss", {
	from   = "server",
	schema = {
		{ name = "id", type = "uint" },
	},
	onReceive = function( _, data )
		if CLIENT then SWRP.UI.DismissPrompt( data.id ) end
	end,
} )
