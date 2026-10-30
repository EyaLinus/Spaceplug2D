# Changelog

## v0.1.4 – 2026-10-30
- **Icons:** goods, additives, products, ship upgrades and the top bar (credits, day, heat, cargo) now show pixel-art icons.
- **Space in pixel art:** Mireth, the Cinder Belt asteroid, the Drift Bazaar ring station, the customs beacon and the patrol cutters are now pixel art too.
- **Smarter police:** officers chasing you now run around buildings instead of through them.
- **Pixel art:** the player, NPCs, officers, the ship, ground/road/plaza tiles for all three surfaces, buildings and props are now real 16-px pixel art instead of shapes. Each NPC keeps its colour; walkers come in eight looks.
- **Menus:** new main menu (Continue, New game, Load game, Settings, Quit) and pause menu (Esc) with Save game, Load game, Settings, Save & main menu and Save & quit. Keyboard navigation works without a mouse; Esc always goes one step back.
- **Save slots:** three save slots with day, credits, location and save time; overwriting and deleting ask once more on the same button. Your old save moves into slot 1 automatically. Closing the window mid-run saves too.
- **Settings:** master, music and effects volume; windowed/fullscreen, window size and VSync; rebind every key (flight, on foot, pause). Conflicting keys in the same group swap. On-screen key hints follow your bindings. Saved in settings.cfg.
- **Station minigames:** cook batches by hand at the Trim Table / Precursor Scale, Mixing Station, Cook Stove and Packaging Table. Your hands decide yield (±20 %), the quality grade (Shoddy to Pristine, up to ×1.4 value) and how much heat the batch draws. "Quick batch" keeps the old one-click Standard result.

## v0.1.3 – 2026-10-30
- **Police on foot:** Reach Authority officers walk the streets of Mireth (and the Cinder camp once you are hot). Carry product in their line of sight and they frisk you; at high heat they chase you. The Drift Bazaar has no police.
- **Walk the whole sector:** Cinder Belt (mining camp with the Ore Depot and Foreman Dax) and the Drift Bazaar (hull deck with the Hull Market, the fence in the Back Room, Lira and Old Grub) are now walkable like Mireth.

## v0.1.2 – 2026-10-30
- **Land on planets:** docking at Mireth now lands you on its surface. Walk around the Cannery District on foot (WASD/arrows), use doors and talk to people with E, take off again from the launch pad next to your ship.
- **Economy in the world:** the market, your cannery lab, the mechanic at the spaceport, the Consortium office and your contacts Okka and Sen are now places and people on Mireth instead of menu tabs.

## v0.1.1 – 2026-10-30
- **Controls:** Space brakes, S/↓ now fires reverse thrust (half power); docking is E only.
- **Drug ladder:** products renamed by strength – T1 Weed, T2 Cocaine, and new T3 Meth (Pseudoephedrine, Cinder Belt) and T4 Fentanyl (precursor at the Drift Bazaar). Higher tiers sell for more but cost more and bring up to 2.4× heat.
- **Saves:** v0.1.0 saves load with the new names.

## v0.1.0 – 2026-10-30
- **First playable prototype:** fly a ship around the Halvane Reach, dock at Mireth, Cinder Belt Outpost and Drift Bazaar.
- **Cook & mix:** two base products, four additives that transform and add traits, 13 traits with their own value.
- **Deals:** five contacts with favourite traits and cooldowns, a fence at the Bazaar, demand that saturates and recovers.
- **Heat & patrols:** heat from cooking and selling, more patrols as it rises, chase above 30 heat, scan → bust, bribes.
- **Progress:** cargo, engine, stealth and lab upgrades; pay off 6,000 cr debt by day 12 to win; save/continue.
- **Audio:** synthesized sound effects, engine rumble and ambient drone.
