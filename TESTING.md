# Testing guide — features since the last verified build

Last verified in-game: Phases 0–3 core (boot, designation, battalion mgmt,
classes) on the old windowed UI. **Everything below is new and untested at
runtime**: Phase 4 (chat/sync/staff/spawns/armory), named slots (lore &
commanders), the Republic Terminal UI v4, and the RNDX/Circles smooth
rendering layer.

## Setup

- Pull `main`, copy `gamemodes/swrp/` and `addons/swrp_config/` to the server
  (delete any older copies first). Map: anything (`gm_construct` fine).
- Ideal: **two real players** (invites/offers need a second account that can
  click prompts — bots can't accept). Solo + bots covers everything else.
- You need **superadmin** for staff features.
- Useful console: `swrp_menu`, `swrp_bots <n>`, `swrp_audit`,
  `swrp_reload_config`, `ent_create swrp_armory`, `!help` in chat.

## 0 · Boot sanity

- [ ] Server console shows `booting v0.1.0 (server realm, root 'swrp/gamemode/')`,
  **12 modules loaded** (Audit, Battalion, Character, Chat, Class, Example,
  Hierarchy, HUD, Interaction, Lore, Spawns, UI), `registry OK: 2 battalion(s)`,
  `registry OK: 3 template(s), 4 assignment(s)`, `registry OK: 1 lore slot(s)`,
  `DB ready (sqlite)`, `cross-server sync polling every 5s`.
- [ ] **No** `Failed to load shaders!` line in the CLIENT console after joining
  (that's the RNDX shader mount — if you ever see it, the UI silently falls
  back to stock rendering; report it).

## 1 · First join — designation picker (NEW: digit boxes + live availability)

- [ ] Picker appears after join: dialog with N digit boxes, blur + drop shadow
  behind it, no close button.
- [ ] Typing fills the boxes; box outlines turn **green + "#### is available"**
  when complete and free.
- [ ] Type a designation someone holds → **red + "is taken"** live, before
  clicking anything.
- [ ] Claim → success toast, picker closes, name everywhere shows the number.
- [ ] Reconnect → no picker (persisted).

## 2 · Republic Terminal (F4) — full-screen UI v4

- [ ] F4 opens a **full-screen** translucent layer (world dimmed/blurred
  behind), caps nav top (`SWRP / GRAND ARMY COMMAND` left, `F4 / ESC` right).
- [ ] F4 again **and** ESC both close it (ESC must NOT open the pause menu).
- [ ] Tab underline + hover transitions feel smooth (no snapping).

### Character tab
- [ ] Your **live player model** renders left, slowly swaying; identity reads
  `CT-#### "NAME"` with battalion · rank · class subline.
- [ ] Fact rows: designation (gold), **service time ticking live** (h/m),
  loadout list, lore identity ("None held").
- [ ] Chain of command shows **circular avatars** of online officers
  (commander first) or "No officers online".

### Battalion tab
- [ ] Roster rows: circular Steam avatars (initials discs for bots/offline),
  derived names, online green / offline dim, hairline dividers.
- [ ] **Search** filters instantly by name or designation.
- [ ] **Click/right-click a member → context menu** (shadowed): only actions
  your rank allows appear; your own row opens nothing.
- [ ] Promote/Demote from the menu → toast + roster updates + their name
  changes everywhere live.
- [ ] Remove → confirm dialog → they respawn as Unassigned.
- [ ] Invite (button only visible with `can_invite`): picker lists non-members
  with avatars → they get the **gold "DECISION NEEDED · 30S"** prompt with
  countdown → accept → they respawn in the battalion.

### Classes tab
- [ ] Cards with **model thumbnails**, HP/ARMOR/SLOTS stats.
- [ ] Current class = gold border + `CURRENT CLASS`; eligible = blue
  `BECOME X`; locked = dimmed card with the reason where the button would be
  (`REQUIRES SERGEANT+`, `SLOTS FULL 2/2`).
- [ ] Become → confirm ("You will respawn") → respawn with new loadout, name
  gains the class tag (`MED`/`HVY`), card flips to gold.

### Staff tab (superadmin)
- [ ] Non-staff see only "Restricted to staff."
- [ ] Record editor: set a target's battalion/rank/designation/name → toast
  feedback, target notified, change visible immediately.
- [ ] Audit feed lists recent actions with severity dots (red = kick/strip,
  gold = lore/admin, blue = rest); Refresh works.

## 3 · Chat channels (NEW)

- [ ] Plain chat = **local**: a player ~600+ units away does NOT see it; a
  near one does. Battalion-colored derived name.
- [ ] **Radio**: `/r <msg>` *and* the team-chat key → gold `[RADIO]` tag;
  heard battalion-wide regardless of distance; NOT heard by other battalions.
- [ ] Dead player using `/r` → refused ("cannot use comms while dead");
  dead local chat shows `*DEAD*`.
- [ ] `/ooc <msg>` → dim `[OOC]`, everyone sees it.
- [ ] `/me salutes` → `* NAME salutes` italic-style, proximity only.
- [ ] `/notacommand hello` → "Unknown command — try !help" to you only,
  **nothing broadcast**.
- [ ] Spam fast (9+ messages in 5s, e.g. via bound `swrp_ooc`) → excess
  silently dropped.
- [ ] Empty `/r` → "Nothing to send" hint.

## 4 · Lore characters & commanders (NEW)

Prep: second player in the 501st.

- [ ] `!lore` lists "Appo (Commander) — open".
- [ ] As a CPT (non-staff): `!offerlore <player> Appo` → refused, "commander
  slots are granted by staff".
- [ ] As staff: `!offerlore <player> Appo` → they get the prompt → accept →
  they respawn as `501st CDR 1119 Appo` (150HP/100AR, extra weapon).
- [ ] Commander shows **gold** on scoreboard/roster with rank "Commander".
- [ ] Authority: Appo can promote/kick anyone in the 501st; a CPT trying to
  kick Appo → "target does not rank below you".
- [ ] `!lore` now shows "held by ..."; offering Appo to someone else →
  "already claimed".
- [ ] `!striplore <player>` (staff) → they respawn as their normal identity;
  slot reopens.
- [ ] Claim again, then **kick the holder from the battalion** → slot
  auto-frees (`!lore` shows open) and they lose the identity.

## 5 · Spawns + armory (NEW)

- [ ] Stand somewhere, `!addspawn 501st` (staff) → chat + console print a
  ready-to-paste config line.
- [ ] Paste into `swrp_customthings/spawns.lua`, `swrp_reload_config`,
  respawn → 501st members spawn there (Unassigned still at map default).
- [ ] `ent_create swrp_armory` → crate; dump ammo, press **E** → "Loadout
  resupplied" + full weapons/ammo; spamming E → 5s cooldown (silent); HP/armor
  NOT restored (by design).

## 6 · Scoreboard (v4)

- [ ] Hold TAB: **top-anchored** centered bar, server name band, map +
  personnel count.
- [ ] Players grouped under battalion color-tick bands with counts; rows have
  circular avatars, derived names in battalion color (commander gold), rank,
  designation, ping; sorted rank-descending.
- [ ] Stays open while held; updates within ~2s when someone is promoted.

## 7 · HUD (v4)

- [ ] Plate bottom-left: name, battalion · rank line, HP/armor bars **with
  numbers**, low HP turns the bar red.
- [ ] **Ammo block** bottom-right with a gun out: big clip count `/ max`,
  `N RESERVE · WEAPON` line; hidden with fists/no-clip weapons; default HL2
  ammo HUD is gone.
- [ ] Overhead tags: name + smaller `Rank · Battalion` subline; still hidden
  through walls and beyond ~600 units.

## 8 · Rendering quality (RNDX/Circles)

- [ ] Corners on buttons/cards/popups look **smooth** (no stair-stepping —
  compare any old screenshot).
- [ ] Avatars are **true circles** everywhere.
- [ ] Dialogs (invite picker, confirms) have a soft drop shadow + rounded
  blur; context menus have a shadow.

## 9 · Stress pass

- [ ] `swrp_bots 20` → bots spawn spaced out, get records/loadouts, appear
  grouped on scoreboard/roster with initials discs.
- [ ] With ~20+ bots: open F4 roster, scoreboard, fight a bit — watch client
  FPS and server console for errors. Note anything that stutters.
- [ ] `swrp_audit` still prints cleanly afterwards.

## Expected (not bugs)

- Brief Steam-name flash for ~1 tick while a record loads on join.
- `swrp_reload_config`: NEW config files can't reach clients until restart
  (warned in console); edits apply server-side.
- Cross-server sync is inert on SQLite — testable only with MySQL + a second
  server (later).
- Class slot counts ignore bots (they're memory-only).
- Lore/commander model = battalion model until bespoke models are configured.

## Reporting

For each issue: **what you did → what you expected → what happened**, plus
server console output, client console output (`condump` writes a file), and a
screenshot for anything visual. Paste straight into chat — file:line errors
are gold.

## UI v6 — "AotR Replication" skin (Phase A)

**Everywhere**
- [ ] All corners are sharp (~2px); panels read as thin 1px-stroke cells
- [ ] Green identity line under the nav on EVERY tab: `CT-#### "NAME"` + battalion · rank · class
- [ ] Tab strip reads LOADOUT · BATTALION · CLASSES · STAFF (staff only) · SETTINGS

**Loadout tab (replaces Character)**
- [ ] Live model centered; PRIMARY/SIDEARM/EQUIPMENT cells left; ring + BATTALION/RANK/CLASS/LORE cells right
- [ ] Ring: gold designation centered, green arc fills with service time (10h per lap)
- [ ] HP/ARMOR bars under the model track damage live
- [ ] Lore cell goes gold when you hold a slot (`!lore` to claim as staff)
- [ ] Right zone shows HOLONET NEWS posts from swrp_customthings/news.lua (on a local listen server, lua autorefresh re-runs the file on save — reopen the menu; dedicated-server clients need a reconnect)
- [ ] Model updates after a class-switch respawn while the menu is open

**Battalion tab**
- [ ] UNIT COMMAND panel right: Commander (gold when filled / Vacant), Strength, capped-rank cells (e.g. Captain 1/1), lore slots with holder names
- [ ] Roster rows show a gold lore-slot chip for holders
- [ ] Search, invite, and the right-click member actions still work
- [ ] Promote/demote while the tab is open: unit panel updates WITHOUT re-fading

**Classes tab**
- [ ] Full-height trooper columns; the WHOLE body is visible (no torso zoom)
- [ ] Check full-body framing at your resolution AND once on an ultrawide/odd aspect if available (fixed camera; cropping would show there first)
- [ ] Stat cells (HP/ARMOR/SLOTS) above a CTA bar; gold = current, blue = become, dim = locked reason

**Settings tab (new)**
- [ ] Toggle cells flip ON (green) / OFF and persist across reconnects (data/swrp/prefs.txt)
- [ ] "Reduce menu motion" kills fades/staggers immediately
- [ ] "Show overhead name tags" hides/shows overhead names
- [ ] Quick-link cells open their URLs in the Steam overlay

**Scoreboard / HUD**
- [ ] Scoreboard, HUD plate, and ammo block have the 1px cell stroke

**Expected (not bugs)**
- The ring/service bar measure playtime — XP arrives in the progression phase
- News right zone becomes the inventory grid in Phase B
- The v4 chain-of-command strip is gone by design (unit panel replaces it)
