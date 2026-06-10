--[[----------------------------------------------------------------------------
	Example module body (server-only).

	Demonstrates an sv_ file loading only on the server (never sent to clients),
	plus the DB layer: a module owns its migrations and round-trips data through
	the same async API regardless of driver.

	Schema note: primary keys are app-generated stable string IDs (invariant 5),
	NOT auto-increment — that keeps DDL identical across SQLite and MySQL and
	avoids dialect differences. Stick to VARCHAR/INTEGER/TEXT in migrations.
------------------------------------------------------------------------------]]

local log = SWRP.Logger( "Example" )

log.Info( "server-only file loaded" )

-- This module owns migration #1. The loader has already run every module's
-- registrations by the time the DB connects, so ordering is safe.
SWRP.DB.RegisterMigration( "example", 1, [[
	CREATE TABLE IF NOT EXISTS swrp_example (
		id         VARCHAR(64)  NOT NULL,
		note       VARCHAR(128) NOT NULL,
		created_at INTEGER      NOT NULL,
		PRIMARY KEY ( id )
	)
]] )

-- Once the DB is ready, prove a full round-trip works through whichever driver
-- is live (delete with the rest of this template module).
hook.Add( "SWRP.DBReady", "SWRP.Example.DBTest", function( driver )
	local id = "test-" .. os.time()

	SWRP.DB.Query(
		"INSERT INTO swrp_example ( id, note, created_at ) VALUES ( ?, ?, ? )",
		{ id, "hello from example", os.time() },
		function( _, err )
			if err then return end

			SWRP.DB.Query( "SELECT COUNT(*) AS n FROM swrp_example", function( rows )
				local n = rows and rows[ 1 ] and rows[ 1 ].n or "?"
				log.Info( "DB round-trip OK via %s — swrp_example has %s row(s)", driver, tostring( n ) )
			end )
		end
	)
end )
