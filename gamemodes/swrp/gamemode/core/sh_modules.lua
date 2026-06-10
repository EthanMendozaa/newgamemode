--[[----------------------------------------------------------------------------
	SWRP — module loader

	Responsibilities (Phase 0, build inventory #1):
	  1. Realm-aware file inclusion by filename prefix (sv_ / cl_ / sh_).
	  2. Load the gamemode's own `core/` files in a declared order.
	  3. Discover, dependency-sort, and load modules from two roots:
	       • the gamemode's   gamemode/modules/<name>/
	       • any addon's      lua/swrp_modules/<name>/
	     so future systems ship as standalone addons, zero core edits.

	Path resolution: GMod's "LUA" filesystem exposes gamemode files under
	"<gamemodefolder>/gamemode/..." — NOT at the gamemode root. Every file.Find
	and include in this loader therefore goes through Loader.GamemodeRoot
	("swrp/gamemode/"), exactly like DarkRP's GM.FolderName-prefixed loader.
	Addon drop-ins ("swrp_modules/...") resolve against mounted lua/ folders.
	(Relative includes like init.lua -> shared.lua work file-relative and don't
	need the prefix; only root-based lookups do.)

	Module convention:
	  modules/<name>/
	    ├── module.lua   -- OPTIONAL manifest; sets MODULE.Name/Version/Depends
	    ├── sh_*.lua     -- shared files (loaded on both realms)
	    ├── sv_*.lua     -- server-only files
	    └── cl_*.lua     -- client-only files (sent to clients automatically)

	All manifests run first across all modules so dependency order is resolved
	before any module body loads. While a module's body loads, the `MODULE`
	global points at that module's table (DarkRP-style); cleared afterwards.
------------------------------------------------------------------------------]]

SWRP.Loader = SWRP.Loader or {}
local Loader = SWRP.Loader

-- "swrp/gamemode/" — the LUA-filesystem prefix for this gamemode's files.
-- The engine sets GM.FolderName (and GM.Folder = "gamemodes/<name>") before
-- gamemode files run; GAMEMODE covers lua_refresh after load.
local gm       = GM or GAMEMODE or {}
local gmFolder = gm.FolderName or string.match( gm.Folder or "", "([^/]+)$" ) or "swrp"
Loader.GamemodeRoot = gmFolder .. "/gamemode/"

--------------------------------------------------------------------------------
-- Logging
--------------------------------------------------------------------------------

local TAG      = "[SWRP]"
local COL_TAG  = Color( 80, 170, 255 )
local COL_WARN = Color( 255, 180, 60 )
local COL_ERR  = Color( 255, 80, 80 )
local COL_TEXT = Color( 220, 220, 220 )

-- Only run string.format when args are actually supplied, so a pre-formatted
-- message containing a literal '%' can be logged safely.
local function fmtMsg( fmt, ... )
	if select( "#", ... ) > 0 then return string.format( fmt, ... ) end
	return fmt
end

function Loader.Log( fmt, ... )
	MsgC( COL_TAG, TAG .. " ", COL_TEXT, fmtMsg( fmt, ... ), "\n" )
end

function Loader.Warn( fmt, ... )
	MsgC( COL_WARN, TAG .. " [warn] ", COL_TEXT, fmtMsg( fmt, ... ), "\n" )
end

function Loader.Error( fmt, ... )
	MsgC( COL_ERR, TAG .. " [error] ", COL_TEXT, fmtMsg( fmt, ... ), "\n" )
end

--------------------------------------------------------------------------------
-- Realm-aware inclusion
--------------------------------------------------------------------------------

-- Include a single .lua file, deciding realm from its filename prefix.
-- `path` is relative to a Lua search root (gamemode root or lua/).
function Loader.IncludeRealm( path )
	local name   = string.GetFileFromFilename( path )
	local prefix = string.sub( name, 1, 3 )

	if prefix == "sv_" then
		if SERVER then include( path ) end
	elseif prefix == "cl_" then
		if SERVER then AddCSLuaFile( path ) else include( path ) end
	elseif prefix == "sh_" then
		if SERVER then AddCSLuaFile( path ) end
		include( path )
	else
		-- No recognised prefix: treat as shared, but flag it so the convention
		-- stays honest. (Never crash on a stray file.)
		Loader.Warn( "file '%s' has no sv_/cl_/sh_ prefix; loading as shared", path )
		if SERVER then AddCSLuaFile( path ) end
		include( path )
	end
end

-- Recursively include every .lua file under `dir` (a search-root-relative
-- path), optionally skipping files whose lowercased basename is in `skip`.
function Loader.IncludeDir( dir, skip )
	skip = skip or {}
	local files, dirs = file.Find( dir .. "/*", "LUA" )

	for _, f in ipairs( files or {} ) do
		if string.EndsWith( f, ".lua" ) and not skip[ string.lower( f ) ] then
			Loader.IncludeRealm( dir .. "/" .. f )
		end
	end

	for _, d in ipairs( dirs or {} ) do
		Loader.IncludeDir( dir .. "/" .. d, skip )
	end
end

--------------------------------------------------------------------------------
-- Core loading
--------------------------------------------------------------------------------

-- Files that must load before others, in this order. Listed by basename; any
-- that don't exist yet (Phase 0 is incremental) are silently skipped. Remaining
-- core files load alphabetically afterwards.
local CORE_ORDER = {
	"sh_util.lua",
	"sh_netwrapper.lua",
	"sv_database.lua",
	"sh_config.lua",      -- validation engine + settings store
	"sv_config.lua",      -- loads the swrp_config addon (needs DB.SetConfig)
	"sh_permissions.lua",
}

function Loader.LoadCore()
	local files = file.Find( Loader.GamemodeRoot .. "core/*.lua", "LUA" ) or {}

	-- Index what's present (excluding ourselves — already loaded).
	local present = {}
	for _, f in ipairs( files ) do
		if string.lower( f ) ~= "sh_modules.lua" then present[ f ] = true end
	end

	local loaded = {}
	local function load( f )
		if not present[ f ] or loaded[ f ] then return end
		loaded[ f ] = true
		Loader.IncludeRealm( Loader.GamemodeRoot .. "core/" .. f )
	end

	-- Declared order first, then everything else alphabetically.
	for _, f in ipairs( CORE_ORDER ) do load( f ) end

	local rest = {}
	for f in pairs( present ) do if not loaded[ f ] then rest[ #rest + 1 ] = f end end
	table.sort( rest )
	for _, f in ipairs( rest ) do load( f ) end
end

--------------------------------------------------------------------------------
-- Module discovery + dependency resolution
--------------------------------------------------------------------------------

-- Roots searched for modules, in priority order.
local MODULE_ROOTS = {
	Loader.GamemodeRoot .. "modules",   -- gamemode's own modules
	"swrp_modules",                     -- drop-in modules shipped by any addon (lua/)
}

-- Pass 1 — read every module's manifest so names + dependencies are known
-- before any body loads. Returns name(lowercase) -> meta.
local function discoverManifests()
	local found = {}

	for _, base in ipairs( MODULE_ROOTS ) do
		local _, dirs = file.Find( base .. "/*", "LUA" )
		for _, dir in ipairs( dirs or {} ) do
			local key  = string.lower( dir )
			local path = base .. "/" .. dir

			if found[ key ] then
				Loader.Warn( "duplicate module '%s' at '%s' ignored (already found at '%s')",
					dir, path, found[ key ].Path )
			else
				-- Seed the manifest table with defaults, then let module.lua override.
				MODULE = {
					Name    = dir,
					Folder  = dir,
					Version = "1.0.0",
					Depends = {},
					Path    = path,
					Root    = base,
				}

				local manifest = path .. "/module.lua"
				if file.Exists( manifest, "LUA" ) then
					if SERVER then AddCSLuaFile( manifest ) end
					include( manifest )
				end

				found[ key ] = MODULE
				MODULE = nil
			end
		end
	end

	return found
end

-- Topologically sort modules by their Depends. Drops modules with missing deps
-- or that sit in a dependency cycle, logging clearly. Returns an ordered list
-- of keys safe to load.
local function resolveOrder( modules )
	local order   = {}
	local visited = {}   -- fully resolved + queued
	local failed  = {}   -- missing dep / cycle / depends-on-failed
	local stack   = {}   -- currently being visited (cycle detection)

	-- Deterministic traversal regardless of pairs() ordering.
	local keys = {}
	for key in pairs( modules ) do keys[ #keys + 1 ] = key end
	table.sort( keys )

	local function visit( key, chain )
		if visited[ key ] then return true end
		if failed[ key ] then return false end

		if stack[ key ] then
			Loader.Error( "dependency cycle: %s -> %s", table.concat( chain, " -> " ), key )
			failed[ key ] = true
			return false
		end

		stack[ key ] = true
		local meta = modules[ key ]

		for _, dep in ipairs( meta.Depends or {} ) do
			local depKey = string.lower( dep )
			if not modules[ depKey ] then
				Loader.Error( "module '%s' requires missing dependency '%s' — skipped", meta.Name, dep )
				stack[ key ]  = nil
				failed[ key ] = true
				return false
			end

			chain[ #chain + 1 ] = key
			local ok = visit( depKey, chain )
			chain[ #chain ] = nil

			if not ok then
				Loader.Error( "module '%s' skipped: dependency '%s' failed to load", meta.Name, dep )
				stack[ key ]  = nil
				failed[ key ] = true
				return false
			end
		end

		stack[ key ]   = nil
		visited[ key ] = true
		order[ #order + 1 ] = key
		return true
	end

	for _, key in ipairs( keys ) do visit( key, {} ) end
	return order
end

function Loader.LoadModules()
	local modules = discoverManifests()
	local order   = resolveOrder( modules )

	for _, key in ipairs( order ) do
		local meta = modules[ key ]

		-- Expose the module table to its own body files, DarkRP-style.
		MODULE = meta
		Loader.IncludeDir( meta.Path, { ["module.lua"] = true } )
		MODULE = nil

		SWRP.Modules[ key ] = meta
		Loader.Log( "loaded module '%s' v%s", meta.Name, meta.Version )
	end

	return #order
end

-- Lookup helper for cross-module access (case-insensitive module name).
function SWRP.GetModule( name )
	return SWRP.Modules[ string.lower( tostring( name ) ) ]
end

--------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------

function Loader.Boot()
	Loader.Log( "booting v%s (%s realm, root '%s')", SWRP.Version, SWRP.Realm, Loader.GamemodeRoot )

	Loader.LoadCore()

	-- Sanity: if core produced nothing, the LUA-path root is wrong (or files
	-- are missing). This failure mode once shipped as a clean-looking boot —
	-- never let it be quiet again.
	if not SWRP.Util then
		Loader.Error( "CORE FAILED TO LOAD — file.Find found nothing under '%score/'. The gamemode is NOT running.", Loader.GamemodeRoot )
		return
	end

	local count = Loader.LoadModules()

	Loader.Log( "boot complete — %d module(s) loaded", count )

	-- Let modules/core react to a finished boot without touching this file.
	hook.Run( "SWRP.Loaded" )
end
