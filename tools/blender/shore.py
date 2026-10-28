"""MUSH lake-shore kit from the ChatGPT sheet mush-sheet-shore-01 (v2, review 25: cattail heads read dark maroon
and the corner bank dark: tan heads, lighter reed and rush greens): cattail (1.8 m), reed with plumes (1.4 m),
rush tuft (0.5 m), iris (0.8 m), three wet mossy rocks, two half-submerged stones and a lily-pad cluster.
One glb per piece in <out_dir>/shore_<tag>.glb, plus an overview sheet render.
Usage: blender -b -P shore.py -- <out_dir> <render_prefix.png>"""
import bpy, bmesh, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
import floralib as F
from mathutils import Vector

out_dir, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out_dir, exist_ok=True)
F.OUT_DIR = out_dir
F.PREFIX = "shore_"

def mats():
    return {
        "reed": L.mat("reed_green", "#6a8a38", 0.85),
        "olive": L.mat("reed_olive", "#8b8a3c", 0.85),
        "rush": L.mat("rush_grass", "#96b646", 0.85),
        "stem": L.mat("reed_stem", "#6e7a3a", 0.85),
        "cattail": L.mat("cattail_head", "#b08a5a", 0.9),
        "spike": L.mat("cattail_spike", "#b49a6a", 0.9),
        "plume": L.mat("reed_plume", "#c6a66c", 0.95),
        "iris_leaf": L.mat("iris_leaf", "#4f7a3a", 0.85),
        "iris": L.mat("petal_iris", "#9a74d8", 0.6, "#a47cff", 0.15),
        "iris_core": L.mat("iris_core", "#f2cf62", 0.6),
        "dry": L.mat("stone_dry", "#a39a9e", 0.85),
        "wet": L.mat("stone_wet", "#5f5c5d", 0.35),
        "moss": L.mat("moss_wet", "#5f7a2c", 0.95),
        "pad": L.mat("lily_pad", "#6c9a3c", 0.7),
        "pad2": L.mat("lily_pad_young", "#8db24a", 0.7),
    }

PIECES = []
def piece(fn):
    PIECES.append(fn); return fn

@piece
def cattail():
    M = mats(); rnd = random.Random(11)
    for k in range(19):
        m = M["reed"] if k % 3 else M["olive"]
        F.leaf("lf%d" % k, (rnd.uniform(-0.07, 0.07), rnd.uniform(-0.07, 0.07), 0), rnd.uniform(0, 6.28),
               rnd.uniform(1.0, 1.75), rnd.uniform(0.03, 0.042), math.radians(rnd.uniform(78, 88)), rnd.uniform(0.04, 0.16), m, "strap")
    for s in range(4):
        yaw = 2 * math.pi * s / 4 + rnd.uniform(-0.4, 0.4)
        h = rnd.uniform(1.45, 1.8)
        lean = rnd.uniform(0.04, 0.1)
        top = Vector((math.cos(yaw) * lean * h, math.sin(yaw) * lean * h, h))
        pts = [Vector((0, 0, 0)).lerp(top, t / 7) for t in range(8)]
        F.tube("st%d" % s, pts, 0.008, M["stem"])
        d = (top - pts[0]).normalized()
        hl = rnd.uniform(0.16, 0.21)
        c0 = top - d * (0.12 + hl)
        prof = [(0.0, 0.0), (0.02, 0.0), (0.029, 0.02), (0.031, hl * 0.5), (0.028, hl - 0.015), (0.012, hl), (0.0, hl)]
        head = L.lathe("hd%d" % s, prof, 10, M["cattail"])
        F.orient(head, c0, d)
        F.tube("sp%d" % s, [c0 + d * (hl + 0.0), c0 + d * (hl + 0.06), c0 + d * (hl + 0.11)], 0.004, M["spike"], sides=4)
    F.finish("cattail", 0)

@piece
def reed():
    M = mats(); rnd = random.Random(12)
    for k in range(18):
        m = M["olive"] if k % 2 else M["reed"]
        F.leaf("lf%d" % k, (rnd.uniform(-0.06, 0.06), rnd.uniform(-0.06, 0.06), 0), rnd.uniform(0, 6.28),
               rnd.uniform(0.7, 1.25), rnd.uniform(0.018, 0.026), math.radians(rnd.uniform(62, 84)), rnd.uniform(0.25, 0.45), m, "strap")
    for s in range(3):
        yaw = 2 * math.pi * s / 3 + rnd.uniform(-0.5, 0.5)
        h = rnd.uniform(1.22, 1.42)
        top = Vector((math.cos(yaw) * 0.12 * h, math.sin(yaw) * 0.12 * h, h))
        pts = [Vector((0, 0, 0)).lerp(top, t / 7) + Vector((math.cos(yaw), math.sin(yaw), 0)) * 0.04 * math.sin(math.pi * t / 7) for t in range(8)]
        F.tube("st%d" % s, pts, 0.007, M["stem"])
        # Feathery plume: a nodding spray of thin strips from the stem tip.
        d = (top - pts[5]).normalized()
        for p in range(9):
            a = rnd.uniform(0, 6.28)
            dd = (d + Vector((math.cos(a), math.sin(a), 0)) * 0.35 + Vector((math.cos(yaw), math.sin(yaw), 0)) * 0.4).normalized()
            base = top - d * rnd.uniform(0.0, 0.16)
            pp = F.curve(base, dd, rnd.uniform(0.14, 0.24), 0.35, n=5)
            F.strip("pl%d_%d" % (s, p), pp, [0.012, 0.022, 0.024, 0.016, 0.004], Vector((0, 0, 1)), M["plume"], fold=0.1)
    F.finish("reed", 0)

@piece
def rush():
    M = mats(); rnd = random.Random(13)
    for k in range(34):
        m = M["rush"] if k % 4 else M["reed"]
        F.leaf("lf%d" % k, (rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05), 0), rnd.uniform(0, 6.28),
               rnd.uniform(0.28, 0.52), rnd.uniform(0.008, 0.013), math.radians(rnd.uniform(66, 88)), rnd.uniform(0.08, 0.3), m, "strap")
    F.finish("rush", 0)

@piece
def iris():
    M = mats(); rnd = random.Random(14)
    fan = rnd.uniform(0, 3.14)
    for k in range(10):
        yaw = fan + (0 if k % 2 else math.pi) + rnd.uniform(-0.35, 0.35)
        F.leaf("lf%d" % k, (rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), 0), yaw,
               rnd.uniform(0.42, 0.68), rnd.uniform(0.026, 0.034), math.radians(rnd.uniform(74, 86)), rnd.uniform(0.04, 0.12), M["iris_leaf"], "strap")
    for s in range(3):
        yaw = fan + math.pi / 2 + s * 2.1 + rnd.uniform(-0.3, 0.3)
        h = rnd.uniform(0.72, 0.82)
        top = Vector((math.cos(yaw) * 0.06, math.sin(yaw) * 0.06, h))
        F.tube("st%d" % s, [Vector((0, 0, 0)).lerp(top, t / 6) for t in range(7)], 0.006, M["iris_leaf"])
        # Three drooping falls under three upright standards.
        F.petals_flower("fa%d" % s, top, (0, 0, 1), 3, 0.1, 0.042, 0.25, M["iris"], M["iris_core"], 0.012, flare=1.1)
        st = F.petals_flower("sd%d" % s, top + Vector((0, 0, 0.005)), (0, 0, 1), 3, 0.08, 0.03, 1.2, M["iris"], M["iris_core"], 0.008)
        st.rotation_mode = "XYZ"; st.rotation_euler = (0, 0, math.pi / 3)
    F.finish("iris", 0)

def mossy_rock(name, size, seed, M, n=40, bevel=0.06, sink=0.0):
    """Faceted convex-hull boulder (as promontory3's rock()); faces facing up carry moss, low faces are wet."""
    r2 = random.Random(seed)
    bm = bmesh.new()
    for _ in range(n):
        th = r2.uniform(0, 2 * math.pi); ph = math.acos(r2.uniform(-1, 1))
        rr = r2.uniform(0.9, 1.0)
        z = rr * math.cos(ph) * size[2] * 0.5
        bm.verts.new((rr * math.sin(ph) * math.cos(th) * size[0] * 0.5, rr * math.sin(ph) * math.sin(th) * size[1] * 0.5, max(z, -size[2] * 0.32)))
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    for m in (M["dry"], M["wet"], M["moss"]): ob.data.materials.append(m)
    zlo = min(v.co.z for v in me.vertices); zhi = max(v.co.z for v in me.vertices)
    for p in me.polygons:
        c = p.center; t = (c.z - zlo) / max(zhi - zlo, 1e-3)
        ns = r2.uniform(-0.12, 0.12)
        if p.normal.z > 0.72 + ns and t > 0.5 and r2.random() < 0.7: p.material_index = 2
        elif t < 0.3 + ns: p.material_index = 1
        else: p.material_index = 0
    for v in me.vertices: v.co.z -= zlo + sink
    md = ob.modifiers.new("bevel", "BEVEL"); md.width = bevel; md.segments = 1; md.limit_method = "ANGLE"
    return ob

def split_rock_by_material(ob):
    bpy.context.view_layer.objects.active = ob
    for md in list(ob.modifiers): bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.ops.object.select_all(action="DESELECT"); ob.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.separate(type="MATERIAL"); bpy.ops.object.mode_set(mode="OBJECT")
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            used = {p.material_index for p in o.data.polygons}
            if len(used) == 1:
                m = o.data.materials[list(used)[0]]
                o.data.materials.clear(); o.data.materials.append(m)
                for p in o.data.polygons: p.material_index = 0

def rock_piece(tag, parts, M):
    for i, (size, off, seed, sink) in enumerate(parts):
        ob = mossy_rock("%s%d" % (tag, i), size, seed, M, sink=sink)
        ob.location = off
        split_rock_by_material(ob)
    F.finish(tag, 0)

@piece
def rock_a():
    M = mats(); rock_piece("rock_a", [((1.7, 1.5, 1.4), (0, 0, 0), 21, 0.0)], M)

@piece
def rock_b():
    M = mats(); rock_piece("rock_b", [((0.8, 0.7, 0.85), (0, 0, 0), 22, 0.0), ((0.6, 0.55, 0.6), (0.45, 0.15, 0), 23, 0.0),
                                      ((0.5, 0.5, 0.42), (-0.3, -0.32, 0), 24, 0.0)], M)

@piece
def rock_c():
    M = mats(); rock_piece("rock_c", [((1.6, 1.1, 0.55), (0, 0, 0), 25, 0.0)], M)

@piece
def stone_sub_a():
    # Half-submerged: the origin is the waterline, a third of the stone sits under it.
    M = mats(); rock_piece("stone_sub_a", [((1.2, 1.0, 0.9), (0, 0, 0), 26, 0.3)], M)

@piece
def stone_sub_b():
    M = mats(); rock_piece("stone_sub_b", [((1.4, 0.9, 0.55), (0, 0, 0), 27, 0.18)], M)

@piece
def lilypad():
    M = mats(); rnd = random.Random(15)
    for k in range(6):
        r = rnd.uniform(0.14, 0.3)
        cx, cy = rnd.uniform(-0.6, 0.6), rnd.uniform(-0.5, 0.5)
        notch = rnd.uniform(0, 6.28); seg = 18
        verts = [(cx, cy, 0.01)]
        for i in range(seg + 1):
            a = notch + 0.32 + (2 * math.pi - 0.64) * i / seg
            rr = r * (1 + 0.04 * math.sin(5 * a))
            verts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr, 0.012 + 0.006 * (i % 2)))
        faces = [(0, i + 1, i + 2) for i in range(seg)]
        ob = L.obj_from("pad%d" % k, verts, faces, M["pad2"] if k % 3 == 0 else M["pad"], smooth=False)
        sol = ob.modifiers.new("solid", "SOLIDIFY"); sol.thickness = 0.01
    F.finish("lilypad", 0)

for fn in PIECES:
    L.reset()
    fn()

L.reset()
tags = ["cattail", "reed", "rush", "iris", "rock_a", "rock_b", "rock_c", "stone_sub_a", "stone_sub_b", "lilypad"]
gaps = [1.0, 1.0, 0.8, 1.0, 1.8, 1.5, 1.6, 1.5, 1.6, 1.6]
x = 0.0
for tag, g in zip(tags, gaps):
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(out_dir, "shore_%s.glb" % tag))
    for o in set(bpy.context.scene.objects) - before:
        if o.parent is None: o.location.x += x
    x += g
# a water plane for the submerged stones and pads
bpy.ops.mesh.primitive_plane_add(size=1, location=(x * 0.5, 0, 0.0))
wp = bpy.context.active_object; wp.scale = (x + 2, 3, 1); wp.data.materials.append(L.mat("water", "#7fa6c0", 0.2))
files = L.sheet_render(out_png, x + 2.0, center=(x * 0.5 - 0.5, 0, 0.8), res=(4608, 1536),
                       views=[("front", (0, -60, 0), (90, 0, 0)), ("top", (0, 0, 60), (0, 0, 0)), ("hero", (-3, -14, 7), None)])
print("RENDERS", files)
