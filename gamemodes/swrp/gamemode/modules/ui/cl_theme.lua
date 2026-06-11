--[[----------------------------------------------------------------------------
	UI module (client) — the "Republic Terminal" theme (v4, approved via
	research-driven mockups).

	EVERY color, font, and spacing in SWRP UI comes from this table
	(invariant 7). No drawing code hardcodes visuals; reskinning the gamemode
	is editing/swapping this one file.

	Direction: full-screen translucent terminal (the non-DarkRP SWRP genre
	standard), caps top-nav, hairline-divider rows instead of boxes, generous
	negative space, ONE accent (Republic blue) + gold strictly for
	decision/special states.
------------------------------------------------------------------------------]]

SWRP.Theme = {
	colors = {
		-- Terminal layers (translucent — the world stays visible behind)
		termTop   = Color( 20, 29, 51, 247 ),    -- gradient top
		termBot   = Color( 11, 16, 30, 251 ),    -- gradient bottom
		bg        = Color( 16, 24, 43, 250 ),    -- dialog window background
		bgLight   = Color( 24, 34, 56, 250 ),    -- cards / rows
		bgRaised  = Color( 34, 46, 74, 250 ),    -- hover / raised elements
		titleBar  = Color( 19, 28, 51, 255 ),
		hairline  = Color( 28, 40, 69, 255 ),    -- divider rows (the v4 look)
		divider   = Color( 43, 58, 94, 200 ),    -- borders/outlines
		modelBg   = Color( 31, 43, 72, 120 ),    -- model panel backdrop

		-- Text
		text      = Color( 238, 242, 247 ),
		textBlue  = Color( 198, 210, 245 ),      -- roster names
		textDim   = Color( 148, 160, 184 ),
		label     = Color( 107, 120, 148 ),      -- uppercase micro-labels

		-- Accents
		accent    = Color( 65, 105, 225 ),       -- Republic blue (primary)
		accentHi  = Color( 96, 136, 245 ),
		accentSub = Color( 141, 166, 240 ),      -- identity sublines
		gold      = Color( 224, 164, 70 ),       -- decision / lore / current
		white     = Color( 244, 246, 248 ),

		-- Semantics
		danger    = Color( 210, 74, 62 ),
		dangerHi  = Color( 235, 100, 88 ),
		dangerTx  = Color( 224, 138, 128 ),
		success   = Color( 63, 174, 98 ),

		-- Vitals + misc
		health    = Color( 95, 200, 120 ),
		healthLow = Color( 230, 90, 80 ),
		armor     = Color( 90, 150, 235 ),
		barBack   = Color( 0, 0, 0, 160 ),
		outline   = Color( 0, 0, 0, 200 ),
	},

	spacing = {
		pad    = 12,    -- dialog inner padding
		termX  = 34,    -- terminal horizontal padding
		termY  = 22,    -- terminal vertical rhythm
		margin = 24,    -- HUD distance from screen edges
		barH   = 14,    -- stat bar height
		rowH   = 34,    -- compact table rows (staff tab)
		listH  = 52,    -- airy roster rows
		factH  = 46,    -- fact rows (character tab)
	},

	kit = {
		radius   = 6,
		titleH   = 44,    -- dialog title bar
		btnH     = 36,
		navH     = 64,    -- terminal nav strip height
		accentW  = 3,
		popupW   = 310,
		toastW   = 290,
		blur     = 4,
		hoverSpd = 10,
		avatar   = 34,    -- roster avatar size
	},

	overhead = {
		distance = 600,
		height   = 12,
	},
}

--------------------------------------------------------------------------------
-- Fonts (the only place fonts are created)
--------------------------------------------------------------------------------

surface.CreateFont( "SWRP.Display", {   -- identity statements (CT-4456 "PARA")
	font = "Roboto", size = 36, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.H2", {        -- section titles (501ST LEGION)
	font = "Roboto", size = 24, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.Nav", {       -- terminal nav tabs
	font = "Roboto", size = 18, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.Title", {     -- dialog titles
	font = "Roboto", size = 20, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.Name", {      -- HUD plate name, card titles
	font = "Roboto", size = 22, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.Fact", {      -- fact-row values
	font = "Roboto", size = 18, weight = 500, antialias = true,
} )

surface.CreateFont( "SWRP.Sub", {       -- body
	font = "Roboto", size = 17, weight = 500, antialias = true,
} )

surface.CreateFont( "SWRP.Small", {     -- secondary
	font = "Roboto", size = 15, weight = 500, antialias = true,
} )

surface.CreateFont( "SWRP.Label", {     -- uppercase micro-labels
	font = "Roboto", size = 13, weight = 600, antialias = true,
} )

surface.CreateFont( "SWRP.Button", {
	font = "Roboto", size = 16, weight = 600, antialias = true,
} )

surface.CreateFont( "SWRP.Overhead", {
	font = "Roboto", size = 18, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.OverheadSub", {
	font = "Roboto", size = 14, weight = 500, antialias = true,
} )

surface.CreateFont( "SWRP.Ammo", {      -- HUD ammo count
	font = "Roboto", size = 30, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.Digit", {     -- designation picker digit boxes
	font = "Roboto", size = 34, weight = 700, antialias = true,
} )
