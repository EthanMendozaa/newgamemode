--[[----------------------------------------------------------------------------
	HUD module (client) — the identity plate + vitals.

	Bottom-left: derived name, battalion + rank line (battalion-colored), and
	health/armor bars. All values event-derived from networked identity; all
	visuals from SWRP.Theme.
------------------------------------------------------------------------------]]

local Character = SWRP.Character

local HIDE = {
	CHudHealth  = true,
	CHudBattery = true,
}

hook.Add( "HUDShouldDraw", "SWRP.HUD.HideDefault", function( name )
	if HIDE[ name ] then return false end
end )

hook.Add( "HUDPaint", "SWRP.HUD.Plate", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end

	local T  = SWRP.Theme
	local C  = T.colors
	local S  = T.spacing

	local w, h = 300, 96
	local x    = S.margin
	local y    = ScrH() - S.margin - h

	draw.RoundedBox( 6, x, y, w, h, C.bg )

	-- Identity
	local name      = Character.GetName( ply )
	local battalion = Character.GetBattalion( ply )
	local rank      = Character.GetRank( ply )
	local batColor  = battalion and battalion.color or C.textDim

	draw.SimpleText( name, "SWRP.Name", x + S.pad, y + S.pad, C.text )

	local subline = ( battalion and battalion.name or "No battalion" )
		.. ( rank and ( "  ·  " .. rank.name ) or "" )
	draw.SimpleText( subline, "SWRP.Sub", x + S.pad, y + S.pad + 26, batColor )

	-- Vitals
	local barW = w - S.pad * 2
	local hpY  = y + h - S.pad * 2 - S.barH * 2 + 2

	local hp     = math.max( 0, ply:Health() )
	local hpMax  = math.max( 1, ply:GetMaxHealth() )
	local hpFrac = math.min( 1, hp / hpMax )

	draw.RoundedBox( 4, x + S.pad, hpY, barW, S.barH, C.barBack )
	draw.RoundedBox( 4, x + S.pad, hpY, barW * hpFrac, S.barH,
		hpFrac < 0.25 and C.healthLow or C.health )
	draw.SimpleText( hp, "SWRP.Small", x + S.pad + 4, hpY, C.text )

	local arY = hpY + S.barH + 4
	local ar  = math.max( 0, ply:Armor() )
	if ar > 0 then
		local arFrac = math.min( 1, ar / 100 )
		draw.RoundedBox( 4, x + S.pad, arY, barW, S.barH, C.barBack )
		draw.RoundedBox( 4, x + S.pad, arY, barW * arFrac, S.barH, C.armor )
		draw.SimpleText( ar, "SWRP.Small", x + S.pad + 4, arY, C.text )
	end
end )
