--[[----------------------------------------------------------------------------
	Chat module (shared) — channel definitions + net contract.

	Every routed message carries its channel; the client renders from theme
	colors (invariant 7). Hearing rules live server-side only.
------------------------------------------------------------------------------]]

SWRP.Chat = SWRP.Chat or {}
local Chat = SWRP.Chat

-- Shared channel metadata (ranges are advisory here; enforced server-side).
Chat.Channels = {
	[ "local" ] = { range = 600 },
	radio       = { tag = "RADIO" },
	ooc         = { tag = "OOC" },
	me          = { range = 600 },
}

SWRP.Net.Register( "swrp.chat.msg", {
	from   = "server",
	schema = {
		{ name = "channel", type = "string", oneOf = { "local", "radio", "ooc", "me" } },
		{ name = "sender",  type = "player" },
		{ name = "text",    type = "string", max = 300 },
		{ name = "dead",    type = "bool" },
	},
	onReceive = function( _, data )
		if CLIENT then Chat.Render( data ) end
	end,
} )
