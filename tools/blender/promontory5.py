"""Promontory V3 from ChatGPT sheet mush-sheet-promontory-03 (ChatGPT checkpoint 2: V2's vertical striped
column walls read as constructed geometry): the V2 layout with the tier faces built from overlapping,
irregular, faceted boulder masses of different sizes and leans, and the stair set in a grassy slope lined
with boulders instead of a walled rib. No straight vertical lines.
Usage: blender -b -P promontory5.py -- <out.glb> <render_prefix.png>

V2 notes:
v4 (capture pr10: lime ramp, pale flat-lit stone): olive ramp 3.2 m wide, darker stone.
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


import bmesh
def rock(name, loc, size, mat, lean=(0.0, 0.0), yaw=0.0, seed=0, n=16, bevel=0.12):
    """A low-poly faceted boulder: the convex hull of n points on a squashed ellipsoid, flat shaded,
    lightly bevelled (the sheet's chunky rounded rocks with big facets)."""
    r2 = random.Random(seed)
    bm = bmesh.new()
    for _ in range(n):
        th = r2.uniform(0, 2 * math.pi); ph = math.acos(r2.uniform(-1, 1))
        rr = r2.uniform(0.82, 1.0)
        bm.verts.new((rr * math.sin(ph) * math.cos(th) * size[0] * 0.5, rr * math.sin(ph) * math.sin(th) * size[1] * 0.5, rr * math.cos(ph) * size[2] * 0.5))
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(mat)
    ob.rotation_euler = (lean[0], lean[1], yaw)
    ob.location = loc
    if bevel > 0:
        md = ob.modifiers.new("bevel", "BEVEL"); md.width = bevel; md.segments = 1; md.limit_method = "ANGLE"
    return ob

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(7)

M = {
    "moss": L.mat("moss_top", "#6a8236", 0.95),
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
    # v3: overlapping faceted boulder masses along the outline, two staggered courses on tall faces
    face_h = zt - lip - max(zb, zt - 7.5)
    courses = 2 if face_h > 4.5 else 1
    nrock = int(total / 2.6)
    for c in range(nrock):
        for course in range(courses):
            s0 = total * (c + 0.5 * course + rnd.uniform(-0.15, 0.15)) / nrock
            p = Vector(at(s0) + (0.0,))
            inward = Vector((cx - p.x, cy - p.y, 0.0)).normalized()
            h_course = face_h / courses
            ztop = zt - lip + 0.2 - course * h_course
            hh = h_course * rnd.uniform(1.05, 1.45)
            w = rnd.uniform(2.6, 4.2)
            d = rnd.uniform(2.4, 3.4)
            cz = ztop - hh * 0.5
            yaw = math.atan2(inward.y, inward.x) + math.pi / 2 + rnd.uniform(-0.3, 0.3)
            loc = p + inward * (d * 0.32 - rnd.uniform(0.0, 0.35)) + Vector((0, 0, cz))
            rock("rk%d_%d_%d" % (ti, c, course), loc, (w, d, hh), M["stone"] if rnd.random() < 0.7 else M["stone2"],
                 lean=(rnd.uniform(-0.12, 0.12), rnd.uniform(-0.12, 0.12)), yaw=yaw, seed=ti * 1000 + c * 7 + course, n=rnd.randint(13, 18))
    if zb < 0:
        # bedrock: big boulders round the foot so the base reads as an outcrop, not a pedestal
        for c in range(int(total / 4.0)):
            p = Vector(at(total * (c + 0.3) / int(total / 4.0)) + (0.0,))
            outward = Vector((p.x - cx, p.y - cy, 0.0)).normalized()
            rock("bed%d_%d" % (ti, c), p + outward * rnd.uniform(0.2, 0.9) + Vector((0, 0, rnd.uniform(-3.5, -1.5))), (rnd.uniform(3.5, 5.5), rnd.uniform(3.0, 4.0), rnd.uniform(4.0, 6.0)),
                 M["stone2"], yaw=rnd.uniform(0, 6.28), seed=5000 + ti * 100 + c)
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

# ---- V5 hillside stair (ChatGPT sheet mush-sheet-stair-04; checkpoint 3: the three-flight stair with landings
# read as a long constructed zigzag): ten large oval slabs stepping down one continuous rounded grassy slope
# along a short S-curve ~14 m in plan, grass lapping the slab edges, mossy rocks only where it steepens and at
# the foot, no landings or walls.
P = [(4.4, 3.6, 11.75), (6.3, 2.4, 10.6), (7.6, 0.4, 8.7), (7.8, -2.0, 6.6), (8.6, -4.3, 4.2), (9.8, -6.3, 1.8), (10.5, -7.9, -0.2)]
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
# A wide rounded grass mound under the stair: soft shoulders falling ~5 m to either side.
sec = [(-4.6, -4.0), (-3.6, -2.0), (-2.8, -0.9), (-2.1, -0.3), (-1.4, -0.04), (0.0, 0.0), (1.4, -0.04), (2.1, -0.3), (2.8, -0.9), (3.6, -2.0), (4.6, -4.0)]
arc = [0.0]
for i in range(1, len(path)):
    arc.append(arc[-1] + (path[i] - path[i - 1]).length)
NSLAB = 10
LS = arc[-1] / NSLAB
SLAB_S = [LS * (k + 0.45 + rnd.uniform(-0.06, 0.06)) for k in range(NSLAB)]
def zpath(s):
    i = next(i for i in range(len(arc) - 1) if arc[i + 1] >= s)
    f = (s - arc[i]) / max(arc[i + 1] - arc[i], 1e-6)
    return path[i].z + (path[i + 1].z - path[i].z) * f
TREAD = [zpath(min(sk, arc[-1] - 0.01)) + 0.25 for sk in SLAB_S]
rverts, rfaces = [], []
for i, p in enumerate(path):
    q = path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]
    tan = Vector((q.x, q.y, 0.0)).normalized()
    side = Vector((tan.y, -tan.x, 0.0))
    wob = 1.0 + 0.12 * math.sin(i * 0.7)
    # stepped treads under the slabs in the middle of the slope, blending to the smooth shoulders
    k = max(0, min(NSLAB - 1, int(round(arc[i] / LS - 0.45))))
    zt = TREAD[k] - 0.45
    for off, dz in sec:
        w = max(0.0, min(1.0, (abs(off) - 1.4) / 1.4))
        z = zt * (1 - w) + (p.z + dz) * w if abs(off) < 2.8 else p.z + dz
        rverts.append((p.x + side.x * off * wob, p.y + side.y * off * wob, z))
ns = len(sec)
for i in range(len(path) - 1):
    for j in range(ns - 1):
        a_, b_ = i * ns + j, i * ns + j + 1
        rfaces.append((a_, b_, b_ + ns, a_ + ns))
L.obj_from("ramp", rverts, rfaces, M["grass"])
def at_arc(s):
    i = next(i for i in range(len(arc) - 1) if arc[i + 1] >= s)
    f = (s - arc[i]) / max(arc[i + 1] - arc[i], 1e-6)
    return path[i].lerp(path[i + 1], f), path[i + 1] - path[i]
M["slab"] = L.mat("slab_stone", "#bcae9e", 0.85)
M["slab_moss"] = L.mat("slab_moss", "#6a8a33", 0.95)
M["tuft"] = L.mat("grass_tuft", "#7a9c3a", 0.95)
def oval_slab(k, p, yaw, across, depth, thick, tilt):
    n = 14
    pts = []
    for j in range(n):
        ph = 2 * math.pi * j / n
        rr = rnd.uniform(0.92, 1.04)
        c, sn = math.cos(ph), math.sin(ph)
        ex = abs(c) ** 0.8 * (1 if c >= 0 else -1)
        ey = abs(sn) ** 0.8 * (1 if sn >= 0 else -1)
        pts.append((rr * 0.5 * depth * ex, rr * 0.5 * across * ey))
    verts = [(x, y, 0.0) for x, y in pts] + [(x * 0.94, y * 0.95, thick) for x, y in pts]
    faces = [tuple(range(n))[::-1], tuple(range(n, 2 * n))]
    for j in range(n):
        j2 = (j + 1) % n
        faces.append((j, j2, j2 + n, j + n))
    ob = L.obj_from("slab%d" % k, verts, faces, M["slab"], smooth=False)
    ob.rotation_euler = (tilt[0], tilt[1], yaw)
    ob.location = (p.x, p.y, p.z - thick + 0.22)
    md = ob.modifiers.new("bevel", "BEVEL"); md.width = 0.09; md.segments = 2
    return ob
for k in range(NSLAB):
    s = SLAB_S[k]
    p, q = at_arc(s)
    p = Vector((p.x, p.y, TREAD[k] - 0.22))
    yaw = math.atan2(q.y, q.x) + rnd.uniform(-0.12, 0.12)
    p = p + Vector((-q.y, q.x, 0.0)).normalized() * rnd.uniform(-0.25, 0.25)
    oval_slab(k, p, yaw, rnd.uniform(2.3, 2.9), rnd.uniform(1.2, 1.45), 0.7, (rnd.uniform(-0.05, 0.05), rnd.uniform(-0.05, 0.05)))
    if k % 3 == 1:
        L.blob("slabmoss%d" % k, 0.35, (p.x - 0.2, p.y + 0.4, p.z + 0.2), M["slab_moss"], squash=(1.4, 1.0, 0.12), seed=300 + k)
    # grass lapping over both slab ends
    side = Vector((q.y, -q.x, 0.0)).normalized()
    for sgn in (-1, 1):
        if rnd.random() < 0.8:
            c = p + side * sgn * rnd.uniform(1.15, 1.4)
            L.blob("tuft%d_%d" % (k, sgn), rnd.uniform(0.35, 0.55), (c.x, c.y, p.z + 0.12), M["tuft"], squash=(1.3, 1.0, 0.45), seed=400 + k * 2 + sgn)
# mossy rocks where the slope steepens and at the foot
def mossy_rock(name, c, size, seed):
    ob = rock(name, c, size, M["stone"], yaw=rnd.uniform(0, 6.28), seed=seed, n=22)
    L.blob(name + "_cap", max(size[0], size[1]) * 0.42, (c.x, c.y, c.z + size[2] * 0.42), M["moss"], squash=(1.1, 1.0, 0.32), seed=seed + 1)
    return ob
nr = 0
for frac, sgn, sz in [(0.38, 1, 2.0), (0.46, -1, 1.6), (0.62, 1, 2.4), (0.7, -1, 1.5), (0.86, 1, 2.6), (0.97, 1, 1.8), (1.0, -1, 2.2), (0.93, -1, 1.4)]:
    p, q = at_arc(arc[-1] * min(frac, 0.999))
    side = Vector((q.y, -q.x, 0.0)).normalized()
    c = p + side * sgn * rnd.uniform(2.1, 2.7) + Vector((0, 0, -0.55 * sz * 0.5))
    mossy_rock("srk%d" % nr, c, (sz * 1.25, sz, sz * 0.85), 7000 + nr * 3)
    nr += 1
for frac in (0.3, 0.52, 0.74):
    p, q = at_arc(arc[-1] * frac)
    side = Vector((q.y, -q.x, 0.0)).normalized()
    sz = rnd.uniform(3.2, 4.2)
    mossy_rock("brk%d" % nr, p - side * 3.6 + Vector((0, 0, -2.6)), (sz * 1.3, sz, sz * 1.1), 7500 + nr)
    nr += 1
print("STAIR_V5 slabs", NSLAB, "rocks", nr, "arc", round(arc[-1], 1))
for f in (0.2, 0.5, 0.8):
    p, q = at_arc(arc[-1] * f)
    side = Vector((q.y, -q.x, 0.0)).normalized()
    print("LANTERN_AT", tuple(round(v, 2) for v in (p - side * 2.0 + Vector((0, 0, -0.3)))))

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
    # v2 (review 23: a lime disc rimmed by identical bead shrubs): fewer shrubs in clusters of varied size
    # (2:1 and more) with gaps, boulders breaking the rim, darker moss mottling on the top
    for j in range(14 if ti == 0 else 10):
        jj = rnd.randrange(N_OUT)
        for m in range(rnd.choice([1, 1, 2, 3])):
            x, y = out[(jj + m * 2) % N_OUT]
            if stair_side(x, y): continue
            bush("bush%d" % nb, (cx + (x - cx) * 0.96, cy + (y - cy) * 0.96, zt + 0.05), rnd.uniform(0.6, 1.9), 500 + nb * 7)
            nb += 1
    for j in range(7 if ti == 0 else 5):
        x, y = out[rnd.randrange(N_OUT)]
        if stair_side(x, y): continue
        sz = rnd.uniform(1.4, 2.4)
        rock("rim%d_%d" % (ti, j), Vector((cx + (x - cx) * 0.99, cy + (y - cy) * 0.99, zt + 0.1)), (sz * 1.3, sz, sz * 0.8), M["stone"], yaw=rnd.uniform(0, 6.28), seed=9100 + ti * 50 + j)
    for j in range(16 if ti == 0 else 12):
        a = rnd.uniform(0, 2 * math.pi); r = math.sqrt(rnd.uniform(0.0, 0.85))
        L.blob("mott%d_%d" % (ti, j), rnd.uniform(1.2, 2.6), (cx + rx * r * math.cos(a), cy + ry * r * math.sin(a), zt + 0.18), M["drape"], squash=(1.4, 1.0, 0.06), seed=9300 + ti * 50 + j)
for i in range(2, len(path) - 2, 3):
    p = path[i]
    q = path[i + 1] - path[i - 1]
    side = Vector((q.y, -q.x, 0.0)).normalized()
    for sgn in (-1, 1):
        if rnd.random() < 0.35: continue
        c = p + side * sgn * rnd.uniform(1.9, 2.6)
        bush("sbush%d_%d" % (i, sgn), (c.x, c.y, p.z - 0.45), rnd.uniform(0.6, 1.0), 900 + i * 2 + sgn)

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
