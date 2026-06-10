--[[----------------------------------------------------------------------------
	Class module (shared) — templates, assignments, resolution, net contracts.

	Config API (FPtje-grade validation, never crashes):

	  CLASS_MEDIC = SWRP.createClass( "Medic", {
	      weapons = { "weapon_357" }, health = 100, armor = 50,
	      nameTag = "MED",                  -- shows in derived names
	      requiredCerts = {},               -- cert gates wired from day one (§3.8)
	  } )

	  SWRP.assignClass( BATTALION_501ST, CLASS_MEDIC, {
	      name = "501st Medic",             -- display override
	      max = 4,                          -- session-based slot limit
	      minRank = "SPC",                  -- rank gate (tag, name, or index)
	      models = { ... },                 -- battalion-specific models
	  } )

	Resolution order (plan §3.6): template defaults -> assignment overrides ->
	battalion base (models) -> player record. Resolved tables are computed once
	at SWRP.ConfigLoaded and cached on the assignment.

	IDs: template "medic"; assignment "<battalion_id>/medic" — class_id in the
	DB references the assignment.
------------------------------------------------------------------------------]]

SWRP.Class = SWRP.Class or {}
local Class     = SWRP.Class
local Hierarchy = SWRP.Hierarchy
local Config    = SWRP.Config
local log       = SWRP.Logger( "Class" )

Class.Templates   = Class.Templates or {}    -- template id -> template
Class.Assignments = Class.Assignments or {}  -- assignment id -> assignment
Class.ByBattalion = Class.ByBattalion or {}  -- battalion id -> { assignment ids }

--------------------------------------------------------------------------------
-- Config API: templates
--------------------------------------------------------------------------------

local TEMPLATE_SCHEMA = {
	weapons       = { type = "table",  default = {} },
	ammo          = { type = "table",  default = nil },   -- { smg1 = 90, ... }
	health        = { type = "number", default = 100, min = 1, max = 1000 },
	armor         = { type = "number", default = 0,   min = 0, max = 1000 },
	nameTag       = { type = "string", default = nil, max = 8 },
	models        = { type = "table",  default = nil },
	requiredCerts = { type = "table",  default = {} },    -- checked once certs ship (§3.8)
}

function SWRP.createClass( name, def )
	local src = Config.Where( 1 )

	if not isstring( name ) or name == "" then
		log.Error( "%s: createClass needs a name string", src or "?" )
		return nil
	end
	if Config.IsDisabled( name ) then
		log.Info( "class '%s' is disabled by config — skipped", name )
		return nil
	end

	local res, errs = SWRP.Validate( def, TEMPLATE_SCHEMA,
		{ label = "class field", source = src } )
	for _, e in ipairs( errs ) do log.Warn( e ) end

	local template = {
		id            = Hierarchy.Slug( name ),
		name          = name,
		weapons       = res.weapons,
		ammo          = res.ammo,
		health        = res.health,
		armor         = res.armor,
		nameTag       = res.nameTag,
		models        = res.models,
		requiredCerts = res.requiredCerts,
	}

	if Class.Templates[ template.id ] then
		log.Info( "class '%s' re-registered (config reload)", name )
	end
	Class.Templates[ template.id ] = template

	return template
end

--------------------------------------------------------------------------------
-- Config API: assignments
--------------------------------------------------------------------------------

local ASSIGN_SCHEMA = {
	name          = { type = "string",  default = nil, max = 48 },
	weapons       = { type = "table",   default = nil },   -- full replacement
	addWeapons    = { type = "table",   default = nil },
	removeWeapons = { type = "table",   default = nil },
	ammo          = { type = "table",   default = nil },
	health        = { type = "number",  default = nil, min = 1, max = 1000 },
	armor         = { type = "number",  default = nil, min = 0, max = 1000 },
	nameTag       = { type = "string",  default = nil, max = 8 },
	models        = { type = "table",   default = nil },
	max           = { type = "number",  default = nil, min = 1 },
	minRank       = { default = nil },                     -- rank tag/name/index
	exclusive     = { type = "boolean", default = false },
	requiredCerts = { type = "table",   default = nil },
}

function SWRP.assignClass( battalion, template, overrides )
	local src = Config.Where( 1 )

	if not istable( battalion ) or not battalion.id then
		log.Error( "%s: assignClass: first argument is not a battalion (disabled or typo?)", src or "?" )
		return nil
	end
	if not istable( template ) or not template.id then
		log.Error( "%s: assignClass: second argument is not a class template (disabled or typo?)", src or "?" )
		return nil
	end

	local res, errs = SWRP.Validate( overrides or {}, ASSIGN_SCHEMA,
		{ label = "assignment field", source = src } )
	for _, e in ipairs( errs ) do log.Warn( e ) end

	local assignment = {
		id        = battalion.id .. "/" .. template.id,
		battalion = battalion,
		template  = template,
		overrides = res,
		source    = src,
	}

	if Class.Assignments[ assignment.id ] then
		log.Info( "assignment '%s' re-registered (config reload)", assignment.id )
	else
		Class.ByBattalion[ battalion.id ] = Class.ByBattalion[ battalion.id ] or {}
		table.insert( Class.ByBattalion[ battalion.id ], assignment.id )
	end
	Class.Assignments[ assignment.id ] = assignment

	return assignment
end

function Class.GetAssignment( id )
	return Class.Assignments[ id ]
end

--------------------------------------------------------------------------------
-- Resolution (template -> assignment -> battalion)
--------------------------------------------------------------------------------

local function mergeWeapons( template, o )
	if o.weapons then return table.Copy( o.weapons ) end

	local out, seen = {}, {}
	local removed = {}
	for _, w in ipairs( o.removeWeapons or {} ) do removed[ w ] = true end

	for _, w in ipairs( template.weapons or {} ) do
		if not removed[ w ] and not seen[ w ] then
			seen[ w ] = true
			out[ #out + 1 ] = w
		end
	end
	for _, w in ipairs( o.addWeapons or {} ) do
		if not removed[ w ] and not seen[ w ] then
			seen[ w ] = true
			out[ #out + 1 ] = w
		end
	end
	return out
end

-- Compute an assignment's effective values; cached as assignment.resolved.
function Class.Resolve( assignment )
	if assignment.resolved then return assignment.resolved end

	local t, o, b = assignment.template, assignment.overrides, assignment.battalion

	local minRank = nil
	if o.minRank ~= nil then
		minRank = Hierarchy.FindRank( b, tostring( o.minRank ) )
		if not minRank and SERVER then
			log.Warn( "%s: assignment '%s' has unknown minRank '%s' — gate ignored",
				assignment.source or "?", assignment.id, tostring( o.minRank ) )
		end
	end

	assignment.resolved = {
		name          = o.name or ( b.tag .. " " .. t.name ),
		weapons       = mergeWeapons( t, o ),
		ammo          = o.ammo or t.ammo,
		health        = o.health or t.health,
		armor         = o.armor or t.armor,
		nameTag       = o.nameTag or t.nameTag,
		models        = o.models or t.models or b.models,
		max           = o.max,
		minRank       = minRank,
		requiredCerts = o.requiredCerts or t.requiredCerts or {},
	}
	return assignment.resolved
end

-- The battalion's default assignment (no-void target). Resolved at validation.
function Class.GetDefaultAssignment( battalion )
	return battalion and battalion._defaultAssignment or nil
end

--------------------------------------------------------------------------------
-- Registry validation + default-class enforcement (SWRP.ConfigLoaded)
--------------------------------------------------------------------------------

hook.Add( "SWRP.ConfigLoaded", "SWRP.Class.Validate", function()
	-- Rebuild the per-battalion index from the registry so assignments removed
	-- by a config reload don't linger as stale ids.
	Class.ByBattalion = {}
	for id, a in pairs( Class.Assignments ) do
		local list = Class.ByBattalion[ a.battalion.id ] or {}
		Class.ByBattalion[ a.battalion.id ] = list
		list[ #list + 1 ] = id
	end

	local exclusiveOwner = {}   -- template id -> battalion id

	for id, a in pairs( Class.Assignments ) do
		Class.Resolve( a )

		if a.overrides.exclusive then
			local owner = exclusiveOwner[ a.template.id ]
			if owner and owner ~= a.battalion.id and SERVER then
				log.Warn( "template '%s' is exclusive to '%s' but also assigned to '%s'",
					a.template.name, owner, a.battalion.id )
			else
				exclusiveOwner[ a.template.id ] = a.battalion.id
			end
		end
	end

	for _, b in pairs( Hierarchy.Battalions ) do
		local def = nil

		if istable( b.defaultClass ) and b.defaultClass.id then
			local id = b.id .. "/" .. b.defaultClass.id
			def = Class.Assignments[ id ]
			if not def then
				-- Required but not explicitly assigned: auto-assign bare so the
				-- no-void invariant always has a target.
				def = SWRP.assignClass( b, b.defaultClass )
				if SERVER then
					log.Info( "battalion '%s': defaultClass '%s' auto-assigned (no explicit assignClass)",
						b.name, b.defaultClass.name )
				end
			end
		end

		if def then
			-- Default classes may never be slot-limited or rank-gated (§3.6).
			local r = Class.Resolve( def )
			if r.max or r.minRank then
				if SERVER then
					log.Warn( "battalion '%s': default class '%s' may not have max/minRank — gates stripped",
						b.name, r.name )
				end
				r.max, r.minRank = nil, nil
			end
			b._defaultAssignment = def
		else
			b._defaultAssignment = nil
			if SERVER then
				log.Error( "battalion '%s' has no defaultClass — members get no loadout (set defaultClass)",
					b.name )
			end
		end
	end

	if SERVER then
		log.Info( "registry OK: %d template(s), %d assignment(s)",
			table.Count( Class.Templates ), table.Count( Class.Assignments ) )
	end
end )

--------------------------------------------------------------------------------
-- Net contracts
--------------------------------------------------------------------------------

-- Client asks for its battalion's class list + live slot state.
SWRP.Net.Register( "swrp.class.state_request", {
	from      = "client",
	rateLimit = { times = 10, seconds = 10 },
	schema    = {},
	onReceive = function( ply )
		if SERVER then Class.SendState( ply ) end
	end,
} )

-- { current = id, confirm = bool, classes = { { id, name, tag, health, armor,
--   weapons, max, used, eligible, reason }, ... } }
SWRP.Net.Register( "swrp.class.state", {
	from   = "server",
	schema = {
		{ name = "data", type = "table" },
	},
	onReceive = function( _, payload )
		if CLIENT then Class.OnState( payload.data ) end
	end,
} )

SWRP.Net.Register( "swrp.class.switch", {
	from      = "client",
	rateLimit = { times = 5, seconds = 10 },
	schema    = {
		{ name = "id", type = "string", max = 96 },
	},
	onReceive = function( ply, data )
		if SERVER then Class.HandleSwitch( ply, data.id ) end
	end,
} )
