--[[----------------------------------------------------------------------------
	UI module (client) — main menu shell.

	One window every module plugs a tab into (plan: RegisterMenuTab API):

	  SWRP.UI.RegisterMenuTab{
	      id    = "battalion",
	      name  = "Battalion",
	      order = 20,
	      build = function( panel ) ... end,
	  }

	Opens on F4 (relayed via sh_ui) or the `swrp_menu` console command.
	Ships with a built-in "Character" tab; Phase 2/3 modules add theirs.
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

local menu = nil

function UI.OpenMenu()
	if IsValid( menu ) then
		menu:Close()
		menu = nil
		return
	end

	local theme = SWRP.Theme

	-- Sized to content density, not the whole screen — no dead void below.
	local w = math.Clamp( ScrW() * 0.46, 640, 860 )
	local h = math.Clamp( ScrH() * 0.58, 440, 580 )

	-- Title follows the gamemode brand (GM.Name) — renames are one-line edits.
	menu = UI.Frame( w, h, ( GAMEMODE and GAMEMODE.Name ) or "SWRP" )

	local tabs = UI.Tabs( menu.Body )

	local sorted = {}
	for _, tab in pairs( UI.MenuTabs ) do sorted[ #sorted + 1 ] = tab end
	table.sort( sorted, function( a, b ) return a.order < b.order end )

	for _, tab in ipairs( sorted ) do
		tabs:Add( tab.name, tab.build )
	end

	if #sorted == 0 then
		local empty = vgui.Create( "DLabel", menu.Body )
		empty:SetText( "No menu tabs registered." )
		empty:SetFont( "SWRP.Sub" )
		empty:SetTextColor( theme.colors.textDim )
		empty:Dock( TOP )
	end
end

concommand.Add( "swrp_menu", function() UI.OpenMenu() end )

--------------------------------------------------------------------------------
-- Built-in tab: Character (local identity overview)
--------------------------------------------------------------------------------

UI.RegisterMenuTab( {
	id    = "character",
	name  = "Character",
	order = 10,
	build = function( panel )
		local theme = SWRP.Theme
		local S     = theme.spacing

		local card = UI.PlayerCard( panel, LocalPlayer() )
		card:Dock( TOP )
		card:SetTall( 76 )
		card:DockMargin( 0, 0, 0, S.pad )

		local info = UI.Card( panel, "Service record" )
		info:Dock( TOP )
		info:SetTall( 168 )

		info.PaintOver = function( self, w, h )
			local C   = theme.colors
			local ply = LocalPlayer()
			local Character = SWRP.Character

			local battalion = Character.GetBattalion( ply )
			local rank      = Character.GetRank( ply )

			local className = "—"
			if SWRP.Class then
				local a = SWRP.Class.GetAssignment( Character.GetClassId( ply ) )
				if a then className = SWRP.Class.Resolve( a ).name end
			end

			local designation = Character.GetDesignation( ply )
			local rows = {
				{ "Battalion",   battalion and battalion.name or "—", battalion and battalion.color },
				{ "Rank",        rank and rank.name or "—" },
				{ "Class",       className },
				{ "Designation", designation ~= "" and designation or "Not chosen" },
			}

			local x = theme.kit.accentW + S.pad
			local y = 38
			for _, r in ipairs( rows ) do
				draw.SimpleText( r[ 1 ], "SWRP.Small", x, y + 2, C.textDim )

				local vx = w * 0.38
				if r[ 3 ] then
					draw.RoundedBox( 3, vx, y + 3, 13, 13, r[ 3 ] )
					vx = vx + 20
				end
				draw.SimpleText( r[ 2 ], "SWRP.Sub", vx, y, C.text )
				y = y + 31
			end
		end
	end,
} )
