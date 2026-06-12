--[[----------------------------------------------------------------------------
	Prefs module (client) — JSON-backed preference store.

	  SWRP.Prefs.Get( key, fallback )
	  SWRP.Prefs.Set( key, value )            -- persists immediately
	  SWRP.Prefs.Register( category, key, label, default )  -- Settings tab row

	Storage: data/swrp/prefs.txt. Booleans only at Phase A (toggle rows).
------------------------------------------------------------------------------]]

SWRP.Prefs = SWRP.Prefs or {}
local Prefs = SWRP.Prefs

local PATH  = "swrp/prefs.txt"
local store = nil

local function load()
	if store then return end
	store = util.JSONToTable( file.Read( PATH, "DATA" ) or "" ) or {}
end

function Prefs.Get( key, fallback )
	load()
	local v = store[ key ]
	if v == nil then return fallback end
	return v
end

function Prefs.Set( key, value )
	load()
	store[ key ] = value
	file.CreateDir( "swrp" )
	file.Write( PATH, util.TableToJSON( store, true ) )
end

-- Settings-tab registry (ordered; category groups rows under a header).
Prefs.Defs = Prefs.Defs or {}

function Prefs.Register( category, key, label, default )
	Prefs.Defs[ #Prefs.Defs + 1 ] =
		{ category = category, key = key, label = label, default = default }
end

Prefs.Register( "General", "reduced_motion",  "Reduce menu motion",        false )
Prefs.Register( "HUD",     "overhead_names",  "Show overhead name tags",   true )
