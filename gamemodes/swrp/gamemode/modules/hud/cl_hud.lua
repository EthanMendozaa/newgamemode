--[[----------------------------------------------------------------------------
	HUD module (client) — identity plate + vitals + ammo (v4, approved).

	Bottom-left: derived name, battalion · rank line, HP/armor bars with live
	numbers. Bottom-right: ammo block (clip / reserve / weapon). Everything
	event-derived from networked identity; all visuals from SWRP.Theme.
	One glance = ≤4 chunks (player-ux).
------------------------------------------------------------------------------]]

local Character = SWRP.Character

local HIDE = {
	CHudHealth        = true,
	CHudBattery       = true,
	CHudAmmo          = true,
	CHudSecondaryAmmo = true,
}

hook.Add( "HUDShouldDraw", "SWRP.HUD.HideDefault", function( name )
	if HIDE[ name ] then return false end
end )

hook.Add( "HUDPaint", "SWRP.HUD.Plate", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not ply:Alive() then return end

	local T = SWRP.Theme
	local C = T.colors
	local S = T.spacing

	-- Identity plate (bottom-left) -------------------------------------------
	local w, h = 264, 104
	local x    = S.margin
	local y    = ScrH() - S.margin - h

	SWRP.UI.Rect( T.kit.radius, x, y, w, h, C.bg )
	surface.SetDrawColor( C.accent )
	surface.DrawRect( x, y, T.kit.accentW, h )

	local name      = Character.GetName( ply )
	local battalion = Character.GetBattalion( ply )
	local rank      = Character.GetRank( ply )
	local batColor  = battalion and battalion.color or C.textDim

	local pad = S.pad + T.kit.accentW
	draw.SimpleText( name, "SWRP.Name", x + pad, y + 10, C.text )

	local subline = ( battalion and battalion.name or "No battalion" )
		.. ( rank and ( " · " .. rank.name ) or "" )
	draw.SimpleText( subline, "SWRP.Small", x + pad, y + 36, batColor )

	-- Vitals with live numbers
	local barW = w - pad - S.pad
	local hpY  = y + h - S.pad - S.barH * 2 - 4

	local hp     = math.max( 0, ply:Health() )
	local hpMax  = math.max( 1, ply:GetMaxHealth() )
	local hpFrac = math.min( 1, hp / hpMax )

	SWRP.UI.Rect( 3, x + pad, hpY, barW, S.barH, C.barBack )
	SWRP.UI.Rect( 3, x + pad, hpY, barW * hpFrac, S.barH,
		hpFrac < 0.25 and C.healthLow or C.health )
	draw.SimpleText( hp, "SWRP.Small", x + pad + barW - 5, hpY + S.barH / 2 - 1,
		C.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

	local arY = hpY + S.barH + 4
	local ar  = math.max( 0, ply:Armor() )
	if ar > 0 then
		local arFrac = math.min( 1, ar / 100 )
		SWRP.UI.Rect( 3, x + pad, arY, barW, S.barH, C.barBack )
		SWRP.UI.Rect( 3, x + pad, arY, barW * arFrac, S.barH, C.armor )
		draw.SimpleText( ar, "SWRP.Small", x + pad + barW - 5, arY + S.barH / 2 - 1,
			C.white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	end

	-- Ammo block (bottom-right) ------------------------------------------------
	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) then
		local clip = wep:Clip1()
		if clip and clip >= 0 then
			local reserve = ply:GetAmmoCount( wep:GetPrimaryAmmoType() )
			local max     = wep:GetMaxClip1()

			local aw, ah = 196, 64
			local ax     = ScrW() - S.margin - aw
			local ay     = ScrH() - S.margin - ah

			SWRP.UI.Rect( T.kit.radius, ax, ay, aw, ah, C.bg )
			surface.SetDrawColor( C.accent )
			surface.DrawRect( ax + aw - T.kit.accentW, ay, T.kit.accentW, ah )

			draw.SimpleText( clip, "SWRP.Ammo", ax + aw - 16, ay + 4, C.text,
				TEXT_ALIGN_RIGHT )
			if max and max > 0 then
				surface.SetFont( "SWRP.Ammo" )
				local cw = surface.GetTextSize( tostring( clip ) )
				draw.SimpleText( "/ " .. max, "SWRP.Small",
					ax + aw - 20 - cw, ay + 16, C.textDim, TEXT_ALIGN_RIGHT )
			end

			local wname = string.gsub( wep:GetClass(), "^weapon_", "" )
			draw.SimpleText( string.upper( reserve .. " RESERVE · " .. wname ),
				"SWRP.Label", ax + aw - 16, ay + ah - 20, C.label, TEXT_ALIGN_RIGHT )
		end
	end
end )
