--[[----------------------------------------------------------------------------
	SWRP — shared bootstrap

	Runs on BOTH realms (included by init.lua on the server and cl_init.lua on
	the client). Defines gamemode metadata and the `SWRP` namespace, then
	hands off to the module loader. No gameplay logic lives here.
------------------------------------------------------------------------------]]

DeriveGamemode( "base" )

-- Working title — final (probably clone-wars) brand TBD. The internal `SWRP`
-- namespace/prefix is PERMANENT and brand-agnostic: when the real name lands,
-- only this line and swrp.txt's title change. Never rename tables/net/globals.
GM.Name    = "SWRP_UNNAMED"
GM.Author  = "Rene & Claude"
GM.Email   = ""
GM.Website = ""

--[[--------------------------------------------------------------------------
	Namespace. Globals do not cross realms, so each realm builds its own table;
	this is the single root every SWRP system hangs off of.
----------------------------------------------------------------------------]]
SWRP         = SWRP or {}
SWRP.Version = "0.1.0"
SWRP.Realm   = SERVER and "server" or "client"
SWRP.Modules = SWRP.Modules or {}

-- Pull in (and, on the server, send) the loader, then run it.
if SERVER then AddCSLuaFile( "core/sh_modules.lua" ) end
include( "core/sh_modules.lua" )

SWRP.Loader.Boot()
