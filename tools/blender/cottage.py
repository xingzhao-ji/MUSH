"""Mushroom cottage from ChatGPT sheet mush-sheet-cottage-01 (front view: 64 px/m, cap 7.1 m wide, 5.8 m tall).
Front faces -Y (glTF +Z). Usage: blender -b -P cottage.py -- <out.glb> <render_prefix.png>"""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(7)

M = {
    "cap": L.mat("cap", "#956674", 0.75),
    "spot": L.mat("spot", "#ddbec2", 0.8),
    "gill": L.mat("gill", "#f8af65", 0.7, "#f6a352", 1.6),
    "rib": L.mat("gill_rib", "#c9783f", 0.7, "#d98236", 0.6),
    "plaster": L.mat("plaster", "#e6d2c1", 0.9),
    "wood": L.mat("timber", "#9d6b4a", 0.8),
    "wood_dark": L.mat("timber_dark", "#6b4429", 0.85),
    "glass": L.mat("glass", "#fcbe67", 0.3, "#ffb040", 4.0),
    "stone": L.mat("stone", "#b9b2a5", 0.9),
    "stone_dark": L.mat("stone_dark", "#8d857a", 0.9),
    "moss": L.mat("moss", "#7a9140", 0.95),
    "leaf": L.mat("leaf", "#5e7d33", 0.85),
    "metal": L.mat("metal", "#3a3230", 0.5),
}

def pol(r, a, z):
    a = math.radians(a)
    return Vector((r * math.sin(a), -r * math.cos(a), z))

# ---- cap -------------------------------------------------------------------------------------------------
# v2: a fuller dome (v1 read as a pointed witch-hat cone against the sheet's rounded cap)
TOP = [(3.40, 2.87), (3.52, 2.94), (3.60, 3.08), (3.60, 3.22), (3.52, 3.42), (3.30, 3.78), (2.98, 4.15), (2.61, 4.47),
       (2.20, 4.78), (1.75, 5.08), (1.30, 5.34), (0.85, 5.56), (0.45, 5.70), (0.18, 5.76), (0.0, 5.78)]
UNDER = [(0.0, 3.14), (1.2, 3.14), (2.2, 3.10), (2.8, 3.01), (3.15, 2.93), (3.40, 2.87)]

def droop_z(x, y, z, r):
    # a gentle lean: the front-left of the rim sits lower, as in the sheet's front and hero views
    th = math.atan2(y, x)
    return z - 0.16 * (r / 3.6) ** 2 * (0.5 + 0.5 * math.cos(th - math.radians(-130)))

def deform(x, y, z, th, i):
    r = math.hypot(x, y)
    return x, y, droop_z(x, y, z, r)

L.lathe("cap_top", TOP, 64, M["cap"], close_top=True, deform=deform)
L.lathe("cap_under", UNDER, 64, M["gill"], deform=deform)

def z_top(r):
    pts = sorted([(rr, zz) for rr, zz in TOP[4:]], key=lambda p: p[0])
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if r0 <= r <= r1:
            t = (r - r0) / (r1 - r0)
            return z0 + (z1 - z0) * t
    return pts[-1][1] if r > pts[-1][0] else pts[0][1]

# spots: discs that follow the cap surface
spots = [(0.45, 0, 0.42), (1.3, 40, 0.5), (1.4, 160, 0.42), (1.2, 270, 0.45), (2.2, -20, 0.55), (2.1, 80, 0.38), (2.3, 130, 0.5),
         (2.0, 200, 0.4), (2.25, 250, 0.52), (2.9, 20, 0.36), (2.85, 60, 0.3), (2.95, 105, 0.42), (2.8, 175, 0.33), (3.0, 220, 0.4),
         (2.9, 300, 0.45), (3.1, -45, 0.32), (1.8, -60, 0.35), (2.6, 320, 0.3), (0.9, 110, 0.3), (3.15, 145, 0.28)]
for k, (r, adeg, s) in enumerate(spots):
    cx, cy = r * math.cos(math.radians(adeg)), r * math.sin(math.radians(adeg))
    # two rings so the disc bends with the cap instead of cutting through it (v1 showed dark cracks)
    verts, faces = [], []
    n = 16
    def onsurf(px, py, lift):
        pr = min(math.hypot(px, py), 3.5)
        return (px, py, droop_z(px, py, z_top(pr), pr) + lift)
    verts.append(onsurf(cx, cy, 0.05))
    for ring, f in ((1, 0.55), (2, 1.0)):
        for i in range(n):
            ph = 2 * math.pi * i / n
            verts.append(onsurf(cx + s * f * math.cos(ph), cy + s * f * 0.86 * math.sin(ph), 0.05))
    for i in range(n):
        faces.append((0, 1 + i, 1 + (i + 1) % n))
        a, b = 1 + i, 1 + (i + 1) % n
        faces.append((a, a + n, b + n, b))
    L.obj_from("spot%d" % k, verts, faces, M["spot"])

# gill ribs under the cap
for i in range(72):
    a = 360.0 * i / 72
    r0, r1 = 2.35, 3.33
    mid = (r0 + r1) / 2
    p = pol(mid, a, 0)
    zz = droop_z(p.x, p.y, 3.0, mid) - 0.04
    L.box("rib%d" % i, (0.035, r1 - r0, 0.07), (p.x, p.y, zz), M["rib"], rot=(math.radians(-6), 0, math.radians(a)))

# ---- walls -----------------------------------------------------------------------------------------------
L.lathe("walls", [(2.30, 0.0), (2.38, 0.5), (2.42, 1.4), (2.38, 2.4), (2.25, 3.15)], 48, M["plaster"])
for k in range(20):
    a = 360.0 * k / 20 + rnd.uniform(-5, 5)
    if abs(((a + 180) % 360) - 180) < 66: continue
    p = pol(2.45, a, 0.1)
    L.blob("base_stone%d" % k, rnd.uniform(0.22, 0.32), p, M["stone"], squash=(1.3, 0.9, 0.55), seed=k)

# ---- porch -----------------------------------------------------------------------------------------------
def wedge(name, r0, r1, z0, z1, a0, a1, mat, segs=4):
    verts, faces = [], []
    for j in range(segs + 1):
        a = a0 + (a1 - a0) * j / segs
        for (r, z) in [(r0, z0), (r1, z0), (r1, z1), (r0, z1)]:
            verts.append(tuple(pol(r, a, z)))
    for j in range(segs):
        for i in range(4):
            a_, b_ = j * 4 + i, j * 4 + (i + 1) % 4
            faces.append((a_, b_, b_ + 4, a_ + 4))
    faces.append((0, 1, 2, 3)[::-1]); e = segs * 4; faces.append((e, e + 1, e + 2, e + 3))
    return L.obj_from(name, verts, faces, mat, smooth=False)

DECK_Z = 0.55
n_planks = 16
for i in range(n_planks):
    a0 = -64 + 128.0 * i / n_planks + 0.35
    a1 = -64 + 128.0 * (i + 1) / n_planks - 0.35
    wedge("plank%d" % i, 2.3, 3.58, DECK_Z - 0.1, DECK_Z + rnd.uniform(-0.01, 0.01), a0, a1, M["wood"], 2)
wedge("fascia", 3.5, 3.6, 0.05, DECK_Z - 0.08, -64, 64, M["wood_dark"], 12)
POSTS = [-58, -22, 22, 58]
for k, a in enumerate(POSTS):
    p = pol(3.4, a, 1.43)
    L.box("post%d" % k, (0.2, 0.2, 2.86), p, M["wood"], rot=(0, 0, math.radians(a)), bevel=0.03)
    # knee braces up to the beam
    for s in (-1, 1):
        q = pol(3.4, a + s * 4.5, 2.45)
        L.box("brace%d_%d" % (k, s), (0.09, 0.09, 0.62), q, M["wood"], rot=(0, math.radians(-s * 40), math.radians(a)), bevel=0.015)
wedge("beam", 3.31, 3.49, 2.62, 2.8, -63, 63, M["wood"], 16)
for (a0, a1) in [(-58, -22), (22, 58)]:
    for z in (DECK_Z + 0.38, DECK_Z + 0.82):
        wedge("rail%d_%d" % (a0, int(z * 100)), 3.36, 3.46, z, z + 0.1, a0, a1, M["wood"], 6)
    for t in (0.25, 0.5, 0.75):
        a = a0 + (a1 - a0) * t
        L.box("baluster%d_%d" % (a0, int(t * 100)), (0.07, 0.07, 0.8), pol(3.41, a, DECK_Z + 0.42), M["wood"], rot=(0, 0, math.radians(a)))
# steps
for k, (r0, r1, top, w) in enumerate([(3.55, 4.15, 0.37, 1.8), (4.05, 4.7, 0.18, 2.0)]):
    c = pol((r0 + r1) / 2, 0, top / 2)
    L.box("step%d" % k, (w, r1 - r0, top), c, M["stone"], bevel=0.07, segs=3)
    for m_ in range(3):
        L.blob("step_moss%d_%d" % (k, m_), 0.16, (c.x + rnd.uniform(-0.7, 0.7), c.y + rnd.uniform(-0.15, 0.15), top + 0.01), M["moss"], squash=(1.6, 0.8, 0.12), seed=30 + k * 3 + m_)

# ---- door ------------------------------------------------------------------------------------------------
def arch_pts(w, h, n=16):
    r = w / 2
    return [(-r, 0.0)] + [(-r * math.cos(math.pi * i / n), h - r + r * math.sin(math.pi * i / n)) for i in range(n + 1)] + [(r, 0.0)]

def arch_ring(name, wo, ho, wi, hi, y0, depth, z0, mat):
    o, i_ = arch_pts(wo, ho), arch_pts(wi, hi)
    n = len(o)
    verts = [(x, y0, z + z0) for x, z in o] + [(x, y0, z + z0) for x, z in i_]
    verts += [(x, y0 - depth, z + z0) for x, z in o] + [(x, y0 - depth, z + z0) for x, z in i_]
    faces = []
    for k in range(n - 1):
        faces.append((k, k + 1, n + k + 1, n + k))                      # back
        faces.append((2 * n + k, 3 * n + k, 3 * n + k + 1, 2 * n + k + 1))  # front
        faces.append((k, 2 * n + k, 2 * n + k + 1, k + 1))              # outer side
        faces.append((n + k, n + k + 1, 3 * n + k + 1, 3 * n + k))      # inner side
    return L.obj_from(name, verts, faces, mat, smooth=False)

WALL_Y = -2.40
L.extrude_outline("door", arch_pts(1.25, 2.05), 0.1, WALL_Y + 0.02, M["wood"])
for k, x in enumerate((-0.33, -0.05, 0.22)):
    L.obj_from  # noqa
    L.box("door_groove%d" % k, (0.025, 0.02, 1.6), (x + 0.08, WALL_Y - 0.085, DECK_Z + 0.85), M["wood_dark"])
for k, z in enumerate((0.95, 1.95)):
    L.box("strap%d" % k, (0.42, 0.03, 0.07), (-0.4, WALL_Y - 0.095, z), M["metal"])
arch_ring("door_frame", 1.6, 2.32, 1.25, 2.05, WALL_Y + 0.04, 0.2, DECK_Z - 0.02, M["wood"])
L.cyl("door_window", 0.17, 0.04, (0, WALL_Y - 0.09, DECK_Z + 1.55), M["glass"], rot=(math.radians(90), 0, 0), verts=20)
L.torus("door_window_frame", 0.19, 0.035, (0, WALL_Y - 0.1, DECK_Z + 1.55), (math.radians(90), 0, 0), M["wood_dark"], 24, 6)
L.box("door_window_bar_v", (0.03, 0.02, 0.34), (0, WALL_Y - 0.11, DECK_Z + 1.55), M["wood_dark"])
L.box("door_window_bar_h", (0.34, 0.02, 0.03), (0, WALL_Y - 0.11, DECK_Z + 1.55), M["wood_dark"])
bpy.ops.mesh.primitive_uv_sphere_add(radius=0.05, location=(0.42, WALL_Y - 0.12, DECK_Z + 0.95))
bpy.context.active_object.data.materials.append(M["metal"])

# ---- windows ---------------------------------------------------------------------------------------------
for k, a in enumerate((-52, 52, 128)):
    p = pol(2.44, a, 1.85)
    rot = (math.radians(90), 0, math.radians(a))
    L.cyl("window%d" % k, 0.33, 0.06, p, M["glass"], rot=rot, verts=24)
    L.torus("window_frame%d" % k, 0.37, 0.065, pol(2.47, a, 1.85), rot, M["wood"], 28, 8)
    for b, sz in enumerate([(0.035, 0.03, 0.64), (0.64, 0.03, 0.035)]):
        L.box("window_bar%d_%d" % (k, b), sz, tuple(pol(2.49, a, 1.85)), M["wood_dark"], rot=(0, 0, math.radians(a)))
# wall timber posts framing the door
for k, a in enumerate((-30, 30)):
    L.box("wall_post%d" % k, (0.18, 0.14, 2.6), pol(2.42, a, DECK_Z + 1.25), M["wood"], rot=(0, 0, math.radians(a)), bevel=0.02)

# ---- chimney ---------------------------------------------------------------------------------------------
ch = pol(1.75, 150, 0)
for row in range(5):
    for col in range(2):
        z = 3.75 + row * 0.38
        off = 0.16 if row % 2 else 0.0
        L.box("chim%d_%d" % (row, col), (0.34, 0.66, 0.36), (ch.x - 0.17 + col * 0.34 + (off - 0.08) * 0.3, ch.y, z),
              M["stone"] if (row + col) % 2 else M["stone_dark"], bevel=0.035)
L.lathe("chim_cap", [(0.0, 5.62), (0.48, 5.62), (0.55, 5.70), (0.5, 5.84), (0.34, 5.98), (0.0, 6.06)], 24, M["cap"], close_top=True, close_bottom=True,
        deform=lambda x, y, z, th, i: (x + ch.x, y + ch.y, z))
L.lathe("chim_gill", [(0.0, 5.60), (0.47, 5.61)], 24, M["gill"], deform=lambda x, y, z, th, i: (x + ch.x, y + ch.y, z))

# ---- lantern ---------------------------------------------------------------------------------------------
lp = pol(3.55, -66, 2.05)
L.box("lantern_arm", (0.5, 0.05, 0.05), tuple(pol(3.45, -62, 2.38)), M["metal"], rot=(0, 0, math.radians(-62 + 90)))
L.box("lantern_glass", (0.17, 0.17, 0.24), tuple(lp), M["glass"])
for sx in (-1, 1):
    for sy in (-1, 1):
        L.box("lantern_rod", (0.025, 0.025, 0.3), (lp.x + sx * 0.095, lp.y + sy * 0.095, lp.z), M["metal"])
L.box("lantern_base", (0.24, 0.24, 0.04), (lp.x, lp.y, lp.z - 0.15), M["metal"])
L.lathe("lantern_roof", [(0.0, 0.0), (0.17, 0.0), (0.0, 0.14)], 4, M["metal"], close_bottom=True,
        deform=lambda x, y, z, th, i: (x + lp.x, y + lp.y, z + lp.z + 0.14), smooth=False)

# ---- greenery --------------------------------------------------------------------------------------------
k = 0
for a in range(0, 360, 9):
    aa = ((a + 180) % 360) - 180
    if abs(aa) < 70:
        if abs(aa) < 18: continue
        r = 3.72
    else:
        r = 2.62
    for j in range(2 if rnd.random() < 0.5 else 1):
        p = pol(r + rnd.uniform(-0.12, 0.15), a + rnd.uniform(-4, 4), 0.12)
        L.blob("leaf%d" % k, rnd.uniform(0.18, 0.32), p, M["leaf"] if rnd.random() < 0.7 else M["moss"], squash=(1.2, 1.2, 0.75), seed=100 + k)
        k += 1
# a little ivy up two posts
for a in (-58, 58):
    for j in range(4):
        p = pol(3.48, a + rnd.uniform(-3, 3), 0.3 + j * 0.35)
        L.blob("ivy%d" % k, 0.13, p, M["leaf"], squash=(1, 0.7, 1.3), seed=200 + k); k += 1

print("TRIS_BEFORE_JOIN", L.tri_count())
names = list(L.join_by_material())
print("MATERIAL_OBJECTS", names)
print("TRIS", L.tri_count())
L.export_glb(out_glb)
print("EXPORTED", out_glb, os.path.getsize(out_glb))
files = L.sheet_render(out_png, 9.0, center=(0, 0, 3.0))
print("RENDERS", files)
