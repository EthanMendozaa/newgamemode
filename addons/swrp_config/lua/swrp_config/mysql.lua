--[[----------------------------------------------------------------------------
	SWRP config — database credentials + server identity

	Leave `host` blank to run on the built-in SQLite database (zero setup,
	perfect for local development). Fill it in to use a shared MySQL instance
	across servers (requires the mysqloo binary module on the server).

	If MySQL is configured but unreachable, the gamemode automatically falls
	back to SQLite so the server still boots.
------------------------------------------------------------------------------]]

SWRP.Config.Database( {
	host      = "",          -- "" => SQLite (local dev). Set to your MySQL host to enable MySQL.
	port      = 3306,
	username  = "",
	password  = "",
	database  = "",

	-- Stable identity of THIS server, used for cross-server record sync. Each
	-- server sharing the database must use a different value (e.g. "main", "event").
	server_id = "main",
} )
