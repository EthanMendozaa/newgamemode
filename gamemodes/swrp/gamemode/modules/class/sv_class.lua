--[[----------------------------------------------------------------------------
	Class module (server) — authoritative class state.

	• Injects the class resolver into Character.Recompute: derives the name's
	  classTag + model from the resolved assignment, and REPAIRS class_id to
	  the battalion default whenever it's invalid for the record's battalion
	  (covers battalion joins, kicks, config removals — no void states).
	• Session-based slot limits (locked decision): in-memory only, freed on
	  disconnect, switch-away, and battalion change. The DB never stores slots.
	• Switching: eligibility re-checked server-side, slot claimed atomically
	  in-memory BEFORE the async commit (rolled back on failure), applied via
	  respawn (invariant 4).
	• Spawn: PlayerLoadout gives the resolved weapons/ammo; health/armor applied
	  right after spawn.
------------------------------------------------------------------------------]]

local Class     = SWRP.Class
local Character = SWRP.Character
local Hierarchy = SWRP.Hierarchy
local Audit     = SWRP.Audit
local Config    = SWRP.Config
local UI        = SWRP.UI
local log       = SWRP.Logger( "Class" )

--------------------------------------------------------------------------------
-- Session slot tracking
--------------------------------------------------------------------------------

local slotHolders = {}   -- assignment id -> { record id = true }
local heldSlot    = {}   -- record id -> assignment id (only slot-limited ones)

local function slotCount( assignmentId )
	return table.Count( slotHolders[ assignmentId ] or {} )
end

local function releaseSlot( recordId )
	local id = heldSlot[ recordId ]
	if not id then return end
	heldSlot[ recordId ] = nil
	if slotHolders[ id ] then slotHolders[ id ][ recordId ] = nil end
end

local function claimSlot( recordId, assignmentId )
	releaseSlot( recordId )
	slotHolders[ assignmentId ] = slotHolders[ assignmentId ] or {}
	slotHolders[ assignmentId ][ recordId ] = true
	heldSlot[ recordId ] = assignmentId
end

hook.Add( "PlayerDisconnected", "SWRP.Class.FreeSlots", function( ply )
	local rec = Character.GetRecord( ply )
	if rec then releaseSlot( rec.id ) end
end )

-- Battalion changes invalidate the class (Recompute repairs it); free the slot.
hook.Add( "SWRP.CharacterChanged", "SWRP.Class.BattalionMove", function( ply, rec, fields )
	if fields.battalion_id then releaseSlot( rec.id ) end
end )

--------------------------------------------------------------------------------
-- Resolver injection (name tag, model, no-void repair)
--------------------------------------------------------------------------------

Character.SetClassResolver( function( rec, battalion )
	local assignment = Class.Assignments[ rec.class_id or "" ]
	local repaired   = false

	if not assignment or assignment.battalion.id ~= battalion.id then
		assignment = Class.GetDefaultAssignment( battalion )
		local newId = assignment and assignment.id or ""
		if ( rec.class_id or "" ) ~= newId then
			rec.class_id = newId
			repaired     = true
		end
	end

	if not assignment then
		return { tag = "", model = nil, repaired = repaired }
	end

	local resolved = Class.Resolve( assignment )

	local model = nil
	if resolved.models and #resolved.models > 0 then
		local n = tonumber( util.CRC( rec.id ) ) or 0
		model = resolved.models[ ( n % #resolved.models ) + 1 ]
	end

	return { tag = resolved.nameTag or "", model = model, repaired = repaired }
end )

--------------------------------------------------------------------------------
-- Eligibility (server-authoritative; reasons are player-facing)
--------------------------------------------------------------------------------

-- `forRec` may already hold a slot in the target class; their own slot never
-- blocks them.
local function eligibility( rec, assignment )
	local r = Class.Resolve( assignment )

	if assignment.battalion.id ~= rec.battalion_id then
		return false, "Wrong battalion"
	end

	if r.minRank then
		local myRank = Hierarchy.GetRank( rec.rank_id )
		if not myRank or myRank.index < r.minRank.index then
			return false, "Requires " .. r.minRank.name .. "+"
		end
	end

	-- Cert gates are schema-wired from day one (§3.8); enforced when the cert
	-- system ships (Phase 5). SWRP.Certs.Has is its documented contract.
	if #r.requiredCerts > 0 and SWRP.Certs and SWRP.Certs.Has then
		for _, cert in ipairs( r.requiredCerts ) do
			if not SWRP.Certs.Has( rec, cert ) then
				return false, "Requires certification"
			end
		end
	end

	if r.max then
		local used = slotCount( assignment.id )
		if heldSlot[ rec.id ] == assignment.id then used = used - 1 end
		if used >= r.max then
			return false, "Slots full (" .. used .. "/" .. r.max .. ")"
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- State for the class menu
--------------------------------------------------------------------------------

function Class.SendState( ply )
	local rec = Character.GetRecord( ply )
	if not rec then return end

	local list = {}
	for _, id in ipairs( Class.ByBattalion[ rec.battalion_id ] or {} ) do
		local a = Class.Assignments[ id ]   -- nil if removed by a config reload
		if a then
			local r = Class.Resolve( a )
			local ok, reason = eligibility( rec, a )

			list[ #list + 1 ] = {
				id       = id,
				name     = r.name,
				tag      = r.nameTag,
				health   = r.health,
				armor    = r.armor,
				weapons  = r.weapons,
				max      = r.max,
				used     = r.max and slotCount( id ) or nil,
				minRank  = r.minRank and r.minRank.name or nil,
				eligible = ok,
				reason   = ok and "" or reason,
			}
		end
	end

	table.sort( list, function( a, b ) return a.name < b.name end )

	SWRP.Net.Send( "swrp.class.state", ply, {
		data = {
			current = rec.class_id or "",
			confirm = Config.Get( "respawn_confirmation", true ),
			classes = list,
		},
	} )
end

--------------------------------------------------------------------------------
-- Switching
--------------------------------------------------------------------------------

function Class.HandleSwitch( ply, id )
	local rec = Character.GetRecord( ply )
	if not rec then return end

	local assignment = Class.Assignments[ id ]
	if not assignment or assignment.battalion.id ~= rec.battalion_id then
		UI.Notify( ply, false, "That class is not available to you" )
		return
	end

	if rec.class_id == id then
		UI.Notify( ply, false, "Already your current class" )
		return
	end

	local ok, reason = eligibility( rec, assignment )
	if not ok then
		UI.Notify( ply, false, reason )
		return
	end

	-- Claim the slot synchronously BEFORE the async DB write so two players
	-- can't both pass the check for the last opening; roll back on failure.
	local resolved   = Class.Resolve( assignment )
	local hadSlot    = heldSlot[ rec.id ]
	if resolved.max then claimSlot( rec.id, id ) end

	rec:Commit( { class_id = id }, function( err )
		if err then
			-- Roll back the optimistic claim.
			if resolved.max then
				releaseSlot( rec.id )
				if hadSlot then claimSlot( rec.id, hadSlot ) end
			end
			UI.Notify( ply, false, "Database error" )
			return
		end

		if not resolved.max then releaseSlot( rec.id ) end

		Audit.LogAction( ply, "class_switch", rec, { to = id } )
		UI.Notify( ply, true, "Now serving as " .. resolved.name )
		Class.SendState( ply )
		hook.Run( "SWRP.ClassChanged", ply, assignment )
	end, { respawn = true } )
end

--------------------------------------------------------------------------------
-- Spawn application: loadout + stats
--------------------------------------------------------------------------------

local function resolvedFor( ply )
	local rec = Character.GetRecord( ply )
	if not rec then return nil end
	local assignment = Class.Assignments[ rec.class_id or "" ]
	if not assignment then return nil end
	return Class.Resolve( assignment )
end

-- Re-equip a player with their resolved class loadout. Used by the spawn
-- loadout hook and by the armory entity (re-arm without respawn — refills
-- weapons/ammo only; health/armor stay spawn-time, so it's not a free heal).
-- Returns true if a class loadout was applied.
function Class.Equip( ply )
	local r = resolvedFor( ply )
	if not r then return false end   -- classless (misconfigured battalion)

	ply:StripWeapons()
	ply:StripAmmo()

	for _, weapon in ipairs( r.weapons ) do
		ply:Give( weapon )
	end
	for ammoType, count in pairs( r.ammo or {} ) do
		ply:GiveAmmo( count, ammoType, true )
	end

	-- Deferred: SelectWeapon inside PlayerLoadout switches out of prediction
	-- (wiki-documented client hitch); next tick is clean.
	local first = r.weapons[ 1 ]
	if first then
		timer.Simple( 0, function()
			if IsValid( ply ) and ply:Alive() and ply:HasWeapon( first ) then
				ply:SelectWeapon( first )
			end
		end )
	end

	return true
end

hook.Add( "PlayerLoadout", "SWRP.Class.Loadout", function( ply )
	if Class.Equip( ply ) then
		return true   -- suppress base loadout
	end
end )

hook.Add( "PlayerSpawn", "SWRP.Class.Stats", function( ply )
	-- Next tick: runs after the base gamemode finishes its spawn setup, so our
	-- values are the final word.
	timer.Simple( 0, function()
		if not IsValid( ply ) or not ply:Alive() then return end
		local r = resolvedFor( ply )
		if not r then return end

		ply:SetMaxHealth( r.health )
		ply:SetHealth( r.health )
		ply:SetArmor( r.armor )
	end )
end )
