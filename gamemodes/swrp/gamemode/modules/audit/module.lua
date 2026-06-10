--[[----------------------------------------------------------------------------
	Audit — every hierarchy mutation, on the record (plan: "everything audited").

	Server-only DB log of who did what to whom. Phase 4's admin suite gets a
	UI over this table; until then `swrp_audit` prints recent entries.
------------------------------------------------------------------------------]]

MODULE.Name    = "Audit"
MODULE.Version = "1.0.0"
MODULE.Depends = { "character" }   -- LogAction resolves actor/target records
