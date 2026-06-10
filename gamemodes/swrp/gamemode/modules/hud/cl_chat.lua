--[[----------------------------------------------------------------------------
	HUD module (client) — chat names from the record.

	Chat lines render the DERIVED name in battalion color. The server stays
	untouched (PlayerSay etc. come with the chat module, Phase 4); this is
	purely presentation.
------------------------------------------------------------------------------]]

local Character = SWRP.Character

hook.Add( "OnPlayerChat", "SWRP.HUD.Chat", function( ply, text, teamChat, isDead )
	if not IsValid( ply ) then return end   -- server console etc: default handling

	local C    = SWRP.Theme.colors
	local args = {}

	if isDead then
		args[ #args + 1 ] = Color( 230, 90, 80 )
		args[ #args + 1 ] = "*DEAD* "
	end

	args[ #args + 1 ] = Character.GetColor( ply )
	args[ #args + 1 ] = Character.GetName( ply )
	args[ #args + 1 ] = C.text
	args[ #args + 1 ] = ": " .. text

	chat.AddText( unpack( args ) )
	return true
end )
