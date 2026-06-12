--[[----------------------------------------------------------------------------
	News posts + quick links (SHARED — clients render these).

	Put the NEWEST post at the TOP. Quick links appear on the Settings tab.
------------------------------------------------------------------------------]]

if not SWRP.addNews then return end   -- news module disabled

SWRP.addNews( {
	title = "Welcome to the server",
	date  = "12 JUN 2026",
	body  = "The Grand Army terminal is live. Pick your designation, join a "
		.. "battalion, and report to your commanding officer. Edit this post in "
		.. "swrp_customthings/news.lua.",
} )

SWRP.addQuickLink( { label = "Discord",  url = "https://discord.gg/yourserver",                       color = Color( 88, 101, 242 ) } )
SWRP.addQuickLink( { label = "Workshop", url = "https://steamcommunity.com/workshop/",                color = Color( 60, 110, 160 ) } )
SWRP.addQuickLink( { label = "Rules",    url = "https://yourserver.com/rules",                        color = Color( 178, 64, 56 ) } )
