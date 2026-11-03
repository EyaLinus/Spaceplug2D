# Progress log

## Release v0.1.6 (2026-11-02)
- Phase 2 wave 2 complete: A2 Deal-O-Matic, A3 Market & Orders, B2 ship cargo bay, B1 NPC schedules + day/night.
  Changelog folded, version 0.1.6 in project.godot and export_presets.cfg. Next: wave 3 (A4 DeadDrops, B3 workers
  (open PR #30), A5 dealers, A6 galaxy map + jump).

## E2: space combat (2026-11-03)
- **Core** `scripts/core/spacecombat.gd` (static rules over Game), state `Game.combat` {hull, shield, missiles, kills} saved
  (+ runtime boost/idle); old saves load an undamaged stock ship. Four new upgrades in `content.json` (laser, missile, shield,
  hull, 3 levels each; bought via the normal `buy_upgrade` at the mechanic, so the layered E3 ship art, shipyard grid and
  save/old-save fallback come for free) and a `combat` section (weapons, boost, pirates, spawn, defeat). Rules: shield soaks
  first, shield regen after 3 s idle and on docking, hull repaired for credits at the shipyard, boost = energy + 0.45 s
  invulnerability, pirate pressure x system (Kovar 1.6) x hold (product units), pirates only farther than 750 px from any
  location, wreck = half the hold + 10 % fine + half hull.
- **World** `combat_layer.gd` (pirates, bolts, homing missiles, effects, spawn, shield ring, screen shake), `pirate.gd` (circle,
  strafe, lead-aim), `ship.gd` boost/dodge, `world.gd` hooks (small hunks), HUD `scripts/ui/combat_hud.gd` as the world's own
  CanvasLayer (hud.gd untouched; main.gd only gets 3 input actions J/K/Shift, also rebindable in settings). New art: pirate
  sprite, 12 module frames (laser/missile/shield/hull x Mk2..Mk4) and 4 upgrade icons via build_art.py.
- **Shipyard UI:** module rows come from the existing grid, new Mechanic block (repair hull, restock missiles, stats).
- Verified: unit checks (module stats, damage/shield/regen, boost, pirates/pressure/defeat, mechanic, save + old-save
  fallback, abstract duel balance: stock ship kills a pirate in 2.8 s at 50 % hits and survives ~12 s against three), UI smoke
  (modules bought, auto-spawn, laser kill + bounty, missile kill, shield then hull damage, dodge passes bolts, wreck, docking
  clears the fight), menu smoke, sim 5/5 won (bot ignores combat). Screenshot `space_combat` added to tools/shot.gd.
- Gaps: no human playtest, pirate numbers are eyeballed (the unit "balance" test is an abstract duel, not the live game); the
  sim bot does not fight or buy modules; the parked ship on the landing pad shows the new modules automatically (it draws
  Game.upgrades) but surface.gd is untouched; no ramming/collisions; D3 Interdiction can reuse `combat_layer.spawn_pirate`.
## A4: DeadDrop Logistics (2026-11-02)
- **Core:** `scripts/core/deaddrops.gd`, rules in content.json `deaddrops`, state `Game.drops` (+ `next_drop_id`, saved;
  old saves load without). Request a drop (60 cr, max 3, one per planet/station/outpost) from the phone; while docked
  there it takes one job at a time: an accepted Deal-O-Matic deal (offer state `dropped`, customer collects after 25 s
  and pays) or a courier run to the hub stash (4 cr/unit, min 20). Drop heat is 30 % of the in-person hand-over; every
  pickup/courier can be stolen (7 % + up to 15 % at max heat, courier +5 %): no goods, no pay (offer state `stolen`).
  Idle drops close after 600 s. `Deals._trim` keeps `dropped` deals.
- **UI:** `apps/deaddrop_app.gd` + one line in `registry.gd` (icon `app_deaddrop`), toasts on pickup/theft in `main.gd`.
- Verified: 1857 unit checks (rules, heat vs hand-over, pay, theft, courier, expiry, caps, trimming, save round-trip,
  old save), UI smoke (request, leave deal, collect and pay), menu smoke, sim 5/5 won (avg day 6.2), screenshot of the app.
- Gaps: no map marker for drops on the surface; the customer collects instantly in the sim (no walking NPC);
  A5 (dealers) can reuse `Deaddrops.at()` / jobs; courier only goes drop -> hub stash.

## B1: NPC schedules on foot (2026-11-02)
- Surfaces have `spots` (schedule place name → tile, `surfaces.json`). `People.spot(c, spots, hour, slot)` picks the
  spot of the current schedule place, nudged by the person's index on the surface so people sharing a place stand
  side by side. Named people start at their current spot on landing and walk there (AStarGrid path) when the hour
  changes; while the player is within 60 px they stop (`npc.hold`), so a conversation never walks away. Their
  interaction point follows them.
- Day/night: `time.daylight` colour keys, `CanvasModulate` on outdoor surfaces (interiors excluded). A day now starts
  at 06:00 (`time.day_start_hour`), so the phone clock, contact schedules and Deal-O-Matic places shift accordingly.
- Verified: 1816 unit checks (every schedule place has a spot on the person's surface, every spot walkable and
  reachable at every hour, day start, daylight), UI smoke (schedule change → Okka walks, her interaction point
  follows, light changes), menu smoke, night screenshot.
- Gaps vs. the old draft PR #5: no idle chatter bubbles; anonymous walkers keep roaming; people stand at a spot in front
  of "Home" instead of going indoors (keeps them dealable).

## B2: ship cargo bay estate (2026-10-30)
- **Core:** `estates["ship_bay"]` (`Game.SHIP_BAY`, content.json estates entry flagged `"ship": true`, 7x4 cells) is
  always owned (also created for old saves) and not for sale. `estate_reachable()` gates `enter_ship_bay`, `can_place`,
  `place_building` and `remove_building`: only while docked. Everything else (door cell, refund, cooking via
  `lab_here`/`missing_stations`, save round-trip) is the existing estate code; `estate_layout.gd` is unchanged.
- **UI:** a ramp interactable beside the landing pad (added in `main._with_ship_ramp`, so `surface.gd` and
  `surfaces.json` are untouched) enters the bay; its exit door returns to the pad. Stations without a surface get a
  "Cargo Bay" tab in the docked menu. Build menu and placement work as in any estate.
- Verified: unit tests (new `test_ship_bay`), UI smoke (ramp, place, leave), menu smoke, sim 5/5 won.
- Gaps: size does not grow with the cargo upgrade; no generator/crate buildables yet (needs the production-buildings
  milestone); the ramp has no art, only an interaction label.
## A2: Deal-O-Matic (2026-11-02)
- **Core** `scripts/core/deals.gd`, state `Game.offers` (+ `next_offer_id`, `offer_clock`, saved; old saves start empty).
  Every 40 s each known customer without an open deal may text (chance 0.3 × (0.5 + addiction), max 3 open):
  a preferred drug, qty within deal size and today's budget, price = their Standard price + 15 % premium.
  Accept → 150 s to meet them; counter +10/+25 % once (chance 0.8 − 2.6 × raise + 0.4 × affinity + 0.4 × addiction);
  decline −0.02 affinity, failed counter −0.03, no-show −0.08. Fulfil in person: any product of the right drug,
  heat × 0.8 vs. a walk-up sale. Rules in `content.json` → `deals`.
- **Phone app** `apps/deals_app.gd`: threads sorted new → agreed → closed, chat bubbles, Accept / +10 % / +25 % /
  Decline with shown odds, agreed deals show where to meet, time left and whether the hold has enough.
- **On foot:** customers with an agreed deal carry a gold "$"; their Deals panel has a Hand over button.
  Toasts for new requests and missed meets.
- Verified: 1078 unit checks (request rules, expiry, decline/accept/counter odds and outcomes, no-show, fulfil rules,
  save), UI smoke drives text → phone accept → marker → hand over, menu smoke, sim 5/5 (bot ignores texts),
  screenshots of list, thread and marker checked.
- Deviations/gaps: the meeting point is the customer on their planet, not a separate spot (dead drops are A4); the
  walk-up Deals panel stays as a fallback; the balance bot does not use texts yet; prices are eyeballed.
## A3: Market & Orders app (2026-11-02)
- **Core** `scripts/core/orders.gd`, state on `Game`: `orders` (open, saved), `order_seq`, `estate_stock` (estate id -> items, saved),
  `orders_unseen` (runtime, app badge). Phone price = cheapest walk-in price anywhere + 35% markup, plus a delivery fee
  (6%, min 12 cr; express x2 fee, 30 s instead of 90 s; +60 s to estates outside the start system). Max 40 per order, 6 open
  orders. Goods arrive via `Game.tick` in the hub stash or an owned estate's stock; `collect_stash()` inside the estate
  unloads that stock into the stash first, then loads the hold. Cancel refunds 80% of the goods, fee is lost. Rules in
  `content.json` -> `orders`. Old saves load with no orders; orders for unknown estates fall back to the stash.
- **Phone app** `apps/orders_app.gd` (one line in `registry.gd`): destination picker, standard/express, per-item qty
  stepper (Shift = 5) with live total, in-transit list with countdown and cancel, badge for new deliveries. HUD toast and
  sound on delivery.
- **Station kits** (lab expansions): every buildable can be ordered as `kit:<station>` for 85% of the on-site build
  cost (`orders.kit_price`). Kits land in `Game.kits` (saved), the estate build menu shows "Kit ×N" and
  `place_building` uses a kit instead of credits.
- Verified: unit tests (new `test_orders`, `test_order_kits`, `test_orders_save`), UI smoke (order from the phone,
  delivery, cancel), menu smoke, sim 4/4 won.
- Gaps: no price history or per-planet stock, delivery time is flat per speed, estate stock is not shown inside the
  estate UI except via [collect]. Kits can't be ordered to a specific estate (they are a global shelf).

## Release v0.1.5 (2026-10-30)
- Phase 2 wave 1 complete: A1 Com-Phone + Contacts, D1 Kovar system (Varrow, Glacis), C1 Extractor/Refiner, E3 visible
  ship upgrades. Changelog folded, version 0.1.5 in project.godot and export_presets.cfg. Next: wave 2 (A2, A3, B2, B1).

## E3: visible ship upgrades (2026-10-30)
- **Modules:** every bought upgrade level adds a pixel-art module to the player ship: engine nacelles (Mk2 small,
  Mk3 with fins, Mk4 with a centre booster), cargo pods on struts (one, bigger, two per side), stealth plating (wing
  panels → most of the hull → full dark hull with teal sensor strips), hydro rig dome (small, large, plus tanks).
  Sources `assets/src/sprites/ship_<upgrade>.txt` (24x24, one frame per level), `build_ship_modules()` in build_art.py.
- **Drawing:** `Art.draw_ship(ci, levels)` layers engine/cargo under and stealth/lab over the hull. Used by the ship in
  flight (`world.gd` passes `Game.upgrades`), the parked ship on the landing pad (redraws on `upgraded`) and a new 3x
  preview in the shipyard tab (`scripts/ui/ship_preview.gd`). Engine flames come from `Art.SHIP_NOZZLES` (1/3/3/3
  nozzles) and burn teal-hot with higher engine levels.
- **No gameplay change:** hull is not an upgrade yet, so "hull" is shown through the stealth plating; weapons/shields
  (E2) plug in as further keys in `SHIP_UNDER`/`SHIP_OVER`.
- Verified: unit checks incl. new module/nozzle checks in `test_art_registry`, UI smoke, screenshots (`shipyard`,
  `flight_upgraded` added to `tools/shot.gd`) reviewed.
- Gaps: no collision/size change for bigger ships (modules are cosmetic); Mk4 cargo + Mk4 engine make the silhouette
  busy at 1x zoom.

## C1: Lab stations II – Extractor + Refiner (2026-10-30)
- **Purity:** new station stat `affects: "purity"`. `Production.outcome()` returns `purity` (average of the purity
  stations, missing = `quick_score`) and the grade now uses `lerp(quality stations, purity, quality.purity_weight = 0.5)`.
  Quick batches stay Standard; a perfect cook with a skipped purity step tops out at Premium.
- **Stations** (`content.json` stations/station_order/buildables): Extractor (weed, cocaine; 450 cr, 2x1) and Refiner
  (cocaine, meth, fentanyl; 550 cr, 2x2). Order: prep → extractor → mixing → cook → refiner → pack. Every drug has one
  purity station at least (test). Old estates must build the new ones before they can cook those drugs.
- **Minigames** (`scripts/ui/minigames/`): `extract.gd` = hold-to-heat with inertia along a moving profile (warm-up,
  two fractions, cool-down) on a chart recorder, boiling over costs double; `equilibrium.gd` = runaway reaction with
  a flipping pull, acid/base doses that act after 0.5 s, 14 doses each. Bots: extract looks 0.4 s ahead, equilibrium
  simulates its own dynamics forward (`predict()`); skilled ≥ 0.85, idle ≤ 0.35 over 4 seeds per drug (test).
- **Art** (game-assets-2d): pixel sprites for all 7 stations, `assets/src/stations/<id>.txt` sized to the footprint,
  `build_stations()` in `build_art.py`, drawn by `surface.gd` with smaller name tags (procedural fallback stays).
  `tools/shot.gd` now also shoots an estate with every station and the Refiner minigame.
- Verified: 961 unit checks, UI smoke (weed hand batch runs 5 stations incl. extractor), menu smoke, sim 5/5 won;
  screenshots of both minigames and the furnished estate reviewed.
- Gaps: purity is not stored on the product (only in the grade); equilibrium tuning is bot-tested, not human-tested;
  the 1x1 Precursor Scale label is still a bit wider than the machine.

## D1: galaxy model + two new planets (2026-10-30)
- **Galaxy model:** `content.json` → `systems` (name, galaxy_pos for the later map app, security, `patrol_mult`, star and
  nebula colours) and `jump` (fee 80 cr, 20 s travel time). Every location has a `system`; gates are locations of kind
  `gate` with `jump_to` + `arrive`. Core in `game.gd`: `system` (saved; old saves fall back to the start system),
  `loc_system`, `locations_in`, `patrol_home` (location with `patrol_base`, else the gate), `jump(gate)` (in flight only,
  toll, ticks time, emits `jumped`); `patrol_count()` scales with the system's `patrol_mult`.
- **World:** `world.gd` builds one system at a time (`show_system`, starfield/nebulae seeded per system), patrols fly from
  the current system's base, gates count as "nearby". `main.gd` turns docking at a gate into a jump with a short white
  flash; loading a save in flight puts the ship at its system's gate. HUD shows the system next to the day and
  "[E] Jump to … (80 cr toll)".
- **Kovar Expanse:** Varrow (desert, surface security 0.3, fence, cheap coca/pseudo, meth demand ×1.35, Dune Cellar
  estate) and Glacis (ice, security 1.6, heat 3.5/unit, cocaine ×1.5/fentanyl ×1.4, additives, Cryo Vault 4, patrol base)
  with walkable surfaces and 4 new named customers (Rhea, Kip, Ivo Halden, Nadia Frost).
- Art (game-assets-2d pipeline): tile sets varrow/glacis, space sprites for both planets and the jump gate, props
  cactus/ice_rock.
- Verified: 897 unit checks (new `test_galaxy_and_jump`, surface/art tests cover the new planets), UI smoke jumps both
  ways and walks every door and person on Varrow and Glacis, menu smoke, sim 5/5 won (bot stays in Halvane);
  screenshots of both surfaces, both planets and the gate in space reviewed.
- Gaps: the jump is a plain toll gate (A6 brings the galaxy map, charge-up and hyperspace VFX, D3 interdiction);
  bot/sim ignores the second system; prices in Kovar are eyeballed; no mechanic/shipyard there yet.

## A1: Com-Phone + named customers (2026-10-30)
- **Core** `scripts/core/people.gd`, state in `Game.people` (saved; old saves get defaults): addiction 0..1 (+ per unit by
  drug tier, −0.04/day), affinity −1..1 (+ per deal, liked trait, preferred drug, grade; Shoddy lowers it), daily budget
  (grows with addiction, resets each day), deal size (grows with addiction), price × affinity × preferred drug, last 8
  deals, `known` flag (`Game.meet()` when you talk to someone), schedule data with `whereabouts(hour)`.
  Rules in `content.json` → `people`, profiles in `contacts` (job, bio, look, prefers, budget, schedule).
- 9 named customers, 4 new (Teo, Vesna on Mireth, Marta on Cinder, Ozzy on the Bazaar), placed on their surfaces.
- **Com-Phone** `scripts/ui/phone/`: overlay [Tab] (rebindable) in flight and on foot, home screen from `registry.gd`,
  apps subclass `phone_app.gd` (home(), badge()); screens stack via `phone.push(title, builder)` and rebuild after every
  game event. Ship holds position / player is frozen while it is open; time keeps running.
- **Contacts app**: met people by location with mood, addiction, ready dot; profile with portrait, bio, "now at",
  affinity/addiction/budget meters, prefers, loves, deal size, status, schedule, history. Unmet people as a hint only.
- Art: 6 phone app icons (contacts + deals, deaddrop, hr, orders, map ready for later apps).
- Verified: 663 unit checks, UI smoke (meet Teo, Tab, contacts list/profile, Esc back/close), menu smoke, sim 5/5 won,
  screenshots of home, list and profile checked.
- Gaps: schedules are data only (B1 makes people walk them); balance got easier (sim avg win day 8.0 → 6.2 with
  4 more buyers and affinity bonus), fine for now since prices are eyeballed; Deals panel still exists (A2 replaces it).

## P4 step 2: cook in your estate (2026-10-30)
- Inside an owned estate every placed station opens the Lab (plus its own Station tab). A batch needs the stations its
  recipe runs through (`Production.stations_for`); missing ones are named in the lab and block the batch.
  Output, queue and stash are still shared with the hub lab (one production queue), so you can cook on Cinder or the
  Bazaar and load the stash there. Core: `Game.lab_here`, `missing_stations`, runtime `inside_estate`.
- Verified: 504 unit checks (cook in the Shaft 9 Shack once Trim Table + Cook Stove + Packaging Table stand; additives
  need a Mixing Station; no lab outside), UI smoke checks the estate counts as a lab; screenshot of the estate lab checked.
- Gaps: estates share one queue/stash with the hub; per-estate storage and workers come with P5.

## P4 step 1: estates (2026-10-30)
- Four estates for sale (`content.json` → `estates`): Cannery Annex (1,500 cr) and Ridge Glasshouse (4,500 cr) on Mireth,
  Shaft 9 Shack (1,200 cr) on Cinder, Hull Locker 13 (2,200 cr) on the Bazaar. Each is a building on its surface.
- Buying opens the estate: its own instanced room (`scripts/planet/estate_layout.gd` → surface config, 2× zoom),
  [B] build menu lists the station types from the minigame station registry (`content.json` → `buildables`: cost + size),
  placement ghost on the cells in front of you (green/red), E places, Esc cancels. Using a placed station lets you take
  it down for 50 % back. The door cell always stays free. Core: `Game.buy_estate/can_place/place_building/remove_building`, saved.
- Verified: 495 unit checks (estate buy rules, placement bounds/overlap/door, save round-trip, refund, every estate has
  a surface building), UI smoke buys the annex, places a stove through the ghost, opens it, leaves; screenshots checked.
- Gaps: you cannot cook with your own stations yet (next step); no rotation, no upkeep, no selling estates;
  machines are procedural drawings, labels overflow on 1-cell stations.

## Art pass 3: UI icons (2026-10-30)
- 19 pixel icons: 4 raws, 4 products (baggies), 4 additives (vials), 4 upgrades, HUD credits/day/heat (+cargo).
  Shown in market rows, hold, deals, shipyard and the top bar via `Art.with_icon()`.
- Verified: 468 unit checks (every raw/additive/base/upgrade has an icon), UI + menu smoke, market/deals/HUD screenshots.
- Gaps: lab dropdowns and minigame panels have no icons yet.

## Art pass 2: space view (2026-10-30)
- Pixel art for Mireth (dithered sphere with continents), Cinder asteroid (craters, outpost hut), Drift Bazaar ring
  station (rotates), customs beacon and patrol cutters; glow, scan circles and siren lights stay procedural.
- Verified: 451 unit checks (every location has a space sprite, patrol sprite), UI + menu smoke, screenshots of each
  location in space reviewed (`tools/shot.gd` now shoots them).
- Gaps: new locations need a sprite in `build_space()` (the test enforces it); starfield still plain dots.

## Police pathfinding (2026-10-30)
- `scripts/planet/nav.gd`: AStarGrid2D per surface (building tiles solid). Chasing officers re-path to the player every
  0.35 s; an officer that gives up walks back to the roads around the buildings. Give-up range 320 → 480 px.
- Verified: unit test routes around every building with a door on all three surfaces without touching a building;
  UI smoke puts a chasing officer behind the Mireth hangar and checks it closes in without entering it.

## Art pass 1: pixel art for surfaces, characters and ship (2026-10-30)
- First real art via the game-assets-2d skill workflow (pipeline in `docs/art.md`): player, officer and 8 NPC looks with
  4-direction walk cycles, ship, tiles for Mireth/Cinder/Bazaar, tinted roof/wall pieces + windows/doors/hatches,
  props (crate, barrel, rock, tree, lamp, vent, stall). Central registry `scripts/core/art.gd`, procedural fallback kept.
- Verified: 328 unit checks (new: every surface/prop/look has art, sheet sizes, fallback returns null), UI smoke,
  screenshots of all three surfaces and flight reviewed; palette check 0 % off-palette.
- Gaps: space view (planets, stations, patrols) still procedural; characters have no idle animation; side-view arm
  is simple; ground tiles are noise-based, no transitions between grass and road.

## Station minigames in the lab (2026-10-30)
Every batch can now be cooked **by hand**: the Old Cannery lab runs it through its stations one after another
(`scripts/ui/minigames/`, rules in `scripts/core/production.gd`, numbers in `content.json` → `stations`, `quality`).
- **Trim Table** (Weed): click the fan leaves off the bud, nicking the bud costs → yield ×0.8–1.2.
- **Precursor Scale** (Cocaine/Meth/Fentanyl): scoops of 4–9 g, 1 g pinches, wobbling needle, hit the target → yield.
- **Mixing Station** (only with additives): hold to pour each additive, release in the green band → quality.
- **Cook Stove**: hold to fire the burner, temperature has inertia and drafts, stay in the band → quality.
- **Packaging Table**: press when the sweeping sealer is over the seal strip, one press per bag → heat ×1.3–0.7.
- Quality → grade Shoddy ×0.75 / Standard / Premium ×1.2 / Pristine ×1.4 on the sell value. Graded products are
  separate cargo stacks (key suffix `@grade`; old keys are Standard, saves stay compatible).
- "Quick batch" keeps the old one-click Standard result (and the balance bot uses it, so the sim is unchanged).
  Esc during the minigames skips the rest as Standard; ingredients are only taken at the end, but a skip never refunds.
- Higher drug tiers make the bands narrower and the sealer faster.
- Modular: a minigame subclasses `station_minigame.gd` (setup/step/press/key/bot_input, emits `finished(score)`),
  is listed in `registry.gd` and gets a `stations` entry; `MinigameRunner.start()` can be reused by estate buildings.
- Verified: 359 unit checks (new: station lists per drug, outcome math, graded keys + save, every minigame: skilled
  bot ≥ 0.8, idle ≤ 0.35, always ends); UI smoke plays a full hand batch through the real lab panel and checks that
  Esc skips without closing the panel; screenshots of every station checked.
- Gaps: not played by a human yet, so timings and band widths are guesses; art is procedural placeholder;
  the lab panel now needs a little scrolling for the stash button; contacts don't prefer grades yet (only value).

## P3 first step: police on foot (2026-10-30)
- Officers (`scripts/planet/officer.gd`) walk the roads with a drawn vision cone. Count = (1 + heat/20) × planet
  security, max 4 (Mireth 1.0, Cinder 0.5, Drift Bazaar 0 = lawless). Numbers in `content.json` → `police`.
- Carrying product inside a cone (buildings block sight) fills a frisk bar (1.6 s) → the normal bust (product + fine).
  At heat ≥ 40 an officer who sees you chases you until you are 320 px away or clean. Inside shop/deal panels you are safe.
- Verified: 241 unit checks (police count per heat/security, cone/range/wall sight rules); UI smoke places an officer in
  front of a carrying player and checks the bust; screenshot of a chase checked.
- Gaps: chasing officers walk through buildings (no pathfinding); no curfew, hiding spots or bribable officers yet.

## World: Cinder Belt and Drift Bazaar on foot (2026-10-30)
Every dockable location is now walkable; the docked menu is no longer used by any location (kept as fallback).
- Cinder Belt · Mining Camp 3: landing pad, Ore Depot (raws), Foreman Dax, canteen, bunkhouse, drill tower, rocks/barrels.
- Drift Bazaar · Hull Deck: docking bay, Hull Market (additives + fentanyl precursor), the Back Room (fence only),
  Lira Nine and Old Grub, cantina, cargo hold, vents.
- Verified: 228 unit checks (new: every dockable location has a surface, fence door exists only where there is a fence),
  UI smoke lands on both, opens every door/person and takes off again; screenshots checked.
- Gaps: both are still placeholder art; the map name label sits under the controls help at the bottom-left corner.

## Menu system (2026-10-30, unreleased)
- Main menu (Continue = latest slot, New game → pick slot, Load, Settings, Quit) and pause menu (Esc: Resume, Save,
  Load, Settings, Save & main menu, Save & quit). Menus are overlays in `scripts/ui/menu/`; Esc always steps back one level.
- Three save slots (`user://save_N.json`, `GameState.slot`); the old `user://savegame.json` moves into slot 1. The window
  close button saves a running game.
- `Settings` autoload (`user://settings.cfg`): Master/Music/SFX buses (AudioManager now plays on Music/SFX), windowed/
  fullscreen, window size, VSync, rebinding of each action's primary key with swap inside a group (Flight / On foot /
  General). HUD and surface prompts read the bound keys.

**Verified:** 166 unit checks, UI smoke unchanged and green, new `tools/menu_smoke.gd` (CI step) drives the menus with
real Esc / key events: slot picker, pause/resume, settings from pause, save/overwrite confirm, continue, load, delete,
volume → bus, rebind + swap + cancel, reload from disk, reset. Screenshots of all screens checked under Xvfb.

**Not verified:** fullscreen / window size only run on a real display (headless skips them); not tested on Windows yet.
Gamepad bindings are not supported (keyboard only). Station "Undock [E]" button text is still fixed to E.

## v0.1.2 (2026-10-30) – planet vision P1: landing & walking
Plan for the whole vision (planets as instanced on-foot levels, police, estates, production buildings, workers) is in
ROADMAP.md as milestones P1–P6. P1 is done in this step:
- Docking at Mireth now **lands on its surface** (`scripts/planet/surface.gd`, layout in `data/surfaces.json`):
  top-down walking (WASD/arrows), collision with buildings and map edge, camera follows with limits and 1.5× zoom.
- Economy moved into the world: Spaceport hangar + Rusk (mechanic) → ship upgrades, Night Market → buying,
  Old Cannery → lab/stash, Consortium office → debt + fixer, Okka and Sen stand on the plaza → deals with that person only.
  The station panel opens filtered to that one tab ("Leave [E]" / Esc closes it).
- Launch pad with your parked ship → take off back into flight; the surface instance is freed.
- Ambient walkers on the main roads, surface minimap, on-foot controls line in the HUD.
- Cinder Belt and Drift Bazaar keep the old docked menu until they get surfaces (P2).

**Verified:** 166 unit checks (new: surface layout validation – buildings inside the map, no overlaps, doors on
edges, every Mireth feature and contact reachable on foot). UI smoke now lands, walks, tests wall collision, opens
every door/person and checks each opens exactly its own tab, takes off from the pad. Screenshots under Xvfb look right.

**Not verified / known gaps**
- Not played by a human yet: walking distances and the 1.5× zoom are guesses.
- Walking around Mireth now costs in-game time (the day clock keeps running); the balance bot does not model
  walking, so the 12-day debt may feel tighter. Balance is eyeballed for now (Linus, 2026-10-30).
- Art is still procedural placeholder (rectangles + circles). Doors on the top side of a building look like a hatch in
  the roof; interiors come in P2.
- Walkers do not avoid each other or the fountain.

**Next for the planet vision (in order):** P2 art pass for the surface (tileset + character walk cycles via the
asset skill), building interiors, NPC schedules, customers on foot → P3 police on foot → P4 estates + placeable
production buildings → P5 workers.

## v0.1.1 (2026-10-30) – playtest fixes
Linus' first playtest: technically everything worked. Done here: Space = brake, S = reverse thrust; drug ladder with
real names (Weed → Cocaine → Meth → Fentanyl, value and heat scale with tier); old saves migrate.
Verified: 104 unit checks, UI smoke (incl. reverse + brake), bot sim 8/8 (bot only cooks Weed, so the T3/T4 prices are
estimates: higher tiers have more profit per cargo slot but lower return per credit).

## Current state (2026-10-30, v0.1 prototype)
**Playable loop:** start docked at Mireth → buy Cannabis Buds + additives → cook in the lab (mix up to 3 additives) →
load stash → sell to Okka/Sen at Mireth or fly to the Drift Bazaar (Lira, Old Grub, fence) / Cinder Belt (Dax) →
dodge patrol scans → upgrade ship and rig → pay 6,000 cr debt before day 12 → win screen (sandbox continues).

**Verified**
- 83 unit-test checks (core: mixing, market, lab, heat, bust, upgrades, bribe, debt, save round-trip) pass headless.
- UI smoke runs the whole loop through the real main scene (all tabs at all 3 docks, flight, bust, pause, save/load, win, lose) with 0 script errors.
- Balance bot (8 seeds, one fixed recipe, travel approximated): wins 8/8, on day 7–9 of 12, 1–6 busts.
- Screenshots of menu, lab, deals and flight taken under Xvfb (software GL).

**Not verified / known gaps**
- The Windows `.exe` is built by CI only; it has not been started on a real Windows machine yet.
- Balance numbers are first guesses; the bot flies perfectly and uses one recipe, a human will be slower (hence 12 days instead of 10).
- Art is procedural placeholder vector drawing; sound is synthesized beeps.
- No tutorial; the main menu text explains the loop.

## Next iteration (priority order)
1. **Playtest the exe** (Linus): is the debt timer too tight or too loose? Are patrols fair? Is the lab UI clear?
2. **Art pass** with the game-assets-2d skill: art profile, ship/patrol/planet sprites, UI icons for goods and traits.
3. **Tutorial contracts** (first batch / first sale / first bribe) replacing the menu text.
4. **Mixing journal** + one-click re-cook; show trait values in the lab preview.
5. **Patrol feel**: warning before entering scan range, asteroid field to break pursuit, a little screen shake on bust.
6. **Grow raws** (hydro trays) – first M2 feature.

## History
- v0.1 (2026-10-30): repo skeleton, architecture, vertical slice, CI with Windows export.

## E1: Ground combat (2026-11-02)
- **Core** `scripts/core/combat.gd` (static functions over `Game`), rules in `content.json` -> `combat` (player hp/regen/knock-out,
  3 weapons, officer stats and draw heat, cover pieces per planet). State on `Game`: `hp`, `weapons`, `weapon`, `ammo` (saved under
  `combat`; old saves load full health + pistol), runtime `cooldown`/`reload_left`/`since_hit`; `stats.kills/knockouts`.
  Pure geometry (`segment_rect_t`, `segment_circle_t`, `step_bullet`) so bullets, cover and line of fire are unit-testable.
- **Weapons:** pistol (free, 12 rounds), SMG (600 cr, auto), shotgun (900 cr, 7 pellets). Magazine + reload, fire rate, spread.
  Shots add a little heat only if an officer is within earshot (`witness_range`).
- **Player:** 100 HP, regenerates 4/s after 6 s without a hit. Knock-out (0 HP): product confiscated, fine 20 % (min 80), heat -20,
  wakes up at the launch pad with 50 % HP. Not a game over.
- **Officers:** at heat >= 55 (`officer.draw_heat`) or once shot at, they draw weapons, stop within 280 px if the line is clear and
  shoot every 1.0 s (9 dmg, spread). They hunt a visible player even without cargo while hostile (4 s memory). 40 HP; a kill gives
  +12 heat, a hit +4; killed officers respawn after 25 s.
- **Cover:** 5-7 pieces per planet beside the streets (`combat.cover`), solid for walking (also in the nav grid) and bullets, not for
  sight. Test: inside the map, off buildings/roads/plazas/pad, every spot, NPC, door and pad stays reachable.
- **UI** (`surface.gd`, `planet/combat_hud.gd`): crosshair, HP bar, weapon + magazine, reload ring, hurt vignette, weapon wheel,
  bullets, sparks, gun in hand; officer gun, hp bar and hit flash. Foot help line lists the new keys.
- Verified: 2185 unit checks (weapons, fire rate, reload, shop, damage/regen/knock-out, geometry incl. tunnelling, officer rules, cover
  layout on all 5 planets, save/old save/garbage save), UI smoke (cover stops a bullet, clear shot hurts + provokes, real mouse click and
  R key, armed officer shoots back, knock-out at the pad, officer kill, wheel buy + equip, key 1), menu smoke, sim 5/5 won.
- Deviations/gaps: civilians and named NPCs cannot be shot (bullets pass them); new keys (Q, R, 1-3) are not in the rebinding screen
  and the weapon actions are keyboard/mouse only; no ammo economy (unlimited reloads); cover is a static ground layer (no y-sort,
  walkers on the roads can brush past it); no screenshot of the HUD/wheel (Xvfb rendering hung in this container), so the layout is
  unseen; numbers are eyeballed; the balance bot does not fight. Officer AI is simple (no flanking, they do not seek cover).
