--[[----------------------------------------------------------------------------
	Prefs module (client) — the Settings terminal tab (UI v6).
	Left: preference toggle cells grouped by category. Right: quick links
	(config-driven, swrp_customthings/news.lua).
------------------------------------------------------------------------------]]

local Prefs = SWRP.Prefs
local UI    = SWRP.UI

local function categoryHeader( parent, text )
	local head = vgui.Create( "DPanel", parent )
	head:Dock( TOP )
	head:SetTall( 30 )
	head:DockMargin( 0, 8, 0, 6 )
	head.Paint = function( self, w, h )
		local C = SWRP.Theme.colors
		draw.SimpleText( string.upper( text ), "SWRP.Label", 0, h - 12, C.label )
	end
end

local function toggleRow( parent, def, i )
	local row = vgui.Create( "DPanel", parent )
	row:Dock( TOP )
	row:SetTall( 44 )
	row:DockMargin( 0, 0, 0, 8 )
	row:SetCursor( "hand" )

	row.Paint = function( self, w, h )
		local C, K = SWRP.Theme.colors, SWRP.Theme.kit
		local hf = UI.HoverFrac( self )
		UI.Rect( K.radius, 0, 0, w, h, UI.Blend( C.cell, C.bgRaised, hf * 0.6 ) )
		surface.SetDrawColor( C.cellBorder )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )

		draw.SimpleText( def.label, "SWRP.Sub", 14, h / 2, C.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

		local on = Prefs.Get( def.key, def.default )
		draw.SimpleText( on and "ON" or "OFF", "SWRP.Button", w - 14, h / 2,
			on and C.presence or C.label, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end

	row.OnMousePressed = function()
		Prefs.Set( def.key, not Prefs.Get( def.key, def.default ) )
	end

	UI.FadeIn( row, UI.Stagger( i ) )
end

local function linkCell( parent, link, i )
	local b = vgui.Create( "DButton", parent )
	b:SetText( "" )
	b:Dock( TOP )
	b:SetTall( 84 )
	b:DockMargin( 0, 0, 0, 14 )
	b:SetCursor( "hand" )

	b.Paint = function( self, w, h )
		local C, K = SWRP.Theme.colors, SWRP.Theme.kit
		local hf  = UI.HoverFrac( self )
		local col = link.color or C.accent
		UI.RectGrad( K.radius, 0, 0, w, h,
			UI.Blend( C.cell, col, 0.18 + 0.10 * hf ), 14 )
		surface.SetDrawColor( UI.Blend( C.cellBorder, col, 0.4 + 0.6 * hf ) )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
		surface.SetDrawColor( col )
		surface.DrawRect( 0, 0, 4, h )
		draw.SimpleText( string.upper( link.label ), "SWRP.H2", 22, h / 2, C.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		draw.SimpleText( link.url, "SWRP.Label", w - 16, h - 8, C.label,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM )
	end

	b.DoClick = function() gui.OpenURL( link.url ) end
	UI.FadeIn( b, UI.Stagger( i ) )
end

UI.RegisterMenuTab( {
	id    = "settings",
	name  = "Settings",
	order = 95,
	build = function( panel )
		local C = SWRP.Theme.colors

		-- Left: toggles grouped by category ------------------------------------
		local left = vgui.Create( "DPanel", panel )
		left:Dock( LEFT )
		left:SetWide( math.floor( ScrW() * 0.32 ) )
		left:DockMargin( 0, 0, 50, 0 )
		left.Paint = nil

		local scroll = vgui.Create( "DScrollPanel", left )
		scroll:Dock( FILL )
		UI.Scrollbar( scroll )

		local lastCat, i = nil, 0
		for _, def in ipairs( Prefs.Defs ) do
			if def.category ~= lastCat then
				lastCat = def.category
				categoryHeader( scroll, def.category )
			end
			i = i + 1
			toggleRow( scroll, def, i )
		end

		-- Right: quick links ----------------------------------------------------
		local right = vgui.Create( "DPanel", panel )
		right:Dock( LEFT )
		right:SetWide( math.floor( ScrW() * 0.28 ) )
		right:DockPadding( 0, 26, 0, 0 )
		right.Paint = function( self, w, h )
			draw.SimpleText( "QUICK LINKS", "SWRP.Label", 0, 0, C.label )
		end

		local links = SWRP.News and SWRP.News.OrderedLinks() or {}
		for j, link in ipairs( links ) do
			linkCell( right, link, j )
		end
		if #links == 0 then
			local lbl = vgui.Create( "DLabel", right )
			lbl:SetFont( "SWRP.Sub" )
			lbl:SetTextColor( C.textDim )
			lbl:SetText( "Add links with SWRP.addQuickLink in swrp_customthings/news.lua." )
			lbl:Dock( TOP )
		end
	end,
} )
