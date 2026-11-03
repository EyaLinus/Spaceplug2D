# Changelog

## v0.1.9 – 2026-11-03
- **Main quest, chapter 1:** after the tutorial, seven missions around the Ouroboros debt: an installment for Mara Vesk (+2 days), a second estate, your first Cocaine batch, the jump to Kovar, ten units for Rhea Dunmore on Varrow, three Black Comet raiders shot down and the final payment. New contacts (Vesna, Kip) and credits as rewards. Paying the debt now ends chapter 1 instead of the game; old saves start straight into the main quest.
- **Quests and tutorial:** a quest system with a HUD tracker, a gold waypoint (on screen, at the screen edge and on the minimap), messages from the quest giver and a Quests app on the Com-Phone. New games start with Okka's four-part tutorial: buy buds, cook and mix a batch on foot in the Old Cannery, price it in the Products app, close a texted deal and hire a street dealer. It can be skipped in the Quests app or switched off in Settings.

## v0.1.8 – 2026-11-03
- **Deal appointments:** customers now text a concrete deal with the product (often one from your recipe book), amount, price and a meeting time on the clock at a place. Hand over from two hours before the meeting; late costs affinity, on time earns some, and after the window the deal is missed. Requests use your asking price when the customer accepts it.
- **Haggle on everything:** before you agree, haggle once each on price (+10/+25 %), amount (fewer or more) and time (2 h earlier or 3 h later).
- **Calendar:** the Com-Phone home screen lists today's meetings, and tapping one opens the conversation. You get a reminder an hour before each meeting.
- **Dealers:** hire street dealers in the HR app (one-off fee, then they keep a cut). Give them a district, hand them product in person, and they sell to the locals at your asking price while you're away. Collect the cash when you're back in their district. Heat raises their bust risk, skill lowers it, and a bust costs their stock and cash and puts them in jail for a while.
- **Auto recipes from your book:** the HR estate screen can now set a worker's auto recipe to any mix from the Products app, not only plain drugs.
- **Products app:** a recipe book on the Com-Phone. Every product you've cooked once, grouped by drug, with its recipe in mixing order, traits, best grade and the estates that can make it; drugs you never cooked show as "???".
- **Your own prices:** set an asking price per product (grades scale it) or leave it on Market. Customers pay your price if it is within what they'd pay (loyal and hooked customers tolerate more), refuse if it is too steep, and like you a bit more for a bargain. The product screen lists every buyer you know with their offer and limit.

## v0.1.7 – 2026-11-03
- **Shop screens:** markets now work with item cards and a shopping basket (one checkout, totals and hold space shown up front), the mechanic shows every ship upgrade as a card with what it changes, the build menu shows the station machines, and buyers in the Deals panel get their own cards. Hover anything for a tooltip.
- **Production on foot:** the lab menu is gone. The Old Cannery is now your first estate with a full production line: start a batch at the Trim Table or Precursor Scale, carry the tray from station to station and play each minigame, pick additives from an ingredient shelf with a live preview at the Mixing Station, then collect the product from the stash crate. The next station glows on the floor.
- **New UI look:** every menu, tab, list, phone screen and button now uses pixel-art frames in the game's own palette (dusk purple panels with brass rims, gold buttons for the main action) instead of the blue prototype boxes. Tooltips and scroll bars got the same style.
- **Heat per system and a wanted level:** Every star system keeps its own heat (it swaps in when you jump and the one you left cools down in the background). Busts raise a personal wanted level (0-100, decays daily) that adds to what patrols and officers react to everywhere. Hot systems can get an Authority sweep with extra patrols for a day.
- **Corrupt officials:** Six named officials (inspectors, customs officers, patrol captains) in Halvane and Kovar. Meet them by docking where they work, recruit them with a bribe and pay a daily retainer. Inspectors buy down heat and wanted, customs officers wave cargo through patrol scans and frisks, patrol captains tip you off a day before a sweep and can divert it.
- **Fixer replaced:** The Consortium office fixer is gone; heat can only be bought down through a hired inspector, from the new Fixers phone app or the office panel.
- **HR app & workers:** New HR app on the Com-Phone. Hire lab hands and stockers (wage per day, skill, loyalty), assign them to your estates and set an auto recipe. A lab hand cooks batches by himself at your stations (skill sets grade, yield and speed, heat still applies); a stocker hauls raws from the estate shelf to the bench and finished product back to storage. Stock raws and take products while standing inside the estate. Wages are charged every day; unpaid wages cost loyalty and people quit at zero. Old saves load fine.
- **Galaxy Map and Jump Drive:** new Com-Phone app "Map". See every star system and jump lane with a heat overlay (patrol pressure at your current heat) or a price overlay, tap a system for its locations (sale heat, police, goods), compare raw/additive prices and drug demand across all locations, and plan a route. The jump drive then charges (6 s, shorter with engine upgrades) and jumps from anywhere in flight, paying the gate toll per hop. Hyperspace streaks while charging and a hyperspace loading transition on every jump; docking, a bust or the Cancel button interrupt the charge.
- **Space combat:** pirate raiders now hunt you in deep space (far from any planet or station), more of them in lawless systems like the Kovar Expanse and when your hold is full of product. Shoot lasers (J), launch homing missiles (K) and dodge with a short invulnerable boost (Shift, costs boost energy). Your ship has hull and shield bars (bottom left); the shield recharges after a few quiet seconds and on docking, the hull is repaired for credits at the mechanic. Downed pirates pay a bounty. If your hull is gone the pirates loot half your hold, you pay a tow fine and respawn at half hull next to the system's patrol base.
- **Weapon and shield modules:** the shipyard sells Laser Cannons, Missile Pods, a Shield Generator and Hull Armour (three levels each). Every level shows on the ship as extra wing guns, missile pods, a shield ring and armour plates. New Mechanic section: repair hull, restock missiles. The key bindings are in the settings menu. Old saves start with an undamaged stock ship.
- **Ground combat (E1):** on planets you can aim with the mouse and shoot (left button; R reload; hold Q for the weapon wheel; 1/2/3 or mouse wheel to swap). Pistol is free, SMG (600 cr) and shotgun (900 cr) are bought in the wheel. You have 100 HP that regenerates after a few quiet seconds; at 0 you are knocked out (product confiscated, fine, back at your ship). Low cover (barriers and crates) stands along the streets of every planet and stops bullets. Officers draw their weapons at heat 55 or when shot at, stop to fire and can be shot down (extra heat). Saves are backward compatible.
- **DeadDrop app:** request anonymous drop points on planets, stations and outposts. Leave an agreed Deal-O-Matic deal there (30 % of the heat, customer collects and pays later, small theft risk) or send goods to your hub stash by courier.

## v0.1.6 – 2026-11-02
- **Living planets:** named people follow their daily schedule on foot (work, market, cantina, home …) and walk there when the hour changes; they stop when you walk up to them. Planets now have a day/night light, and a day starts at 06:00.
- **Ship cargo bay:** Your ship now has its own estate grid. While docked, take the ramp next to the landing pad (or the "Cargo Bay" tab on stations without a surface) to enter the bay, place lab stations and cook there, even where there is no lab. Closed in flight; old saves get an empty bay.
- **Deal-O-Matic (Com-Phone app):** customers you know text you requests (drug, amount, price with a 15 % premium). Accept, haggle (+10 % / +25 %, odds shown, better with loyal or hooked customers) or decline. Agreed deals are handed over in person: the customer gets a gold $ marker, talk to them and press Hand over. Missing the meet or a failed haggle costs affinity.
- **Market & Orders app:** new Com-Phone app. Order cannabis, coca leaf, precursors, additives and flat-packed station kits (15% cheaper than building on site, placed for free in build mode) from anywhere (flight or on foot), pay cost plus a delivery fee (standard or express), and the goods arrive after a countdown in the hub stash or in an estate you own; collect them inside the estate. Open orders can be cancelled (goods refunded, fee lost). Walk-in markets stay cheaper.
- **Fix:** The station window's Undock/Leave button now shows the current key binding instead of a hardcoded [E].

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
