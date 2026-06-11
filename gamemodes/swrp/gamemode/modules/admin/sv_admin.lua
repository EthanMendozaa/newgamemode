--[[----------------------------------------------------------------------------
	Admin module (server) — staff record operations.

	Authority: superadmin, or the server console. This is the STAFF tree —
	deliberately bypasses Hierarchy.Can (RP authority), but never the single
	mutation path: everything goes through rec:Commit (write-through,
	record_version, Recompute, hooks) and is audited as admin_*.

	One ops table backs BOTH entry points — chat/console commands and the
	Staff menu tab's net messages — so the gates can never drift:

	  !setrank <player> <rank|tag|index>     e.g. !setrank Para CPT
	  !setbattalion <player> <battalion>     (lowest rank, respawns)
	  !setdesignation <player> <digits>
	  !setname <player> <new name...>
	  !record <player>                       print the raw record
	  !addspawn <battalion>                  (spawns module)
	  swrp_bots <n>                          spawn test bots (perf testing)

	Targets are online players. (Offline staff edits: Phase 5 record browser.)
------------------------------------------------------------------------------]]

local Admin     = SWRP.Admin
local Character = SWRP.Character
local Hierarchy = SWRP.Hierarchy
local Commands  = SWRP.Commands
local Audit     = SWRP.Audit
local Util      = SWRP.Util
local Config    = SWRP.Config
local DB        = SWRP.DB
local log       = SWRP.Logger( "Admin" )

local function isStaff( ply )
	return not IsValid( ply ) or ply:IsSuperAdmin()
end

--------------------------------------------------------------------------------
-- The ops table (shared by commands and the Staff tab)
--
-- Each op: fn( actor, target, rec, value, reply ) — `reply( ok, msg )` exactly
-- once. Commits are async; never reply before the write lands.
--------------------------------------------------------------------------------

Admin.Ops = {}

function Admin.Ops.rank( actor, target, rec, value, reply )
	local battalion = Hierarchy.GetBattalion( rec.battalion_id )
	local rank      = Hierarchy.FindRank( battalion, value )
	if not rank then
		reply( false, "Unknown rank — use a rank name, tag, or ladder index" )
		return
	end

	rec:Commit( { rank_id = rank.id }, function( err )
		if err then reply( false, "Database error" ) return end
		Audit.LogAction( actor, "admin_setrank", rec, { to = rank.id } )
		target:ChatPrint( "[SWRP] A staff member set your rank to " .. rank.name )
		reply( true, rec.rp_name_base .. " is now " .. rank.name )
	end )
end

function Admin.Ops.battalion( actor, target, rec, value, reply )
	local battalion = Hierarchy.FindBattalion( value )
	if not battalion then
		reply( false, "Unknown battalion — use its name, tag, or id" )
		return
	end

	rec:Commit( {
		battalion_id = battalion.id,
		rank_id      = Hierarchy.LowestRank( battalion ).id,
	}, function( err )
		if err then reply( false, "Database error" ) return end
		Audit.LogAction( actor, "admin_setbattalion", rec, { to = battalion.id } )
		target:ChatPrint( "[SWRP] A staff member moved you to the " .. battalion.name )
		reply( true, rec.rp_name_base .. " moved to " .. battalion.name )
	end, { respawn = true } )
end

function Admin.Ops.designation( actor, target, rec, value, reply )
	local digits = Config.Get( "designation_digits", 4 )
	if #value ~= digits or not string.match( value, "^%d+$" ) then
		reply( false, "Designation must be exactly " .. digits .. " digits" )
		return
	end

	rec:Commit( { designation = value }, function( err )
		if err then
			if string.find( err, "UNIQUE", 1, true ) or string.find( err, "Duplicate", 1, true ) then
				reply( false, "That designation is already taken" )
			else
				reply( false, "Database error" )
			end
			return
		end
		Audit.LogAction( actor, "admin_setdesignation", rec, { to = value } )
		target:ChatPrint( "[SWRP] A staff member set your designation to " .. value )
		reply( true, rec.rp_name_base .. " is now designation " .. value )
	end )
end

function Admin.Ops.name( actor, target, rec, value, reply )
	if string.Trim( value ) == "" then
		reply( false, "Give a name" )
		return
	end

	local old  = rec.rp_name_base
	local name = Character.SanitizeName( value )

	rec:Commit( { rp_name_base = name }, function( err )
		if err then reply( false, "Database error" ) return end
		Audit.LogAction( actor, "admin_setname", rec, { from = old, to = name } )
		target:ChatPrint( "[SWRP] A staff member renamed you to " .. name )
		reply( true, old .. " renamed to " .. name )
	end )
end

--------------------------------------------------------------------------------
-- Entry point 1: the Staff menu tab (net)
--------------------------------------------------------------------------------

function Admin.HandleEdit( ply, targetStr, field, value )
	if not isStaff( ply ) then return end

	local op = Admin.Ops[ field ]
	if not op then return end

	local target, err = Util.FindPlayer( targetStr )
	if not target then
		SWRP.UI.Notify( ply, false, err )
		return
	end

	local rec = Character.GetRecord( target )
	if not rec then
		SWRP.UI.Notify( ply, false, "Target has no loaded character yet" )
		return
	end

	op( ply, target, rec, value, function( ok, msg )
		SWRP.UI.Notify( ply, ok, msg )
	end )
end

function Admin.SendAudit( ply )
	if not isStaff( ply ) or not IsValid( ply ) then return end

	DB.Query( "SELECT * FROM swrp_audit ORDER BY at DESC LIMIT 30", function( rows )
		if not IsValid( ply ) then return end
		SWRP.Net.Send( "swrp.admin.audit", ply, { rows = rows or {} } )
	end )
end

--------------------------------------------------------------------------------
-- Entry point 2: chat/console commands
--------------------------------------------------------------------------------

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
	return table.concat( args, " ", math.min( from, #args + 1 ), #args )
end

local function opCommand( name, field, description )
	Commands.Register( name, {
		description = description,
		handler = function( ply, args )
			local target, rec = staffTarget( ply, args )
			if not target then return end
			Admin.Ops[ field ]( ply, target, rec, restOfArgs( args, 2 ), function( ok, msg )
				Commands.Reply( ply, msg )
			end )
		end,
	} )
end

opCommand( "setrank",        "rank",        "STAFF: set a player's rank within their battalion" )
opCommand( "setbattalion",   "battalion",   "STAFF: move a player to a battalion (lowest rank, respawns)" )
opCommand( "setdesignation", "designation", "STAFF: change a player's designation" )
opCommand( "setname",        "name",        "STAFF: change a player's RP name" )

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

--------------------------------------------------------------------------------
-- Perf testing: bot fill
--------------------------------------------------------------------------------

concommand.Add( "swrp_bots", function( ply, _, args )
	if not isStaff( ply ) then return end

	local n = math.Clamp( tonumber( args[ 1 ] ) or 1, 1, 64 )
	log.Info( "spawning %d bot(s) for stress testing", n )

	-- Spaced out: each bot triggers a full spawn + record + loadout pipeline.
	for i = 1, n do
		timer.Simple( i * 0.2, function()
			game.ConsoleCommand( "bot\n" )
		end )
	end
end )
