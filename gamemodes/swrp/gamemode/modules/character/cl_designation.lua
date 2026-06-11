--[[----------------------------------------------------------------------------
	Character module (client) — ready handshake + designation picker (v4).

	Digit-box hero moment (approved mockup): type your number into big boxes,
	availability checks live as you complete it, claim when green. Cannot be
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
local state = { value = "", digits = 4, checked = nil, free = false }

function Character.OpenDesignationPicker( digits )
	if IsValid( frame ) then frame:Remove() end

	local UI    = SWRP.UI
	local theme = SWRP.Theme
	local C     = theme.colors

	state.value, state.digits, state.checked, state.free = "", digits, nil, false

	local boxW   = 56
	local boxGap = 10
	local w      = math.max( 420, digits * ( boxW + boxGap ) + 120 )

	frame = UI.Frame( w, 310, "Choose your designation", { noClose = true } )

	local info = vgui.Create( "DLabel", frame.Body )
	info:SetText( "Your number in the Grand Army — it becomes part of your name, permanently.\nExample: 501st PVT 4456 Para" )
	info:SetFont( "SWRP.Small" )
	info:SetTextColor( C.textDim )
	info:SetWrap( true )
	info:Dock( TOP )
	info:SetTall( 40 )

	-- Hidden entry captures keystrokes; the digit boxes render its value.
	local entry = vgui.Create( "DTextEntry", frame.Body )
	entry:SetSize( 1, 1 )
	entry:SetPos( -10, -10 )
	entry:SetNumeric( true )
	entry:SetUpdateOnType( true )
	entry.OnValueChange = function( self, value )
		value = string.sub( string.gsub( value, "%D", "" ), 1, digits )
		if value ~= self:GetValue() then self:SetValue( value ) end

		state.value   = value
		state.checked = nil
		state.free    = false

		if #value == digits then
			SWRP.Net.Send( "swrp.character.designation_check", { designation = value } )
		end
	end

	-- Digit boxes
	local boxes = vgui.Create( "DPanel", frame.Body )
	boxes:Dock( TOP )
	boxes:SetTall( 78 )
	boxes:DockMargin( 0, 14, 0, 0 )
	boxes:SetCursor( "hand" )
	boxes.OnMousePressed = function() entry:RequestFocus() end

	boxes.Paint = function( self, bw, bh )
		local total = digits * boxW + ( digits - 1 ) * boxGap
		local x     = ( bw - total ) / 2

		for i = 1, digits do
			local ch     = string.sub( state.value, i, i )
			local active = ( #state.value == i - 1 ) and entry:HasFocus()

			surface.SetDrawColor( C.barBack )
			draw.RoundedBox( theme.kit.radius, x, 4, boxW, 68, C.barBack )
			surface.SetDrawColor( active and C.accent or
				( state.checked and ( state.free and C.success or C.danger ) or C.divider ) )
			surface.DrawOutlinedRect( x, 4, boxW, 68, 1 )

			draw.SimpleText( ch ~= "" and ch or "–", "SWRP.Digit",
				x + boxW / 2, 38, ch ~= "" and C.text or C.divider,
				TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

			x = x + boxW + boxGap
		end
	end

	local status = vgui.Create( "DLabel", frame.Body )
	status:SetText( "Click the boxes and type " .. digits .. " digits." )
	status:SetFont( "SWRP.Small" )
	status:SetTextColor( C.textDim )
	status:SetContentAlignment( 5 )
	status:Dock( TOP )
	status:DockMargin( 0, 8, 0, 0 )
	status:SetTall( 20 )
	frame._status = status

	local submit = UI.Button( frame.Body, "Claim designation", "primary", function()
		if #state.value ~= digits then
			status:SetText( "Must be exactly " .. digits .. " digits." )
			status:SetTextColor( C.danger )
			return
		end
		status:SetText( "Claiming..." )
		status:SetTextColor( C.textDim )
		SWRP.Net.Send( "swrp.character.designation_claim", { designation = state.value } )
	end )
	submit:Dock( BOTTOM )

	entry.OnEnter = function() submit:DoClick() end
	entry:RequestFocus()
end

-- Live availability feedback (server checked the DB).
function Character.OnDesignationCheck( designation, free )
	if not IsValid( frame ) or designation ~= state.value then return end

	local C = SWRP.Theme.colors
	state.checked, state.free = true, free

	if free then
		frame._status:SetText( designation .. " is available" )
		frame._status:SetTextColor( C.success )
	else
		frame._status:SetText( designation .. " is taken — try another" )
		frame._status:SetTextColor( C.danger )
	end
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
