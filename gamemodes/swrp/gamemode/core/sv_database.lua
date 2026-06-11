--[[----------------------------------------------------------------------------
	SWRP — database layer (server only)

	One async, driver-agnostic API. Callers never know or care which backend is
	live:
	  • mysqloo — used when the binary module is installed AND credentials are
	              configured (via SWRP.DB.SetConfig). Truly async.
	  • SQLite  — automatic fallback for local dev (zero setup) or when mysqloo
	              is absent / fails to connect. Synchronous under the hood, but
	              results are delivered next-tick so the API shape is identical
	              and callbacks never fire inside the caller's stack frame.

	Invariant 5: all DB access is async; mutations write through immediately.

	Public API:
	  SWRP.DB.SetConfig{ host, port, username, password, database }
	  SWRP.DB.Query( sql [, params] [, cb] )     -- cb( rows, err )
	  SWRP.DB.Escape( str ) -> string            -- no surrounding quotes
	  SWRP.DB.RegisterMigration( namespace, id, upSqlOrFn )
	  SWRP.DB.IsReady() / .GetDriver()

	Parameterised queries use `?` placeholders, escaped per-driver:
	  SWRP.DB.Query( "SELECT * FROM x WHERE steamid = ?", { sid }, fn )

	Schema portability note: keep DDL to VARCHAR / INTEGER / TEXT and use
	app-generated stable string IDs as primary keys (invariant 5) — that keeps
	migrations identical across SQLite and MySQL with no dialect branching.

	Lifecycle: connect + migrations run on `SWRP.Loaded` (after every module
	has registered its migrations). `SWRP.DBReady` fires when usable; queries
	issued before that are queued and flushed in order.
------------------------------------------------------------------------------]]

if not SERVER then return end

SWRP.DB = SWRP.DB or {}
local DB  = SWRP.DB
local log = SWRP.Logger( "DB" )

DB.Config    = DB.Config or nil   -- set by the config addon; nil/blank host => SQLite
DB.Driver    = nil                -- "mysqloo" | "sqlite"
DB.Connected = false
DB.Ready     = false              -- connected AND migrations applied

local active   = nil              -- selected driver implementation
local preQueue = {}               -- queries issued before the DB is ready

function DB.SetConfig( cfg ) DB.Config = cfg end
function DB.IsReady()        return DB.Ready end
function DB.GetDriver()      return DB.Driver end

-- Explicit SQL NULL for parameter lists: a bare nil can't live in an array
-- (pairs/# skip it), so callers clearing a column pass DB.NULL instead.
DB.NULL = {}

--------------------------------------------------------------------------------
-- Parameter binding
--------------------------------------------------------------------------------

-- Replace `?` placeholders left-to-right with escaped/typed values. Strings are
-- escaped via the active driver and quoted; numbers inline; bools as 1/0; nil
-- as NULL. (Reserve `?` for placeholders in our SQL.)
--
-- Pattern note (verified): a lone "?" is a LITERAL in Lua patterns — the
-- quantifier meaning only binds to a preceding class — and function-replacement
-- results are never rescanned, so a bound value containing "?" cannot consume
-- later placeholders. Do not "fix" this to "%?"; it is already correct.
local function buildSQL( sqlStr, params )
	if not params or #params == 0 then return sqlStr end

	local i = 0
	return ( sqlStr:gsub( "?", function()
		i = i + 1
		local v = params[ i ]
		if v == nil or v == DB.NULL then return "NULL" end
		if isnumber( v ) then
			-- nan/inf would inline as malformed SQL; store NULL instead.
			if v ~= v or v == math.huge or v == -math.huge then return "NULL" end
			return tostring( v )
		end
		if isbool( v )   then return v and "1" or "0" end
		return "'" .. active.escape( tostring( v ) ) .. "'"
	end ) )
end

--------------------------------------------------------------------------------
-- Driver: SQLite (GMod's built-in, synchronous `sql` library)
--------------------------------------------------------------------------------

local sqlite      = {}
local sqliteFlush = {}   -- deferred result callbacks

function sqlite.connect( cfg, onDone ) onDone( true ) end
function sqlite.escape( str )          return sql.SQLStr( str, true ) end

function sqlite.query( finalSQL, onDone )
	local res = sql.Query( finalSQL )

	local rows, err
	if res == false then
		err = sql.LastError() or "sqlite error"
	elseif res == nil then
		rows = {}            -- valid query, no rows
	else
		rows = res
	end

	-- Deliver next-tick so callbacks never fire inside the caller's stack frame
	-- (matches mysqloo's deferred behaviour, so caller code can't accidentally
	-- depend on synchronous results).
	sqliteFlush[ #sqliteFlush + 1 ] = { cb = onDone, rows = rows, err = err }
end

hook.Add( "Tick", "SWRP.DB.SQLiteFlush", function()
	if #sqliteFlush == 0 then return end
	local batch = sqliteFlush
	sqliteFlush = {}
	for _, p in ipairs( batch ) do p.cb( p.rows, p.err ) end
end )

--------------------------------------------------------------------------------
-- Driver: mysqloo (async)
--------------------------------------------------------------------------------

local mysql   = {}
local mysqlDB = nil

function mysql.connect( cfg, onDone )
	if not pcall( require, "mysqloo" ) or not mysqloo then
		onDone( false, "mysqloo binary module not installed" )
		return
	end

	mysqlDB = mysqloo.connect( cfg.host, cfg.username, cfg.password, cfg.database, cfg.port or 3306 )
	mysqlDB.onConnected        = function()         onDone( true ) end
	mysqlDB.onConnectionFailed = function( _, err ) onDone( false, err ) end
	mysqlDB:connect()

	-- mysqloo needs polling to fire its callbacks.
	hook.Add( "Think", "SWRP.DB.Poll", function()
		if mysqlDB and mysqlDB.poll then mysqlDB:poll() end
	end )
end

function mysql.escape( str ) return mysqlDB:escape( str ) end

function mysql.query( finalSQL, onDone )
	local q = mysqlDB:query( finalSQL )
	q.onSuccess = function( _, data ) onDone( data or {}, nil ) end
	q.onError   = function( _, err )  onDone( nil, err ) end
	q:start()
end

--------------------------------------------------------------------------------
-- Query execution
--------------------------------------------------------------------------------

-- Unconditional execution against the active driver. Used internally
-- (migrations, preQueue flush). External callers go through DB.Query, which
-- gates on readiness.
local function rawQuery( sqlStr, params, cb )
	if isfunction( params ) then cb, params = params, nil end

	local final = buildSQL( sqlStr, params )
	active.query( final, function( rows, err )
		if err then log.Warn( "query error: %s | %s", err, final ) end
		if cb then SWRP.Util.SafeCall( cb, rows, err ) end
	end )
end

function DB.Query( sqlStr, params, cb )
	if isfunction( params ) then cb, params = params, nil end

	if DB.Failed then
		if cb then SWRP.Util.SafeCall( cb, nil, "database unavailable" ) end
		return
	end

	if not DB.Ready then
		preQueue[ #preQueue + 1 ] = { sqlStr, params, cb }
		return
	end

	rawQuery( sqlStr, params, cb )
end

function DB.Escape( str )
	if not active then return tostring( str ) end
	return active.escape( str )
end

--------------------------------------------------------------------------------
-- Migrations
--------------------------------------------------------------------------------

local migrations = {} -- { { namespace, id, up }, ... }

-- `up` is either a SQL string or a function( done ) that calls done() on
-- success or done( errString ) on failure. Modules own their own migrations.
function DB.RegisterMigration( namespace, id, up )
	migrations[ #migrations + 1 ] = { namespace = namespace, id = id, up = up }
end

local MIGRATIONS_TABLE = [[
	CREATE TABLE IF NOT EXISTS swrp_migrations (
		namespace  VARCHAR(64) NOT NULL,
		id         INTEGER     NOT NULL,
		applied_at INTEGER     NOT NULL,
		PRIMARY KEY ( namespace, id )
	)
]]

local function runMigrations( done )
	rawQuery( MIGRATIONS_TABLE, function( _, err )
		if err then log.Error( "could not create migrations table: %s", err ); done( false ); return end

		rawQuery( "SELECT namespace, id FROM swrp_migrations", function( rows )
			local applied = {}
			for _, r in ipairs( rows or {} ) do
				applied[ r.namespace .. "/" .. r.id ] = true
			end

			-- Pending only, ordered by namespace then numeric id.
			local pending = {}
			for _, m in ipairs( migrations ) do
				if not applied[ m.namespace .. "/" .. m.id ] then pending[ #pending + 1 ] = m end
			end
			table.sort( pending, function( a, b )
				if a.namespace ~= b.namespace then return a.namespace < b.namespace end
				return a.id < b.id
			end )

			-- Run sequentially; each must finish (and be recorded) before the next.
			local i = 0
			local function step()
				i = i + 1
				local m = pending[ i ]
				if not m then
					if #pending > 0 then log.Info( "applied %d migration(s)", #pending ) end
					done( true )
					return
				end

				local function finished( merr )
					if merr then
						log.Error( "migration %s#%d failed: %s", m.namespace, m.id, merr )
						done( false )
						return
					end
					rawQuery(
						"INSERT INTO swrp_migrations ( namespace, id, applied_at ) VALUES ( ?, ?, ? )",
						{ m.namespace, m.id, os.time() },
						function( _, ierr )
							if ierr then
								log.Error( "could not record migration %s#%d: %s", m.namespace, m.id, ierr )
								done( false )
								return
							end
							log.Info( "migrated %s#%d", m.namespace, m.id )
							step()
						end
					)
				end

				if isstring( m.up ) then
					rawQuery( m.up, function( _, err2 ) finished( err2 ) end )
				elseif isfunction( m.up ) then
					SWRP.Util.SafeCall( m.up, finished )
				else
					finished( "migration has no SQL string or function" )
				end
			end

			step()
		end )
	end )
end

--------------------------------------------------------------------------------
-- Connect + boot
--------------------------------------------------------------------------------

local function finishBoot()
	DB.Ready = true

	-- Flush anything queued before we were ready, in issue order.
	local q = preQueue
	preQueue = {}
	for _, item in ipairs( q ) do rawQuery( item[1], item[2], item[3] ) end

	log.Info( "ready (%s) — %d query(ies) were queued", DB.Driver, #q )
	hook.Run( "SWRP.DBReady", DB.Driver )
end

-- Migration failure: fail LOUDLY. DB.Ready stays false, but instead of letting
-- every future query queue silently forever, fail them (and the pre-queue)
-- through their callbacks so operators and code see the breakage immediately.
local function failBoot( why )
	DB.Failed = true
	log.Error( "DATABASE UNAVAILABLE: %s", why )
	log.Error( "All database operations will fail until this is fixed and the server restarts." )

	local q = preQueue
	preQueue = {}
	for _, item in ipairs( q ) do
		if item[3] then SWRP.Util.SafeCall( item[3], nil, "database unavailable" ) end
	end
end

local function bootAfterConnect()
	runMigrations( function( ok )
		if ok then finishBoot()
		else failBoot( "a migration failed (see errors above)" ) end
	end )
end

local function useSQLite( reason )
	active    = sqlite
	DB.Driver = "sqlite"
	if reason then log.Warn( "%s — using SQLite fallback", reason )
	else           log.Info( "using SQLite (local dev)" ) end

	sqlite.connect( nil, function()
		DB.Connected = true
		bootAfterConnect()
	end )
end

function DB.Connect()
	local cfg     = DB.Config
	local wantSQL = not ( cfg and cfg.host and cfg.host ~= "" )

	if wantSQL then
		useSQLite( nil )
		return
	end

	active    = mysql
	DB.Driver = "mysqloo"
	mysql.connect( cfg, function( ok, err )
		if ok then
			DB.Connected = true
			log.Info( "connected via mysqloo to '%s'", cfg.database )
			bootAfterConnect()
		else
			-- Policy: mysqloo missing or unreachable -> SQLite fallback, so the
			-- server always boots.
			useSQLite( "mysqloo connect failed (" .. tostring( err ) .. ")" )
		end
	end )
end

-- Connect after all modules have loaded so their migrations are registered
-- first. NOTE: this listener must run before sh_config's LoadCustomthings
-- listener is irrelevant — customthings never touch the DB — but DB credentials
-- MUST be set before this fires, which holds because sv_config.lua loads (and
-- runs LoadSystem synchronously) during core load, long before SWRP.Loaded.
hook.Add( "SWRP.Loaded", "SWRP.DB.Boot", function()
	DB.Connect()
end )
