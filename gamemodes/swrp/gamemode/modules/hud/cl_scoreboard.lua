--[[----------------------------------------------------------------------------
	HUD module (client) — scoreboard.

	Minimal pre-UI-kit scoreboard: every row renders the DERIVED identity
	(name, battalion, rank) straight from the record's networked values —
	nothing comes from Steam names or teams. Rebuilt on the UI kit in Phase 2.
------------------------------------------------------------------------------]]

local Character = SWRP.Character

local board = nil

local function buildRows( list )
	list:Clear()

	local players = player.GetAll()
	table.sort( players, function( a, b )
		local ba = a:GetNW2String( "SWRPBattalion", "" )
		local bb = b:GetNW2String( "SWRPBattalion", "" )
		if ba ~= bb then return ba < bb end
		return Character.GetName( a ) < Character.GetName( b )
	end )

	local T = SWRP.Theme

	for _, ply in ipairs( players ) do
		-- Identity is resolved ONCE per rebuild (every 2s), not per paint frame
		-- — only ping is read live.
		local battalion = Character.GetBattalion( ply )
		local rank      = Character.GetRank( ply )
		local name      = Character.GetName( ply )
		local batName   = battalion and battalion.name or "—"
		local rankName  = rank and rank.name or "—"
		local batColor  = battalion and battalion.color or T.colors.textDim

		local row = vgui.Create( "DPanel" )
		row:SetTall( T.spacing.rowH )
		row:Dock( TOP )
		row:DockMargin( 0, 0, 0, 2 )

		row.Paint = function( self, w, h )
			if not IsValid( ply ) then return end
			local C = T.colors

			draw.RoundedBox( 4, 0, 0, w, h, C.bgLight )
			draw.RoundedBox( 0, 0, 0, 4, h, batColor )

			draw.SimpleText( name, "SWRP.Sub",
				12, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

			draw.SimpleText( batName, "SWRP.Small",
				w * 0.55, h / 2, batColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

			draw.SimpleText( rankName, "SWRP.Small",
				w * 0.78, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

			draw.SimpleText( ply:Ping(), "SWRP.Small",
				w - 12, h / 2, C.textDim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end

		list:AddItem( row )
	end
end

hook.Add( "ScoreboardShow", "SWRP.HUD.Scoreboard", function()
	local T = SWRP.Theme
	local C = T.colors

	if IsValid( board ) then board:Remove() end

	board = vgui.Create( "DFrame" )
	board:SetSize( math.min( 700, ScrW() * 0.6 ), math.min( 600, ScrH() * 0.7 ) )
	board:Center()
	board:SetTitle( "" )
	board:SetDraggable( false )
	board:ShowCloseButton( false )

	board.Paint = function( self, w, h )
		draw.RoundedBox( 8, 0, 0, w, h, C.bg )
		draw.SimpleText( GetHostName(), "SWRP.Name", w / 2, 14, C.text,
			TEXT_ALIGN_CENTER )
		draw.SimpleText( #player.GetAll() .. " personnel online", "SWRP.Small",
			w / 2, 38, C.textDim, TEXT_ALIGN_CENTER )
	end

	local list = vgui.Create( "DScrollPanel", board )
	list:Dock( FILL )
	list:DockMargin( T.spacing.pad, 56, T.spacing.pad, T.spacing.pad )

	buildRows( list )

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
	-- No return value: ScoreboardHide has no documented return semantics, and
	-- the base scoreboard was never shown anyway.
end )
