--[[----------------------------------------------------------------------------
	Class module (client) — the Classes terminal tab (v4).

	Large model cards, one verb per card ("BECOME MEDIC"), locked classes stay
	quiet (dim + reason in the CTA slot). Eligibility comes from the server
	payload; the switch is re-validated server-side.
------------------------------------------------------------------------------]]

local Class = SWRP.Class
local UI    = SWRP.UI

local state = {
	data = nil,
	grid = nil,
}

local function rebuild()
	if not ( IsValid( state.grid ) and state.data ) then return end

	state.grid:Clear()

	local data = state.data
	local n = 0

	for _, c in ipairs( data.classes ) do
		-- Model thumb from the shared registry (assignment -> resolved models).
		local model = nil
		local a = Class.GetAssignment( c.id )
		if a then
			local models = Class.Resolve( a ).models
			model = models and models[ 1 ]
		end

		local card = UI.ClassCard( state.grid, {
			name     = c.name,
			health   = c.health,
			armor    = c.armor,
			max      = c.max,
			used     = c.used,
			current  = ( c.id == data.current ),
			eligible = c.eligible,
			reason   = c.reason,
			model    = model,
			onUse    = function()
				local function send()
					SWRP.Net.Send( "swrp.class.switch", { id = c.id } )
				end
				if data.confirm then
					UI.Confirm( "Switch class",
						"Switch to " .. c.name .. "? You will respawn.", send )
				else
					send()
				end
			end,
		} )

		card:Dock( LEFT )
		card:SetWide( math.floor(
			( ScrW() - SWRP.Theme.spacing.termX * 2 )
			/ math.max( #data.classes, 4 ) ) - 22 )
		card:DockMargin( 0, 0, 22, 0 )
		n = n + 1
		UI.FadeIn( card, UI.Stagger( n ) )
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
		local C     = theme.colors

		local head = vgui.Create( "DPanel", panel )
		head:Dock( TOP )
		head:SetTall( 40 )
		head:DockMargin( 0, 0, 0, 16 )
		head.Paint = function( self, w, h )
			draw.SimpleText( "COMBAT LOADOUT", "SWRP.H2", 0, h / 2 - 1, C.text,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			draw.SimpleText( "SWITCHING RESPAWNS YOU  ·  SLOTS FREE ON DISCONNECT",
				"SWRP.Label", 246, h / 2, C.label, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end

		-- Full-height trooper columns (v6 — the model owns the column; the
		-- old torso-zoom came from a ClassCard cam override, now removed).
		local grid = vgui.Create( "DPanel", panel )
		grid:Dock( FILL )
		grid.Paint = nil
		state.grid = grid

		rebuild()
		SWRP.Net.Send( "swrp.class.state_request", {} )
	end,
} )
