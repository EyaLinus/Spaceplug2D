# Progress log

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
