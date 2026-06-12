--[[----------------------------------------------------------------------------
	SWRP — client resource downloads (server only)

	Ships the gamemode's content to connecting clients. Fonts: Barlow
	Condensed (SIL Open Font License — see content/resource/fonts/OFL.txt),
	the display face of the approved Republic Terminal design.
------------------------------------------------------------------------------]]

if not SERVER then return end

resource.AddFile( "resource/fonts/BarlowCondensed-Regular.ttf" )
resource.AddFile( "resource/fonts/BarlowCondensed-Medium.ttf" )
resource.AddFile( "resource/fonts/BarlowCondensed-SemiBold.ttf" )
