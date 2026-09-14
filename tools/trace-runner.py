#!/usr/bin/env python3
"""Trace a silhouette bitmap sequence into runner frames.

For runners that come from footage rather than from a spec. The bitmap is
already a clean two-tone silhouette; this only has to place it in the 60x32 box
every other runner uses and emit it as SVG.

Rows of set pixels become <rect> runs. That is blocky at source resolution and
deliberately so: the input IS a bitmap, and pretending otherwise with curve
fitting would invent detail the footage never had. Rendered down into a 35px
bar the runs are sub-pixel anyway.

The frames are cropped to one shared bounding box, not to each frame's own
content: trimming per frame makes the figure jump around as its outline
changes, which reads as a camera shake rather than a dance.
"""

import argparse
import os
import subprocess
import sys

W, H = 60, 32
# The input is expected to be ALREADY at icon size: one source pixel becomes one
# unit in the 60x32 box. Tracing a full-resolution silhouette and scaling it down
# here produced sub-pixel rects that antialiased to grey and never merged into a
# solid shape -- the figure came out translucent.
SCALE = 1.0


def pixels(path):
    """White pixel coordinates and the image size."""
    out = subprocess.run(["magick", path, "txt:-"], capture_output=True, text=True).stdout
    lines = out.splitlines()
    # Header is "# ImageMagick pixel enumeration: W,H,min,max,colorspace".
    fields = lines[0].split(":", 1)[1].strip().split(",")
    w, h = int(fields[0]), int(fields[1])
    on = set()
    for line in lines[1:]:
        if "#FFFFFF" not in line.upper():
            continue
        coord = line.split(":", 1)[0]
        x, y = (int(v) for v in coord.split(","))
        on.add((x, y))
    return on, w, h


def upper_centroid(on, box, band=0.45):
    """Mean x of the pixels in the top `band` of the figure -- the shoulder
    line, which is what the sway is actually made of."""
    y0, y1 = box[1], box[3]
    cut = y0 + (y1 - y0) * band
    xs = [x for (x, y) in on if y <= cut]
    return sum(xs) / len(xs) if xs else 0.0


def exaggerate(on, box, lean, hip=0.62):
    """Shear the upper body sideways by `lean`, tapering to nothing at the hips.

    Footage sways less than it feels like it does: measured on this clip the
    shoulder line moves about a sixth of the figure's width, which at 17 pixels
    across is two or three pixels. Amplifying it keeps the real silhouette and
    the real timing while making the motion legible at icon size.

    The taper matters as much as the amount -- shifting the whole figure would
    slide it around the bar; shifting only above the hips reads as the body
    leaning over planted feet, which is the move.
    """
    y0, y1 = box[1], box[3]
    hip_y = y0 + (y1 - y0) * hip
    out = set()
    for (x, y) in on:
        if y >= hip_y:
            out.add((x, y))
            continue
        t = (hip_y - y) / max(1.0, hip_y - y0)      # 0 at the hips, 1 at the head
        out.add((x + int(round(lean * t)), y))
    return out


def broaden(on, box, amount, top=0.22, bottom=0.46):
    """Widen a horizontal band -- the shoulders -- by `amount` pixels each side.

    A dilation over the whole figure would just make a fatter person. Confining
    it to the shoulder band is what reads as a build rather than a weight.
    """
    if amount <= 0:
        return on
    y0, y1 = box[1], box[3]
    lo = y0 + (y1 - y0) * top
    hi = y0 + (y1 - y0) * bottom
    out = set(on)
    for (x, y) in on:
        if lo <= y <= hi:
            for d in range(1, amount + 1):
                out.add((x - d, y))
                out.add((x + d, y))
    return out


def bbox(on):
    xs = [p[0] for p in on]
    ys = [p[1] for p in on]
    return min(xs), min(ys), max(xs), max(ys)


def to_svg(on, box, scale, name, index, total):
    x0, y0, x1, y1 = box
    fw = (x1 - x0 + 1) * scale
    ox = (W - fw) / 2 - x0 * scale
    oy = (H - (y1 - y0 + 1) * scale) / 2 - y0 * scale

    # Row runs first, then merged downwards.
    #
    # One <rect> per row leaves a hairline seam between every pair of them:
    # adjacent rectangles at fractional scale do not quite meet, and the result
    # is a figure combed with horizontal stripes. Runs that share both edges are
    # the same rectangle, so emit them as one tall rect and the seams inside a
    # solid area disappear. On the cat this takes ~300 rects down to ~60.
    runs = {}
    for y in range(y0, y1 + 1):
        run = None
        for x in range(x0, x1 + 2):
            if (x, y) in on:
                if run is None:
                    run = x
            elif run is not None:
                runs.setdefault((run, x - run), []).append(y)
                run = None

    rects = []
    for (rx, rw), ys in runs.items():
        ys.sort()
        start = prev = ys[0]
        for y in ys[1:] + [None]:
            if y == prev + 1:
                prev = y
                continue
            rects.append((rx, start, rw, prev - start + 1))
            if y is not None:
                start = prev = y

    # Every rect is grown by a hair so neighbours OVERLAP.
    #
    # Merging identical runs was not enough: an organic shape changes width on
    # almost every row, so there is little to merge. The seams come from
    # antialiasing -- two rects that share an edge are each rendered with
    # partial coverage there, and the two halves do not add up to a solid
    # pixel, leaving a hairline. Overlapping saturates the coverage instead.
    #
    # The bleed is symmetric so the silhouette does not drift, and at 0.15 of a
    # source pixel on a figure 30 tall it is half a percent -- far below what
    # the eye can see, and far above what the renderer needs to close a seam.
    bleed = 0.15
    body = []
    for (rx, ry, rw, rh) in rects:
        body.append(f'  <rect x="{ox + (rx - bleed) * scale:.3f}" '
                    f'y="{oy + (ry - bleed) * scale:.3f}" '
                    f'width="{(rw + 2 * bleed) * scale:.3f}" '
                    f'height="{(rh + 2 * bleed) * scale:.3f}" fill="#fff"/>')

    head = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',
        f'  <!-- {name}: frame {index} of {total}, traced from footage.',
        '       Rows of set pixels as rect runs; see tools/trace-runner.py.',
        '       White; the widget recolours it to the bar text colour. -->',
    ]
    return "\n".join(head + body + ["</svg>"]) + "\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("sources", nargs="+", help="silhouette PNGs, in frame order")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "ui", "frames"))
    ap.add_argument("--fat-levels", type=int, default=4)
    ap.add_argument("--sway", type=float, default=0.0,
                    help="amplify the measured shoulder sway by this factor")
    ap.add_argument("--shoulders", type=int, default=0,
                    help="widen the shoulder band by this many pixels each side")
    args = ap.parse_args()

    frames = [pixels(p)[0] for p in args.sources]
    if not all(frames):
        print("  a frame came back empty", file=sys.stderr)
        return 1

    # One bounding box for the whole sequence, so the figure stays put.
    union = set().union(*frames)
    box = bbox(union)

    if args.sway or args.shoulders:
        centroids = [upper_centroid(f, box) for f in frames]
        base = sum(centroids) / len(centroids)
        frames = [
            broaden(exaggerate(f, box, args.sway * (c - base)), box, args.shoulders)
            for f, c in zip(frames, centroids)
        ]
        # The shear moves pixels outside the original box.
        union = set().union(*frames)
        box = bbox(union)
    scale = SCALE

    for i, on in enumerate(frames, start=1):
        svg = to_svg(on, box, scale, args.name, i, len(frames))
        # Footage gives one body, not four weights: the same frame is written
        # for every fatness level so the runner still satisfies the loader's
        # 4 x 5 grid. Memory pressure simply has nothing to say here.
        for fat in range(args.fat_levels):
            with open(os.path.join(args.out, f"{args.name}_f{fat}_{i}.svg"), "w") as fh:
                fh.write(svg)
    print(f"  wrote {len(frames)} frames x {args.fat_levels} levels for {args.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
