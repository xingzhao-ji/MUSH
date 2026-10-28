"""v4 (capture pr10: lime ramp, pale flat-lit stone): olive ramp 3.2 m wide, darker stone.
Promontory V2 from ChatGPT sheet mush-sheet-promontory-02 (after review: V1 read as thin bright-green
shelves over pale round boulders, with steps stacked on blocks in a steep straight line).
Two thick, asymmetric tiers of chunky faceted rock columns under rounded overhanging moss caps (top
platform ~15 x 12 m at z 11.7, lower tier top at z 6.0), and an S-curve stair of large flat slabs sunk
into a grassy ramp that winds down the right flank from the platform's right-rear to the front-right.
Front faces -Y (glTF +Z); right is +X. A rock skirt runs to z -30 so it can stand on a slope.
Usage: blender -b -P promontory2.py -- <out.glb> <render_prefix.png>"""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector, noise

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(7)

M = {
    "moss": L.mat("moss_top", "#6f8f2c", 0.95),
    "drape": L.mat("moss_drape", "#55741f", 0.95),
    "grass": L.mat("grass", "#6e8d30", 0.95),
    "stone": L.mat("stone", "#8e7f74", 0.9),
    "stone2": L.mat("stone_shadow", "#695e5b", 0.9),
    "step": L.mat("step_stone", "#b3a495", 0.85),
    "bush": L.mat("bush", "#335f2c", 0.85),
    "bush2": L.mat("bush_light", "#6c9934", 0.85),
    "flower": L.mat("flower", "#f1ead0", 0.6),
}

# tiers: (centre x, centre y, radius x, radius y, top z, bottom z, noise seed)
TIERS = [(-1.0, -1.2, 10.5, 8.6, 6.0, -30.0, 1.0), (-1.6, 1.0, 7.6, 6.1, 11.7, 3.0, 2.0)]
N_OUT = 72

def outline(t, scale=1.0):
    cx, cy, rx, ry, zt, zb, k = t
    pts = []
    for j in range(N_OUT):
        a = 2 * math.pi * j / N_OUT
        w = 1.0 + 0.085 * noise.noise(Vector((math.cos(a) * 1.3 + k * 4.0, math.sin(a) * 1.3, k))) + 0.035 * math.sin(3 * a + k)
        pts.append((cx + rx * w * scale * math.cos(a), cy + ry * w * scale * math.sin(a)))
    return pts

def stair_side(x, y):
    # the right flank where the stair ramp runs: keep shrubs and drapes off it
    return x > 3.0 and y < 5.0 and (x - 3.0) > -0.4 * (y + 2.0)

def tier(ti, t):
    cx, cy, rx, ry, zt, zb, k = t
    out = outline(t)
    lip = 0.85
    # core: the outline inset 1.2 m, a plain prism (hidden behind the columns)
    core = outline(t, 0.86)
    verts = [(x, y, zb) for x, y in core] + [(x, y, zt - 0.3) for x, y in core]
    n = len(core)
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for j in range(n):
        j2 = (j + 1) % n
        faces.append((j, j2, n + j2, n + j))
    L.obj_from("core%d" % ti, verts, faces, M["stone2"], smooth=False)
    # chunky faceted rock columns along the outline, ~1.9 m wide
    per = [0.0]
    for j in range(N_OUT):
        a, b = out[j], out[(j + 1) % N_OUT]
        per.append(per[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = per[-1]
    ncol = int(total / 1.9)
    def at(s):
        s %= total
        for j in range(N_OUT):
            if per[j + 1] >= s:
                f = (s - per[j]) / max(per[j + 1] - per[j], 1e-6)
                a, b = out[j], out[(j + 1) % N_OUT]
                return (a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f)
        return out[0]
    for c in range(ncol):
        s0 = total * c / ncol
        s1 = total * (c + 1) / ncol
        p0, p1 = Vector(at(s0) + (0.0,)), Vector(at(s1) + (0.0,))
        mid = (p0 + p1) / 2
        inward = Vector((cx - mid.x, cy - mid.y, 0.0)).normalized()
        bulge = rnd.uniform(0.15, 0.45)
        o0 = p0 - inward * rnd.uniform(-0.1, 0.12)
        o1 = p1 - inward * rnd.uniform(-0.1, 0.12)
        om = mid - inward * bulge + (p1 - p0).normalized() * rnd.uniform(-0.25, 0.25)
        i0, i1 = p0 + inward * 2.2, p1 + inward * 2.2
        ztop = zt - lip - rnd.uniform(0.0, 0.7)
        inset = rnd.uniform(0.12, 0.35)
        ring_b = [o0, om, o1, i1, i0]
        ring_t = [o0 + inward * inset, om + inward * (inset + 0.1), o1 + inward * inset, i1, i0]
        verts = [(v.x, v.y, zb) for v in ring_b] + [(v.x, v.y, ztop) for v in ring_t]
        # a chamfered top: the outer ridge drops a little so the column reads as a block
        verts[6] = (verts[6][0], verts[6][1], ztop - rnd.uniform(0.1, 0.4))
        faces = [(4, 3, 2, 1, 0), (5, 6, 7, 8, 9)]
        for j in range(5):
            j2 = (j + 1) % 5
            faces.append((j, j2, 5 + j2, 5 + j))
        L.obj_from("col%d_%d" % (ti, c), verts, faces, M["stone"] if rnd.random() < 0.72 else M["stone2"], smooth=False)
    # moss cap: a gently domed top that overhangs and rolls over the columns
    # v2: a thick moss band whose lower edge hangs 0.9-2.4 m down the columns, wandering (v1's 1 m lip read
    # as a thin shelf edge again)
    prof = [(0.0, 0.28), (0.45, 0.22), (0.8, 0.12), (0.95, 0.02), (1.02, -0.05), (1.065, -0.22), (1.08, -0.5), (1.07, -0.85), (1.05, -1.0), (1.03, -1.0)]
    cverts, cfaces = [], []
    for j in range(N_OUT):
        x, y = out[j]
        a = 2 * math.pi * j / N_OUT
        hang = 0.9 + 1.5 * max(0.0, noise.noise(Vector((math.cos(a) * 2.6 + k * 7.0, math.sin(a) * 2.6, 3.0 + k))) + 0.15)
        for i, (s, dz) in enumerate(prof):
            if i == len(prof) - 2: dz = -0.55 - hang * 0.7
            if i == len(prof) - 1: dz = -0.6 - hang
            cverts.append((cx + (x - cx) * s, cy + (y - cy) * s, zt + dz))
    m_ = len(prof)
    for j in range(N_OUT):
        j2 = (j + 1) % N_OUT
        for i in range(m_ - 1):
            cfaces.append((j * m_ + i, j2 * m_ + i, j2 * m_ + i + 1, j * m_ + i + 1))
    L.obj_from("moss%d" % ti, cverts, cfaces, M["moss"])
    # moss drapes hanging down the faces
    for d in range(26 if ti == 0 else 18):
        j = rnd.randrange(N_OUT)
        x, y = out[j]
        if stair_side(x, y) and ti == 0: continue
        p = (cx + (x - cx) * 1.035, cy + (y - cy) * 1.035, zt - 1.0 - rnd.uniform(0.2, 1.4))
        L.blob("drape%d_%d" % (ti, d), rnd.uniform(0.5, 0.9), p, M["drape"], squash=(1.2, 0.55, rnd.uniform(1.3, 2.4)), seed=ti * 50 + d)
    return out

outs = [tier(i, t) for i, t in enumerate(TIERS)]

# ---- S-curve stair ramp down the right flank ------------------------------------------------------------
P = [(4.2, 4.2, 11.75), (6.6, 3.0, 10.7), (8.4, 1.0, 9.4), (9.1, -1.4, 8.0), (8.7, -3.6, 6.6), (9.3, -5.8, 5.0),
     (10.6, -7.6, 3.2), (11.6, -9.2, 1.4), (12.0, -10.8, -0.2)]
P = [Vector(p) for p in P]
def catmull(pts, n_per=8):
    out = []
    for i in range(len(pts) - 1):
        p0 = pts[max(i - 1, 0)]; p1 = pts[i]; p2 = pts[i + 1]; p3 = pts[min(i + 2, len(pts) - 1)]
        for k in range(n_per):
            t = k / n_per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out
path = catmull(P)
# v2: a grassy walkway on a rock rib (v1's sloped aprons hung like cloth): grass top with rolled edges, then
# faceted rock walls straight down to z -30
sec = [(-2.2, -1.4), (-2.05, -0.55), (-1.6, -0.06), (0.0, 0.0), (1.6, -0.06), (2.05, -0.55), (2.2, -1.4)]
rverts, rfaces, wverts, wfaces = [], [], [], []
for i, p in enumerate(path):
    q = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
    tan = Vector((q.x, q.y, 0.0)).normalized()
    side = Vector((tan.y, -tan.x, 0.0))
    for off, dz in sec:
        rverts.append((p.x + side.x * off, p.y + side.y * off, p.z + dz))
    for off in (-2.1, 2.1):
        jit = 0.18 * math.sin(i * 1.7 + off)
        wverts.append((p.x + side.x * (off + jit), p.y + side.y * (off + jit), p.z - 1.0))
        wverts.append((p.x + side.x * (off * 1.08 + jit), p.y + side.y * (off * 1.08 + jit), -30.0))
ns = len(sec)
for i in range(len(path) - 1):
    for j in range(ns - 1):
        a, b = i * ns + j, i * ns + j + 1
        rfaces.append((a, b, b + ns, a + ns))
    for w in (0, 2):
        a, b = i * 4 + w, (i + 1) * 4 + w
        wfaces.append((a, b, b + 1, a + 1) if w == 0 else (a, a + 1, b + 1, b))
L.obj_from("ramp", rverts, rfaces, M["grass"])
L.obj_from("ramp_wall", wverts, wfaces, M["stone2"], smooth=False)
# v3: faceted columns along both ramp walls (v2's flat wall read as one pink sheet from the right)
def column(name, p0, p1, inward, zb, ztop):
    mid = (p0 + p1) / 2
    bulge = rnd.uniform(0.15, 0.4)
    o0 = p0 - inward * rnd.uniform(-0.08, 0.1)
    o1 = p1 - inward * rnd.uniform(-0.08, 0.1)
    om = mid - inward * bulge
    i0, i1 = p0 + inward * 1.6, p1 + inward * 1.6
    inset = rnd.uniform(0.1, 0.3)
    rb = [o0, om, o1, i1, i0]
    rt = [o0 + inward * inset, om + inward * (inset + 0.1), o1 + inward * inset, i1, i0]
    verts = [(v.x, v.y, zb) for v in rb] + [(v.x, v.y, ztop) for v in rt]
    verts[6] = (verts[6][0], verts[6][1], ztop - rnd.uniform(0.1, 0.35))
    faces = [(4, 3, 2, 1, 0), (5, 6, 7, 8, 9)]
    for j in range(5):
        j2 = (j + 1) % 5
        faces.append((j, j2, 5 + j2, 5 + j))
    L.obj_from(name, verts, faces, M["stone"] if rnd.random() < 0.72 else M["stone2"], smooth=False)
for sgn in (-1, 1):
    edge = []
    for i, p in enumerate(path):
        q = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
        tan = Vector((q.x, q.y, 0.0)).normalized()
        side = Vector((tan.y, -tan.x, 0.0))
        edge.append((Vector((p.x, p.y, 0.0)) + side * sgn * 2.15, side * -sgn, p.z))
    i = 0
    while i < len(edge) - 2:
        j = min(i + 2, len(edge) - 1)
        (a, inw, za), (b, _, zb_) = edge[i], edge[j]
        column("rcol%d_%d" % (sgn, i), a, b, inw, -30.0, min(za, zb_) - 1.0 - rnd.uniform(0.0, 0.5))
        i = j

# slabs: large flat irregular stones sunk into the ramp, long axis across the path
arc = [0.0]
for i in range(1, len(path)):
    arc.append(arc[-1] + (path[i] - path[i - 1]).length)
NSLAB = 17
for k in range(NSLAB):
    s = arc[-1] * (k + 0.5) / NSLAB
    i = next(i for i in range(len(arc) - 1) if arc[i + 1] >= s)
    f = (s - arc[i]) / max(arc[i + 1] - arc[i], 1e-6)
    p = path[i].lerp(path[i + 1], f)
    q = path[i + 1] - path[i]
    yaw = math.atan2(q.y, q.x)
    pts = []
    for j in range(12):
        ph = 2 * math.pi * j / 12
        rr = rnd.uniform(0.88, 1.04)
        # rounded rectangle-ish: superellipse
        c, sn = math.cos(ph), math.sin(ph)
        ex = abs(c) ** 0.6 * (1 if c >= 0 else -1)
        ey = abs(sn) ** 0.6 * (1 if sn >= 0 else -1)
        pts.append((rr * 0.52 * ex, rr * 0.82 * ey))
    sw = rnd.uniform(1.25, 1.55)
    verts = [(x * sw / 0.82 * 0.82, y * sw / 0.82, 0.0) for x, y in pts] + [(x * sw / 0.82 * 0.78, y * sw / 0.82 * 0.95, 0.34) for x, y in pts]
    faces = [tuple(range(12))[::-1], tuple(range(12, 24))]
    for j in range(12):
        j2 = (j + 1) % 12
        faces.append((j, j2, j2 + 12, j + 12))
    ob = L.obj_from("slab%d" % k, verts, faces, M["step"], smooth=False)
    ob.rotation_euler = (0, 0, yaw)
    ob.location = (p.x, p.y, p.z - 0.2)
    md = ob.modifiers.new("bevel", "BEVEL"); md.width = 0.07; md.segments = 2
    if k % 3 == 1:
        L.blob("slab_moss%d" % k, 0.3, (p.x + 0.3, p.y, p.z + 0.13), M["drape"], squash=(1.5, 0.9, 0.15), seed=300 + k)

# ---- shrubs with small flowers on the tier lips and along the stair -------------------------------------
def bush(name, p, s, seed):
    r2 = random.Random(seed)
    for b in range(4):
        q = (p[0] + r2.uniform(-0.5, 0.5) * s, p[1] + r2.uniform(-0.5, 0.5) * s, p[2] + r2.uniform(0.15, 0.5) * s)
        L.blob("%s_%d" % (name, b), s * r2.uniform(0.42, 0.66), q, M["bush"] if b % 2 else M["bush2"], squash=(1, 1, 0.85), seed=seed + b)
    for f in range(4):
        q = (p[0] + r2.uniform(-0.6, 0.6) * s, p[1] + r2.uniform(-0.6, 0.6) * s, p[2] + r2.uniform(0.55, 0.9) * s)
        L.blob("%s_f%d" % (name, f), 0.12, q, M["flower"], seed=seed + 20 + f, jitter=0.05)
nb = 0
for ti, (t, out) in enumerate(zip(TIERS, outs)):
    cx, cy, rx, ry, zt, zb, k = t
    for j in range(26 if ti == 0 else 18):
        x, y = out[rnd.randrange(N_OUT)]
        if stair_side(x, y): continue
        bush("bush%d" % nb, (cx + (x - cx) * 0.97, cy + (y - cy) * 0.97, zt + 0.05), rnd.uniform(0.9, 1.5), 500 + nb * 7)
        nb += 1
for i in range(3, len(path) - 2, 4):
    p = path[i]
    q = path[i + 1] - path[i - 1]
    side = Vector((q.y, -q.x, 0.0)).normalized()
    sgn = 1 if (i // 4) % 2 else -1
    c = p + side * sgn * rnd.uniform(2.0, 2.5)
    bush("sbush%d" % i, (c.x, c.y, p.z - 0.5), rnd.uniform(0.7, 1.1), 900 + i)

print("TRIS_BEFORE_JOIN", L.tri_count())
names = list(L.join_by_material())
print("MATERIAL_OBJECTS", names)
print("TRIS", L.tri_count())
L.export_glb(out_glb)
print("EXPORTED", out_glb, os.path.getsize(out_glb))
files = L.sheet_render(out_png, 30.0, center=(0, 0, 1.0),
                       views=[("front", (0, -80, 0), (90, 0, 0)), ("right", (80, 0, 0), (90, 0, 90)), ("top", (0, 0, 80), (0, 0, 0)),
                              ("hero", (-30, -55, 40), None), ("back", (0, 80, 0), (90, 0, 180))])
print("RENDERS", files)
