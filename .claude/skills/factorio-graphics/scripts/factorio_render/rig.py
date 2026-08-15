"""Blender-side rig: the render settings every Factorio sprite needs.

Import inside Blender only (`bpy`). The numbers here are the validated ones
from SKILL.md -- 64 px/tile, the 45-degree military projection with the
pixel-aspect compensation that squares the ground plane, the upper-left key
sun, Standard view transform, transparent film.

The performance half is not a nicety. Measured on this machine (Ryzen 7 5800,
RX 6800 XT, Blender 5.2, the beacon scene at 512x640 / 96 samples):

    build the scene from the generator      62.9 s   every invocation
    open the saved .blend instead            0.18 s
    one frame, Cycles CPU                   16-17 s
    one frame, Cycles GPU (HIP)            6.9-7.6 s
    one frame, GPU + persistent data          2.2 s   (repeat renders)
    one bordered anim frame, GPU+persist     0.83 s
    24 samples vs 96 samples            6.34 vs 6.96 s

So samples are almost free and the fixed per-call cost is everything: a
"render one frame and look at it" loop went from ~80 s to ~2.5 s by switching
the device, reusing the .blend and turning persistent data on. Iteration count
is what art quality is actually made of, so treat that as a quality setting
rather than a performance one.
"""

import math

import bpy


PX_PER_TILE = 64            # source art; declared scale = 0.5 halves it in game
PIXEL_ASPECT_X = 1.41421    # 1/cos(45) -- squares the foreshortened ground plane
KEY_ENERGY = 5.2
FILL_ENERGY = 1.2
WORLD_STRENGTH = 0.22


def use_gpu(scene, prefer=("OPTIX", "HIP", "CUDA", "ONEAPI")):
    """Point Cycles at a GPU if there is one, otherwise stay on CPU.

    Never assume: `cycles.device = "GPU"` with no usable compute device falls
    back silently and you pay CPU time while believing otherwise. Returns the
    backend actually selected, or None.
    """
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for backend in prefer:
        try:
            prefs.compute_device_type = backend
        except TypeError:
            continue          # this build has no such backend
        prefs.get_devices()
        devices = [d for d in prefs.devices if d.type == backend]
        if not devices:
            continue
        for d in prefs.devices:
            d.use = (d.type == backend)
        scene.cycles.device = "GPU"
        print("[rig] Cycles on %s: %s" % (backend, ", ".join(d.name for d in devices)))
        return backend
    scene.cycles.device = "CPU"
    print("[rig] no GPU backend available -- rendering on CPU")
    return None


def cycles(scene, samples=96, denoise=True, transparent_bounces=128,
           persistent=True, gpu=True):
    """Engine settings. Cycles, not EEVEE: pointiness and the AO node -- the
    whole wear stack in references/materials.md -- flatten out in EEVEE, and
    the shadow catcher needs Cycles anyway.

    `transparent_bounces` matters more than it looks. A material override that
    makes every surface semi-transparent (a frozen patch) sends camera rays
    through far more than the default 8 transparent surfaces; past the limit
    Cycles returns OPAQUE BLACK, which lands as soot blotches over exactly the
    densest greeble and looks like a shading bug.

    `persistent` keeps the BVH between renders. Measured 3.4x on repeat
    renders of the same layer. Turn it off around a material_override swap --
    it is caching exactly the data an override invalidates.
    """
    scene.render.engine = "CYCLES"
    if gpu:
        use_gpu(scene)
    else:
        scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = denoise
    scene.cycles.transparent_max_bounces = transparent_bounces
    scene.render.use_persistent_data = persistent


def output(scene, canvas, ortho_scale=None):
    """Canvas, pixel aspect, colour management, film.

    Factorio needs View Transform **Standard**; Blender defaults to AgX, which
    washes art out relative to vanilla. Standard clips hard, so emission has to
    stay low -- keep the max emitted channel (colour x strength) near 1.0-1.1
    or a coloured glow turns white and takes its hue with it.
    """
    scene.render.resolution_x, scene.render.resolution_y = canvas
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = PIXEL_ASPECT_X
    scene.render.pixel_aspect_y = 1.0
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    if ortho_scale and scene.camera:
        scene.camera.data.ortho_scale = ortho_scale


def camera(scene, canvas, name="FR_Cam"):
    """Orthographic, pitched 45 degrees, targeting the world origin.

    ortho_scale follows from the canvas: px/tile = resolution_x / ortho_scale,
    so a canvas resized without changing ortho_scale silently rescales the
    whole sprite. Always re-run the footprint gate after touching either.
    """
    data = bpy.data.cameras.new(name)
    data.type = "ORTHO"
    data.ortho_scale = canvas[0] / PX_PER_TILE
    data.sensor_fit = "HORIZONTAL"
    data.clip_start, data.clip_end = 0.1, 1000.0
    obj = bpy.data.objects.new(name, data)
    obj.location = (0, -60, 60)
    obj.rotation_euler = (math.radians(45), 0, 0)
    scene.collection.objects.link(obj)
    scene.camera = obj
    return obj


def lights(scene, key=KEY_ENERGY, fill=FILL_ENERGY, ambient=WORLD_STRENGTH):
    """Key from the upper LEFT so shadows fall right.

    Vanilla-verified: assembling-machine-1-shadow is shifted +44.5 px in X.
    The sign is the trap -- the community value (+39.3) casts shadows LEFT for
    this rig; -39.3 is what puts the sun upper-left. The stock add-on rig
    leaves the camera-facing side black, which is why the fill exists.
    """
    kd = bpy.data.lights.new("FR_Key", "SUN")
    kd.energy = key
    ko = bpy.data.objects.new("FR_Key", kd)
    ko.rotation_euler = (0, math.radians(-39.3), math.radians(5))
    scene.collection.objects.link(ko)

    fd = bpy.data.lights.new("FR_Fill", "SUN")
    fd.energy = fill
    fo = bpy.data.objects.new("FR_Fill", fd)
    fo.rotation_euler = (math.radians(45), 0, 0)
    scene.collection.objects.link(fo)

    world = bpy.data.worlds.new("FR_World")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (1, 1, 1, 1)
    bg.inputs["Strength"].default_value = ambient
    scene.world = world
    return ko, fo


def passes(view_layer, ao=True, normal=True, cryptomatte=False):
    """Extra passes, for the cases where they earn their cost.

    **They did not earn it for entity sprites here** -- an AO pass changed the
    paint-over by mean 2/255 and came out slightly *worse* on the contrast
    metric, because at 64 px/tile the crevices are 1-2 px wide and every
    material in the wear stack already carries its own AO node. Measured, not
    assumed; the numbers are in references/pipeline.md.

    Getting a pass OUT of Blender 5.2 is also no longer a compositor job:
    `Scene.node_tree` is gone (it is `Scene.compositing_node_group` now),
    `CompositorNodeComposite` no longer exists, and `CompositorNodeOutputFile`
    has no `file_slots`. Rendering the quantity you want through a
    `material_override` is simpler than any of that and needs no OpenEXR
    reader -- `post.py`'s AO experiment did exactly that.
    """
    view_layer.use_pass_ambient_occlusion = ao
    view_layer.use_pass_normal = normal
    view_layer.use_pass_cryptomatte_object = cryptomatte
    view_layer.use_pass_cryptomatte_material = cryptomatte


def scene_from_blend(path):
    """Reuse a saved .blend instead of rebuilding geometry (0.18 s vs 62.9 s).

    The generator stays the source of truth -- regenerate the .blend whenever
    it changes -- but nothing is gained by re-running it to look at one frame.
    """
    bpy.ops.wm.open_mainfile(filepath=path)
    return bpy.context.scene


def empty_scene(keep_addons=()):
    """Headless Blender starts from the startup file, so the default cube is
    there. A generator that only purges its own prefixed objects will render
    that cube straight through the middle of the model.

    **This also resets preferences, which disables every installed
    extension.** Anything relying on an add-on operator has to re-enable it
    afterwards -- pass the module names in `keep_addons`, e.g.
    `"bl_ext.blender_org.boltfactory"`.
    """
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if keep_addons:
        import addon_utils
        for name in keep_addons:
            try:
                addon_utils.enable(name, default_set=False)
            except Exception as exc:
                print("[rig] could not enable %s: %s" % (name, exc))
    return bpy.context.scene
