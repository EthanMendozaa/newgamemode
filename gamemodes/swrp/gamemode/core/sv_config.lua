--[[----------------------------------------------------------------------------
	SWRP — system config loader (server only)

	Loads server configuration from the SEPARATE swrp_config addon, so
	gamemode files are never edited and gamemode updates never clobber config
	(darkrpmodification model, invariant 6). The addon lives at:

	  addons/swrp_config/lua/
	  ├── swrp_config/        -- system config: settings, DB creds, disables
	  │                              (server-only — NEVER sent to clients)
	  └── swrp_customthings/  -- battalions, classes, ranks (shared; loaded
	                                 by sh_config.lua on both realms)

	Two-phase load:
	  • System (here, during core load): settings + DB credentials must be ready
	    before the DB connects on SWRP.Loaded.
	  • Customthings (sh_config.lua, on SWRP.Loaded): definitions that use
	    create*/assign* APIs registered by modules, then SWRP.ConfigLoaded.

	`swrp_reload_config` re-runs both phases (superadmin only).
------------------------------------------------------------------------------]]

if not SERVER then return end

local Config = SWRP.Config
local log    = SWRP.Logger( "Config" )

local SYSTEM_DIR = "swrp_config"

-- System files load in this order (others after, alphabetically). Disables
-- first so a server can turn off a shipped default before settings touch it.
local SYSTEM_ORDER = { "disabled_defaults.lua", "settings.lua", "mysql.lua" }

--------------------------------------------------------------------------------
-- Database credentials (used by mysql.lua in the addon)
--------------------------------------------------------------------------------

-- Validates DB config and hands it to the DB layer. Empty host => SQLite (the
-- DB layer's fallback), so the shipped default runs locally with no setup.
function Config.Database( tbl )
	local src = Config.Where( 1 )
	local res, errs = SWRP.Validate( tbl or {}, {
		host      = { type = "string", default = "" },
		port      = { type = "number", default = 3306 },
		username  = { type = "string", default = "" },
		password  = { type = "string", default = "" },
		database  = { type = "string", default = "" },
		server_id = { type = "string", default = "main" },
	}, { label = "db setting", source = src } )

	for _, e in ipairs( errs ) do log.Warn( e ) end

	SWRP.DB.SetConfig( {
		host     = res.host,
		port     = res.port,
		username = res.username,
		password = res.password,
		database = res.database,
	} )
	Config.Set( "server_id", res.server_id )
end

--------------------------------------------------------------------------------
-- File loading
--------------------------------------------------------------------------------

local function loadFile( path )
	if not file.Exists( path, "LUA" ) then return end
	local ok, err = pcall( include, path )
	if not ok then
		log.Error( "error loading %s: %s", path, tostring( err ) )
	end
end

-- Load every *.lua in `dir`, honouring `order` first, then the rest
-- alphabetically. Skips files that don't exist.
local function loadDir( dir, order )
	local files = file.Find( dir .. "/*.lua", "LUA" ) or {}

	local present = {}
	for _, f in ipairs( files ) do present[ string.lower( f ) ] = f end

	local loaded = {}
	if order then
		for _, name in ipairs( order ) do
			local f = present[ string.lower( name ) ]
			if f and not loaded[ f ] then
				loaded[ f ] = true
				loadFile( dir .. "/" .. f )
			end
		end
	end

	local rest = {}
	for _, f in pairs( present ) do if not loaded[ f ] then rest[ #rest + 1 ] = f end end
	table.sort( rest )
	for _, f in ipairs( rest ) do loadFile( dir .. "/" .. f ) end
end

function Config.LoadSystem()
	if not file.IsDir( SYSTEM_DIR, "LUA" ) then
		log.Warn( "swrp_config addon not found — using built-in defaults (SQLite)" )
		return
	end
	loadDir( SYSTEM_DIR, SYSTEM_ORDER )
	log.Info( "system config loaded" )
end

--------------------------------------------------------------------------------
-- Boot + reload
--------------------------------------------------------------------------------

-- Phase A: now, during core load — before the DB connects on SWRP.Loaded.
Config.LoadSystem()

concommand.Add( "swrp_reload_config", function( ply )
	if not SWRP.Util.IsStaff( ply ) then
		log.Warn( "%s tried to reload config without permission", ply:Nick() )
		return
	end

	log.Info( "reloading config..." )
	Config.LoadSystem()
	Config.LoadCustomthings()
	log.Info( "config reload complete" )
	-- NOTE: server-side reload only; clients keep their boot-time definitions.
	log.Warn( "files ADDED to swrp_customthings since boot cannot reach clients until restart (AddCSLuaFile is boot-time only); edits to existing files apply server-side only" )
end )
