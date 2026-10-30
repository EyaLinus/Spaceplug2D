# Spaceplug 2D

Top-down 2D space smuggling and production sim. You start on the hub world **Mireth** owing the
Ouroboros Consortium 6,000 credits. Buy raw Sporegel and Cryoshard, cook and mix them in your hydro rig,
sell the product to contacts across the sector and keep the Reach Authority patrols off your back.

> Genre-inspired by production/dealing sims such as *Schedule I*, but its own game: own setting,
> fictional sci-fi goods, own mixing rules, flight-based logistics and patrol scans.

**Download:** Windows builds are attached to [GitHub Releases](../../releases) (unsigned: Windows SmartScreen
shows "Windows protected your PC" → *More info* → *Run anyway*).

## Controls
| Key | Action |
|---|---|
| W / ↑ | Thrust |
| A D / ← → | Turn |
| S / ↓ | Brake |
| E / Space | Dock / undock (when in range) |
| Esc / P | Pause menu (save, sound, main menu) |

## Core loop (prototype v0.1)
1. **Buy** Sporegel (Mireth, cheaper at Cinder Belt) or Cryoshard (Cinder Belt) plus additives.
2. **Cook** in the Mireth lab: base + up to 3 additives. Each additive transforms existing traits and adds its own
   (e.g. Nanoflux turns *Glow* into *Radiant*). More valuable traits → higher price.
3. **Sell** to contacts (each loves one trait, pays a premium, has a cooldown) or to the Drift Bazaar fence.
   Every sale saturates local demand, which recovers over time.
4. **Heat** rises with cooking and selling (most at Mireth, least at the Bazaar). More heat → more patrols; above 30 they
   chase you. A patrol scan on a ship carrying product = **bust** (product confiscated + fine). Bribe the fixer to cool down.
5. **Reinvest** in cargo hold, engine, stealth plating and a bigger rig. Pay the debt before day 12 to win.

## Tech stack and why
**Godot 4.3 + GDScript**, GL Compatibility renderer.
- Excellent built-in 2D, tiny runtime, single `.exe` with embedded pack.
- Headless mode: unit tests, UI smoke tests and balance sims run in CI and in a cloud container without a GPU.
- One-command export to Windows from Linux CI (`barichello/godot-ci` image), so every release is built automatically.
- GDScript needs no extra runtime (.NET), keeps builds small and lets the project reach web/Android later.
- Alternatives considered: Phaser/TypeScript (needs Electron/Tauri for a desktop exe, heavier), Rust/Bevy
  (slow CI compile, cross-compiling to Windows is fiddly), Unity (no headless licence-free CI build in this setup).

## Architecture
```
scripts/core/       headless simulation, no Node dependencies (testable)
  game.gd           state + actions (buy, cook, sell, upgrade, bribe, bust, debt), tick(), save/load
  mixing.gd         recipe → traits → product key/value
  data.gd           loads data/content.json
scripts/autoload/   EventBus (signals), GameState (owns Game, relays events, save files), AudioManager (synth SFX)
scripts/world/      sector, ship physics, locations, patrols (spatial rules → core actions)
scripts/ui/         theme, HUD + minimap + nav arrows, station menu (Market/Lab/Deals/Shipyard/Office)
scripts/main.gd     state switching (menu, flight, docked, paused, end screen)
data/content.json   all content and balance numbers
tests/run_tests.gd  unit tests      tools/ui_smoke.gd  full-loop UI smoke   tools/sim.gd  balance bot
```
Rules: gameplay logic lives in `scripts/core` and gets a test; UI only reads state and calls actions; numbers live in
`data/content.json`; the UI talks to audio and other systems only through `EventBus`.

## Development
```bash
godot --headless --path . --import
godot --headless --path . -s res://tests/run_tests.gd        # unit tests
godot --headless --path . -s res://tools/ui_smoke.gd         # UI smoke over the whole loop
godot --headless --path . -s res://tools/sim.gd -- --runs 8  # balance bot metrics
xvfb-run godot --path . -s res://tools/shot.gd -- --out /tmp/shots   # screenshots
```
Release: Actions → *Test, build and release* → *Run workflow* with `release_tag` (e.g. `v0.1.0`).
Changelog entries go into `changelog.d/<topic>.md`; `python3 tools/changelog_collect.py --version vX.Y.Z` folds them in.

See [ROADMAP.md](ROADMAP.md), [PROGRESS.md](PROGRESS.md) and [docs/GDD.md](docs/GDD.md).
