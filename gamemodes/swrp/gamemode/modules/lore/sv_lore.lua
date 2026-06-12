--[[----------------------------------------------------------------------------
	Lore module (server) — occupancy, claims, offers, strips.

	Occupancy is a DB table with the lore id as PRIMARY KEY: claiming is one
	INSERT — atomic and race-safe across servers (the constraint is the
	arbiter, like designations). The character record carries lore_id as the
	fast-path read; both are written together.

	Authority (locked decision defaults): officers with the can_offer_lore
	rank permission (and commanders) offer lore slots within their battalion;
	the COMMANDER slot itself is granted by staff only. Slots free
	automatically on leaving the battalion, online or offline.

	Commands: !lore (list battalion slots), !offerlore <player> <slot>,
	!striplore <player>.
------------------------------------------------------------------------------]]

local Lore        = SWRP.Lore
local Character   = SWRP.Character
local Hierarchy   = SWRP.Hierarchy
local Class       = SWRP.Class
local Interaction = SWRP.Interaction
local Commands    = SWRP.Commands
local Audit       = SWRP.Audit
local Util        = SWRP.Util
local DB          = SWRP.DB
local log         = SWRP.Logger( "Lore" )

DB.RegisterMigration( "lore", 1, [[
	CREATE TABLE IF NOT EXISTS swrp_lore_slots (
		lore_id      VARCHAR(96) NOT NULL,
		character_id VARCHAR(32) NOT NULL,
		claimed_at   INTEGER     NOT NULL,
		PRIMARY KEY ( lore_id )
	)
]] )

--------------------------------------------------------------------------------
-- Resolver injections (character + class modules expose the seams)
--------------------------------------------------------------------------------

-- Deterministic model pick (same scheme as character/class).
local function pickModel( rec, models )
	if not models or #models == 0 then return nil end
	local n = tonumber( util.CRC( rec.id ) ) or 0
	return models[ ( n % #models ) + 1 ]
end

Character.SetLoreResolver( function( rec, battalion )
	if not rec.lore_id then return nil end

	local slot     = Lore.Slots[ rec.lore_id ]
	local repaired = false

	-- No-void repair: slot removed from config, or holder left its battalion.
	if not slot or slot.battalion.id ~= battalion.id then
		-- Free the occupancy row too (idempotent; scoped to this character).
		DB.Query( "DELETE FROM swrp_lore_slots WHERE lore_id = ? AND character_id = ?",
			{ rec.lore_id, rec.id } )
		log.Info( "record %s lost lore slot '%s' (invalid or wrong battalion)",
			rec.id, rec.lore_id )
		rec.lore_id = nil
		return { repaired = true }
	end

	local resolved = Lore.Resolve( slot )

	return {
		rank       = Lore.SlotRank( slot ),
		nameFormat = slot.def.nameFormat,
		loreName   = slot.name,
		model      = pickModel( rec, resolved.models ),
		repaired   = repaired,
	}
end )

-- Lore loadout replaces the class loadout entirely (§3.7 precedence).
Class.SetLoadoutOverride( function( rec )
	if not rec.lore_id then return nil end
	local slot = Lore.Slots[ rec.lore_id ]
	return slot and Lore.Resolve( slot ) or nil
end )

--------------------------------------------------------------------------------
-- Claim / release
--------------------------------------------------------------------------------

local function isStaff( ply )
	return SWRP.Util.IsStaff( ply )
end

-- May `ply` offer/strip this slot? Staff: any slot. Officers: can_offer_lore,
-- same battalion, and never the commander slot (staff-granted by default).
local function canOffer( ply, slot )
	if isStaff( ply ) then return true end
	if slot.def.commander then return false, "commander slots are granted by staff" end

	local rec = Character.GetRecord( ply )
	if not rec or rec.battalion_id ~= slot.battalion.id then
		return false, "not your battalion"
	end
	return Hierarchy.Can( ply, "can_offer_lore" )
end

-- Atomic claim: the PK INSERT is the arbiter; the record write follows and is
-- rolled back if the commit fails.
local function claim( target, slot, onDone )
	local rec = Character.GetRecord( target )
	if not rec then onDone( false, "record unavailable" ) return end

	DB.Query(
		"INSERT INTO swrp_lore_slots ( lore_id, character_id, claimed_at ) VALUES ( ?, ?, ? )",
		{ slot.id, rec.id, os.time() },
		function( _, err )
			if err then
				if string.find( err, "UNIQUE", 1, true ) or string.find( err, "Duplicate", 1, true )
					or string.find( err, "PRIMARY", 1, true ) then
					onDone( false, "already claimed" )
				else
					onDone( false, "database error" )
				end
				return
			end

			rec:Commit( { lore_id = slot.id }, function( cerr )
				if cerr then
					DB.Query( "DELETE FROM swrp_lore_slots WHERE lore_id = ?", { slot.id } )
					onDone( false, "database error" )
					return
				end
				hook.Run( "SWRP.LoreSlotClaimed", target, slot )
				onDone( true )
			end, { respawn = true } )
		end )
end

-- Strip an online holder. Recompute's resolver handles the no-void fallback.
local function release( target, onDone )
	local rec = Character.GetRecord( target )
	if not rec or not rec.lore_id then onDone( false, "no lore slot held" ) return end

	local loreId = rec.lore_id
	DB.Query( "DELETE FROM swrp_lore_slots WHERE lore_id = ? AND character_id = ?",
		{ loreId, rec.id } )

	rec:Commit( { lore_id = DB.NULL }, function( err )
		if err then onDone( false, "database error" ) return end
		hook.Run( "SWRP.LoreSlotFreed", target, loreId )
		onDone( true, loreId )
	end, { respawn = true } )
end

-- Offline battalion moves (kicks etc.) must free the slot too. The battalion
-- module's write-through already published a sync event; this follow-up write
-- bumps the version again so other servers converge on the lore-less record.
hook.Add( "SWRP.CharacterOfflineChanged", "SWRP.Lore.OfflineRelease", function( id, fields )
	if not fields.battalion_id then return end

	DB.Query( "DELETE FROM swrp_lore_slots WHERE character_id = ?", { id } )
	DB.Query( [[
		UPDATE swrp_characters SET lore_id = NULL, record_version = record_version + 1
		WHERE id = ? AND lore_id IS NOT NULL
	]], { id } )
end )

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

-- Find a slot in `battalionId` by name fragment.
local function findSlot( battalionId, fragment )
	fragment = string.lower( fragment or "" )
	if fragment == "" then return nil end

	local matches = {}
	for _, slot in ipairs( Lore.SlotsFor( battalionId ) ) do
		if string.find( string.lower( slot.name ), fragment, 1, true ) then
			matches[ #matches + 1 ] = slot
		end
	end

	if #matches == 1 then return matches[ 1 ] end
	if #matches > 1 then
		local names = {}
		for _, s in ipairs( matches ) do names[ #names + 1 ] = s.name end
		return nil, "ambiguous: " .. table.concat( names, ", " )
	end
	return nil, "no lore character matches '" .. fragment .. "'"
end

Commands.Register( "lore", {
	description = "List your battalion's lore characters and their holders",
	playerOnly  = true,
	handler = function( ply )
		local rec = Character.GetRecord( ply )
		if not rec then return end

		local slots = Lore.SlotsFor( rec.battalion_id )
		if #slots == 0 then
			Commands.Reply( ply, "Your battalion has no lore characters configured" )
			return
		end

		DB.Query( [[
			SELECT ls.lore_id, c.rp_name_base
			FROM swrp_lore_slots ls
			LEFT JOIN swrp_characters c ON c.id = ls.character_id
		]], function( rows )
			local holder = {}
			for _, r in ipairs( rows or {} ) do
				holder[ r.lore_id ] = r.rp_name_base or "?"
			end

			Commands.Reply( ply, "Lore characters:" )
			for _, slot in ipairs( slots ) do
				Commands.Reply( ply, string.format( "  %s%s — %s",
					slot.name,
					slot.def.commander and " (Commander)" or "",
					holder[ slot.id ] and ( "held by " .. holder[ slot.id ] ) or "open" ) )
			end
		end )
	end,
} )

Commands.Register( "offerlore", {
	description = "Offer a lore character: !offerlore <player> <character> (needs can_offer_lore; commander slots are staff-only)",
	playerOnly  = true,
	handler = function( ply, args )
		local target, err = Util.FindPlayer( args[ 1 ] or "" )
		if not target then Commands.Reply( ply, err ) return end

		local trec = Character.GetRecord( target )
		if not trec then Commands.Reply( ply, "Target has no loaded character yet" ) return end
		if trec.lore_id then Commands.Reply( ply, "Target already holds a lore character" ) return end

		local slot, serr = findSlot( trec.battalion_id, table.concat( args, " ", 2, #args ) )
		if not slot then Commands.Reply( ply, serr or "usage: !offerlore <player> <character>" ) return end

		local ok, reason = canOffer( ply, slot )
		if not ok then Commands.Reply( ply, reason or "Not permitted" ) return end

		local id, ierr = Interaction.Send( {
			type    = "lore_offer",
			from    = ply,
			to      = target,
			title   = "Lore character offer",
			text    = Character.GetName( ply ) .. " offers you the identity of " .. slot.name,
			expires = 30,

			-- Re-validated at accept: state may have changed (invariant 3).
			validate = function()
				if not ( IsValid( ply ) and IsValid( target ) ) then return false, "player left" end
				local t = Character.GetRecord( target )
				if not t then return false, "record unavailable" end
				if t.lore_id then return false, "already holds a lore character" end
				if t.battalion_id ~= slot.battalion.id then return false, "left the battalion" end
				return canOffer( ply, slot )
			end,

			onAccept = function()
				claim( target, slot, function( ok2, why )
					if not ok2 then
						SWRP.UI.Notify( ply, false, "Offer failed: " .. ( why or "?" ) )
						SWRP.UI.Notify( target, false, "Claim failed: " .. ( why or "?" ) )
						return
					end
					Audit.LogAction( ply, "lore_claimed", Character.GetRecord( target ), { slot = slot.id } )
					SWRP.UI.Notify( ply, true, slot.name .. " is now held by " .. trec.rp_name_base )
					SWRP.UI.Notify( target, true, "You are now " .. slot.name )
				end )
			end,

			onDeny = function()
				SWRP.UI.Notify( ply, false, trec.rp_name_base .. " declined " .. slot.name )
			end,

			onExpire = function()
				SWRP.UI.Notify( ply, false, "Lore offer to " .. trec.rp_name_base .. " expired" )
			end,
		} )

		if not id then
			Commands.Reply( ply, "Offer failed: " .. ( ierr or "?" ) )
		else
			Commands.Reply( ply, "Offered " .. slot.name .. " to " .. trec.rp_name_base )
			Audit.LogAction( ply, "lore_offer_sent", trec, { slot = slot.id } )
		end
	end,
} )

Commands.Register( "striplore", {
	description = "Remove a player's lore character: !striplore <player>",
	playerOnly  = true,
	handler = function( ply, args )
		local target, err = Util.FindPlayer( args[ 1 ] or "" )
		if not target then Commands.Reply( ply, err ) return end

		local trec = Character.GetRecord( target )
		if not trec or not trec.lore_id then
			Commands.Reply( ply, "Target holds no lore character" )
			return
		end

		local slot = Lore.Slots[ trec.lore_id ]
		if slot then
			local ok, reason = canOffer( ply, slot )
			if not ok then Commands.Reply( ply, reason or "Not permitted" ) return end
		elseif not isStaff( ply ) then
			Commands.Reply( ply, "Staff only" )   -- orphaned id: staff cleanup
			return
		end

		release( target, function( ok2, loreId )
			if not ok2 then Commands.Reply( ply, "Strip failed: " .. ( loreId or "?" ) ) return end
			Audit.LogAction( ply, "lore_stripped", trec, { slot = loreId } )
			Commands.Reply( ply, trec.rp_name_base .. " stripped of their lore character" )
			SWRP.UI.Notify( target, false, "Your lore character was removed" )
		end )
	end,
} )
