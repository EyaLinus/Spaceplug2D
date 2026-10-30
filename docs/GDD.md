# Spaceplug 2D – Game Design (living document)

## Pitch
Top-down space smuggler. Start broke and in debt on a frontier hub, grow into the operator who runs product,
ships and labs across several star systems. Production/dealing sim at its core, flight and evasion as the moment-to-moment.

## Pillars
1. **Mixing is discovery** – additives transform traits; finding valuable chains is the puzzle.
2. **Logistics is gameplay** – distance, cargo space and patrol routes decide where you sell.
3. **Heat is the throttle** – greed raises heat, heat raises risk; the player decides how hot to run.
4. **Reinvest to scale** – every upgrade unlocks a new way to earn (later: workers, drones, more systems).

## Setting
The Halvane Reach, a frontier sector policed by the Reach Authority. Mireth (hub world, your rig),
Cinder Belt Outpost (mining camp, raws), Drift Bazaar (pirate market, fence), Customs Beacon K-7 (patrol base).
Lender: the Ouroboros Consortium. Products use real drug names (since v0.1.1, playtest feedback) so the strength ladder is obvious; traits and additives stay sci-fi.

## Systems in v0.1
- Drug ladder: T1 Weed (Cannabis Buds, base 40, heat ×1.0), T2 Cocaine (Coca Leaf, 62, ×1.3), T3 Meth (Pseudoephedrine, 95, ×1.7), T4 Fentanyl (Fentanyl Precursor, 150, ×2.4).
- Additives: Nanoflux, Ion Syrup, Static Pollen, Void Salt (transform table in `data/content.json`). Max 4 traits.
- Value = base × (1 + Σ trait values) × local demand × contact factor (liked trait +25 %, fence 70 %).
- Demand drops 3 % per unit sold, recovers 0.2 %/s; one random demand rumour per day.
- Heat 0–100, decays 0.25/s (half while docked). Patrols = 1 + heat/25 (max 5). Chase ≥ 30 heat.
  Scan radius 380 × (1 − stealth); 2.5 s in range with product = bust (product lost, 15 % fine, −40 heat).
- Day = 180 s. Debt 6,000 cr due end of day 12.

## Planned systems (see ROADMAP)
Growing your own raws (planting/harvest cycles), packaging tiers, hired runners and automated drones,
multiple star systems with jump lanes, raids on bases at high heat, customer network with loyalty and referrals,
rival syndicates, story contracts.
