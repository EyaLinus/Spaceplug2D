#!/usr/bin/env python3
"""Builds every PNG in assets/gfx from the sources in assets/src and art_profile.yaml.

    python3 tools/art/build_art.py            # rebuild all
    python3 tools/art/build_art.py --preview build/art_preview.png   # also write a contact sheet

Sources:
  assets/src/sprites/*.txt   hand-written pixel grids (game-assets-2d pixelart format)
  assets/src/stations/*.txt  lab station machines (estate interiors), sized to the buildable footprint
  assets/src/icons/*.txt     UI icons (items, upgrades, HUD), same grid format
  assets/src/characters.yaml role-letter -> palette swaps for the char_* grids
  this file                  procedural tiles and building pieces (seeded, palette-locked)

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
                         ("patrol", "ships"), ("beacon", "space")]:
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


def build_tiles() -> list[Path]:
    out = []
    sets = {
        "mireth": {
            "ground": [speckle("grass", [("grass_dark", 0.06), ("grass_light", 0.025)], s, "grass_light" if s % 2 else "leaf") for s in range(4)],
            "road": [speckle("slate_dark", [("shadow", 0.05), ("slate", 0.015)], 10 + s) for s in range(4)],
            "plaza": [paving("slate", "slate_dark", "slate_light", 20 + s) for s in range(4)],
        },
        "cinder": {
            "ground": [speckle("dirt", [("dirt_dark", 0.07), ("rust", 0.02)], 30 + s, "rust" if s % 2 else None) for s in range(4)],
            "road": [speckle("rust", [("dirt", 0.08), ("rust_light", 0.02), ("dirt_dark", 0.02)], 40 + s) for s in range(4)],
            "plaza": [plates("slate", "slate_dark", "shadow", "slate_light", 50 + s, s % 2 == 0) for s in range(4)],
        },
        "bazaar": {
            "ground": [plates("shadow", "night", "slate_dark", "purple_dark", 60 + s, s % 2 == 0) for s in range(4)],
            "road": [grate("purple_dark", "night", "purple") for _ in range(4)],
            "plaza": [plates("slate_dark", "night", "slate", "slate", 70 + s, s % 2 == 1) for s in range(4)],
        },
        "varrow": {  # desert dust town
            "ground": [speckle("sand", [("rust_light", 0.07), ("wood", 0.02)], 80 + s, "rust_light" if s % 2 else None) for s in range(4)],
            "road": [speckle("wood", [("wood_dark", 0.07), ("rust_light", 0.03)], 90 + s) for s in range(4)],
            "plaza": [paving("rust_light", "rust", "sand", 100 + s) for s in range(4)],
        },
        "glacis": {  # ice colony
            "ground": [speckle("stone", [("white", 0.08), ("slate_light", 0.03), ("blue_light", 0.012)], 110 + s) for s in range(4)],
            "road": [plates("slate", "slate_dark", "shadow", "slate_light", 120 + s, s % 2 == 0) for s in range(4)],
            "plaza": [paving("slate_light", "slate", "white", 130 + s) for s in range(4)],
        },
    }
    for biome, kinds in sets.items():
        for kind, tiles in kinds.items():
            out.append(save(strip(tiles), f"tiles/{biome}_{kind}.png"))
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
    for g in ("halvane_gate", "kovar_gate"):  # one gate design, one file per location id (registry rule)
        out.append(save(gate(60), f"space/{g}.png"))
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


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--preview", help="also write a contact sheet of every output to this PNG")
    args = ap.parse_args()
    paths = build_characters() + build_sprites() + build_stations() + build_tiles() + build_building_parts() + build_space() + build_icons()
    for p in paths:
        print(p.relative_to(ROOT))
    if args.preview:
        contact_sheet(paths, Path(args.preview))
        print("preview:", args.preview)


if __name__ == "__main__":
    main()
