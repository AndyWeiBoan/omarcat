#!/usr/bin/env python3
"""Generate a runner's sprite frames.

The frames are not drawings, they are a formula. Every one is the same nine
shapes -- body, head, ears, tail, four legs -- with two things varying:

  fatness (0-3)  the body grows and the whole animal sinks slightly
  frame   (1-5)  the leg endpoints move through one gait cycle

So a new runner is a spec, not twenty hand-drawn files. This script reproduces
the original cat exactly (verify with --check) before it is trusted to draw
anything else.

Usage:
  make-runner.py cat --check      compare against the committed cat frames
  make-runner.py dog              write ui/frames/dog_f*_*.svg
"""

import argparse
import os
import re
import sys

W, H = 60, 32
STROKE = 3
FAT_LEVELS = 4
FRAMES = 5

# Body centre drifts down-to-up as the animal fattens: it grows about its
# centre, but not quite -- the original sinks 0.1 per level, which keeps the
# feet planted while the back rises.
def centre_y(fat):
    return 15.5 - 0.1 * fat

def body_height(fat):
    return 11.0 + 2.7 * fat

# One gait cycle, as (front_leg_a, front_leg_b, rear_leg_a, rear_leg_b) end
# points. Hips sit at x=17 and x=37; the y origin follows the body.
GAIT = [
    ((13, 29.0), (23, 29.0), (33, 29.0), (43, 29.0)),
    ((15, 30.0), (21, 27.5), (35, 30.0), (41, 27.0)),
    ((18, 30.0), (19, 26.5), (38, 30.0), (37, 26.5)),
    ((21, 29.0), (15, 27.5), (41, 29.0), (35, 27.5)),
    ((23, 28.0), (13, 29.0), (43, 28.0), (33, 29.0)),
]

def fmt(v):
    """Trim trailing zeros, matching how the original frames were written:
    `29`, not `29.0`; `27.5`, not `27.50`."""
    text = f"{float(v):.4f}".rstrip("0").rstrip(".")
    return text or "0"


def line(x1, y1, x2, y2):
    return (f'  <path d="M{x1} {y1} L{fmt(x2)} {fmt(y2)}" fill="none" stroke="#fff" '
            f'stroke-width="{STROKE}" stroke-linecap="round"/>')

SPECS = {}

# --- cat: the original, reproduced -----------------------------------------
def cat(fat, frame, cy):
    d = cy - 15.5
    r = 7.0 + 0.55 * fat
    return {
        "tail": (f'  <path d="M14 {cy:.2f} C 6 {14.5 + d:.2f}, 3.5 {8.5 + d:.2f}, '
                 f'8.5 {4.0 + d:.2f}" fill="none" stroke="#fff" stroke-width="{STROKE}" '
                 f'stroke-linecap="round"/>'),
        "head_r": r,
        # Pointed ears, and deliberately NOT tracking the head radius: the
        # original pins them to the body centre, so a fat cat has a bigger head
        # behind the same ears.
        "after_head": [
            f'  <path d="M40.50 {10.0 + d:.2f} L41.00 {3.8 + d:.2f} L46.00 {7.2 + d:.2f} Z" fill="#fff"/>',
            f'  <path d="M52.50 {10.0 + d:.2f} L51.60 {4.2 + d:.2f} L47.60 {7.4 + d:.2f} Z" fill="#fff"/>',
        ],
    }
SPECS["cat"] = cat

# --- dog -------------------------------------------------------------------
def dog(fat, frame, cy):
    d = cy - 15.5
    r = 6.4 + 0.5 * fat
    # The two cues that read as "dog" at 60x32: a muzzle sticking out in front,
    # and an ear hanging DOWN instead of standing up. Everything else is the
    # same animal.
    muzzle_y = cy - 1.4
    # A short wagging tail, up and back -- the cat's long S-curve is its most
    # recognisable feature and is exactly what this must not have. It swings
    # through the gait so the dog looks pleased with itself.
    wag = [0.0, -1.2, -1.8, -1.2, 0.0][frame]
    return {
        "tail": (f'  <path d="M14 {cy - 2.5:.2f} C 10 {cy - 5.5 + wag:.2f}, '
                 f'8 {cy - 8.5 + wag:.2f}, 9.5 {cy - 11.0 + wag:.2f}" fill="none" '
                 f'stroke="#fff" stroke-width="{STROKE}" stroke-linecap="round"/>'),
        "head_r": r,
        "after_head": [
            # Muzzle: a capsule from the head towards the nose.
            f'  <rect x="49" y="{muzzle_y:.2f}" width="9" height="5.6" rx="2.8" fill="#fff"/>',
            # Floppy ear. It has to hang PAST the bottom of the head or it is
            # invisible: everything here is one solid white shape, so an ear
            # drawn inside the head's disc just becomes more head. Its length
            # tracks the head radius so it still protrudes on a fat dog.
            f'  <rect x="40.80" y="{cy - 6.8:.2f}" width="4.6" '
            f'height="{r + 8.8:.2f}" rx="2.30" fill="#fff"/>',
        ],
    }
SPECS["dog"] = dog


# --- dancer: an articulated figure, not a quadruped --------------------------
#
# The animals are one rigid body with four straight legs; this is a skeleton:
# head, torso, two arms and two legs, each limb two segments through a joint.
#
# The pose is a FUNCTION OF PHASE, not a set of hand-placed poses. The move is a
# continuous shoulder sway -- the feet stay planted, the shoulders rock, and
# everything else follows. Writing it as a phase makes the loop seamless (the
# last frame hands back to the first without a jolt) and makes the frame count a
# number rather than a rewrite.
#
# An earlier version hand-authored five distinct poses including a kick and a
# dip. It read as "some dance" rather than as the sway, because the signature of
# this move is that it never stops doing the same thing.
import math

GROUND = 28.6          # feet; a 3px round cap reaches 1.5 past this in a 32 box
STANCE = 11.5          # half the distance between the feet: a very wide stance


def limb(a, b, c, width):
    """Two segments through a joint, drawn as one rounded polyline.
    Each of a, b, c is an (x, y) pair."""
    return (f'  <path d="M{fmt(a[0])} {fmt(a[1])} L{fmt(b[0])} {fmt(b[1])} '
            f'L{fmt(c[0])} {fmt(c[1])}" fill="none" stroke="#fff" '
            f'stroke-width="{fmt(width)}" stroke-linecap="round" stroke-linejoin="round"/>')


def dancer(fat, frame, cy):
    phase = 2 * math.pi * frame / FRAMES
    sway = math.sin(phase)          # -1 .. 1, the shoulder rock
    bob = math.cos(2 * phase)       # twice a cycle: the body dips at each end

    limb_w = 3.0 + 0.45 * fat
    torso_w = 5.0 + 0.9 * fat
    head_r = 4.2 + 0.7 * fat

    hip_x = 30.0
    hip_y = 18.4 + 0.5 * bob
    # The shoulders lead: they slide further than the hips and tilt with the
    # sway, which is what makes it read as the shoulders doing the work.
    # Amplitudes are deliberately large. At 60x32 rendered into a 35px bar,
    # a 2px shift is invisible; the sway has to be most of the figure's width
    # before anyone sees it move.
    neck_x = hip_x + 3.8 * sway
    neck_y = 9.2 + 0.5 * bob
    shoulder_y = neck_y + 2.0
    tilt = 2.6 * sway
    head_x = neck_x + 1.4 * sway

    # Arms stay bent and swing across the body, opposed to each other.
    left = (neck_x - 3.2, shoulder_y - tilt)
    right = (neck_x + 3.2, shoulder_y + tilt)
    l_elbow = (left[0] - 2.4 - 2.8 * sway, left[1] + 4.4)
    l_hand = (l_elbow[0] - 0.6 - 4.2 * sway, l_elbow[1] - 3.2)
    r_elbow = (right[0] + 2.4 - 2.8 * sway, right[1] + 4.4)
    r_hand = (r_elbow[0] + 0.6 - 4.2 * sway, r_elbow[1] - 3.2)

    # Feet never move. The knees take the weight shift.
    l_foot = (hip_x - STANCE, GROUND)
    r_foot = (hip_x + STANCE, GROUND)
    l_knee = (hip_x - 6.4 + 1.8 * sway, hip_y + 5.6 - 0.5 * sway)
    r_knee = (hip_x + 6.4 + 1.8 * sway, hip_y + 5.6 + 0.5 * sway)

    return {"skeleton": [
        # The chin-to-shoulder gap grows with the head, so a heavy figure keeps
        # a neck instead of merging into one lump.
        f'  <circle cx="{fmt(head_x)}" cy="{fmt(neck_y - head_r - 1.2 - 0.25 * fat)}" '
        f'r="{fmt(head_r)}" fill="#fff"/>',
        (f'  <path d="M{fmt(neck_x)} {fmt(neck_y)} L{fmt(hip_x)} {fmt(hip_y)}" fill="none" '
         f'stroke="#fff" stroke-width="{fmt(torso_w)}" stroke-linecap="round"/>'),
        limb(left, l_elbow, l_hand, limb_w),
        limb(right, r_elbow, r_hand, limb_w),
        limb((hip_x - 1.4, hip_y), l_knee, l_foot, limb_w),
        limb((hip_x + 1.4, hip_y), r_knee, r_foot, limb_w),
    ]}
SPECS["dancer"] = dancer


def render(name, fat, frame):
    cy = centre_y(fat)
    h = body_height(fat)
    y = cy - h / 2
    spec = SPECS[name](fat, frame, cy)
    if "skeleton" in spec:
        # An articulated runner draws itself: no body rect, no gait formula.
        head = [
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',
            f'  <!-- {name}: fatness {fat} of {FAT_LEVELS - 1}, frame {frame + 1} of {FRAMES}.',
            '       CPU load picks the frame, memory pressure thickens the figure.',
            '       White; the widget recolours it to the bar text colour. Generated',
            '       by tools/make-runner.py; edit the spec there, not this file. -->',
        ]
        return "\n".join(head + spec["skeleton"] + ["</svg>"]) + "\n"
    leg_y = y + h - 1.5
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">',
        f'  <!-- {name}: fatness {fat} of {FAT_LEVELS - 1}, gait frame {frame + 1} of {FRAMES}.',
        '       CPU load picks the frame, memory pressure picks the fatness. White;',
        '       the widget recolours it to the bar text colour. Generated by',
        # No double hyphen anywhere in here: XML forbids it inside a comment,
        # and librsvg refuses the whole file rather than shrugging.
        '       tools/make-runner.py; edit the spec there, not this file. -->',
        spec["tail"],
        f'  <rect x="12" y="{y:.2f}" width="30" height="{h:.2f}" rx="{h / 2:.2f}" fill="#fff"/>',
        f'  <circle cx="46" cy="{cy:.2f}" r="{spec["head_r"]:.2f}" fill="#fff"/>',
    ]
    parts += spec["after_head"]
    for (x2, y2) in GAIT[frame][:2]:
        parts.append(line(17, f"{leg_y:.2f}", x2, y2))
    for (x2, y2) in GAIT[frame][2:]:
        parts.append(line(37, f"{leg_y:.2f}", x2, y2))
    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def strip(text):
    """Comments and whitespace out, so only the geometry is compared."""
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    return re.sub(r"\s+", " ", text).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("runner", choices=sorted(SPECS))
    ap.add_argument("--check", action="store_true",
                    help="compare with the existing frames instead of writing")
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "ui", "frames"))
    args = ap.parse_args()

    failures = 0
    for fat in range(FAT_LEVELS):
        for frame in range(FRAMES):
            svg = render(args.runner, fat, frame)
            path = os.path.join(args.out, f"{args.runner}_f{fat}_{frame + 1}.svg")
            if args.check:
                if not os.path.exists(path):
                    print(f"  missing {os.path.basename(path)}")
                    failures += 1
                elif strip(open(path).read()) != strip(svg):
                    print(f"  DIFFERS {os.path.basename(path)}")
                    failures += 1
            else:
                with open(path, "w") as fh:
                    fh.write(svg)
    if args.check:
        print("  all 20 frames match" if not failures else f"  {failures} mismatch")
        return 1 if failures else 0
    print(f"  wrote 20 frames for {args.runner}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
