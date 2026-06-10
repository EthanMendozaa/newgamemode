--[[----------------------------------------------------------------------------
	UI module (client) — the "Republic" theme.

	EVERY color, font, and spacing in SWRP UI comes from this table
	(invariant 7). No drawing code hardcodes visuals; reskinning the gamemode
	is editing/swapping this one file.

	Direction (locked via rendered mockups): clean-modern readability +
	imperial structure, clone-wars palette — dark slate surfaces, Republic
	blue primary, armor-white text, holo-gold secondary accent, crisp corners,
	uppercase headers with accent bars.
------------------------------------------------------------------------------]]

SWRP.Theme = {
	colors = {
		-- Surfaces (blue-slate ramp — raised = lighter)
		bg        = Color( 16, 24, 43, 250 ),    -- window background
		bgLight   = Color( 24, 34, 56, 250 ),    -- cards / rows
		bgRaised  = Color( 34, 46, 74, 250 ),    -- hover / raised elements
		titleBar  = Color( 19, 28, 51, 255 ),
		divider   = Color( 43, 58, 94, 200 ),

		-- Text (clone armor white; dim holds 4.5:1+ on bgLight)
		text      = Color( 238, 242, 247 ),
		textDim   = Color( 148, 160, 184 ),

		-- Accents
		accent    = Color( 65, 105, 225 ),       -- Republic blue (primary)
		accentHi  = Color( 96, 136, 245 ),       -- hover state of primary
		gold      = Color( 224, 164, 70 ),       -- holo gold (secondary)
		white     = Color( 244, 246, 248 ),      -- armor white highlights

		-- Semantics
		danger    = Color( 210, 74, 62 ),
		dangerHi  = Color( 235, 100, 88 ),
		success   = Color( 63, 174, 98 ),

		-- Vitals + misc
		health    = Color( 95, 200, 120 ),
		healthLow = Color( 230, 90, 80 ),
		armor     = Color( 90, 150, 235 ),
		barBack   = Color( 0, 0, 0, 160 ),
		outline   = Color( 0, 0, 0, 200 ),
	},

	spacing = {
		pad    = 12,    -- inner padding
		margin = 24,    -- HUD distance from screen edges
		barH   = 14,    -- stat bar height
		rowH   = 34,    -- table/list row height
	},

	kit = {
		radius   = 6,     -- crisp military corners
		titleH   = 44,    -- window title bar height
		btnH     = 34,    -- button height
		tabH     = 36,    -- tab bar height
		accentW  = 3,     -- left accent bar width on cards/rows
		popupW   = 310,   -- accept/deny popup width
		toastW   = 290,
		blur     = 4,     -- background blur behind windows (0 = off)
		hoverSpd = 10,    -- hover transition speed (lerp factor per second x10)
	},

	overhead = {
		distance = 600,   -- max draw distance (units)
		height   = 12,    -- offset above eye position
	},
}

--------------------------------------------------------------------------------
-- Fonts (the only place fonts are created)
--------------------------------------------------------------------------------

surface.CreateFont( "SWRP.Title", {
	font = "Roboto", size = 20, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.Name", {
	font = "Roboto", size = 24, weight = 700, antialias = true,
} )

surface.CreateFont( "SWRP.Sub", {
	font = "Roboto", size = 17, weight = 500, antialias = true,
} )

surface.CreateFont( "SWRP.Small", {
	font = "Roboto", size = 15, weight = 500, antialias = true,
} )

surface.CreateFont( "SWRP.Button", {
	font = "Roboto", size = 16, weight = 600, antialias = true,
} )

surface.CreateFont( "SWRP.Overhead", {
	font = "Roboto", size = 18, weight = 700, antialias = true,
} )
