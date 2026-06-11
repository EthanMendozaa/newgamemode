--[[----------------------------------------------------------------------------
	Lore module (shared) — registry, config API, validation.

	  LORE_APPO = SWRP.createLoreCharacter( BATTALION_501ST, "Appo", {
	      commander  = true,                 -- top authority, one per battalion
	      tag        = "CDR",                -- rank tag shown in names/scoreboard
	      nameFormat = "{battalion} {rank} 1119 {name}",  -- replaces the format
	      class      = CLASS_RIFLEMAN,       -- base loadout template
	      health     = 200,                  -- bespoke overrides (§3.7)
	      addWeapons = { "weapon_357" },
	      models     = { "models/player/..." },
	  } )

	Non-commander lore characters pass `rank = "CPT"` (tag/name/index on the
	battalion's ladder) instead of `commander = true`.

	IDs: "<battalion id>/lore/<slug>". Occupancy lives in swrp_lore_slots
	(server file); this registry is config-defined and shared so clients can
	render names/tags. Validation: FPtje-grade, never crashes (invariant 6).
------------------------------------------------------------------------------]]

SWRP.Lore = SWRP.Lore or {}
local Lore      = SWRP.Lore
local Hierarchy = SWRP.Hierarchy
local Config    = SWRP.Config
local log       = SWRP.Logger( "Lore" )

Lore.Slots = Lore.Slots or {}   -- lore id -> definition

local LORE_SCHEMA = {
	commander     = { type = "boolean", default = false },
	rank          = { default = nil },                      -- tag/name/index (non-commander)
	tag           = { type = "string",  default = nil, max = 12 },
	nameFormat    = { type = "string",  default = nil, max = 96 },
	class         = { default = nil },                      -- class TEMPLATE handle
	weapons       = { type = "table",   default = nil },
	addWeapons    = { type = "table",   default = nil },
	removeWeapons = { type = "table",   default = nil },
	ammo          = { type = "table",   default = nil },
	health        = { type = "number",  default = nil, min = 1, max = 2000 },
	armor         = { type = "number",  default = nil, min = 0, max = 2000 },
	models        = { type = "table",   default = nil },
}

function SWRP.createLoreCharacter( battalion, name, def )
	local src = Config.Where( 1 )

	if not istable( battalion ) or not battalion.id then
		log.Error( "%s: createLoreCharacter: first argument is not a battalion (disabled or typo?)", src or "?" )
		return nil
	end
	if not isstring( name ) or name == "" then
		log.Error( "%s: createLoreCharacter needs a name string", src or "?" )
		return nil
	end
	if Config.IsDisabled( name ) then
		log.Info( "lore character '%s' is disabled by config — skipped", name )
		return nil
	end

	local res, errs = SWRP.Validate( def, LORE_SCHEMA,
		{ label = "lore field", source = src } )
	for _, e in ipairs( errs ) do log.Warn( e ) end

	local slot = {
		id        = battalion.id .. "/lore/" .. Hierarchy.Slug( name ),
		name      = name,
		battalion = battalion,
		def       = res,
		source    = src,
	}

	if Lore.Slots[ slot.id ] then
		log.Info( "lore character '%s' re-registered (config reload)", name )
	end
	Lore.Slots[ slot.id ] = slot

	return slot
end

function Lore.Get( id )
	return Lore.Slots[ id ]
end

function Lore.SlotsFor( battalionId )
	local out = {}
	for id, slot in pairs( Lore.Slots ) do
		if slot.battalion.id == battalionId then out[ #out + 1 ] = slot end
	end
	table.sort( out, function( a, b ) return a.name < b.name end )
	return out
end

--------------------------------------------------------------------------------
-- Derived rank (commander = virtual rank ABOVE the ladder, all permissions)
--------------------------------------------------------------------------------

local ALL_PERMS = setmetatable( {}, { __index = function() return true end } )

-- Register/fetch the virtual commander rank for a ladder. Lives in the
-- ladder's byId (so Hierarchy.GetRank resolves it on both realms) but NOT in
-- the ordered ranks array — promote/demote can never step into or past it.
local function commanderRank( ladder, tag )
	local id = ladder.id .. "/commander"
	if not ladder.byId[ id ] then
		ladder.byId[ id ] = {
			id          = id,
			index       = #ladder.ranks + 1,   -- strictly above every real rank
			name        = "Commander",
			tag         = tag or "CDR",
			permissions = ALL_PERMS,
			ladder      = ladder,
			virtual     = true,
		}
	end
	return ladder.byId[ id ]
end

-- The rank a slot confers, or nil (slot keeps the holder's own rank).
function Lore.SlotRank( slot )
	if slot.def.commander then
		return commanderRank( slot.battalion.ladder, slot.def.tag )
	end
	if slot.def.rank ~= nil then
		return Hierarchy.FindRank( slot.battalion, tostring( slot.def.rank ) )
	end
	return nil
end

-- For authority checks on offline lore-holders (battalion targeting).
function Lore.EffectiveRankId( loreId )
	local slot = Lore.Slots[ loreId ]
	if not slot then return nil end
	local rank = Lore.SlotRank( slot )
	return rank and rank.id or nil
end

--------------------------------------------------------------------------------
-- Resolved loadout (lore > class assignment > battalion, §3.7)
--------------------------------------------------------------------------------

local function mergeWeapons( base, d )
	if d.weapons then return table.Copy( d.weapons ) end

	local removed, seen, out = {}, {}, {}
	for _, w in ipairs( d.removeWeapons or {} ) do removed[ w ] = true end
	for _, w in ipairs( base or {} ) do
		if not removed[ w ] and not seen[ w ] then seen[ w ] = true out[ #out + 1 ] = w end
	end
	for _, w in ipairs( d.addWeapons or {} ) do
		if not removed[ w ] and not seen[ w ] then seen[ w ] = true out[ #out + 1 ] = w end
	end
	return out
end

function Lore.Resolve( slot )
	if slot.resolved then return slot.resolved end

	local d = slot.def
	local template = istable( d.class ) and d.class or nil

	slot.resolved = {
		weapons = mergeWeapons( template and template.weapons or {}, d ),
		ammo    = d.ammo or ( template and template.ammo ),
		health  = d.health or ( template and template.health ) or 100,
		armor   = d.armor or ( template and template.armor ) or 0,
		models  = d.models or ( template and template.models ) or slot.battalion.models,
	}
	return slot.resolved
end

--------------------------------------------------------------------------------
-- Validation (after customthings load)
--------------------------------------------------------------------------------

hook.Add( "SWRP.ConfigLoaded", "SWRP.Lore.Validate", function()
	local commanders = {}   -- battalion id -> slot name

	for id, slot in pairs( Lore.Slots ) do
		slot.resolved = nil
		Lore.Resolve( slot )

		if slot.def.commander then
			local existing = commanders[ slot.battalion.id ]
			if existing then
				if SERVER then
					log.Warn( "battalion '%s' has two commander slots ('%s', '%s') — only '%s' keeps commander authority",
						slot.battalion.name, existing, slot.name, existing )
				end
				slot.def.commander = false
			else
				commanders[ slot.battalion.id ] = slot.name
				commanderRank( slot.battalion.ladder, slot.def.tag )   -- register on both realms
			end
		elseif slot.def.rank ~= nil and not Lore.SlotRank( slot ) then
			if SERVER then
				log.Warn( "%s: lore character '%s' has unknown rank '%s' — holder keeps own rank",
					slot.source or "?", slot.name, tostring( slot.def.rank ) )
			end
		end
	end

	if SERVER and table.Count( Lore.Slots ) > 0 then
		log.Info( "registry OK: %d lore slot(s)", table.Count( Lore.Slots ) )
	end
end )
