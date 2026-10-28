"""v8 (review 25: the slope still L*39 at hue 108 against the goal's L*45 at 95): leaves lighter, more olive
(albedo hue ~120: the warm light renders it ~15 degrees yellower).
v7 (review 24: the bank L*36 at hue 110 against the goal's L*45): leaves lighter and warmer.
v6 (capture pr18: shadows in the bank far darker than the goal's, p10 L* 5-9 vs 17-27): leaves lighter.
v3 (capture pr14: a pale lime fern field with white-reading flowers): darker leaves, saturated petals,
less self-light by day.
v2 (render flora-v2: spindly, small flowers on tall stems): leafier bases, bigger and more flowers.
Bioluminescent flower and leaf family from ChatGPT sheet mush-sheet-flora-01: five flowers (glowing
blue bell, cyan star, lavender trumpet lily, pink cluster, ivory cup) and four leaf clumps (broad round
leaf, fern, sword leaf, clover mat). Heights from the sheet (0.5 m bar = 95 px). One glb per plant.
Usage: blender -b -P flora.py -- <out_dir> <render_prefix.png>"""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector, Matrix

out_dir, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out_dir, exist_ok=True)

def mats():
    return {
        "leaf": L.mat("leaf_deep", "#62783a", 0.85),
        "leaf2": L.mat("leaf_olive", "#8a8a4a", 0.85),
        "fern": L.mat("fern", "#7e8a42", 0.85),
        "stem": L.mat("stem", "#3c5426", 0.85),
        "bell": L.mat("petal_iceblue", "#7590ea", 0.6, "#6f9cff", 0.35),
        "star": L.mat("petal_cyan", "#4fb4e6", 0.6, "#52c4ff", 0.35),
        "lav": L.mat("petal_lavender", "#a273de", 0.6, "#a878ff", 0.2),
        "pink": L.mat("petal_pink", "#de6fae", 0.7),
        "ivory": L.mat("petal_ivory", "#e8d9c0", 0.6, "#fff0d0", 0.12),
        "core": L.mat("glow_core", "#ffdc8e", 0.4, "#ffd27a", 3.0),
        "stamen": L.mat("stamen", "#f2cf72", 0.6),
        "white": L.mat("tiny_white", "#f4f1e4", 0.7),
    }

def strip(name, pts, widths, normal_up, mat, fold=0.25, smooth=True):
    """A leaf/petal ribbon along points pts (Vectors) with half-widths; the cross-section folds up by
    `fold` x width along the midrib. normal_up: a vector giving the ribbon's 'up' side."""
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(normal_up).normalized()
        if side.length < 0.5: side = Vector((1, 0, 0))
        up = side.cross(t).normalized()
        w = widths[i]
        verts += [p - side * w + up * (-fold * w), p + up * (fold * w * 0.0), p + side * w + up * (-fold * w)]
    for i in range(n - 1):
        a = i * 3
        faces += [(a, a + 3, a + 4, a + 1), (a + 1, a + 4, a + 5, a + 2)]
    ob = L.obj_from(name, verts, faces, mat, smooth=smooth)
    sol = ob.modifiers.new("solid", "SOLIDIFY"); sol.thickness = 0.008; sol.offset = 0.0
    return ob

def curve(p0, d0, length, droop, n=8, side_bend=Vector((0, 0, 0))):
    """Points from p0 heading d0, bending down by `droop` (fraction of length) and sideways."""
    pts = []
    for i in range(n):
        t = i / (n - 1)
        p = p0 + d0 * (length * t) + Vector((0, 0, -droop * length * t * t)) + side_bend * (t * t)
        pts.append(p)
    return pts

def leaf(name, base, yaw, length, width, rise, droop, mat, shape="ovate"):
    d = Vector((math.cos(yaw) * math.cos(rise), math.sin(yaw) * math.cos(rise), math.sin(rise)))
    pts = curve(Vector(base), d, length, droop)
    n = len(pts)
    if shape == "ovate":
        ws = [width * max(0.05, math.sin(math.pi * min(1.0, (i / (n - 1)) * 1.08)) ** 0.8) for i in range(n)]
    else:  # strap / sword
        ws = [width * max(0.04, (1.0 - (i / (n - 1)) ** 1.6)) for i in range(n)]
    return strip(name, pts, ws, Vector((0, 0, 1)), mat)

def tube(name, pts, r, mat, sides=5):
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized(); b = t.cross(a)
        rr = r * (1.0 - 0.4 * i / (n - 1))
        for k in range(sides):
            th = 2 * math.pi * k / sides
            verts.append(p + (a * math.cos(th) + b * math.sin(th)) * rr)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
    return L.obj_from(name, verts, faces, mat)

def orient(ob, at, direction):
    """Point the object's +Z along direction and move it to `at`."""
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized())
    ob.location = at

def petals_flower(name, at, direction, n, length, width, cup, mat, core_mat, core_r=0.05, flare=0.0):
    """n petals around an axis: each petal leaves the centre at elevation `cup` (rad above the flower plane)
    and curls back by `flare`."""
    objs = []
    for k in range(n):
        a = 2 * math.pi * k / n
        pts = []
        for i in range(6):
            t = i / 5
            el = cup * (1 - t) + (cup - flare) * t
            r = length * t
            pts.append(Vector((math.cos(a) * r * math.cos(el), math.sin(a) * r * math.cos(el), length * t * math.sin(cup) * (1 - 0.5 * t) + length * t * t * math.sin(-flare) * 0.4)))
        ws = [width * max(0.08, math.sin(math.pi * min(1.0, t / 5 * 1.1 + 0.05)) ** 0.7) for t in range(6)]
        ob = strip("%s_p%d" % (name, k), pts, ws, Vector((0, 0, 1)), mat, fold=0.3)
        objs.append(ob)
    core = L.blob(name + "_core", core_r, (0, 0, core_r * 0.6), core_mat, sub=1, jitter=0.05)
    objs.append(core)
    # group: parent to an empty, orient the empty
    emp = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(emp)
    for o in objs: o.parent = emp
    orient(emp, Vector(at), direction)
    return emp

def bell_flower(name, at, mats_, size):
    prof = [(0.0, 0.0), (0.18, 0.02), (0.38, 0.1), (0.48, 0.3), (0.5, 0.55), (0.56, 0.8), (0.66, 0.95), (0.6, 1.0)]
    prof = [(r * size, -z * size) for r, z in prof]  # hangs down from its stalk point
    ob = L.lathe(name, prof, 12, mats_["bell"], deform=lambda x, y, z, th, i: (x * (1 + 0.12 * math.cos(6 * th) * (i >= 6)), y * (1 + 0.12 * math.cos(6 * th) * (i >= 6)), z))
    core = L.blob(name + "_core", size * 0.22, (0, 0, -size * 0.7), mats_["core"], sub=1, jitter=0.05)
    emp = bpy.data.objects.new(name + "_g", None); bpy.context.scene.collection.objects.link(emp)
    ob.parent = emp; core.parent = emp
    emp.location = at
    return emp

def finish(tag, x_off):
    """Join this plant's objects by material and export it."""
    bpy.context.view_layer.update()
    for o in list(bpy.context.scene.objects):
        if o.type == "EMPTY":
            # apply parent transforms
            for c in o.children:
                mw = c.matrix_world.copy(); c.parent = None; c.matrix_world = mw
            bpy.data.objects.remove(o)
    names = list(L.join_by_material())
    tris = L.tri_count()
    path = os.path.join(out_dir, "flora_%s.glb" % tag)
    L.export_glb(path)
    print("EXPORTED", tag, tris, os.path.getsize(path))

PLANTS = []
def plant(fn):
    PLANTS.append(fn); return fn

@plant
def bell():
    M = mats(); rnd = random.Random(1)
    for k in range(8):
        leaf("lf%d" % k, (0, 0, 0), rnd.uniform(0, 6.28), rnd.uniform(0.4, 0.58), 0.07, rnd.uniform(0.7, 1.1), 0.45, M["leaf"], "strap")
    for s in range(3):
        yaw = 2 * math.pi * s / 3 + rnd.uniform(-0.3, 0.3)
        d = Vector((math.cos(yaw) * 0.25, math.sin(yaw) * 0.25, 1.0)).normalized()
        pts = []
        h = rnd.uniform(0.85, 1.05)
        for i in range(9):
            t = i / 8
            # rises then arches over
            pts.append(Vector((math.cos(yaw) * 0.32 * h * t ** 1.6, math.sin(yaw) * 0.32 * h * t ** 1.6, h * math.sin(t * math.pi * 0.62) / math.sin(math.pi * 0.62))))
        tube("st%d" % s, pts, 0.012, M["stem"])
        for b in range(3):
            p = pts[8 - b * 2] + Vector((0, 0, -0.04))
            bell_flower("bl%d_%d" % (s, b), p, M, rnd.uniform(0.09, 0.115))
    finish("bell", 0)

@plant
def star():
    M = mats(); rnd = random.Random(2)
    for k in range(9):
        leaf("lf%d" % k, (0, 0, 0), rnd.uniform(0, 6.28), rnd.uniform(0.45, 0.65), 0.075, rnd.uniform(0.6, 1.0), 0.45, M["leaf"], "strap")
    for s in range(7):
        yaw = rnd.uniform(0, 6.28); h = rnd.uniform(0.5, 0.9)
        top = Vector((math.cos(yaw) * 0.18, math.sin(yaw) * 0.18, h))
        tube("st%d" % s, [Vector((0, 0, 0)).lerp(top, t / 6) for t in range(7)], 0.01, M["stem"])
        petals_flower("fl%d" % s, top, (math.cos(yaw) * 0.6, math.sin(yaw) * 0.6, 1.0), 6, 0.15, 0.05, 0.35, M["star"], M["core"], 0.03)
    finish("star", 0)

@plant
def lily():
    M = mats(); rnd = random.Random(3)
    for k in range(6):
        leaf("lf%d" % k, (0, 0, 0.02), 2 * math.pi * k / 6 + rnd.uniform(-0.3, 0.3), rnd.uniform(0.55, 0.72), 0.14, rnd.uniform(0.6, 0.95), 0.4, M["leaf"], "ovate")
    top = Vector((0.02, 0.0, 0.95))
    tube("st", [Vector((0, 0, 0)).lerp(top, t / 7) for t in range(8)], 0.016, M["stem"])
    for k in range(3):
        leaf("sl%d" % k, (0, 0, 0.35 + 0.22 * k), rnd.uniform(0, 6.28), 0.3, 0.05, 0.6, 0.5, M["leaf"], "strap")
    petals_flower("fl", top, (0.25, 0.0, 1.0), 6, 0.36, 0.1, 1.0, M["lav"], M["core"], 0.04, flare=1.0)
    for s in range(5):
        a = 2 * math.pi * s / 5
        p0 = top + Vector((0, 0, 0.03))
        p1 = top + Vector((math.cos(a) * 0.06 + 0.05, math.sin(a) * 0.06, 0.2))
        tube("sta%d" % s, [p0.lerp(p1, t / 3) for t in range(4)], 0.004, M["stamen"], sides=4)
        L.blob("anth%d" % s, 0.012, tuple(p1), M["stamen"], sub=1, jitter=0.05)
    finish("lily", 0)

@plant
def pink():
    M = mats(); rnd = random.Random(4)
    for k in range(7):
        leaf("lf%d" % k, (0, 0, 0), rnd.uniform(0, 6.28), rnd.uniform(0.35, 0.5), 0.06, rnd.uniform(0.5, 0.9), 0.4, M["leaf2"], "strap")
    for s in range(4):
        yaw = rnd.uniform(0, 6.28); h = rnd.uniform(0.7, 1.0)
        top = Vector((math.cos(yaw) * 0.15, math.sin(yaw) * 0.15, h))
        tube("st%d" % s, [Vector((0, 0, 0)).lerp(top, t / 6) for t in range(7)], 0.01, M["stem"])
        for f in range(6):
            q = top + Vector((rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12), rnd.uniform(-0.14, 0.05)))
            petals_flower("fl%d_%d" % (s, f), q, (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 1.0), 5, 0.06, 0.03, 0.15, M["pink"], M["stamen"], 0.014)
    finish("pink", 0)

@plant
def cup():
    M = mats(); rnd = random.Random(5)
    for k in range(5):
        leaf("lf%d" % k, (0, 0, 0.02), 2 * math.pi * k / 5 + rnd.uniform(-0.3, 0.3), rnd.uniform(0.42, 0.58), 0.13, rnd.uniform(0.5, 0.8), 0.45, M["leaf"], "ovate")
    top = Vector((0.0, 0.0, 0.72))
    tube("st", [Vector((0, 0, 0)).lerp(top, t / 6) for t in range(7)], 0.015, M["stem"])
    leaf("sl", (0, 0, 0.5), 1.0, 0.25, 0.06, 0.5, 0.4, M["leaf"], "ovate")
    petals_flower("fl", top, (0.2, 0.0, 1.0), 5, 0.22, 0.12, 0.95, M["ivory"], M["core"], 0.05, flare=0.35)
    finish("cup", 0)

@plant
def broadleaf():
    M = mats(); rnd = random.Random(6)
    for k in range(9):
        leaf("lf%d" % k, (0, 0, 0.02), 2 * math.pi * k / 9 + rnd.uniform(-0.2, 0.2), rnd.uniform(0.38, 0.5), 0.13, rnd.uniform(0.35, 0.8), 0.45, M["leaf"], "ovate")
    for s in range(0):
        yaw = rnd.uniform(0, 6.28)
        top = Vector((math.cos(yaw) * 0.08, math.sin(yaw) * 0.08, rnd.uniform(0.45, 0.6)))
        tube("st%d" % s, [Vector((0, 0, 0)).lerp(top, t / 4) for t in range(5)], 0.008, M["stem"])
        # v5: no flower heads (capture pr16: dozens of small ivory heads read as a white flower field)
        pass
    finish("broadleaf", 0)

@plant
def fern():
    M = mats(); rnd = random.Random(7)
    for k in range(8):
        yaw = 2 * math.pi * k / 8 + rnd.uniform(-0.2, 0.2)
        rise = rnd.uniform(0.75, 1.2)
        length = rnd.uniform(0.9, 1.25)
        d = Vector((math.cos(yaw) * math.cos(rise), math.sin(yaw) * math.cos(rise), math.sin(rise)))
        pts = curve(Vector((0, 0, 0)), d, length, 0.45, n=10)
        tube("ra%d" % k, pts, 0.008, M["stem"], sides=4)
        # leaflets: alternating small tapered blades along the rachis, shorter toward the tip
        for i in range(1, 9):
            t = i / 9
            p = pts[i]
            tan = (pts[min(i + 1, 9)] - pts[i - 1]).normalized()
            side = tan.cross(Vector((0, 0, 1))).normalized()
            for sg in (-1, 1):
                ll = 0.16 * (1 - t) + 0.04
                q = [p + (side * sg * ll + tan * 0.04) * (j / 3) for j in range(4)]
                strip("lt%d_%d_%d" % (k, i, sg), q, [0.028 * (1 - 0.8 * j / 3) for j in range(4)], Vector((0, 0, 1)), M["fern"], fold=0.1)
    finish("fern", 0)

@plant
def sword():
    M = mats(); rnd = random.Random(8)
    for k in range(12):
        leaf("lf%d" % k, (0, 0, 0), 2 * math.pi * k / 12 + rnd.uniform(-0.25, 0.25), rnd.uniform(0.6, 0.85), 0.06, rnd.uniform(0.9, 1.3), 0.35, M["leaf"] if k % 3 else M["leaf2"], "strap")
    finish("sword", 0)

@plant
def clover():
    M = mats(); rnd = random.Random(9)
    for k in range(18):
        a = rnd.uniform(0, 6.28); r = rnd.uniform(0.0, 0.3)
        base = Vector((math.cos(a) * r, math.sin(a) * r, rnd.uniform(0.12, 0.26)))
        for lobe in range(3):
            la = rnd.uniform(0, 6.28) + lobe * 2.09
            L.blob("cl%d_%d" % (k, lobe), 0.05, tuple(base + Vector((math.cos(la) * 0.045, math.sin(la) * 0.045, 0))), M["leaf"], squash=(1.0, 1.0, 0.18), sub=1, seed=k * 3 + lobe)
    for f in range(5):
        a = rnd.uniform(0, 6.28); r = rnd.uniform(0.0, 0.25)
        pass
    finish("clover", 0)

for fn in PLANTS:
    L.reset()
    fn()

# overview render: load all plants side by side
L.reset()
x = 0.0
for tag in ["bell", "star", "lily", "pink", "cup", "broadleaf", "fern", "sword", "clover"]:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(out_dir, "flora_%s.glb" % tag))
    for o in set(bpy.context.scene.objects) - before:
        if o.parent is None: o.location.x += x
    x += 1.4
files = L.sheet_render(out_png, 13.0, center=(5.6, 0, 0.6), res=(4608, 1536),
                       views=[("front", (0, -60, 0), (90, 0, 0)), ("top", (0, 0, 60), (0, 0, 0)), ("hero", (-3, -14, 7), None)])
print("RENDERS", files)
