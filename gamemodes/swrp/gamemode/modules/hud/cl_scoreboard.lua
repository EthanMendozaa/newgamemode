--[[----------------------------------------------------------------------------
	HUD module (client) — scoreboard (v4, approved).

	Top-anchored wide bar (the GMod-native pattern), server band up top, rows
	grouped under battalion bands with avatars and derived identity. Identity
	resolves once per rebuild (every 2s), never per paint frame.
------------------------------------------------------------------------------]]

local Character = SWRP.Character
local Hierarchy = SWRP.Hierarchy
local UI        = SWRP.UI

local board = nil

local rowCount
local function buildRows( list, animate )
	rowCount = 0
	list:Clear()

	local theme = SWRP.Theme
	local C     = theme.colors

	-- Group players by battalion id.
	local groups, order = {}, {}
	for _, ply in ipairs( player.GetAll() ) do
		local b   = Character.GetBattalion( ply )
		local id  = b and b.id or "~none"
		if not groups[ id ] then
			groups[ id ] = { battalion = b, players = {} }
			order[ #order + 1 ] = id
		end
		table.insert( groups[ id ].players, ply )
	end
	table.sort( order )

	for _, id in ipairs( order ) do
		local group     = groups[ id ]
		local battalion = group.battalion

		-- Battalion band
		local band = vgui.Create( "DPanel" )
		band:SetTall( 30 )
		band:Dock( TOP )
		band.Paint = function( self, w, h )
			surface.SetDrawColor( C.termBot )
			surface.DrawRect( 0, 0, w, h )
			surface.SetDrawColor( battalion and battalion.color or C.textDim )
			surface.DrawRect( 14, h / 2 - 5, 4, 10 )
			draw.SimpleText(
				string.upper( battalion and battalion.name or "UNKNOWN" )
				.. "  —  " .. #group.players,
				"SWRP.Label", 28, h / 2, C.accentSub,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end
		list:AddItem( band )

		-- Rows: rank-descending within the battalion
		table.sort( group.players, function( a, b )
			local ra = Character.GetRank( a )
			local rb = Character.GetRank( b )
			local ia = ra and ra.index or 0
			local ib = rb and rb.index or 0
			if ia ~= ib then return ia > ib end
			return Character.GetName( a ) < Character.GetName( b )
		end )

		for _, ply in ipairs( group.players ) do
			-- Resolve identity ONCE per rebuild.
			local name     = Character.GetName( ply )
			local rank     = Character.GetRank( ply )
			local rankName = rank and rank.name or "—"
			local desig    = Character.GetDesignation( ply )
			local gold     = rank and rank.virtual
			local batColor = Character.GetColor( ply )

			local row = vgui.Create( "DPanel" )
			row:SetTall( 40 )
			row:Dock( TOP )

			local av = UI.Avatar( row, ply, 26 )
			av:SetPos( 16, 7 )

			row.Paint = function( self, w, h )
				if not IsValid( ply ) then return end

				draw.SimpleText( name, "SWRP.Sub", 56, h / 2,
					gold and C.gold or batColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				draw.SimpleText( rankName, "SWRP.Small", w * 0.52, h / 2, C.textDim,
					TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				draw.SimpleText( desig ~= "" and desig or "—", "SWRP.Small", w * 0.74, h / 2,
					C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				draw.SimpleText( ply:Ping(), "SWRP.Small", w - 16, h / 2, C.label,
					TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

				surface.SetDrawColor( C.hairline )
				surface.DrawRect( 14, h - 1, w - 28, 1 )
			end

			list:AddItem( row )
			if animate then
				rowCount = ( rowCount or 0 ) + 1
				UI.FadeIn( row, UI.Stagger( rowCount ) )
			end
		end
	end
end

hook.Add( "ScoreboardShow", "SWRP.HUD.Scoreboard", function()
	local theme = SWRP.Theme
	local C     = theme.colors

	if IsValid( board ) then board:Remove() end

	local w = math.Clamp( ScrW() * 0.46, 640, 880 )

	board = vgui.Create( "DPanel" )
	board:SetSize( w, math.min( ScrH() * 0.72, 760 ) )
	board:SetPos( ( ScrW() - w ) / 2, theme.spacing.margin * 2 )

	board.Paint = function( self, pw, ph )
		UI.DrawBlur( self, theme.kit.blur )
		SWRP.UI.Rect( theme.kit.radius, 0, 0, pw, ph, C.bg )
		surface.SetDrawColor( C.cellBorder )
		surface.DrawOutlinedRect( 0, 0, pw, ph, 1 )

		-- Server band
		SWRP.UI.RectTop( theme.kit.radius, 0, 0, pw, 54, C.titleBar )
		surface.SetDrawColor( C.accent )
		surface.DrawRect( 0, 52, pw, 2 )
		draw.SimpleText( string.upper( GetHostName() ), "SWRP.Title", 16, 27 - 1, C.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		draw.SimpleText( game.GetMap() .. "  ·  " .. #player.GetAll() .. " personnel",
			"SWRP.Small", pw - 16, 27, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end

	local list = vgui.Create( "DScrollPanel", board )
	list:Dock( FILL )
	list:DockMargin( 0, 60, 0, 8 )

	UI.Scrollbar( list )

	buildRows( list, true )

	-- Periodic refresh while open (joins/leaves, rank changes).
	timer.Create( "SWRP.Scoreboard.Refresh", 2, 0, function()
		if not IsValid( board ) or not IsValid( list ) then
			timer.Remove( "SWRP.Scoreboard.Refresh" )
			return
		end
		buildRows( list )
	end )

	return true   -- suppress the default scoreboard
end )

hook.Add( "ScoreboardHide", "SWRP.HUD.ScoreboardHide", function()
	timer.Remove( "SWRP.Scoreboard.Refresh" )
	if IsValid( board ) then
		board:Remove()
		board = nil
	end
end )
