# swrp_config

Server configuration for the **SWRP** gamemode — a standalone addon,
exactly like FPtje's `darkrpmodification`. **You never edit the gamemode
itself**, so gamemode updates never overwrite your config.

## Install

Drop this folder into your server's `garrysmod/addons/` (alongside the
`swrp` gamemode in `garrysmod/gamemodes/`). GMod mounts `addons/*/lua/`
automatically, and the gamemode loads config from here at startup.

## Layout

```
lua/
├── swrp_config/          system config (loaded early)
│   ├── disabled_defaults.lua  turn off shipped defaults before replacing them
│   ├── settings.lua           key = value gamemode tuning
│   └── mysql.lua              database credentials + this server's identity
└── swrp_customthings/    content definitions (loaded after modules)
    ├── ranks.lua              rank ladders + permissions
    ├── battalions.lua         battalion definitions
    ├── classes.lua            class templates (skillsets)
    └── assignments.lua        attach classes to battalions + overrides
```

## Database

Ships configured for **SQLite** (blank `host` in `mysql.lua`) — zero setup,
runs locally immediately. Fill in MySQL credentials to share state across
servers (needs the `mysqloo` binary module). If MySQL is configured but
unreachable, the gamemode falls back to SQLite so the server still boots.

## Validation

Every value is validated at load. A typo, wrong type, or out-of-range value is
reported to console with the **file and line**, a **suggestion** for likely
typos, and a **sane default** is used instead — a bad config entry is skipped
with a warning, never a crash.

Run `swrp_reload_config` (superadmin) to reload without restarting.

## Status

`settings.lua` and `mysql.lua` are live. The `customthings/` files are
commented templates showing the API that ships in Phase 1 (battalions/ranks)
and Phase 3 (classes/assignments) — uncomment them as those systems land.
