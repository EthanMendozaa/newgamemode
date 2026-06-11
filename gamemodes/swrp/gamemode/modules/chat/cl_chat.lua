--[[----------------------------------------------------------------------------
	Chat module (client) — rendering.

	Routed messages render the DERIVED name in battalion color with themed
	channel tags. Engine-broadcast messages from other addons keep default
	rendering (we don't intercept OnPlayerChat — our own speech never reaches
	it, since the server suppresses and re-routes).
------------------------------------------------------------------------------]]

local Chat      = SWRP.Chat
local Character = SWRP.Character

function Chat.Render( data )
	if not IsValid( data.sender ) then return end

	local C    = SWRP.Theme.colors
	local name = Character.GetName( data.sender )
	local col  = Character.GetColor( data.sender )
	local args = {}

	local function add( color, text )
		args[ #args + 1 ] = color
		args[ #args + 1 ] = text
	end

	if data.dead then add( C.danger, "*DEAD* " ) end

	if data.channel == "radio" then
		add( C.gold, "[RADIO] " )
		add( col, name )
		add( C.text, ": " .. data.text )
	elseif data.channel == "ooc" then
		add( C.textDim, "[OOC] " )
		add( col, name )
		add( C.textDim, ": " .. data.text )
	elseif data.channel == "me" then
		add( col, "* " .. name .. " " )
		add( C.textDim, data.text )
	else
		add( col, name )
		add( C.text, ": " .. data.text )
	end

	chat.AddText( unpack( args ) )
end
