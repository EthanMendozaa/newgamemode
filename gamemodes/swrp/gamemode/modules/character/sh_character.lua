--[[----------------------------------------------------------------------------
	Character module (shared) — accessors + net message contracts.

	The server is authoritative: the full record lives server-side only
	(plan §3.9). What other clients need to SEE is replicated as networked
	strings, set exclusively by Recompute:

	  SWRPName       -- fully formatted display name
	  SWRPBattalion  -- battalion id (client resolves tag/color via registry)
	  SWRPRank       -- rank id     (client resolves tag/name via registry)

	These accessors are the only sanctioned way to read identity on either
	realm. Everything is event-driven — values change only on record mutation.
------------------------------------------------------------------------------]]

SWRP.Character = SWRP.Character or {}
local Character = SWRP.Character
local Hierarchy = SWRP.Hierarchy

--------------------------------------------------------------------------------
-- Shared accessors (work on both realms, for any player entity)
--------------------------------------------------------------------------------

-- Formatted display name. Falls back to the Steam name until the record has
-- loaded and Recompute has run.
function Character.GetName( ply )
	local name = ply:GetNW2String( "SWRPName", "" )
	if name == "" then return ply:Nick() end
	return name
end

function Character.GetBattalion( ply )
	local id = ply:GetNW2String( "SWRPBattalion", "" )
	if id == "" then return nil end
	return Hierarchy.GetBattalion( id )
end

function Character.GetRank( ply )
	local id = ply:GetNW2String( "SWRPRank", "" )
	if id == "" then return nil end
	return Hierarchy.GetRank( id )
end

-- Battalion color with a neutral fallback, for UI code.
function Character.GetColor( ply )
	local b = Character.GetBattalion( ply )
	return b and b.color or Color( 180, 180, 180 )
end

-- The 4-digit designation, or "" until one is claimed.
function Character.GetDesignation( ply )
	return ply:GetNW2String( "SWRPDesignation", "" )
end

-- The class ASSIGNMENT id (e.g. "501st_legion/medic"), or "" while unset.
-- Resolve to a full assignment via SWRP.Class.GetAssignment (class module).
function Character.GetClassId( ply )
	return ply:GetNW2String( "SWRPClass", "" )
end

-- The named-slot id (e.g. "501st_legion/lore/appo"), or "" when none (§3.7).
function Character.GetLoreId( ply )
	return ply:GetNW2String( "SWRPLore", "" )
end

--------------------------------------------------------------------------------
-- Hierarchy resolver
--
-- Lets Hierarchy.Can accept Player entities without depending on this module.
-- Server-side it prefers the authoritative record (set in sv_character);
-- clients resolve from networked values (advisory UI checks only).
--------------------------------------------------------------------------------

Hierarchy.SetResolver( function( ply )
	if not ( IsValid( ply ) and ply:IsPlayer() ) then return nil end

	if SERVER and Character.GetRecord then
		local rec = Character.GetRecord( ply )
		-- _effRank: the DERIVED rank (virtual commander rank when a lore slot
		-- forces one) — what permission comparisons must use.
		if rec then return { battalion_id = rec.battalion_id, rank_id = rec._effRank or rec.rank_id } end
		return nil
	end

	local bat  = ply:GetNW2String( "SWRPBattalion", "" )
	local rank = ply:GetNW2String( "SWRPRank", "" )
	if bat == "" or rank == "" then return nil end
	return { battalion_id = bat, rank_id = rank }
end )

--------------------------------------------------------------------------------
-- Net message contracts (registered on both realms)
--------------------------------------------------------------------------------

-- Client tells the server its Lua state is fully loaded and it can receive UI
-- prompts (net messages sent during PlayerInitialSpawn can be lost).
SWRP.Net.Register( "swrp.character.client_ready", {
	from      = "client",
	rateLimit = { times = 3, seconds = 30 },
	schema    = {},
	onReceive = function( ply )
		if SERVER then Character.OnClientReady( ply ) end
	end,
} )

-- Server asks a first-join player to choose their designation.
SWRP.Net.Register( "swrp.character.designation_prompt", {
	from   = "server",
	schema = {
		-- bits = 4 carries 0-15; the designation_digits setting is capped at 6.
		{ name = "digits", type = "uint", bits = 4 },
	},
	onReceive = function( _, data )
		if CLIENT then Character.OpenDesignationPicker( data.digits ) end
	end,
} )

-- Client submits a chosen designation. Validated + uniqueness-checked
-- server-side; result comes back via designation_result.
SWRP.Net.Register( "swrp.character.designation_claim", {
	from      = "client",
	rateLimit = { times = 5, seconds = 10 },
	schema    = {
		{ name = "designation", type = "string", max = 8 },
	},
	onReceive = function( ply, data )
		if SERVER then Character.ClaimDesignation( ply, data.designation ) end
	end,
} )

SWRP.Net.Register( "swrp.character.designation_result", {
	from   = "server",
	schema = {
		{ name = "ok",     type = "bool" },
		{ name = "reason", type = "string", max = 64 },
	},
	onReceive = function( _, data )
		if CLIENT then Character.OnDesignationResult( data.ok, data.reason ) end
	end,
} )
