"""Plant-building helpers shared by flora.py and shore.py (extracted from flora.py): leaf/petal ribbons,
tubes, petal flowers, bell flowers, and finish() which joins by material and exports OUT_DIR/PREFIX<tag>.glb."""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
OUT_DIR = "."
PREFIX = "flora_"
from mathutils import Vector, Matrix


def mats():
    return {
        "leaf": L.mat("leaf_deep", "#3f6a35", 0.85),
        "leaf2": L.mat("leaf_olive", "#6a7a3e", 0.85),
        "fern": L.mat("fern", "#66813a", 0.85),
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
    path = os.path.join(OUT_DIR, PREFIX + "%s.glb" % tag)
    L.export_glb(path)
    print("EXPORTED", tag, tris, os.path.getsize(path))
