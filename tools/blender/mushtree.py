"""Giant bioluminescent mushroom tree from the ChatGPT sheet mush-c1-sheet-mushtree-01, drawn from the project's
original reference (design-reference/mush-concept-1.png, top right): a broad violet-blue cap with a glowing vein
network and a luminous rim, a glowing golden underside crossed by the trunk's branches, glowing strands hanging
from the rim, a gnarled trunk of twisted root strands flaring into buttress roots, small glowing mushrooms at
its foot. Built with cap radius R = 7 (420 m sheet -> 7 units), total height 10 (300 m).
Materials are hero_* (vertex colours, see Godot _blender_mat). Front faces -Y.
Usage: blender -b -P mushtree.py -- <out.glb> <render_prefix.png>"""
import bpy, bmesh, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector, noise

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(41)
R = 7.0

def srgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
def mix(a, b, t):
    t = max(0.0, min(1.0, t)); return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))
def ramp(stops, t):
    t = max(0.0, min(1.0, t))
    for k in range(len(stops) - 1):
        t0, c0 = stops[k]; t1, c1 = stops[k + 1]
        if t <= t1: return mix(srgb(c0), srgb(c1), (t - t0) / max(t1 - t0, 1e-6))
    return srgb(stops[-1][1])

_vm = {}
def vmat(name, rough=0.7, emit=None, strength=0.0):
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

def tube(name, pts, radii, mat, colf, sides=7):
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized(); b = t.cross(a)
        for k in range(sides):
            th = 2 * math.pi * k / sides
            verts.append(p + (a * math.cos(th) + b * math.sin(th)) * radii[i])
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
    ob = L.obj_from(name, verts, faces, mat)
    paint(ob, lambda co, i: colf(i // sides / max(n - 1, 1), co))
    return ob

M = {
    "cap": vmat("hero_tree_cap", 0.6, "#5a4ad8", 0.5),
    "vein": vmat("hero_tree_vein", 0.4, "#a070ff", 1.8),
    "rim": vmat("hero_tree_rim", 0.4, "#d58cff", 2.6),
    "under": vmat("hero_tree_under", 0.6, "#ffb048", 1.6),
    "bark": vmat("hero_tree_bark", 0.8),
    "bglow": vmat("hero_tree_glowbark", 0.5, "#6fb8ff", 1.8),
    "drip": vmat("hero_tree_drip", 0.3, "#e8b8ff", 1.4),
    "mini_cap": vmat("hero_tree_minicap", 0.6, "#8a6aff", 0.8),
    "mini_under": vmat("hero_tree_miniunder", 0.6, "#ffb860", 1.6),
}

# ---- cap top: broad dome with a rolled rim ------------------------------------------------------------------
# v5 (ChatGPT checkpoint after milestone 1: a flat roof-like canopy; the concept's cap is a deep dome): taller dome.
# v6 (ChatGPT checkpoint 2: still too flat): dome ~30% taller.
TOP = [(6.95, 7.72), (7.1, 7.92), (7.2, 8.28), (7.12, 8.75), (6.75, 9.45), (5.95, 10.25), (4.75, 10.95), (3.3, 11.5), (1.7, 11.85), (0.0, 11.95)]
cap = L.lathe("cap", TOP, 120, M["cap"], close_top=True)
# v4 (capture c1v09: the dome read saturated ultramarine; concept dome is a lighter lavender-blue)
paint(cap, lambda co, i: mix(ramp([(0.0, "#5c5aa6"), (0.55, "#7a76c8"), (0.85, "#9a94e0"), (1.0, "#b4aaee")], math.hypot(co.x, co.y) / R),
                            srgb("#9a86ff"), 0.35 * max(0.0, noise.noise(Vector((co.x * 0.9, co.y * 0.9, 0.3))))))
# glowing rim band
rim = L.lathe("rim", [(7.0, 7.76), (7.13, 7.92), (7.16, 8.08), (7.08, 8.2)], 120, M["rim"])
paint(rim, lambda co, i: srgb("#e2a8ff"))
# vein network on the cap top: branching glowing strands from the crown outward
def z_top(r):
    pts = sorted([(rr, zz) for rr, zz in TOP[3:]])
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if r0 <= r <= r1: return z0 + (z1 - z0) * (r - r0) / (r1 - r0)
    return pts[-1][1] if r > pts[-1][0] else pts[0][1]
def onsurf(x, y, lift=0.04):
    r = math.hypot(x, y)
    return Vector((x, y, z_top(min(r, 7.0)) + lift))
vk = 0
def vein(p_r, p_a, length, ang, depth):
    global vk
    pts = []
    r, a = p_r, p_a
    x, y = r * math.cos(a), r * math.sin(a)
    for s in range(6):
        pts.append(onsurf(x, y))
        ang += rnd.uniform(-0.35, 0.35)
        x += math.cos(ang) * length / 5; y += math.sin(ang) * length / 5
        if math.hypot(x, y) > 6.95: break
    if len(pts) >= 2:
        w = 0.12 * (1.0 - 0.25 * depth)   # v6: veins wide enough to read from 700 m
        tube("vein%d" % vk, pts, [w] * len(pts), M["vein"], lambda t, co: srgb("#b48aff"), sides=4); vk += 1
        if depth < 2:
            for _ in range(2):
                vein(math.hypot(x, y) * rnd.uniform(0.6, 0.95), math.atan2(y, x), length * 0.6, ang + rnd.uniform(-0.7, 0.7), depth + 1)
for k in range(24):
    a = 2 * math.pi * k / 24 + rnd.uniform(-0.1, 0.1)
    vein(rnd.uniform(0.3, 1.2), a, rnd.uniform(2.4, 3.6), a + rnd.uniform(-0.3, 0.3), 0)
# sparkles: small glowing dots scattered on the cap
for k in range(90):
    r = math.sqrt(rnd.uniform(0.02, 0.97)) * 6.9; a = rnd.uniform(0, 2 * math.pi)
    p = onsurf(r * math.cos(a), r * math.sin(a), 0.06)
    b = L.blob("spark%d" % k, rnd.uniform(0.08, 0.16), tuple(p), M["vein"], sub=1, jitter=0.05)
    paint(b, lambda co, i: srgb("#f2e0ff"))

# ---- underside: glowing gold, brighter toward the centre -----------------------------------------------------
UNDER = [(0.9, 7.15), (2.0, 7.35), (3.5, 7.55), (5.0, 7.66), (6.2, 7.7), (6.97, 7.73)]
und = L.lathe("under", UNDER, 120, M["under"])
paint(und, lambda co, i: mix(ramp([(0.0, "#fff0c0"), (0.35, "#ffc870"), (0.75, "#f09040"), (1.0, "#c86a40")], math.hypot(co.x, co.y) / R),
                            srgb("#e8a050"), 0.3 * max(0.0, noise.noise(Vector((co.x * 1.4, co.y * 1.4, 2.1))))))
# radial gill lines under the cap
for k in range(140):
    a = 2 * math.pi * k / 140
    r0 = rnd.uniform(1.5, 3.5); r1 = 6.85
    p0 = Vector((r0 * math.cos(a), r0 * math.sin(a), 7.25 + 0.3 * (r0 / R))); p1 = Vector((r1 * math.cos(a), r1 * math.sin(a), 7.68))
    tube("gill%d" % k, [p0, p0.lerp(p1, 0.5) + Vector((0, 0, -0.03)), p1], [0.025, 0.03, 0.02], M["under"], lambda t, co: srgb("#d77a3a"), sides=3)

# ---- trunk: twisted strands from buttress roots up, branching under the cap -----------------------------------
# v3 (concept crop: the trunk is a lavender-grey woven column with small blue glows, the branches under the cap
# dark silhouettes against the gold): lighter, greyer bark; dark branches.
def bark_col(t, co):
    return mix(ramp([(0.0, "#6c6668"), (0.5, "#8e8686"), (1.0, "#a49a9c")], t), srgb("#c4bcc0"), 0.4 * max(0.0, noise.noise(co * 2.5)))
def branch_col(t, co):
    return mix(srgb("#4a3d5c"), srgb("#2e2438"), t)
# v3: 18 slimmer strands (11 fat ones read as a draped blue sheet at 42x, capture c1v03).
N_STR = 18
for s in range(N_STR):
    a0 = 2 * math.pi * s / N_STR + rnd.uniform(-0.12, 0.12)
    twist = rnd.uniform(0.9, 1.4) * (1 if s % 2 else 0.85)
    pts, radii = [], []
    for i in range(16):
        t = i / 15
        z = -0.25 + t * 7.1
        # buttress flare at the base, a waist at mid height, spreading again into the branches
        spread = 2.0 * (1 - t) ** 3.0 + 0.85 + 2.2 * max(0.0, t - 0.45) ** 1.4 + 2.4 * max(0.0, t - 0.8) ** 1.2
        a = a0 + twist * t * 2.2
        pts.append(Vector((spread * math.cos(a), spread * math.sin(a), max(z, -0.25) if i else -0.35)))
        radii.append(0.36 * (1 - 0.45 * t) + 0.12)
    tube("strand%d" % s, pts, radii, M["bark"], bark_col, sides=8)
    # branches from the strand top out under the cap, sub-branching
    top = pts[-1]
    base_a = math.atan2(top.y, top.x)
    for b in range(2 if s % 2 else 1):
        ba = base_a + rnd.uniform(-0.4, 0.4)
        p = top.copy(); bpts = [p.copy()]; brad = [0.28]
        for j in range(6):
            r = math.hypot(p.x, p.y) + 0.85
            ba += rnd.uniform(-0.18, 0.18)
            p = Vector((r * math.cos(ba), r * math.sin(ba), 7.15 + 0.5 * min(1.0, r / R)))
            bpts.append(p.copy()); brad.append(max(0.05, 0.28 * (1 - j / 6.5)))
            if r > 6.5: break
        tube("branch%d_%d" % (s, b), bpts, brad, M["bark"], branch_col, sides=5)
        for j in range(1, len(bpts) - 1):
            if rnd.random() < 0.6:
                q = bpts[j]; qa = math.atan2(q.y, q.x) + rnd.choice((-1, 1)) * rnd.uniform(0.3, 0.6)
                q2 = Vector((q.x + math.cos(qa) * 1.1, q.y + math.sin(qa) * 1.1, min(7.62, q.z + 0.18)))
                tube("twig%d_%d_%d" % (s, b, j), [q, q.lerp(q2, 0.5), q2], [0.09, 0.06, 0.03], M["bark"], lambda t, co: branch_col(1.0, co), sides=4)
    # a glowing seam running up some strands
    if s % 3 != 2:
        gp = [pp + (pp - Vector((0, 0, pp.z))).normalized() * radii[i] * 0.9 for i, pp in enumerate(pts) if 2 <= i <= 13]
        tube("seam%d" % s, gp, [0.05] * len(gp), M["bglow"], lambda t, co: srgb("#8fd0ff"), sides=4)
# v5: a branch network under the cap (concept: the trunk splits into many limbs that spread radially and merge into
# the underside, dark against the glow). 16 limbs from the trunk top, each forking twice, twigs at the tips.
def under_z(r):
    return 7.12 + 0.55 * min(1.0, r / R) ** 0.8
def limb(a, r0, z0, w0, n, depth, seed):
    rr = random.Random(seed)
    pts, rad = [], []
    r, z = r0, z0
    for i in range(n + 1):
        t = i / n
        pts.append(Vector((r * math.cos(a), r * math.sin(a), z)))
        rad.append(max(0.035, w0 * (1.0 - 0.75 * t)))
        a += rr.uniform(-0.12, 0.12) + 0.05 * math.sin(i * 1.3 + seed)
        r += (6.75 - r0) / n
        z = z + (under_z(r) - 0.08 - z) * (0.45 + 0.4 * t)
    tube("limb_%d_%d" % (depth, seed), pts, rad, M["bark"], branch_col, sides=6 if depth == 0 else 4)
    if depth < 3:
        for f in (0.32, 0.58):
            i = int(n * f)
            q = pts[i]
            for sgn in (-1, 1):
                if rr.random() < 0.75:
                    limb(math.atan2(q.y, q.x) + sgn * rr.uniform(0.18, 0.4), math.hypot(q.x, q.y), q.z, rad[i] * 0.6, max(3, n - i), depth + 1, seed * 7 + i * 3 + (sgn > 0))
# v6 (ChatGPT checkpoint 2: 2-3x the branching, twisted limbs): 28 limbs, forks down to depth 3, a helical wander.
for k in range(28):
    a = 2 * math.pi * k / 28 + rnd.uniform(-0.06, 0.06)
    limb(a, 1.3, 6.4 + 0.25 * (k % 3), 0.36, 10, 0, 300 + k)

# buttress roots spreading on the ground
for k in range(16):
    a = 2 * math.pi * k / 16 + rnd.uniform(-0.15, 0.15)
    r0, r1 = rnd.uniform(1.2, 1.8), rnd.uniform(3.4, 4.8)
    pts = [Vector((r0 * math.cos(a), r0 * math.sin(a), 0.6)), Vector(((r0 + r1) / 2 * math.cos(a + 0.1), (r0 + r1) / 2 * math.sin(a + 0.1), 0.15)),
           Vector((r1 * math.cos(a + 0.18), r1 * math.sin(a + 0.18), -0.15))]
    tube("root%d" % k, pts, [0.45, 0.3, 0.12], M["bark"], lambda t, co: bark_col(0.1, co), sides=6)

# ---- glowing drips from the rim -----------------------------------------------------------------------------
for k in range(140):
    a = 2 * math.pi * k / 140 + rnd.uniform(-0.02, 0.02)
    r = rnd.uniform(6.5, 7.0)
    ln = rnd.uniform(0.25, 1.1) * (2.2 if k % 7 == 0 else 1.0)
    p0 = Vector((r * math.cos(a), r * math.sin(a), 7.72))
    tube("drip%d" % k, [p0, p0 + Vector((0, 0, -ln * 0.5)), p0 + Vector((0, 0, -ln))], [0.035, 0.025, 0.015], M["drip"],
         lambda t, co: mix(srgb("#ffd0a8"), srgb("#a080ff"), t), sides=4)

# ---- small glowing mushrooms at the foot ----------------------------------------------------------------------
for k in range(9):
    a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(2.6, 4.8); h = rnd.uniform(0.6, 1.8); cr = h * rnd.uniform(0.45, 0.6)
    cx, cy = r * math.cos(a), r * math.sin(a)
    tube("mstem%d" % k, [Vector((cx, cy, -0.1)), Vector((cx, cy, h * 0.5)), Vector((cx, cy, h))], [0.12 * h, 0.08 * h, 0.07 * h], M["bark"], lambda t, co: bark_col(0.6, co), sides=6)
    mc = L.lathe("mcap%d" % k, [(cr, h - 0.05), (cr * 0.9, h + cr * 0.25), (cr * 0.5, h + cr * 0.45), (0.0, h + cr * 0.5)], 20, M["mini_cap"], close_top=True,
                 deform=lambda x, y, z, th, i, cx=cx, cy=cy: (x + cx, y + cy, z))
    paint(mc, lambda co, i: srgb("#7a5ae8"))
    mu = L.lathe("munder%d" % k, [(0.1 * h, h - 0.02), (cr * 0.97, h - 0.06)], 20, M["mini_under"], deform=lambda x, y, z, th, i, cx=cx, cy=cy: (x + cx, y + cy, z))
    paint(mu, lambda co, i: srgb("#ffc070"))

print("TRIS_BEFORE_JOIN", L.tri_count())
names = list(L.join_by_material())
print("MATERIAL_OBJECTS", names)
print("TRIS", L.tri_count())
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", export_apply=True, export_yup=True, export_vertex_color="ACTIVE")
print("EXPORTED", out_glb, os.path.getsize(out_glb))
files = L.sheet_render(out_png, 17.0, center=(0, 0, 5.0),
                       views=[("front", (0, -80, 0), (90, 0, 0)), ("under", (0, 0, -80), (180, 0, 0)), ("hero", (-20, -34, -2), None)])
print("RENDERS", files)
