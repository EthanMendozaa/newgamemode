--[[----------------------------------------------------------------------------
	UI module (client) — the component kit.

	Every SWRP interface is assembled from these constructors; none of them
	hardcode a single visual — everything reads SWRP.Theme at draw time, so a
	theme swap (or live edit) restyles the whole gamemode.

	  SWRP.UI.Frame( w, h, title, opts )      -> frame (use frame.Body)
	       opts.noClose  -- no close button (forced-choice dialogs)
	  SWRP.UI.Button( parent, text, variant, onClick )
	  SWRP.UI.Tabs( parent )                  -> tabs:Add( name, buildFn )
	  SWRP.UI.Table( parent, columns )        -> tbl:AddRow( cells, opts )
	  SWRP.UI.Card( parent, title )           -> card (accent-barred panel)
	  SWRP.UI.Bar( parent )                   -> bar:SetFraction( f ) (cooldowns)
	  SWRP.UI.PlayerCard( parent, ply )
	  SWRP.UI.TextEntry( parent )             -> themed DTextEntry

	Variants for Button: "primary" (blue fill), "ghost" (outline, default),
	"danger" (red fill). All interactive elements animate hover via HoverFrac.
------------------------------------------------------------------------------]]

SWRP.UI = SWRP.UI or {}
local UI = SWRP.UI

local function T() return SWRP.Theme end

--------------------------------------------------------------------------------
-- Shared drawing helpers
--------------------------------------------------------------------------------

-- Per-panel animated hover fraction (0..1) for smooth transitions.
-- RealFrameTime: unaffected by host_timescale/pause, the right clock for UI.
function UI.HoverFrac( panel )
	local target = panel:IsHovered() and 1 or 0
	panel._hover = Lerp( RealFrameTime() * T().kit.hoverSpd, panel._hover or 0, target )
	return panel._hover
end

-- Mix two colors by fraction f (0 = a, 1 = b).
function UI.Blend( a, b, f )
	return Color(
		Lerp( f, a.r, b.r ), Lerp( f, a.g, b.g ),
		Lerp( f, a.b, b.b ), Lerp( f, a.a or 255, b.a or 255 ) )
end

-- Screen blur behind a panel (the standard pp/blurscreen pattern).
local blurMat = Material( "pp/blurscreen" )
function UI.DrawBlur( panel, amount )
	if ( amount or 0 ) <= 0 then return end
	local x, y = panel:LocalToScreen( 0, 0 )

	surface.SetDrawColor( 255, 255, 255 )
	surface.SetMaterial( blurMat )
	for i = 1, 3 do
		blurMat:SetFloat( "$blur", ( i / 3 ) * amount )
		blurMat:Recompute()
		render.UpdateScreenEffectTexture()
		surface.DrawTexturedRect( -x, -y, ScrW(), ScrH() )
	end
end

--------------------------------------------------------------------------------
-- Window shell
--------------------------------------------------------------------------------

function UI.Frame( w, h, title, opts )
	opts = opts or {}
	local theme = T()
	local K, S  = theme.kit, theme.spacing

	local f = vgui.Create( "DFrame" )
	f:SetSize( w, h )
	f:Center()
	f:SetTitle( "" )
	f:ShowCloseButton( false )
	f:SetDraggable( true )
	f:MakePopup()

	-- DFrame ships a hidden 24px top dock padding; replace it with ours.
	f:DockPadding( S.pad, K.titleH + S.pad, S.pad, S.pad )

	f.Paint = function( self, fw, fh )
		local C = T().colors
		UI.DrawBlur( self, T().kit.blur )
		draw.RoundedBox( K.radius, 0, 0, fw, fh, C.bg )
		draw.RoundedBoxEx( K.radius, 0, 0, fw, K.titleH, C.titleBar, true, true, false, false )
		surface.SetDrawColor( C.accent )
		surface.DrawRect( 0, K.titleH - 2, fw, 2 )
		draw.SimpleText( string.upper( title or "" ), "SWRP.Title",
			S.pad + 2, K.titleH / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end

	if not opts.noClose then
		local close = vgui.Create( "DButton", f )
		close:SetSize( 44, K.titleH - 2 )
		close:SetPos( w - 44, 0 )
		close:SetText( "" )
		close.Paint = function( self, bw, bh )
			local C = T().colors
			local hf = UI.HoverFrac( self )
			if hf > 0.01 then
				surface.SetDrawColor( UI.Blend( C.titleBar, C.danger, hf ) )
				surface.DrawRect( 0, 0, bw, bh )
			end
			draw.SimpleText( "✕", "SWRP.Sub", bw / 2, bh / 2,
				UI.Blend( C.textDim, C.white, hf ),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
		close.DoClick = function() f:Close() end
	end

	f.Body = vgui.Create( "DPanel", f )
	f.Body:Dock( FILL )
	f.Body.Paint = nil

	return f
end

--------------------------------------------------------------------------------
-- Buttons
--------------------------------------------------------------------------------

function UI.Button( parent, text, variant, onClick )
	variant = variant or "ghost"

	local b = vgui.Create( "DButton", parent )
	b:SetText( "" )
	b:SetTall( T().kit.btnH )
	b:SetCursor( "hand" )
	b.DoClick = onClick

	b.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		local hf = UI.HoverFrac( self )

		if variant == "primary" then
			draw.RoundedBox( K.radius, 0, 0, w, h, UI.Blend( C.accent, C.accentHi, hf ) )
			draw.SimpleText( text, "SWRP.Button", w / 2, h / 2, C.white,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		elseif variant == "danger" then
			draw.RoundedBox( K.radius, 0, 0, w, h, UI.Blend( C.danger, C.dangerHi, hf ) )
			draw.SimpleText( text, "SWRP.Button", w / 2, h / 2, C.white,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		else -- ghost
			draw.RoundedBox( K.radius, 0, 0, w, h, UI.Blend( C.bgLight, C.bgRaised, hf ) )
			surface.SetDrawColor( UI.Blend( C.divider, C.accent, hf ) )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			draw.SimpleText( text, "SWRP.Button", w / 2, h / 2,
				UI.Blend( C.textDim, C.text, hf ),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

	return b
end

--------------------------------------------------------------------------------
-- Tabs
--------------------------------------------------------------------------------

function UI.Tabs( parent )
	local theme = T()

	local wrap = vgui.Create( "DPanel", parent )
	wrap:Dock( FILL )
	wrap.Paint = nil

	local bar = vgui.Create( "DPanel", wrap )
	bar:Dock( TOP )
	bar:SetTall( theme.kit.tabH )
	bar.Paint = function( self, w, h )
		surface.SetDrawColor( T().colors.divider )
		surface.DrawRect( 0, h - 1, w, 1 )
	end

	local content = vgui.Create( "DPanel", wrap )
	content:Dock( FILL )
	content:DockMargin( 0, theme.spacing.pad + 2, 0, 0 )
	content.Paint = nil

	local tabs = { wrap = wrap, content = content, buttons = {}, active = nil }

	function tabs:Select( name )
		self.active = name
		self.content:Clear()
		local entry = self.buttons[ name ]
		if entry then entry.build( self.content ) end
	end

	function tabs:Add( name, build )
		local label = string.upper( name )

		surface.SetFont( "SWRP.Button" )
		local textW = surface.GetTextSize( label )

		local b = vgui.Create( "DButton", bar )
		b:SetText( "" )
		b:Dock( LEFT )
		b:SetWide( textW + 36 )
		b:DockMargin( 0, 0, 6, 5 )
		b:SetCursor( "hand" )

		b.Paint = function( self, w, h )
			local C, K = T().colors, T().kit
			local on = ( tabs.active == name )
			local hf = UI.HoverFrac( self )

			if on then
				draw.RoundedBox( K.radius, 0, 0, w, h, C.accent )
				draw.SimpleText( label, "SWRP.Button", w / 2, h / 2, C.white,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			else
				draw.RoundedBox( K.radius, 0, 0, w, h, UI.Blend( C.bgLight, C.bgRaised, hf ) )
				draw.SimpleText( label, "SWRP.Button", w / 2, h / 2,
					UI.Blend( C.textDim, C.text, hf ),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			end
		end
		b.DoClick = function() tabs:Select( name ) end

		self.buttons[ name ] = { button = b, build = build }
		if not self.active then self:Select( name ) end
		return b
	end

	return tabs
end

--------------------------------------------------------------------------------
-- Roster table
--------------------------------------------------------------------------------

--[[
	columns = { { name = "Name", frac = 0.4 }, { name = "Rank", frac = 0.2 }, ... }
	tbl:AddRow( { "cell", "cell", ... }, opts )
	  opts.dim       -- muted row (offline members)
	  opts.color     -- accent bar + first-cell color (battalion color)
	  opts.buttons   -- { { label, variant, width, onClick }, ... } docked right
	  opts.onClick   -- whole-row click
]]
function UI.Table( parent, columns )
	local theme = T()

	local wrap = vgui.Create( "DPanel", parent )
	wrap:Dock( FILL )
	wrap.Paint = nil

	local header = vgui.Create( "DPanel", wrap )
	header:Dock( TOP )
	header:SetTall( 26 )
	header.Paint = function( self, w, h )
		local C = T().colors
		local x = 0
		for _, col in ipairs( columns ) do
			draw.SimpleText( string.upper( col.name ), "SWRP.Small",
				x + 12, h / 2 - 1, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			x = x + w * col.frac
		end
		surface.SetDrawColor( C.divider )
		surface.DrawRect( 0, h - 1, w, 1 )
	end

	local scroll = vgui.Create( "DScrollPanel", wrap )
	scroll:Dock( FILL )
	scroll:DockMargin( 0, 6, 0, 0 )

	local sbar = scroll:GetVBar()
	sbar:SetWide( 6 )
	sbar.Paint = nil
	sbar.btnUp.Paint, sbar.btnDown.Paint = nil, nil
	sbar.btnGrip.Paint = function( self, w, h )
		draw.RoundedBox( 3, 0, 0, w, h, T().colors.bgRaised )
	end

	local tbl = { wrap = wrap, scroll = scroll }

	function tbl:Clear()
		self.scroll:Clear()
	end

	function tbl:AddRow( cells, opts )
		opts = opts or {}

		local row = vgui.Create( "DPanel" )
		row:SetTall( theme.spacing.rowH )
		row:Dock( TOP )
		row:DockMargin( 0, 0, 0, 4 )

		row.Paint = function( self, w, h )
			local C, K = T().colors, T().kit
			local hf = opts.onClick and UI.HoverFrac( self ) or 0
			draw.RoundedBox( K.radius, 0, 0, w, h, UI.Blend( C.bgLight, C.bgRaised, hf ) )

			if opts.color and not opts.dim then
				surface.SetDrawColor( opts.color )
				surface.DrawRect( 0, 0, K.accentW, h )
			end

			local x = 0
			for i, col in ipairs( columns ) do
				local text = cells[ i ]
				if text ~= nil then
					draw.SimpleText( tostring( text ), "SWRP.Sub",
						x + 12, h / 2,
						opts.dim and C.textDim or ( i == 1 and opts.color or C.text ),
						TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				end
				x = x + w * col.frac
			end
		end

		if opts.onClick then
			row:SetCursor( "hand" )
			row.OnMousePressed = function() opts.onClick() end
		end

		if opts.buttons then
			for i = #opts.buttons, 1, -1 do
				local def = opts.buttons[ i ]
				local b = UI.Button( row, def.label, def.variant or "ghost", def.onClick )
				b:Dock( RIGHT )
				b:SetWide( def.width or 30 )   -- 30 fits glyphs; set width for text
				b:DockMargin( 0, 5, 5, 5 )
			end
		end

		self.scroll:AddItem( row )
		return row
	end

	return tbl
end

--------------------------------------------------------------------------------
-- Card
--------------------------------------------------------------------------------

function UI.Card( parent, title )
	local theme = T()

	local card = vgui.Create( "DPanel", parent )
	card:DockPadding( theme.kit.accentW + theme.spacing.pad, title and 34 or theme.spacing.pad,
		theme.spacing.pad, theme.spacing.pad )

	card._accent = nil
	function card:SetAccent( color ) self._accent = color end

	card.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		draw.RoundedBox( K.radius, 0, 0, w, h, C.bgLight )
		surface.SetDrawColor( self._accent or C.accent )
		surface.DrawRect( 0, 0, K.accentW, h )
		if title then
			draw.SimpleText( string.upper( title ), "SWRP.Small",
				K.accentW + T().spacing.pad, 11, C.textDim )
		end
	end

	return card
end

--------------------------------------------------------------------------------
-- Progress / cooldown bar
--------------------------------------------------------------------------------

function UI.Bar( parent )
	local bar = vgui.Create( "DPanel", parent )
	bar:SetTall( 6 )
	bar._frac  = 1
	bar._color = nil

	function bar:SetFraction( f ) self._frac = math.Clamp( f, 0, 1 ) end
	function bar:SetColor( c )    self._color = c end

	bar.Paint = function( self, w, h )
		local C = T().colors
		draw.RoundedBox( 3, 0, 0, w, h, C.barBack )
		if self._frac > 0 then
			draw.RoundedBox( 3, 0, 0, w * self._frac, h, self._color or C.accent )
		end
	end

	return bar
end

--------------------------------------------------------------------------------
-- Player card (identity from the record's networked values)
--------------------------------------------------------------------------------

function UI.PlayerCard( parent, ply )
	local card = vgui.Create( "DPanel", parent )

	card.Paint = function( self, w, h )
		local C, K, S = T().colors, T().kit, T().spacing
		if not IsValid( ply ) then return end

		local Character   = SWRP.Character
		local battalion   = Character.GetBattalion( ply )
		local rank        = Character.GetRank( ply )
		local designation = Character.GetDesignation( ply )
		local batColor    = battalion and battalion.color or C.textDim

		draw.RoundedBox( K.radius, 0, 0, w, h, C.bgLight )
		surface.SetDrawColor( batColor )
		surface.DrawRect( 0, 0, K.accentW, h )

		local x = K.accentW + S.pad + 2
		draw.SimpleText( Character.GetName( ply ), "SWRP.Name", x, h / 2 - 15, C.text )
		draw.SimpleText(
			( battalion and battalion.name or "No battalion" )
			.. ( rank and ( "  ·  " .. rank.name ) or "" ),
			"SWRP.Sub", x, h / 2 + 12, batColor )

		-- Designation chip, right side
		if designation ~= "" then
			draw.SimpleText( designation, "SWRP.Name",
				w - S.pad - 2, h / 2, C.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end
	end

	return card
end

--------------------------------------------------------------------------------
-- Themed text entry
--------------------------------------------------------------------------------

function UI.TextEntry( parent )
	local entry = vgui.Create( "DTextEntry", parent )
	entry:SetTall( T().kit.btnH )
	entry:SetFont( "SWRP.Sub" )
	entry:SetPaintBackground( false )

	entry.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		draw.RoundedBox( K.radius, 0, 0, w, h, C.barBack )
		surface.SetDrawColor( self:HasFocus() and C.accent or C.divider )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )

		self:SetTextColor( C.text )
		self:SetCursorColor( C.text )
		self:SetHighlightColor( C.accent )
		self:DrawTextEntryText( C.text, C.accent, C.text )
	end

	return entry
end

--------------------------------------------------------------------------------
-- v4 "Republic Terminal" components
--------------------------------------------------------------------------------

--[[
	UI.Terminal() — the full-screen shell every main page lives in.
	Returns t with:
	  t:AddTab( name, build )   -- caps nav tab; first added auto-selects
	  t.Content                 -- the padded workspace panel
	  t:Close()
	ESC (game menu key) closes it; F4 toggling is handled by the menu opener.
]]
function UI.Terminal()
	local theme = T()
	local K, S  = theme.kit, theme.spacing

	local t = vgui.Create( "DFrame" )
	t:SetSize( ScrW(), ScrH() )
	t:SetPos( 0, 0 )
	t:SetTitle( "" )
	t:SetDraggable( false )
	t:ShowCloseButton( false )
	t:MakePopup()

	t.Paint = function( self, w, h )
		local C = T().colors
		UI.DrawBlur( self, T().kit.blur )
		-- Two-tone translucent terminal layer (flat, no gradient cost)
		surface.SetDrawColor( C.termTop )
		surface.DrawRect( 0, 0, w, math.floor( h * 0.45 ) )
		surface.SetDrawColor( C.termBot )
		surface.DrawRect( 0, math.floor( h * 0.45 ), w, h )
	end

	-- ESC closes the terminal instead of opening the game menu.
	t.Think = function( self )
		if gui.IsGameUIVisible() then
			gui.HideGameUI()
			self:Close()
		end
	end

	-- Nav strip -----------------------------------------------------------
	local nav = vgui.Create( "DPanel", t )
	nav:Dock( TOP )
	nav:SetTall( K.navH )
	nav:DockPadding( S.termX, 14, S.termX, 0 )
	nav.Paint = function( self, w, h )
		local C = T().colors
		draw.SimpleText( "SWRP", "SWRP.H2", S.termX, h / 2 - 12, C.text )
		draw.SimpleText( "GRAND ARMY COMMAND", "SWRP.Label", S.termX, h / 2 + 12, C.label )
		draw.SimpleText( "F4 / ESC", "SWRP.Label", w - S.termX, h / 2, C.label,
			TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		surface.SetDrawColor( C.hairline )
		surface.DrawRect( S.termX, h - 1, w - S.termX * 2, 1 )
	end

	local tabBar = vgui.Create( "DPanel", nav )
	tabBar:Dock( FILL )
	tabBar:DockMargin( 130, 0, 90, 0 )
	tabBar.Paint = nil

	local content = vgui.Create( "DPanel", t )
	content:Dock( FILL )
	content:DockPadding( S.termX, S.termY, S.termX, S.termY )
	content.Paint = nil
	t.Content = content

	t._tabs, t._active = {}, nil

	function t:Select( name )
		self._active = name
		self.Content:Clear()
		local tab = self._tabs[ name ]
		if tab then tab.build( self.Content ) end
	end

	function t:AddTab( name, build )
		local label = string.upper( name )

		surface.SetFont( "SWRP.Nav" )
		local textW = surface.GetTextSize( label )

		local b = vgui.Create( "DButton", tabBar )
		b:SetText( "" )
		b:Dock( LEFT )
		b:SetWide( textW + 34 )
		b:SetCursor( "hand" )

		b.Paint = function( self, w, h )
			local C  = T().colors
			local on = ( t._active == name )
			local hf = UI.HoverFrac( self )
			draw.SimpleText( label, "SWRP.Nav", w / 2, h / 2,
				on and C.white or UI.Blend( C.textDim, C.text, hf ),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			if on then
				surface.SetDrawColor( C.accent )
				surface.DrawRect( 10, h - 3, w - 20, 2 )
			end
		end
		b.DoClick = function() t:Select( name ) end

		self._tabs[ name ] = { build = build, button = b }
		if not self._active then self:Select( name ) end
	end

	return t
end

-- Styled right-click menu. items = { { label=, danger=, onClick= }, ... }
function UI.ContextMenu( items )
	local menu = DermaMenu()
	menu.Paint = function( self, w, h )
		local C = T().colors
		draw.RoundedBox( T().kit.radius, 0, 0, w, h, C.bg )
		surface.SetDrawColor( C.divider )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
	end

	for _, item in ipairs( items ) do
		local opt = menu:AddOption( item.label, item.onClick )
		opt:SetTall( 34 )
		opt:SetTextInset( 14, 0 )
		opt:SetFont( "SWRP.Sub" )
		opt.Paint = function( self, w, h )
			local C = T().colors
			if self:IsHovered() then
				surface.SetDrawColor( C.bgRaised )
				surface.DrawRect( 1, 0, w - 2, h )
			end
			self:SetTextColor( item.danger and C.dangerTx or C.textBlue )
		end
	end

	menu:Open()
	return menu
end

-- Hairline fact row (the v4 box-less look): label left, value right of it.
function UI.FactRow( parent, label, value, valueColor )
	local theme = T()

	local row = vgui.Create( "DPanel", parent )
	row:Dock( TOP )
	row:SetTall( theme.spacing.factH )

	row.Paint = function( self, w, h )
		local C = T().colors
		draw.SimpleText( string.upper( label ), "SWRP.Label", 0, h / 2, C.label,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		draw.SimpleText( tostring( value or "—" ), "SWRP.Fact", 190, h / 2,
			valueColor or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		surface.SetDrawColor( C.hairline )
		surface.DrawRect( 0, h - 1, w, 1 )
	end

	function row:SetValue( v, col )
		value, valueColor = v, col or valueColor
	end

	return row
end

-- Steam avatar with rounded backing; bots/unknown get an initials disc.
-- `who` is a Player, or a string used for initials.
function UI.Avatar( parent, who, size )
	size = size or T().kit.avatar

	local wrap = vgui.Create( "DPanel", parent )
	wrap:SetSize( size, size )

	local isPlayer = IsValid( who ) and who.IsPlayer and who:IsPlayer()

	if isPlayer and not who:IsBot() then
		wrap.Paint = nil
		local img = vgui.Create( "AvatarImage", wrap )
		img:Dock( FILL )
		img:SetPlayer( who, size > 32 and 64 or 32 )
	else
		local name = isPlayer and who:Nick() or tostring( who or "?" )
		local init = string.upper( string.sub( name, 1, 2 ) )
		wrap.Paint = function( self, w, h )
			local C = T().colors
			draw.RoundedBox( w / 2, 0, 0, w, h, C.bgRaised )
			draw.SimpleText( init, "SWRP.Label", w / 2, h / 2, C.textBlue,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

	return wrap
end

-- Posed model viewer (character tab, class cards). Returns the DModelPanel.
function UI.ModelView( parent, model )
	local mdl = vgui.Create( "DModelPanel", parent )
	mdl:SetModel( model or "models/player/group01/male_02.mdl" )
	mdl:SetFOV( 36 )
	mdl:SetCamPos( Vector( 78, 6, 46 ) )
	mdl:SetLookAt( Vector( 0, 0, 40 ) )
	mdl:SetAnimated( false )

	function mdl:LayoutEntity( ent )
		ent:SetAngles( Angle( 0, 32 + math.sin( RealTime() * 0.4 ) * 14, 0 ) )
	end

	mdl.PaintOver = function() end
	return mdl
end

--[[
	Class card (v4): big model thumb on top, name + stats, one CTA bar.
	data = { name, tag, health, armor, max, used, eligible, reason, current,
	         model, onUse }
]]
function UI.ClassCard( parent, data )
	local theme = T()

	local card = vgui.Create( "DPanel", parent )
	card:SetAlpha( ( data.eligible or data.current ) and 255 or 150 )

	card.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		draw.RoundedBox( K.radius, 0, 0, w, h, C.bgLight )
		surface.SetDrawColor( data.current and C.gold or C.divider )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
	end

	local thumb = vgui.Create( "DPanel", card )
	thumb:Dock( FILL )
	thumb:DockMargin( 1, 1, 1, 0 )
	thumb.Paint = function( self, w, h )
		surface.SetDrawColor( T().colors.modelBg )
		surface.DrawRect( 0, 0, w, h )
	end

	if data.model then
		local mdl = UI.ModelView( thumb, data.model )
		mdl:Dock( FILL )
		mdl:SetCamPos( Vector( 64, 4, 42 ) )
	end

	local info = vgui.Create( "DPanel", card )
	info:Dock( BOTTOM )
	info:SetTall( 96 )
	info.Paint = function( self, w, h )
		local C = T().colors
		local title = string.upper( data.name )
		draw.SimpleText( title, "SWRP.Name", 16, 14, C.text )

		local x = 16
		local function stat( label, v )
			draw.SimpleText( label .. " ", "SWRP.Label", x, 44, C.label )
			surface.SetFont( "SWRP.Label" )
			local lw = surface.GetTextSize( label .. " " )
			draw.SimpleText( tostring( v ), "SWRP.Small", x + lw, 42, C.textBlue )
			x = x + lw + 46
		end
		stat( "HP", data.health )
		stat( "ARMOR", data.armor )
		if data.max then stat( "SLOTS", ( data.used or 0 ) .. "/" .. data.max ) end
	end

	local cta = vgui.Create( "DButton", info )
	cta:SetText( "" )
	cta:Dock( BOTTOM )
	cta:SetTall( 34 )
	cta:DockMargin( 14, 0, 14, 12 )

	cta.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		if data.current then
			surface.SetDrawColor( C.gold )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			draw.SimpleText( "CURRENT CLASS", "SWRP.Button", w / 2, h / 2, C.gold,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		elseif data.eligible then
			local hf = UI.HoverFrac( self )
			draw.RoundedBox( K.radius, 0, 0, w, h, UI.Blend( C.accent, C.accentHi, hf ) )
			draw.SimpleText( "BECOME " .. string.upper( data.name ), "SWRP.Button",
				w / 2, h / 2, C.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		else
			surface.SetDrawColor( C.divider )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			draw.SimpleText( string.upper( data.reason or "Unavailable" ), "SWRP.Label",
				w / 2, h / 2, C.label, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

	cta.DoClick = function()
		if not data.current and data.eligible and data.onUse then data.onUse() end
	end
	if data.eligible and not data.current then cta:SetCursor( "hand" ) end

	return card
end
