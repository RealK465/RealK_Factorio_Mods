"""The eight working systems and the designed idle.

Every loop closes EXACTLY on `frames`, because a loop that does not close is
the animation equivalent of a seam: the sprite jumps on the wrap, once a
second, forever. Every rotating part therefore turns a whole number of its own
symmetry steps, and the frame that would follow the last one is the first.

**Speed is checked twice.** The engine scales a crafting machine's animation by
its crafting speed unless `constant_speed` is set, and this machine runs at 1.0
against the vanilla recycler's 0.5 -- so the prototype uses `animation_speed =
2` where the recycler uses 4, and the two read at the same tempo standing side
by side. Per-frame rotation is then kept well under half the symmetry step, so
nothing wagon-wheels backwards:

    rotor    14 poles,  2 pitches/loop ->  0.80 deg/frame  (limit 12.9)
    gear     20 teeth,  5 pitches/loop ->  1.41            (limit  9.0)
    rollers   9 teeth,  4 pitches/loop ->  2.50            (limit 20.0)
    fan       5 blades, 6 pitches/loop ->  6.75            (limit 36.0)

The gear's 5 against the rotor's 2 and the fan's 6 are chosen so no two systems
share a period: three parts turning in lockstep read as one mechanism, which is
the opposite of "a machine with several subsystems".

**Idle** is frame 0 with the emissives off: the rotor parked with a pole at top
dead centre, the rollers shut, the ram home, no chip in flight. The anim sheet
is a layer of `animation`, so the engine simply stops advancing it; the glow and
fx sheets are `working_visualisations` and vanish, and the green status lamp --
which never animates -- is what says IDLE at a glance.
"""
import math

import bpy

import quality_recycler_gen as gen
import qr_layout as L
import qr_rebuild as rb

PREFIX = gen.PREFIX
TAU = 2 * math.pi


def _mat_key(name, socket, pairs):
    """Keyframe one material socket. Emission lives on the material, so this is
    how a glow pulses without any geometry moving."""
    mat = bpy.data.materials.get(PREFIX + name)
    if not mat:
        print("[anim] no material %s" % name)
        return
    bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"),
                None)
    if not bsdf:
        return
    sock = bsdf.inputs[socket]
    for f, v in pairs:
        sock.default_value = v
        sock.keyframe_insert("default_value", frame=f)


def animate(frames=64):
    rotor_pitch = TAU / 14.0
    gear_pitch = TAU / 20.0
    roller_pitch = TAU / 9.0
    fan_pitch = TAU / 5.0

    # 1. THE HERO: the eddy rotor
    piv = gen._pivot("piv-rotor", (L.ROTOR[0], L.ROTOR[1], L.ROTOR_Z))
    gen._attach(piv, ("rotor-drum", "rotor-band", "rotor-ribs", "rotor-flange",
                      "rotor-hub", "rotor-bolts", "rotor-cap"))
    gen._key(piv, "rotation_euler", [(0, 0.0), (frames, 2 * rotor_pitch)],
             index=2)

    # 2. the drive wheel, counter to the rotor: the two halves are geared, and
    #    that is the design's one mechanical statement about the seam
    piv = gen._pivot("piv-gear", (L.GEAR[0], L.GEAR[1], 0.60))
    gen._attach(piv, ("gear-disc", "gear-teeth"))
    gen._key(piv, "rotation_euler", [(0, 0.0), (frames, -5 * gear_pitch)],
             index=2)

    # 3. the shredder rollers, counter-rotating. A shredder whose rollers all
    #    turned the same way would feed material back out of its own mouth.
    for i, z in enumerate(L.MAW_ROLLER_Z):
        piv = gen._pivot("piv-maw%d" % i,
                         (0.5 * (L.MAW[0] + L.MAW[1]), L.MAW_Y, z))
        gen._attach(piv, ("maw-roller%d" % i, "maw-teeth%d" % i))
        turns = 4 * roller_pitch * (1 if i % 2 == 0 else -1)
        gen._key(piv, "rotation_euler", [(0, 0.0), (frames, turns)], index=0)

    # 4. the cooling fan
    piv = gen._pivot("piv-fan", (-0.80, -0.24, 1.13))
    gen._attach(piv, ("fan-hub", "fan-blade"))
    gen._key(piv, "rotation_euler", [(0, 0.0), (frames, 6 * fan_pitch)],
             index=2)

    # 5. the feeder ram: one stroke a loop, quick in and slow out. Keyed on the
    #    objects rather than on a pivot because it travels rather than turns.
    stroke, q = 0.30, frames // 4
    for name in ("flap-ram", "flap-ram-head", "flap-ram-rod"):
        obj = bpy.data.objects.get(PREFIX + name)
        if obj is None:
            continue
        gen._key(obj, "location",
                 [(0, 0.0), (q, stroke), (q + 2, stroke), (frames, 0.0)],
                 index=1, interp="BEZIER")

    # 6. the fragments: one per quarter loop, on a ballistic arc from the
    #    rotor's south rim into the single output chute. CONSTANT-interpolated
    #    scale keys switch each chip on and off, so it exists only in flight --
    #    and they live in QR_Fx, which is excluded from the shadow pass,
    #    because a baked shadow of something in flight lands displaced from the
    #    machine and then never moves.
    launch = (L.ROTOR[0] - 0.08, L.ROTOR[1] - L.R_DISC + 0.04, 0.80)
    land = (1.09, -1.55, 0.30)
    flight = frames // 4 - 2
    for i in range(4):
        obj = bpy.data.objects.get(PREFIX + "frag%d" % i)
        if obj is None:
            continue
        start = i * (frames // 4)
        for step in range(flight + 1):
            t = step / flight
            obj.location = (launch[0] + (land[0] - launch[0]) * t,
                            launch[1] + (land[1] - launch[1]) * t,
                            launch[2] + (land[2] - launch[2]) * t
                            + 0.34 * math.sin(math.pi * t))
            obj.keyframe_insert("location", frame=(start + step) % frames)
        for idx in (0, 1, 2):
            gen._key(obj, "scale",
                     [(0, 0.0), (start, 0.0), (start + 1, 1.0),
                      (start + flight, 1.0), (start + flight + 1, 0.0)],
                     index=idx, interp="CONSTANT")

    # 7. the field glow, phase-locked to the rotor: two beats a loop. Peak 2.1,
    #    because Standard clips hard and a violet past that turns white and
    #    takes its hue with it.
    _mat_key("violet", "Emission Strength",
             [(0, 2.10), (frames // 4, 1.25), (frames // 2, 2.10),
              (3 * frames // 4, 1.25), (frames, 2.10)])

    # 8. the arcs across the rotor contacts: irregular on purpose. A regular
    #    flicker reads as a blinking lamp, and Fulgora's arcs are the opposite
    #    of periodic. The pattern is fixed rather than random so the render is
    #    reproducible, and it closes on `frames` like everything else.
    pattern = [(0, 3), (7, 2), (11, 5), (21, 2), (26, 4), (33, 3), (39, 6),
               (48, 2), (53, 4), (59, 3)]
    for i in range(4):
        obj = bpy.data.objects.get(PREFIX + "arc%d" % i)
        if obj is None:
            continue
        keys = [(0, 0.0)]
        for j, (at, dur) in enumerate(pattern):
            if j % 4 != i:
                continue
            a = at % frames
            keys += [(a, 1.0), (min(a + dur, frames - 1), 1.0),
                     (min(a + dur + 1, frames), 0.0)]
        keys.append((frames, 0.0))
        for idx in (0, 1, 2):
            gen._key(obj, "scale", keys, index=idx, interp="CONSTANT")

    # 9. THE GRADING SCAN: a bar crossing the window twice a loop, each lens
    #    lighting as the bar reaches it. This is the one thing the entity does
    #    that the vanilla recycler does not, and it is the only place the
    #    quality colours are allowed to move.
    scan = bpy.data.objects.get(PREFIX + "scan")
    travel = 0.86
    if scan is not None:
        half = frames // 2
        gen._key(scan, "location",
                 [(0, 0.0), (half - 1, travel), (half, 0.0),
                  (frames - 1, travel), (frames, 0.0)],
                 index=0, interp="LINEAR")
        # SCALE 0 AT FRAME 0, and this is not cosmetic. `scan` lives in
        # QR_Base, so the static base sheet is rendered with it at frame 0 --
        # which put a violet bar permanently at the left end of the grading
        # window while the glow sheet swept a second one across it. Two violet
        # marks, one of them frozen, on the feature whose whole job is to look
        # like a scan. Keying it off at frame 0 removes it from the base sheet
        # and makes "idle = not scanning" true as well.
        for idx in (0, 1, 2):
            gen._key(scan, "scale",
                     [(0, 0.0), (1, 1.0), (half - 1, 1.0), (half, 0.0),
                      (half + 1, 1.0), (frames - 1, 1.0), (frames, 0.0)],
                     index=idx, interp="CONSTANT")
    for i in range(5):
        # the bar starts at x 0.20 and lens i sits at 0.26 + 0.22 i, so the bar
        # reaches it at (0.06 + 0.22 i) / travel of each sweep
        at = (0.06 + 0.22 * i) / travel
        # 0.80 at the peak, not 1.70. The base sheet already carries each
        # lens's true colour as a lit dielectric, and the glow sheet is ADDED
        # over it -- at 1.70 the sum clipped and the row of five quality
        # colours rendered as five white dots, which is the one feature on this
        # machine whose entire job is to be five different colours.
        pairs = {0: 0.10 * (rb.LENS_STRENGTH[i] if rb.LENS_STRENGTH else 1.0),
             frames: 0.10 * (rb.LENS_STRENGTH[i] if rb.LENS_STRENGTH else 1.0)}
        for sweep in range(2):
            c = int((sweep + at) * frames / 2.0) % frames
            peak = 0.42 * rb.LENS_STRENGTH[i] if rb.LENS_STRENGTH else 0.80
            for f, v in ((max(c - 3, 1), 0.12 * peak), (c, peak),
                         (min(c + 3, frames - 1), 0.12 * peak)):
                pairs[f] = max(pairs.get(f, 0.0), v)
        _mat_key("q%d" % i, "Emission Strength", sorted(pairs.items()))
