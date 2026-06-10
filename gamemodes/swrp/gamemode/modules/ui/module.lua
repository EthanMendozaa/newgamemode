--[[----------------------------------------------------------------------------
	UI — the component kit (build inventory #10).

	Owns SWRP.Theme (the ONE place visuals come from, invariant 7) and the
	Derma component kit every SWRP interface is built from: window shell,
	buttons, tabs, roster table, cards, accept/deny popup queue, toasts,
	confirm dialogs, progress bars, and the main menu shell (modules register
	tabs via SWRP.UI.RegisterMenuTab).

	Visual direction (locked by Rene from rendered mockups): "Republic" —
	clean-modern layout discipline crossed with imperial structure, in a
	clone-wars palette (Republic blue / armor white / holo gold on dark slate).
------------------------------------------------------------------------------]]

MODULE.Name    = "UI"
MODULE.Version = "1.0.0"
MODULE.Depends = {}
