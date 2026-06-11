--[[----------------------------------------------------------------------------
	Character module (server) — cross-server sync (plan §3.2, item 15).

	Servers sharing one MySQL instance must invalidate each other's in-memory
	records when one writes an OFFLINE mutation (the only case where a record
	can be live on server B while server A edits it). Mechanism: a swrp_sync
	event table, polled on a timer — lightweight by design; Redis can replace
	the transport later without touching callers.

	On SQLite (single server) this is inert: events are written, the poll
	finds only our own server_id and skips them.
------------------------------------------------------------------------------]]

local Character = SWRP.Character
local Config    = SWRP.Config
local DB        = SWRP.DB
local log       = SWRP.Logger( "Sync" )

local POLL_INTERVAL = 5   -- seconds; event-driven enough at this latency

DB.RegisterMigration( "character", 4, [[
	CREATE TABLE IF NOT EXISTS swrp_sync (
		at           INTEGER     NOT NULL,
		server_id    VARCHAR(32) NOT NULL,
		character_id VARCHAR(32) NOT NULL
	)
]] )

-- No "IF NOT EXISTS": MySQL doesn't support it on CREATE INDEX (MariaDB-only);
-- the migrations ledger already guarantees once-only execution.
DB.RegisterMigration( "character", 5, [[
	CREATE INDEX swrp_sync_at ON swrp_sync ( at )
]] )

local function serverId()
	return Config.Get( "server_id", "main" )
end

--------------------------------------------------------------------------------
-- Publish: every offline mutation broadcasts an invalidation event
--------------------------------------------------------------------------------

hook.Add( "SWRP.CharacterOfflineChanged", "SWRP.Sync.Publish", function( id )
	DB.Query(
		"INSERT INTO swrp_sync ( at, server_id, character_id ) VALUES ( ?, ?, ? )",
		{ os.time(), serverId(), id } )
end )

--------------------------------------------------------------------------------
-- Subscribe: poll for other servers' events, reload affected online records
--------------------------------------------------------------------------------

local lastPoll = os.time()

hook.Add( "SWRP.DBReady", "SWRP.Sync.Start", function( driver )
	timer.Create( "SWRP.Sync.Poll", POLL_INTERVAL, 0, function()
		local since = lastPoll
		lastPoll = os.time()

		-- ">=" tolerates 1s clock granularity; re-processing is harmless because
		-- reloads are version-gated AND serialized per record.
		DB.Query( [[
			SELECT DISTINCT character_id FROM swrp_sync
			WHERE at >= ? AND server_id <> ?
		]], { since, serverId() }, function( rows, err )
			if err or not rows then return end
			for _, r in ipairs( rows ) do
				-- Only matters if that character is online HERE.
				Character.ReloadFromDB( r.character_id )
			end
		end )

		-- Prune consumed events so the table can't grow forever. 60s retention
		-- comfortably covers every server's poll window; any server may prune.
		DB.Query( "DELETE FROM swrp_sync WHERE at < ?", { os.time() - 60 } )
	end )

	log.Info( "cross-server sync polling every %ds (server_id '%s', %s)",
		POLL_INTERVAL, serverId(), driver )
end )
