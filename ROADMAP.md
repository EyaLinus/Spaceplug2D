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
- [x] Running away raises heat (chase adds up to +12 heat)
- [ ] Curfew at night, hiding spots, bribable officers
- [ ] Planet heat zones: dealing in the plaza is hotter than in the back alleys

## P4 – Estates & production buildings
- [ ] Core: properties per planet (price, size in grid cells, upkeep), buy/sell, ownership in the save
- [ ] Estate instance: enter your property, grid placement mode (place/rotate/remove) with a build menu
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

## Carried over from the v0.1 roadmap (fold into the milestones above when they are picked up)
- Patrol feel in space: warning before scan range, asteroid fields to break pursuit, screen shake on bust
- Packaging tiers (shielded product survives a scan with a chance) → P4 packaging table
- Price board with per-location history → P2/P6
