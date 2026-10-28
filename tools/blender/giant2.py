"""Giant luminous mushroom V2 from ChatGPT sheet mush-sheet-giant-02 (after review of V1 in the vista: cap
too flat, stem too thin and straight, skirt an angular collar). Profiles traced from the FRONT and
CROSS-SECTION panels (axis x=272, cap radius 250 px = R, ground y=490), heights x0.945 so the rim's lowest
point sits at 1.125 R like V1 (Godot's GIANT_MODEL_UNDERSIDE). Built with R = 7 m.
Usage: blender -b -P giant2.py -- <out.glb> <render_prefix.png>"""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(23)
R = 7.0

# v3 (capture pr12 against the goal): stem and skirt back to the colours that rendered at the goal's stem
# (pr08 stem 129,92,117 vs goal 124,92,120); gills darker and dimmer (pr12 237,173,95 vs 199,134,81).
M = {
    "cap": L.mat("cap", "#a888c8", 0.7),
    "spot": L.mat("spot_nightglow", "#e4c8ec", 0.75, "#f2c6e6", 1.2),
    "gill": L.mat("gill", "#d98a40", 0.7, "#f39a3d", 0.9),
    "rib": L.mat("gill_rib", "#c06e30", 0.7, "#e88a35", 0.6),
    "drip": L.mat("drip", "#fbd98a", 0.3, "#ffd47a", 3.0),
    "stem": L.mat("stem", "#b48c93", 0.85),
    "skirt": L.mat("skirt", "#a8828f", 0.85),
    "moss": L.mat("moss", "#6f7f37", 0.95),
}
K = 0.945
# outer shell: from the gill plane at the inner lip, the lip curling under, then over the dome (r/R, z/R)
TOP = [(0.905, 1.25), (0.93, 1.225), (0.965, 1.20), (0.99, 1.19), (1.0, 1.215), (1.0, 1.255), (0.97, 1.33), (0.89, 1.42),
       (0.75, 1.52), (0.57, 1.62), (0.37, 1.70), (0.17, 1.75), (0.0, 1.77)]
UNDER = [(0.15, 1.26), (0.4, 1.255), (0.7, 1.25), (0.905, 1.25)]
# v2 (capture pr11: the sheet's stem, 0.15 R mid and a 0.52 R root bell, read twice the goal's width; the
# lip hid the gills): the stem to the numbers asked of the sheet (mid ~0.11 R, roots ~0.3 R), gills only
# 0.055 R above the lip.
STEM = [(0.32, -0.06), (0.31, 0.0), (0.26, 0.07), (0.2, 0.17), (0.155, 0.32), (0.125, 0.5), (0.112, 0.7), (0.108, 0.9),
        (0.125, 1.1), (0.15, 1.26)]
def S(pts): return [(r * R, z * K * R) for r, z in pts]

L.lathe("cap_top", S(TOP), 80, M["cap"], close_top=True)
L.lathe("cap_under", S(UNDER), 80, M["gill"])

# stem: four big buttress roots and one smaller, soft vertical ridges, a very slight lean
LOBES = [0.35, 1.6, 2.85, 4.2, 5.35]
REACH = [1.0, 0.75, 0.95, 0.85, 0.55]
def stem_deform(x, y, z, th, i):
    zr = z / (K * R)
    base_w = max(0.0, 1.0 - zr / 0.42) ** 1.5
    lobe = 0.0
    for a0, reach in zip(LOBES, REACH):
        d = math.atan2(math.sin(th - a0), math.cos(th - a0))
        lobe = max(lobe, reach * math.exp(-(d / 0.45) ** 2))
    k = 0.6 + 0.4 * lobe
    k = 1.0 + (k - 1.0) * base_w
    k *= 1.0 + 0.045 * math.cos(14 * th + 0.6 * zr * 10) * (1.0 - 0.5 * base_w)
    lean = 0.05 * R * max(0.0, zr - 0.2) ** 1.5
    return x * k + lean, y * k, z
L.lathe("stem", S(STEM), 96, M["stem"], deform=stem_deform)

# flowing frilly skirt: hangs from just under the cap (z 1.10) to ~0.83, 8 soft frills on the hem
segs = 128
rows = 8
for layer, off in ((0, 0.0), (1, -0.01)):
    verts, faces = [], []
    for j in range(segs):
        th = 2 * math.pi * j / segs
        for t_i in range(rows):
            t = t_i / (rows - 1)
            fr = math.sin(8 * th + 0.6 * math.sin(3 * th))
            rr = (0.14 + 0.1 * t ** 1.3 + 0.03 * t * fr + off) * R
            zz = (1.17 - 0.28 * t - 0.04 * t * fr) * K * R
            verts.append((rr * math.cos(th), rr * math.sin(th), zz))
    for j in range(segs):
        j2 = (j + 1) % segs
        for t_i in range(rows - 1):
            a, b, c, d = j * rows + t_i, j2 * rows + t_i, j2 * rows + t_i + 1, j * rows + t_i + 1
            faces.append((a, b, c, d) if layer == 0 else (d, c, b, a))
    L.obj_from("skirt%d" % layer, verts, faces, M["skirt"])

# dense radiating gill blades just under the gill surface
n_ribs = 168
for i in range(n_ribs):
    a = 2 * math.pi * i / n_ribs
    r0 = (0.2 if i % 3 == 0 else (0.38 if i % 3 == 1 else 0.58)) * R
    r1 = 0.9 * R
    mid = (r0 + r1) / 2
    L.box("rib%d" % i, (r1 - r0, 0.05, 0.22), (mid * math.cos(a), mid * math.sin(a), 1.25 * K * R - 0.12), M["rib"], rot=(0, 0, a))

# spots following the dome, larger near the top
def z_top(r):
    pts = sorted([(rr * R, zz * K * R) for rr, zz in TOP[5:]])
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if r0 <= r <= r1: return z0 + (z1 - z0) * (r - r0) / (r1 - r0)
    return pts[-1][1] if r > pts[-1][0] else pts[0][1]
spots = [(0.0, 0, 0.12)]
for k in range(46):
    rr = math.sqrt(rnd.uniform(0.02, 0.86))
    spots.append((rr, rnd.uniform(0, 360), rnd.uniform(0.03, 0.075) * (1.45 if rr < 0.45 else 1.0)))
for k, (r, adeg, s) in enumerate(spots):
    r *= R; s *= R
    cx, cy = r * math.cos(math.radians(adeg)), r * math.sin(math.radians(adeg))
    n = 16
    def onsurf(px, py):
        pr = min(math.hypot(px, py), 0.97 * R)
        return (px, py, z_top(pr) + 0.05)
    verts = [onsurf(cx, cy)]
    for f in (0.55, 1.0):
        for i in range(n):
            ph = 2 * math.pi * i / n
            verts.append(onsurf(cx + s * f * math.cos(ph), cy + s * f * math.sin(ph)))
    faces = []
    for i in range(n):
        faces.append((0, 1 + i, 1 + (i + 1) % n))
        a_, b_ = 1 + i, 1 + (i + 1) % n
        faces.append((a_, a_ + n, b_ + n, b_))
    L.obj_from("spot%d" % k, verts, faces, M["spot"])

# luminous drips hanging from the curled rim
for k in range(8):
    a = 2 * math.pi * (k + rnd.uniform(-0.3, 0.3)) / 8
    rr = 0.975 * R
    length = rnd.uniform(0.3, 0.6)
    L.lathe("drip%d" % k, [(0.0, 0.0), (0.09, 0.08), (0.11, 0.18), (0.06, length * 0.7), (0.03, length)], 10, M["drip"], close_top=True,
            deform=lambda x, y, z, th, i, a=a, rr=rr, length=length: (x + rr * math.cos(a), y + rr * math.sin(a), 1.19 * K * R - length + z))

# moss on the root shoulders
for k, (a0, reach) in enumerate(zip(LOBES, REACH)):
    for j in range(3):
        rr = (0.2 + 0.1 * reach + rnd.uniform(-0.02, 0.02)) * R
        a = a0 + rnd.uniform(-0.25, 0.25)
        L.blob("moss%d_%d" % (k, j), rnd.uniform(0.14, 0.26), (rr * math.cos(a), rr * math.sin(a), rnd.uniform(0.03, 0.25)), M["moss"], squash=(1.4, 1.0, 0.5), seed=k * 3 + j)

print("TRIS_BEFORE_JOIN", L.tri_count())
names = list(L.join_by_material())
print("MATERIAL_OBJECTS", names)
print("TRIS", L.tri_count())
L.export_glb(out_glb)
print("EXPORTED", out_glb, os.path.getsize(out_glb))
files = L.sheet_render(out_png, 15.5, center=(0, 0, 6.0),
                       views=[("front", (0, -60, 0), (90, 0, 0)), ("under", (0, 0, -60), (180, 0, 0)), ("top", (0, 0, 60), (0, 0, 0)),
                              ("side", (60, 0, 0), (90, 0, 90)), ("hero", (-26, -40, -4), None)])
print("RENDERS", files)
