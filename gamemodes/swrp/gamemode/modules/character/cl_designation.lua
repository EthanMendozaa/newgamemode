--[[----------------------------------------------------------------------------
	Character module (client) — ready handshake + designation picker.

	The picker is intentionally plain Derma: it ships before the UI kit and
	visual-direction decision, and will be rebuilt on the kit in Phase 2.
	It cannot be dismissed without choosing (first-join requirement), but never
	blocks gameplay — it's a window, not a lock screen.
------------------------------------------------------------------------------]]

local Character = SWRP.Character

-- Tell the server our Lua state is fully loaded (prompts sent before this can
-- be lost in the void between InitialSpawn and client readiness).
hook.Add( "InitPostEntity", "SWRP.Character.ClientReady", function()
	SWRP.Net.Send( "swrp.character.client_ready", {} )
end )

--------------------------------------------------------------------------------
-- Designation picker
--------------------------------------------------------------------------------

local frame = nil

function Character.OpenDesignationPicker( digits )
	if IsValid( frame ) then frame:Remove() end

	frame = vgui.Create( "DFrame" )
	frame:SetSize( 340, 170 )
	frame:Center()
	frame:SetTitle( "Choose your designation" )
	frame:SetDraggable( true )
	frame:ShowCloseButton( false )   -- must choose one
	frame:MakePopup()

	local info = vgui.Create( "DLabel", frame )
	info:SetText( "Pick a unique " .. digits .. "-digit designation (e.g. 4456).\nIt becomes part of your name: 501st PVT 4456 Name" )
	info:SetWrap( true )
	info:Dock( TOP )
	info:DockMargin( 10, 4, 10, 0 )
	info:SetTall( 40 )

	local entry = vgui.Create( "DTextEntry", frame )
	entry:Dock( TOP )
	entry:DockMargin( 10, 8, 10, 0 )
	entry:SetTall( 30 )
	entry:SetNumeric( true )
	entry:SetUpdateOnType( true )
	entry:SetPlaceholderText( string.rep( "0", digits ) )
	entry.OnValueChange = function( self, value )
		if #value > digits then self:SetValue( string.sub( value, 1, digits ) ) end
	end

	local status = vgui.Create( "DLabel", frame )
	status:SetText( "" )
	status:Dock( TOP )
	status:DockMargin( 10, 4, 10, 0 )
	status:SetTall( 18 )
	frame._status = status

	local submit = vgui.Create( "DButton", frame )
	submit:SetText( "Claim designation" )
	submit:Dock( BOTTOM )
	submit:DockMargin( 10, 6, 10, 10 )
	submit:SetTall( 30 )
	submit.DoClick = function()
		local C = SWRP.Theme.colors
		local value = entry:GetValue()
		if #value ~= digits or not string.match( value, "^%d+$" ) then
			status:SetText( "Must be exactly " .. digits .. " digits." )
			status:SetTextColor( C.danger )
			return
		end
		status:SetText( "Checking..." )
		status:SetTextColor( C.textDim )
		SWRP.Net.Send( "swrp.character.designation_claim", { designation = value } )
	end

	entry.OnEnter = submit.DoClick
end

function Character.OnDesignationResult( ok, reason )
	if not IsValid( frame ) then return end

	local C = SWRP.Theme.colors
	if ok then
		frame:Remove()
		frame = nil
		chat.AddText( C.accent, "[SWRP] ", C.text, "Designation set." )
	else
		frame._status:SetText( reason ~= "" and reason or "Rejected — try another." )
		frame._status:SetTextColor( C.danger )
	end
end
