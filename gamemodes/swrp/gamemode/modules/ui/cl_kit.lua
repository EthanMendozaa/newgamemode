--[[----------------------------------------------------------------------------
	UI module (client) — the component kit.

	Every SWRP interface is assembled from these constructors; none of them
	hardcode a single visual — everything reads SWRP.Theme at draw time, so
	a theme swap (or live edit) restyles the whole gamemode.

	  SWRP.UI.Frame( w, h, title )            -> frame (use frame.Body)
	  SWRP.UI.Button( parent, text, variant, onClick )
	  SWRP.UI.Tabs( parent )                  -> tabs:Add( name, buildFn )
	  SWRP.UI.Table( parent, columns )        -> tbl:AddRow( cells, opts )
	  SWRP.UI.Card( parent, title )           -> card (accent-barred panel)
	  SWRP.UI.Bar( parent )                   -> bar:SetFraction( f ) (cooldowns)
	  SWRP.UI.PlayerCard( parent, ply )

	Variants for Button: "primary" (blue fill), "ghost" (outline, default),
	"danger" (red fill).
------------------------------------------------------------------------------]]

SWRP.UI = SWRP.UI or {}
local UI = SWRP.UI

local function T()  return SWRP.Theme end

--------------------------------------------------------------------------------
-- Window shell
--------------------------------------------------------------------------------

function UI.Frame( w, h, title )
	local theme = T()

	local f = vgui.Create( "DFrame" )
	f:SetSize( w, h )
	f:Center()
	f:SetTitle( "" )
	f:ShowCloseButton( false )
	f:SetDraggable( true )
	f:MakePopup()

	f.Paint = function( self, fw, fh )
		local C, K = T().colors, T().kit
		draw.RoundedBox( K.radius, 0, 0, fw, fh, C.bg )
		draw.RoundedBoxEx( K.radius, 0, 0, fw, K.titleH, C.titleBar, true, true, false, false )
		surface.SetDrawColor( C.accent )
		surface.DrawRect( 0, K.titleH - 2, fw, 2 )
		draw.SimpleText( string.upper( title or "" ), "SWRP.Title",
			12, K.titleH / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end

	local close = vgui.Create( "DButton", f )
	close:SetSize( theme.kit.titleH, theme.kit.titleH - 2 )
	close:SetPos( w - theme.kit.titleH, 0 )
	close:SetText( "" )
	close.Paint = function( self, bw, bh )
		local C = T().colors
		if self:IsHovered() then
			surface.SetDrawColor( C.danger )
			surface.DrawRect( 0, 0, bw, bh )
		end
		draw.SimpleText( "✕", "SWRP.Sub", bw / 2, bh / 2,
			self:IsHovered() and C.white or C.textDim,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
	close.DoClick = function() f:Close() end

	f.Body = vgui.Create( "DPanel", f )
	f.Body:Dock( FILL )
	f.Body:DockMargin( theme.spacing.pad, theme.kit.titleH + theme.spacing.pad - 24,
		theme.spacing.pad, theme.spacing.pad )
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
	b.DoClick = onClick

	b.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		local hovered = self:IsHovered()

		if variant == "primary" then
			draw.RoundedBox( K.radius, 0, 0, w, h, hovered and C.accentHi or C.accent )
			draw.SimpleText( text, "SWRP.Button", w / 2, h / 2, C.white,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		elseif variant == "danger" then
			draw.RoundedBox( K.radius, 0, 0, w, h, hovered and C.dangerHi or C.danger )
			draw.SimpleText( text, "SWRP.Button", w / 2, h / 2, C.white,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		else -- ghost
			draw.RoundedBox( K.radius, 0, 0, w, h, hovered and C.bgRaised or C.bgLight )
			surface.SetDrawColor( hovered and C.accent or C.bgRaised )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			draw.SimpleText( text, "SWRP.Button", w / 2, h / 2,
				hovered and C.text or C.textDim,
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
	bar.Paint = nil

	local content = vgui.Create( "DPanel", wrap )
	content:Dock( FILL )
	content:DockMargin( 0, theme.spacing.pad, 0, 0 )
	content.Paint = nil

	local tabs = { wrap = wrap, content = content, buttons = {}, active = nil }

	function tabs:Select( name )
		self.active = name
		self.content:Clear()
		local entry = self.buttons[ name ]
		if entry then entry.build( self.content ) end
	end

	function tabs:Add( name, build )
		local b = vgui.Create( "DButton", bar )
		b:SetText( "" )
		b:Dock( LEFT )
		b:SetWide( 110 )
		b:DockMargin( 0, 0, 4, 0 )

		b.Paint = function( self, w, h )
			local C, K = T().colors, T().kit
			local on = ( tabs.active == name )
			draw.RoundedBox( K.radius, 0, 0, w, h, on and C.accent or C.bgLight )
			draw.SimpleText( string.upper( name ), "SWRP.Button", w / 2, h / 2,
				on and C.white or ( self:IsHovered() and C.text or C.textDim ),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
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
	  opts.color     -- color for the first cell (battalion color)
	  opts.buttons   -- { { label = "▲", variant, onClick = fn }, ... } in last column
	  opts.onClick   -- whole-row click
]]
function UI.Table( parent, columns )
	local theme = T()

	local wrap = vgui.Create( "DPanel", parent )
	wrap:Dock( FILL )
	wrap.Paint = nil

	local header = vgui.Create( "DPanel", wrap )
	header:Dock( TOP )
	header:SetTall( 24 )
	header.Paint = function( self, w, h )
		local C = T().colors
		local x = 0
		for _, col in ipairs( columns ) do
			local cw = w * col.frac
			draw.SimpleText( string.upper( col.name ), "SWRP.Small",
				x + 10, h / 2, C.textDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
			x = x + cw
		end
		surface.SetDrawColor( C.bgRaised )
		surface.DrawRect( 0, h - 1, w, 1 )
	end

	local scroll = vgui.Create( "DScrollPanel", wrap )
	scroll:Dock( FILL )
	scroll:DockMargin( 0, 4, 0, 0 )

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
		row:DockMargin( 0, 0, 0, 3 )

		row.Paint = function( self, w, h )
			local C, K = T().colors, T().kit
			draw.RoundedBox( K.radius, 0, 0, w, h,
				( opts.onClick and self:IsHovered() ) and C.bgRaised or C.bgLight )

			if opts.color then
				surface.SetDrawColor( opts.color )
				surface.DrawRect( 0, 0, K.accentW, h )
			end

			local x = 0
			for i, col in ipairs( columns ) do
				local cw   = w * col.frac
				local text = cells[ i ]
				if text ~= nil then
					draw.SimpleText( tostring( text ), "SWRP.Sub",
						x + 10, h / 2,
						opts.dim and C.textDim or ( i == 1 and opts.color or C.text ),
						TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
				end
				x = x + cw
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
				b:SetWide( def.width or 28 )   -- 28 fits glyphs; set width for text labels
				b:DockMargin( 0, 4, 4, 4 )
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
	card:DockPadding( theme.spacing.pad + theme.kit.accentW, title and 30 or theme.spacing.pad,
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
				K.accentW + theme.spacing.pad, 9, C.textDim )
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
	local card = UI.Card( parent )

	card.Paint = function( self, w, h )
		local C, K = T().colors, T().kit
		if not IsValid( ply ) then return end

		local Character = SWRP.Character
		local battalion = Character.GetBattalion( ply )
		local rank      = Character.GetRank( ply )
		local batColor  = battalion and battalion.color or C.textDim

		draw.RoundedBox( K.radius, 0, 0, w, h, C.bgLight )
		surface.SetDrawColor( batColor )
		surface.DrawRect( 0, 0, K.accentW, h )

		local x = K.accentW + 12
		draw.SimpleText( Character.GetName( ply ), "SWRP.Name", x, 10, C.text )
		draw.SimpleText(
			( battalion and battalion.name or "No battalion" )
			.. ( rank and ( "  ·  " .. rank.name ) or "" ),
			"SWRP.Sub", x, 38, batColor )
	end

	return card
end
