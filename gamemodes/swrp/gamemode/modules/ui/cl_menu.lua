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
	A built-in "Character" tab shows the local player's derived identity —
	Phase 2 modules (battalion management, requests) add theirs.
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

	-- Title follows the gamemode brand (GM.Name) — renames are one-line edits.
	menu = UI.Frame( math.min( 920, ScrW() * 0.7 ), math.min( 620, ScrH() * 0.75 ),
		( GAMEMODE and GAMEMODE.Name ) or "SWRP" )

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

		local card = UI.PlayerCard( panel, LocalPlayer() )
		card:Dock( TOP )
		card:SetTall( 64 )
		card:DockMargin( 0, 0, 0, theme.spacing.pad )

		local info = UI.Card( panel, "Service record" )
		info:Dock( TOP )
		info:SetTall( 110 )

		info.PaintOver = function( self, w, h )
			local C   = theme.colors
			local ply = LocalPlayer()
			local Character = SWRP.Character

			local battalion = Character.GetBattalion( ply )
			local rank      = Character.GetRank( ply )

			local designation = Character.GetDesignation( ply )
			local rows = {
				{ "Battalion",   battalion and battalion.name or "—" },
				{ "Rank",        rank and rank.name or "—" },
				{ "Designation", designation ~= "" and designation or "Not chosen" },
			}

			local y = 30
			for _, r in ipairs( rows ) do
				draw.SimpleText( r[ 1 ], "SWRP.Small", 16, y, C.textDim )
				draw.SimpleText( r[ 2 ], "SWRP.Sub", w * 0.4, y - 2, C.text )
				y = y + 26
			end
		end
	end,
} )
