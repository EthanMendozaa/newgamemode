--[[----------------------------------------------------------------------------
	UI module (client) — kit showcase.

	`swrp_ui_demo` opens every component in one window so the kit can be
	eyeballed in-game without waiting for Phase 2 consumers. Safe to delete
	once the kit is signed off.
------------------------------------------------------------------------------]]

local UI = SWRP.UI

concommand.Add( "swrp_ui_demo", function()
	local theme = SWRP.Theme
	local f = UI.Frame( 760, 540, "UI kit — Republic theme" )
	local tabs = UI.Tabs( f.Body )

	tabs:Add( "Components", function( panel )
		local row = vgui.Create( "DPanel", panel )
		row:Dock( TOP )
		row:SetTall( theme.kit.btnH )
		row.Paint = nil

		local b1 = UI.Button( row, "Primary action", "primary", function()
			UI.Toast( "Primary clicked", "info" )
		end )
		b1:Dock( LEFT ) b1:SetWide( 150 ) b1:DockMargin( 0, 0, 8, 0 )

		local b2 = UI.Button( row, "Ghost action", "ghost", function()
			UI.Toast( "Saved successfully", "success" )
		end )
		b2:Dock( LEFT ) b2:SetWide( 150 ) b2:DockMargin( 0, 0, 8, 0 )

		local b3 = UI.Button( row, "Danger action", "danger", function()
			UI.Toast( "Action failed", "danger" )
		end )
		b3:Dock( LEFT ) b3:SetWide( 150 )

		local row2 = vgui.Create( "DPanel", panel )
		row2:Dock( TOP )
		row2:SetTall( theme.kit.btnH )
		row2:DockMargin( 0, 10, 0, 0 )
		row2.Paint = nil

		local b4 = UI.Button( row2, "Confirm dialog", "ghost", function()
			UI.Confirm( "Switch class", "Switch to Heavy? You will respawn.",
				function() UI.Toast( "Confirmed", "success" ) end,
				function() UI.Toast( "Cancelled", "info" ) end )
		end )
		b4:Dock( LEFT ) b4:SetWide( 150 ) b4:DockMargin( 0, 0, 8, 0 )

		local n = 0
		local b5 = UI.Button( row2, "Queue prompt", "ghost", function()
			n = n + 1
			UI.Prompt( {
				id      = "demo_" .. n,
				title   = "Battalion invite",
				text    = "LT 2187 Hale invites you to the 501st (" .. n .. ")",
				expires = 20,
				onAccept = function() UI.Toast( "Accepted #" .. n, "success" ) end,
				onDeny   = function() UI.Toast( "Denied #" .. n, "danger" ) end,
			} )
		end )
		b5:Dock( LEFT ) b5:SetWide( 150 )

		local card = UI.PlayerCard( panel, LocalPlayer() )
		card:Dock( TOP )
		card:SetTall( 64 )
		card:DockMargin( 0, 14, 0, 0 )

		local cd = UI.Card( panel, "Cooldown" )
		cd:Dock( TOP )
		cd:SetTall( 52 )
		cd:DockMargin( 0, 10, 0, 0 )

		local bar = UI.Bar( cd )
		bar:Dock( TOP )
		bar:DockMargin( 0, 4, 0, 0 )
		local started = RealTime()
		bar.Think = function( self )
			self:SetFraction( 1 - math.Clamp( ( RealTime() - started ) / 10, 0, 1 ) )
		end
	end )

	tabs:Add( "Roster", function( panel )
		local tbl = UI.Table( panel, {
			{ name = "Name",   frac = 0.40 },
			{ name = "Rank",   frac = 0.22 },
			{ name = "Desig",  frac = 0.14 },
			{ name = "Status", frac = 0.24 },
		} )

		local blue = SWRP.Theme.colors.accent
		local rows = {
			{ { "501st CPT 1010 Vex",  "Captain",    "1010", "Online"  }, { color = blue } },
			{ { "501st LT 2187 Hale",  "Lieutenant", "2187", "Online"  }, { color = blue } },
			{ { "501st SGT 4456 Para", "Sergeant",   "4456", "Online"  }, { color = blue } },
			{ { "501st PVT 7731 Dorn", "Private",    "7731", "Offline" }, { color = blue, dim = true } },
		}

		for _, r in ipairs( rows ) do
			r[ 2 ].buttons = {
				{ label = "▲", onClick = function() UI.Toast( "Promote " .. r[ 1 ][ 1 ], "info" ) end },
				{ label = "▼", onClick = function() UI.Toast( "Demote " .. r[ 1 ][ 1 ], "info" ) end },
				{ label = "✕", variant = "danger", onClick = function() UI.Toast( "Kick " .. r[ 1 ][ 1 ], "danger" ) end },
			}
			tbl:AddRow( r[ 1 ], r[ 2 ] )
		end
	end )
end )
