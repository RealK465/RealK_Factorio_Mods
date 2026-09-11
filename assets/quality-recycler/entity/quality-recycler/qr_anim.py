"""v3: the working loop, ejection included.

Every loop closes EXACTLY on `frames` -- a loop that does not close is the
animation equivalent of a seam, and the sprite jumps on the wrap once a second
forever. Rotating parts turn a whole number of their own symmetry steps.

The engine scales a crafting machine's animation by its crafting speed unless
`constant_speed` is set, and this machine runs at 1.0 against the vanilla
recycler's 0.5, so the prototype uses `animation_speed = 2`. Per-frame
rotation stays well under half the symmetry step:

    rotor    12 poles / 6 cap slots, 120 deg per loop -> 1.9 deg/frame
    rollers   9 teeth,  4 pitches/loop               -> 2.50

## The ejection cycle, one batch per loop

    f0        chips at rest at the trough's south end; doors shut; ram home
    f2-f26    the ram pushes north, slowly -- effortful -- chips ride ahead
    f8-f16    the scanner over the trough lights as the batch passes under
    f20-f26   each chip reaches the trough's end and DROPS into the throat,
              seen from above; the ejector lamp on the throat's rim lights
    f22-f28   the doors part
    f27-f33   the batch is inside the hopper (hidden)
    f34-f42   chips drop out of the mouth, over the sill, off the tile
    f30-f42   the ram returns, quickly
    f42-f48   the doors close
    f46-f54   the rotor throws the next batch down the discharge chute into
              the trough; they settle by f56 and sit there until f64 = f0

Idle is frame 0: doors shut, ram home, cap parked with a slot at top dead
centre, no chip anywhere (the chips are a working_visualisation and simply do
not draw), no violet. Only the green status lamp.
"""
import math

import bpy

import quality_recycler_gen as gen
import qr_layout as L

PREFIX = gen.PREFIX
TAU = 2 * math.pi


def _mat_key(name, socket, pairs):
    """Keyframe one material socket: emission pulses without geometry moving."""
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


def _smooth(t):
    """Ease in and out -- a hydraulic stroke, not a linear slide."""
    return 0.5 - 0.5 * math.cos(math.pi * min(max(t, 0.0), 1.0))


def ram_offset(f, frames=64):
    """The pusher's y offset at frame f: out slowly over f2..f26, hold, back
    quickly over f30..f42. Shared with the chips so they ride the head."""
    if f < 2:
        return 0.0
    if f <= 26:
        return L.RAM_STROKE * _smooth((f - 2) / 24.0)
    if f <= 30:
        return L.RAM_STROKE
    if f <= 42:
        return L.RAM_STROKE * (1.0 - _smooth((f - 30) / 12.0))
    return 0.0


def animate(frames=64):
    rotor_pitch = TAU / L.POLES
    roller_pitch = TAU / 9.0

    # 1. THE HERO: the magnet ring, the copper retaining ring, the slotted cap
    piv = gen._pivot("piv-rotor", (L.ROTOR[0], L.ROTOR[1], L.ROTOR_Z))
    gen._attach(piv, ("rotor-poles-a", "rotor-poles-b", "rotor-ring",
                      "rotor-cap-rim", "rotor-cap-outer", "rotor-cap-inner",
                      "rotor-cap-groove", "rotor-cap-bolts")
                + tuple("rotor-cap-web%d" % i for i in range(L.CAP_SLOTS)))
    # 4 pole pitches a loop (120 degrees): at 2 the cap's slots crept and the
    # hero read as idling. 1.9 degrees a frame against a 30-degree pitch still
    # cannot wagon-wheel backwards.
    gen._key(piv, "rotation_euler", [(0, 0.0), (frames, 4 * rotor_pitch)],
             index=2)

    # 2. the shredder rollers, counter-rotating
    for i, z in enumerate(L.MAW_ROLLER_Z):
        piv = gen._pivot("piv-maw%d" % i,
                         (0.5 * (L.MAW[0] + L.MAW[1]), L.MAW_Y, z))
        gen._attach(piv, ("maw-roller%d" % i, "maw-teeth%d" % i))
        turns = 4 * roller_pitch * (1 if i % 2 == 0 else -1)
        gen._key(piv, "rotation_euler", [(0, 0.0), (frames, turns)], index=0)

    # 3. the feeder ram on the apron: one stroke, quick in and slow out.
    #    0.11: the apron is inside the footprint now and the head stops just
    #    short of the bottom roller
    stroke, q = 0.11, frames // 4
    for name in ("flap-ram", "flap-ram-head", "flap-ram-rod"):
        obj = bpy.data.objects.get(PREFIX + name)
        if obj is None:
            continue
        gen._key(obj, "location",
                 [(0, 0.0), (q, stroke), (q + 2, stroke), (frames, 0.0)],
                 index=1, interp="BEZIER")

    # 4. THE EJECTOR RAM, keyed every frame so the ease is exact
    for name in ("ram-head", "ram-rod"):
        obj = bpy.data.objects.get(PREFIX + name)
        if obj is None:
            print("[anim] missing %s" % name)
            continue
        gen._key(obj, "location",
                 [(f, ram_offset(f, frames)) for f in range(frames + 1)],
                 index=1, interp="LINEAR")

    # 5. the doors part and close
    travel = L.MOUTH_W + 0.01
    for name, sgn in (("door-l", -1.0), ("door-r", 1.0)):
        obj = bpy.data.objects.get(PREFIX + name)
        if obj is None:
            print("[anim] missing %s" % name)
            continue
        gen._key(obj, "location",
                 [(0, 0.0), (22, 0.0), (28, sgn * travel), (42, sgn * travel),
                  (48, 0.0), (frames, 0.0)],
                 index=0, interp="BEZIER")

    # 6. THE CHIPS. Five, keyed per frame through the whole cycle. They are
    #    in QR_Fx (a working_visualisation) and excluded from the shadow pass.
    #    Each tumbles as it flies out of the mouth and again down the chute.
    rest = [(-0.36, 0.50), (-0.22, 0.56), (-0.29, 0.66), (-0.38, 0.62),
            (-0.19, 0.69)]                                    # x, y at rest
    z_rest = L.TROUGH_Z + 0.045
    trough_end = L.TROUGH_Y[1] + 0.02
    throat_floor = 0.42 + 0.045
    py1 = L.PORT_Y[1]
    notch = (L.ROTOR[0] - L.R_STATOR_IN + 0.06, L.ROTOR[1], 0.92)
    mouth_x = tuple(L.PORT_X + v for v in (-0.13, 0.0, 0.13, -0.22, 0.22))
    for i in range(5):
        obj = bpy.data.objects.get(PREFIX + "frag%d" % i)
        if obj is None:
            continue
        rx, ry = rest[i]
        base_rot = math.radians(25.0 * i)
        dropped_at = None
        for f in range(frames + 1):
            vis = 1.0
            rot = base_rot
            if f <= 26:                                   # riding the ram
                y = ry + ram_offset(f, frames)
                z = z_rest
                if y > trough_end:                        # ...and dropping
                    if dropped_at is None:
                        dropped_at = f
                    z = max(throat_floor,
                            z_rest - 0.03 * (f - dropped_at + 1) ** 2)
                pos = (rx, y, z)
            elif f <= 33:                                 # inside the hopper
                pos = (rx, ry + L.RAM_STROKE, throat_floor)
                vis = 0.0
            elif f <= 42:                                 # out of the mouth
                t = (f - 34) / 8.0
                pos = (mouth_x[i], py1 + 0.02 + 0.30 * t,
                       0.30 - 0.32 * t * t)
                rot = base_rot + (1.0 + 0.4 * i) * t
                if f == 42:
                    vis = 0.0
            elif f < 46:
                pos = (mouth_x[i], py1 + 0.34, -0.05)
                vis = 0.0
            elif f <= 54:                                 # down the chute
                t = (f - 46) / 8.0
                pos = (notch[0] + (rx - notch[0]) * t,
                       notch[1] + (ry - notch[1]) * t,
                       notch[2] + (z_rest - notch[2]) * t + 0.05 * math.sin(math.pi * t))
                rot = base_rot + (0.8 + 0.3 * i) * (1.0 - t)
            else:                                         # settled
                pos = (rx, ry, z_rest)
            obj.location = pos
            obj.keyframe_insert("location", frame=f)
            obj.rotation_euler = (0.0, 0.0, rot)
            obj.keyframe_insert("rotation_euler", index=2, frame=f)
            obj.scale = (vis, vis, vis)
            obj.keyframe_insert("scale", frame=f)

    # 6b. THE FEED STREAM: six more chips along the open trough from the
    #     shredder's spout to the rotor's inlet hood, a sixth of a length
    #     apart and one full length per loop, so frame 64 is frame 0 exactly.
    #     Each starts inside the spout and ends inside the hood -- both solid,
    #     and the fx layer holds the base out -- so the wrap happens out of
    #     sight.
    lateral = (-0.03, 0.025, -0.01, 0.035, 0.005, -0.04)
    for i in range(6):
        obj = bpy.data.objects.get(PREFIX + "frag%d" % (5 + i))
        if obj is None:
            print("[anim] missing frag%d" % (5 + i))
            continue
        base = math.radians(20.0 + 37.0 * i)
        for f in range(frames + 1):
            t = ((f / float(frames)) + i / 6.0) % 1.0
            obj.location = L.stream_point(t, lateral[i], 0.048)
            obj.keyframe_insert("location", frame=f)
            # a slow tumble over the run, as a chip on a vibrating tray does;
            # the 60-degree mismatch at the wrap happens inside the hood
            obj.rotation_euler = (0.0, 0.0, base + math.radians(60.0) * t)
            obj.keyframe_insert("rotation_euler", index=2, frame=f)
    _constant_scales()

    # 7. the field ring and the discharge edge share `violet`: two beats a
    #    loop, phase-locked to the rotor. Peak 2.1, because Standard clips
    #    hard and a violet past that turns white and takes its hue with it.
    _mat_key("violet", "Emission Strength",
             [(0, 2.10), (frames // 4, 1.25), (frames // 2, 2.10),
              (3 * frames // 4, 1.25), (frames, 2.10)])

    # 8. the scanner lights as the batch passes under it (f8..f16)
    _mat_key("violet2", "Emission Strength",
             [(0, 0.35), (6, 0.35), (10, 2.0), (14, 2.0), (18, 0.35),
              (frames, 0.35)])

    # 9. the ejector lamp on the throat rim pulses as the batch drops in and
    #    leaves (f20..f40)
    _mat_key("violet3", "Emission Strength",
             [(0, 0.30), (18, 0.30), (22, 2.0), (38, 2.0), (42, 0.30),
              (frames, 0.30)])

    # 9b. the console screen: a slow two-beat breathe, the quietest light on
    #     the machine, so the pad reads as attended without competing with
    #     the hero
    _mat_key("violet4", "Emission Strength",
             [(0, 0.6), (frames // 4, 1.2), (frames // 2, 0.6),
              (3 * frames // 4, 1.2), (frames, 0.6)])

    # 10. two arcs across the field gap: irregular on purpose, fixed so the
    #     render is reproducible, closing on `frames` like everything else
    pattern = [(3, 3), (11, 2), (21, 4), (33, 2), (39, 5), (53, 3)]
    for i in range(2):
        obj = bpy.data.objects.get(PREFIX + "arc%d" % i)
        if obj is None:
            continue
        keys = [(0, 0.0)]
        for j, (at, dur) in enumerate(pattern):
            if j % 2 != i:
                continue
            a = at % frames
            keys += [(a, 1.0), (min(a + dur, frames - 1), 1.0),
                     (min(a + dur + 1, frames), 0.0)]
        keys.append((frames, 0.0))
        for idx in (0, 1, 2):
            gen._key(obj, "scale", keys, index=idx, interp="CONSTANT")


def _fcurves(obj):
    """Blender 4.4+ slotted actions and the older flat ones alike."""
    if obj.animation_data is None or obj.animation_data.action is None:
        return []
    act = obj.animation_data.action
    if hasattr(act, "fcurves"):
        return list(act.fcurves)
    try:
        slot = obj.animation_data.action_slot
        for layer in act.layers:
            for strip in layer.strips:
                return list(strip.channelbag(slot).fcurves)
    except Exception:
        pass
    return []


def _constant_scales():
    """The chips' visibility is a switch, not a fade: hold scale keys."""
    for i in range(11):
        obj = bpy.data.objects.get(PREFIX + "frag%d" % i)
        if obj is None:
            continue
        for fc in _fcurves(obj):
            if fc.data_path == "scale":
                for kp in fc.keyframe_points:
                    kp.interpolation = "CONSTANT"
            elif fc.data_path in ("location", "rotation_euler"):
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
