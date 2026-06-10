--[[----------------------------------------------------------------------------
	Character module (client) — ready handshake + designation picker.

	Built on the UI kit (SWRP.UI) — first impression screen. It cannot be
	dismissed without choosing (first-join requirement), but never blocks
	gameplay — it's a window, not a lock screen.
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

	local UI    = SWRP.UI
	local theme = SWRP.Theme
	local C     = theme.colors

	frame = UI.Frame( 400, 240, "Choose your designation", { noClose = true } )

	local info = vgui.Create( "DLabel", frame.Body )
	info:SetText( "Pick a unique " .. digits .. "-digit designation — it becomes part of your name,\nlike 501st PVT 4456 Para. This is permanent (staff can change it)." )
	info:SetFont( "SWRP.Small" )
	info:SetTextColor( C.textDim )
	info:SetWrap( true )
	info:Dock( TOP )
	info:SetTall( 40 )

	local entry = UI.TextEntry( frame.Body )
	entry:Dock( TOP )
	entry:DockMargin( 0, theme.spacing.pad, 0, 0 )
	entry:SetNumeric( true )
	entry:SetUpdateOnType( true )
	entry:SetPlaceholderText( string.rep( "0", digits ) )
	entry.OnValueChange = function( self, value )
		if #value > digits then self:SetValue( string.sub( value, 1, digits ) ) end
	end

	local status = vgui.Create( "DLabel", frame.Body )
	status:SetText( "" )
	status:SetFont( "SWRP.Small" )
	status:Dock( TOP )
	status:DockMargin( 0, 6, 0, 0 )
	status:SetTall( 18 )
	frame._status = status

	local submit = UI.Button( frame.Body, "Claim designation", "primary", function()
		local value = entry:GetValue()
		if #value ~= digits or not string.match( value, "^%d+$" ) then
			status:SetText( "Must be exactly " .. digits .. " digits." )
			status:SetTextColor( C.danger )
			return
		end
		status:SetText( "Checking..." )
		status:SetTextColor( C.textDim )
		SWRP.Net.Send( "swrp.character.designation_claim", { designation = value } )
	end )
	submit:Dock( BOTTOM )

	entry.OnEnter = function() submit:DoClick() end
	entry:RequestFocus()
end

function Character.OnDesignationResult( ok, reason )
	if not IsValid( frame ) then return end

	local C = SWRP.Theme.colors
	if ok then
		frame:Remove()
		frame = nil
		SWRP.UI.Toast( "Designation set", "success" )
	else
		frame._status:SetText( reason ~= "" and reason or "Rejected — try another." )
		frame._status:SetTextColor( C.danger )
	end
end
