--[[----------------------------------------------------------------------------
	Battalion module (server) — authoritative battalion management.

	Every mutation: resolve target (online record or offline DB row) -> gate
	through Hierarchy.Can -> enforce structural rules (rank order, slot caps,
	no-void) -> apply through the single mutation path (Commit online,
	write-through UPDATE + record_version bump offline) -> audit -> notify ->
	push a fresh roster to the actor.

	Identity changes apply via respawn (invariant 4): joining and being kicked
	respawn the player; rank changes are name-only and don't.
------------------------------------------------------------------------------]]

local Battalion   = SWRP.Battalion
local Character   = SWRP.Character
local Hierarchy   = SWRP.Hierarchy
local Interaction = SWRP.Interaction
local Audit       = SWRP.Audit
local DB          = SWRP.DB
local log         = SWRP.Logger( "Battalion" )

-- One feedback channel for the whole gamemode (swrp.ui.notice).
local function notify( ply, ok, msg )
	SWRP.UI.Notify( ply, ok, msg )
end

--------------------------------------------------------------------------------
-- Roster
--------------------------------------------------------------------------------

function Battalion.SendRoster( ply )
	local arec = Character.GetRecord( ply )
	if not arec then return end

	local battalionId = arec.battalion_id

	DB.Query( [[
		SELECT id, rp_name_base, designation, rank_id, lore_id
		FROM swrp_characters WHERE battalion_id = ?
	]], { battalionId }, function( rows, err )
		if err or not IsValid( ply ) then return end

		local out, seen = {}, {}
		for _, r in ipairs( rows or {} ) do
			seen[ r.id ] = true

			-- Display/gate against the DERIVED rank: lore commanders sit above
			-- the ladder, not at their stored rank.
			local rec    = Character.GetRecordById( r.id )
			local rankId = rec and ( rec._effRank or rec.rank_id ) or r.rank_id
			if not rec and SWRP.Lore and r.lore_id and r.lore_id ~= "NULL" and r.lore_id ~= "" then
				rankId = SWRP.Lore.EffectiveRankId( r.lore_id ) or rankId
			end

			-- v6 unit panel: clients map lore slots to holders from the payload.
			-- The live record wins INCLUDING its nil (a falsy chain would resurrect
			-- a just-released slot from the stale SELECT row).
			local loreId = r.lore_id
			if rec then loreId = rec.lore_id end
			if loreId == "NULL" or loreId == "" then loreId = nil end

			out[ #out + 1 ] = {
				id          = r.id,
				name        = r.rp_name_base,
				designation = ( r.designation ~= "NULL" ) and r.designation or nil,
				rank_id     = rankId,
				lore_id     = loreId,
				online      = rec ~= nil,
			}
		end

		-- Bots live in memory only; merge any in this battalion so they show.
		for _, p in ipairs( player.GetAll() ) do
			local rec = Character.GetRecord( p )
			if rec and rec.isBot and rec.battalion_id == battalionId and not seen[ rec.id ] then
				out[ #out + 1 ] = {
					id = rec.id, name = rec.rp_name_base, designation = rec.designation,
					rank_id = rec._effRank or rec.rank_id, lore_id = rec.lore_id, online = true,
				}
			end
		end

		SWRP.Net.Send( "swrp.battalion.roster", ply, {
			data = { battalion_id = battalionId, rows = out },
		} )
	end )
end

--------------------------------------------------------------------------------
-- Target resolution + application (online or offline)
--------------------------------------------------------------------------------

local function resolveTarget( targetId, cb )
	local rec = Character.GetRecordById( targetId )
	if rec then
		cb( {
			-- _effRank: lore commanders sit above the ladder; rank checks must
			-- see the derived rank, not the stored one.
			battalion_id = rec.battalion_id, rank_id = rec._effRank or rec.rank_id,
			name = rec.rp_name_base, id = rec.id, online = true, rec = rec,
		} )
		return
	end

	DB.Query(
		"SELECT id, rp_name_base, battalion_id, rank_id, lore_id FROM swrp_characters WHERE id = ? LIMIT 1",
		{ targetId }, function( rows )
			local row = rows and rows[ 1 ]
			if not row then cb( nil ) return end

			-- Offline lore-holders keep their derived rank for authority checks
			-- (an offline commander must not be kickable by a captain).
			local rankId = row.rank_id
			if SWRP.Lore and row.lore_id and row.lore_id ~= "NULL" and row.lore_id ~= "" then
				rankId = SWRP.Lore.EffectiveRankId( row.lore_id ) or rankId
			end

			cb( {
				battalion_id = row.battalion_id, rank_id = rankId,
				name = row.rp_name_base, id = row.id, online = false,
			} )
		end )
end

-- Same column whitelist as REC_META:Commit — keys are interpolated into SQL,
-- so the two mutation paths must never drift on this guard.
local MUTABLE = {
	rp_name_base = true, designation = true, battalion_id = true,
	rank_id = true, class_id = true, flags = true, lore_id = true,
}

local function applyTo( target, fields, respawn, done )
	if target.online then
		target.rec:Commit( fields, done, { respawn = respawn } )
		return
	end

	-- Offline: direct write-through (plan §3.2); bump record_version so other
	-- servers can invalidate stale in-memory copies (sync lands Phase 4).
	-- Deliberately hook-light: Recompute/CharacterChanged need a live player;
	-- SWRP.CharacterOfflineChanged is the offline-mutation signal instead.
	local sets, params = {}, {}
	for k, v in pairs( fields ) do
		if not MUTABLE[ k ] then
			log.Error( "applyTo: column '%s' is not mutable — ignored", k )
		else
			sets[ #sets + 1 ]     = k .. " = ?"
			params[ #params + 1 ] = v
		end
	end
	if #sets == 0 then done( "no valid fields" ) return end

	params[ #params + 1 ] = target.id

	DB.Query(
		"UPDATE swrp_characters SET " .. table.concat( sets, ", " ) ..
		", record_version = record_version + 1 WHERE id = ?",
		params, function( _, err )
			if not err then hook.Run( "SWRP.CharacterOfflineChanged", target.id, fields ) end
			done( err )
		end )
end

--------------------------------------------------------------------------------
-- Rank actions: promote / demote / kick
--------------------------------------------------------------------------------

-- COUNT-then-UPDATE on capped ranks is not atomic; serialize per
-- (battalion, rank) so two simultaneous promotions can't both pass the check.
-- (Cross-server atomicity arrives with the Phase 4 sync layer.)
local capLocks = {}

function Battalion.HandleAction( ply, action, targetId )
	local arec = Character.GetRecord( ply )
	if not arec then return end

	resolveTarget( targetId, function( target )
		if not target then notify( ply, false, "Target not found" ) return end

		local can, reason = Hierarchy.Can( ply, "can_" .. action, target )
		if not can then notify( ply, false, reason or "Not permitted" ) return end

		local battalion = Hierarchy.GetBattalion( target.battalion_id )
		local tRank     = Hierarchy.GetRank( target.rank_id )
		if not battalion or not tRank then notify( ply, false, "Target record is invalid" ) return end

		local function finish( fields, respawn, verb, detail, after )
			applyTo( target, fields, respawn, function( err )
				if after then after() end
				if err then notify( ply, false, "Database error" ) return end
				Audit.LogAction( ply, "battalion_" .. action, { id = target.id, rp_name_base = target.name }, detail )
				notify( ply, true, verb )
				Battalion.SendRoster( ply )
				hook.Run( "SWRP.Battalion" .. string.upper( action:sub( 1, 1 ) ) .. action:sub( 2 ), ply, target, detail )
			end )
		end

		if action == "promote" then
			local newRank = battalion.ladder.ranks[ tRank.index + 1 ]
			if not newRank then notify( ply, false, "Already at the highest rank" ) return end

			local aRank = Hierarchy.GetRank( arec.rank_id )
			if not aRank or newRank.index >= aRank.index then
				notify( ply, false, "Cannot promote to your rank or above" )
				return
			end

			-- Rank slot caps (1 CPT, 2 LT...) are persistent and DB-counted.
			if newRank.max then
				local key = battalion.id .. "|" .. newRank.id
				if capLocks[ key ] then
					notify( ply, false, "Another promotion to " .. newRank.name .. " is processing — try again" )
					return
				end
				capLocks[ key ] = true
				local function release() capLocks[ key ] = nil end

				DB.Query(
					"SELECT COUNT(*) AS n FROM swrp_characters WHERE battalion_id = ? AND rank_id = ?",
					{ battalion.id, newRank.id }, function( rows )
						local n = rows and rows[ 1 ] and tonumber( rows[ 1 ].n ) or 0
						if n >= newRank.max then
							release()
							notify( ply, false, newRank.name .. " slots are full (" .. n .. "/" .. newRank.max .. ")" )
							return
						end
						finish( { rank_id = newRank.id }, false,
							target.name .. " promoted to " .. newRank.name,
							{ from = tRank.id, to = newRank.id }, release )
					end )
			else
				finish( { rank_id = newRank.id }, false,
					target.name .. " promoted to " .. newRank.name,
					{ from = tRank.id, to = newRank.id } )
			end

		elseif action == "demote" then
			local newRank = battalion.ladder.ranks[ tRank.index - 1 ]
			if not newRank then notify( ply, false, "Already at the lowest rank" ) return end

			finish( { rank_id = newRank.id }, false,
				target.name .. " demoted to " .. newRank.name,
				{ from = tRank.id, to = newRank.id } )

		elseif action == "kick" then
			local default = Hierarchy.GetDefaultBattalion()
			if not default or default.id == target.battalion_id then
				notify( ply, false, "Target is already unassigned" )
				return
			end

			-- No void states: kicked players land in the default battalion at
			-- its lowest rank, applied via respawn if online.
			finish( {
				battalion_id = default.id,
				rank_id      = Hierarchy.LowestRank( default ).id,
			}, true,
				target.name .. " removed from " .. battalion.name,
				{ from = battalion.id, to = default.id } )
		end
	end )
end

--------------------------------------------------------------------------------
-- Invites (interaction framework — validated at send AND accept)
--------------------------------------------------------------------------------

function Battalion.HandleInvite( ply, target )
	local arec = Character.GetRecord( ply )
	local trec = Character.GetRecord( target )
	if not arec or not trec then return end

	local battalion = Hierarchy.GetBattalion( arec.battalion_id )
	if not battalion then return end

	-- Shared validation closure: runs at send AND again at accept time.
	local function validate()
		if not ( IsValid( ply ) and IsValid( target ) ) then return false, "player left" end

		local a = Character.GetRecord( ply )
		local t = Character.GetRecord( target )
		if not a or not t then return false, "record unavailable" end
		if a.battalion_id ~= battalion.id then return false, "you changed battalion" end
		if t.battalion_id == battalion.id then return false, "already a member" end

		local can, reason = Hierarchy.Can( ply, "can_invite" )
		if not can then return false, reason end

		return true
	end

	local id, reason = Interaction.Send( {
		type    = "battalion_invite",
		from    = ply,
		to      = target,
		title   = "Battalion invite",
		text    = Character.GetName( ply ) .. " invites you to the " .. battalion.name,
		expires = 30,
		validate = validate,

		onAccept = function()
			local t = Character.GetRecord( target )
			t:Commit( {
				battalion_id = battalion.id,
				rank_id      = Hierarchy.LowestRank( battalion ).id,
			}, function( err )
				if err then notify( ply, false, "Database error" ) return end
				Audit.LogAction( ply, "battalion_invite_accepted", t, { battalion = battalion.id } )
				notify( ply, true, t.rp_name_base .. " joined " .. battalion.name )
				notify( target, true, "Welcome to the " .. battalion.name )
				Battalion.SendRoster( ply )
				hook.Run( "SWRP.BattalionJoined", target, battalion )
			end, { respawn = true } )
		end,

		onDeny = function()
			notify( ply, false, trec.rp_name_base .. " declined the invite" )
		end,

		onExpire = function()
			notify( ply, false, "Invite to " .. trec.rp_name_base .. " expired" )
		end,
	} )

	if not id then
		notify( ply, false, "Invite failed: " .. ( reason or "?" ) )
	else
		notify( ply, true, "Invite sent to " .. trec.rp_name_base )
		Audit.LogAction( ply, "battalion_invite_sent", trec, { battalion = battalion.id } )
	end
end
