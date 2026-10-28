"""Concept-1 valley kit V2 (ChatGPT checkpoint after milestone 1: the V1 islands read as rows of rectangular basalt
towers and the viaducts as evenly spaced arches; the concept's islands are irregular mesas at very different heights
with rounded tree-covered crowns, striated cliffs, projecting shelves, broken silhouettes, varied waterfalls).

Mesas: a lobed noise outline swept up a height profile (talus flare at the foot, a waist, an overhanging crown),
vertical striations and grooves, one or two projecting mossy shelves, a rounded grassy crown with clustered dark
trees and huts, waterfalls of varied width that hug the cliff from crown notches to the foot. Bridges: a viaduct
with unequal spans and a gently arched deck, tapered piers, hanging vines; a single great arch.
One glb per piece in <out_dir> (origin at the base centre, Z up, front -Y):
  mesa_wide (220 x 110 m, 70 m), mesa_round (130 x 110 m, 95 m), rock_tall (70 x 60 m, 170 m),
  mesa_lobed (180 x 120 m, 120 m), viaduct (deck at 80 m, 300 m long), arch (one arch, 140 m, deck at 70 m).
Usage: blender -b -P valley2.py -- <out_dir> <render_prefix.png>"""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import valley as V
from valley import srgb, mix, bblob, btube, add_mesh, flush, mats, MOSS_COL, spire
import mushlib as L
from mathutils import Vector, noise

out_dir, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out_dir, exist_ok=True)

def tree(M, p, s, seed):
    """valley.tree with low-poly crowns (sub 1): islands are seen from 400 m+, and V2 has 3x the trees."""
    r2 = random.Random(seed)
    btube(M["bark"], [p, p + Vector((0, 0, s * 0.5)), p + Vector((r2.uniform(-0.1, 0.1) * s, r2.uniform(-0.1, 0.1) * s, s * 0.9))], [s * 0.07, s * 0.05, s * 0.035], 5,
          col=lambda q: srgb("#3a2e28"))
    for j in range(4):
        q = p + Vector((r2.uniform(-0.3, 0.3) * s, r2.uniform(-0.3, 0.3) * s, s * r2.uniform(0.75, 1.15)))
        rr = s * r2.uniform(0.3, 0.45)
        bblob(M["leaf"], rr, tuple(q), squash=(1, 1, 0.8), sub=1, seed=r2.randint(0, 9999), jitter=0.2,
              col=lambda co, q=q, rr=rr: mix(srgb("#1e3424"), srgb("#5a7e48"), 0.45 + 0.7 * (co.z - q.z) / rr))

ROCK = [srgb("#5c5470"), srgb("#8a809e"), srgb("#aaa0b8"), srgb("#423c50")]

def profile(t, crown):
    """Radius factor up the cliff (t 0 foot .. 1 crown edge): talus flare, a waist, an overhanging crown."""
    pts = [(0.0, 1.22), (0.08, 1.06), (0.3, 0.97), (0.55, 0.93), (0.8, 0.96), (0.93, 1.0 + 0.05 * crown), (1.0, 1.02 + 0.06 * crown)]
    for (t0, r0), (t1, r1) in zip(pts, pts[1:]):
        if t <= t1: return r0 + (r1 - r0) * (t - t0) / (t1 - t0)
    return pts[-1][1]

def mesa(M, rx, ry, h, seed, lobes=3, crown=1.0, shelves=(0.45,), n_trees=12, n_spires=1, falls=((-1.57, 8.0, 0.8),), lean=0.0):
    r2 = random.Random(seed)
    NA, NH = 96, 22
    ph = [r2.uniform(0, 6.28) for _ in range(4)]
    def outline(a):
        w = 1.0 + 0.16 * math.sin(lobes * a + ph[0]) + 0.08 * math.sin((lobes + 2) * a + ph[1]) + 0.1 * noise.noise(Vector((math.cos(a) * 1.7, math.sin(a) * 1.7, seed * 0.37)))
        return w
    def shelf_k(t, a):
        k = 0.0
        for s_t in shelves:
            # a shelf on part of the circumference only, so the silhouette breaks
            reach = max(0.0, math.sin(a * 1.0 + s_t * 9.0 + seed))
            if s_t - 0.035 < t < s_t + 0.012: k += 0.13 * reach
        return k
    def radius(a, t):
        ridge = 0.035 * abs(math.sin(a * 46 + 2.0 * noise.noise(Vector((a * 3.0, t * 4.0, seed))))) + 0.03 * noise.noise(Vector((a * 9.0, t * 6.0, seed + 5)))
        return outline(a) * (profile(t, crown) + shelf_k(t, a)) * (1.0 - ridge)
    vs, fs, cols = [], [], []
    for i in range(NH + 1):
        t = i / NH
        z = -h * 0.12 + (h * 1.12) * t
        off = Vector((lean * h * t * t, 0.0, 0.0))
        for j in range(NA):
            a = 2 * math.pi * j / NA
            r = radius(a, t)
            p = Vector((math.cos(a) * rx * r, math.sin(a) * ry * r, z)) + off
            vs.append(p)
            groove = abs(math.sin(a * 46 + 2.0 * noise.noise(Vector((a * 3.0, t * 4.0, seed)))))
            n = noise.noise(Vector((p.x * 0.03, p.y * 0.03, p.z * 0.02)))
            c = mix(ROCK[0], ROCK[2], 0.25 + 0.5 * t + 0.35 * n)
            c = mix(c, ROCK[3], 0.45 * (1.0 - groove))
            if shelf_k(t, a) > 0.02 or t > 0.97: c = MOSS_COL(p)
            cols.append(c)
    for i in range(NH):
        for j in range(NA):
            j2 = (j + 1) % NA
            fs.append((i * NA + j, i * NA + j2, (i + 1) * NA + j2, (i + 1) * NA + j))
    add_mesh(M["rock"], vs, fs, cols)
    top_off = Vector((lean * h, 0.0, 0.0))
    # crown: a rounded grassy dome over the rim, with a mossy lip that hangs over the edge
    cv, cf = [], []
    NR = 7
    for k in range(NR + 1):
        u = k / NR
        for j in range(NA):
            a = 2 * math.pi * j / NA
            r = radius(a, 1.0) * (1.04 - 0.04 * u) * (1.0 - u * u * 0.98)
            dome = h * 0.06 * (1.0 - (1.0 - u) ** 2) * 0 + h * 0.07 * math.sin(u * math.pi * 0.5) ** 0.8
            z = h + dome + 1.5 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, u * 3 + seed))) - (2.0 if k == 0 else 0.0)
            cv.append(Vector((math.cos(a) * rx * r, math.sin(a) * ry * r, z)) + top_off)
    for k in range(NR):
        for j in range(NA):
            j2 = (j + 1) % NA
            cf.append((k * NA + j, k * NA + j2, (k + 1) * NA + j2, (k + 1) * NA + j))
    add_mesh(M["moss"], cv, cf, [MOSS_COL(p) for p in cv])
    # moss drapes over the crown edge and the shelves
    for k in range(int(NA * 0.5)):
        a = r2.uniform(0, 2 * math.pi)
        r = radius(a, 1.0) * 1.0
        p = Vector((math.cos(a) * rx * r, math.sin(a) * ry * r, h - 2.0)) + top_off
        ln = r2.uniform(0.05, 0.22) * h
        bblob(M["moss"], min(rx, ry) * 0.06, (p.x, p.y, p.z - ln / 2), squash=(1.0, 1.0, ln / (min(rx, ry) * 0.12)), sub=1, seed=r2.randint(0, 9999), col=MOSS_COL, jitter=0.3)
    for s_t in shelves:
        for k in range(18):
            a = r2.uniform(0, 2 * math.pi)
            if shelf_k(s_t, a) < 0.03: continue
            r = radius(a, s_t)
            z = -h * 0.12 + h * 1.12 * s_t
            p = Vector((math.cos(a) * rx * r * 0.97, math.sin(a) * ry * r * 0.97, z + 1.0)) + Vector((lean * h * s_t * s_t, 0, 0))
            tree(M, p, min(rx, ry) * r2.uniform(0.16, 0.26), r2.randint(0, 9999))
    # trees clustered on the crown (denser toward the rim, as the concept's dark round crowns); v2 (capture c1v14:
    # crowns read as bare olive tables): 3x the trees plus low dark shrub masses between them
    for k in range(int(min(rx, ry) * 0.6)):
        a = r2.uniform(0, 2 * math.pi); u = math.sqrt(r2.uniform(0.0, 1.0)) * 0.9
        r = radius(a, 1.0) * u
        p = Vector((math.cos(a) * rx * r, math.sin(a) * ry * r, h + h * 0.07 * math.sin((1 - u) * math.pi * 0.5) ** 0.8))
        s = min(rx, ry) * r2.uniform(0.08, 0.14)
        bblob(M["leaf"], s, (p.x, p.y, p.z + s * 0.3), squash=(1.3, 1.3, 0.6), sub=1, seed=r2.randint(0, 9999), jitter=0.25,
              col=lambda co, s=s, z0=p.z: mix(srgb("#1a2c20"), srgb("#4a6a44"), 0.4 + (co.z - z0) / (s * 1.2)))
    for k in range(n_trees * 3):
        a = r2.uniform(0, 2 * math.pi); u = math.sqrt(r2.uniform(0.0, 1.0)) * 0.85
        r = radius(a, 1.0) * u
        p = Vector((math.cos(a) * rx * r, math.sin(a) * ry * r, h + h * 0.07 * math.sin((1 - u) * math.pi * 0.5) ** 0.8 - 0.5)) + top_off
        tree(M, p, min(rx, ry) * r2.uniform(0.18, 0.3) * (1.0 + 0.5 * u), r2.randint(0, 9999))
    # v3 (cell analysis c1v19: the valley cells read neutral, the concept's violet b -17..-20): glowing violet
    # flora and a few warm lamps among the crown trees, as the concept's bioluminescent island tops
    for k in range(int(min(rx, ry) * 0.5)):
        a = r2.uniform(0, 2 * math.pi); u = math.sqrt(r2.uniform(0.0, 1.0)) * 0.92
        r = radius(a, 1.0) * u
        p = Vector((math.cos(a) * rx * r, math.sin(a) * ry * r, h + h * 0.07 * math.sin((1 - u) * math.pi * 0.5) ** 0.8))
        bblob(M["glowflora"] if r2.random() < 0.85 else M["lamp"], min(rx, ry) * r2.uniform(0.025, 0.05), (p.x, p.y, p.z + 1.0), squash=(1, 1, 0.7), sub=1, seed=r2.randint(0, 9999))
    for k in range(n_spires):
        a = r2.uniform(0, 2 * math.pi); u = r2.uniform(0.1, 0.5)
        r = radius(a, 1.0) * u
        p = Vector((math.cos(a) * rx * r, math.sin(a) * ry * r, h + h * 0.05)) + top_off
        spire(M, p, min(rx, ry) * r2.uniform(0.35, 0.55), r2.randint(0, 9999), r2.uniform(0, 6.28))
    # waterfalls hugging the cliff: (angle, width m, length fraction of the height)
    for (a, w, frac) in falls:
        pts = []
        n = 26
        for i in range(n + 1):
            t = 1.0 - frac * i / n
            r = radius(a, max(0.0, t)) * 1.0
            z = -h * 0.12 + h * 1.12 * t
            out = Vector((math.cos(a), math.sin(a), 0.0))
            p = Vector((math.cos(a) * rx * r, math.sin(a) * ry * r, z)) + out * (2.5 + 3.0 * (i / n) ** 2) + Vector((lean * h * t * t, 0, 0))
            pts.append(p)
        side = Vector((-math.sin(a), math.cos(a), 0.0))
        fv, ff = [], []
        for i, p in enumerate(pts):
            ww = w * (0.55 + 1.2 * (i / n) ** 1.6)
            wob = side * math.sin(i * 0.6 + a * 5) * w * 0.15
            fv.append(p - side * ww / 2 + wob); fv.append(p + side * ww / 2 + wob)
        for i in range(n):
            ff.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
        add_mesh(M["falls"], fv, ff, [(1, 1, 1)] * len(fv))
        # spray at the foot
        foot = pts[-1]
        for k in range(5):
            bblob(M["spray"], w * r2.uniform(0.6, 1.1), (foot.x + r2.uniform(-w, w), foot.y + r2.uniform(-w, w), foot.z + r2.uniform(-2, 4)), squash=(1.3, 1.3, 0.7), sub=2, seed=r2.randint(0, 9999), jitter=0.25)

def piece(name, **kw):
    L.reset(); M = mats()
    M["spray"] = L.mat("valley_spray", "#e8ecff", 0.5, "#c8d4ff", 0.5)
    M["glowflora"] = L.mat("valley_glowflora", "#b48aff", 0.5, "#9a6aff", 1.6)
    mesa(M, **kw)
    flush(name)

piece("mesa_wide", rx=110.0, ry=55.0, h=70.0, seed=31, lobes=3, crown=1.0, shelves=(0.5,), n_trees=40, n_spires=3, falls=((-1.75, 12.0, 0.95), (-1.2, 6.0, 0.85), (-2.3, 4.0, 0.7)))
piece("mesa_round", rx=65.0, ry=55.0, h=95.0, seed=37, lobes=4, crown=1.2, shelves=(0.42, 0.7), n_trees=22, n_spires=2, falls=((-1.5, 9.0, 0.9),))
piece("rock_tall", rx=35.0, ry=30.0, h=170.0, seed=41, lobes=2, crown=1.6, shelves=(0.35, 0.62), n_trees=9, n_spires=1, falls=((-1.9, 5.0, 0.8),), lean=0.06)
piece("mesa_lobed", rx=90.0, ry=60.0, h=120.0, seed=43, lobes=5, crown=1.1, shelves=(0.55,), n_trees=30, n_spires=2, falls=((-1.4, 14.0, 0.92), (-2.0, 7.0, 0.8)))

def bridge(name, spans, deck, rise, width=9.0, seed=0, kiosks=True):
    """Unequal round arches on tapering piers; the deck arcs up `rise` m at mid-length; vines hang from the arches."""
    L.reset(); M = mats(); r2 = random.Random(seed)
    total = sum(spans); x0 = -total / 2
    xs = [x0]
    for s in spans: xs.append(xs[-1] + s)
    deck_z = lambda x: deck + rise * (1.0 - (2.0 * (x - x0) / total - 1.0) ** 2)
    stone_col = lambda p: mix(srgb("#6c6478"), srgb("#a69cb2"), 0.35 + 0.45 * (p.z / (deck + rise)) + 0.2 * noise.noise(Vector((p.x * 0.08, p.y * 0.08, p.z * 0.05))))
    for i, x in enumerate(xs):
        top = deck_z(x)
        pw = (6.5 if 0 < i < len(xs) - 1 else 9.0) * r2.uniform(0.85, 1.15)
        prof = [(pw * 2.0, -14.0), (pw * 1.45, 0.0), (pw * 1.0, top * 0.18), (pw * 0.66, top * 0.5), (pw * 0.58, top - 22.0), (pw * 0.78, top - 6.0), (pw * 0.82, top)]
        vs, fs = [], []
        sides = 10
        for j in range(sides):
            th = 2 * math.pi * j / sides
            for (rr, z) in prof:
                k = 1.0 + 0.08 * noise.noise(Vector((math.cos(th) * 2, math.sin(th) * 2, z * 0.05 + i)))
                vs.append(Vector((x + rr * k * math.cos(th), rr * k * 0.7 * math.sin(th), z)))
        m = len(prof)
        for j in range(sides):
            j2 = (j + 1) % sides
            for k in range(m - 1):
                fs.append((j * m + k, j2 * m + k, j2 * m + k + 1, j * m + k + 1))
        add_mesh(M["stone"], vs, fs, [stone_col(p) for p in vs])
        for k in range(6):
            q = Vector((x + r2.uniform(-1, 1) * pw * 1.5, r2.uniform(-1, 1) * pw * 1.1, r2.uniform(-8, 8)))
            bblob(M["rock"], pw * r2.uniform(0.7, 1.2), tuple(q), squash=(1, 0.8, 1.2), sub=1, seed=r2.randint(0, 9999), col=lambda p: mix(srgb("#5c5470"), srgb("#8a809e"), 0.5))
        bblob(M["moss"], pw * 0.8, (x, 0, top - 7), squash=(1.2, 1.3, 0.55), sub=1, seed=i + seed, col=MOSS_COL)
    for i in range(len(spans)):
        a0, a1 = xs[i] + 3.5, xs[i + 1] - 3.5
        cx = (a0 + a1) / 2; r = (a1 - a0) / 2
        crown = min(deck_z(a0), deck_z(a1)) - 6.0
        spring = crown - r * r2.uniform(0.8, 1.0)
        n = 24
        vs, fs = [], []
        for k in range(n + 1):
            a = math.pi * k / n
            ix = cx - r * math.cos(a); iz = spring + (crown - spring) * math.sin(a)
            for yy in (-width / 2, width / 2):
                vs.append(Vector((ix, yy, iz))); vs.append(Vector((ix, yy, deck_z(ix) - 1.0)))
        for k in range(n):
            q0 = k * 4; q1 = (k + 1) * 4
            fs.append((q0, q1, q1 + 1, q0 + 1)); fs.append((q0 + 3, q1 + 3, q1 + 2, q0 + 2)); fs.append((q0 + 2, q1 + 2, q1, q0))
        add_mesh(M["stone"], vs, fs, [stone_col(p) for p in vs], smooth=False)
        for k in range(int(r / 4)):
            a = r2.uniform(0.1, 0.9) * math.pi
            q = Vector((cx - r * math.cos(a), r2.choice((-width / 2 - 0.5, width / 2 + 0.5)), spring + (crown - spring) * math.sin(a)))
            ln = r2.uniform(5, 22)
            bblob(M["moss"], 1.4, (q.x, q.y, q.z - ln / 2), squash=(1, 0.6, ln / 2.8), sub=1, seed=r2.randint(0, 9999), col=MOSS_COL, jitter=0.3)
    # deck: a strip following the arc, with parapets and lanterns
    xa, xb = xs[0] - 6.0, xs[-1] + 6.0
    N = 60
    dv, df = [], []
    for k in range(N + 1):
        x = xa + (xb - xa) * k / N; z = deck_z(x)
        for yy, dz in ((-width / 2 - 0.6, 0.0), (width / 2 + 0.6, 0.0), (width / 2 + 0.6, -2.5), (-width / 2 - 0.6, -2.5)):
            dv.append(Vector((x, yy, z + dz)))
    for k in range(N):
        for e in range(4):
            e2 = (e + 1) % 4
            df.append((k * 4 + e, (k + 1) * 4 + e, (k + 1) * 4 + e2, k * 4 + e2))
    add_mesh(M["stone"], dv, df, [stone_col(p) for p in dv], smooth=False)
    for yy in (-width / 2, width / 2):
        btube(M["stone"], [Vector((xa + (xb - xa) * k / N, yy, deck_z(xa + (xb - xa) * k / N) + 1.3)) for k in range(N + 1)], [0.45] * (N + 1), 4, col=stone_col)
        x = xa
        while x <= xb:
            z = deck_z(x)
            btube(M["stone"], [Vector((x, yy, z)), Vector((x, yy, z + 1.4))], [0.32, 0.32], 4, col=stone_col)
            x += 3.2
        x = xa + 4.0
        while x <= xb:
            z = deck_z(x)
            btube(M["bark"], [Vector((x, yy, z)), Vector((x, yy, z + 3.0))], [0.22, 0.18], 5, col=lambda p: srgb("#3a2a20"))
            bblob(M["lamp"], 0.6, (x, yy, z + 3.2), squash=(0.9, 0.9, 1.3), sub=1, jitter=0.0)
            x += r2.uniform(11.0, 16.0)
    if kiosks:
        for x in (xs[0], xs[len(xs) // 2], xs[-1]):
            spire(M, Vector((x, 0, deck_z(x))), 12.0, int(x) + 700)
    flush(name)

bridge("viaduct", [70.0, 48.0, 86.0, 56.0, 40.0], 80.0, 12.0, seed=51)
bridge("arch", [140.0], 70.0, 6.0, width=7.0, seed=53, kiosks=False)

L.reset()
names = ("mesa_wide", "mesa_round", "rock_tall", "mesa_lobed", "viaduct", "arch")
for i, name in enumerate(names):
    bpy.ops.import_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"))
    for ob in bpy.context.selected_objects:
        ob.location.x += (-520, -280, -120, 60, 360, 640)[i]
files = L.sheet_render(out_png, 1500.0, center=(60, 0, 80), views=[("front", (0, -900, 0), (90, 0, 0)), ("hero", (-450, -700, 320), None)])
print("RENDERS", files)
