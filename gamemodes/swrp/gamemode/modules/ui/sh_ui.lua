--[[----------------------------------------------------------------------------
	UI module (shared) — main menu net wiring.

	F4 (ShowSpare2) fires SERVER-side in GMod, so the server bounces it to the
	client through the net wrapper, and the client opens the menu shell.
------------------------------------------------------------------------------]]

SWRP.Net.Register( "swrp.ui.open_menu", {
	from   = "server",
	schema = {},
	onReceive = function()
		if CLIENT then SWRP.UI.OpenMenu() end
	end,
} )

if SERVER then
	hook.Add( "ShowSpare2", "SWRP.UI.OpenMenu", function( ply )
		SWRP.Net.Send( "swrp.ui.open_menu", ply, {} )
	end )
end

-- Generic server -> client toast, for any module's action feedback.
SWRP.Net.Register( "swrp.ui.notice", {
	from   = "server",
	schema = {
		{ name = "ok",      type = "bool" },
		{ name = "message", type = "string", max = 96 },
	},
	onReceive = function( _, data )
		if CLIENT then
			SWRP.UI.Toast( data.message, data.ok and "success" or "danger" )
		end
	end,
} )

if SERVER then
	function SWRP.UI.Notify( ply, ok, message )
		if not IsValid( ply ) then return end
		SWRP.Net.Send( "swrp.ui.notice", ply, { ok = ok, message = message } )
	end
end
