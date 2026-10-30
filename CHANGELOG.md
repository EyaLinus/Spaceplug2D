# Changelog

## v0.1.5 – 2026-10-30
- **Visible ship upgrades:** every upgrade you buy at the mechanic now shows on your ship: engine nacelles with extra exhaust flames that burn hotter per level, cargo pods, dark stealth plating and a hydro rig dome. The shipyard shows a large preview of your current ship, and the parked ship on the landing pad changes too.
- **Lab II – Extractor and Refiner:** two new lab stations with their own minigames. The **Extractor** (weed, cocaine) has you ride a moving temperature profile on a chart recorder; the **Refiner** (cocaine, meth, fentanyl) has you hold a runaway reaction in equilibrium with delayed acid/base doses and a limited reagent supply. Both set the new **purity**, which counts half towards the quality grade, so a Pristine batch now needs a clean extraction or refinement too. The batch summary shows the purity.
- **Estates:** Extractor (450 cr) and Refiner (550 cr) can be built in estates. Existing estates need them before they can cook the drugs that use them.
- **Station art:** all seven lab stations now have pixel-art sprites inside estates, with smaller name tags.
- **Second star system:** fly to the Kovar Jump Gate at the edge of the Halvane Reach and jump (80 cr toll, a few seconds of travel time) into the **Kovar Expanse**. Each system has its own starfield, patrols and HUD name; saves remember which system you are in.
- **Varrow:** lawless desert world (almost no police on foot, thin patrols in the system), cheap Coca Leaf and Pseudoephedrine at the Saltpan Market, a fence in the Dust Cantina, hungry meth buyers, and the Dune Cellar estate (1,800 cr). New customers: Rhea Dunmore and Kip Sallow.
- **Glacis:** corporate ice colony with rich buyers (cocaine ×1.5, fentanyl ×1.4) but heavy security: more officers, a lot of heat per sale and Authority cutters in orbit. Dome Exchange sells additives, Cryo Vault 4 is a pricey estate (5,200 cr). New customers: Ivo Halden and Nadia Frost.
- **Com-Phone [Tab]:** a handheld with apps, usable in flight and on foot. First app: **Contacts** with every person you have met: mood (affinity), addiction, today's budget, favourite drugs, schedule and recent deals.
- **Named customers:** customers now have a job, a story, a daily budget and preferred drugs. Selling raises their addiction (stronger drugs faster) and their affinity (more with their favourite trait and good grades, less with Shoddy product); loyal and hooked customers pay and buy more. Four new people to meet: Teo Brack and Dr. Vesna Holt on Mireth, Marta Kell on Cinder, Ozzy Fenn on the Bazaar.

## v0.1.4 – 2026-10-30
- **Estates:** buy property on Mireth, the Cinder Belt or the Drift Bazaar, walk inside and set up production stations with the build menu (B). Once the stations a recipe needs stand, any of them opens the lab right there; missing stations are listed.
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
