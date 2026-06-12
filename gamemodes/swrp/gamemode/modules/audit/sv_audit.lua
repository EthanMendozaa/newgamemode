--[[----------------------------------------------------------------------------
	Audit module (server) — append-only mutation log.

	SWRP.Audit.Log{
	    actor_id = "...", actor_name = "...",   -- nil for system actions
	    action   = "battalion_promote",          -- short machine-readable verb
	    target_id = "...", target_name = "...",  -- optional
	    detail   = { from = "...", to = "..." }, -- stored as JSON
	}

	Helper: SWRP.Audit.LogAction( actorPly, action, targetRec, detailTable )
------------------------------------------------------------------------------]]

SWRP.Audit = SWRP.Audit or {}
local Audit = SWRP.Audit
local log   = SWRP.Logger( "Audit" )

SWRP.DB.RegisterMigration( "audit", 1, [[
	CREATE TABLE IF NOT EXISTS swrp_audit (
		at          INTEGER     NOT NULL,
		server_id   VARCHAR(32) NOT NULL,
		actor_id    VARCHAR(32),
		actor_name  VARCHAR(64),
		action      VARCHAR(32) NOT NULL,
		target_id   VARCHAR(32),
		target_name VARCHAR(64),
		detail      TEXT
	)
]] )

function Audit.Log( e )
	if not istable( e ) or not isstring( e.action ) then
		log.Error( "Audit.Log needs at least { action = ... }" )
		return
	end

	SWRP.DB.Query( [[
		INSERT INTO swrp_audit
			( at, server_id, actor_id, actor_name, action, target_id, target_name, detail )
		VALUES ( ?, ?, ?, ?, ?, ?, ?, ? )
	]], {
		os.time(),
		SWRP.Config.Get( "server_id", "main" ),
		e.actor_id or "system",
		e.actor_name or "system",
		e.action,
		e.target_id or "",
		e.target_name or "",
		util.TableToJSON( e.detail or {} ),
	} )
end

-- Convenience for the common "player did X to a character record" case.
function Audit.LogAction( actorPly, action, targetRec, detail )
	local arec = IsValid( actorPly ) and SWRP.Character.GetRecord( actorPly ) or nil
	Audit.Log( {
		actor_id    = arec and arec.id or nil,
		actor_name  = arec and arec.rp_name_base or nil,
		action      = action,
		target_id   = targetRec and targetRec.id or nil,
		target_name = targetRec and targetRec.rp_name_base or nil,
		detail      = detail,
	} )
end

-- Quick console inspection until the Phase 4 admin UI exists.
concommand.Add( "swrp_audit", function( ply )
	if not SWRP.Util.IsStaff( ply ) then return end

	SWRP.DB.Query(
		"SELECT * FROM swrp_audit ORDER BY at DESC LIMIT 20",
		function( rows )
			if not rows or #rows == 0 then log.Info( "audit log is empty" ) return end
			for i = #rows, 1, -1 do
				local r = rows[ i ]
				log.Info( "%s | %s -> %s | %s -> %s | %s",
					os.date( "%Y-%m-%d %H:%M:%S", tonumber( r.at ) or 0 ),
					r.actor_name or "?", r.action or "?",
					r.target_name ~= "" and r.target_name or "—",
					r.detail or "{}", r.server_id or "?" )
			end
		end )
end )
