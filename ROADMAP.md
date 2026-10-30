# Roadmap

Versions are small and frequent: patch steps only (0.1.1, 0.1.2, …); a minor bump is Linus's call.
Each finished step ends with a Windows build on GitHub Releases. Price balance is eyeballed until Linus asks for a balance pass.

## Vision (Linus, 2026-10-30)
Two layers of play:
- **Space** – the existing ship flight between locations, patrol scans, smuggling routes.
- **Planets** – every planet is its own instanced level (like a dungeon instance): land at the spaceport and walk
  around top-down in RPG-Maker style. NPCs, houses, markets, police, a spaceport with a mechanic for ship upgrades and
  **estates** you can buy. In an estate you place production buildings (grow trays, mixing stations, packaging,
  storage) and hire workers who automate them. Taking off at the spaceport switches back to ship flight.

The core simulation (`scripts/core`) stays headless; planets are a new presentation layer on top of it, and every
new rule (estates, workers, police on foot) lands in the core with tests first.

## M0 – Foundation ✅ (v0.1)
- [x] Godot 4.3 project, headless core, EventBus/GameState/AudioManager
- [x] CI: unit tests, UI smoke, balance sim, Windows export, release on dispatch
- [x] Vertical slice: flight, 3 dockable locations, buy → cook/mix → sell, heat + patrols + bust, upgrades, debt goal, save

## P1 – Landing & walking (v0.1.2) ← current
- [x] Scene switch ship ↔ planet: docking at a planet loads its surface instance, take-off at the launch pad returns to flight
- [x] On-foot top-down movement (WASD/arrows, 8 directions, collision with buildings and map edge, camera limits)
- [x] One planet (Mireth, Cannery District) built from `data/surfaces.json`: spaceport + launch pad, mechanic,
      night market, old cannery (your rented rig), Consortium office, houses, roads, props
- [x] Existing economy migrated into buildings/NPCs: each door or person opens only its own panel
      (market → buy, cannery → lab, mechanic → ship upgrades, office → debt + fixer, Okka/Sen → deals with that person)
- [x] Ambient walkers on the roads, surface minimap, on-foot controls help
- [x] Stations without a surface (Cinder Belt, Drift Bazaar) keep the docked menu

## P2 – Living planets
- [ ] Art pass for the surface via the asset pipeline (tileset, character sprites with 4-direction walk cycles, building sprites)
- [ ] Building interiors as their own small instances (enter door → interior scene) instead of opening a panel at the door
- [ ] NPC schedules (home ↔ work ↔ plaza by time of day), day/night tint, idle chatter bubbles
- [ ] Customers on foot: NPCs who want product walk up to you; you deal with them directly (replaces part of the contacts menu)
- [x] Second and third surface: Drift Bazaar as a walkable hull deck (with the fence's back room), Cinder Belt as a mining camp

## P3 – Police on the ground
- [x] Reach Authority officers patrol the streets with vision cones; heat controls their number (shared with space heat), scaled per planet (`security`: Mireth 1, Cinder 0.5, Bazaar 0)
- [x] Carrying product in an officer's sight → frisk bar; at high heat they chase you; bust on foot = confiscation + fine (same core bust)
- [x] Officers path around buildings (AStarGrid2D on the tile grid, `scripts/planet/nav.gd`)
- [ ] Running away raises heat
- [ ] Curfew at night, hiding spots, bribable officers
- [ ] Planet heat zones: dealing in the plaza is hotter than in the back alleys

## P4 – Estates & production buildings
- [x] Core: properties per planet (price, size in grid cells), buy, ownership in the save (upkeep/selling later)
- [x] Estate instance: enter your property, grid placement mode (place/remove, no rotation yet) with a build menu [B]
- [x] Cook in your estate with the stations you placed (station minigames from the lab run on your own stations)
- [ ] Production buildings as core entities: grow tray (raws with growth time/quality), mixing station (the current lab,
      one per station), drying/packaging table, storage crate; each has its own input/output inventory
- [ ] The global "hydro rig" becomes the first rented estate; lab upgrades turn into building tiers
- [ ] Raids on estates when heat stays high
- [x] Station minigames (trim, scale, mixing, cook, packaging) decide yield, quality grade and heat; reusable runner
      for estate buildings (`scripts/ui/minigames/`)

## P5 – Workers & automation
- [ ] Hire workers at the job board (botanist, cook, handler) with daily wages
- [ ] Assign workers to buildings; simple job system moves items storage → station → storage
- [ ] Dealers: workers who sell product to customers on their own (with bust risk)
- [ ] Courier drones between estates and the spaceport

## P6 – Expansion & 1.0
- [ ] More planets with own laws, demand and security levels; jump lanes to a second system
- [ ] Rival syndicate with territory and price wars; ship classes
- [x] Menu system: main + pause menu, 3 save slots, settings (volumes, window mode/size, VSync, key rebinding)
- [ ] Tutorial contract chain, mixing journal, balance pass with long sims, localisation DE/EN

# Phase 2 – Deep systems & content (master prompt, Linus 2026-10-30)

Goal: replace flat menus with in-game systems in the spirit of Schedule 1 (own implementation), grow the universe,
add real combat. Pillars A–F follow the master prompt. Every milestone below is **one thread session** and **one or a
few small PRs** that each merge on their own with green CI. Versions stay 0.1.x: a patch release closes each wave.
Where a phase-2 milestone covers an older P-step, it replaces it (noted in brackets).

**Conflict hot spots** (two milestones touching the same one should not run at the same time):
`scripts/planet/surface.gd` (on-foot world), `scripts/world/world.gd` + `ship.gd` (flight), `scripts/ui/station_ui.gd`
(old panels), `data/surfaces.json`. `game.gd` and `content.json` are touched by almost everything, but in separate
functions/sections, so they rebase cleanly if each milestone puts its rules in its own core module (`scripts/core/<x>.gd`).
The phone registry (`scripts/ui/phone/registry.gd`) is one line per app and is safe to share.

### Wave 1 – foundations (all four can run in parallel)
- [x] **A1 Com-Phone + Contacts + named NPCs**. Phone overlay [Tab] in flight and on foot with a modular app
  framework (`scripts/ui/phone/`, one script per app, registry); Contacts app; core `people.gd`: every customer is a
  named person with preferred drugs, liked trait, daily budget, addiction, affinity, deal history and a schedule (data).
- **D1 Galaxy model + 2 new planets.** Systems in `content.json` (Halvane Reach + a second system), two new planets
  with own biome, security level and economy (demand, prices, police), walkable surfaces + space art. Travel between
  systems is a plain jump for now. Touches: content.json locations, surfaces.json, art.
- **C1 Lab stations II.** Extractor and Refiner as new stations with two new minigames (temperature balancing,
  reaction equilibrium) that set purity; purity joins the quality grade. Touches: minigames/, production.gd, stations.
- **E3 Visible ship upgrades.** Engine, hull, cargo, stealth (later weapons/shields) levels change the ship sprite
  (modular parts in the art pipeline). Touches: ship.gd, art only.
- → **Release v0.1.5** when wave 1 is merged.

### Wave 2 – the phone takes over trade (needs A1)
- **A2 Deal-O-Matic.** Customers text you requests (product, amount, price, place, time window) driven by addiction,
  budget and schedule; you accept, counter (haggling success depends on affinity) or decline; the deal is closed on
  foot at the agreed spot. Replaces the Deals panel for named customers (fence stays). Not parallel with B1 (surface.gd).
- **A3 Market & Orders app.** Order raws, additives and equipment from the phone with delivery time and fee; goods
  arrive in the stash or an estate. Market buildings stay as a cheaper walk-in option. Needs #14 (estates).
- **B2 Ship cargo bay estate.** The ship gets its own estate grid (machines, tables, crates, generator) that you can
  enter while docked; reuses estate_layout/build mode from #14. Parallel with A2/A3.
- **B1 NPCs on foot with schedules** [P2]. Revive draft PR #5 on top of A1: named people walk home ↔ work ↔ plaza by
  time of day, day/night tint, chatter; customers in the Contacts app can be found where their schedule says.
  Run after A2 or coordinate (both touch surface.gd).
- → **Release v0.1.6**.

### Wave 3 – logistics & automation (needs wave 2)
- **A4 DeadDrop Logistics.** Request anonymous drop points on planets/stations; customers or couriers pick up from
  them (less heat than hand-to-hand, small chance of theft). Needs A2 + A3.
- **B3 Workers & HR app** [P5]. Hire lab hands and stockers in the HR app (wage per day, skill, loyalty); assigned
  workers run stations in an estate and move items storage → station → storage. Needs #14, A1.
- **A5 Dealers & couriers** (HR app part 2) [P5]. Dealers sell to your customers on their own (cut, bust risk), couriers
  move goods between estates and drops. Needs A2, A4, B3.
- **A6 Galaxy Map app + Jump Drive.** Map app with heat overlay, price comparison per location and route planning;
  interstellar jump with charge-up, hyperspace VFX and loading transition. Needs D1, A1. Not parallel with E2 (world.gd).
- → **Release v0.1.7**.

### Wave 4 – combat & factions (mostly needs wave 1 only, but large)
- **E1 Ground combat.** Player health, twin-stick aiming (mouse), 2–3 weapons (pistol, SMG, shotgun), weapon wheel,
  cover objects on surfaces, officers can draw weapons at high heat. Not parallel with B1 (surface.gd).
- **E2 Space combat.** Hull + shield, lasers and missiles, dodge (boost), pirate ships that attack in deep space,
  weapon/shield modules at the mechanic (visible via E3). Not parallel with A6 (world.gd).
- **F1 Heat II + corruption.** Heat per system and personal "wanted" level; corrupt inspectors, customs officers and
  patrol captains as named NPCs (people.gd) you recruit with bribes: tip-offs before raids, cargo passes scanners.
  Replaces the office fixer bribe. Needs A1, D1.
- **D3 Interdiction.** Jumps can be intercepted by pirates or the Authority: fight (E2), pay, dump cargo or flee.
  Needs A6, E2.
- **F2 Rival gangs.** Cartels with territory per planet, robbing your dealers, demanding protection money, gang
  members as ground enemies. Needs E1, A5.
- **D4 Larger planet maps.** Bigger hand-made sectors per planet (districts, alleys, interiors), procedural filler
  props; minimap zoom. Run last among the surface.gd milestones.
- → **Release v0.1.8** (phase 2 complete).

### Dependency graph (short)
A1 → A2, A3, B1, B3, A6, F1 · #14 → A3, B2, B3 · A2 + A3 → A4 · A2 + A4 + B3 → A5 · D1 → A6, F1 · A6 + E2 → D3 ·
E1 + A5 → F2

## Carried over from the v0.1 roadmap (fold into the milestones above when they are picked up)
- Patrol feel in space: warning before scan range, asteroid fields to break pursuit, screen shake on bust
- Packaging tiers (shielded product survives a scan with a chance) → P4 packaging table
- Price board with per-location history → P2/P6
