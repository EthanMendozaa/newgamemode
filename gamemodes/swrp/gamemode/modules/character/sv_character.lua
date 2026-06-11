--[[----------------------------------------------------------------------------
	Character module (server) — record lifecycle + Recompute.

	THE single mutation path (invariant 1): every change goes through
	rec:Commit(fields), which writes through to the DB immediately
	(crash-safe, invariant 5), bumps record_version, re-derives everything via
	Character.Recompute, and fires SWRP.CharacterChanged. Nothing sets a
	player's name/model/battalion directly anywhere else.

	No void states (invariant 2): a record always has a valid battalion + rank.
	If config removed either (battalion deleted, ladder renamed), Recompute
	repairs the record to the default battalion / lowest rank and writes the fix
	through.

	Plain-Lua note: SQLite returns every column as a string; mysqloo returns
	typed values. coerceRow() normalises so the rest of the code never cares.
------------------------------------------------------------------------------]]

local Character = SWRP.Character
local Hierarchy = SWRP.Hierarchy
local Config    = SWRP.Config
local DB        = SWRP.DB
local log       = SWRP.Logger( "Character" )

local records = {} -- record id -> record (online players only)

--------------------------------------------------------------------------------
-- Migrations (this module owns its tables)
--------------------------------------------------------------------------------

DB.RegisterMigration( "character", 1, [[
	CREATE TABLE IF NOT EXISTS swrp_characters (
		id             VARCHAR(32) NOT NULL,
		steamid64      VARCHAR(32) NOT NULL,
		rp_name_base   VARCHAR(64) NOT NULL,
		designation    VARCHAR(8),
		battalion_id   VARCHAR(64) NOT NULL,
		rank_id        VARCHAR(96) NOT NULL,
		class_id       VARCHAR(96) NOT NULL DEFAULT '',
		playtime       INTEGER     NOT NULL DEFAULT 0,
		created_at     INTEGER     NOT NULL,
		flags          TEXT        NOT NULL DEFAULT '{}',
		record_version INTEGER     NOT NULL DEFAULT 1,
		PRIMARY KEY ( id )
	)
]] )

-- Designation is unique server-wide (multiple NULLs allowed on both SQLite and
-- MySQL, so unset designations don't collide).
-- No "IF NOT EXISTS" on indexes: MySQL doesn't support it (MariaDB-only), and
-- the swrp_migrations ledger already guarantees each migration runs once.
DB.RegisterMigration( "character", 2, [[
	CREATE UNIQUE INDEX swrp_characters_designation
	ON swrp_characters ( designation )
]] )

-- Rosters and rank slot-cap counts filter by battalion (and rank); keep those
-- scans indexed at 64-100 players x many offline records.
DB.RegisterMigration( "character", 3, [[
	CREATE INDEX swrp_characters_battalion
	ON swrp_characters ( battalion_id, rank_id )
]] )

-- Named slots (§3.7): the record's one nullable lore reference. Occupancy
-- itself lives in swrp_lore_slots (lore module) — this is the fast-path read.
DB.RegisterMigration( "character", 6, [[
	ALTER TABLE swrp_characters ADD COLUMN lore_id VARCHAR(96)
]] )

--------------------------------------------------------------------------------
-- Record access
--------------------------------------------------------------------------------

local function recordId( ply )
	-- Bots have no SteamID64; they get ephemeral in-memory records (no DB).
	return ply:SteamID64() or ( "BOT_" .. ply:EntIndex() )
end

function Character.GetRecord( ply )
	if not IsValid( ply ) then return nil end
	return records[ recordId( ply ) ]
end

-- Online lookup by record id (other modules act on roster entries by id).
function Character.GetRecordById( id )
	return records[ id ]
end

--------------------------------------------------------------------------------
-- Name derivation
--------------------------------------------------------------------------------

-- Strip control characters, trim, cap length. Used on the Steam name at first
-- join to seed rp_name_base.
local function sanitizeName( s )
	s = string.gsub( tostring( s ), "[%c]", "" )
	s = string.Trim( s )
	if s == "" then s = "Recruit" end
	return string.sub( s, 1, 32 )
end

-- Exposed for staff tools (admin setname etc.) — one sanitizer everywhere.
Character.SanitizeName = sanitizeName

-- Build the formatted display name from the record + config template.
-- Empty tokens (no designation yet, untagged class) collapse cleanly instead
-- of leaving double spaces. Lore characters replace the whole format and may
-- replace the {name} token with the lore identity (§3.7).
local function deriveName( rec, battalion, rank, classTag, loreInfo )
	local tokens = {
		battalion   = battalion.tag,
		rank        = rank.tag,
		classTag    = classTag or "",
		designation = rec.designation or "",
		name        = ( loreInfo and loreInfo.loreName ) or rec.rp_name_base,
	}

	local out = ( loreInfo and loreInfo.nameFormat ) or Config.Get( "name_format" )
	out = string.gsub( out, "{(%w+)}", function( key ) return tokens[ key ] or "" end )
	out = string.gsub( out, "%s+", " " )
	return string.Trim( out )
end

--------------------------------------------------------------------------------
-- Recompute — apply the record to the player entity (invariant 1)
--------------------------------------------------------------------------------

-- Deterministic model pick so a player keeps the same model across sessions.
local function pickModel( rec, battalion )
	local models = battalion.models
	if not models or #models == 0 then return nil end
	local n = tonumber( util.CRC( rec.id ) ) or 0
	return models[ ( n % #models ) + 1 ]
end

-- The class module injects this (same pattern as Hierarchy.SetResolver, so
-- character never depends on class). Called during Recompute with the already
-- battalion-repaired record; may repair rec.class_id (no-void) and returns
-- { tag = nameTag or "", model = string or nil, repaired = bool } or nil.
local classResolver = nil
function Character.SetClassResolver( fn )
	classResolver = fn
end

-- The lore module injects this (named slots, §3.7). Runs BEFORE rank/class
-- derivation; may repair rec.lore_id (slot removed from config / wrong
-- battalion) and returns nil or:
-- { rank = rankObj or nil (forced, e.g. virtual commander rank),
--   nameFormat = string or nil, loreName = string or nil,
--   model = string or nil, repaired = bool }
local loreResolver = nil
function Character.SetLoreResolver( fn )
	loreResolver = fn
end

function Character.Recompute( ply )
	local rec = Character.GetRecord( ply )
	if not rec then return end

	-- No-void repair: config may have removed this battalion/rank since the
	-- record was written. Fall back and write the fix through.
	local battalion = Hierarchy.GetBattalion( rec.battalion_id )
	if not battalion then
		battalion = Hierarchy.GetDefaultBattalion()
		if not battalion then
			log.Error( "no battalions registered — cannot recompute %s", rec.id )
			return
		end
		log.Warn( "record %s had unknown battalion '%s' — repaired to '%s'",
			rec.id, rec.battalion_id, battalion.name )
		rec.battalion_id = battalion.id
		rec.rank_id      = Hierarchy.LowestRank( battalion ).id
		rec._dirtyRepair = true
	end

	-- Lore resolution/repair (injected by the lore module). May clear an
	-- invalid rec.lore_id; may force the rank (commander sits above the ladder).
	local loreInfo = loreResolver and loreResolver( rec, battalion ) or nil
	if loreInfo and loreInfo.repaired then rec._dirtyRepair = true end

	local rank = loreInfo and loreInfo.rank or nil
	if not rank then
		rank = Hierarchy.GetRank( rec.rank_id )
		if not rank or rank.ladder ~= battalion.ladder then
			rank = Hierarchy.LowestRank( battalion )
			log.Warn( "record %s had invalid rank '%s' — repaired to '%s'",
				rec.id, tostring( rec.rank_id ), rank.name )
			rec.rank_id      = rank.id
			rec._dirtyRepair = true
		end
	end

	-- Class resolution/repair (injected by the class module; nil before Phase 3
	-- definitions exist). May fix rec.class_id to the battalion default.
	local classInfo = classResolver and classResolver( rec, battalion ) or nil
	if classInfo and classInfo.repaired then rec._dirtyRepair = true end

	if rec._dirtyRepair and not rec.isBot then
		rec._dirtyRepair = nil
		-- Keep the in-memory version in lockstep with the relative SQL bump, or
		-- the sync poller sees a phantom remote update on the next event.
		rec.record_version = rec.record_version + 1
		DB.Query( [[
			UPDATE swrp_characters
			SET battalion_id = ?, rank_id = ?, class_id = ?, lore_id = ?, record_version = record_version + 1
			WHERE id = ?
		]], { rec.battalion_id, rec.rank_id, rec.class_id or "", rec.lore_id, rec.id } )
	end

	-- The rank others must compare against (virtual commander rank when lore
	-- forces one). Consumed by the Hierarchy resolver + battalion targeting.
	rec._effRank = rank.id

	-- Derived state -> networked values (the ONLY place these are set).
	ply:SetNW2String( "SWRPName",        deriveName( rec, battalion, rank, classInfo and classInfo.tag, loreInfo ) )
	ply:SetNW2String( "SWRPBattalion",   battalion.id )
	ply:SetNW2String( "SWRPRank",        rank.id )
	ply:SetNW2String( "SWRPDesignation", rec.designation or "" )
	ply:SetNW2String( "SWRPClass",       rec.class_id or "" )
	ply:SetNW2String( "SWRPLore",        rec.lore_id or "" )

	-- Model applies on (re)spawn via the PlayerSetModel hook below; identity
	-- changes respawn the player (invariant 4). The live SetModel below covers
	-- ONLY the initial record load (player already spawned before the async DB
	-- round-trip finished) — never later mutations, which all respawn.
	-- Precedence: lore > class assignment > battalion base (§3.7).
	rec._model = ( loreInfo and loreInfo.model )
		or ( classInfo and classInfo.model )
		or pickModel( rec, battalion )
	if rec._model and not rec._modelApplied then
		rec._modelApplied = true
		if ply:Alive() and ply:GetModel() ~= rec._model then
			ply:SetModel( rec._model )
		end
	end

	hook.Run( "SWRP.CharacterRecomputed", ply, rec )
end

hook.Add( "PlayerSetModel", "SWRP.Character.Model", function( ply )
	local rec = Character.GetRecord( ply )
	if rec and rec._model then
		ply:SetModel( rec._model )
		return true
	end
end )

--------------------------------------------------------------------------------
-- The single mutation path
--------------------------------------------------------------------------------

local REC_META = {}
REC_META.__index = REC_META

-- Whitelisted mutable columns — keys end up interpolated into SQL.
local ALLOWED_FIELDS = {
	rp_name_base = true, designation = true, battalion_id = true,
	rank_id = true, class_id = true, flags = true, lore_id = true,
}

-- One queued commit. `done` MUST be called exactly once on every path so the
-- per-record queue advances; caller callbacks run through SafeCall so a buggy
-- cb can never stall the queue.
local function performCommit( rec, fields, cb, opts, done )
	local function apply()
		-- DB.NULL is the "clear this column" sentinel (a bare nil can't sit in
		-- a fields table); in memory it becomes a real nil.
		for k, v in pairs( fields ) do
			rec[ k ] = ( v ~= DB.NULL ) and v or nil
		end
		rec.record_version = rec.record_version + 1

		local ply = rec:GetPlayer()
		if IsValid( ply ) then
			Character.Recompute( ply )
			if opts and opts.respawn and ply:Alive() then ply:Spawn() end
			hook.Run( "SWRP.CharacterChanged", ply, rec, fields )
		end
		if cb then SWRP.Util.SafeCall( cb, nil ) end
		done()
	end

	if rec.isBot then apply() return end

	local sets, params = {}, {}
	for k, v in pairs( fields ) do
		if not ALLOWED_FIELDS[ k ] then
			log.Error( "Commit: field '%s' is not mutable — ignored", k )
		else
			sets[ #sets + 1 ]     = k .. " = ?"
			params[ #params + 1 ] = istable( v ) and util.TableToJSON( v ) or v
		end
	end
	if #sets == 0 then
		if cb then SWRP.Util.SafeCall( cb, "no valid fields" ) end
		done()
		return
	end

	params[ #params + 1 ] = rec.id

	DB.Query(
		"UPDATE swrp_characters SET " .. table.concat( sets, ", " ) ..
		", record_version = record_version + 1 WHERE id = ?",
		params,
		function( _, err )
			if err then
				log.Error( "Commit failed for %s: %s", rec.id, err )
				if cb then SWRP.Util.SafeCall( cb, err ) end
				done()
				return
			end
			apply()
		end
	)
end

-- Serialize any async job against this record. Every mutation AND every
-- sync reload goes through here, so nothing can interleave between another
-- job's DB round-trip and its in-memory apply. job( done ) must call done()
-- exactly once.
function REC_META:_Enqueue( job )
	local rec = self
	rec._commitQueue = rec._commitQueue or {}
	rec._commitQueue[ #rec._commitQueue + 1 ] = job

	if rec._committing then return end
	rec._committing = true

	local function step()
		local nextJob = table.remove( rec._commitQueue, 1 )
		if not nextJob then
			rec._committing = false
			return
		end
		nextJob( step )
	end

	step()
end

--[[
	rec:Commit( fields [, cb] [, opts] )

	Applies `fields` to the record: write-through UPDATE + record_version bump,
	then Recompute + SWRP.CharacterChanged. cb( err ) fires after the DB
	write (err = nil on success). opts.respawn respawns the player on success —
	identity changes apply via respawn (invariant 4).

	Commits on the SAME record are serialized through the record's job queue:
	each waits for the previous one's DB round-trip, so the in-memory record
	can never apply out of order against the DB (and record_version stays in
	lockstep).
]]
function REC_META:Commit( fields, cb, opts )
	local rec = self
	rec:_Enqueue( function( done )
		performCommit( rec, fields, cb, opts, done )
	end )
end

function REC_META:GetPlayer()
	return self._ply
end

--------------------------------------------------------------------------------
-- Load / create on join
--------------------------------------------------------------------------------

-- SQLite returns every value as a string; normalise the row.
local function coerceRow( row )
	row.playtime       = tonumber( row.playtime ) or 0
	row.created_at     = tonumber( row.created_at ) or 0
	row.record_version = tonumber( row.record_version ) or 1
	row.flags          = util.JSONToTable( row.flags or "{}" ) or {}
	if row.designation == "NULL" then row.designation = nil end
	if row.lore_id == "NULL" or row.lore_id == "" then row.lore_id = nil end
	return row
end

-- One load may be in flight per record id (fast reconnects can otherwise race
-- two SELECTs into double-INSERT / double-attach).
local loading = {}

local function attach( ply, rec )
	loading[ rec.id ] = nil
	if records[ rec.id ] then return end   -- a racing load attached first

	rec._ply      = ply
	rec._joinedAt = os.time()
	setmetatable( rec, REC_META )
	records[ rec.id ] = rec

	Character.Recompute( ply )
	hook.Run( "SWRP.CharacterLoaded", ply, rec )

	-- First-join designation prompt (if the client is already ready; otherwise
	-- OnClientReady sends it when the handshake arrives).
	if not rec.designation and rec._clientReady then
		Character.PromptDesignation( ply )
	end
end

local function createRecord( ply, id, sid64, unlock )
	local battalion = Hierarchy.GetDefaultBattalion()
	if not battalion then
		if unlock then unlock() end
		log.Error( "cannot create record for %s — no battalions registered", ply:Nick() )
		return
	end

	local rec = {
		id             = id,
		steamid64      = sid64 or id,
		rp_name_base   = sanitizeName( ply:Nick() ),
		designation    = nil,
		battalion_id   = battalion.id,
		rank_id        = Hierarchy.LowestRank( battalion ).id,
		class_id       = "",
		playtime       = 0,
		created_at     = os.time(),
		flags          = {},
		record_version = 1,
		isBot          = ply:IsBot(),
	}

	if rec.isBot then
		attach( ply, rec )
		return
	end

	-- Write-through immediately (designation omitted — stays NULL until
	-- claimed; nil params can't be passed positionally).
	DB.Query( [[
		INSERT INTO swrp_characters
			( id, steamid64, rp_name_base, battalion_id, rank_id, class_id,
			  playtime, created_at, flags, record_version )
		VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
	]], {
		rec.id, rec.steamid64, rec.rp_name_base, rec.battalion_id, rec.rank_id,
		rec.class_id, rec.playtime, rec.created_at, "{}", rec.record_version,
	}, function( _, err )
		if err then
			-- ply may have disconnected mid-flight; rec.id is always safe.
			if unlock then unlock() end
			log.Error( "failed to create record %s: %s", rec.id, err )
			return
		end
		if not IsValid( ply ) then if unlock then unlock() end return end
		log.Info( "created record %s (%s)", rec.id, rec.rp_name_base )
		attach( ply, rec )
	end )
end

function Character.Load( ply )
	local id    = recordId( ply )
	local sid64 = ply:SteamID64()

	if records[ id ] or loading[ id ] then return end   -- loaded / in flight

	if not sid64 then
		-- Bot: ephemeral record, never touches the DB.
		createRecord( ply, id, nil, nil )
		return
	end

	-- Token lock: a stale callback (player disconnected, lock cleared, player
	-- reconnected and started a NEW load) must not clear the new load's lock.
	local token = {}
	loading[ id ] = token
	local function unlock()
		if loading[ id ] == token then loading[ id ] = nil end
	end

	DB.Query( "SELECT * FROM swrp_characters WHERE id = ? LIMIT 1", { id },
		function( rows, err )
			if err then
				unlock()
				log.Error( "load failed for %s: %s", id, err )
				return
			end
			if not IsValid( ply ) then unlock() return end

			if rows and rows[ 1 ] then
				attach( ply, coerceRow( rows[ 1 ] ) )
			else
				createRecord( ply, id, sid64, unlock )   -- lock held until done
			end
		end )
end

hook.Add( "PlayerInitialSpawn", "SWRP.Character.Load", function( ply )
	Character.Load( ply )
end )

-- Re-pull an ONLINE record from the DB after another server mutated it
-- (cross-server sync). No-ops if our copy is already at/past that version.
-- Identity-affecting changes apply via respawn (invariant 4).
--
-- Serialized through the record's job queue: a reload can never run between
-- a local Commit's UPDATE and its in-memory apply (which would desync
-- record_version and silently suppress future syncs).
function Character.ReloadFromDB( id )
	local rec = records[ id ]
	if not rec or rec.isBot then return end

	rec:_Enqueue( function( done )
		-- Re-check: the player may have disconnected while queued.
		if records[ id ] ~= rec then done() return end

		DB.Query( "SELECT * FROM swrp_characters WHERE id = ? LIMIT 1", { id },
			function( rows, err )
				if err or not rows or not rows[ 1 ] then done() return end

				local row = coerceRow( rows[ 1 ] )
				if row.record_version <= rec.record_version then done() return end

				local identityChanged =
					row.battalion_id ~= rec.battalion_id
					or row.class_id ~= rec.class_id
					or row.lore_id ~= rec.lore_id

				rec.rp_name_base   = row.rp_name_base
				rec.designation    = row.designation
				rec.battalion_id   = row.battalion_id
				rec.rank_id        = row.rank_id
				rec.class_id       = row.class_id
				rec.lore_id        = row.lore_id
				rec.flags          = row.flags
				rec.record_version = row.record_version

				local ply = rec:GetPlayer()
				if not IsValid( ply ) then done() return end

				Character.Recompute( ply )
				if identityChanged and ply:Alive() then ply:Spawn() end
				SWRP.UI.Notify( ply, true, "Your record was updated" )
				hook.Run( "SWRP.CharacterSynced", ply, rec )

				log.Info( "synced record %s to v%d", id, row.record_version )
				done()
			end )
	end )
end

--------------------------------------------------------------------------------
-- Client-ready handshake + designation flow
--------------------------------------------------------------------------------

function Character.PromptDesignation( ply )
	SWRP.Net.Send( "swrp.character.designation_prompt", ply, {
		digits = Config.Get( "designation_digits", 4 ),
	} )
end

function Character.OnClientReady( ply )
	local rec = Character.GetRecord( ply )
	if rec then
		rec._clientReady = true
		if not rec.designation then Character.PromptDesignation( ply ) end
	else
		-- Record still loading; attach() will prompt.
		ply.SWRPClientReady = true
	end
end

-- attach() checks rec._clientReady; bridge the flag if ready arrived first.
hook.Add( "SWRP.CharacterLoaded", "SWRP.Character.ReadyBridge", function( ply, rec )
	if ply.SWRPClientReady then
		rec._clientReady = true
		if not rec.designation then Character.PromptDesignation( ply ) end
	end
end )

function Character.ClaimDesignation( ply, designation )
	local rec = Character.GetRecord( ply )
	if not rec then return end

	local function reply( ok, reason )
		SWRP.Net.Send( "swrp.character.designation_result", ply, {
			ok = ok, reason = reason or "",
		} )
	end

	if rec.designation then
		reply( false, "Designation already set" )
		return
	end

	local digits = Config.Get( "designation_digits", 4 )
	if #designation ~= digits or not string.match( designation, "^%d+$" ) then
		reply( false, "Must be exactly " .. digits .. " digits" )
		return
	end

	-- The UNIQUE index is the real arbiter — a constraint error means someone
	-- claimed it first (race-safe across servers).
	rec:Commit( { designation = designation }, function( err )
		if err then
			if string.find( err, "UNIQUE", 1, true ) or string.find( err, "Duplicate", 1, true ) then
				reply( false, "That designation is taken" )
			else
				reply( false, "Database error, try again" )
			end
			return
		end
		log.Info( "%s claimed designation %s", rec.rp_name_base, designation )
		reply( true, "" )
	end )
end

--------------------------------------------------------------------------------
-- Disconnect: playtime + cleanup
--------------------------------------------------------------------------------

hook.Add( "PlayerDisconnected", "SWRP.Character.Disconnect", function( ply )
	ply.SWRPClientReady = nil          -- entity tables can be reused
	loading[ recordId( ply ) ] = nil   -- a reconnect must be able to load fresh

	local rec = Character.GetRecord( ply )
	if not rec then return end

	if not rec.isBot then
		local session = os.time() - ( rec._joinedAt or os.time() )
		DB.Query(
			"UPDATE swrp_characters SET playtime = playtime + ? WHERE id = ?",
			{ session, rec.id } )
	end

	records[ rec.id ] = nil
end )
