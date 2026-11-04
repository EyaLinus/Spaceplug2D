# Progress log

## Release v0.1.12 (2026-11-03) – end of phase 3
- Phase 3 wave 10: K1 feedback + tooltips (#63), K2 customization / Style app (#65), K3 QoL (#66). Changelog folded,
  version 0.1.12. Phase 3 is closed. Still open from phase 3: C2 automation machines, escort missions (E4), building
  interiors (D4), a real balance pass (waits for Linus), Ninth Veil base quest (chapter 3), duplicate PRs #48 and #64.

## D4 leftover: building interiors (2026-11-04, wave 11)
- **Core** (`scripts/core/interiors.gd`, data in new `data/interiors.json`, merged as `data.interiors`): a surface building
  with a panel action (market, shipyard, office, fence) has a room when `interiors[loc][building]` exists. `build_cfg`
  returns a surface config like the estate layout: wall ring with an exit gap, a counter (4 tiles, opens the building's own
  panel), one clerk beside it (same panel), props, no police, no walkers, no cover, no day/night tint. 9 rooms: Mireth
  spaceport/market/office, Cinder depot, Bazaar hull market + back room, Varrow salt market + cantina, Glacis exchange.
  Estates keep their own entry; outdoor people (Rusk, Okka, ...) still open their panel in the street.
- **Surface/main**: `cfg.interior` marks a room. Door press (`_on_surface_action`) calls `enter_interior` instead of opening
  the panel; `exit_interior` -> `leave_interior` re-lands the planet and stands you at the door. `entered_building` event
  emitted. HUD quest waypoint inside a room points at the counter (building target) or the exit. New `counter` building style.
- **Verified** (Godot 4.3 headless): unit tests 11173 checks, 0 failures (new `test_interiors`: a room iff panel door, layout
  inside the room, counter clear of walls, spawn/exit/counter/clerk on free floor and connected, one clerk with the same
  panel, props inside); UI smoke 50 steps (every key building: door -> room, counter blocks walking, counter and clerk open
  the right panel, exit returns to the door; all five planets walked); tip audit `TIPS DONE 0`; menu smoke 6 steps;
  `tools/shot.gd` under Xvfb renders `interior_market` and it looks right.
- **Not verified / gaps**: not played by a human. The street is rebuilt on exit (NPCs and officers re-roll their positions,
  like leaving an estate). Interiors are not saved: a save made inside loads on the landing pad. Rooms are placeholder art
  (procedural counter, existing props); the clerks are anonymous and generic, named contacts still stand in the street.
  The balance sim was not run (no economy change).

## K3: QoL (phase 3 wave 10, 2026-11-03)
- **Autopilot** (`ship.gd`): action `ship_autopilot` (T) toggles; `goal_provider` = `hud.quest_point` (set in main);
  `autopilot_step()` turns to the goal, thrusts when within ~20°, brakes inside the stopping distance, switches off
  under 260 px or on any flight key. Only targets quest waypoints (no free map target yet).
- **Quick-save/-load**: actions `quick_save` (F5) / `quick_load` (F9) in `main.gd` (current slot; load is blocked
  while the interdiction card is up).
- **Hold-to-repeat**: `UI.is_stepper()` (+, −, -5, +10 …) → `UI.hold_to_repeat()`; the loop runs on the tree with a
  static press id, so it survives the screen rebuilding under the held button.
- **Contacts filter** (`contacts_app.gd` `filter`, `passes()`): all / here / buying / fans (affinity ≥ 0.25) /
  hooked (addiction ≥ 0.45).
- **Price compare** in market card tooltips (`station_ui._compare_tip`, from `Galaxy.buy_table`).
- **UI scale**: `Settings.ui_scale` → `UI_SCALES` [1.0, 1.1, 1.25]; main scales `_ui_root` and sizes it to
  viewport / scale (re-applied on Settings.changed and window resize).
- **Rebinding**: weapon_wheel, reload, ship_autopilot, quick_save, quick_load added to `Settings.BINDABLE`.
- **Blue sweep**: map app galaxy view navy → ink/brass/slate. Remaining blue = police uniforms and art fallbacks.
- Verified: unit tests, UI smoke 50 steps (+ autopilot flight, filter, quick-save round trip, 125 % UI), menu smoke,
  tip audit 0, sim 5/5 avg win day 4.6, screenshots.
- Gaps: autopilot ignores asteroids/patrols and only knows quest waypoints; no hand-placed map marker; no balance pass.

## K2: customization (phase 3 wave 10, 2026-11-03)
- **Core** `scripts/core/style.gd`, data `content.json` "style" (hair, skin, jacket, pants, paint, decal, decor; each
  item has name/cost, colour items a palette `ramp`). State `Game.style` {slot ids, owned ["cat:id"], decor [ids]},
  saved; old saves get the stock look. `buy` (pays, equips), `equip` (decor toggles), event `style_changed`.
- **Recolour**: `Art.recolored(rel, {Color: Color})` swaps exact palette colours of a texture (cached).
  `Style.player_swaps` maps the player sheet roles (hair_dark/hair, skin/skin_dark, gold ramp coat, blue_dark pants);
  `Style.hull_swaps` maps the gold hull ramp. Walker (`sheet`), ship (`paint`, `decal`), parked ship on the pad and the
  shipyard preview use them; `Art.draw_decal` draws decals between hull and top modules.
- **Decor**: `Style.decor_spots` fills free cells along the bottom row (right to left) then the right column, never on
  a station or the cell in front of it, the door or the stash. `EstateLayout.build_cfg(..., decor)` adds them as
  props tagged "decor"; the surface re-lays them on `style_changed`. New sprites assets/src/sprites/{plant,rug,sofa,
  neon,aquarium,trophy}.txt + icon app_style.
- **UI** `scripts/ui/phone/apps/style_app.gd`: character + ship preview, colour-swatch tiles (✓ = worn, price when
  not owned, disabled when too expensive), decor tiles with the prop sprite.
- Verified: unit test `test_style` (buy/afford/equip/toggle, swaps, decor spots for every estate, save round trip,
  junk ids, old saves), UI smoke +1 step (buy a jacket by tapping, walker recoloured, decor), tip audit 0, screenshots.
- Gaps: cosmetic only (no gameplay effect); decor can't be placed by hand; NPCs don't react to your outfit.

## K1: action feedback + tooltips (phase 3 wave 10, 2026-11-03)
- **Feedback layer** `scripts/ui/fx.gd` (HUD child, drawn last): watches credits/heat and pops the delta under the HUD
  stat, floats text over the player on game events (sold, loot, discoveries, referrals, batches), full-screen flashes
  (bust, wreck, interdiction, raid, upgrades, quest done), coin jingle for sales ≥ 400 cr. `scripts/world/float_text.gd`
  = world-space rising text (damage numbers in `combat_layer.gd` and `surface.gd`).
- **Shake**: new `EventBus.shake(strength)`; world and surface cameras both shake (surface had none), scaled by
  `Settings.screen_shake` (0..1, Display tab); `Settings.damage_numbers` toggle. Saved under [feel] in settings.cfg.
- **Toasts**: card per message (stripe colour = good/bad), max 5, same text again → "×n" on the last card.
- **Tooltips**: top bar stats (live text), phone tiles (`phone.gd APP_TIPS`), list rows in contacts/HR/fixers/deals,
  map modes/systems, settings rows; `UI.button` fills hover help from `UI.BUTTON_TIPS` (prefix match) unless the call
  site sets its own. `tools/tip_audit.gd` opens the main screens and lists visible buttons without a tooltip; CI fails
  unless it prints "TIPS DONE 0".
- Verified: 10559 unit checks, UI smoke +1 step (credit pop, toast stacking, surface shake, float text), menu smoke,
  tip audit 0 missing over 21 screens, screenshots.
- Gaps: deeper screens the audit does not open (product detail, HR worker detail, interdiction card) are only covered
  by the BUTTON_TIPS table; not played by a human.

## Release v0.1.11 (2026-11-03)
- Phase 3 wave 9: I1 cartels + sector influence (#59), E4 space combat II (#60), D3 interdiction + main quest
  chapter 2 (#61). Changelog folded, version 0.1.11. Next: wave 10 (K1 feedback & tooltips, K2 customization,
  K3 QoL, C2 automation machines) in a fresh thread. Escort missions from E4 are still open.

## D3: interdiction + main quest chapter 2 (phase 3 wave 9, 2026-11-03)
- **Core** `scripts/core/interdiction.gd`, data `content.json` "interdiction". `Game.jump` rolls on arrival with its own
  `Game.lane_rng` (game RNG untouched); from `min_day` 2. Authority: only with product aboard and heat ≥ chase heat.
  Cartels: present in the arrival system (home or ground), not weakened; chance from hostility, +bonus with product.
  Pending encounter in `Game.interdiction` (runtime only, not saved), events `interdicted` and
  `interdiction_resolved` {choice, kind, cartel, fight}. `resolve(g, choice)`: pay (toll base + per product unit /
  bribe base + heat × bribe rate, heat −30), dump (product only; cartel gains ground in the system / heat −20),
  flee (35 % + 12 % per engine level + hull speed; failing = 30 damage + fight), fight (units for the world;
  Authority fight +25 heat). Interceptor kills: no bounty, +15 heat.
- **UI** `scripts/ui/interdict_card.gd`: dimmed full-screen card (who, boss line, crew, four buttons with cost or
  chance, error line), opened deferred after the arrival; the game pauses, Esc does not open the pause menu over
  it. Fight spawns the wing 520 px ahead of the ship.
- **Main quest chapter 2** (`data/quests.json`, chained after Clean Slate): Turf War (turf_changed by you), Toll Road
  (interdiction_resolved), Smoke the Nest (base_raided comets, waypoint on the Nest), Cold Front (base_raided tide,
  waypoint routes over the gate). Win screen text updated.
- Verified: 10559 unit checks (chances, every choice for both kinds, jumps roll and stay off on day 1, chapter 2
  played through the core), UI smoke 46 steps (card, pause lock, pay, Authority fight spawns interceptors; random
  interdictions off in the smoke and screenshot scripts via min_day), screenshot `interdiction`.
- Gaps: numbers eyeballed; the Ninth Veil has no base quest yet (chapter 3); not played by a human.

## E4: space combat II (phase 3 wave 9, 2026-11-03)
- **Enemies** `space_combat.enemies` (fighter, gunship with `shots`/`fan_degrees`, interceptor for D3); pirate.gd
  is now the generic enemy (kind, cartel, tint, ion `stun`). Sprites ships/fighter.png, ships/gunship.png (neutral
  stone ramp, tinted with the cartel colour at runtime), space/loot.png.
- **Wings**: `SpaceCombat.pick_spawn` → a cartel present in the system sends its `wing` (content cartels.gangs.*.wing)
  with chance from hostility + system share (`space_combat.wings`), gunship from hostility 45, extra fighter from 70;
  weakened cartels send none. `enemy_down` pays the kind's bounty, counts kills, Cartels.on_kill, rolls loot and
  emits `pirate_down` {kind, cartel} (quests unchanged).
- **Loot**: `space_combat.loot` per kind (credits, missiles, a raw/additive/"product" = plain batch of a random drug);
  crates drift for 25 s, picked up within 46 px (`collect_loot`, hold and pods capped, event `loot`).
- **Secondaries**: upgrades `flak` (pellet cone, no ammo) and `ion` (stun in a blast radius, ×2 vs gunships and bases);
  `secondary` saved in combat state, K fires it, new action `ship_cycle` (Q, rebindable) switches. HUD shows it.
- **Cartel bases**: locations comet_nest (halvane), tide_rig, veil_spire (kovar), kind `cartel_base`, not dockable,
  space art `fortress()` in build_art.py. Within `aggro` they wake up (toast), fire 4 turrets, launch `defenders`
  once; hull is runtime (resets when you leave). Destroyed → `SpaceCombat.raid_base` (reward, loot, Cartels.on_raid,
  event `base_raided`). Weakened bases smoulder and stay quiet until rebuilt.
- **Ship classes** `ship_classes` (courier, runner, hauler, corvette: cargo/hull/shield/speed/laser multipliers,
  drawn scale and paint stripe). `Game.buy_ship` / `switch_ship` at a shipyard (hold must fit, hull damage carries
  over as a share), `ship_class` + `hulls` saved. Shipyard tab: "Hulls" cards, flak/ion cards.
- Verified: 10417 unit checks, UI smoke (wing spawn, flak kill, ion stun, loot pickup, HUD, base raid by a laser hit,
  shipyard cards), menu smoke, screenshots (space_wing, space_base_raid). Sim 8/8, avg win day 4.6 (bot never flies
  combat).
- Gaps: escort missions not built; numbers eyeballed; not played by a human; base hull resets when you leave.

## I1: enemy cartels + sector influence (phase 3 wave 9, 2026-11-03)
- **Core** `scripts/core/cartels.gd`, data `content.json` "cartels" (3 gangs: Black Comets/halvane, Saltglass
  Tide/kovar, Ninth Veil/kovar, with boss, colour, home, base id for E4, start hostility; start shares per trade
  location). State `Game.cartels` {influence {loc: {you, <cartel>: share}}, gangs {hostility, weakened, kills, raids},
  owner} (saved; old saves start from the defaults). Unclaimed street = 1 - sum.
- Ground moves: `gain()` (half from the street, the rest from the others in proportion), sales via the `sold` /
  `dealer_sold` events (Cartels.on_event in Game._emit), `on_kill` (cartel ship down in the current system),
  `on_raid` (base destroyed → weakened for N days). Daily: cartels push at home and where they already are (capped),
  your share erodes where you have no active dealer, hostility cools, dealers on cartel turf may be robbed
  (`dealer_robbed`). Owner = actor with ≥ 50 %, `turf_changed` event.
- Effects: `price_mult(loc)` = 1 ± 15 % by your share minus the top cartel's (in Game.sell_price, so contacts,
  fence and dealers all see it); `pressure_mult(sys)` scales the pirate spawn pressure (1.2 with no ground, 0.5 when
  you hold everything).
- **UI**: Map app third overlay "Influence" (system glow in the leading actor's colour, your system share bar,
  per-location turf / price / robbery line and a stacked share bar with tooltip), "Cartels" screen (boss, home, mood,
  hostility bar, ships downed, rebuilding). Toasts for turf changes and robberies.
- Verified: 10056 unit checks, UI smoke (influence overlay + cartel screen), screenshots. Sim 8/8 won, avg win day
  4.9 → 4.6 (the bot's sales build ground at Mireth/Bazaar → slightly better prices).
- Gaps: hostility does nothing visible yet (E4 wings, D3 interdictions use it); numbers eyeballed.

## Release v0.1.10 (2026-11-03)
- Phase 3 wave 8: D4 bigger planet maps with districts and landmarks (#55), B4 every person a named customer (#56).
  Changelog folded, version 0.1.10. Next: wave 9 (I1 cartels + sector influence, E4 space combat II, D3 interdiction)
  in a fresh thread.

## Release v0.1.9 (2026-11-03)
- Phase 3 wave 7: Q1 quest core + tutorial (#52), Q2 main quest chapter 1 (#53). Changelog folded, version 0.1.9.
  Next: wave 8 (D4 bigger planet maps, B4 every NPC a named person) in a fresh thread.

## Q2: main quest, chapter 1 (phase 3 wave 7, 2026-11-03)
- 7 missions in `data/quests.json` (`main: true, chapter: 1`), chained after the tutorial (and started by Skip tutorial
  or by loading a pre-quest save): The Collector (Mara Vesk, Ouroboros: pay 1,000 cr → +2 debt days), Room to Grow
  (second estate, 300 cr), Heavier Product (Coca Leaf at Cinder, cook Cocaine or stronger → 400 cr + Vesna), Out of
  Reach (Rhea Dunmore: jump to Kovar, land on Varrow → 300 cr), Desert Friends (sell 10 units to Rhea → 500 cr + Kip),
  Black Comets (3 raiders → 600 cr), Clean Slate (debt 0). Steps with an extra state check complete on their own
  when the condition already holds (old saves that paid down the debt).
- `pirate_down` and `ship_destroyed` now go through `Game._emit`, so quests see them. Win screen: "DEBT CLEARED ·
  CHAPTER 1 COMPLETE", button "Keep playing"; tracker tag "MAIN QUEST · CH.1".
- Verified: 2898 unit checks (whole chapter played through the core incl. jump routing of the waypoint), UI smoke,
  menu smoke. Gaps: the cartels are only story text until I1; numbers eyeballed; not played by a human.

## Q1: quest core + tutorial (phase 3 wave 7, 2026-11-03)
- **Core** `scripts/core/quests.gd`, quests in `data/quests.json` (merged into content as `quests`), state `Game.quests`
  {active, done, step, count, tracked} (saved). Steps complete on an event (`on` + `match` payload filter, `min`, `sum`,
  `need`) or a state check (`check`: cargo, credits, debt_max, estates, recipes, dealers, system, location, inside).
  Step `on_start` effects (force a customer text, hand out the additive for the tray), `retry_on` (expired or declined
  deal sends the quest back a step), rewards (credits, items, contacts met, extra debt days), `next` chains.
  `Game._emit` feeds every event to the quests; `Game.note()` lets the UI report `app_opened`, `entered_estate`,
  `landed`. New events: `tray_mixed`, `tray_step`; `lab_started` now carries `base` and `additives`.
- **Tutorial** (4 quests by Okka): buy 5 buds → enter the Old Cannery → start a tray → mix Ion Syrup (gifted) → finish
  the line → collect → open Products → set a price → accept Okka's forced request → hand it over at the meet → hire a
  dealer → stock them. Rewards 120/60/150(+Teo)/100 cr. Core `new_game` starts no quests (tests, bot and sims are
  unchanged); `GameState.new_game` starts them. Saves from before v0.1.9 count the tutorial as done.
- **UI** HUD tracker (`QuestTracker`, top left), giver message card (`QuestCard`, bottom centre, queued, click to
  dismiss), waypoint diamond / edge arrow and minimap ring (`hud.quest_point()`: market door, estate door, next
  station on the tray, stash crate, contact NPC, pad when on another planet, gate on the route when in another system),
  Quests app (first tile, Track buttons, Skip tutorial), Settings → Display → "Tutorial (new games)", quest sounds.
- Verified: 2825 unit checks (quest data references, full tutorial run through the core, retry on decline and no-show,
  check-steps that already hold, skip, save / old save / garbage save), UI smoke (tracker, card, waypoint on the
  market door, quest log, skip button), menu smoke, screenshots (surface with tracker + card, Quests app).
- Gaps: the tutorial has not been played through by a human; the deal step waits for Okka's meet time (6–16 game
  hours ≈ 45–120 s); if the player walks past the Mixing Station the mix step waits for the next batch.

## Release v0.1.8 (2026-11-03)
- Phase 3 wave 6: H1 Products app (#46), H2 deal appointments (#47), A5 dealers (#49). Changelog folded, version
  0.1.8. Next: wave 7 (Q1 quest core + tutorial, Q2 main quest act 1).

## H2: deal appointments (phase 3 wave 6, 2026-11-03)
- **Core** `deals.gd`: requests carry `product` (recipe key from your book, liked trait first; "" = any of the drug,
  `any_product_chance`), `meet_at` (total_time of a full hour 6–16 h ahead) and the schedule place at that hour.
  Price = your asking price when within their ceiling, else their offer + premium (capped at the ceiling while you
  have a price). `window()`: open from `early_hours` before, late after `grace_hours`, closes after `window_hours`
  (= expires_at once agreed). `fulfill` refuses too early, late = `affinity_late`, on time = `affinity_on_time`.
  `counter_qty` (fewer always ok, more by chance), `counter_time` (±h, chance from affinity); one haggle per kind
  (`haggled`). `meet_soon` event once `remind_hours` before. Clock helpers `clock_at/clock_text/hour_start`.
  Old saves: offers without `meet_at` keep the old timer. Dead drops bypass the meeting time.
- **UI**: Deal-O-Matic thread shows the meeting time and phase, Fewer/More/Earlier/Later buttons; phone home has a
  MEETINGS calendar strip (`Meet_<id>`), toasts for new requests with time and the reminder; the Deals panel on the
  surface shows the time and "(too early)".
- Verified: unit tests (appointments, haggles, named products), UI smoke (calendar), menu smoke, sim; screenshots.

## A5: dealers (phase 3 wave 6, 2026-11-03)
- **Core** `scripts/core/dealers.gd`, state `Game.dealers` [{id, loc, stock, cash, sold, jail}] (saved), candidates and
  numbers in content.json `dealers` (fee, cut, skill, bag capacity). `hire/fire/assign/give/take_back/collect`
  (stock and cash only in person, docked in the district). Every `sell_seconds` a dealer sells 1 + skill × 3 units of
  the best-paying product: `street_price` = your asking price if ≤ local value × demand × (1 + tolerance), Market =
  value × demand; they keep `cut`; demand saturates; heat in the current system. `bust_chance` from heat (also parked
  heat of other systems), location heat and skill: stock and cash lost, `jail_seconds`. Stops at `max_cash`.
- **UI** HR app: DEALERS section (`Dealer_<id>`, `DHire_<id>`), dealer screen with stats, bust risk, district buttons,
  bag, Collect, +5 / All from your hold, Take stock back, Let go. Toasts for bust / cash full / released.
  HR auto recipe menu now lists the mixes from the recipe book.
- Couriers between estates and drops were not built (DeadDrop couriers already move goods to the stash).
- Verified: unit tests (dealers, bust + save), UI smoke (hire, district, stock, collect), menu smoke, sim; screenshots.

## H1: Products app (phase 3 wave 6, 2026-11-03)
- **Core** `scripts/core/products.gd`: `Game.recipes` (recipe key without grade -> base, additives in order, made,
  best grade, first day) filled by `Products.discover` from `Game.queue_batch` and worker batches; old saves adopt
  carried products with an unknown recipe. `Game.prices` (recipe key -> cr per Standard unit, no entry = Market).
  `Game.unit_price(key, contact)` = their offer on Market, else your asking price × grade if it is within
  `ceiling` (offer × (1 + tolerance from affinity/addiction)), else -1 (refused). Bargains (≤ 90 % of offer) add
  affinity. The fence ignores your prices. Numbers in content.json `products`.
- **UI** `scripts/ui/phone/apps/products_app.gd` (icon `app_products`): list per drug with "???" for unknown drugs,
  detail with recipe steps, traits, estates that can cook it (`Game.missing_stations_in`), price editor (±1/5/25,
  Worth, Market), per-grade prices and every known buyer with offer / max. The Deals panel shows "won't pay N".
  Toast on a new product.
- Verified: unit tests (recipe book, asking price), UI smoke (price from the phone), menu smoke, sim; screenshots.

## Release v0.1.7 (2026-11-03)
- Phase 2 leftovers merged (A4 DeadDrops, E1 ground combat, E2 space combat, A6 galaxy map + jump drive, B3 workers,
  F1 heat II + corruption) plus phase 3 wave 5: G1 UI skin, G2 production on foot, G3 shop screens. Changelog folded,
  version 0.1.7. Next: wave 6 (H1 products app, H2 deal appointments, A5 dealers).

## G3: shop screens (phase 3, 2026-11-03)
- **Market:** item cards (icon, price, owned, tooltip with what the raw/additive is for via `UI.item_tip`), click +1 /
  Shift+click +5 into a basket (`station_ui._basket`, capped by credits and hold space), basket panel with −/+, total,
  credits and hold after, one gold "Buy" checkout. Hold shown as icon chips.
- **Shipyard:** one card per upgrade (current → next value, gold upgrade button `Up_<key>`, tooltip what it does),
  ship preview and credits on the left, mechanic below. **Build menu:** station cards with the station sprite, cost or
  kit count, footprint, stat and which drug lines use it. **Deals:** each buyer is a card, gold sell buttons.
- Verified: unit tests, UI smoke (basket + checkout, upgrade cards), menu smoke, sim; screenshots reviewed.
- Gaps: the office/estate-sale panels are only re-skinned (no card layout); market has no sell-back of raws.

## G2: lab on foot (phase 3, 2026-11-03)
- **No lab menu any more.** The Old Cannery door now enters `cannery_rig`, a starter estate (content.json `estates`,
  `"starter": true`, owned from day one, old saves get it on load) with all 7 stations bolted down (`fixed`, can't be
  taken down). Any estate works the same way.
- **Core** `scripts/core/bench.gd`, state `Game.bench` (estate id -> tray, saved): `begin` at the drug's prep station
  (raws leave the hold), optional `mix` at the Mixing Station (only after the pre-mix stations, before any later one;
  walking on past it means no additives), `record` each station's minigame score in line order, the last station calls
  `Game.queue_batch` (new; `start_batch` = check + consume + queue_batch). `abandon` puts raws/additives in the stash.
- **UI** `scripts/ui/bench_ui.gd` opens on [E] at a station: start (raw cards, units stepper), ingredient shelf
  (additive cards with tooltips, order, live trait/value preview), the station minigame, result; line strip with
  ✓/▶/± per station, Scrap tray, Take down for non-fixed stations. Estates got a stash crate (cook queue, stash,
  load into hold). The next station pulses gold on the floor (teal = optional mixing).
- `station_ui.gd` lost the Lab tab and the minigame runner; `minigame_runner.gd` stays for `effect_text()`.
- Verified: 2581 unit checks (new `test_bench_line`, `test_bench_mixing`, `test_bench_save`), UI smoke walks the
  cannery line with the minigame bots (start, extractor, shelf + pour, cook, pack), Esc/scrap/stash crate; menu smoke,
  sim; screenshots of the rig, start overlay, shelf, minigame, result and stash crate reviewed.
- Gaps: no hand-batch shortcut for players any more (workers automate, C2 machines later); the stash crate can be
  covered by a station placed in the bottom-left cell; the balance bot still uses the core quick batch.

## G1: UI skin (phase 3, 2026-11-03)
- **Art:** `build_ui()` in `tools/art/build_art.py` draws 14 bevelled 12×12 nine-patch frames (panel, inset, card,
  button states, gold accent button, tabs, tooltip, bar) from the art_profile palette → `assets/gfx/ui/*.png`.
- **Theme:** `ui_theme.gd` builds StyleBoxTexture frames (margin 8 px, flat fallback when a PNG is missing) for panels,
  popups, tooltips, buttons/option buttons, line edits/spin boxes, tabs, progress and scroll bars. Type variations
  `AccentButton`, `CardButton`, `Card`, `Inset` and helpers `UI.accent_button`, `UI.card`, `UI.heading` for the next
  milestones (G2 lab, G3 shops). Old blue hard-coded colours in UI scripts mapped to the palette; UI root draws nearest.
- Phase 3 plan in ROADMAP.md (waves 5–10). Also fixed `tools/shot.gd` crashing after the HR shots (surface rebuilt).
- Verified: unit tests, UI + menu smoke, sim, all screenshots reviewed (no blue panels left).

## B3: Workers & HR app (2026-10-30)
- **Core** `scripts/core/workers.gd` (state: `Game.workers` [{id, loyalty, estate, hired_day}] + per-estate `storage`,
  `bench`, `out`, `recipe`, `job`, all saved; old saves get empty defaults). Candidates and tuning are data in
  `content.json` -> `workers` (6 candidates: 3 lab hands, 3 stockers; max crew 6; signing fee = 2 days of wages).
- **Lab hand** cooks the estate's auto recipe when the stations for it stand: station scores = skill +/- noise through
  `Production.outcome` (same yield/grade/heat rules as the player), time = batch time x (1.3 - 0.5 skill), adds heat like a
  hand batch. **Stocker** trips every 8 s / (0.5 + skill) move up to 4 + 8 skill units: output tray -> shelf, shelf -> bench.
  Without a stocker the lab hand fetches from the shelf himself, 1.6x slower. One lab hand + one stocker per estate.
- **Wages** charged in `_new_day` (stats `wages`); can't pay = -0.3 loyalty and a missed-wage event, quits at 0; paid = +0.02.
- **HR app** (`scripts/ui/phone/apps/hr_app.gd`): crew, estates, candidates; worker profile (skill, loyalty, hire/fire,
  assign); estate screen (crew, recipe picker, batch size, job bar, shelf/bench/tray, stock raws / take products, only
  while standing inside). Badge = workers close to quitting.
- Verified: 1022 unit checks (new `test_workers`: hire/fire/assign rules, skill beats rookie on grade and speed, stocker
  speeds the line, wages, quitting, save round trip incl. mid-job, old save without worker data), UI smoke (hire, assign,
  recipe, stock, cook, take, wages through the real phone), menu smoke, sim 5/5 won avg day 6.2 (unchanged);
  screenshots `phone_hr*` in `tools/shot.gd` reviewed.
- Gaps: workers are invisible (no sprites walking the estate); auto recipe is plain (no additives picker, core supports
  them); loyalty has no gameplay beyond quitting (no theft/strikes, no raises); no skill growth or training; auto cooking
  ignores the shared lab queue and lab-level capacity of the hub; worker-cooked batches are not wired into the sim bot;
  estates cannot be sold, so assignment cleanup on removal is not needed yet; wage balance (15-110 cr/day) is eyeballed.
## A6: Galaxy Map app + Jump Drive (2026-11-02)
- **Core** `scripts/core/galaxy.gd`, one runtime field `Game.jump_plan` (not saved), one `Galaxy.tick` line in `Game.tick`.
  Lanes come from the gates of D1 (`jump_to`), `route()` is a breadth-first search (multi-hop works for any number of
  systems; tested with a synthetic third system). Overlays: `system_heat`/`heat_level`/`patrols_in` (one global heat scaled
  by the system's `patrol_mult`; F1 should replace `system_heat` with a per-system value), `location_risk` (sale heat,
  police density), `buy_table` (cheapest raws/additives per location), `sell_table` (plain-batch value per drug at
  today's saturated demand).
- **Jump drive:** jumps from anywhere in flight (the gate stays the instant, free-flying way). `Galaxy.start` plans the
  route and charges `jump.charge_seconds` (6 s, -10% per engine level, min 2.5 s) per hop; docking, a bust, a manual gate
  jump or the player cancel it. When charged, `jump_ready` makes main.gd call `Galaxy.engage`, which pays the toll for the
  hop and uses `Game.jump`; further hops start charging automatically. `content.json` -> `jump` got the new numbers.
- **UI:** phone app `apps/map_app.gd` (one line in `registry.gd`): map canvas with heat or price glow, tap a system for
  its locations (heat or goods), planned route with tolls/charge/travel, Charge/Cancel with a live bar, "Price comparison"
  screen (raws and additives cheapest first, drug demand best first). `scripts/ui/hyperspace.gd` is the VFX layer:
  streaks and a charge bar while charging, tunnel + loading card ("Hyperspace / Kovar Expanse") and fade after every
  jump (gate jumps use it too, replacing the old white flash). Two synth sounds (`jump_charge`, `jump`).
  `main.gd`: `jump()` split into `jump`/`_engage_drive`/`_arrive`.
- Verified: 1124 unit checks (new `test_galaxy_routes`, `test_galaxy_overlays`, `test_jump_drive`,
  `test_jump_drive_multi_hop`), UI smoke (overlays, route plan, price screens, charge, cancel, drive to Kovar and home with
  transition), menu smoke, sim 5/5 won (unchanged, 6.2 avg day), screenshots of map, price overlay, price comparison,
  charging and hyperspace reviewed.
- Gaps: map shows every system and price from the start (no exploration or stale prices), no price history; only two
  systems exist so multi-hop is only tested with synthetic data; the transition is cosmetic (state changes instantly
  under it); ship keeps flying while charging; world.gd/ship.gd untouched; bot/sim does not use the drive.

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

## F1: Heat II + corruption (2026-10-30)
- **Core:** new `scripts/core/corruption.gd` (rules in `content.json` -> `corruption`, six `officials`), official profiles and
  state helpers in `people.gd`. `Game.corruption` holds wanted level, parked heat of the other systems, official state,
  the announced/active sweep and a private roll counter (does not touch `g.rng`, so runs without corruption are unchanged).
  Game hooks are one-liners: `tick`, `_new_day`, `dock`, `jump`, `bust`, save, `patrol_count`/`police_on_foot`.
- **Heat per system:** `g.heat` stays "heat of the current system" (all old rules keep working); `jump` parks it and swaps
  in the destination's heat, parked heat cools down while you are away.
- **Wanted:** +14 per bust, -4 per day, adds `0.25 * wanted` to the heat patrols/officers react to in every system.
- **Sweeps:** a system at heat >= 60 may get a sweep the next day (50% per day, deterministic roll): +22 effective heat for
  that day. Captains tip you off the day before and can divert it (220 cr).
- **Officials:** known after docking where they work; `Corruption.recruit` (in person, pays the bribe), daily retainer,
  loyalty rises with retainer/favours, unpaid retainer drops loyalty and finally lapses them. Inspector: `bribe` and
  `clear_wanted`; customs: `bust()` may be waved through (pass chance = base * loyalty factor, halved at wanted >= 50);
  captain: tip-off and divert. `Game.bribe` now needs a hired inspector in the system (old office fixer removed).
- **UI:** Fixers phone app (`apps/officials_app.gd`: wanted stars, heat per system, officials, recruit/favour buttons),
  the Consortium office panel lists the same actions, `notice` game events become toasts in `main.gd`.
- **Bot:** recruits Inspector Vell the first time it wants to bribe.
- Verified: 1051 unit checks (new tests for data, per-system heat, wanted, recruiting/retainer, customs pass, sweep +
  tip-off + divert, save round trip incl. old saves), UI smoke (Fixers app recruit + favour), menu smoke, sim 12 runs x
  seeds 100 and 300: 12/12 won, avg win day 6.0 / 6.0 (main: 6.1 / 6.0); CI-size sim (5 runs) 5/5, 5.8 vs 6.2.
- Balance note: the bot is sensitive to bribe prices (a 25% inspector discount made it a day slower because it bribes
  more often), so `fix_discount` is 0; the inspector sells access, not a discount.
- Gaps: officials are only reachable in the phone/office (no walkable official NPCs, surface.gd untouched); estate
  raids do not exist yet, so tip-offs warn about sweeps only; the sweep is only an effective-heat bump (no extra story);
  wanted level not on the HUD; no dismiss action; Fixers app has no icon art (coloured tile).

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

## D4: Larger planet maps (2026-11-03, wave 8)
- **Data** (`data/surfaces.json`): every planet grew 2–3× (Mireth 50×34 → 84×56, Cinder 36×26 → 64×46, Bazaar 36×24 → 64×42,
  Varrow 44×30 → 76×50, Glacis 46×32 → 78×52). All old coordinates (buildings, doors, pad, spawn, spots, NPCs, cover) stay where
  they were, so quests, tutorial waypoints and old saves are untouched; the new districts were added to the east and south.
- New keys per surface: `districts` ([{name, rect}], they tile the whole map) and `areas` ([x, y, w, h, kind]). Kinds
  `water`, `pit`, `slag`, `void`, `chasm` are solid (`Nav.SOLID_AREAS`, nav grid + collision; bullets fly over them); `grass`, `sand`,
  `salt`, `ice`, `rubble`, `rail`, `deck`, `arena`, `dome` are paint. A road drawn over a gap between two solid areas is a bridge.
- 31 new decorative buildings with signs, ~40 new named spots (for people's schedules), more props and 4–5 new cover pieces per planet
  (`content.json` → `combat.cover`).
- **HUD:** minimap zoom (M: whole map, ×2, ×4 following the player, clipped), solid areas on the minimap, district label above it that
  lights up when you enter a new district. **Sprint** on Shift (×1.6). `sprint` and `map_zoom` are in the rebinding screen.
- Verified: unit tests (new `test_planet_districts`: size, districts tile the map, area kinds, solid areas off roads/buildings and solid in
  the nav grid, every spot reachable; existing reachability/cover/schedule tests pass on the bigger maps), UI smoke (canal blocks,
  bridge crosses, district label changes, M key zooms, sprint), menu smoke, sim 6/6 won. Screenshots of all five planets checked.
- Gaps: no interiors for key buildings (ROADMAP item left open); new buildings are decoration only; every planet still uses a
  two-by-two street grid, so the layouts differ by districts and landmarks more than by street shape.

## B4: Everyone is someone (2026-11-03, wave 8)
- **Core** `scripts/core/locals.gd`: `Data.load_all` appends generated townsfolk to `data.contacts` (flag `local`, ids
  `<planet>_local_<n>`). Rules and pools in `content.json` → `locals` (count per planet: Mireth 16, Cinder 11, Bazaar 14,
  Varrow 11, Glacis 13; first/last names and jobs per planet; budget 80–220, 1–3 units, `prefer_weights` so weed is the most common
  habit, tilted by the planet's demand; `referral_chance` 0.25). Seeded per planet, so every run and save sees the same people;
  saves only store their state in `Game.people` like any contact.
- Schedules: four parts of the day over four distinct spots of the planet (home at night), hours shifted per person so people are
  always walking somewhere. `People.spot` now nudges crowds into rows; `Nav.free_spot` falls back to the place spot if the nudge
  hits a wall (used by surface.gd and the test).
- **Surface:** `Locals.npcs_for` adds the locals to the surface npcs; anonymous walkers removed (officers still patrol the roads).
  Unmet locals show no name, only their job when you are close; the prompt reads "Talk to <job/name> · wants <drug>". Talking
  meets them (existing `met` toast) → Contacts app, Deal-O-Matic requests, Products "buyers you know".
- **Referrals:** a sale to a contact can reveal an unmet person on the same planet (`referral` event + toast).
- Bot: sells to at most 4 locals per stop (they have to be found on foot). Sim 8/8 won, avg win day 4.9 (was 6.0 before B4):
  more buyers make the debt easier. Eyeballed, left as is until a balance pass is asked for.
- Verified: unit tests (`test_locals`: count, determinism, unique names, demand-valid habits, schedules over real spots, meet,
  referral, save; schedule walkability for every local at every hour), UI smoke (all Mireth locals on the surface, no anonymous
  people, stranger shows job, prompt shows want, talking opens Deals and makes a contact, name appears), menu smoke, screenshot.
- Gaps: locals reuse the 8 NPC sprite looks (no per-planet outfits yet); no dialogue lines beyond the deal screen; the Contacts app
  grows long once you know many people (no search/filter yet, K3).
