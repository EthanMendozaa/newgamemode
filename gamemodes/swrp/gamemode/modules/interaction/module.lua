--[[----------------------------------------------------------------------------
	Interaction — the generalized request -> accept/deny framework (plan §3.5).

	Every player-to-player flow reuses this one pattern: actor initiates, target
	gets a queueable prompt, the server validates at SEND time and AGAIN at
	ACCEPT time (state may have changed), then applies atomically. Battalion
	invites, training sign-offs, lore slot offers, duels — all of it.
------------------------------------------------------------------------------]]

MODULE.Name    = "Interaction"
MODULE.Version = "1.0.0"
MODULE.Depends = { "ui" }
