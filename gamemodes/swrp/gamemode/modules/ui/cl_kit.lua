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
