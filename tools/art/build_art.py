#!/usr/bin/env python3
"""Builds every PNG in assets/gfx from the sources in assets/src and art_profile.yaml.

    python3 tools/art/build_art.py            # rebuild all
    python3 tools/art/build_art.py --preview build/art_preview.png   # also write a contact sheet

Sources:
  assets/src/sprites/*.txt   hand-written pixel grids (game-assets-2d pixelart format)
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
                         ("lamp", "props"), ("vent", "props"), ("stall", "props"), ("ship", "ships")]:
        legend, frames = parse_grid(SRC / "sprites" / f"{name}.txt")
        out.append(save(grid_image(frames[0], legend), f"{folder}/{name}.png"))
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
    paths = build_characters() + build_sprites() + build_tiles() + build_building_parts()
    for p in paths:
        print(p.relative_to(ROOT))
    if args.preview:
        contact_sheet(paths, Path(args.preview))
        print("preview:", args.preview)


if __name__ == "__main__":
    main()
