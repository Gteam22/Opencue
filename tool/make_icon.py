#!/usr/bin/env python3
"""Draws the OpenCue mark and writes the icon assets.

The mark is a speech bubble with a compass needle inside it: something said,
pointed at a particular moment. Generated in-repo rather than committed as an
opaque binary so it can be regenerated at any size and so the geometry stays
reviewable. It matches OpenCueMark in lib/features/shared/widgets.dart.

Outputs:
  assets/icons/opencue.ico          Windows app + installer icon
  assets/icons/opencue-256.png      Preview / docs
  assets/icons/opencue-mono.png     Flat single-colour version

Run:  python3 tool/make_icon.py

This is a clean placeholder, not final brand artwork. Replacing the PNG/ICO
files here is all that is needed; nothing reads the geometry at runtime.
"""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icons"

# Matches AppTheme.seed (0xFF2F5D62) and its light surface.
TEAL = (47, 93, 98, 255)
PALE = (233, 240, 239, 255)
TRANSPARENT = (0, 0, 0, 0)

# Rendered large and downsampled, which is cheaper than antialiasing by hand.
SUPERSAMPLE = 8


def draw_mark(size: int, background: tuple[int, int, int, int]) -> Image.Image:
    """Renders the mark at [size] px on a [background] fill."""
    scale = size * SUPERSAMPLE
    image = Image.new("RGBA", (scale, scale), background)
    draw = ImageDraw.Draw(image)

    # One unit is 1/32 of the canvas, the same grid the Flutter painter uses.
    u = scale / 32
    stroke = max(1, round(2.2 * u))

    # Speech bubble.
    draw.rounded_rectangle(
        (3 * u, 4 * u, 29 * u, 24 * u),
        radius=6 * u,
        outline=TEAL,
        width=stroke,
    )

    # Tail.
    draw.line(
        [(10 * u, 24 * u), (10 * u, 29 * u), (16 * u, 24 * u)],
        fill=TEAL,
        width=stroke,
        joint="curve",
    )
    # The tail meets the bubble's lower edge; redrawing that short segment in
    # the background colour opens it so the two shapes read as one outline.
    draw.line(
        [(10 * u + stroke, 24 * u), (16 * u - stroke, 24 * u)],
        fill=background,
        width=stroke,
    )

    # Compass needle: filled leading half, outlined counterweight.
    draw.polygon(
        [(21 * u, 9.5 * u), (15 * u, 18.5 * u), (19.5 * u, 16 * u)],
        fill=TEAL,
    )
    draw.polygon(
        [(21 * u, 9.5 * u), (16.5 * u, 12 * u), (19.5 * u, 16 * u)],
        outline=TEAL,
        width=max(1, round(1.4 * u)),
    )

    return image.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    # Windows shows the icon at several sizes; the shell picks the closest.
    ico_sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [draw_mark(size, PALE) for size in ico_sizes]
    frames[-1].save(
        OUT / "opencue.ico",
        format="ICO",
        sizes=[(s, s) for s in ico_sizes],
        append_images=frames[:-1],
    )

    draw_mark(256, PALE).save(OUT / "opencue-256.png")
    draw_mark(256, TRANSPARENT).save(OUT / "opencue-mono.png")

    print(f"Wrote {OUT / 'opencue.ico'} ({len(ico_sizes)} sizes)")
    print(f"Wrote {OUT / 'opencue-256.png'}")
    print(f"Wrote {OUT / 'opencue-mono.png'}")


if __name__ == "__main__":
    main()
