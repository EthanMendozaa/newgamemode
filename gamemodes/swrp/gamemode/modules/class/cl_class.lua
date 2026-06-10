--[[----------------------------------------------------------------------------
	Class module (client) — the Classes menu tab.

	Openable anywhere (plan §3.6): lists the battalion's classes with LIVE
	eligibility and greyed-out reasons straight from the server payload.
	Switching shows the respawn confirmation (config-driven) and sends an
	intent; the server re-validates everything.
------------------------------------------------------------------------------]]

local Class = SWRP.Class
local UI    = SWRP.UI

local state = {
	data = nil,    -- last payload
	tbl  = nil,    -- live table widget
}

local function rebuild()
	if not ( state.tbl and IsValid( state.tbl.wrap ) ) or not state.data then return end

	local theme = SWRP.Theme
	local data  = state.data

	state.tbl:Clear()

	for _, c in ipairs( data.classes ) do
		local current = ( c.id == data.current )

		local slots = "—"
		if c.max then slots = ( c.used or 0 ) .. " / " .. c.max end

		local status
		if current then
			status = "Current class"
		elseif c.eligible then
			status = c.minRank and ( c.minRank .. "+" ) or "Available"
		else
			status = c.reason
		end

		local buttons = {}
		if not current and c.eligible then
			buttons[ #buttons + 1 ] = { label = "Use", variant = "primary", width = 52, onClick = function()
				local function send()
					SWRP.Net.Send( "swrp.class.switch", { id = c.id } )
				end
				if data.confirm then
					UI.Confirm( "Switch class",
						"Switch to " .. c.name .. "? You will respawn.", send )
				else
					send()
				end
			end }
		end

		state.tbl:AddRow( {
			c.name .. ( c.tag and ( "  [" .. c.tag .. "]" ) or "" ),
			c.health .. " HP / " .. c.armor .. " AR",
			slots,
			status,
		}, {
			color   = current and theme.colors.gold or ( c.eligible and theme.colors.accent or nil ),
			dim     = not c.eligible and not current,
			buttons = buttons,
		} )
	end
end

function Class.OnState( data )
	state.data = data
	rebuild()
end

UI.RegisterMenuTab( {
	id    = "classes",
	name  = "Classes",
	order = 30,
	build = function( panel )
		local theme = SWRP.Theme

		local top = vgui.Create( "DPanel", panel )
		top:Dock( TOP )
		top:SetTall( theme.kit.btnH )
		top:DockMargin( 0, 0, 0, theme.spacing.pad )
		top.Paint = nil

		local hint = vgui.Create( "DLabel", top )
		hint:SetFont( "SWRP.Sub" )
		hint:SetTextColor( theme.colors.textDim )
		hint:SetText( "Switching class respawns you. Gold = current." )
		hint:Dock( FILL )

		local refresh = UI.Button( top, "Refresh", "ghost", function()
			SWRP.Net.Send( "swrp.class.state_request", {} )
		end )
		refresh:Dock( RIGHT )
		refresh:SetWide( 90 )

		state.tbl = UI.Table( panel, {
			{ name = "Class",  frac = 0.34 },
			{ name = "Stats",  frac = 0.20 },
			{ name = "Slots",  frac = 0.14 },
			{ name = "Status", frac = 0.32 },
		} )

		rebuild()
		SWRP.Net.Send( "swrp.class.state_request", {} )
	end,
} )
