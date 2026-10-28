"""v3 (capture pr02: pale boulders and white coin-stack steps): greyer stone, step bases mossed.
Mossy promontory with curved stone steps, from ChatGPT sheet mush-sheet-promontory-01.
Three stacked rounded tiers, 12 m tall; top platform ~16 x 13 m, set back to the rear-left; stone slabs
curve down the right-front. A rock skirt continues 30 m below z=0 so it can stand on a slope.
Front faces -Y (glTF +Z). Usage: blender -b -P promontory.py -- <out.glb> <render_prefix.png>"""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector, noise

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(5)

M = {
    "moss": L.mat("moss_top", "#7f9a34", 0.95),
    "moss_lip": L.mat("moss_lip", "#6c8a2e", 0.95),
    "grass": L.mat("grass", "#93ad57", 0.95),
    "stone": L.mat("stone", "#968b80", 0.9),
    "stone2": L.mat("stone_shadow", "#6f6862", 0.9),
    "earth": L.mat("earth", "#6e4f36", 0.95),
    "step": L.mat("step_stone", "#a1988b", 0.85),
    "bush": L.mat("bush", "#4f7a2f", 0.85),
    "bush2": L.mat("bush_light", "#6c9a3a", 0.85),
    "flower": L.mat("flower", "#f2dc6a", 0.6),
}

# tiers: (centre x, y, radius x, radius y, z bottom, z top)
TIERS = [(1.0, -1.0, 12.0, 10.0, -30.0, 4.0), (0.0, 0.2, 10.0, 8.4, 4.0, 8.0), (-1.0, 1.2, 8.0, 6.6, 8.0, 12.0)]
SEG = 64

def wob(a, k, amp=0.07):
    return 1.0 + amp * noise.noise(Vector((math.cos(a) * 1.7 + k * 3.1, math.sin(a) * 1.7, k)))

def ring(cx, cy, rx, ry, k, scale=1.0, amp=0.07):
    pts = []
    for j in range(SEG):
        a = 2 * math.pi * j / SEG
        w = wob(a, k, amp) * scale
        pts.append((cx + rx * w * math.cos(a), cy + ry * w * math.sin(a), a))
    return pts

def tier(k, cx, cy, rx, ry, z0, z1):
    lip = 0.9
    # rock face: rings from z0 to just under the lip, slightly tapering in at the top, faceted per column
    face_rings = [(z0, 1.02), (min(z1 - 2.4, z0 + 0.6) if z0 > -1 else -1.0, 1.0), (z1 - 1.9, 0.985), (z1 - lip, 0.96)]
    verts, faces, mats = [], [], []
    for (z, s) in face_rings:
        for (x, y, a) in ring(cx, cy, rx, ry, k, s):
            # faceted blocks: push alternate columns in and out a little
            col = int(a / (2 * math.pi) * SEG)
            f = 1.0 + (0.025 if (col // 3) % 2 else -0.02)
            verts.append((cx + (x - cx) * f, cy + (y - cy) * f, z))
    n = SEG
    for r in range(len(face_rings) - 1):
        for j in range(n):
            j2 = (j + 1) % n
            faces.append((r * n + j, r * n + j2, (r + 1) * n + j2, (r + 1) * n + j))
            mats.append(1 if ((j // 3) + r) % 3 == 0 else 0)
    me = bpy.data.meshes.new("rock%d" % k)
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new("rock%d" % k, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(M["stone2"])   # core, mostly hidden behind the boulders
    # v2: the face is a ring of big rounded boulders (the sheet's stacked rock blocks); v1's two-material
    # facet checker read as a chessboard
    nbould = int(2 * math.pi * (rx + ry) / 2 / 3.2)
    for b in range(nbould):
        a = 2 * math.pi * (b + rnd.uniform(-0.2, 0.2)) / nbould
        w = wob(a, k) * 0.99
        zc_top = z1 - lip - 0.2
        zc_bot = max(z0, z1 - 4.6)
        hgt = zc_top - zc_bot
        for layer in range(2 if hgt > 3.0 else 1):
            hh = hgt / (2 if hgt > 3.0 else 1)
            zc = zc_bot + hh * (layer + 0.5) + rnd.uniform(-0.25, 0.25)
            p = (cx + rx * w * math.cos(a), cy + ry * w * math.sin(a), zc)
            bo = L.blob("boulder%d_%d_%d" % (k, b, layer), 1.0, p, M["stone"] if rnd.random() < 0.7 else M["stone2"],
                        squash=(rnd.uniform(1.6, 2.0), 1.25, hh * 0.62), sub=2, seed=k * 100 + b * 3 + layer, jitter=0.12)
            bo.rotation_euler = (0, 0, a + math.pi / 2)
    if z0 < 0:
        # the skirt below the bottom tier: a few deep boulders so the base reads as bedrock
        for b in range(nbould):
            a = 2 * math.pi * (b + 0.5) / nbould
            w = wob(a, k) * 1.0
            p = (cx + rx * w * math.cos(a), cy + ry * w * math.sin(a), -3.0)
            bo = L.blob("bed%d_%d" % (k, b), 1.0, p, M["stone2"], squash=(2.2, 1.4, 3.2), seed=900 + b, jitter=0.12)
            bo.rotation_euler = (0, 0, a + math.pi / 2)
    # moss cap: an overhanging rounded slab, lip rolled over the face, gently domed top
    cap_profile = [(1.0, -0.15), (1.045, z1 - lip + 0.25), (1.06, z1 - 0.35), (1.04, z1 - 0.08), (1.0, z1), (0.75, z1 + 0.12), (0.4, z1 + 0.2), (0.0, z1 + 0.22)]
    cverts, cfaces = [], []
    for j in range(n):
        a = 2 * math.pi * j / n
        w = wob(a, k)
        for (s, z) in cap_profile:
            if z < 0: z = z1 - lip - 0.15
            cverts.append((cx + rx * w * s * math.cos(a), cy + ry * w * s * math.sin(a), z))
    m_ = len(cap_profile)
    for j in range(n):
        j2 = (j + 1) % n
        for i in range(m_ - 1):
            cfaces.append((j * m_ + i, j2 * m_ + i, j2 * m_ + i + 1, j * m_ + i + 1))
    cap = L.obj_from("moss%d" % k, cverts, cfaces, M["moss"])
    # moss drapes down the face in a few places
    for d in range(10):
        a = rnd.uniform(0, 2 * math.pi)
        w = wob(a, k) * 1.03
        p = (cx + rx * w * math.cos(a), cy + ry * w * math.sin(a), z1 - lip - rnd.uniform(0.3, 1.0))
        L.blob("drape%d_%d" % (k, d), rnd.uniform(0.6, 1.1), p, M["moss_lip"], squash=(1.3, 1.3, 0.9), seed=k * 40 + d)
    return ring(cx, cy, rx, ry, k)

edges = []
for k, (cx, cy, rx, ry, z0, z1) in enumerate(TIERS):
    edges.append(tier(k, cx, cy, rx, ry, z0, z1))

# ---- stone steps curving down the right-front -------------------------------------------------------------
def tier_edge_point(k, a, inset=0.0):
    cx, cy, rx, ry, z0, z1 = TIERS[k]
    w = wob(a, k)
    return Vector((cx + (rx * w - inset) * math.cos(a), cy + (ry * w - inset) * math.sin(a), z1))

# path: start on the top platform's right-front edge, wind down across tier 2 and tier 1 to the ground
steps = []
a_top, a_bot = math.radians(-10), math.radians(-75)
N = 16
for i in range(N):
    t = i / (N - 1)
    a = a_top + (a_bot - a_top) * t
    z = 12.0 - t * 12.0 + 0.15
    # radius: hug the outside of whichever tier is below this height
    k = 2 if z > 8.0 else (1 if z > 4.0 else 0)
    cx, cy, rx, ry, z0, z1 = TIERS[k]
    w = wob(a, k)
    out = 1.2 + 1.5 * ((z1 - z) / 4.0)
    p = Vector((cx + (rx * w + out) * math.cos(a), cy + (ry * w + out) * math.sin(a), z))
    steps.append((p, a))
for i, (p, a) in enumerate(steps):
    # irregular rounded slab
    pts = []
    for j in range(10):
        ph = 2 * math.pi * j / 10
        rr = rnd.uniform(0.85, 1.05)
        pts.append((rr * 1.9 * math.cos(ph), rr * 1.15 * math.sin(ph)))
    verts = [(x, y, 0.0) for x, y in pts] + [(x * 0.95, y * 0.95, 0.38) for x, y in pts]
    faces = [tuple(range(10))[::-1], tuple(range(10, 20))]
    for j in range(10):
        j2 = (j + 1) % 10
        faces.append((j, j2, j2 + 10, j + 10))
    ob = L.obj_from("step%d" % i, verts, faces, M["step"], smooth=False)
    ob.rotation_euler = (0, 0, a + math.pi / 2)
    ob.location = (p.x, p.y, p.z - 0.38)
    md = ob.modifiers.new("bevel", "BEVEL"); md.width = 0.08; md.segments = 2
    # a stone block under each slab down to the tier below (or the ground)
    below = 0.0 if p.z < 4.2 else (4.0 if p.z < 8.2 else 8.0)
    if p.z - 0.38 - below > 0.2:
        h = p.z - 0.38 - below
        L.box("step_base%d" % i, (3.0, 1.8, h), (p.x, p.y, below + h / 2), M["moss_lip"], rot=(0, 0, a + math.pi / 2), bevel=0.15)
    if i % 3 == 1:
        L.blob("step_moss%d" % i, 0.35, (p.x + 0.4, p.y, p.z + 0.02), M["moss_lip"], squash=(1.6, 0.9, 0.15), seed=300 + i)

# ---- shrubs and small flowers on the tier lips ------------------------------------------------------------
def bush(name, p, s, seed):
    r2 = random.Random(seed)
    for b in range(4):
        q = (p[0] + r2.uniform(-0.5, 0.5) * s, p[1] + r2.uniform(-0.5, 0.5) * s, p[2] + r2.uniform(0.2, 0.6) * s)
        L.blob("%s_%d" % (name, b), s * r2.uniform(0.45, 0.7), q, M["bush"] if b % 2 else M["bush2"], squash=(1, 1, 0.85), seed=seed + b)
    for f in range(5):
        q = (p[0] + r2.uniform(-0.7, 0.7) * s, p[1] + r2.uniform(-0.7, 0.7) * s, p[2] + r2.uniform(0.6, 1.0) * s)
        L.blob("%s_f%d" % (name, f), 0.13, q, M["flower"], seed=seed + 20 + f, jitter=0.05)
nb = 0
for k, (cx, cy, rx, ry, z0, z1) in enumerate(TIERS):
    for j in range(9 + 3 * k):
        a = rnd.uniform(0, 2 * math.pi)
        if -1.4 < a - 2 * math.pi < -0.1 or -1.4 < a < -0.1: continue   # keep the steps clear
        w = wob(a, k) * 0.97
        bush("bush%d" % nb, (cx + rx * w * math.cos(a), cy + ry * w * math.sin(a), z1 + 0.1), rnd.uniform(1.0, 1.6), 500 + nb * 7)
        nb += 1

print("TRIS_BEFORE_JOIN", L.tri_count())
names = list(L.join_by_material())
print("MATERIAL_OBJECTS", names)
print("TRIS", L.tri_count())
L.export_glb(out_glb)
print("EXPORTED", out_glb, os.path.getsize(out_glb))
files = L.sheet_render(out_png, 30.0, center=(0, 0, 6.0),
                       views=[("front", (0, -80, 0), (90, 0, 0)), ("right", (80, 0, 0), (90, 0, 90)), ("top", (0, 0, 80), (0, 0, 0)),
                              ("hero", (-30, -55, 40), None), ("back", (0, 80, 0), (90, 0, 180))])
print("RENDERS", files)
