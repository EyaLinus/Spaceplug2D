#!/usr/bin/env python3
"""Builds every PNG in assets/gfx from the sources in assets/src and art_profile.yaml.

    python3 tools/art/build_art.py            # rebuild all
    python3 tools/art/build_art.py --preview build/art_preview.png   # also write a contact sheet

Sources:
  assets/src/sprites/*.txt   hand-written pixel grids (game-assets-2d pixelart format)
  assets/src/stations/*.txt  lab station machines (estate interiors), sized to the buildable footprint
  assets/src/icons/*.txt     UI icons (items, upgrades, HUD), same grid format
  assets/src/characters.yaml role-letter -> palette swaps for the char_* grids
  this file                  procedural tiles, building pieces and UI nine-patch frames (palette-locked)

Everything is drawn on a 16 px art grid and written pre-scaled by grid.pixel_art.scale (2),
so Godot draws the textures 1:1 with texture_filter = nearest.
Needs: pip install pillow pyyaml
"""
from __future__ import annotations

import argparse
import random
from pathlib import Path

import yaml
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "src"
OUT = ROOT / "assets" / "gfx"

PROFILE = yaml.safe_load((ROOT / "art_profile.yaml").read_text())
PAL = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) + (255,) for k, v in PROFILE["palette"].items()}
SCALE = int(PROFILE["grid"]["pixel_art"]["scale"])
T = int(PROFILE["grid"]["pixel_art"]["tile_px"])
CLEAR = (0, 0, 0, 0)


# ---------------------------------------------------------------- pixel grids

def parse_grid(path: Path) -> tuple[dict, list[list[str]]]:
    legend, frames, cur, mode = {}, [], [], "head"
    for raw in path.read_text().splitlines():
        line = raw.rstrip()
        s = line.strip()
        if mode != "grid":
            if not s or s.startswith("#"):
                continue
            if s.lower() == "legend:":
                mode = "legend"
            elif s == "---":
                mode = "grid"
            elif mode == "legend":
                ch, _, val = s.partition("=")
                legend[ch.strip()] = val.split("#")[0].strip()
            continue
        if s == "===":
            frames.append(cur)
            cur = []
        elif s:
            cur.append(line)
    if cur:
        frames.append(cur)
    return legend, frames


def color(name: str) -> tuple:
    if name == "transparent":
        return CLEAR
    if name not in PAL:
        raise SystemExit(f"color '{name}' is not in the art_profile palette")
    return PAL[name]


def grid_image(rows: list[str], legend: dict) -> Image.Image:
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), CLEAR)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            img.putpixel((x, y), color(legend.get(ch, "transparent")))
    return img


def up(img: Image.Image) -> Image.Image:
    return img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)


def save(img: Image.Image, rel: str) -> Path:
    p = OUT / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    up(img).save(p)
    return p


# ---------------------------------------------------------------- characters

def build_characters() -> list[Path]:
    """One 3x3 sheet per look: rows down/up/right, columns idle/stepA/stepB."""
    looks = yaml.safe_load((SRC / "characters.yaml").read_text())
    dirs = [parse_grid(SRC / "sprites" / f"char_{d}.txt") for d in ("down", "up", "right")]
    out = []
    for look, roles in looks.items():
        sheet = Image.new("RGBA", (T * 3, T * 3), CLEAR)
        for row, (legend, frames) in enumerate(dirs):
            lg = dict(legend)
            lg.update(roles)
            for col, frame in enumerate(frames[:3]):
                sheet.paste(grid_image(frame, lg), (col * T, row * T))
        out.append(save(sheet, f"chars/{look}.png"))
    return out


def build_sprites() -> list[Path]:
    out = []
    for name, folder in [("crate", "props"), ("barrel", "props"), ("rock", "props"), ("tree", "props"),
                         ("lamp", "props"), ("vent", "props"), ("stall", "props"), ("cactus", "props"), ("ice_rock", "props"), ("ship", "ships"),
                         ("patrol", "ships"), ("pirate", "ships"), ("fighter", "ships"), ("gunship", "ships"), ("loot", "space"), ("beacon", "space"),
                         ("plant", "props"), ("rug", "props"), ("sofa", "props"), ("neon", "props"), ("aquarium", "props"), ("trophy", "props"),
                         ("roof_vent", "buildings"), ("roof_skylight", "buildings"), ("roof_chimney", "buildings"), ("roof_dish", "buildings"),
                         ("window_shut", "buildings"), ("window_dark", "buildings")]:
        legend, frames = parse_grid(SRC / "sprites" / f"{name}.txt")
        out.append(save(grid_image(frames[0], legend), f"{folder}/{name}.png"))
    return out


def build_stations() -> list[Path]:
    """Lab station machines for estate interiors: one grid per station id, sized to its buildable footprint."""
    out = []
    for src in sorted((SRC / "stations").glob("*.txt")):
        legend, frames = parse_grid(src)
        out.append(save(grid_image(frames[0], legend), f"stations/{src.stem}.png"))
    return out


SHIP_MODULES = ("engine", "cargo", "stealth", "lab", "hull", "laser", "missile", "shield")


def build_ship_modules() -> list[Path]:
    """Upgrade modules for the player ship: ship_<key>.txt holds one 24x24 frame per upgrade level (Mk2..Mk4),
    aligned to the 16x16 hull at offset 4,4. Written as ships/mod_<key>_<level>.png (48 px); level 0 has none.
    ship_composite() renders a full loadout for review (unused by the game, which layers the PNGs itself)."""
    out = []
    for key in SHIP_MODULES:
        legend, frames = parse_grid(SRC / "sprites" / f"ship_{key}.txt")
        for lvl, frame in enumerate(frames, start=1):
            out.append(save(grid_image(frame, legend), f"ships/mod_{key}_{lvl}.png"))
    return out


def ship_composite(levels: dict) -> Image.Image:
    """Hull plus modules in draw order (engine, cargo under the hull; stealth, lab over it), unscaled."""
    legend, frames = parse_grid(SRC / "sprites" / "ship.txt")
    img = Image.new("RGBA", (24, 24), CLEAR)
    mods = {k: parse_grid(SRC / "sprites" / f"ship_{k}.txt") for k in SHIP_MODULES}
    def layer(k):
        lvl = levels.get(k, 0)
        if lvl > 0:
            lg, fr = mods[k]
            m = grid_image(fr[lvl - 1], lg)
            img.alpha_composite(m)
    layer("hull"); layer("engine"); layer("cargo")
    img.alpha_composite(grid_image(frames[0], legend), (4, 4))
    layer("stealth"); layer("lab"); layer("laser"); layer("missile"); layer("shield")
    return img


def build_icons() -> list[Path]:
    """UI icons: 16 px grids in assets/src/icons, one PNG each (32 px)."""
    out = []
    for src in sorted((SRC / "icons").glob("*.txt")):
        legend, frames = parse_grid(src)
        out.append(save(grid_image(frames[0], legend), f"icons/{src.stem}.png"))
    return out


# ---------------------------------------------------------------- procedural tiles

def strip(tiles: list[Image.Image]) -> Image.Image:
    img = Image.new("RGBA", (T * len(tiles), T), CLEAR)
    for i, t in enumerate(tiles):
        img.paste(t, (i * T, 0))
    return img


def speckle(base: str, specks: list[tuple[str, float]], seed: int, tufts: str | None = None) -> Image.Image:
    r = random.Random(seed)
    img = Image.new("RGBA", (T, T), color(base))
    for name, chance in specks:
        for y in range(T):
            for x in range(T):
                if r.random() < chance:
                    img.putpixel((x, y), color(name))
    if tufts:
        for _ in range(r.randint(0, 2)):
            x, y = r.randint(1, T - 3), r.randint(2, T - 2)
            for dx, dy in ((0, 0), (1, -1), (2, 0)):
                img.putpixel((x + dx, y + dy), color(tufts))
    return img


def plates(base: str, seam: str, rivet: str, hi: str, seed: int, split: bool) -> Image.Image:
    """Metal deck plate: dark seams on the bottom/right edge, light edge top/left, rivets in the corners."""
    r = random.Random(seed)
    img = Image.new("RGBA", (T, T), color(base))
    for i in range(T):
        img.putpixel((i, T - 1), color(seam))
        img.putpixel((T - 1, i), color(seam))
        img.putpixel((i, 0), color(hi))
        img.putpixel((0, i), color(hi))
    if split:
        for i in range(1, T - 1):
            img.putpixel((i, T // 2 - 1), color(seam))
            img.putpixel((i, T // 2), color(hi))
    for x, y in ((2, 2), (T - 3, 2), (2, T - 3), (T - 3, T - 3)):
        img.putpixel((x, y), color(rivet))
    for _ in range(3):
        img.putpixel((r.randint(2, T - 3), r.randint(2, T - 3)), color(seam))
    return img


def paving(base: str, seam: str, hi: str, seed: int) -> Image.Image:
    """Stone slabs in a running bond, 8x8 art px."""
    r = random.Random(seed)
    img = Image.new("RGBA", (T, T), color(base))
    for y in range(T):
        off = 4 if (y // 8) % 2 else 0
        for x in range(T):
            if y % 8 == 7 or (x + off) % 8 == 7:
                img.putpixel((x, y), color(seam))
            elif y % 8 == 0:
                img.putpixel((x, y), color(hi))
            elif r.random() < 0.03:
                img.putpixel((x, y), color(seam))
    return img


def grate(base: str, bar: str, hi: str) -> Image.Image:
    img = Image.new("RGBA", (T, T), color(base))
    for y in range(T):
        for x in range(T):
            if x % 4 == 0:
                img.putpixel((x, y), color(bar))
            if x % 4 == 1:
                img.putpixel((x, y), color(hi))
            if y == T - 1:
                img.putpixel((x, y), color(bar))
    return img



def stamp(img: Image.Image, x: int, y: int, rows: list[str], legend: dict[str, str]) -> Image.Image:
    """Pastes a small ascii grid (legend: char -> palette name, '.' = keep) onto a copy of the tile at x, y."""
    img = img.copy()
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch in legend and 0 <= x + dx < T and 0 <= y + dy < T:
                img.putpixel((x + dx, y + dy), color(legend[ch]))
    return img


def feature(base: Image.Image, spots: list[tuple[int, int, list[str]]], legend: dict[str, str]) -> Image.Image:
    for x, y, rows in spots:
        base = stamp(base, x, y, rows, legend)
    return base


def rand_cells(seed: int, n: int, margin: int = 2) -> list[tuple[int, int]]:
    r = random.Random(seed)
    return [(r.randint(margin, T - margin - 3), r.randint(margin, T - margin - 3)) for _ in range(n)]


def ground_with_features(base_fn, plain_seeds: list[int], features: list) -> Image.Image:
    """4 plain variants (the common tiles) followed by len(features) rarer feature tiles; art.gd picks feature tiles ~14% of cells."""
    tiles = [base_fn(s) for s in plain_seeds]
    for i, fn in enumerate(features):
        tiles.append(fn(base_fn(plain_seeds[i % len(plain_seeds)] + 7)))
    return strip(tiles)


def area_tiles(base: str, specks: list[tuple[str, float]], seed: int, detail) -> Image.Image:
    return strip([detail(speckle(base, specks, seed + s), seed + s) for s in range(4)])


def build_tiles() -> list[Path]:
    out = []

    def f(spots, legend):
        return lambda t: feature(t, spots, legend)

    def caution(t):  # warning-stripe corner on a deck plate
        t = t.copy()
        for y in range(T - 5, T - 1):
            for x in range(T):
                t.putpixel((x, y), color("gold_dark" if (x + y) % 6 < 3 else "night"))
        return t

    flower = {"p": "pink", "g": "gold", "l": "leaf"}
    pebble = {"S": "slate_light", "s": "slate", "d": "slate_dark"}
    sets = {
        "mireth": {
            "ground": ground_with_features(
                lambda s: speckle("grass", [("grass_dark", 0.06), ("grass_light", 0.025)], s, "grass_light" if s % 2 else "leaf"), list(range(4)), [
                    f([(3, 4, ["p", "l"]), (10, 9, ["g", "l"]), (6, 12, ["p", "l"]), (12, 3, ["g", "l"])], flower),
                    f([(2, 3, ["Ss.", "sdd"]), (9, 10, [".Ss", "sdd"])], pebble),
                    f([(3, 5, ["l.lL", "LlLl", ".lL."]), (9, 10, ["lLl", ".l."])], {"l": "leaf", "L": "grass_light"}),
                    f([(4, 6, [".rr.", "rwrr", ".ww."]), (10, 4, [".rr", "rwr", ".w."])], {"r": "red", "w": "white"}),
                ]),
            "road": strip([speckle("slate_dark", [("shadow", 0.05), ("slate", 0.015)], 10 + s) for s in range(4)]),
            "plaza": strip([paving("slate", "slate_dark", "slate_light", 20 + s) for s in range(4)]),
        },
        "cinder": {
            "ground": ground_with_features(
                lambda s: speckle("dirt", [("dirt_dark", 0.07), ("rust", 0.02)], 30 + s, "rust" if s % 2 else None), list(range(4)), [
                    f([(3, 4, [".dd.", "dGgd", ".dd."]), (10, 10, ["dd", "gd"])], {"d": "dirt_dark", "g": "gold_dark", "G": "gold"}),
                    f([(2, 3, ["dd......", "..d.....", "...dd...", ".....d..", "......dd"])], {"d": "dirt_dark"}),
                    f([(3, 5, ["..ss..", ".ssss.", "sssss.", ".ss..."]), (10, 10, ["ss", "s."])], {"s": "slate_dark"}),
                    f([(3, 4, ["SS", "ss"]), (10, 9, ["S.", "ss"]), (6, 12, ["SS", ".s"])], {"S": "slate_light", "s": "slate"}),
                ]),
            "road": strip([speckle("rust", [("dirt", 0.08), ("rust_light", 0.02), ("dirt_dark", 0.02)], 40 + s) for s in range(4)]),
            "plaza": strip([plates("slate", "slate_dark", "shadow", "slate_light", 50 + s, s % 2 == 0) for s in range(4)]),
        },
        "bazaar": {
            "ground": ground_with_features(
                lambda s: plates("shadow", "night", "slate_dark", "purple_dark", 60 + s, s % 2 == 0), list(range(4)), [
                    f([(4, 4, ["nnnnnnnn", "nssssssn", "nsggggsn", "nsgnngsn", "nsgnngsn", "nsggggsn", "nssssssn", "nnnnnnnn"])],
                      {"n": "night", "s": "slate_dark", "g": "gold_dark"}),
                    f([(0, 6, ["pppppp..........", "......pppp......", ".........ppppppp"])], {"p": "purple"}),
                    f([(4, 5, ["..nn..", ".nnnn.", "nniinn", ".nnnn."])], {"n": "night", "i": "ink"}),
                    caution,
                ]),
            "road": strip([grate("purple_dark", "night", "purple") for _ in range(4)]),
            "plaza": strip([plates("slate_dark", "night", "slate", "slate", 70 + s, s % 2 == 1) for s in range(4)]),
        },
        "varrow": {  # desert dust town
            "ground": ground_with_features(
                lambda s: speckle("sand", [("rust_light", 0.07), ("wood", 0.02)], 80 + s, "rust_light" if s % 2 else None), list(range(4)), [
                    f([(3, 4, ["Rr.", "rrw"]), (10, 10, [".Rr", "rwr"])], {"R": "rust_light", "r": "rust", "w": "wood"}),
                    f([(2, 3, ["dd......", "..d.....", "...dd...", ".....d..", "......dd"])], {"d": "wood"}),
                    f([(4, 4, ["..w.w..", ".wWwWw.", "wWwWwWw", ".w.w.w.", "...w..."])], {"w": "wood_dark", "W": "wood"}),
                    f([(4, 6, ["WW..WW", "wWWWWw", "WW..WW"])], {"W": "white", "w": "stone"}),
                ]),
            "road": strip([speckle("wood", [("wood_dark", 0.07), ("rust_light", 0.03)], 90 + s) for s in range(4)]),
            "plaza": strip([paving("rust_light", "rust", "sand", 100 + s) for s in range(4)]),
        },
        "glacis": {  # ice colony
            "ground": ground_with_features(
                lambda s: speckle("stone", [("white", 0.08), ("slate_light", 0.03), ("blue_light", 0.012)], 110 + s), list(range(4)), [
                    f([(2, 2, ["cc......", ".cd.....", "..cc....", "....cd..", ".....cc.", "......cc"])], {"c": "slate", "d": "slate_light"}),
                    f([(3, 4, ["..WW..", ".WWWW.", "WWbWWW", ".WWWW."]), (10, 10, ["WW", "Wb"])], {"W": "white", "b": "blue_light"}),
                    f([(5, 3, ["..b..", ".bwb.", "bBwBb", ".bBb.", "..b.."])], {"b": "blue_light", "B": "blue", "w": "white"}),
                    f([(2, 5, ["..WWWW..", "WW....WW"]), (6, 11, ["..WWWW..", "WW....WW"])], {"W": "white"}),
                ]),
            "road": strip([plates("slate", "slate_dark", "shadow", "slate_light", 120 + s, s % 2 == 0) for s in range(4)]),
            "plaza": strip([paving("slate_light", "slate", "white", 130 + s) for s in range(4)]),
        },
    }
    for biome, kinds in sets.items():
        for kind, img in kinds.items():
            out.append(save(img, f"tiles/{biome}_{kind}.png"))

    # ground paint for surfaces.json "areas" (lawns, dunes, salt flats, ice sheets, rubble); biome neutral, opaque
    def lawn(t, seed):
        for x, y in rand_cells(seed, 3):
            t = stamp(t, x, y, ["p" if seed % 3 == 0 else "g", "l"], {"p": "pink", "g": "gold", "l": "leaf"})
        return t

    def dunes(t, seed):
        return feature(t, [(x, y, ["..RRR..", "RR...RR"]) for x, y in rand_cells(seed, 2, 1)], {"R": "rust_light"})

    def crust(t, seed):
        return feature(t, [(x, y, ["cc.", ".cc", "..c"]) for x, y in rand_cells(seed, 2)], {"c": "slate_light"})

    def sheen(t, seed):
        return feature(t, [(x, y, ["W", ".W", "..W"]) for x, y in rand_cells(seed, 3)], {"W": "white"})

    def stones(t, seed):
        return feature(t, [(x, y, ["Ss", "sd"]) for x, y in rand_cells(seed, 3)], {"S": "slate_light", "s": "slate", "d": "slate_dark"})

    areas = {
        "grass": area_tiles("grass_light", [("leaf", 0.07), ("grass", 0.06)], 200, lawn),
        "sand": area_tiles("sand", [("rust_light", 0.04), ("white", 0.01)], 210, dunes),
        "salt": area_tiles("white", [("stone", 0.08), ("slate_light", 0.02)], 220, crust),
        "ice": area_tiles("blue_light", [("white", 0.06), ("blue", 0.04)], 230, sheen),
        "rubble": area_tiles("dirt_dark", [("dirt", 0.1), ("rust", 0.02)], 240, stones),
    }
    for kind, img in areas.items():
        out.append(save(img, f"tiles/area_{kind}.png"))
    return out


# ---------------------------------------------------------------- building pieces (tinted at runtime)

def build_building_parts() -> list[Path]:
    out = []
    # roof: corrugated sheet, ridges every 4 px; neutral so the building's roof colour can tint it
    roof = Image.new("RGBA", (T, T), color("stone"))
    for y in range(T):
        for x in range(T):
            m = x % 4
            img_c = "white" if m == 0 else ("stone" if m in (1, 2) else "slate_light")
            if y == T - 1:
                img_c = "slate_light"
            roof.putpixel((x, y), color(img_c))
    out.append(save(roof, "buildings/roof.png"))
    # wall: panels with vertical seams every 8 px and a darker kick plate at the bottom
    wall = Image.new("RGBA", (T, T), color("stone"))
    for y in range(T):
        for x in range(T):
            c = "stone"
            if x % 8 == 7:
                c = "slate_light"
            if x % 8 == 0:
                c = "white"
            if y >= T - 3:
                c = "slate_light" if y < T - 1 else "slate"
            wall.putpixel((x, y), color(c))
    out.append(save(wall, "buildings/wall.png"))
    # facade variants, picked per building at runtime so one street does not repeat the same roof and wall
    def piece(fn) -> Image.Image:
        img = Image.new("RGBA", (T, T), color("stone"))
        for y in range(T):
            for x in range(T):
                img.putpixel((x, y), color(fn(x, y)))
        return img

    def shingles(x, y):  # overlapping rows, seams offset every other row
        if y % 4 == 3:
            return "slate_light"
        if (x + (y // 4 % 2) * 4) % 8 == 7:
            return "slate_light"
        return "white" if y % 4 == 0 else "stone"

    def panels(x, y):  # standing-seam plates with corner rivets
        if x % 8 == 7 or y % 8 == 7:
            return "slate_light"
        if x % 8 == 0 or y % 8 == 0:
            return "white"
        return "slate" if (x % 8, y % 8) in ((2, 2), (5, 2), (2, 5), (5, 5)) else "stone"

    def kick(y):
        return ("slate_light" if y < T - 1 else "slate") if y >= T - 3 else None

    def brick(x, y):
        if kick(y):
            return kick(y)
        if y % 4 == 3 or (x + (y // 4 % 2) * 4) % 8 == 7:
            return "slate_light"
        return "white" if y % 4 == 0 and x % 8 < 2 else "stone"

    def planks(x, y):
        if kick(y):
            return kick(y)
        if x % 4 == 3:
            return "slate_light"
        if x % 4 == 0:
            return "white"
        return "slate_light" if (x, y) in ((6, 4), (6, 5), (13, 9), (2, 8)) else "stone"

    out.append(save(piece(shingles), "buildings/roof_b.png"))
    out.append(save(piece(panels), "buildings/roof_c.png"))
    out.append(save(piece(brick), "buildings/wall_b.png"))
    out.append(save(piece(planks), "buildings/wall_c.png"))
    # door awning, 24x8 art px, neutral stripes tinted with the building's roof colour at runtime
    awning = Image.new("RGBA", (24, 8), CLEAR)
    for x in range(24):
        stripe = "white" if (x // 4) % 2 == 0 else "slate_light"
        for y in range(7):
            if y < 5 or x % 4 in (1, 2) or y == 5:
                awning.putpixel((x, y), color(stripe))
        awning.putpixel((x, 0), color("stone"))
        awning.putpixel((x, 7 if x % 4 in (1, 2) else 5), color("slate"))
    out.append(save(awning, "buildings/awning.png"))
    legend = {".": "transparent", "k": "ink", "y": "gold", "Y": "gold_light", "d": "gold_dark", "n": "night", "t": "teal",
              "s": "slate", "S": "slate_light"}
    window = [
        "................",
        "................",
        "...kkkkkkkkkk...",
        "...kYYYYkyyyk...",
        "...kYYyykyyyk...",
        "...kYyyykyydk...",
        "...kkkkkkkkkk...",
        "...kyyyykyddk...",
        "...kyyydkdddk...",
        "...kkkkkkkkkk...",
        "..kSSSSSSSSSSk..",
        "..kkkkkkkkkkkk..",
        "................",
        "................",
        "................",
        "................",
    ]
    out.append(save(grid_image(window, legend), "buildings/window.png"))
    door = [
        "..kkkkkkkkkkkk..",
        "..kSSSSSSSSSSk..",
        "..kSkkkkkkkkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSknnnnnnkSk..",
        "..kSkyyyyyykSk..",
        "..kkkkkkkkkkkk..",
        "................",
    ]
    out.append(save(grid_image(door, legend), "buildings/door.png"))
    hatch = [
        "................",
        "..kkkkkkkkkkkk..",
        "..kyyyyyyyyyyk..",
        "..kyknnnnnnkyk..",
        "..kynnttnnnnyk..",
        "..kynnnnttnnyk..",
        "..kynnnnnnttyk..",
        "..kytnnnnnnnyk..",
        "..kyknnnnnnkyk..",
        "..kyyyyyyyyyyk..",
        "..kkkkkkkkkkkk..",
        "..ksssssssssk...",
        "................",
        "................",
        "................",
        "................",
    ]
    hatch[11] = "..kssssssssssk.."
    out.append(save(grid_image(hatch, legend), "buildings/hatch.png"))
    return out


# ---------------------------------------------------------------- space view (procedural bodies)

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
LIGHT = (-0.55, -0.6, 0.58)  # top-left, towards the viewer


def value_noise(seed: int, cells: int):
    r = random.Random(seed)
    g = [[r.random() for _ in range(cells + 1)] for _ in range(cells + 1)]

    def f(u: float, v: float) -> float:  # u, v in 0..1
        x, y = u * cells, v * cells
        x0, y0 = min(int(x), cells - 1), min(int(y), cells - 1)
        tx, ty = x - x0, y - y0
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0][x0] + (g[y0][x0 + 1] - g[y0][x0]) * tx
        b = g[y0 + 1][x0] + (g[y0 + 1][x0 + 1] - g[y0 + 1][x0]) * tx
        return a + (b - a) * ty
    return f


def fbm(seed: int):
    layers = [value_noise(seed + i, c) for i, c in enumerate((4, 8, 16))]
    return lambda u, v: sum(l(u, v) * w for l, w in zip(layers, (0.55, 0.3, 0.15)))


def shade(ramp: list[str], light: float, x: int, y: int) -> str:
    """Pick a ramp step from 0..1 light with ordered dithering between steps (palette-locked shading)."""
    t = max(0.0, min(0.999, light)) * (len(ramp) - 1)
    i = int(t)
    if t - i > (BAYER[y % 4][x % 4] + 0.5) / 16.0 and i + 1 < len(ramp):
        i += 1
    return ramp[i]


def sphere(d: int, x: int, y: int, squash=lambda a: 1.0):
    """Normal and light at pixel x, y of a d-wide disc, or None outside."""
    import math
    cx = cy = (d - 1) / 2.0
    nx, ny = (x - cx) / (d / 2.0), (y - cy) / (d / 2.0)
    rr = nx * nx + ny * ny
    edge = squash(math.atan2(ny, nx))
    if rr > edge * edge:
        return None
    nz = math.sqrt(max(0.0, 1 - rr))
    l = nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2]
    return nx, ny, nz, l


def planet(d: int, seed: int, ocean: list[str], land: list[str], night: str) -> Image.Image:
    n = fbm(seed)
    img = Image.new("RGBA", (d, d), CLEAR)
    for y in range(d):
        for x in range(d):
            s = sphere(d, x, y)
            if s is None:
                continue
            nx, ny, nz, l = s
            h = n(x / d, y / d)
            ramp = land if h > 0.52 else ocean
            light = 0.15 + 0.85 * max(0.0, l)
            c = shade(ramp, light, x, y) if l > -0.05 else night
            if l > -0.05 and l < 0.12 and BAYER[y % 4][x % 4] < 8:
                c = night
            img.putpixel((x, y), color(c))
    return img


def asteroid(d: int, seed: int, ramp: list[str]) -> Image.Image:
    import math
    lump = value_noise(seed, 12)
    n = fbm(seed + 5)
    r = random.Random(seed)
    craters = [(r.uniform(0.2, 0.8) * d, r.uniform(0.25, 0.85) * d, r.uniform(0.05, 0.11) * d) for _ in range(6)]
    img = Image.new("RGBA", (d, d), CLEAR)
    squash = lambda a: 0.78 + 0.22 * lump((a + math.pi) / (2 * math.pi), 0.5)
    for y in range(d):
        for x in range(d):
            s = sphere(d, x, y, squash)
            if s is None:
                continue
            l = s[3] + (n(x / d, y / d) - 0.5) * 0.5
            for cx, cy, cr in craters:
                dd = math.hypot(x - cx, y - cy)
                if dd < cr:
                    l = l - 0.35 if (x - cx) + (y - cy) < 0 else l + 0.1
            img.putpixel((x, y), color(shade(ramp, 0.1 + 0.8 * max(0.0, l), x, y)))
    # outline pass: ink on transparent neighbours
    out = img.copy()
    for y in range(d):
        for x in range(d):
            if img.getpixel((x, y))[3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if not (0 <= xx < d and 0 <= yy < d) or img.getpixel((xx, yy))[3] == 0:
                    out.putpixel((x, y), color("ink"))
                    break
    return out


def station(d: int, accent: str) -> Image.Image:
    """Ring station seen from above: segmented ring, four spokes, hub; lit windows on the ring."""
    import math
    img = Image.new("RGBA", (d, d), CLEAR)
    c = (d - 1) / 2.0
    R = d / 2.0
    for y in range(d):
        for x in range(d):
            dx, dy = x - c, y - c
            dist = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            seg = int((ang + math.pi) / (2 * math.pi) * 24)
            lit = 0.5 + 0.5 * (-(dx * 0.6 + dy * 0.7) / max(dist, 1))
            col = None
            if R * 0.72 <= dist < R - 0.5:
                if dist >= R - 1.5 or dist < R * 0.72 + 1:
                    col = "ink"
                elif abs(((ang + math.pi) / (2 * math.pi) * 24) - seg - 0.5) > 0.44:
                    col = "slate_dark"
                elif abs(dist - R * 0.86) < 0.8 and seg % 2 == 0:
                    col = "gold_light"
                else:
                    col = shade(["slate_dark", "slate", "slate_light", "stone"], lit, x, y)
            elif dist < R * 0.24:
                col = "ink" if dist >= R * 0.24 - 1.2 else (accent if dist < R * 0.1 else shade(["slate", "slate_light", "stone"], lit, x, y))
            elif dist < R * 0.72:
                for k in range(4):
                    a = k * math.pi / 2 + math.pi / 4
                    px = -math.sin(a) * dx + math.cos(a) * dy
                    along = math.cos(a) * dx + math.sin(a) * dy
                    if abs(px) < 2.2 and along > 0:
                        col = "ink" if abs(px) > 1.2 else "slate_light"
            if col:
                img.putpixel((x, y), color(col))
    return img


def fortress(d: int, accent: str) -> Image.Image:
    """Cartel base seen from above: armoured octagon hull, four turret blisters, a glowing core in the cartel accent."""
    import math
    img = Image.new("RGBA", (d, d), CLEAR)
    c = (d - 1) / 2.0
    R = d / 2.0
    for y in range(d):
        for x in range(d):
            dx, dy = x - c, y - c
            oct_d = max(abs(dx), abs(dy), (abs(dx) + abs(dy)) / 1.35)
            dist = math.hypot(dx, dy)
            lit = 0.5 + 0.5 * (-(dx * 0.6 + dy * 0.7) / max(dist, 1))
            col = None
            for k in range(4):  # turret blisters on the diagonals
                a = k * math.pi / 2 + math.pi / 4
                tx, ty = c + math.cos(a) * R * 0.72, c + math.sin(a) * R * 0.72
                td = math.hypot(x - tx, y - ty)
                if td < R * 0.2:
                    col = "ink" if td >= R * 0.2 - 1.2 else ("red" if td < R * 0.07 else shade(["slate_dark", "slate", "slate_light"], lit, x, y))
            if col is None and oct_d < R * 0.78:
                if oct_d >= R * 0.78 - 1.3:
                    col = "ink"
                elif dist < R * 0.22:
                    col = "ink" if dist >= R * 0.22 - 1.2 else (accent if dist < R * 0.14 else "white")
                elif abs(oct_d - R * 0.5) < 0.8:
                    col = "slate_dark"
                elif (int(dx + 64) // 5 + int(dy + 64) // 5) % 2 == 0 and oct_d > R * 0.5:
                    col = shade(["slate_dark", "slate", "slate_light"], lit, x, y)
                else:
                    col = shade(["ink", "slate_dark", "slate", "slate_light"], lit, x, y)
            if col:
                img.putpixel((x, y), color(col))
    return img


def gate(d: int) -> Image.Image:
    """Jump gate seen from above: thick segmented ring with four clamps and teal emitters on the inner edge."""
    import math
    img = Image.new("RGBA", (d, d), CLEAR)
    c = (d - 1) / 2.0
    R = d / 2.0
    for y in range(d):
        for x in range(d):
            dx, dy = x - c, y - c
            dist = math.hypot(dx, dy)
            ang = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)
            lit = 0.5 + 0.5 * (-(dx * 0.6 + dy * 0.7) / max(dist, 1))
            col = None
            clamp = min(abs(ang * 4 - round(ang * 4)), 1) < 0.045
            outer = R - 0.5 + (2 if clamp else 0) - 2
            if R * 0.62 <= dist < outer:
                if dist >= outer - 1 or dist < R * 0.62 + 1:
                    col = "ink"
                elif abs(dist - R * 0.66) < 1 and int(ang * 32) % 2 == 0:
                    col = "teal"
                elif clamp:
                    col = shade(["gold_dark", "gold", "gold_light"], lit, x, y)
                else:
                    col = shade(["slate_dark", "slate", "slate_light", "stone"], lit, x, y)
            if col:
                img.putpixel((x, y), color(col))
    return img


def build_space() -> list[Path]:
    out = []
    out.append(save(planet(170, 7, ["blue_dark", "blue", "blue_light"], ["grass_dark", "grass", "grass_light", "leaf"], "night"), "space/mireth.png"))
    out.append(save(asteroid(90, 11, ["dirt_dark", "dirt", "rust", "rust_light"]), "space/cinder.png"))
    out.append(save(station(70, "purple"), "space/bazaar.png"))
    out.append(save(planet(150, 23, ["dirt_dark", "rust", "rust_light"], ["rust_light", "sand", "gold_light"], "night"), "space/varrow.png"))
    out.append(save(planet(160, 31, ["slate_light", "stone", "white"], ["blue", "blue_light", "stone"], "night"), "space/glacis.png"))  # ice sheet, blue melt lakes
    for loc, accent in (("comet_nest", "rust_light"), ("tide_rig", "blue_light"), ("veil_spire", "purple")):  # cartel bases (E4)
        out.append(save(fortress(64, accent), f"space/{loc}.png"))
    for g in ("halvane_gate", "kovar_gate"):  # one gate design, one file per location id (registry rule)
        out.append(save(gate(60), f"space/{g}.png"))
    return out


# ---------------------------------------------------------------- art pass 4: fx, idle frames, ground edges, starfield

def build_fx() -> list[Path]:
    """Combat effects from sprites/fx_*.txt and the starfield sprites: all frames side by side in one strip each
    (fx/<name>.png, space/stars.png). Single-frame files are one sprite pointing right; Godot rotates them."""
    out = []
    for src in sorted((SRC / "sprites").glob("fx_*.txt")):
        legend, frames = parse_grid(src)
        w, h = max(len(r) for r in frames[0]), len(frames[0])
        sheet = Image.new("RGBA", (w * len(frames), h), CLEAR)
        for i, f in enumerate(frames):
            sheet.paste(grid_image(f, legend), (i * w, 0))
        out.append(save(sheet, f"fx/{src.stem[3:]}.png"))
    legend, frames = parse_grid(SRC / "sprites" / "stars.txt")
    sheet = Image.new("RGBA", (8 * len(frames), 8), CLEAR)
    for i, f in enumerate(frames):
        sheet.paste(grid_image(f, legend), (i * 8, 0))
    out.append(save(sheet, "space/stars.png"))
    out.append(save(nebula_strip(3, 48), "space/nebula.png"))
    return out


def nebula_strip(n: int, d: int) -> Image.Image:
    """n neutral gas clouds (d art px each): dithered fbm density with a radial falloff, stone ramp so the game can
    tint each cloud with the system's nebula colour. Transparent where the gas is thin."""
    import math
    ramp = ["slate_dark", "slate", "slate_light", "stone"]
    sheet = Image.new("RGBA", (d * n, d), CLEAR)
    for i in range(n):
        f = fbm(200 + i * 7)
        for y in range(d):
            for x in range(d):
                r = math.hypot(x - (d - 1) / 2, y - (d - 1) / 2) / (d / 2)
                v = f(x / d, y / d) * 1.5 - r * 1.1
                if v <= 0.05 + 0.35 * (BAYER[y % 4][x % 4] / 15.0) * 0.5:
                    continue
                sheet.putpixel((i * d + x, y), color(shade(ramp, min(1.0, v * 1.4), x, y)))
    return sheet


IDLE_FRAMES = 4  # stand, breathe (head and shoulders 1 px lower), stand, blink


def build_idle() -> list[Path]:
    """chars/<look>_idle.png: 4 idle frames x 3 facings (down/up/right) derived from the walk sheet's idle frame."""
    looks = yaml.safe_load((SRC / "characters.yaml").read_text())
    dirs = [parse_grid(SRC / "sprites" / f"char_{d}.txt") for d in ("down", "up", "right")]
    out = []
    for look, roles in looks.items():
        sheet = Image.new("RGBA", (T * IDLE_FRAMES, T * 3), CLEAR)
        for row, (legend, frames) in enumerate(dirs):
            lg = dict(legend)
            lg.update(roles)
            base = frames[0]
            breathe = ["." * len(base[0])] + base[0:8] + base[9:]
            blink = [r.replace("E", "S") for r in base]
            for col, fr in enumerate((base, breathe, base, blink)):
                sheet.paste(grid_image(fr, lg), (col * T, row * T))
        out.append(save(sheet, f"chars/{look}_idle.png"))
    return out


def build_edges() -> list[Path]:
    """tiles/<set>_edge.png: 8 fringe tiles (N, E, S, W, NE, SE, SW, NW) drawn over a road or plaza tile where the
    ground starts on that side (corners = ground only diagonal). The fringe reuses the ground tile's own pixels,
    so it matches every set. Run after build_tiles()."""
    out = []
    for gp in sorted((OUT / "tiles").glob("*_ground.png")):
        ground = Image.open(gp).convert("RGBA").resize((T * 4, T), Image.NEAREST)
        ground = ground.crop((0, 0, T, T))  # first ground variant at art scale
        name = gp.name.replace("_ground", "_edge")
        r = random.Random(sum(map(ord, name)))

        def fringe(side: str) -> Image.Image:
            img = Image.new("RGBA", (T, T), CLEAR)
            for i in range(T):
                d = 1 + sum(r.random() < p for p in (0.9, 0.6, 0.3, 0.1))  # 1..5 px deep, ragged
                for k in range(d):
                    x, y = {"N": (i, k), "S": (i, T - 1 - k), "W": (k, i), "E": (T - 1 - k, i)}[side]
                    img.putpixel((x, y), ground.getpixel((x, y)))
            return img

        tiles = [fringe(side) for side in "NESW"]
        for cx, cy in ((1, 0), (1, 1), (0, 1), (0, 0)):  # NE, SE, SW, NW
            img = Image.new("RGBA", (T, T), CLEAR)
            for dy in range(5):
                for dx in range(5):
                    if dx + dy < 4 + (r.random() < 0.4) - (r.random() < 0.3):
                        x, y = (T - 1 - dx if cx else dx), (T - 1 - dy if cy else dy)
                        img.putpixel((x, y), ground.getpixel((x, y)))
            tiles.append(img)
        out.append(save(strip(tiles), f"tiles/{name}"))
    return out


def contact_sheet(paths: list[Path], dest: Path) -> None:
    pad, scale = 8, 2
    imgs = [Image.open(p) for p in paths]
    w = sum(i.width * scale + pad for i in imgs) + pad
    cols, rows, x, y, rh = [], [], pad, pad, 0
    # simple shelf packing into ~1000 px wide rows
    placed = []
    for im in imgs:
        iw, ih = im.width * scale, im.height * scale
        if x + iw > 1000:
            x, y, rh = pad, y + rh + pad, 0
        placed.append((im, x, y))
        x += iw + pad
        rh = max(rh, ih)
    sheet = Image.new("RGBA", (1000 + pad, y + rh + pad), PAL["night"])
    for im, px, py in placed:
        sheet.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST), (px, py))
    dest.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(dest)


# ---------------------------------------------------------------- UI frames (nine-patch)

def frame(w: int, h: int, fill: str, hi: str, lo: str, outline: str = "ink", ring: str | None = None,
          rivet: str | None = None, sunken: bool = False) -> Image.Image:
    """A bevelled pixel frame for a StyleBoxTexture: outline, optional coloured ring, light top-left (or bottom-right
    when sunken), fill, optional rivets in the corners. Corners stay inside a 4 art px margin."""
    img = Image.new("RGBA", (w, h), color(fill))
    px = img.putpixel
    for x in range(w):
        px((x, 0), color(outline))
        px((x, h - 1), color(outline))
    for y in range(h):
        px((0, y), color(outline))
        px((w - 1, y), color(outline))
    o = 1
    if ring:
        for x in range(1, w - 1):
            px((x, 1), color(ring))
            px((x, h - 2), color(ring))
        for y in range(1, h - 1):
            px((1, y), color(ring))
            px((w - 2, y), color(ring))
        o = 2
    a, b = (lo, hi) if sunken else (hi, lo)
    for x in range(o, w - o):
        px((x, o), color(a))
        px((x, h - 1 - o), color(b))
    for y in range(o, h - o):
        px((o, y), color(a))
        px((w - 1 - o, y), color(b))
    # cut the outer corners so frames read as chunky pixel boxes, not rectangles
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        px((cx, cy), CLEAR)
    if rivet:
        for cx, cy in ((o + 1, o + 1), (w - o - 2, o + 1), (o + 1, h - o - 2), (w - o - 2, h - o - 2)):
            px((cx, cy), color(rivet))
    return img


def build_ui() -> list[Path]:
    """Nine-patch frames for the UI theme (scripts/ui/ui_theme.gd), 12x12 art px, margin 4 art px (= 8 px in game)."""
    specs = {
        "panel": dict(fill="night", hi="shadow", lo="ink", ring="gold_dark", rivet="gold"),
        "inset": dict(fill="ink", hi="shadow", lo="night", sunken=True, outline="shadow"),
        "card": dict(fill="shadow", hi="slate_dark", lo="night"),
        "card_hover": dict(fill="shadow", hi="slate_dark", lo="night", outline="gold_dark"),
        "button": dict(fill="purple_dark", hi="purple", lo="ink"),
        "button_hover": dict(fill="purple", hi="pink", lo="purple_dark", outline="gold_dark"),
        "button_pressed": dict(fill="teal_dark", hi="ink", lo="teal", sunken=True),
        "button_disabled": dict(fill="night", hi="shadow", lo="night", outline="shadow"),
        "button_accent": dict(fill="gold_dark", hi="gold", lo="wood_dark"),
        "button_accent_hover": dict(fill="gold", hi="gold_light", lo="gold_dark", outline="wood_dark"),
        "tab": dict(fill="ink", hi="night", lo="ink", outline="shadow"),
        "tab_selected": dict(fill="shadow", hi="gold_dark", lo="night", ring=None),
        "tooltip": dict(fill="ink", hi="night", lo="ink", outline="gold_dark"),
        "bar_bg": dict(fill="ink", hi="ink", lo="shadow", outline="shadow", sunken=True),
    }
    out = []
    for name, spec in specs.items():
        out.append(save(frame(12, 12, **spec), f"ui/{name}.png"))
    return out


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preview", help="also write a contact sheet of every output to this PNG")
    args = ap.parse_args()
    paths = build_characters() + build_sprites() + build_stations() + build_tiles() + build_edges() + build_idle() + build_fx() + build_building_parts() + build_space() + build_icons() + build_ship_modules() + build_ui()
    for p in paths:
        print(p.relative_to(ROOT))
    if args.preview:
        contact_sheet(paths, Path(args.preview))
        print("preview:", args.preview)


if __name__ == "__main__":
    main()
