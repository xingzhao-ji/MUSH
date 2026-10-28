"""MUSH foreground hero plants from the ChatGPT sheet mush-sheet-heroflora-01 (checkpoint 3: the lower-left needs
a few large silhouette anchors that read from 5-15 m). Thick petals with vertex-colour gradients instead of flat
colours (flora2.py's flat strips read as white blobs): a glowing ice-blue morning-glory cup, a lavender lily
pair, a pink daisy cluster, white star lilies, a mossy boulder and a broad-leaf clump with light midribs.
One glb each in <out_dir>/hero_<tag>.glb plus an overview render.
Usage: blender -b -P heroflora.py -- <out_dir> <render_prefix.png>"""
import bpy, bmesh, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector

out_dir, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out_dir, exist_ok=True)

def srgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

def ramp(stops, t):
    """stops: [(t, hex)] ascending."""
    t = max(0.0, min(1.0, t))
    for k in range(len(stops) - 1):
        t0, c0 = stops[k]; t1, c1 = stops[k + 1]
        if t <= t1:
            return mix(srgb(c0), srgb(c1), (t - t0) / max(t1 - t0, 1e-6))
    return srgb(stops[-1][1])

_vm = {}
def vmat(name, rough=0.7, emit=None, strength=0.0):
    """A material whose base colour is the mesh's 'Col' vertex colours (glTF COLOR_0)."""
    if name in _vm: return _vm[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes.get("Principled BSDF")
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = L.hexcol(emit)
        b.inputs["Emission Strength"].default_value = strength
    _vm[name] = m
    return m

def paint(ob, fn):
    me = ob.data
    attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="POINT")
    for i, v in enumerate(me.vertices):
        c = fn(v.co, i)
        attr.data[i].color_srgb = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = attr

def mesh_obj(name, verts, faces, mat, colors, smooth=True, thick=0.0):
    ob = L.obj_from(name, verts, faces, mat, smooth=smooth)
    paint(ob, lambda co, i: colors[i])
    if thick > 0:
        sol = ob.modifiers.new("solid", "SOLIDIFY"); sol.thickness = thick; sol.offset = 0.0
    return ob

def ribbon(name, pts, widths, up, mat, cols_mid, cols_edge, fold=0.25, thick=0.012):
    """Leaf/petal ribbon (3 verts a row: edge, midrib, edge) with per-row colours (midrib and edge)."""
    verts, faces, cols = [], [], []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        side = t.cross(up).normalized()
        if side.length < 0.5: side = Vector((1, 0, 0))
        upv = side.cross(t).normalized()
        w = widths[i]
        verts += [p - side * w - upv * fold * w, p, p + side * w - upv * fold * w]
        cols += [cols_edge[i], cols_mid[i], cols_edge[i]]
    for i in range(n - 1):
        a = i * 3
        faces += [(a, a + 3, a + 4, a + 1), (a + 1, a + 4, a + 5, a + 2)]
    return mesh_obj(name, verts, faces, mat, cols, thick=thick)

def curve(p0, d0, length, droop, n=8, bend=Vector((0, 0, 0))):
    return [p0 + d0 * (length * i / (n - 1)) + Vector((0, 0, -droop * length * (i / (n - 1)) ** 2)) + bend * (i / (n - 1)) ** 2 for i in range(n)]

def leaf(name, base, yaw, length, width, rise, droop, mat, dark="#2f4a30", light="#6a9448", mid="#9cbc6a", shape="ovate"):
    d = Vector((math.cos(yaw) * math.cos(rise), math.sin(yaw) * math.cos(rise), math.sin(rise)))
    pts = curve(Vector(base), d, length, droop, 9)
    n = len(pts)
    if shape == "ovate":
        ws = [width * max(0.05, math.sin(math.pi * min(1.0, (i / (n - 1)) * 1.06)) ** 0.75) for i in range(n)]
    else:
        ws = [width * max(0.04, 1.0 - (i / (n - 1)) ** 1.5) for i in range(n)]
    edge = [ramp([(0, dark), (1, light)], i / (n - 1)) for i in range(n)]
    midc = [ramp([(0, dark), (0.3, mid), (1, light)], i / (n - 1)) for i in range(n)]
    return ribbon(name, pts, ws, Vector((0, 0, 1)), mat, midc, edge, fold=0.22, thick=0.012)

def tube(name, pts, r, mat, col="#3d5a2c", sides=6, taper=0.35):
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized(); b = t.cross(a)
        rr = r * (1.0 - taper * i / (n - 1))
        for k in range(sides):
            th = 2 * math.pi * k / sides
            verts.append(p + (a * math.cos(th) + b * math.sin(th)) * rr)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
    c = srgb(col)
    return mesh_obj(name, verts, faces, mat, [c] * len(verts))

def group(name, objs, at, direction=(0, 0, 1)):
    emp = bpy.data.objects.new(name, None); bpy.context.scene.collection.objects.link(emp)
    for o in objs: o.parent = emp
    emp.rotation_mode = "QUATERNION"
    emp.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized())
    emp.location = at
    return emp

def finish(tag):
    bpy.context.view_layer.update()
    for o in list(bpy.context.scene.objects):
        if o.type == "EMPTY":
            for c in o.children:
                mw = c.matrix_world.copy(); c.parent = None; c.matrix_world = mw
            bpy.data.objects.remove(o)
    L.join_by_material()
    path = os.path.join(out_dir, "hero_%s.glb" % tag)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True, export_vertex_color="ACTIVE")
    print("EXPORTED", tag, L.tri_count(), os.path.getsize(path))

def reset():
    L.reset(); _vm.clear()

def M():
    return {"leaf": vmat("hero_leaf", 0.75), "stem": vmat("hero_stem", 0.8)}

def stamens(at, mat, n, length, col="#f5d27a", spread=0.04):
    objs = []
    for s in range(n):
        a = 2 * math.pi * s / n
        p1 = Vector((math.cos(a) * spread, math.sin(a) * spread, length))
        objs.append(tube("sta%d" % s, [Vector((0, 0, 0)).lerp(p1, t / 3) for t in range(4)], 0.004, mat, col, sides=4, taper=0.0))
        b = L.blob("anth%d" % s, 0.012, tuple(p1), mat, sub=1, jitter=0.05)
        paint(b, lambda co, i: srgb("#f2a43a"))
        objs.append(b)
    return objs

PLANTS = []
def plant(fn):
    PLANTS.append(fn); return fn

@plant
def cup():
    """Morning-glory: a funnel flaring to a wide five-lobed bowl ~0.5 m across.
    v2 (review 26: a flat pale-blue disc facing the camera, internal L* std 10 against the goal cup's 23, and a
    uniform sticker at night): a deep blue unlit throat (own material) under a glowing pale rim with lighter
    ribs and a bright core, the bowl turned ~40 degrees aside so the trumpet shows."""
    mm = M(); rnd = random.Random(31)
    rim_m = vmat("hero_petal_ice", 0.5, "#9fdcff", 0.3)
    throat_m = vmat("hero_petal_throat", 0.6)
    core_m = vmat("hero_core", 0.4, "#fff0c0", 2.0)
    for k in range(11):
        leaf("lf%d" % k, (0, 0, 0.03), 2 * math.pi * k / 11 + rnd.uniform(-0.25, 0.25), rnd.uniform(0.45, 0.62), 0.12,
             math.radians(rnd.uniform(45, 72)), rnd.uniform(0.45, 0.7), mm["leaf"])
    top = Vector((0.0, -0.04, 0.42))
    tube("st", [Vector((0, 0, 0)).lerp(top, t / 6) + Vector((0, -0.03 * math.sin(math.pi * t / 6), 0)) for t in range(7)], 0.03, mm["stem"])
    prof = [(0.025, 0.0), (0.04, 0.06), (0.06, 0.12), (0.1, 0.17), (0.16, 0.2), (0.22, 0.22), (0.26, 0.235), (0.28, 0.25)]
    segs = 60
    def part(name, i0, i1, mat, colf):
        verts, faces, cols = [], [], []
        rows = list(range(i0, i1 + 1))
        for ri, i in enumerate(rows):
            r, z = prof[i]; f = i / (len(prof) - 1)
            for k in range(segs):
                th = 2 * math.pi * k / segs
                lobe = 1.0 + 0.14 * math.cos(5 * th) * f ** 2
                dip = -0.025 * (1 - math.cos(5 * th)) * f ** 3
                verts.append((r * lobe * math.cos(th), r * lobe * math.sin(th), z + dip))
                cols.append(colf(f, max(0.0, math.cos(5 * th)) ** 4))
        for ri in range(len(rows) - 1):
            for k in range(segs):
                k2 = (k + 1) % segs
                faces.append((ri * segs + k, ri * segs + k2, (ri + 1) * segs + k2, (ri + 1) * segs + k))
        return mesh_obj(name, verts, faces, mat, cols, thick=0.018)
    throat = part("throat", 0, 3, throat_m, lambda f, rib: mix(ramp([(0, "#22397a"), (0.43, "#5a86d8")], f), srgb("#7aa6ec"), 0.4 * rib))
    rim = part("rim", 3, 7, rim_m, lambda f, rib: mix(ramp([(0.43, "#6f9fe6"), (0.7, "#a9d6f8"), (1, "#e2f7ff")], f), srgb("#f2fbff"), 0.5 * rib * f))
    core = L.blob("core", 0.03, (0, 0, 0.035), core_m, sub=2)
    paint(core, lambda co, i: srgb("#fff4cc"))
    st = stamens(Vector((0, 0, 0)), core_m, 5, 0.11, "#fff4d0", 0.02)
    group("bloom", [throat, rim, core] + st, top, (-0.5, -0.45, 1.0))
    finish("cup")

def petal_ribbon(name, length, width, cup_el, flare, mat, base_hex, tip_hex, edge_hex=None, n=7):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        el = cup_el * (1 - t) + (cup_el - flare) * t
        r = length * t
        pts.append(Vector((r * math.cos(el), 0.0, length * t * math.sin(cup_el) * (1 - 0.5 * t) - length * t * t * math.sin(flare) * 0.35)))
    ws = [width * max(0.1, math.sin(math.pi * min(1.0, t / (n - 1) * 1.08 + 0.04)) ** 0.7) for t in range(n)]
    midc = [ramp([(0, base_hex), (1, tip_hex)], i / (n - 1)) for i in range(n)]
    edge = [ramp([(0, base_hex), (1, edge_hex or tip_hex)], i / (n - 1)) for i in range(n)]
    return ribbon(name, pts, ws, Vector((0, 0, 1)), mat, midc, edge, fold=0.3, thick=0.02)

def bloom(name, at, direction, n, length, width, cup_el, flare, mat, base_hex, tip_hex, stam_mat, stam_len, edge_hex=None, rot=0.0):
    objs = []
    for k in range(n):
        p = petal_ribbon("%s_p%d" % (name, k), length, width, cup_el, flare, mat, base_hex, tip_hex, edge_hex)
        p.rotation_euler = (0, 0, rot + 2 * math.pi * k / n)
        objs.append(p)
    objs += stamens(Vector((0, 0, 0)), stam_mat, 6, stam_len)
    return group(name, objs, at, direction)

@plant
def lily():
    mm = M(); rnd = random.Random(32)
    petal = vmat("hero_petal_lav", 0.55, "#b49cff", 0.25)
    for k in range(10):
        leaf("lf%d" % k, (0, 0, 0.03), 2 * math.pi * k / 10 + rnd.uniform(-0.3, 0.3), rnd.uniform(0.5, 0.68), 0.1,
             math.radians(rnd.uniform(50, 75)), rnd.uniform(0.4, 0.6), mm["leaf"])
    for s, (top, d, ln) in enumerate([(Vector((0.04, 0.0, 1.0)), (0.3, -0.4, 1.0), 0.3), (Vector((-0.1, 0.05, 0.7)), (-0.45, -0.3, 1.0), 0.25)]):
        tube("st%d" % s, [Vector((0, 0, 0)).lerp(top, t / 7) for t in range(8)], 0.018, mm["stem"])
        for j in range(3):
            leaf("sl%d_%d" % (s, j), tuple(Vector((0, 0, 0)).lerp(top, 0.3 + 0.18 * j)), rnd.uniform(0, 6.28), 0.3, 0.05, math.radians(45), 0.4, mm["leaf"], shape="strap")
        bloom("bl%d" % s, top, d, 6, ln, 0.075, 1.0, 1.15, petal, "#f1e6ff", "#9b72e4", mm["stem"], 0.16, "#b994f0")
    bud = Vector((0.12, 0.08, 0.86))
    tube("bst", [Vector((0.04, 0.0, 0.6)).lerp(bud, t / 4) for t in range(5)], 0.01, mm["stem"])
    b = L.blob("bud", 0.05, tuple(bud + Vector((0, 0, 0.06))), petal, squash=(0.55, 0.55, 1.6), sub=2)
    paint(b, lambda co, i: ramp([(0, "#7a5bc4"), (1, "#c3a6f4")], (co.z + 0.08) / 0.16))
    finish("lily")

@plant
def daisy():
    mm = M(); rnd = random.Random(33)
    petal = vmat("hero_petal_pink", 0.6, "#ff9cc8", 0.1)
    for k in range(14):
        leaf("lf%d" % k, (0, 0, 0.03), rnd.uniform(0, 6.28), rnd.uniform(0.35, 0.52), 0.075, math.radians(rnd.uniform(45, 70)), rnd.uniform(0.35, 0.55), mm["leaf"])
    for s in range(7):
        yaw = rnd.uniform(0, 6.28); h = rnd.uniform(0.5, 0.82); rr = rnd.uniform(0.05, 0.2)
        top = Vector((math.cos(yaw) * rr, math.sin(yaw) * rr, h))
        tube("st%d" % s, [Vector((0, 0, 0)).lerp(top, t / 6) for t in range(7)], 0.009, mm["stem"])
        objs = []
        for k in range(16):
            p = petal_ribbon("pt%d_%d" % (s, k), 0.1, 0.02, 0.12, 0.0, petal, "#d65a96", "#ffe0ec", n=5)
            p.rotation_euler = (0, 0, 2 * math.pi * k / 16)
            objs.append(p)
        c = L.blob("disc%d" % s, 0.034, (0, 0, 0.014), petal, squash=(1, 1, 0.5), sub=2)
        paint(c, lambda co, i: srgb("#f6b23a"))
        objs.append(c)
        group("hd%d" % s, objs, top, (math.cos(yaw) * 0.4, math.sin(yaw) * 0.4 - 0.5, 1.0))
    finish("daisy")

@plant
def whitelily():
    mm = M(); rnd = random.Random(34)
    petal = vmat("hero_petal_ivory", 0.55, "#fff3d8", 0.2)
    for k in range(12):
        leaf("lf%d" % k, (0, 0, 0.03), rnd.uniform(0, 6.28), rnd.uniform(0.42, 0.6), 0.08, math.radians(rnd.uniform(50, 75)), rnd.uniform(0.35, 0.5), mm["leaf"])
    for s in range(3):
        yaw = 2 * math.pi * s / 3 + rnd.uniform(-0.3, 0.3); h = rnd.uniform(0.62, 0.85)
        top = Vector((math.cos(yaw) * 0.12, math.sin(yaw) * 0.12, h))
        tube("st%d" % s, [Vector((0, 0, 0)).lerp(top, t / 6) for t in range(7)], 0.012, mm["stem"])
        for j in range(2):
            leaf("sl%d_%d" % (s, j), tuple(Vector((0, 0, 0)).lerp(top, 0.35 + 0.25 * j)), rnd.uniform(0, 6.28), 0.2, 0.03, math.radians(45), 0.4, mm["leaf"], shape="strap")
        bloom("bl%d" % s, top, (math.cos(yaw) * 0.5, math.sin(yaw) * 0.5 - 0.4, 1.0), 6, 0.17, 0.042, 0.75, 0.9, petal, "#ffd27a", "#fffaf0", mm["stem"], 0.1, "#fff6e6")
    for b_ in range(2):
        bp = Vector((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), rnd.uniform(0.7, 0.9)))
        tube("bst%d" % b_, [Vector((0, 0, 0)).lerp(bp, t / 5) for t in range(6)], 0.008, mm["stem"])
        bb = L.blob("bud%d" % b_, 0.035, tuple(bp + Vector((0, 0, 0.05))), petal, squash=(0.5, 0.5, 1.7), sub=2)
        paint(bb, lambda co, i: ramp([(0, "#b9c48a"), (1, "#fff8ea")], (co.z + 0.06) / 0.12))
    finish("whitelily")

@plant
def boulder():
    """1.5 m wide, 1.0 m tall; a lumpy moss blanket over the top half, grey-brown base (v2, capture pr50: the moss
    read L*30 at hue 119 against the goal boulder's L*41 at 90: olive and lighter, more rock showing)."""
    rnd = random.Random(35)
    rockm = vmat("hero_rock", 0.9); mossm = vmat("hero_moss", 0.95)
    def hull(name, size, seed, n, zcut=None):
        r2 = random.Random(seed)
        bm = bmesh.new()
        for _ in range(n):
            th = r2.uniform(0, 2 * math.pi); ph = math.acos(r2.uniform(-1, 1)); rr = r2.uniform(0.9, 1.0)
            bm.verts.new((rr * math.sin(ph) * math.cos(th) * size[0] * 0.5, rr * math.sin(ph) * math.sin(th) * size[1] * 0.5, max(rr * math.cos(ph) * size[2] * 0.5, -size[2] * 0.3)))
        bmesh.ops.convex_hull(bm, input=bm.verts[:])
        if zcut is not None:
            bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < zcut], context="FACES")
        me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
        return ob
    rk = hull("rock", (1.5, 1.25, 1.0), 351, 46)
    rk.data.materials.append(rockm)
    zs = [v.co.z for v in rk.data.vertices]; z0, z1 = min(zs), max(zs)
    paint(rk, lambda co, i: ramp([(0, "#5e5552"), (0.5, "#8a7f78"), (1, "#a59a90")], (co.z - z0) / (z1 - z0)))
    md = rk.modifiers.new("bevel", "BEVEL"); md.width = 0.05; md.segments = 1; md.limit_method = "ANGLE"
    zc = z0 + (z1 - z0) * 0.5
    ms = hull("moss", (1.58, 1.33, 1.08), 351, 46, zcut=zc)
    ms.data.materials.append(mossm)
    bm = bmesh.new(); bm.from_mesh(ms.data)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    bm.to_mesh(ms.data); bm.free()
    from mathutils import noise as mnoise
    for v in ms.data.vertices:
        n = mnoise.noise(v.co * 4.0)
        v.co += v.co.normalized() * (0.03 + 0.05 * n)
    ms.data.polygons.foreach_set("use_smooth", [True] * len(ms.data.polygons))
    paint(ms, lambda co, i: mix(ramp([(0, "#5c6a2e"), (0.55, "#8a963e"), (1, "#b3b558")], (co.z - zc) / (z1 + 0.05 - zc)), srgb("#6a7434"), 0.5 * max(0.0, mnoise.noise(co * 6.0))))
    sol = ms.modifiers.new("solid", "SOLIDIFY"); sol.thickness = 0.04
    for o in (rk, ms): o.location.z -= z0
    for k in range(6):
        a = rnd.uniform(0, 6.28)
        leaf("cl%d" % k, (math.cos(a) * 0.75, math.sin(a) * 0.6, 0.02), a, 0.22, 0.08, math.radians(20), 0.4, vmat("hero_leaf", 0.75))
    finish("boulder")

@plant
def broadleaf():
    mm = M(); rnd = random.Random(36)
    for k in range(9):
        leaf("lf%d" % k, (rnd.uniform(-0.04, 0.04), rnd.uniform(-0.04, 0.04), 0.03), 2 * math.pi * k / 9 + rnd.uniform(-0.2, 0.2),
             rnd.uniform(0.75, 0.95), rnd.uniform(0.24, 0.3), math.radians(rnd.uniform(45, 75)), rnd.uniform(0.4, 0.6), mm["leaf"],
             dark="#2c4a30", light="#4f7c3f", mid="#8fb466")
    finish("broadleaf")

for fn in PLANTS:
    reset()
    fn()

reset()
x = 0.0
for tag, g in [("cup", 1.1), ("lily", 1.1), ("daisy", 1.0), ("whitelily", 1.1), ("boulder", 1.9), ("broadleaf", 1.4)]:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(out_dir, "hero_%s.glb" % tag))
    for o in set(bpy.context.scene.objects) - before:
        if o.parent is None: o.location.x += x
    x += g
files = L.sheet_render(out_png, x + 1.0, center=(x * 0.5 - 0.5, 0, 0.55), res=(3600, 1200),
                       views=[("front", (0, -60, 0), (90, 0, 0)), ("top", (0, 0, 60), (0, 0, 0)), ("hero", (-1.5, -8, 3), None)])
print("RENDERS", files)
