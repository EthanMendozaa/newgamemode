# SWRP_UNNAMED

A from-scratch Garry's Mod gamemode for Star Wars RP, replacing DarkRP. Working
title — the internal `SWRP`/`swrp_` namespace is permanent; only the display
name changes when the final (probably clone-wars) brand is chosen.

**Status: Phases 0–3 built + code-reviewed. Phase 4 (server fit) next.**

| Phase | Scope | State |
|---|---|---|
| 0 | Skeleton, module loader, net wrapper, async DB (SQLite/mysqloo), config addon | done |
| 1 | Character record, hierarchy (battalions/ranks/`Hierarchy.Can`), derived naming, HUD/scoreboard | done |
| — | UI kit ("Republic" theme), F4 menu shell | done |
| 2 | Interaction framework (accept/deny), battalion management (incl. offline), audit log, commands | done |
| 3 | Classes/loadouts (templates + assignments), class menu, session slot limits | done |
| 4 | Chat/comms, admin suite UI, cross-server sync, perf pass, spawn points/armory | next |

## Layout

```
gamemodes/swrp/        the gamemode (never edit for server config)
addons/swrp_config/    ALL server configuration (darkrpmodification model)
```

## Install (test server)

1. Copy `gamemodes/swrp/` -> `garrysmod/gamemodes/`
2. Copy `addons/swrp_config/` -> `garrysmod/addons/`
3. Set gamemode `swrp` and start. Ships on SQLite (zero setup); fill in
   `addons/swrp_config/lua/swrp_config/mysql.lua` for shared MySQL (mysqloo).

## Quick test pass

- Join: designation picker appears; HUD shows `UNA PVT <digits> <name>`.
- `swrp_ui_demo` (console): UI kit showcase. F4: menu (Character/Battalion/Classes).
- Bootstrap an officer: `!setbattalion <you> 501st` then `!setrank <you> CPT`
  (superadmin/console).
- `!invite <player>` -> accept prompt -> respawns as 501st Rifleman.
- Promote to SPC/SGT -> Medic/Heavy unlock in F4 Classes (slot-capped).
- `!kick` -> back to Unassigned. `swrp_audit` -> every action logged.
- `!help` lists all commands. `swrp_reload_config` hot-reloads config.

## Architecture invariants (see CLAUDE.md / plan)

Single source of truth per player (everything derived via `Recompute`); no void
states; all authority server-side (`Hierarchy.Can` + validated/rate-limited net
wrapper); identity changes apply via respawn; all DB access async with
write-through mutations; config lives only in the addon; all UI visuals come
from one theme table.
