--[[----------------------------------------------------------------------------
	Battalion module (client) — the Battalion menu tab.

	Pure intent-sender: buttons fire net messages; the server is the gate.
	Hierarchy.Can runs here only to HIDE actions the server would reject
	(player-ux: don't show controls that can't work), and the same check is
	re-run authoritatively server-side on every click.
------------------------------------------------------------------------------]]

local Battalion = SWRP.Battalion
local Hierarchy = SWRP.Hierarchy
local UI        = SWRP.UI

local state = {
	roster = nil,    -- last payload from the server
	tbl    = nil,    -- live table widget (if tab open)
	title  = nil,    -- live header label
}

--------------------------------------------------------------------------------
-- Roster rendering
--------------------------------------------------------------------------------

local function myId()
	return LocalPlayer():SteamID64() or ( "BOT_" .. LocalPlayer():EntIndex() )
end

local function rebuild()
	if not ( state.tbl and IsValid( state.tbl.wrap ) ) or not state.roster then return end

	local data      = state.roster
	local battalion = Hierarchy.GetBattalion( data.battalion_id )
	local batColor  = battalion and battalion.color or nil
	local lp        = LocalPlayer()

	if IsValid( state.title ) then
		state.title:SetText( string.format( "%s — %d member(s)",
			battalion and battalion.name or "Battalion", #data.rows ) )
	end

	-- Sort: online first, then rank (highest first), then name.
	table.sort( data.rows, function( a, b )
		if a.online ~= b.online then return a.online end
		local ra = Hierarchy.GetRank( a.rank_id )
		local rb = Hierarchy.GetRank( b.rank_id )
		local ia = ra and ra.index or 0
		local ib = rb and rb.index or 0
		if ia ~= ib then return ia > ib end
		return ( a.name or "" ) < ( b.name or "" )
	end )

	state.tbl:Clear()

	for _, row in ipairs( data.rows ) do
		local rank   = Hierarchy.GetRank( row.rank_id )
		local desc   = { battalion_id = data.battalion_id, rank_id = row.rank_id }
		local isSelf = ( row.id == myId() )

		local buttons = {}
		if not isSelf then
			if Hierarchy.Can( lp, "can_promote", desc ) then
				buttons[ #buttons + 1 ] = { label = "▲", onClick = function()
					SWRP.Net.Send( "swrp.battalion.action", { action = "promote", target = row.id } )
				end }
			end
			if Hierarchy.Can( lp, "can_demote", desc ) then
				buttons[ #buttons + 1 ] = { label = "▼", onClick = function()
					SWRP.Net.Send( "swrp.battalion.action", { action = "demote", target = row.id } )
				end }
			end
			if Hierarchy.Can( lp, "can_kick", desc ) then
				buttons[ #buttons + 1 ] = { label = "✕", variant = "danger", onClick = function()
					UI.Confirm( "Remove member",
						"Remove " .. row.name .. " from the battalion?",
						function()
							SWRP.Net.Send( "swrp.battalion.action", { action = "kick", target = row.id } )
						end )
				end }
			end
		end

		state.tbl:AddRow( {
			( rank and rank.tag or "?" ) .. " " .. ( row.designation or "----" ) .. " " .. ( row.name or "?" ),
			rank and rank.name or "—",
			row.designation or "—",
			row.online and "Online" or "Offline",
		}, {
			color   = batColor,
			dim     = not row.online,
			buttons = buttons,
		} )
	end
end

function Battalion.OnRoster( data )
	state.roster = data
	rebuild()
end

--------------------------------------------------------------------------------
-- Invite picker
--------------------------------------------------------------------------------

local function openInvitePicker()
	local lp     = LocalPlayer()
	local myBat  = SWRP.Character.GetBattalion( lp )
	local f      = UI.Frame( 360, 380, "Invite to " .. ( myBat and myBat.name or "battalion" ) )

	local tbl = UI.Table( f.Body, {
		{ name = "Player", frac = 0.62 },
		{ name = "",       frac = 0.38 },
	} )

	local any = false
	for _, p in ipairs( player.GetAll() ) do
		local theirBat = SWRP.Character.GetBattalion( p )
		if p ~= lp and ( not theirBat or not myBat or theirBat.id ~= myBat.id ) then
			any = true
			tbl:AddRow( { SWRP.Character.GetName( p ), "" }, {
				color   = SWRP.Character.GetColor( p ),
				buttons = {
					{ label = "Invite", variant = "primary", width = 64, onClick = function()
						SWRP.Net.Send( "swrp.battalion.invite", { target = p } )
						f:Close()
					end },
				},
			} )
		end
	end

	if not any then
		tbl:AddRow( { "No eligible players online", "" }, { dim = true } )
	end
end

--------------------------------------------------------------------------------
-- Menu tab
--------------------------------------------------------------------------------

UI.RegisterMenuTab( {
	id    = "battalion",
	name  = "Battalion",
	order = 20,
	build = function( panel )
		local theme = SWRP.Theme

		local top = vgui.Create( "DPanel", panel )
		top:Dock( TOP )
		top:SetTall( theme.kit.btnH )
		top:DockMargin( 0, 0, 0, theme.spacing.pad )
		top.Paint = nil

		local title = vgui.Create( "DLabel", top )
		title:SetFont( "SWRP.Sub" )
		title:SetTextColor( theme.colors.text )
		title:SetText( "Loading roster..." )
		title:Dock( FILL )
		state.title = title

		local lp = LocalPlayer()
		if Hierarchy.Can( lp, "can_invite" ) then
			local invite = UI.Button( top, "Invite member", "primary", openInvitePicker )
			invite:Dock( RIGHT )
			invite:SetWide( 130 )
			invite:DockMargin( 8, 0, 0, 0 )
		end

		local refresh = UI.Button( top, "Refresh", "ghost", function()
			SWRP.Net.Send( "swrp.battalion.roster_request", {} )
		end )
		refresh:Dock( RIGHT )
		refresh:SetWide( 90 )

		state.tbl = UI.Table( panel, {
			{ name = "Name",   frac = 0.42 },
			{ name = "Rank",   frac = 0.20 },
			{ name = "Desig",  frac = 0.12 },
			{ name = "Status", frac = 0.26 },
		} )

		-- Render cached roster instantly, then ask for fresh data.
		rebuild()
		SWRP.Net.Send( "swrp.battalion.roster_request", {} )
	end,
} )
