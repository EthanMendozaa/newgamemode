--[[----------------------------------------------------------------------------
	Admin module (client) — the Staff terminal tab (v4).

	Record editor (left column) + live audit feed (right column). Client
	gating is cosmetic; every action re-checks IsSuperAdmin server-side.
------------------------------------------------------------------------------]]

local Admin = SWRP.Admin
local UI    = SWRP.UI

local state = {
	feed = nil,   -- audit scroll panel
}

local function timeAgo( at )
	local d = os.time() - ( tonumber( at ) or 0 )
	if d < 60 then return d .. "s" end
	if d < 3600 then return math.floor( d / 60 ) .. "m" end
	if d < 86400 then return math.floor( d / 3600 ) .. "h" end
	return math.floor( d / 86400 ) .. "d"
end

function Admin.OnAudit( rows )
	if not IsValid( state.feed ) then return end

	state.feed:Clear()

	local theme = SWRP.Theme
	for _, r in ipairs( rows or {} ) do
		local row = vgui.Create( "DPanel" )
		row:SetTall( 40 )
		row:Dock( TOP )
		row.Paint = function( self, w, h )
			local C = theme.colors
			local sev = C.accent
			if string.find( r.action or "", "kick" ) or string.find( r.action or "", "strip" ) then
				sev = C.danger
			elseif string.find( r.action or "", "lore" ) or string.find( r.action or "", "admin" ) then
				sev = C.gold
			end

			SWRP.UI.Rect( 4, 0, h / 2 - 4, 8, 8, sev )
			draw.SimpleText( timeAgo( r.at ), "SWRP.Small", 22, h / 2, C.label,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			draw.SimpleText( ( r.actor_name ~= "" and r.actor_name or "system" ), "SWRP.Sub",
				72, h / 2, C.textBlue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			draw.SimpleText( r.action or "?", "SWRP.Small", w * 0.42, h / 2, C.textDim,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			draw.SimpleText( r.target_name ~= "" and r.target_name or "—", "SWRP.Small",
				w * 0.74, h / 2, C.textBlue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			surface.SetDrawColor( C.hairline )
			surface.DrawRect( 0, h - 1, w, 1 )
		end
		state.feed:AddItem( row )
	end
end

UI.RegisterMenuTab( {
	id    = "staff",
	name  = "Staff",
	order = 90,
	build = function( panel )
		local theme = SWRP.Theme
		local C     = theme.colors

		if not SWRP.Util.IsStaff( LocalPlayer() ) then
			local label = vgui.Create( "DLabel", panel )
			label:SetText( "Restricted to staff." )
			label:SetFont( "SWRP.Sub" )
			label:SetTextColor( C.textDim )
			label:Dock( TOP )
			return
		end

		-- Left: record editor ---------------------------------------------------
		local editor = vgui.Create( "DPanel", panel )
		editor:Dock( LEFT )
		editor:SetWide( math.floor( ScrW() * 0.30 ) )
		editor:DockMargin( 0, 0, 50, 0 )
		editor.Paint = function( self, w, h )
			draw.SimpleText( "RECORD EDITOR — ONLINE PLAYERS", "SWRP.Label", 0, 4, C.label )
		end
		editor:DockPadding( 0, 34, 0, 0 )

		local targetEntry

		local function fieldRow( label, field, placeholder )
			local row = vgui.Create( "DPanel", editor )
			row:Dock( TOP )
			row:SetTall( theme.kit.btnH )
			row:DockMargin( 0, 0, 0, 12 )
			row.Paint = nil

			local lbl = vgui.Create( "DLabel", row )
			lbl:SetText( label )
			lbl:SetFont( "SWRP.Label" )
			lbl:SetTextColor( C.label )
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
				apply:SetWide( 80 )
				apply:DockMargin( 10, 0, 0, 0 )
			end

			return entry
		end

		targetEntry = fieldRow( "TARGET",      nil,           "player name or SteamID" )
		fieldRow(    "BATTALION",   "battalion",   "name, tag, or id — e.g. 501st" )
		fieldRow(    "RANK",        "rank",        "name, tag, or index — e.g. CPT" )
		fieldRow(    "DESIGNATION", "designation", "e.g. 4456" )
		fieldRow(    "RP NAME",     "name",        "new name" )

		-- Right: audit feed ------------------------------------------------------
		local right = vgui.Create( "DPanel", panel )
		right:Dock( FILL )
		right.Paint = function( self, w, h )
			draw.SimpleText( "AUDIT FEED", "SWRP.Label", 0, 4, C.label )
		end
		right:DockPadding( 0, 34, 0, 0 )

		local refresh = UI.Button( right, "Refresh", "ghost", function()
			SWRP.Net.Send( "swrp.admin.audit_request", {} )
		end )
		refresh:Dock( BOTTOM )
		refresh:SetWide( 110 )
		refresh:DockMargin( 0, 12, 0, 0 )

		local feed = vgui.Create( "DScrollPanel", right )
		feed:Dock( FILL )
		SWRP.UI.Scrollbar( feed )
		state.feed = feed

		SWRP.Net.Send( "swrp.admin.audit_request", {} )
	end,
} )
