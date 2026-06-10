--[[----------------------------------------------------------------------------
	UI module (client) — popups: accept/deny prompts, toasts, confirm dialogs.

	Prompts are QUEUEABLE and non-intrusive (plan §3.5): one shows at a time,
	bottom-right, with a countdown bar; the next in queue appears when it
	resolves. The Phase 2 interaction framework drives these over the net —
	this file is just the client primitive.

	  SWRP.UI.Prompt{ id, title, text, expires, onAccept, onDeny, onExpire }
	  SWRP.UI.DismissPrompt( id )   -- e.g. server revoked the request
	  SWRP.UI.Toast( text, kind )   -- kind: "info" | "success" | "danger"
	  SWRP.UI.Confirm( title, text, onYes, onNo )
------------------------------------------------------------------------------]]

SWRP.UI = SWRP.UI or {}
local UI = SWRP.UI

local function T() return SWRP.Theme end

--------------------------------------------------------------------------------
-- Accept/deny prompt queue
--------------------------------------------------------------------------------

local queue   = {}
local current = nil

local function showNext()
	if IsValid( current and current.panel ) then return end
	current = table.remove( queue, 1 )
	if not current then return end

	local theme = T()
	local K, S  = theme.kit, theme.spacing
	local data  = current

	local w, h = K.popupW, 118
	local p = vgui.Create( "DPanel" )
	p:SetSize( w, h )
	p:SetPos( ScrW() - w - S.margin, ScrH() - h - S.margin - 110 )
	current.panel = p

	local deadline = data.expires and ( RealTime() + data.expires ) or nil

	p.Paint = function( self, pw, ph )
		local C = T().colors
		draw.RoundedBox( K.radius, 0, 0, pw, ph, C.bg )
		surface.SetDrawColor( C.gold )
		surface.DrawRect( 0, 0, K.accentW, ph )
		draw.SimpleText( string.upper( data.title or "Request" ), "SWRP.Title",
			K.accentW + 10, 10, C.text )
		draw.SimpleText( data.text or "", "SWRP.Small",
			K.accentW + 10, 34, C.textDim )
	end

	local function resolve( fn )
		if IsValid( p ) then p:Remove() end
		current = nil
		if fn then fn() end
		timer.Simple( 0.1, showNext )
	end

	local bar
	if deadline then
		bar = UI.Bar( p )
		bar:SetColor( theme.colors.gold )
		bar:SetSize( w - K.accentW - 20, 5 )
		bar:SetPos( K.accentW + 10, 56 )

		p.Think = function()
			local left = deadline - RealTime()
			if left <= 0 then
				resolve( data.onExpire )
				return
			end
			bar:SetFraction( left / data.expires )
		end
	end

	local accept = UI.Button( p, "Accept", "primary", function() resolve( data.onAccept ) end )
	accept:SetSize( ( w - K.accentW - 28 ) / 2, 28 )
	accept:SetPos( K.accentW + 10, h - 38 )

	local deny = UI.Button( p, "Deny", "ghost", function() resolve( data.onDeny ) end )
	deny:SetSize( ( w - K.accentW - 28 ) / 2, 28 )
	deny:SetPos( K.accentW + 10 + ( w - K.accentW - 28 ) / 2 + 8, h - 38 )

	surface.PlaySound( "buttons/button14.wav" )
end

function UI.Prompt( data )
	queue[ #queue + 1 ] = data
	showNext()
	return data.id
end

-- Remove a pending/visible prompt (e.g. the server revoked the request).
function UI.DismissPrompt( id )
	if current and current.id == id then
		if IsValid( current.panel ) then current.panel:Remove() end
		current = nil
		timer.Simple( 0.1, showNext )
		return
	end
	for i, data in ipairs( queue ) do
		if data.id == id then table.remove( queue, i ) return end
	end
end

--------------------------------------------------------------------------------
-- Toasts
--------------------------------------------------------------------------------

local toasts = {}

local function layoutToasts()
	local theme = T()
	local y = theme.spacing.margin
	for _, t in ipairs( toasts ) do
		if IsValid( t ) then
			t:MoveTo( ScrW() - t:GetWide() - theme.spacing.margin, y, 0.15 )
			y = y + t:GetTall() + 6
		end
	end
end

function UI.Toast( text, kind )
	local theme = T()
	local K = theme.kit

	local accent = theme.colors.accent
	if kind == "success" then accent = theme.colors.success end
	if kind == "danger"  then accent = theme.colors.danger end

	local t = vgui.Create( "DPanel" )
	t:SetSize( K.toastW, 40 )
	t:SetPos( ScrW(), theme.spacing.margin )

	t.Paint = function( self, w, h )
		local C = T().colors
		draw.RoundedBox( K.radius, 0, 0, w, h, C.bg )
		surface.SetDrawColor( accent )
		surface.DrawRect( 0, 0, K.accentW, h )
		draw.SimpleText( text, "SWRP.Sub", K.accentW + 10, h / 2, C.text,
			TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	end

	toasts[ #toasts + 1 ] = t
	layoutToasts()

	timer.Simple( 4, function()
		if not IsValid( t ) then return end
		t:AlphaTo( 0, 0.3, 0, function()
			for i, v in ipairs( toasts ) do
				if v == t then table.remove( toasts, i ) break end
			end
			if IsValid( t ) then t:Remove() end
			layoutToasts()
		end )
	end )

	return t
end

--------------------------------------------------------------------------------
-- Confirm dialog ("Switch to Heavy? You will respawn.")
--------------------------------------------------------------------------------

function UI.Confirm( title, text, onYes, onNo )
	local theme = T()
	local K = theme.kit

	local f = UI.Frame( 360, 140, title )
	f:SetDraggable( false )

	local label = vgui.Create( "DLabel", f.Body )
	label:SetText( text or "" )
	label:SetFont( "SWRP.Sub" )
	label:SetTextColor( theme.colors.text )
	label:SetWrap( true )
	label:Dock( TOP )
	label:SetTall( 40 )

	local row = vgui.Create( "DPanel", f.Body )
	row:Dock( BOTTOM )
	row:SetTall( K.btnH )
	row.Paint = nil

	local yes = UI.Button( row, "Confirm", "primary", function()
		f:Close()
		if onYes then onYes() end
	end )
	yes:Dock( LEFT )
	yes:SetWide( 160 )

	local no = UI.Button( row, "Cancel", "ghost", function()
		f:Close()
		if onNo then onNo() end
	end )
	no:Dock( RIGHT )
	no:SetWide( 160 )

	return f
end
