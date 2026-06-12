--[[----------------------------------------------------------------------------
	News module (client) — feed renderer (used by the Loadout tab's right zone;
	that zone becomes the inventory grid in Phase B and news relocates then).
------------------------------------------------------------------------------]]

local News = SWRP.News
local UI   = SWRP.UI

-- Builds the scrolling post feed into `parent` (a panel; dock-padded by caller).
function News.BuildFeed( parent )
	local theme = SWRP.Theme
	local C, K  = theme.colors, theme.kit

	local scroll = vgui.Create( "DScrollPanel", parent )
	scroll:Dock( FILL )
	UI.Scrollbar( scroll )

	local posts = News.OrderedPosts()

	if #posts == 0 then
		local lbl = vgui.Create( "DLabel", scroll )
		lbl:SetFont( "SWRP.Sub" )
		lbl:SetTextColor( C.textDim )
		lbl:SetText( "No news posted. Add posts in swrp_customthings/news.lua." )
		lbl:Dock( TOP )
		lbl:SizeToContents()
		return scroll
	end

	for i, post in ipairs( posts ) do
		local cell = vgui.Create( "DPanel" )
		cell:Dock( TOP )
		cell:DockMargin( 0, 0, 0, 10 )
		cell:DockPadding( 14, 46, 14, 12 )
		cell:SetTall( 70 )

		cell.Paint = function( self, w, h )
			UI.Rect( K.radius, 0, 0, w, h, C.cell )
			surface.SetDrawColor( C.cellBorder )
			surface.DrawOutlinedRect( 0, 0, w, h, 1 )
			draw.SimpleText( string.upper( post.title ), "SWRP.Name", 14, 10, C.text )
			draw.SimpleText( string.upper( post.date or "" ), "SWRP.Label",
				w - 14, 18, C.label, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
		end

		local body = vgui.Create( "DLabel", cell )
		body:SetFont( "SWRP.Sub" )
		body:SetTextColor( C.textDim )
		body:SetText( post.body or "" )
		body:SetWrap( true )
		body:SetAutoStretchVertical( true )
		body:Dock( TOP )
		-- Wrapped height lands after layout; grow the cell to fit.
		body.OnSizeChanged = function( _, _, bh )
			cell:SetTall( 46 + bh + 14 )
		end

		scroll:AddItem( cell )
		UI.FadeIn( cell, UI.Stagger( i ) )
	end

	return scroll
end
