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

	-- Dialogs float above a dimmed veil and ease in (created before the frame
	-- so it sits underneath).
	local veil = not opts.noVeil and UI.Veil() or nil

	local f = vgui.Create( "DFrame" )
	f:SetSize( w, h )
	f:Center()
	f:SetTitle( "" )
	f:ShowCloseButton( false )
	f:SetDraggable( true )
	f:MakePopup()
	UI.PopIn( f )

	f.OnRemove = function()
		if IsValid( veil ) then
			veil:AlphaTo( 0, 0.12, 0, function()
				if IsValid( veil ) then veil:Remove() end
			end )
		end
	end

	-- DFrame ships a hidden 24px top dock padding; replace it with ours.
	f:DockPadding( S.pad, K.titleH + S.pad, S.pad, S.pad )

	f.Paint = function( self, fw, fh )
		local C = T().colors
		UI.Shadow( K.radius, 0, 0, fw, fh )
		UI.BlurRect( K.radius, 0, 0, fw, fh )
		UI.Rect( K.radius, 0, 0, fw, fh, C.bg )
		UI.RectGrad( K.radius, 0, 0, fw, K.titleH, C.titleBar, 12 )
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
		local hf    = UI.HoverFrac( self )
		local down  = self:IsDown()
		local press = down and 1 or 0   -- press: darken + nudge the label

		if variant == "primary" or variant == "danger" then
			local base = variant == "danger" and C.danger or C.accent
			local hi   = variant == "danger" and C.dangerHi or C.accentHi

			if hf > 0.02 and not down then
				UI.Glow( K.radius, 0, 0, w, h,
					ColorAlpha( base, 90 * hf ), 10, 14 )
			end
			UI.RectGrad( K.radius, 0, 0, w, h, UI.Blend( base, hi, hf ), down and 6 or 22 )
			if down then UI.Rect( K.radius, 0, 0, w, h, Color( 0, 0, 0, 50 ) ) end

			draw.SimpleText( text, "SWRP.Button", w / 2, h / 2 + press, C.white,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		else -- ghost
			UI.Rect( K.radius, 0, 0, w, h, UI.Blend( C.bgLight, C.bgRaised, hf ) )
			if down then UI.Rect( K.radius, 0, 0, w, h, Color( 0, 0, 0, 40 ) ) end
			surface.SetDrawColor( UI.Blend( C.divider, C.accent, hf ) )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			draw.SimpleText( text, "SWRP.Button", w / 2, h / 2 + press,
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
				UI.Rect( K.radius, 0, 0, w, h, C.accent )
				draw.SimpleText( label, "SWRP.Button", w / 2, h / 2, C.white,
					TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
			else
				UI.Rect( K.radius, 0, 0, w, h, UI.Blend( C.bgLight, C.bgRaised, hf ) )
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
	UI.Scrollbar( scroll )

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
			UI.Rect( K.radius, 0, 0, w, h, UI.Blend( C.bgLight, C.bgRaised, hf ) )

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
		UI.Rect( K.radius, 0, 0, w, h, C.bgLight )
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
		UI.Rect( 3, 0, 0, w, h, C.barBack )
		if self._frac > 0 then
			UI.Rect( 3, 0, 0, w * self._frac, h, self._color or C.accent )
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

		UI.Rect( K.radius, 0, 0, w, h, C.bgLight )
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
		UI.Rect( K.radius, 0, 0, w, h, C.barBack )
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

	-- Ease in (fade only — the terminal owns the whole screen).
	t:SetAlpha( 0 )
	t:AlphaTo( 255, 0.14 )

	local gradUp = Material( "vgui/gradient-u" )
	t.Paint = function( self, w, h )
		local C = T().colors
		-- Opaque designed surface (matches the mockups; no world bleed, no
		-- blur cost). Base + top-lightening gradient = seamless navy ramp.
		surface.SetDrawColor( C.termBot )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( C.termTop )
		surface.SetMaterial( gradUp )
		surface.DrawTexturedRect( 0, 0, w, math.floor( h * 0.6 ) )
	end

	-- ESC closes the terminal instead of opening the game menu.
	-- (OnPauseMenuShow: return false suppresses the pause menu — the supported
	-- replacement for the deprecated gui.HideGameUI pattern.)
	local escHook = "SWRP.Terminal.Esc." .. tostring( t )
	hook.Add( "OnPauseMenuShow", escHook, function()
		if not IsValid( t ) then
			hook.Remove( "OnPauseMenuShow", escHook )
			return
		end
		t:Close()
		return false
	end )
	t.OnRemove = function()
		hook.Remove( "OnPauseMenuShow", escHook )
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
	-- 210: clears the "GRAND ARMY COMMAND" brand sublabel (collided at 130).
	tabBar:DockMargin( 210, 0, 90, 0 )

	-- SLIDING active indicator: one glowing underline that eases between tabs
	-- (per-button static underlines snap — the Derma feel).
	tabBar.Paint = function( self, w, h )
		local active = t._tabs[ t._active ]
		if not ( active and IsValid( active.button ) ) then return end

		local C  = T().colors
		local bx = active.button:GetX()
		local bw = active.button:GetWide()
		local tx, tw = bx + 12, bw - 24

		self._ulX = Lerp( RealFrameTime() * 14, self._ulX or tx, tx )
		self._ulW = Lerp( RealFrameTime() * 14, self._ulW or tw, tw )

		UI.Glow( 2, self._ulX, h - 3, self._ulW, 2, ColorAlpha( C.accent, 120 ), 8, 12 )
		surface.SetDrawColor( C.accent )
		surface.DrawRect( self._ulX, h - 3, self._ulW, 2 )
	end

	-- Identity strip (v6): green caps identity on every tab (the AotR line).
	local ident = vgui.Create( "DPanel", t )
	ident:Dock( TOP )
	ident:SetTall( K.identH )
	ident.Paint = function( self, w, h )
		local C  = T().colors
		local lp = LocalPlayer()
		local Character = SWRP.Character
		if not ( Character and Character.GetName and IsValid( lp ) ) then return end

		local desig = Character.GetDesignation( lp )
		local base  = string.match( Character.GetName( lp ), "(%S+)$" ) or lp:Nick()
		local left  = ( desig ~= "" and ( "CT-" .. desig .. "  " ) or "" )
			.. "“" .. string.upper( base ) .. "”"
		draw.SimpleText( left, "SWRP.Nav", S.termX, h / 2, C.presence,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

		local battalion = Character.GetBattalion( lp )
		local rank      = Character.GetRank( lp )
		local className
		if SWRP.Class then
			local a = SWRP.Class.GetAssignment( Character.GetClassId( lp ) )
			if a then className = SWRP.Class.Resolve( a ).name end
		end

		surface.SetFont( "SWRP.Nav" )
		local lw = surface.GetTextSize( left )
		draw.SimpleText( string.upper(
			( battalion and battalion.name or "UNASSIGNED" )
			.. ( rank and ( " · " .. rank.name ) or "" )
			.. ( className and ( " · " .. className ) or "" ) ),
			"SWRP.Label", S.termX + lw + 16, h / 2 + 1, C.presenceDim,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

		surface.SetDrawColor( C.hairline )
		surface.DrawRect( S.termX, h - 1, w - S.termX * 2, 1 )
	end

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
		if tab then
			tab.build( self.Content )
			UI.FadeIn( self.Content, 0, 0.14 )   -- tab transition
		end
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
		UI.Shadow( T().kit.radius, 0, 0, w, h, 12, 16 )
		UI.Rect( T().kit.radius, 0, 0, w, h, C.bg )
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
	UI.PopIn( menu, 0, 6 )
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

-- TRUE circular Steam avatar (stencil-masked, the Circles.lua pattern);
-- bots/offline entries get an antialiased initials disc.
-- `who` is a Player, or a string used for initials.
function UI.Avatar( parent, who, size )
	size = size or T().kit.avatar

	local wrap = vgui.Create( "DPanel", parent )
	wrap:SetSize( size, size )

	local isPlayer = IsValid( who ) and who.IsPlayer and who:IsPlayer()

	if isPlayer and not who:IsBot() and SWRP.Circles then
		local mask = SWRP.Circles.New( CIRCLE_FILLED, size / 2, size / 2, size / 2 )
		mask:SetDistance( 1 )

		local img = vgui.Create( "AvatarImage", wrap )
		img:Dock( FILL )
		img:SetPlayer( who, size > 32 and 64 or 32 )
		img:SetPaintedManually( true )

		wrap.Paint = function( self, w, h )
			render.ClearStencil()
			render.SetStencilEnable( true )
			render.SetStencilWriteMask( 1 )
			render.SetStencilTestMask( 1 )

			render.SetStencilFailOperation( STENCILOPERATION_REPLACE )
			render.SetStencilPassOperation( STENCILOPERATION_ZERO )
			render.SetStencilZFailOperation( STENCILOPERATION_ZERO )
			render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_NEVER )
			render.SetStencilReferenceValue( 1 )

			draw.NoTexture()
			surface.SetDrawColor( 255, 255, 255 )
			mask()

			render.SetStencilFailOperation( STENCILOPERATION_ZERO )
			render.SetStencilPassOperation( STENCILOPERATION_REPLACE )
			render.SetStencilZFailOperation( STENCILOPERATION_ZERO )
			render.SetStencilCompareFunction( STENCILCOMPARISONFUNCTION_EQUAL )
			render.SetStencilReferenceValue( 1 )

			img:PaintManual()

			render.SetStencilEnable( false )
			render.ClearStencil()
		end
	else
		local name = isPlayer and who:Nick() or tostring( who or "?" )
		local init = string.upper( string.sub( name, 1, 2 ) )
		wrap.Paint = function( self, w, h )
			local C = T().colors
			UI.Dot( w / 2, h / 2, w, C.bgRaised )
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
	-- Tight full-body framing (playtest: the model floated small in the panel).
	mdl:SetFOV( 28 )
	mdl:SetCamPos( Vector( 88, 4, 42 ) )
	mdl:SetLookAt( Vector( 0, 0, 38 ) )
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
		UI.Rect( K.radius, 0, 0, w, h, C.bgLight )
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

	-- 118 tall: title 12, stats 46, CTA 64..98 — playtest showed the CTA's top
	-- border striking through the stats line at 96.
	local info = vgui.Create( "DPanel", card )
	info:Dock( BOTTOM )
	info:SetTall( 118 )
	info.Paint = function( self, w, h )
		local C = T().colors
		local title = string.upper( data.name )
		draw.SimpleText( title, "SWRP.Name", 16, 10, C.text )

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
	cta:SetTall( 36 )
	cta:DockMargin( 14, 0, 14, 14 )

	cta.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		if data.current then
			surface.SetDrawColor( C.gold )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			draw.SimpleText( "CURRENT CLASS", "SWRP.Button", w / 2, h / 2, C.gold,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		elseif data.eligible then
			local hf = UI.HoverFrac( self )
			UI.Rect( K.radius, 0, 0, w, h, UI.Blend( C.accent, C.accentHi, hf ) )
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

--------------------------------------------------------------------------------
-- Smooth rendering (vendored RNDX + Circles, core/cl_rndx.lua + cl_circles.lua)
--
-- Every shape in the kit routes through these: shader-antialiased rounded
-- rects/circles, soft shadows, rounded blur, and animated rings. If the
-- shader GMA ever fails to mount, everything falls back to stock draw.* —
-- the UI degrades, never breaks.
--------------------------------------------------------------------------------

-- Antialiased rounded rect; drop-in for draw.RoundedBox.
function UI.Rect( rad, x, y, w, h, col )
	local R = SWRP.RNDX
	if R then R.Draw( rad, x, y, w, h, col ) return end
	draw.RoundedBox( rad, x, y, w, h, col )
end

-- Top-corners-only rounded rect (title bars, header bands).
function UI.RectTop( rad, x, y, w, h, col )
	local R = SWRP.RNDX
	if R then R.Draw( rad, x, y, w, h, col, R.NO_BL + R.NO_BR ) return end
	draw.RoundedBoxEx( rad, x, y, w, h, col, true, true, false, false )
end

-- Filled circle (status dots, initials discs). d = diameter, centered.
function UI.Dot( cx, cy, d, col )
	local R = SWRP.RNDX
	if R then R.DrawCircle( cx, cy, d, col ) return end
	UI.Rect( d / 2, cx - d / 2, cy - d / 2, d, d, col )
end

-- Animated arc ring (cooldowns/countdowns). frac 0..1, d = diameter.
function UI.Ring( cx, cy, d, thickness, frac, col )
	local R = SWRP.RNDX
	if not R then   -- fallback: plain outline, no arc
		surface.SetDrawColor( col )
		surface.DrawOutlinedRect( cx - d / 2, cy - d / 2, d, d, thickness )
		return
	end
	R().Circle( cx, cy, d )
		:Outline( thickness )
		:StartAngle( -90 )
		:EndAngle( -90 + 360 * math.Clamp( frac, 0, 1 ) )
		:Color( col )
		:Draw()
end

-- Soft drop shadow behind a panel-shaped rect.
function UI.Shadow( rad, x, y, w, h, spread, intensity )
	local R = SWRP.RNDX
	if not R then return end
	R.DrawShadows( rad, x, y, w, h, T().colors.outline, spread or 18, intensity or 22 )
end

-- Rounded blur matching a panel rect (windows); fullscreen surfaces keep
-- UI.DrawBlur (pp/blurscreen covers the whole screen anyway).
function UI.BlurRect( rad, x, y, w, h )
	local R = SWRP.RNDX
	if R then R.DrawBlur( x, y, w, h, 0, rad, rad, rad, rad ) return end
end

--------------------------------------------------------------------------------
-- Motion & depth layer ("it must not feel like Derma")
--
-- Every surface animates in, interactive elements glow and depress, lists
-- stagger, dialogs float over a dimmed veil. All durations are short
-- (120-220ms) — motion you feel, never wait for.
--------------------------------------------------------------------------------

local sheenMat = Material( "vgui/gradient-u" )

-- Rounded rect with a top-light sheen (subtle vertical gradient = depth).
function UI.RectGrad( rad, x, y, w, h, col, sheen )
	UI.Rect( rad, x, y, w, h, col )
	local R = SWRP.RNDX
	if not R then return end
	R().Rect( x, y, w, h ):Rad( rad ):Material( sheenMat )
		:Color( 255, 255, 255, sheen or 16 ):Draw()
end

-- Colored outer glow (hover emphasis on primary actions, active indicators).
function UI.Glow( rad, x, y, w, h, col, spread, intensity )
	local R = SWRP.RNDX
	if not R then return end
	R.DrawShadows( rad, x, y, w, h, col, spread or 12, intensity or 16 )
end

local function reducedMotion()
	return SWRP.Prefs and SWRP.Prefs.Get( "reduced_motion", false ) or false
end

-- Fade-in for DOCKED elements (docking owns position; alpha is ours).
function UI.FadeIn( panel, delay, dur )
	if reducedMotion() then panel:SetAlpha( 255 ) return end
	panel:SetAlpha( 0 )
	panel:AlphaTo( 255, dur or 0.18, delay or 0 )
end

-- Fade + upward slide for FLOATING elements (frames, menus, toasts).
function UI.PopIn( panel, delay, dist )
	if reducedMotion() then return end
	local x, y = panel:GetPos()
	panel:SetAlpha( 0 )
	panel:AlphaTo( 255, 0.16, delay or 0 )
	panel:SetPos( x, y + ( dist or 14 ) )
	panel:MoveTo( x, y, 0.2, delay or 0, 0.3 )
end

-- Stagger delay for the i-th list item (capped so long lists don't crawl).
function UI.Stagger( i )
	if reducedMotion() then return 0 end
	return math.min( ( i - 1 ) * 0.025, 0.25 )
end

-- Dimmed fullscreen veil behind a dialog. Removed via the returned handle.
function UI.Veil()
	local v = vgui.Create( "DPanel" )
	v:SetSize( ScrW(), ScrH() )
	v:SetPos( 0, 0 )
	v:SetMouseInputEnabled( true )   -- swallow clicks behind the dialog
	v.Paint = function( self, w, h )
		surface.SetDrawColor( 8, 11, 20, 150 )
		surface.DrawRect( 0, 0, w, h )
	end
	v:SetAlpha( 0 )
	v:AlphaTo( 255, 0.15 )
	return v
end

-- One thin, quiet scrollbar everywhere (the chunky DVScrollBar is the
-- loudest "this is Derma" tell).
function UI.Scrollbar( scrollPanel )
	local sbar = scrollPanel:GetVBar()
	sbar:SetWide( 4 )
	sbar:SetHideButtons( true )
	sbar.Paint = nil
	sbar.btnGrip.Paint = function( self, w, h )
		UI.Rect( 2, 0, 0, w, h, T().colors.bgRaised )
	end
	return sbar
end

--------------------------------------------------------------------------------
-- v6 "AotR" components
--------------------------------------------------------------------------------

--[[
	UI.SlotCell( parent, label ) — labeled thin-stroke cell (the AotR equipment
	slot language). Size/dock it yourself.
	  cell:SetValue( text, color )  -- centered main line
	  cell:SetSub( text )           -- small second line (optional)
	  cell:SetAccent( color )       -- border tint (gold = lore, presence = equipped)
]]
function UI.SlotCell( parent, label )
	local cell = vgui.Create( "DPanel", parent )
	local labelUp = string.upper( label )
	cell._value = "—"

	function cell:SetValue( v, col ) self._value, self._valueCol = v, col end
	function cell:SetSub( s )        self._sub = s end
	function cell:SetAccent( c )     self._accent = c end

	cell.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		draw.SimpleText( labelUp, "SWRP.Label", 1, 0, C.label )

		local by = 18   -- box starts under the micro-label
		UI.Rect( K.radius, 0, by, w, h - by, C.cell )
		surface.SetDrawColor( self._accent or C.cellBorder )
		surface.DrawOutlinedRect( 0, by, w, h - by, 1 )

		local cy = by + ( h - by ) / 2
		draw.SimpleText( tostring( self._value ), "SWRP.Sub", w / 2,
			cy - ( self._sub and 8 or 0 ),
			self._valueCol or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		if self._sub then
			draw.SimpleText( self._sub, "SWRP.Small", w / 2, cy + 12,
				C.textDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

	return cell
end

--[[
	UI.RingGauge( parent ) — circular gauge (the AotR level ring). Square panel;
	size it yourself, the ring fits the smaller dimension.
	  ring:SetFraction( f )          -- 0..1, eases toward the target
	  ring:SetCenter( big, small )   -- center statement + micro-label
	  ring:SetColor( col )           -- arc color (default accent)
]]
function UI.RingGauge( parent )
	local ring = vgui.Create( "DPanel", parent )
	ring._frac, ring._anim, ring._big = 0, 0, ""

	function ring:SetFraction( f )        self._frac = math.Clamp( f or 0, 0, 1 ) end
	function ring:SetCenter( big, small ) self._big, self._small = big, small end
	function ring:SetColor( c )           self._color = c end

	ring.Paint = function( self, w, h )
		local C = T().colors
		self._anim = Lerp( RealFrameTime() * 6, self._anim, self._frac )

		if SWRP.RNDX then
			local d = math.min( w, h ) - 8
			UI.Ring( w / 2, h / 2, d, 4, 1, C.hairline )                       -- track
			UI.Ring( w / 2, h / 2, d, 4, self._anim, self._color or C.accent ) -- fill
		else
			-- No shader arcs: an honest bar beats a ring stuck at 100%.
			local frac = math.Clamp( self._anim, 0, 1 )
			UI.Rect( 2, 8, h - 12, w - 16, 4, C.hairline )
			UI.Rect( 2, 8, h - 12, ( w - 16 ) * frac, 4, self._color or C.accent )
		end

		draw.SimpleText( tostring( self._big ), "SWRP.Display", w / 2,
			h / 2 - ( self._small and 10 or 0 ),
			C.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		if self._small then
			draw.SimpleText( string.upper( self._small ), "SWRP.Label", w / 2, h / 2 + 22,
				C.label, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		end
	end

	return ring
end
