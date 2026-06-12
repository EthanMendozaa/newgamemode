--[[----------------------------------------------------------------------------
	SWRP — config validation framework + settings store (shared)

	The validation engine (`SWRP.Validate`) is the FPtje-grade core every
	create*/assign*/setting call runs through: it checks types, ranges, allowed
	values and custom rules, fills sane defaults for anything optional, and
	collects human-readable errors (with a source location and typo suggestions)
	instead of crashing. A misconfigured entry is skipped with a warning — never
	a server crash (invariant 6).

	Also defines the settings store (RegisterSetting / Get / Set). Actual values
	are loaded from the swrp_config addon by sv_config.lua; this file only
	defines schemas + defaults, so both realms share the same defaults.
------------------------------------------------------------------------------]]

SWRP.Config = SWRP.Config or {}
local Config = SWRP.Config
local log    = SWRP.Logger( "Config" )

--------------------------------------------------------------------------------
-- Typo suggestions (Levenshtein)
--------------------------------------------------------------------------------

local function levenshtein( a, b )
	local la, lb = #a, #b
	if la == 0 then return lb end
	if lb == 0 then return la end

	local prev = {}
	for j = 0, lb do prev[ j ] = j end

	for i = 1, la do
		local cur = { [0] = i }
		local ca  = string.sub( a, i, i )
		for j = 1, lb do
			local cost = ( ca == string.sub( b, j, j ) ) and 0 or 1
			cur[ j ] = math.min( prev[ j ] + 1, cur[ j - 1 ] + 1, prev[ j - 1 ] + cost )
		end
		prev = cur
	end
	return prev[ lb ]
end

-- Closest candidate to `key`, or nil if nothing is close enough to suggest.
local function suggest( key, candidates )
	local best, bestDist = nil, math.huge
	for _, c in ipairs( candidates ) do
		local d = levenshtein( string.lower( key ), string.lower( c ) )
		if d < bestDist then best, bestDist = c, d end
	end

	-- Only suggest when it's plausibly a typo, not a wild guess.
	if best and bestDist <= math.max( 2, math.floor( #key / 2 ) ) then return best end
	return nil
end

Config.Suggest = suggest

--------------------------------------------------------------------------------
-- Source location helper
--------------------------------------------------------------------------------

-- "file.lua:42" for the caller, for error messages. `level` = how many stack
-- frames above the Where() call to report; 1 (default) is Where's caller. A
-- create* API calls Config.Where(1) to blame its own caller (the config file).
function Config.Where( level )
	local info = debug.getinfo( ( level or 1 ) + 1, "Sl" )
	if not info then return nil end
	return ( info.short_src or info.source or "?" ) .. ":" .. ( info.currentline or 0 )
end

--------------------------------------------------------------------------------
-- The validation engine
--------------------------------------------------------------------------------

local function renderList( t )
	local parts = {}
	for _, v in ipairs( t ) do parts[ #parts + 1 ] = tostring( v ) end
	return table.concat( parts, ", " )
end

-- Validate a single value against a field definition. Returns ok, errMessage.
local function validateValue( v, def )
	local t = def.type
	if t and t ~= "any" then
		if t == "color" then
			if not IsColor( v ) then return false, "must be a Color" end
		elseif type( v ) ~= t then
			return false, string.format( "must be a %s, got %s", t, type( v ) )
		end
	end

	if def.oneOf then
		local found = false
		for _, o in ipairs( def.oneOf ) do if v == o then found = true break end end
		if not found then return false, "must be one of: " .. renderList( def.oneOf ) end
	end

	-- min/max bound a number's value, or a string/table's length.
	if def.min or def.max then
		local n
		if isnumber( v ) then n = v
		elseif isstring( v ) or istable( v ) then n = #v end
		if n then
			if def.min and n < def.min then return false, "is below minimum " .. def.min end
			if def.max and n > def.max then return false, "is above maximum " .. def.max end
		end
	end

	if def.validate then
		local ok, msg = def.validate( v )
		if not ok then return false, msg or "failed validation" end
	end

	return true
end

--[[
	Validate `input` against `schema` (key -> field def). Field def fields:
	  type      "string"|"number"|"boolean"|"table"|"function"|"color"|"any"
	  default   value used when the key is absent (or invalid)
	  required  true => absence is an error
	  oneOf     { allowed values }
	  min/max   numeric bound, or length bound for strings/tables
	  validate  function( v ) -> ok, msg   (custom rule)
	  desc      human description (docs only)

	ctx = { label = "setting", source = "file.lua:42" }

	Returns: result (always a full table with defaults filled), errors (array of
	strings). Never throws. Invalid fields fall back to their default.
]]
function SWRP.Validate( input, schema, ctx )
	input = input or {}
	ctx   = ctx or {}
	local label  = ctx.label or "field"
	local source = ctx.source

	local result, errors = {}, {}
	local function addErr( fmt, ... )
		local msg = string.format( fmt, ... )
		errors[ #errors + 1 ] = source and ( source .. ": " .. msg ) or msg
	end

	-- Schema key list for typo suggestions.
	local keys = {}
	for k in pairs( schema ) do keys[ #keys + 1 ] = k end

	-- Unknown keys (likely typos).
	for k in pairs( input ) do
		if schema[ k ] == nil then
			local s = suggest( k, keys )
			addErr( "unknown %s '%s'%s", label, k, s and ( " — did you mean '" .. s .. "'?" ) or "" )
		end
	end

	-- Validate each declared field, filling defaults.
	for k, def in pairs( schema ) do
		local v = input[ k ]
		if v == nil then
			if def.required then addErr( "missing required %s '%s'", label, k ) end
			result[ k ] = def.default
		else
			local ok, err = validateValue( v, def )
			if ok then
				result[ k ] = v
			else
				addErr( "%s '%s' %s — using default", label, k, err )
				result[ k ] = def.default
			end
		end
	end

	return result, errors
end

--------------------------------------------------------------------------------
-- Settings store
--------------------------------------------------------------------------------

Config.Settings    = Config.Settings or {}     -- key -> current value
Config.SettingDefs = Config.SettingDefs or {}  -- key -> field def

-- Register a setting and its default. Modules call this for their own settings.
function Config.RegisterSetting( key, def )
	Config.SettingDefs[ key ] = def
	if Config.Settings[ key ] == nil then Config.Settings[ key ] = def.default end
end

function Config.Get( key, fallback )
	local v = Config.Settings[ key ]
	if v == nil then return fallback end
	return v
end

-- Set a value (called from the addon's settings.lua). Validated against the
-- registered def; unknown keys warn with a suggestion; invalid values keep the
-- default. Blames the calling file:line.
function Config.Set( key, value )
	local src = Config.Where( 1 )

	local def = Config.SettingDefs[ key ]
	if not def then
		local keys = {}
		for k in pairs( Config.SettingDefs ) do keys[ #keys + 1 ] = k end
		local s = suggest( key, keys )
		log.Warn( "%sunknown setting '%s'%s",
			src and ( src .. ": " ) or "", key, s and ( " — did you mean '" .. s .. "'?" ) or "" )
		return
	end

	local res, errs = SWRP.Validate( { [ key ] = value }, { [ key ] = def },
		{ label = "setting", source = src } )
	for _, e in ipairs( errs ) do log.Warn( e ) end
	Config.Settings[ key ] = res[ key ]
end

--------------------------------------------------------------------------------
-- Disabled defaults
--------------------------------------------------------------------------------

Config.Disabled = Config.Disabled or {}

-- Mark a shipped default (battalion, class, ladder...) off before replacing it.
-- Domain create*/assign* APIs consult IsDisabled before registering. Disables
-- are declared in the addon's server-only disabled_defaults.lua, so clients
-- never see them — harmless, since clients only ever *render* entities that
-- the server actually put players in.
function Config.Disable( name )
	Config.Disabled[ string.lower( tostring( name ) ) ] = true
end

function Config.IsDisabled( name )
	return Config.Disabled[ string.lower( tostring( name ) ) ] == true
end

--------------------------------------------------------------------------------
-- Customthings loading (shared)
--
-- Battalion/class/rank definitions must exist on BOTH realms (clients render
-- tags/colors on scoreboard, overhead names, chat), so the customthings dir is
-- AddCSLuaFile'd and included on both. The system dir (swrp_config/) holds
-- DB credentials and stays strictly server-side — it is NEVER sent to clients.
--------------------------------------------------------------------------------

local CUSTOM_DIR = "swrp_customthings"

-- Definition dependency order: battalions reference ladders + class templates
-- (defaultClass); assignments reference classes AND battalions. Files not
-- listed load alphabetically afterwards.
local CUSTOM_ORDER = { "ranks.lua", "classes.lua", "battalions.lua", "assignments.lua", "lore.lua" }

local function includeCustomFile( path )
	if SERVER then AddCSLuaFile( path ) end
	local ok, err = pcall( include, path )
	if not ok then
		log.Error( "error loading %s: %s", path, tostring( err ) )
	end
end

function Config.LoadCustomthings()
	local files = file.Find( CUSTOM_DIR .. "/*.lua", "LUA" ) or {}

	local present = {}
	for _, f in ipairs( files ) do present[ string.lower( f ) ] = f end

	local count, loaded = 0, {}
	local function loadOne( f )
		if not f or loaded[ f ] then return end
		loaded[ f ] = true
		count = count + 1
		includeCustomFile( CUSTOM_DIR .. "/" .. f )
	end

	for _, name in ipairs( CUSTOM_ORDER ) do loadOne( present[ name ] ) end

	local rest = {}
	for _, f in pairs( present ) do if not loaded[ f ] then rest[ #rest + 1 ] = f end end
	table.sort( rest )
	for _, f in ipairs( rest ) do loadOne( f ) end

	if count > 0 then log.Info( "customthings loaded (%d file(s))", count ) end

	-- Deterministic "definitions are in" signal — modules validate registries
	-- here instead of racing other SWRP.Loaded listeners.
	hook.Run( "SWRP.ConfigLoaded" )
end

-- After all modules have loaded (their create*/assign* APIs exist by then).
hook.Add( "SWRP.Loaded", "SWRP.Config.LoadCustomthings", function()
	Config.LoadCustomthings()
end )

--------------------------------------------------------------------------------
-- Core settings (defaults; actual values come from the addon)
--------------------------------------------------------------------------------

Config.RegisterSetting( "name_format", {
	type    = "string",
	default = "{battalion} {rank} {classTag} {designation} {name}",
	desc    = "Template for derived player names. Tokens: {battalion} {rank} {classTag} {designation} {name}",
} )

Config.RegisterSetting( "respawn_confirmation", {
	type    = "boolean",
	default = true,
	desc    = "Ask the player to confirm before identity changes that respawn them.",
} )

Config.RegisterSetting( "designation_digits", {
	type    = "number",
	default = 4,
	min     = 3,
	max     = 6,
	desc    = "Number of digits in a player's chosen designation.",
} )

Config.RegisterSetting( "server_id", {
	type    = "string",
	default = "main",
	desc    = "Stable identity of this server for cross-server sync.",
} )

Config.RegisterSetting( "staff_groups", {
	type    = "table",
	default = { "superadmin" },
	desc    = "Usergroups treated as gamemode staff (works with any admin mod: SAM, ULX, ServerGuard...). CAMI inheritance to superadmin also counts automatically.",
} )
