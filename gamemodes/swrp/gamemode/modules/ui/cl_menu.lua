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
-- Built-in tab: Character
--------------------------------------------------------------------------------

local function formatService( seconds )
	local h = math.floor( seconds / 3600 )
	local m = math.floor( ( seconds % 3600 ) / 60 )
	return h .. "h " .. m .. "m"
end

UI.RegisterMenuTab( {
	id    = "character",
	name  = "Character",
	order = 10,
	build = function( panel )
		local theme = SWRP.Theme
		local C     = theme.colors
		local lp    = LocalPlayer()
		local Character = SWRP.Character

		-- Live model, left ---------------------------------------------------
		local modelWrap = vgui.Create( "DPanel", panel )
		modelWrap:Dock( LEFT )
		modelWrap:SetWide( math.floor( ScrW() * 0.18 ) )
		modelWrap:DockMargin( 0, 0, 40, 0 )
		modelWrap.Paint = function( self, w, h )
			surface.SetDrawColor( C.modelBg )
			surface.DrawRect( 0, 0, w, h )
		end

		local mdl = UI.ModelView( modelWrap, lp:GetModel() )
		mdl:Dock( FILL )

		-- Identity + facts, right — content capped ~820px wide (playtest: fact
		-- rows stretched edge-to-edge on wide monitors).
		local contentW = ScrW() - theme.spacing.termX * 2
		local modelW   = math.floor( ScrW() * 0.18 )
		local rightCap = math.max( math.floor( ScrW() * 0.05 ), contentW - modelW - 40 - 820 )

		local right = vgui.Create( "DPanel", panel )
		right:Dock( FILL )
		right:DockPadding( 0, 6, rightCap, 0 )
		right.Paint = nil

		local head = vgui.Create( "DPanel", right )
		head:Dock( TOP )
		head:SetTall( 76 )
		head.Paint = function( self, w, h )
			local battalion = Character.GetBattalion( lp )
			local rank      = Character.GetRank( lp )
			local desig     = Character.GetDesignation( lp )

			-- "CT-4456 “PARA”" — RP base name is the last token of the derived name.
			local base = string.match( Character.GetName( lp ), "(%S+)$" ) or lp:Nick()
			local statement = ( desig ~= "" and ( "CT-" .. desig .. " " ) or "" )
				.. "“" .. string.upper( base ) .. "”"

			draw.SimpleText( statement, "SWRP.Display", 0, 6, C.text )

			local classId = Character.GetClassId( lp )
			local className
			if SWRP.Class then
				local a = SWRP.Class.GetAssignment( classId )
				if a then className = SWRP.Class.Resolve( a ).name end
			end

			local sub = ( battalion and battalion.name or "No battalion" )
				.. ( rank and ( " · " .. rank.name ) or "" )
				.. ( className and ( " · " .. className ) or "" )
			draw.SimpleText( sub, "SWRP.Sub", 2, 50, C.accentSub )
		end

		local facts = vgui.Create( "DPanel", right )
		facts:Dock( TOP )
		facts:SetTall( theme.spacing.factH * 4 )
		facts:DockMargin( 0, 22, 0, 0 )
		facts.Paint = nil

		local desigRow = UI.FactRow( facts, "Designation", "—", C.gold )
		local timeRow  = UI.FactRow( facts, "Service time", "—" )
		local loadRow  = UI.FactRow( facts, "Loadout", "—", C.textDim )
		local loreRow  = UI.FactRow( facts, "Lore identity", "—", C.textDim )

		facts.Think = function()
			local desig = Character.GetDesignation( lp )
			desigRow:SetValue( desig ~= "" and desig or "Not chosen" )
			timeRow:SetValue( formatService( Character.GetServiceTime( lp ) ) )

			local a = SWRP.Class and SWRP.Class.GetAssignment( Character.GetClassId( lp ) )
			if a then
				local weapons = {}
				for _, w in ipairs( SWRP.Class.Resolve( a ).weapons ) do
					weapons[ #weapons + 1 ] = string.gsub( w, "^weapon_", "" )
				end
				loadRow:SetValue( table.concat( weapons, " · " ), C.textDim )
			end

			local loreId = Character.GetLoreId( lp )
			local slot   = loreId ~= "" and SWRP.Lore and SWRP.Lore.Get( loreId )
			loreRow:SetValue( slot and slot.name or "None held",
				slot and C.gold or C.label )
		end

		-- Chain of command -----------------------------------------------------
		local chain = vgui.Create( "DPanel", right )
		chain:Dock( TOP )
		chain:SetTall( 56 )
		chain:DockMargin( 0, 26, 0, 0 )
		chain.Paint = function( self, w, h )
			draw.SimpleText( "CHAIN OF COMMAND", "SWRP.Label", 0, h / 2, C.label,
				TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end

		local myBat = Character.GetBattalion( lp )
		local officers, labels = {}, {}
		for _, p in ipairs( player.GetAll() ) do
			local b = Character.GetBattalion( p )
			local r = Character.GetRank( p )
			if b and myBat and b.id == myBat.id and r
				and ( r.virtual or next( r.permissions or {} ) ~= nil ) then
				officers[ #officers + 1 ] = { ply = p, rank = r }
			end
		end
		table.sort( officers, function( a, b ) return a.rank.index > b.rank.index end )

		local x = 190
		for i = 1, math.min( #officers, 5 ) do
			local o  = officers[ i ]
			local av = UI.Avatar( chain, o.ply, 34 )
			av:SetPos( x, 11 )
			x = x + 46
			labels[ #labels + 1 ] = o.rank.tag .. " " .. ( string.match( SWRP.Character.GetName( o.ply ), "(%S+)$" ) or "" )
		end

		local lbl = vgui.Create( "DLabel", chain )
		lbl:SetFont( "SWRP.Small" )
		lbl:SetTextColor( C.textDim )
		lbl:SetText( #officers > 0 and ( table.concat( labels, " · " ) .. " online" )
			or "No officers online" )
		lbl:SetPos( x + 12, 18 )
		lbl:SizeToContents()
	end,
} )
