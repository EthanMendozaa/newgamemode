# UI v6 — "AotR Replication" design & systems roadmap

**Date:** 2026-06-12
**Status:** Awaiting Rene's approval
**North star:** the "Age of the Republic" GMod UI (ArtStation kD3xyn) — Rene
supplied 10 full-res screenshots (Loadout, Profile/Vitals, Profile/Fireteam,
Shop, Trading ×2, Versus ×2, Season, Settings). Goal upgraded from
look-and-feel to **feature replication**, "a tad more modern", phased.

## 1. Scope decision

Everything in the reference is on the roadmap **except survival vitals**
(hunger/thirst and per-limb broken/bleeding are cut — HP/armor vitals stay).
Skill tracks survive the cut but are **config-defined** (the reference's
botany/cooking only make sense with survival; ours will be defined in
`swrp_customthings/skills.lua` when that phase lands).

This spec covers two things:

1. **Phase A (this spec's implementation plan): the v6 skin** — every
   existing screen rebuilt in the reference's exact visual language, plus the
   small new systems that need no backend redesign (news feed, settings
   persistence, quick links).
2. **Phases B–I: the systems roadmap** — dependency-ordered. Each later
   phase is its own brainstorm → spec → plan cycle; here they get scope
   definitions only, so Phase A leaves the right seams.

## 2. Design language (theme v6)

Derived from the screenshots, adapted per the standing decisions (navy/blue/
gold Republic palette, Barlow Condensed, motion layer, "tad more modern").

- **Surfaces:** near-black charcoal-navy panels (more opaque than v4's
  wash); content cells are **thin 1px-stroke boxes** on slightly lighter
  fill; corner radius 2px everywhere (sharp, tactical).
- **Accent system:** blue = active tab/interactive (sliding underline
  stays), **green = identity & live presence** (identity line, equipped
  highlight, "Viewing X" presence, On toggles), gold = special (lore,
  commander, current class, designation), red = danger, magenta reserved for
  the premium currency if we ever add one.
- **Rarity ramp** (item frames, value chips, season tiers): grey → blue →
  gold → red → magenta → purple. Defined once in the theme as
  `colors.rarity[tier]`.
- **Type:** Barlow Condensed (existing fonts). Section headers are spaced
  caps with the small label font; values use the condensed semibold.
- **Motion:** existing kit (FadeIn/PopIn/Stagger/HoverFrac/underline). New:
  equipped-cell pulse on equip, ring fill animation on open.

## 3. Shell (every tab)

- Full-screen terminal as today; tab strip becomes the reference's caps
  row: `LOADOUT · BATTALION · CLASSES · STAFF · SETTINGS` at Phase A, with
  `SHOP · TRADING · VERSUS · DAILIES · SEASON` appearing only as their
  systems land (no dead tabs).
- **Identity line** under the strip on every tab: green caps
  `CT-4456 "PARA" — 501ST LEGION · SERGEANT · MEDIC`.
- **Currency readout** top-right (Phase B+, hidden until economy exists).
- X close button top-right; F4/ESC behavior unchanged.

## 4. Phase A tabs

### 4.1 LOADOUT (replaces "Character")

Two zones, reference layout:

- **Left/center hero:** identity statement + level progress bar (fed by
  service time until XP exists, labeled SERVICE); live model; **slot cells**
  flanking it — left column PRIMARY / SIDEARM / EQUIPMENT (current class
  weapons, icons via spawnicon or weapon class name), right column
  BATTALION / RANK / CLASS / LORE (gold frame when lore/commander). Slots
  are read-only at Phase A (loadout comes from class); they become
  interactive equip targets in Phase B. HP/ARMOR vitals bars under the
  model. **Service ring** (UI.RingGauge): gold designation centered, ring =
  service time.
- **Right zone:** **NEWS panel** standing in where the reference shows the
  inventory grid — config-driven posts (`SWRP.addNews(title, date, body)`
  in `swrp_customthings/news.lua`), rendered newest-first as thin-stroke
  cells. The zone is sized to the inventory grid's geometry so Phase B
  swaps news out for the real grid without relayout (news then moves to
  DAILIES-adjacent placement or a NEWS tab — decided in Phase B's spec).

### 4.2 BATTALION

Reference's Fireteam screen is the template: roster rows left (avatar,
name, role line, eliminations→rank, online/last-online), action buttons
inline in the panel header (Invite, search) instead of v4's floating
header. Right zone: **unit panel** — commander cell, member/online counts,
rank-cap cells, **lore slots with current holders** (requires adding lore
occupancy to the roster payload — small server change, in Phase A).

### 4.3 CLASSES

Full-height trooper columns (already approved): one column per class, model
fills the column (fix the torso zoom: remove the `SetCamPos` override in
ClassCard and frame full-body), stats as labeled slot-cells, CTA bar at the
bottom. Gold = current, blue = available, dim = locked with reason.

### 4.4 STAFF

v5 layout (editor + command reference left, full-height audit feed right,
refresh inline in the feed header), reskinned to v6 cells.

### 4.5 SETTINGS (new, small system)

- Left: category nav (General / HUD / Chat at launch) + toggle/value rows.
  Backed by a new tiny client store: `SWRP.Prefs.Get/Set(key)` persisted
  via `file.Write` JSON in `data/swrp/prefs.txt` (client-side only at
  Phase A; nothing here is authoritative).
- Right: **Quick Links** panel — config-driven
  (`SWRP.Config.Settings.quick_links = { {label, url, color}, ... }`),
  opens via `gui.OpenURL`. Discord/Workshop/Rules out of the box.

### 4.6 Scoreboard + HUD

Reskin only: scoreboard bands and HUD plate adopt the v6 stroke-cell
treatment and accent system. No structural change.

## 5. Phase A engineering inventory

- `cl_theme.lua` v6 tokens (surfaces, accents, rarity ramp, radius 2).
- New kit components: `UI.SlotCell` (label + content + rarity/state frame),
  `UI.RingGauge` (Circles-based arc + center text), `UI.CellList`
  (thin-stroke row container), `UI.IdentityLine`.
- New module `modules/news/` (sh config API + cl rendering; no DB).
- New module `modules/prefs/` (client settings store) + Settings tab.
- Battalion roster payload: + lore occupancy (server).
- ClassCard rewrite for full-height columns.
- Everything else is relayout/reskin of existing tabs.

No DB migrations in Phase A. All new nets: none (news/prefs/quick-links are
config/client-side; lore occupancy rides the existing roster net).

## 6. Systems roadmap (Phases B–I)

Dependency-ordered; each is its own spec → plan cycle. Listed scope is the
contract Phase A's seams must respect.

| Phase | System | Scope summary |
|-------|--------|---------------|
| **B** | **Items + Inventory + Economy** | Item definition registry (config-driven: id, name, rarity, type [weapon/cosmetic/perk/title/icon], weight, model/icon); per-character inventory table + equip slots; weight cap; loadout presets; credits ledger table with transaction log. UI: inventory grid (filter, rarity frames), Loadout slots become interactive, currency readout, weight bar. |
| **C** | **Shop + Crates** | Config catalog (price, stock, NEW flag); order flow with server-side validation; crate loot tables + open animation; audit-logged transactions. UI: Shop tab. |
| **D** | **Trading** | Escrowed two-party sessions (both confirm, server swaps atomically); offer grids + credits; private trade chat (rides chat module); presence ("Viewing X"); full audit log. UI: Trading tab. |
| **E** | **XP / Levels + Dailies + lifetime stats** | XP sources (playtime, events, kills if wanted); level curve config; lifetime stat counters; daily objective rotation + rewards. UI: ring/bar switch from service time to XP, Profile stat chips, Dailies tab. |
| **F** | **Season / battle pass** | Season config (name, dates, tier rewards, weapon objective grids); season XP separate from level XP; reward claiming through economy/items. UI: Season tab (Objectives/Overview/Rules). |
| **G** | **Versus** | Server-authoritative wager games: Credit Flip (open-game lobby) + Minefield (per-tile RNG, cash-out); house rules config (min/max bets); winner history + hourly tickers; heavy audit logging. UI: Versus tab. |
| **H** | **Skills** | Config-defined skill tracks with XP + level caps and perk hooks. UI: skill rows on Profile. |
| **I** | **Fireteams** | Squads orthogonal to battalions: name/color, leader, invites (interaction module), member overhead/minimap markers. UI: Profile sub-tab. |

**Cut (explicit):** hunger/thirst, per-limb damage/broken/bleeding, premium
second currency (crystals) — readout supports one currency; magenta slot
reserved if this ever changes.

## 7. Error handling & testing

- All new Phase A surfaces are client/config only — config errors go
  through `SWRP.Validate` (file:line + suggestions, never crash).
- Roster payload change is additive (older clients ignore the field).
- TESTING.md gains a v6 section per tab (visual checklist + news/prefs/
  quick-links behaviors).
- `luac -p` on every file; runtime pass by Rene on the local server is the
  acceptance gate, as established.
