--[[----------------------------------------------------------------------------
	Hierarchy module (shared) — rank ladders, battalions, Hierarchy.Can.

	Definitions come from the config addon's customthings (shared on both
	realms), via the create* APIs below. The DB stores only STATE (who is in
	which battalion at which rank), keyed by the stable string IDs minted here —
	config renames don't orphan records as long as `id` stays stable.

	ID scheme:
	  battalion: explicit def.id, or slug of the name   -> "501st_legion"
	  rank:      "<ladder slug>/<rank slug>"            -> "clone/sergeant"

	Hierarchy.Can( actor, action, target ) is THE permission gate (plan §3.4):
	every interactive system calls it, always server-side at mutation time.
	Clients may call it too (to grey out UI), but the server re-checks.
------------------------------------------------------------------------------]]

SWRP.Hierarchy = SWRP.Hierarchy or {}
local Hierarchy = SWRP.Hierarchy
local Config    = SWRP.Config
local log       = SWRP.Logger( "Hierarchy" )

Hierarchy.Ladders    = Hierarchy.Ladders or {}     -- ladder id -> ladder
Hierarchy.Battalions = Hierarchy.Battalions or {}  -- battalion id -> battalion

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

-- "501st Legion" -> "501st_legion". Stable as long as the name (or explicit id)
-- doesn't change.
local function slug( s )
	s = string.lower( tostring( s ) )
	s = string.gsub( s, "[^%w]+", "_" )
	s = string.gsub( s, "^_+", "" )
	s = string.gsub( s, "_+$", "" )
	return s
end

Hierarchy.Slug = slug

--------------------------------------------------------------------------------
-- Rank ladders
--------------------------------------------------------------------------------

local RANK_SCHEMA = {
	name        = { type = "string",  required = true,  max = 32 },
	tag         = { type = "string",  required = true,  max = 12 },
	max         = { type = "number",  default = nil },   -- holders per battalion (nil = unlimited)
	permissions = { type = "table",   default = nil },   -- { can_invite = true, ... }
}

--[[
	RANKS_CLONE = SWRP.createRankLadder( "Clone", {
		{ name = "Private",  tag = "PVT" },
		{ name = "Sergeant", tag = "SGT", permissions = { can_invite = true } },
		...
	} )

	Entries are ordered lowest -> highest. Each gets a stable id
	"<ladder>/<rank>" and an index used for rank-order comparisons.
	Invalid entries are skipped with a warning, never fatal (invariant 6).
]]
function SWRP.createRankLadder( name, entries )
	local src = Config.Where( 1 )

	if not isstring( name ) or name == "" then
		log.Error( "%s: createRankLadder needs a name string", src or "?" )
		return nil
	end
	if not istable( entries ) then
		log.Error( "%s: createRankLadder '%s' needs a table of rank entries", src or "?", name )
		return nil
	end

	local ladder = {
		id     = slug( name ),
		name   = name,
		ranks  = {},   -- ordered, lowest first
		byId   = {},   -- rank id -> rank
	}

	for i, entry in ipairs( entries ) do
		local res, errs = SWRP.Validate( entry, RANK_SCHEMA,
			{ label = "rank field", source = src and ( src .. " (rank #" .. i .. ")" ) } )
		for _, e in ipairs( errs ) do log.Warn( e ) end

		if not res.name or not res.tag then
			log.Warn( "%s: rank #%d in ladder '%s' missing name/tag — skipped",
				src or "?", i, name )
		else
			local rank = {
				id          = ladder.id .. "/" .. slug( res.name ),
				index       = #ladder.ranks + 1,
				name        = res.name,
				tag         = res.tag,
				max         = res.max,
				permissions = res.permissions or {},
				ladder      = ladder,
			}

			if ladder.byId[ rank.id ] then
				log.Warn( "%s: duplicate rank '%s' in ladder '%s' — skipped", src or "?", res.name, name )
			else
				ladder.ranks[ rank.index ] = rank
				ladder.byId[ rank.id ]     = rank
			end
		end
	end

	if #ladder.ranks == 0 then
		log.Error( "%s: ladder '%s' has no valid ranks — not registered", src or "?", name )
		return nil
	end

	if Hierarchy.Ladders[ ladder.id ] then
		log.Info( "ladder '%s' re-registered (config reload)", name )
	end
	Hierarchy.Ladders[ ladder.id ] = ladder

	return ladder
end

function Hierarchy.GetLadder( id )
	return Hierarchy.Ladders[ id ]
end

-- Global rank lookup: "clone/sergeant" -> rank (or nil).
function Hierarchy.GetRank( rankId )
	if not isstring( rankId ) then return nil end
	local ladderId = string.match( rankId, "^([^/]+)/" )
	local ladder   = ladderId and Hierarchy.Ladders[ ladderId ]
	return ladder and ladder.byId[ rankId ] or nil
end

--------------------------------------------------------------------------------
-- Battalions
--------------------------------------------------------------------------------

local BATTALION_SCHEMA = {
	id           = { type = "string",  default = nil },  -- stable id override
	tag          = { type = "string",  required = true, max = 12 },
	color        = { type = "color",   default = Color( 255, 255, 255 ) },
	ranks        = { type = "table",   required = true,
		validate = function( v )
			if not istable( v.ranks ) or #v.ranks == 0 then
				return false, "must be a rank ladder (from createRankLadder)"
			end
			return true
		end },
	models       = { type = "table",   default = {} },
	default      = { type = "boolean", default = false },
	defaultClass = { default = nil },  -- required from Phase 3 (classes); optional until then
}

--[[
	BATTALION_501ST = SWRP.createBattalion( "501st Legion", {
		tag = "501st", color = Color( 65, 105, 225 ),
		ranks = RANKS_CLONE, models = { ... },
	} )

	Exactly one battalion must set `default = true` (validated after config
	load): new players land there, kicked players fall back to it (invariant 2).
]]
function SWRP.createBattalion( name, def )
	local src = Config.Where( 1 )

	if not isstring( name ) or name == "" then
		log.Error( "%s: createBattalion needs a name string", src or "?" )
		return nil
	end

	if Config.IsDisabled( name ) then
		log.Info( "battalion '%s' is disabled by config — skipped", name )
		return nil
	end

	local res, errs = SWRP.Validate( def, BATTALION_SCHEMA,
		{ label = "battalion field", source = src } )
	for _, e in ipairs( errs ) do log.Warn( e ) end

	if not res.tag or not res.ranks then
		log.Error( "%s: battalion '%s' missing required tag/ranks — not registered", src or "?", name )
		return nil
	end

	local battalion = {
		id           = res.id or slug( name ),
		name         = name,
		tag          = res.tag,
		color        = res.color,
		ladder       = res.ranks,
		models       = res.models,
		isDefault    = res.default,
		defaultClass = res.defaultClass,
	}

	if Hierarchy.Battalions[ battalion.id ] then
		log.Info( "battalion '%s' re-registered (config reload)", name )
	end
	Hierarchy.Battalions[ battalion.id ] = battalion

	return battalion
end

function Hierarchy.GetBattalion( id )
	return Hierarchy.Battalions[ id ]
end

-- Lowest rank of a battalion's ladder (where new members start).
function Hierarchy.LowestRank( battalion )
	return battalion and battalion.ladder and battalion.ladder.ranks[ 1 ] or nil
end

-- The no-void fallback battalion. Prefers the `default = true` flag; if config
-- forgot one, falls back to the alphabetically-first battalion with a warning
-- (never returns nil while any battalion exists).
local warnedNoDefault = false
function Hierarchy.GetDefaultBattalion()
	local first, firstId = nil, nil
	for id, b in pairs( Hierarchy.Battalions ) do
		if b.isDefault then return b end
		if firstId == nil or id < firstId then first, firstId = b, id end
	end

	if first and not warnedNoDefault then
		warnedNoDefault = true
		log.Warn( "no battalion sets default = true — falling back to '%s'", first.name )
	end
	return first
end

--------------------------------------------------------------------------------
-- Fuzzy lookups (commands)
--------------------------------------------------------------------------------

-- Find a rank on a battalion's ladder by name, tag, or 1-based index.
function Hierarchy.FindRank( battalion, str )
	if not battalion or not isstring( str ) or str == "" then return nil end
	local ladder = battalion.ladder

	local idx = tonumber( str )
	if idx and ladder.ranks[ idx ] then return ladder.ranks[ idx ] end

	local needle = slug( str )
	for _, rank in ipairs( ladder.ranks ) do
		if slug( rank.name ) == needle or string.lower( rank.tag ) == string.lower( str ) then
			return rank
		end
	end
	return nil
end

-- Find a battalion by id, name, or tag.
function Hierarchy.FindBattalion( str )
	if not isstring( str ) or str == "" then return nil end

	local direct = Hierarchy.Battalions[ str ]
	if direct then return direct end

	local needle = slug( str )
	for _, b in pairs( Hierarchy.Battalions ) do
		if b.id == needle or slug( b.name ) == needle
			or string.lower( b.tag ) == string.lower( str ) then
			return b
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Hierarchy.Can — THE permission gate
--------------------------------------------------------------------------------

-- The character module registers a resolver that maps a Player (or descriptor)
-- to { battalion_id, rank_id }. Keeping it injected avoids a hierarchy ->
-- character dependency (core/module layering stays one-directional).
local resolver = nil
function Hierarchy.SetResolver( fn )
	resolver = fn
end

local function resolve( who )
	if istable( who ) and who.battalion_id then return who end
	if resolver then return resolver( who ) end
	return nil
end

--[[
	Hierarchy.Can( actor, action, target ) -> ok, reason

	actor/target: Player entities or { battalion_id, rank_id } descriptors
	              (target optional for non-targeted actions).
	action:       a rank permission key, e.g. "can_invite", "can_promote".

	Rules (Phase 1):
	  • actor's rank must grant `action`
	  • targeted actions require same battalion
	  • targeted actions require target's rank strictly below actor's

	ALWAYS re-check server-side at mutation/accept time — client results are
	advisory only (UI greying).
]]
function Hierarchy.Can( actor, action, target )
	local a = resolve( actor )
	if not a then return false, "unknown actor" end

	local aRank = Hierarchy.GetRank( a.rank_id )
	if not aRank then return false, "actor has no valid rank" end

	if not aRank.permissions[ action ] then
		return false, "missing permission: " .. tostring( action )
	end

	if target ~= nil then
		local t = resolve( target )
		if not t then return false, "unknown target" end

		if t.battalion_id ~= a.battalion_id then
			return false, "target is not in your battalion"
		end

		local tRank = Hierarchy.GetRank( t.rank_id )
		if not tRank then return false, "target has no valid rank" end

		if tRank.index >= aRank.index then
			return false, "target does not rank below you"
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- Registry validation (server, after customthings load)
--------------------------------------------------------------------------------

if SERVER then
	hook.Add( "SWRP.ConfigLoaded", "SWRP.Hierarchy.Validate", function()
		local count, defaults = 0, 0
		for _, b in pairs( Hierarchy.Battalions ) do
			count = count + 1
			if b.isDefault then defaults = defaults + 1 end
		end

		if count == 0 then
			log.Error( "no battalions defined — add definitions to swrp_config's customthings" )
			return
		end
		if defaults == 0 then
			log.Warn( "no battalion sets default = true — new players will land in an arbitrary battalion" )
		elseif defaults > 1 then
			log.Warn( "%d battalions set default = true — only one should (using first found)", defaults )
		end

		log.Info( "registry OK: %d battalion(s), %d ladder(s)", count, table.Count( Hierarchy.Ladders ) )
	end )
end
