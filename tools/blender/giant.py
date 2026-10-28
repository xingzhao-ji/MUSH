"""Giant luminous mushroom from ChatGPT sheet mush-sheet-giant-01. Profile traced from the FRONT panel
(axis x=265, cap radius 240 px = R, base y=469). Built with R = 7 m; Godot rescales to each giant.
Usage: blender -b -P giant.py -- <out.glb> <render_prefix.png>"""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(11)
R = 7.0

# v3 colours from the goal frame as rendered in Godot (v2 cap read deep violet-blue #5040a0 against the
# goal's #c49bbb; stem blue-lavender #856fb8 against #88606f)
M = {
    "cap": L.mat("cap", "#b48fb2", 0.7),
    "spot": L.mat("spot_nightglow", "#ecd6e4", 0.75, "#f2c6e6", 1.2),
    "gill": L.mat("gill", "#fdb261", 0.7, "#f9a64a", 1.4),
    "rib": L.mat("gill_rib", "#e08a3e", 0.7, "#f39a3d", 0.9),
    "drip": L.mat("drip", "#feda8f", 0.3, "#ffd47a", 3.0),
    "stem": L.mat("stem", "#b48c93", 0.85),
    "skirt": L.mat("skirt", "#a8828f", 0.85),
    "moss": L.mat("moss", "#8e873c", 0.95),
}

# traced profile, (r/R, z/R)
TOP = [(0.92, 1.125), (0.955, 1.150), (0.985, 1.180), (1.000, 1.215), (1.000, 1.246), (0.985, 1.290), (0.960, 1.336),
       (0.920, 1.400), (0.870, 1.454), (0.810, 1.500), (0.730, 1.545), (0.650, 1.590), (0.560, 1.630), (0.470, 1.668),
       (0.370, 1.705), (0.240, 1.746), (0.120, 1.768), (0.0, 1.775)]
UNDER = [(0.18, 1.06), (0.26, 1.10), (0.45, 1.135), (0.65, 1.140), (0.82, 1.130), (0.92, 1.125)]
STEM = [(0.62, -0.06), (0.585, 0.0375), (0.48, 0.121), (0.3625, 0.204), (0.2875, 0.2875), (0.244, 0.371), (0.219, 0.454),
        (0.200, 0.5375), (0.1875, 0.621), (0.179, 0.704), (0.171, 0.79), (0.172, 0.88), (0.178, 0.96), (0.19, 1.02), (0.21, 1.075)]

# v3 proportions to match the goal frame's hero (v2 in Godot: stem twice the goal's width, base a broad
# lavender skirt, cap top cut off by the frame): the cap dome is 27% lower above the rim, the stem 18%
# slimmer, the base envelope 0.45 R.
CAP_SQUASH = 0.73
TOP = [(r, 1.125 + (z - 1.125) * CAP_SQUASH) for r, z in TOP]
# v4: the goal's hero stem is slender (mid radius ~0.11 R, base with roots ~0.24 R; capture pr01 showed v3's
# 0.18 R stem as a broad lavender tent): a new slim profile flaring only at the foot and into the cap.
STEM = [(0.27, -0.06), (0.255, 0.0), (0.205, 0.04), (0.16, 0.10), (0.132, 0.18), (0.117, 0.28), (0.108, 0.40), (0.102, 0.55),
        (0.100, 0.70), (0.103, 0.82), (0.110, 0.92), (0.122, 1.00), (0.145, 1.055), (0.185, 1.09)]
# v5 (capture pr05): still ~1.4x the goal's stem width in frame; 0.78 thinner below the cap flare.
STEM = [(r * (0.78 if z < 1.04 else 0.9), z) for r, z in STEM]
def S(pts): return [(r * R, z * R) for r, z in pts]

L.lathe("cap_top", S(TOP), 72, M["cap"], close_top=True)
L.lathe("cap_under", S(UNDER), 72, M["gill"])

# stem with five buttress lobes at the base and soft vertical ridges
LOBES = [0.3, 1.55, 2.7, 3.95, 5.1]
REACH = [1.0, 0.7, 0.9, 0.6, 0.85]
def stem_deform(x, y, z, th, i):
    r = math.hypot(x, y)
    zr = z / R
    base_w = max(0.0, 1.0 - zr / 0.32) ** 1.6
    lobe = 0.0
    for a0, reach in zip(LOBES, REACH):
        d = math.atan2(math.sin(th - a0), math.cos(th - a0))
        lobe = max(lobe, reach * math.exp(-(d / 0.42) ** 2))
    # the traced base width is the lobe envelope: the core between lobes sits at ~0.36 R (v1 flared into a tent)
    k = 0.66 + 0.5 * lobe
    k = 1.0 + (k - 1.0) * base_w
    k *= 1.0 + 0.035 * math.cos(16 * th + 0.4 * zr * 10)
    return x * k, y * k, z
L.lathe("stem", S(STEM), 80, M["stem"], deform=stem_deform)

# frilly skirt ring under the cap (two layers so it reads from both sides)
segs = 96
for layer, off in ((0, 0.0), (1, -0.012)):
    verts, faces = [], []
    rows = 6
    for j in range(segs):
        th = 2 * math.pi * j / segs
        for t_i in range(rows):
            t = t_i / (rows - 1)
            rr = (0.098 + 0.065 * t + 0.02 * t * math.sin(9 * th) + off) * R
            zz = (0.99 - 0.14 * t - 0.03 * t * math.sin(9 * th + 1.3)) * R
            verts.append((rr * math.cos(th), rr * math.sin(th), zz))
    for j in range(segs):
        j2 = (j + 1) % segs
        for t_i in range(rows - 1):
            a, b, c, d = j * rows + t_i, j2 * rows + t_i, j2 * rows + t_i + 1, j * rows + t_i + 1
            faces.append((a, b, c, d) if layer == 0 else (d, c, b, a))
    L.obj_from("skirt%d" % layer, verts, faces, M["skirt"])

# gill ribs: long and short blades fanning from the stem to the rim
n_ribs = 132
for i in range(n_ribs):
    a = 2 * math.pi * i / n_ribs
    r0 = (0.24 if i % 3 == 0 else (0.42 if i % 3 == 1 else 0.6)) * R
    r1 = 0.9 * R
    mid = (r0 + r1) / 2
    z_mid = (1.12 if mid > 0.6 * R else 1.115) * R - 0.06
    L.box("rib%d" % i, (r1 - r0, 0.045, 0.16), (mid * math.cos(a), mid * math.sin(a), z_mid), M["rib"], rot=(0, 0, a))

# spots following the cap
def z_top(r):
    pts = sorted([(rr * R, zz * R) for rr, zz in TOP[3:]])
    for (r0, z0), (r1, z1) in zip(pts, pts[1:]):
        if r0 <= r <= r1: return z0 + (z1 - z0) * (r - r0) / (r1 - r0)
    return pts[-1][1] if r > pts[-1][0] else pts[0][1]
spots = [(0.0, 0, 0.13)]
for k in range(34):
    rr = math.sqrt(rnd.uniform(0.03, 0.85))
    spots.append((rr, rnd.uniform(0, 360), rnd.uniform(0.035, 0.085) * (1.2 if rr < 0.5 else 1.0)))
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

# luminous drips hanging from the rim
for k in range(9):
    a = 2 * math.pi * (k + rnd.uniform(-0.3, 0.3)) / 9
    rr = 0.91 * R
    length = rnd.uniform(0.35, 0.7)
    L.lathe("drip%d" % k, [(0.0, 0.0), (0.09, 0.08), (0.11, 0.18), (0.06, length * 0.7), (0.03, length)], 10, M["drip"], close_top=True,
            deform=lambda x, y, z, th, i, a=a, rr=rr, length=length: (x + rr * math.cos(a), y + rr * math.sin(a), 1.12 * R - length + z))

# moss on the buttress shoulders
for k, (a0, reach) in enumerate(zip(LOBES, REACH)):
    for j in range(3):
        rr = (0.15 + 0.08 * reach + rnd.uniform(-0.02, 0.02)) * R
        a = a0 + rnd.uniform(-0.2, 0.2)
        L.blob("moss%d_%d" % (k, j), rnd.uniform(0.35, 0.6), (rr * math.cos(a), rr * math.sin(a), rnd.uniform(0.1, 0.5)), M["moss"], squash=(1.4, 1.0, 0.45), seed=k * 3 + j)

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
