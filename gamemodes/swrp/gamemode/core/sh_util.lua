--[[----------------------------------------------------------------------------
	SWRP — shared utilities

	Loaded first in the loader's CORE_ORDER, so every later core file and module
	can rely on it. Keep this lean: only genuinely cross-cutting primitives live
	here (logging, safe calls). Domain helpers belong in their own modules.
------------------------------------------------------------------------------]]

SWRP.Util = SWRP.Util or {}
local Util = SWRP.Util

--------------------------------------------------------------------------------
-- Logging
--------------------------------------------------------------------------------

local COL_TAG  = Color( 80, 170, 255 )
local COL_WARN = Color( 255, 180, 60 )
local COL_ERR  = Color( 255, 80, 80 )
local COL_TEXT = Color( 220, 220, 220 )

-- Only run string.format when args are supplied, so a pre-formatted message
-- containing a literal '%' (e.g. an echoed bad config value) logs safely.
local function fmtMsg( fmt, ... )
	if select( "#", ... ) > 0 then return string.format( fmt, ... ) end
	return fmt
end

-- Tagged logger factory. Each system grabs one:
--   local log = SWRP.Logger( "Net" )
--   log.Info( "registered %d message(s)", n )
function SWRP.Logger( tag )
	local label = "[SWRP" .. ( tag and ( ":" .. tag ) or "" ) .. "] "

	return {
		Info  = function( fmt, ... ) MsgC( COL_TAG,  label,               COL_TEXT, fmtMsg( fmt, ... ), "\n" ) end,
		Warn  = function( fmt, ... ) MsgC( COL_WARN, label .. "[warn] ",  COL_TEXT, fmtMsg( fmt, ... ), "\n" ) end,
		Error = function( fmt, ... ) MsgC( COL_ERR,  label .. "[error] ", COL_TEXT, fmtMsg( fmt, ... ), "\n" ) end,
	}
end

-- Canonical top-level logging API (untagged). Delegates to the loader's
-- implementation so exactly one place formats SWRP output.
SWRP.Log   = SWRP.Loader.Log
SWRP.Warn  = SWRP.Loader.Warn
SWRP.Error = SWRP.Loader.Error

--------------------------------------------------------------------------------
-- Safe execution
--------------------------------------------------------------------------------

-- pcall wrapper that logs the error instead of letting it bubble. Use anywhere
-- third-party/module code is invoked (net handlers, migration functions, hook
-- bodies) so one bad callback never takes down a load pass or net message.
-- Returns: ok (bool), result-or-error.
function Util.SafeCall( fn, ... )
	local ok, res = pcall( fn, ... )
	if not ok then
		SWRP.Error( "SafeCall: %s", tostring( res ) )
	end
	return ok, res
end

--------------------------------------------------------------------------------
-- Staff detection (admin-mod agnostic)
--
-- Never call ply:IsSuperAdmin() directly in gamemode code: admin suites
-- (SAM, ULX, ServerGuard...) override it, and some error client-side before
-- their rank data syncs (observed with SAM). This helper:
--   1. pcall-guards the IsSuperAdmin override,
--   2. checks the networked usergroup against the staff_groups setting,
--   3. walks CAMI inheritance (the standard admin-mod interop layer) to
--      superadmin when a CAMI-registered mod is present.
--------------------------------------------------------------------------------

function Util.IsStaff( ply )
	if not IsValid( ply ) then return true end   -- server console

	-- Admin-mod overrides can error mid-init (client); never trust them bare.
	local ok, super = pcall( ply.IsSuperAdmin, ply )
	if ok and super == true then return true end

	local group = ""
	local gok, g = pcall( ply.GetUserGroup, ply )
	if gok and isstring( g ) then group = g end

	local groups = ( SWRP.Config and SWRP.Config.Get( "staff_groups" ) ) or { "superadmin" }
	for _, allowed in ipairs( groups ) do
		if group == allowed then return true end
	end

	-- CAMI inheritance: any group that ultimately inherits superadmin counts.
	if CAMI and CAMI.GetUsergroup and group ~= "" then
		local ug, guard = CAMI.GetUsergroup( group ), 0
		while ug and guard < 16 do
			if ug.Name == "superadmin" then return true end
			if not ug.Inherits or ug.Inherits == ug.Name then break end
			ug = CAMI.GetUsergroup( ug.Inherits )
			guard = guard + 1
		end
	end

	return false
end

--------------------------------------------------------------------------------
-- Player lookup (commands, pickers)
--------------------------------------------------------------------------------

-- Find one online player by SteamID64/SteamID (exact) or a case-insensitive
-- fragment of their Steam or RP name. Returns player, or nil + reason
-- ("no match" / "ambiguous: A, B") — callers show the reason to the user.
function Util.FindPlayer( str )
	if not isstring( str ) or str == "" then return nil, "no target given" end
	local needle = string.lower( str )

	local matches = {}
	for _, p in ipairs( player.GetAll() ) do
		if p:SteamID64() == str or string.lower( p:SteamID() or "" ) == needle then
			return p
		end

		local rpName = ""
		if SWRP.Character and SWRP.Character.GetName then
			rpName = string.lower( SWRP.Character.GetName( p ) )
		end

		if string.find( string.lower( p:Nick() ), needle, 1, true )
			or string.find( rpName, needle, 1, true ) then
			matches[ #matches + 1 ] = p
		end
	end

	if #matches == 0 then return nil, "no player matches '" .. str .. "'" end
	if #matches > 1 then
		local names = {}
		for _, p in ipairs( matches ) do names[ #names + 1 ] = p:Nick() end
		return nil, "ambiguous: " .. table.concat( names, ", " )
	end
	return matches[ 1 ]
end
