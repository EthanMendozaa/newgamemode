--[[----------------------------------------------------------------------------
	SWRP config — gamemode settings

	Simple key = value tuning. Each call is validated against the gamemode's
	registered settings: unknown keys warn (with a typo suggestion), bad values
	fall back to the default. None of this can crash the server.

	See every available key + its default by reading the RegisterSetting calls
	in the gamemode, or run `lua_run PrintTable(SWRP.Config.SettingDefs)`.
------------------------------------------------------------------------------]]

-- How derived player names are built. Tokens:
--   {battalion} {rank} {classTag} {designation} {name}
SWRP.Config.Set( "name_format", "{battalion} {rank} {classTag} {designation} {name}" )

-- Confirm before identity changes that respawn the player ("Switch to Heavy?
-- You will respawn.").
SWRP.Config.Set( "respawn_confirmation", true )

-- Digits in a player's chosen designation (3-6).
SWRP.Config.Set( "designation_digits", 4 )
