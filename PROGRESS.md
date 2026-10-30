# Progress log

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
