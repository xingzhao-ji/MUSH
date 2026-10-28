"""Shared Blender helpers for MUSH assets built from ChatGPT modeling sheets.
Blender Z-up, metres; the glTF exporter turns Blender -Y into glTF +Z (the model's front)."""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def hexcol(h, a=1.0):
    h = h.lstrip("#")
    s = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in s]
    return (lin[0], lin[1], lin[2], a)

_mats = {}
def mat(name, color, rough=0.8, emit=None, emit_strength=0.0):
    if name in _mats: return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = hexcol(color)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = hexcol(emit)
        b.inputs["Emission Strength"].default_value = emit_strength
    _mats[name] = m
    return m

def obj_from(name, verts, faces, material=None, smooth=True, coll=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], faces)
    me.validate()
    me.update()
    if smooth:
        me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    ob = bpy.data.objects.new(name, me)
    (coll or bpy.context.scene.collection).objects.link(ob)
    if material is not None: ob.data.materials.append(material)
    return ob

def lathe(name, profile, segs=48, material=None, close_top=False, close_bottom=False, deform=None, smooth=True, arc=(0.0, 2 * math.pi)):
    """profile: list of (r, z). deform(x, y, z, theta, i) -> (x, y, z)."""
    full = abs(arc[1] - arc[0] - 2 * math.pi) < 1e-6
    n = segs if full else segs + 1
    verts, faces = [], []
    for j in range(n):
        th = arc[0] + (arc[1] - arc[0]) * j / segs
        for i, (r, z) in enumerate(profile):
            x, y = r * math.cos(th), r * math.sin(th)
            if deform: x, y, z2 = deform(x, y, z, th, i)
            else: z2 = z
            verts.append((x, y, z2))
    m = len(profile)
    for j in range(segs):
        j2 = (j + 1) % n
        for i in range(m - 1):
            a, b, c, d = j * m + i, j2 * m + i, j2 * m + i + 1, j * m + i + 1
            faces.append((a, b, c, d))
    # The pole vertices go through deform too (they were left at the origin, which drew spikes to the axis).
    if close_top and full:
        z = profile[-1][1]
        verts.append(deform(0.0, 0.0, z, 0.0, m - 1) if deform else (0, 0, z)); ci = len(verts) - 1
        for j in range(segs): faces.append((j * m + m - 1, ((j + 1) % n) * m + m - 1, ci))
    if close_bottom and full:
        z = profile[0][1]
        verts.append(deform(0.0, 0.0, z, 0.0, 0) if deform else (0, 0, z)); ci = len(verts) - 1
        for j in range(segs): faces.append((((j + 1) % n) * m, j * m, ci))
    return obj_from(name, verts, faces, material, smooth)

def box(name, size, loc, material=None, rot=(0, 0, 0), bevel=0.0, segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0:
        md = ob.modifiers.new("bevel", "BEVEL"); md.width = bevel; md.segments = segs; md.limit_method = "ANGLE"
    if material is not None: ob.data.materials.append(material)
    return ob

def cyl(name, r, depth, loc, material=None, rot=(0, 0, 0), verts=16, smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=loc, rotation=rot, vertices=verts)
    ob = bpy.context.active_object; ob.name = name
    if smooth: ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    if material is not None: ob.data.materials.append(material)
    return ob

def torus(name, R, r, loc, rot, material=None, maj=32, mino=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, location=loc, rotation=rot, major_segments=maj, minor_segments=mino)
    ob = bpy.context.active_object; ob.name = name
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    if material is not None: ob.data.materials.append(material)
    return ob

def blob(name, r, loc, material=None, squash=(1, 1, 1), sub=2, seed=0, jitter=0.18):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=sub, location=loc)
    ob = bpy.context.active_object; ob.name = name
    rnd = random.Random(seed)
    for v in ob.data.vertices:
        k = 1.0 + rnd.uniform(-jitter, jitter)
        v.co = Vector((v.co.x * squash[0] * k, v.co.y * squash[1] * k, v.co.z * squash[2] * k))
    ob.data.polygons.foreach_set("use_smooth", [True] * len(ob.data.polygons))
    if material is not None: ob.data.materials.append(material)
    return ob

def arch_shape(w, h, n=16):
    """Outline (x, z) of a round-topped arch, base at z=0, width w, total height h."""
    r = w / 2
    pts = [(-r, 0.0), (r, 0.0)]
    for i in range(n + 1):
        a = math.pi * i / n
        pts.append((r * math.cos(a), h - r + r * math.sin(a)))
    pts = [(-r, 0.0), (r, 0.0)] + [(r * math.cos(math.pi * i / n), h - r + r * math.sin(math.pi * i / n)) for i in range(n + 1)]
    return pts

def extrude_outline(name, pts_xz, depth, y0, material=None, smooth=False):
    """Flat prism from an (x, z) outline, from y0 to y0 - depth (towards the front, -Y)."""
    n = len(pts_xz)
    verts = [(x, y0, z) for x, z in pts_xz] + [(x, y0 - depth, z) for x, z in pts_xz]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for i in range(n):
        a, b = i, (i + 1) % n
        faces.append((a, b, b + n, a + n))
    return obj_from(name, verts, faces, material, smooth)

def join_by_material(objs_name_prefix=None):
    """Apply modifiers, then join all mesh objects into one object per material for a lean glb."""
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            bpy.context.view_layer.objects.active = ob
            for md in list(ob.modifiers):
                bpy.ops.object.modifier_apply(modifier=md.name)
    groups = {}
    for ob in list(bpy.context.scene.objects):
        if ob.type != "MESH" or not ob.data.materials: continue
        groups.setdefault(ob.data.materials[0].name, []).append(ob)
    for mname, obs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for ob in obs: ob.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1: bpy.ops.object.join()
        bpy.context.active_object.name = mname
    return groups.keys()

def tri_count():
    t = 0
    dg = bpy.context.evaluated_depsgraph_get()
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            me = ob.evaluated_get(dg).to_mesh()
            t += sum(len(p.vertices) - 2 for p in me.polygons)
    return t

def export_glb(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True)

def sheet_render(path, size_m, center=(0, 0, 2.5), res=(1536, 1024), bg="#d9d9d9", views=None):
    """Render FRONT, RIGHT, BACK, TOP, 3/4 orthographic panels into one sheet image like the ChatGPT sheets."""
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    world = bpy.data.worlds.new("w"); sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = hexcol(bg)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.view_settings.view_transform = "Standard"
    sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    sun.data.energy = 2.2; sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"; cam.data.ortho_scale = size_m
    sc.collection.objects.link(cam); sc.camera = cam
    pw, ph = res[0] // 3, res[1] // 2
    sc.render.resolution_x, sc.render.resolution_y = pw, ph
    sc.render.film_transparent = False
    c = Vector(center)
    views = views or [("front", (0, -40, 0), (90, 0, 0)), ("right", (40, 0, 0), (90, 0, 90)), ("back", (0, 40, 0), (90, 0, 180)),
                      ("top", (0, 0, 40), (0, 0, 0)), ("hero", (-24, -30, 18), None)]
    files = []
    for name, off, rot in views:
        cam.location = c + Vector(off)
        if rot is None:
            d = (c - cam.location).normalized()
            cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        else:
            cam.rotation_euler = tuple(math.radians(a) for a in rot)
        f = path.replace(".png", "-%s.png" % name)
        sc.render.filepath = f
        bpy.ops.render.render(write_still=True)
        files.append(f)
    return files
