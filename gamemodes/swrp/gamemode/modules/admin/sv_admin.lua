--[[----------------------------------------------------------------------------
	Admin module (server) — staff record-editing commands.

	Authority: superadmin, or the server console. This is the STAFF tree —
	deliberately bypasses Hierarchy.Can (RP authority), but never bypasses the
	single mutation path: everything goes through rec:Commit (write-through,
	record_version, Recompute, hooks) and is audited as admin_*.

	  !setrank <player> <rank|tag|index>     e.g. !setrank Para CPT
	  !setbattalion <player> <battalion>     e.g. !setbattalion Para 501st
	  !setdesignation <player> <digits>      e.g. !setdesignation Para 4456
	  !setname <player> <new name...>
	  !record <player>                       print the raw record

	Targets are online players. (Offline staff edits come with the Phase 4
	record editor UI.)
------------------------------------------------------------------------------]]

local Character = SWRP.Character
local Hierarchy = SWRP.Hierarchy
local Commands  = SWRP.Commands
local Audit     = SWRP.Audit
local Util      = SWRP.Util
local Config    = SWRP.Config

local function isStaff( ply )
	return not IsValid( ply ) or ply:IsSuperAdmin()
end

-- Shared preamble: staff check + resolve online target + record.
local function staffTarget( ply, args )
	if not isStaff( ply ) then
		Commands.Reply( ply, "Staff only" )
		return nil
	end

	local target, err = Util.FindPlayer( args[ 1 ] or "" )
	if not target then
		Commands.Reply( ply, err )
		return nil
	end

	local rec = Character.GetRecord( target )
	if not rec then
		Commands.Reply( ply, target:Nick() .. " has no loaded character yet" )
		return nil
	end
	return target, rec
end

local function restOfArgs( args, from )
	return table.concat( args, " ", from, #args )
end

--------------------------------------------------------------------------------

Commands.Register( "setrank", {
	description = "STAFF: set a player's rank within their battalion",
	handler = function( ply, args )
		local target, rec = staffTarget( ply, args )
		if not target then return end

		local battalion = Hierarchy.GetBattalion( rec.battalion_id )
		local rank      = Hierarchy.FindRank( battalion, restOfArgs( args, 2 ) )
		if not rank then
			Commands.Reply( ply, "Unknown rank — use a rank name, tag, or ladder index" )
			return
		end

		rec:Commit( { rank_id = rank.id }, function( err )
			if err then Commands.Reply( ply, "Database error" ) return end
			Audit.LogAction( ply, "admin_setrank", rec, { to = rank.id } )
			Commands.Reply( ply, rec.rp_name_base .. " is now " .. rank.name )
			target:ChatPrint( "[SWRP] A staff member set your rank to " .. rank.name )
		end )
	end,
} )

Commands.Register( "setbattalion", {
	description = "STAFF: move a player to a battalion (lowest rank, respawns)",
	handler = function( ply, args )
		local target, rec = staffTarget( ply, args )
		if not target then return end

		local battalion = Hierarchy.FindBattalion( restOfArgs( args, 2 ) )
		if not battalion then
			Commands.Reply( ply, "Unknown battalion — use its name, tag, or id" )
			return
		end

		rec:Commit( {
			battalion_id = battalion.id,
			rank_id      = Hierarchy.LowestRank( battalion ).id,
		}, function( err )
			if err then Commands.Reply( ply, "Database error" ) return end
			Audit.LogAction( ply, "admin_setbattalion", rec, { to = battalion.id } )
			Commands.Reply( ply, rec.rp_name_base .. " moved to " .. battalion.name )
			target:ChatPrint( "[SWRP] A staff member moved you to the " .. battalion.name )
		end, { respawn = true } )
	end,
} )

Commands.Register( "setdesignation", {
	description = "STAFF: change a player's designation",
	handler = function( ply, args )
		local target, rec = staffTarget( ply, args )
		if not target then return end

		local designation = args[ 2 ] or ""
		local digits      = Config.Get( "designation_digits", 4 )
		if #designation ~= digits or not string.match( designation, "^%d+$" ) then
			Commands.Reply( ply, "Designation must be exactly " .. digits .. " digits" )
			return
		end

		rec:Commit( { designation = designation }, function( err )
			if err then
				if string.find( err, "UNIQUE", 1, true ) or string.find( err, "Duplicate", 1, true ) then
					Commands.Reply( ply, "That designation is already taken" )
				else
					Commands.Reply( ply, "Database error" )
				end
				return
			end
			Audit.LogAction( ply, "admin_setdesignation", rec, { to = designation } )
			Commands.Reply( ply, rec.rp_name_base .. " is now designation " .. designation )
			target:ChatPrint( "[SWRP] A staff member set your designation to " .. designation )
		end )
	end,
} )

Commands.Register( "setname", {
	description = "STAFF: change a player's RP name",
	handler = function( ply, args )
		local target, rec = staffTarget( ply, args )
		if not target then return end

		local raw  = restOfArgs( args, 2 )
		local name = Character.SanitizeName( raw )
		if string.Trim( raw ) == "" then
			Commands.Reply( ply, "Give a name: !setname <player> <new name>" )
			return
		end

		local old = rec.rp_name_base
		rec:Commit( { rp_name_base = name }, function( err )
			if err then Commands.Reply( ply, "Database error" ) return end
			Audit.LogAction( ply, "admin_setname", rec, { from = old, to = name } )
			Commands.Reply( ply, old .. " renamed to " .. name )
			target:ChatPrint( "[SWRP] A staff member renamed you to " .. name )
		end )
	end,
} )

Commands.Register( "record", {
	description = "STAFF: print a player's character record",
	handler = function( ply, args )
		local target, rec = staffTarget( ply, args )
		if not target then return end

		Commands.Reply( ply, string.format(
			"%s | battalion=%s rank=%s desig=%s class=%s playtime=%ds v%d",
			rec.id, rec.battalion_id, rec.rank_id, rec.designation or "—",
			rec.class_id ~= "" and rec.class_id or "—",
			rec.playtime or 0, rec.record_version or 1 ) )
	end,
} )
