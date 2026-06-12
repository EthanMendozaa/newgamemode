--[[----------------------------------------------------------------------------
	HUD module (client) — overhead name tags.

	Derived name + battalion color above nearby visible players. Range-limited
	and line-of-sight checked so tags don't leak positions through walls.
------------------------------------------------------------------------------]]

local Character = SWRP.Character

hook.Add( "HUDPaint", "SWRP.HUD.Overhead", function()
	local lp = LocalPlayer()
	if not IsValid( lp ) then return end
	if SWRP.Prefs and not SWRP.Prefs.Get( "overhead_names", true ) then return end

	local T       = SWRP.Theme
	local maxDist = T.overhead.distance * T.overhead.distance
	local eyePos  = lp:EyePos()

	for _, ply in ipairs( player.GetAll() ) do
		if ply ~= lp and IsValid( ply ) and ply:Alive() then
			local target = ply:EyePos()

			if eyePos:DistToSqr( target ) <= maxDist then
				-- No wallhack: only tag players we can actually see.
				local tr = util.TraceLine( {
					start  = eyePos,
					endpos = target,
					filter = { lp, ply },
					mask   = MASK_VISIBLE,
				} )

				if not tr.Hit then
					local pos = ( target + Vector( 0, 0, T.overhead.height ) ):ToScreen()
					if pos.visible then
						-- Name + a quiet rank · battalion subline (v4, approved).
						local rank      = Character.GetRank( ply )
						local battalion = Character.GetBattalion( ply )

						draw.SimpleTextOutlined(
							Character.GetName( ply ), "SWRP.Overhead",
							pos.x, pos.y - 16, Character.GetColor( ply ),
							TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
							1, T.colors.outline )

						if rank or battalion then
							draw.SimpleTextOutlined(
								( rank and rank.name or "" )
								.. ( ( rank and battalion ) and " · " or "" )
								.. ( battalion and battalion.name or "" ),
								"SWRP.OverheadSub",
								pos.x, pos.y, T.colors.white,
								TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
								1, T.colors.outline )
						end
					end
				end
			end
		end
	end
end )
