--[[----------------------------------------------------------------------------
	UI module (client) — the Republic Terminal (v4, approved via mockups).

	Full-screen translucent layer (the non-DarkRP SWRP genre standard) with a
	caps top-nav. Modules plug in via the same declarative API as before:

	  SWRP.UI.RegisterMenuTab{ id, name, order, build = function( panel ) end }

	Opens on F4 (relayed via sh_ui) or `swrp_menu`; F4/ESC closes. Ships with
	the built-in Character tab: live player model + identity statement + airy
	fact rows + chain of command. No action buttons by design.
------------------------------------------------------------------------------]]

SWRP.UI = SWRP.UI or {}
local UI = SWRP.UI

UI.MenuTabs = UI.MenuTabs or {}

function UI.RegisterMenuTab( tab )
	if not istable( tab ) or not isstring( tab.id ) or not isfunction( tab.build ) then
		SWRP.Error( "RegisterMenuTab needs { id, name, build }" )
		return
	end
	tab.name  = tab.name or tab.id
	tab.order = tab.order or 100
	UI.MenuTabs[ tab.id ] = tab
end

local terminal = nil

function UI.OpenMenu()
	if IsValid( terminal ) then
		terminal:Close()
		terminal = nil
		return
	end

	terminal = UI.Terminal()

	local sorted = {}
	for _, tab in pairs( UI.MenuTabs ) do sorted[ #sorted + 1 ] = tab end
	table.sort( sorted, function( a, b ) return a.order < b.order end )

	for _, tab in ipairs( sorted ) do
		terminal:AddTab( tab.name, tab.build )
	end
end

concommand.Add( "swrp_menu", function() UI.OpenMenu() end )


--------------------------------------------------------------------------------
-- Built-in tab: Loadout (v6 — AotR slot cells around the live model)
--------------------------------------------------------------------------------

UI.RegisterMenuTab( {
	id    = "loadout",
	name  = "Loadout",
	order = 10,
	build = function( panel )
		local theme = SWRP.Theme
		local C, K  = theme.colors, theme.kit
		local lp    = LocalPlayer()
		local Character = SWRP.Character

		-- HERO (left ~58%): slot columns flanking the live model ----------------
		local hero = vgui.Create( "DPanel", panel )
		hero:Dock( LEFT )
		hero:SetWide( math.floor( ( ScrW() - theme.spacing.termX * 2 ) * 0.58 ) )
		hero:DockMargin( 0, 0, 44, 0 )
		hero.Paint = nil

		-- Identity statement + SERVICE bar (stands in for XP until Phase E)
		local head = vgui.Create( "DPanel", hero )
		head:Dock( TOP )
		head:SetTall( 86 )
		head.Paint = function( self, w, h )
			local desig = Character.GetDesignation( lp )
			local base  = string.match( Character.GetName( lp ), "(%S+)$" ) or lp:Nick()
			draw.SimpleText(
				( desig ~= "" and ( "CT-" .. desig .. " " ) or "" )
				.. "“" .. string.upper( base ) .. "”",
				"SWRP.Display", 0, 0, C.text )

			local secs = Character.GetServiceTime( lp )
			local frac = ( secs % 36000 ) / 36000   -- one bar = 10 hours
			SWRP.UI.Rect( 2, 0, 62, w * 0.7, 8, C.barBack )
			SWRP.UI.Rect( 2, 0, 62, w * 0.7 * frac, 8, C.presence )
			draw.SimpleText( "SERVICE  " .. math.floor( secs / 3600 ) .. "H "
				.. math.floor( ( secs % 3600 ) / 60 ) .. "M",
				"SWRP.Label", w * 0.7 + 12, 66, C.label,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end

		-- Weapon slots, left column
		local SLOT_W = 168
		local leftCol = vgui.Create( "DPanel", hero )
		leftCol:Dock( LEFT )
		leftCol:SetWide( SLOT_W )
		leftCol:DockMargin( 0, 18, 0, 0 )
		leftCol.Paint = nil

		local primary = UI.SlotCell( leftCol, "Primary" )
		local sidearm = UI.SlotCell( leftCol, "Sidearm" )
		local equip   = UI.SlotCell( leftCol, "Equipment" )
		for i, cell in ipairs( { primary, sidearm, equip } ) do
			cell:Dock( TOP )
			cell:SetTall( 92 )
			cell:DockMargin( 0, 0, 0, 14 )
			UI.FadeIn( cell, UI.Stagger( i ) )
		end

		-- Service ring + identity slots, right column
		local rightCol = vgui.Create( "DPanel", hero )
		rightCol:Dock( RIGHT )
		rightCol:SetWide( SLOT_W )
		rightCol:DockMargin( 0, 18, 0, 0 )
		rightCol.Paint = nil

		local ring = UI.RingGauge( rightCol )
		ring:Dock( TOP )
		ring:SetTall( SLOT_W )
		ring:DockMargin( 0, 0, 0, 14 )

		local batCell  = UI.SlotCell( rightCol, "Battalion" )
		local rankCell = UI.SlotCell( rightCol, "Rank" )
		local clsCell  = UI.SlotCell( rightCol, "Class" )
		local loreCell = UI.SlotCell( rightCol, "Lore" )
		for i, cell in ipairs( { batCell, rankCell, clsCell, loreCell } ) do
			cell:Dock( TOP )
			cell:SetTall( 64 )
			cell:DockMargin( 0, 0, 0, 14 )
			UI.FadeIn( cell, UI.Stagger( 3 + i ) )
		end

		-- Center: live model over HP/ARMOR vitals
		local center = vgui.Create( "DPanel", hero )
		center:Dock( FILL )
		center:DockMargin( 24, 18, 24, 0 )
		center.Paint = nil

		local vitals = vgui.Create( "DPanel", center )
		vitals:Dock( BOTTOM )
		vitals:SetTall( 54 )
		vitals.Paint = function( self, w, h )
			local barH = theme.spacing.barH
			local hp     = math.max( 0, lp:Health() )
			local hpMax  = math.max( 1, lp:GetMaxHealth() )
			local hpFrac = math.min( 1, hp / hpMax )
			SWRP.UI.Rect( 2, 0, 6, w, barH, C.barBack )
			SWRP.UI.Rect( 2, 0, 6, w * hpFrac, barH,
				hpFrac < 0.25 and C.healthLow or C.health )
			draw.SimpleText( "HP " .. hp, "SWRP.Label", 4, 6 + barH / 2,
				C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )

			local ar  = math.max( 0, lp:Armor() )
			local arY = 6 + barH + 6
			SWRP.UI.Rect( 2, 0, arY, w, barH, C.barBack )
			SWRP.UI.Rect( 2, 0, arY, w * math.min( 1, ar / 100 ), barH, C.armor )
			draw.SimpleText( "ARMOR " .. ar, "SWRP.Label", 4, arY + barH / 2,
				C.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end

		local modelWrap = vgui.Create( "DPanel", center )
		modelWrap:Dock( FILL )
		modelWrap:DockMargin( 0, 0, 0, 12 )
		modelWrap.Paint = function( self, w, h )
			SWRP.UI.Rect( K.radius, 0, 0, w, h, C.modelBg )
			surface.SetDrawColor( C.cellBorder )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
		end
		local mdl = UI.ModelView( modelWrap, lp:GetModel() )
		mdl:Dock( FILL )
		UI.FadeIn( modelWrap, 0.05 )

		-- Live updates (identity/class can change while the menu is open)
		hero.Think = function()
			local battalion = Character.GetBattalion( lp )
			local rank      = Character.GetRank( lp )
			batCell:SetValue( battalion and battalion.name or "Unassigned",
				battalion and battalion.color or C.textDim )
			rankCell:SetValue( rank and rank.name or "—" )

			local className, weapons = "—", {}
			if SWRP.Class then
				local a = SWRP.Class.GetAssignment( Character.GetClassId( lp ) )
				if a then
					local res = SWRP.Class.Resolve( a )
					className = res.name
					weapons   = res.weapons or {}
				end
			end
			clsCell:SetValue( className )

			local function wname( i )
				return weapons[ i ] and string.gsub( weapons[ i ], "^weapon_", "" ) or nil
			end
			primary:SetValue( wname( 1 ) or "Empty", wname( 1 ) and C.text or C.label )
			sidearm:SetValue( wname( 2 ) or "Empty", wname( 2 ) and C.text or C.label )
			equip:SetValue(
				#weapons > 2 and ( "+" .. ( #weapons - 2 ) .. " items" ) or "Empty",
				#weapons > 2 and C.text or C.label )

			local loreId = Character.GetLoreId( lp )
			local slot   = loreId ~= "" and SWRP.Lore and SWRP.Lore.Get( loreId ) or nil
			loreCell:SetValue( slot and slot.name or "None held",
				slot and C.gold or C.label )
			loreCell:SetAccent( slot and C.gold or nil )

			local desig = Character.GetDesignation( lp )
			local secs  = Character.GetServiceTime( lp )
			ring:SetFraction( ( secs % 36000 ) / 36000 )
			ring:SetCenter( desig ~= "" and desig or "—",
				"SERVICE " .. math.floor( secs / 3600 ) .. "H" )
			ring:SetColor( C.presence )
		end

		-- NEWS (right zone — sized where the Phase B inventory grid will live) ---
		local news = vgui.Create( "DPanel", panel )
		news:Dock( FILL )
		news:DockPadding( 0, 26, 0, 0 )
		news.Paint = function( self, w, h )
			draw.SimpleText( "HOLONET NEWS", "SWRP.Label", 0, 0, C.label )
		end
		if SWRP.News then SWRP.News.BuildFeed( news ) end
	end,
} )
