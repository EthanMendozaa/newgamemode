--[[----------------------------------------------------------------------------
	Battalion module (client) — the Battalion terminal tab (v4).

	Airy avatar roster, client-side search, and ALL member actions in a
	click/right-click context menu (no persistent action buttons — approved
	design). Pure intent-sender: Hierarchy.Can here only hides menu entries the
	server would reject; every action is re-validated server-side.
------------------------------------------------------------------------------]]

local Battalion = SWRP.Battalion
local Hierarchy = SWRP.Hierarchy
local Character = SWRP.Character
local UI        = SWRP.UI

local state = {
	roster = nil,    -- last payload
	list   = nil,    -- scroll panel
	head   = nil,    -- header line panel
	filter = "",
}

local function myId()
	return LocalPlayer():SteamID64() or ( "BOT_" .. LocalPlayer():EntIndex() )
end

--------------------------------------------------------------------------------
-- Context menu (the v4 action surface)
--------------------------------------------------------------------------------

local function openMemberMenu( row )
	local lp   = LocalPlayer()
	local desc = { battalion_id = state.roster.battalion_id, rank_id = row.rank_id }

	local items = {}

	if Hierarchy.Can( lp, "can_promote", desc ) then
		items[ #items + 1 ] = { label = "▲  Promote", onClick = function()
			SWRP.Net.Send( "swrp.battalion.action", { action = "promote", target = row.id } )
		end }
	end
	if Hierarchy.Can( lp, "can_demote", desc ) then
		items[ #items + 1 ] = { label = "▼  Demote", onClick = function()
			SWRP.Net.Send( "swrp.battalion.action", { action = "demote", target = row.id } )
		end }
	end

	-- Lore offers: online targets only, officers with the permission (the
	-- server re-checks; commander slots are refused server-side for non-staff).
	if SWRP.Lore and row.online and Hierarchy.Can( lp, "can_offer_lore" ) then
		local slots = SWRP.Lore.SlotsFor( state.roster.battalion_id )
		for _, slot in ipairs( slots ) do
			items[ #items + 1 ] = { label = "Offer: " .. slot.name, onClick = function()
				LocalPlayer():ConCommand( 'swrp_offerlore "' .. row.id .. '" "' .. slot.name .. '"' )
			end }
		end
	end

	if Hierarchy.Can( lp, "can_kick", desc ) then
		items[ #items + 1 ] = { label = "Remove from battalion", danger = true, onClick = function()
			UI.Confirm( "Remove member", "Remove " .. row.name .. " from the battalion?",
				function()
					SWRP.Net.Send( "swrp.battalion.action", { action = "kick", target = row.id } )
				end )
		end }
	end

	if #items == 0 then return end
	UI.ContextMenu( items )
end

--------------------------------------------------------------------------------
-- Roster rendering
--------------------------------------------------------------------------------

local function rebuild()
	if not ( IsValid( state.list ) and state.roster ) then return end

	local theme = SWRP.Theme
	local C     = theme.colors
	local data  = state.roster

	-- Sort: online first, rank descending, then name.
	table.sort( data.rows, function( a, b )
		if a.online ~= b.online then return a.online end
		local ra = Hierarchy.GetRank( a.rank_id )
		local rb = Hierarchy.GetRank( b.rank_id )
		local ia = ra and ra.index or 0
		local ib = rb and rb.index or 0
		if ia ~= ib then return ia > ib end
		return ( a.name or "" ) < ( b.name or "" )
	end )

	state.list:Clear()

	local needle = string.lower( state.filter )

	for _, row in ipairs( data.rows ) do
		local visible = needle == ""
			or string.find( string.lower( row.name or "" ), needle, 1, true )
			or string.find( row.designation or "", needle, 1, true )

		if visible then
			local rank   = Hierarchy.GetRank( row.rank_id )
			local isSelf = ( row.id == myId() )
			local gold   = rank and rank.virtual   -- commander

			local r = vgui.Create( "DPanel" )
			r:SetTall( theme.spacing.listH )
			r:Dock( TOP )

			-- Avatar (online players by entity; offline get initials discs)
			local who = nil
			for _, p in ipairs( player.GetAll() ) do
				local pid = p:SteamID64() or ( "BOT_" .. p:EntIndex() )
				if pid == row.id then who = p break end
			end
			local av = UI.Avatar( r, who or row.name, theme.kit.avatar )
			av:SetPos( 6, ( theme.spacing.listH - theme.kit.avatar ) / 2 )

			r.Paint = function( self, w, h )
				local hf = isSelf and 0 or UI.HoverFrac( self )
				if hf > 0.02 then
					surface.SetDrawColor( 65, 105, 225, 24 * hf )
					surface.DrawRect( 0, 0, w, h )
				end

				local nameCol = gold and C.gold or ( row.online and C.textBlue or C.textDim )
				local fullName = ( rank and rank.tag or "?" ) .. " "
					.. ( row.designation or "----" ) .. " " .. ( row.name or "?" )

				draw.SimpleText( fullName, "SWRP.Sub", 56, h / 2,
					nameCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				draw.SimpleText( rank and rank.name or "—", "SWRP.Small", w * 0.52, h / 2,
					row.online and C.textDim or C.label, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				draw.SimpleText( row.online and "Online" or "Offline", "SWRP.Small",
					w - 8, h / 2, row.online and C.success or C.label,
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

				surface.SetDrawColor( C.hairline )
				surface.DrawRect( 0, h - 1, w, 1 )
			end

			if not isSelf then
				r:SetCursor( "hand" )
				r.OnMousePressed = function() openMemberMenu( row ) end
			end

			state.list:AddItem( r )
		end
	end
end

function Battalion.OnRoster( data )
	state.roster = data
	rebuild()
end

--------------------------------------------------------------------------------
-- Invite picker (dialog)
--------------------------------------------------------------------------------

local function openInvitePicker()
	local lp    = LocalPlayer()
	local myBat = Character.GetBattalion( lp )
	local f     = UI.Frame( 380, 420, "Invite to " .. ( myBat and myBat.name or "battalion" ) )

	local scroll = vgui.Create( "DScrollPanel", f.Body )
	scroll:Dock( FILL )

	local any = false
	for _, p in ipairs( player.GetAll() ) do
		local theirBat = Character.GetBattalion( p )
		if p ~= lp and ( not theirBat or not myBat or theirBat.id ~= myBat.id ) then
			any = true

			local row = vgui.Create( "DPanel" )
			row:SetTall( 48 )
			row:Dock( TOP )

			local av = UI.Avatar( row, p, 30 )
			av:SetPos( 4, 9 )

			row.Paint = function( self, w, h )
				local C = SWRP.Theme.colors
				draw.SimpleText( Character.GetName( p ), "SWRP.Sub", 44, h / 2,
					Character.GetColor( p ), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				surface.SetDrawColor( C.hairline )
				surface.DrawRect( 0, h - 1, w, 1 )
			end

			local invite = UI.Button( row, "Invite", "primary", function()
				SWRP.Net.Send( "swrp.battalion.invite", { target = p } )
				f:Close()
			end )
			invite:Dock( RIGHT )
			invite:SetWide( 76 )
			invite:DockMargin( 0, 7, 0, 7 )

			scroll:AddItem( row )
		end
	end

	if not any then
		local lbl = vgui.Create( "DLabel", f.Body )
		lbl:SetFont( "SWRP.Sub" )
		lbl:SetTextColor( SWRP.Theme.colors.textDim )
		lbl:SetText( "No eligible players online." )
		lbl:Dock( TOP )
	end
end

--------------------------------------------------------------------------------
-- Terminal tab
--------------------------------------------------------------------------------

UI.RegisterMenuTab( {
	id    = "battalion",
	name  = "Battalion",
	order = 20,
	build = function( panel )
		local theme = SWRP.Theme
		local C     = theme.colors
		local lp    = LocalPlayer()

		-- Cap content ~1150px (playtest: rows stretched edge-to-edge on wide
		-- monitors, putting columns a head-turn apart).
		local rosterCap = math.max( 0, ( ScrW() - theme.spacing.termX * 2 ) - 1150 )

		-- Header line: battalion statement + counts + search + invite
		local head = vgui.Create( "DPanel", panel )
		head:Dock( TOP )
		head:SetTall( 46 )
		head:DockMargin( 0, 0, rosterCap, 16 )
		head.Paint = function( self, w, h )
			local battalion = Character.GetBattalion( lp )
			draw.SimpleText( string.upper( battalion and battalion.name or "BATTALION" ),
				"SWRP.H2", 0, h / 2 - 1, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

			if state.roster then
				local online = 0
				for _, r in ipairs( state.roster.rows ) do
					if r.online then online = online + 1 end
				end
				surface.SetFont( "SWRP.H2" )
				local tw = surface.GetTextSize( string.upper( battalion and battalion.name or "BATTALION" ) )
				draw.SimpleText( #state.roster.rows .. " members  ·  " .. online .. " online",
					"SWRP.Small", tw + 22, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			end
		end

		if Hierarchy.Can( lp, "can_invite" ) then
			local invite = UI.Button( head, "Invite member", "primary", openInvitePicker )
			invite:Dock( RIGHT )
			invite:SetWide( 140 )
			invite:DockMargin( 10, 5, 0, 5 )
		end

		local search = UI.TextEntry( head )
		search:Dock( RIGHT )
		search:SetWide( 280 )
		search:DockMargin( 0, 5, 0, 5 )
		search:SetPlaceholderText( "Search members…" )
		search:SetUpdateOnType( true )
		search.OnValueChange = function( _, value )
			state.filter = value or ""
			rebuild()
		end

		local list = vgui.Create( "DScrollPanel", panel )
		list:Dock( FILL )
		list:DockMargin( 0, 0, rosterCap, 0 )
		local sbar = list:GetVBar()
		sbar:SetWide( 6 )
		sbar.Paint = nil
		sbar.btnUp.Paint, sbar.btnDown.Paint = nil, nil
		sbar.btnGrip.Paint = function( self, w, h )
			draw.RoundedBox( 3, 0, 0, w, h, C.bgRaised )
		end
		state.list = list

		rebuild()
		SWRP.Net.Send( "swrp.battalion.roster_request", {} )
	end,
} )
