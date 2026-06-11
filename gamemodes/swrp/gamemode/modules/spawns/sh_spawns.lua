--[[----------------------------------------------------------------------------
	Spawns module (shared) — config API + registry.

	  SWRP.addBattalionSpawn( "rp_venator_v2", BATTALION_501ST,
	      Vector( 100, 200, 64 ), Angle( 0, 90, 0 ) )

	Map-keyed so one config addon serves every map; entries for other maps are
	registered but inert. Validated FPtje-style: a bad entry warns and skips,
	never crashes (invariant 6).
------------------------------------------------------------------------------]]

SWRP.Spawns = SWRP.Spawns or {}
local Spawns = SWRP.Spawns
local Config = SWRP.Config
local log    = SWRP.Logger( "Spawns" )

Spawns.Points = Spawns.Points or {}   -- [map][battalion id] = { { pos, ang }, ... }

function SWRP.addBattalionSpawn( map, battalion, pos, ang )
	local src = Config.Where( 1 )

	if not isstring( map ) or map == "" then
		log.Warn( "%s: addBattalionSpawn needs a map name string — skipped", src or "?" )
		return
	end
	if not istable( battalion ) or not battalion.id then
		log.Warn( "%s: addBattalionSpawn: second argument is not a battalion (disabled or typo?) — skipped", src or "?" )
		return
	end
	if not isvector( pos ) then
		log.Warn( "%s: addBattalionSpawn: position must be a Vector — skipped", src or "?" )
		return
	end

	map = string.lower( map )
	Spawns.Points[ map ] = Spawns.Points[ map ] or {}
	Spawns.Points[ map ][ battalion.id ] = Spawns.Points[ map ][ battalion.id ] or {}

	table.insert( Spawns.Points[ map ][ battalion.id ], {
		pos = pos,
		ang = isangle( ang ) and ang or Angle( 0, 0, 0 ),
	} )
end

-- Random spawn for a battalion on the current map, or nil (map defaults).
function Spawns.GetFor( battalionId )
	local forMap = Spawns.Points[ string.lower( game.GetMap() ) ]
	local list   = forMap and forMap[ battalionId ]
	if not list or #list == 0 then return nil end
	return list[ math.random( #list ) ]
end
