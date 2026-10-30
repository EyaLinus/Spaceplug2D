# Art pipeline

All art is pixel art built from text sources with the game-assets-2d skill workflow. No external tools besides Python.

- **Style and palette:** `art_profile.yaml` (single source of truth; 37 named colours, 16-px art grid, exported 2x).
- **Sources:** `assets/src/sprites/*.txt` (hand-written pixel grids), `assets/src/characters.yaml` (colour swaps per
  character look), procedural tiles and building pieces in `tools/art/build_art.py`.
- **Build:** `pip install pillow pyyaml && python3 tools/art/build_art.py [--preview out.png]` writes `assets/gfx/**`.
  The PNGs are committed, so CI and Godot need no Python.
- **Registry:** `assets/manifest.yaml` lists every asset. In Godot, `scripts/core/art.gd` is the only place that knows
  file names: `Art.tex()`, `Art.draw_character()`, `Art.draw_prop()`, `Art.fill_tiles()`. Every getter returns null
  when a file is missing and the caller keeps its old procedural drawing, so new content works before it has art.
- **Godot settings:** the surface and ship nodes use `texture_filter = nearest`; the surface also sets
  `texture_repeat` because roof and wall pieces are tiled.
- **Buildings:** roof and wall pieces are neutral grey and tinted with the `wall`/`roof` colours from
  `data/surfaces.json`, so a new building needs no new art. Windows, doors and hatches are untinted.
- **Characters:** 3x3 sheet per look (rows down/up/right, columns idle/step A/step B; left = mirrored right).
  Named NPCs pick the `npc_*` look whose coat is closest to their data colour; walkers get a mix.

- **Space view:** planets, asteroid and station are procedural pixel art from `build_space()` (palette ramps + ordered
  dithering, light from top-left), one PNG per location id (`space/<id>.png`); beacon and patrol are grids.

Not covered yet: UI icons, building interiors, menu art.
