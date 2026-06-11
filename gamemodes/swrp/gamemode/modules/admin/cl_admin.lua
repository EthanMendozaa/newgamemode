--[[----------------------------------------------------------------------------
	Admin module (client) — the Staff menu tab.

	Record editor (online targets) + recent audit log. Client gating is
	cosmetic; every action re-checks IsSuperAdmin server-side.
------------------------------------------------------------------------------]]

local Admin = SWRP.Admin
local UI    = SWRP.UI

local state = {
	tbl = nil,   -- audit table widget
}

local function timeAgo( at )
	local d = os.time() - ( tonumber( at ) or 0 )
	if d < 60 then return d .. "s ago" end
	if d < 3600 then return math.floor( d / 60 ) .. "m ago" end
	if d < 86400 then return math.floor( d / 3600 ) .. "h ago" end
	return math.floor( d / 86400 ) .. "d ago"
end

function Admin.OnAudit( rows )
	if not ( state.tbl and IsValid( state.tbl.wrap ) ) then return end

	state.tbl:Clear()
	for _, r in ipairs( rows or {} ) do
		state.tbl:AddRow( {
			timeAgo( r.at ),
			r.actor_name ~= "" and r.actor_name or "system",
			r.action or "?",
			r.target_name ~= "" and r.target_name or "—",
		}, {} )
	end
	if #( rows or {} ) == 0 then
		state.tbl:AddRow( { "No entries", "", "", "" }, { dim = true } )
	end
end

UI.RegisterMenuTab( {
	id    = "staff",
	name  = "Staff",
	order = 90,
	build = function( panel )
		local theme = SWRP.Theme
		local C, S  = theme.colors, theme.spacing

		if not LocalPlayer():IsSuperAdmin() then
			local label = vgui.Create( "DLabel", panel )
			label:SetText( "Staff only." )
			label:SetFont( "SWRP.Sub" )
			label:SetTextColor( C.textDim )
			label:Dock( TOP )
			return
		end

		-- Record editor -------------------------------------------------------
		local editor = UI.Card( panel, "Record editor (online players)" )
		editor:Dock( TOP )
		editor:SetTall( 34 + 5 * ( theme.kit.btnH + 8 ) + S.pad )
		editor:DockMargin( 0, 0, 0, S.pad )

		local targetEntry

		local function fieldRow( label, field, placeholder )
			local row = vgui.Create( "DPanel", editor )
			row:Dock( TOP )
			row:SetTall( theme.kit.btnH )
			row:DockMargin( 0, 0, 0, 8 )
			row.Paint = nil

			local lbl = vgui.Create( "DLabel", row )
			lbl:SetText( label )
			lbl:SetFont( "SWRP.Small" )
			lbl:SetTextColor( C.textDim )
			lbl:Dock( LEFT )
			lbl:SetWide( 110 )

			local entry = UI.TextEntry( row )
			entry:Dock( FILL )
			entry:SetPlaceholderText( placeholder or "" )

			if field then
				local apply = UI.Button( row, "Apply", "primary", function()
					SWRP.Net.Send( "swrp.admin.edit", {
						target = targetEntry:GetValue(),
						field  = field,
						value  = entry:GetValue(),
					} )
				end )
				apply:Dock( RIGHT )
				apply:SetWide( 76 )
				apply:DockMargin( 8, 0, 0, 0 )
			end

			return entry
		end

		targetEntry = fieldRow( "Target",      nil,           "player name or SteamID" )
		fieldRow(    "Battalion",   "battalion",   "name, tag, or id — e.g. 501st" )
		fieldRow(    "Rank",        "rank",        "name, tag, or index — e.g. CPT" )
		fieldRow(    "Designation", "designation", "e.g. 4456" )
		fieldRow(    "RP name",     "name",        "new name" )

		-- Audit log -----------------------------------------------------------
		local logCard = UI.Card( panel, "Recent audit log" )
		logCard:Dock( FILL )

		local refresh = UI.Button( logCard, "Refresh", "ghost", function()
			SWRP.Net.Send( "swrp.admin.audit_request", {} )
		end )
		refresh:Dock( BOTTOM )
		refresh:DockMargin( 0, 8, 0, 0 )

		state.tbl = UI.Table( logCard, {
			{ name = "When",   frac = 0.16 },
			{ name = "Actor",  frac = 0.28 },
			{ name = "Action", frac = 0.30 },
			{ name = "Target", frac = 0.26 },
		} )

		SWRP.Net.Send( "swrp.admin.audit_request", {} )
	end,
} )
