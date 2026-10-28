"""Concept-1 eroded cliff-and-waterfall kit V3 from the ChatGPT sheet mush-c1-sheet-cliffs-01 (after ChatGPT checkpoint 2:
the V2 mesas still read as horizontal shelves). Each landform is a cluster of rounded, fissured rock columns of very
different heights: the columns overlap into deep vertical fissures, their mossy tops make stepped ledges and an
overhanging tree-covered crown, some narrow at the foot into cave-like undercuts; waterfalls pour from crown notches
down the faces and fray into spray. A curved rising bridge springs from a low ledge to one ~40% higher, S-shaped in
plan, on end piers with one mid arch.
Pieces (origin at the base centre, Z up, front -Y), one glb each in <out_dir>:
  tower (350 m tall, ~100 m wide), massif (220 m, ~300 m wide, two crowns and a saddle), needle (250 m, ~50 m,
  leaning), lowisle (100 m, ~200 m, pools), risebridge (400 m long, rising 48 m, deck from 72 to 120 m).
Usage: blender -b -P cliffs.py -- <out_dir> <render_prefix.png>"""
import bpy, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import valley as V
from valley import srgb, mix, bblob, btube, add_mesh, flush, mats, MOSS_COL, spire
import mushlib as L
from mathutils import Vector, noise

out_dir, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
os.makedirs(out_dir, exist_ok=True)

# sheet swatches: rock base purple-grey, highlight lavender, shadow deep blue-grey
ROCK_BASE, ROCK_HI, ROCK_SH = srgb("#6a6080"), srgb("#a898c0"), srgb("#3c3a58")
FOLIAGE_D, FOLIAGE_H = srgb("#284838"), srgb("#5a8a62")   # v3: lighter (capture c1v26: crowns too dark, cell L29 vs 40)

def tree(M, p, s, seed):
    r2 = random.Random(seed)
    btube(M["bark"], [p, p + Vector((0, 0, s * 0.5)), p + Vector((r2.uniform(-0.1, 0.1) * s, r2.uniform(-0.1, 0.1) * s, s * 0.9))], [s * 0.07, s * 0.05, s * 0.035], 5,
          col=lambda q: srgb("#3a2e28"))
    for j in range(4):
        q = p + Vector((r2.uniform(-0.32, 0.32) * s, r2.uniform(-0.32, 0.32) * s, s * r2.uniform(0.75, 1.15)))
        rr = s * r2.uniform(0.3, 0.45)
        bblob(M["leaf"], rr, tuple(q), squash=(1, 1, 0.75), sub=1, seed=r2.randint(0, 9999), jitter=0.2,
              col=lambda co, q=q, rr=rr: mix(FOLIAGE_D, FOLIAGE_H, 0.4 + 0.7 * (co.z - q.z) / rr))

def column(M, c, R, H, seed, undercut=0.0, lean=(0.0, 0.0), lobes=9, flare=0.12, overhang=0.06):
    """A rounded fissured rock column from z -0.1H to H with a domed mossy top; returns (top centre, top radius)."""
    r2 = random.Random(seed)
    NA, NH = 40, 16
    ph = r2.uniform(0, 6.28)
    vs, fs, cols = [], [], []
    def rad(a, t):
        prof = 1.0 + flare * (1.0 - min(1.0, t / 0.12)) ** 2
        if undercut > 0.0: prof -= undercut * math.exp(-((t - 0.1) / 0.08) ** 2)
        prof += overhang * smoothstep(0.82, 1.0, t)
        # v2 (capture c1v23: smooth cylinders): deep sharp fissures, bulging lobes, waviness up the height
        fiss = 0.2 * (1.0 - abs(math.sin(a * lobes * 0.5 + ph + 0.8 * noise.noise(Vector((a, t * 3.0, seed)))))) ** 3.0
        bul = 0.12 * noise.noise(Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, t * 5.0 + seed))) + 0.1 * noise.noise(Vector((seed * 0.3, t * 2.2, 1.0)))
        return R * (prof - fiss + bul)
    for i in range(NH + 1):
        t = i / NH
        z = -0.1 * H + 1.1 * H * t
        off = Vector((lean[0] * H * t * t, lean[1] * H * t * t, 0.0))
        for j in range(NA):
            a = 2 * math.pi * j / NA
            r = rad(a, t)
            p = Vector((c.x + math.cos(a) * r, c.y + math.sin(a) * r, z)) + off
            vs.append(p)
            fiss = 1.0 - (1.0 - abs(math.sin(a * lobes * 0.5 + ph + 0.8 * noise.noise(Vector((a, t * 3.0, seed)))))) ** 3.0
            n = noise.noise(Vector((p.x * 0.04, p.y * 0.04, p.z * 0.02)))
            col = mix(ROCK_BASE, ROCK_HI, 0.3 + 0.35 * t + 0.35 * n)
            col = mix(col, ROCK_SH, 0.55 * (1.0 - fiss) + 0.25 * (1.0 - t))
            cols.append(col)
    for i in range(NH):
        for j in range(NA):
            j2 = (j + 1) % NA
            fs.append((i * NA + j, i * NA + j2, (i + 1) * NA + j2, (i + 1) * NA + j))
    add_mesh(M["rock"], vs, fs, cols)
    top = Vector((c.x + lean[0] * H, c.y + lean[1] * H, H))
    # mossy dome top with a hanging lip
    cv, cf = [], []
    NR = 4
    for k in range(NR + 1):
        u = k / NR
        for j in range(NA):
            a = 2 * math.pi * j / NA
            r = rad(a, 1.0) * (1.015 - 0.015 * u) * (1.0 - u * u * 0.97)
            z = H + R * 0.26 * math.sin(u * math.pi * 0.5) - (R * 0.03 if k == 0 else 0.0) + R * 0.05 * noise.noise(Vector((a * 2.0, u * 2.0, seed)))
            cv.append(Vector((top.x + math.cos(a) * r, top.y + math.sin(a) * r, z)))
    for k in range(NR):
        for j in range(NA):
            j2 = (j + 1) % NA
            cf.append((k * NA + j, k * NA + j2, (k + 1) * NA + j2, (k + 1) * NA + j))
    add_mesh(M["moss"], cv, cf, [MOSS_COL(p) for p in cv])
    # moss drapes over the lip
    for k in range(int(R * 0.8) + 4):
        a = r2.uniform(0, 2 * math.pi)
        r = rad(a, 1.0) * 1.02
        ln = r2.uniform(0.04, 0.16) * H
        p = Vector((top.x + math.cos(a) * r, top.y + math.sin(a) * r, H - ln / 2))
        bblob(M["moss"], R * 0.07, tuple(p), squash=(1.0, 1.0, ln / (R * 0.14)), sub=1, seed=r2.randint(0, 9999), col=MOSS_COL, jitter=0.3)
    return top, R

def smoothstep(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a))); return t * t * (3 - 2 * t)

def dress_top(M, top, R, seed, trees=1.0, hut=False, glow=True):
    r2 = random.Random(seed)
    zt = top.z + R * 0.1
    # v3 (capture c1v25: still flat plates with small stick trees): a rounded canopy mound over each top, then big
    # round-crowned trees packed over it, as the sheet's tree clumps
    for k in range(5):
        a = r2.uniform(0, 2 * math.pi); u = r2.uniform(0.0, 0.45)
        q = Vector((top.x + math.cos(a) * u * R, top.y + math.sin(a) * u * R, zt + R * 0.12))
        rr = R * r2.uniform(0.45, 0.62)
        bblob(M["leaf"], rr, tuple(q), squash=(1.0, 1.0, 0.55), sub=2, seed=r2.randint(0, 9999), jitter=0.22,
              col=lambda co, q=q, rr=rr: mix(FOLIAGE_D, FOLIAGE_H, 0.35 + 0.8 * (co.z - q.z) / (rr * 0.55)))
    for k in range(max(3, int(R * 0.3 * trees))):
        a = r2.uniform(0, 2 * math.pi); u = math.sqrt(r2.uniform(0.15, 1.0)) * 0.95
        p = Vector((top.x + math.cos(a) * u * R, top.y + math.sin(a) * u * R, zt + R * 0.2 * (1.0 - u * u) - R * 0.05))
        tree(M, p, R * r2.uniform(0.55, 0.85), r2.randint(0, 9999))
    if glow:
        for k in range(max(1, int(R * 0.1))):
            a = r2.uniform(0, 2 * math.pi); u = math.sqrt(r2.uniform(0.0, 1.0)) * 0.9
            p = Vector((top.x + math.cos(a) * u * R, top.y + math.sin(a) * u * R, zt + R * 0.1 * (1.0 - u * u) + 0.8))
            bblob(M["glowflora"] if r2.random() < 0.8 else M["lamp"], R * r2.uniform(0.025, 0.045), tuple(p), squash=(1, 1, 0.7), sub=1, seed=r2.randint(0, 9999))
    if hut:
        a = r2.uniform(0, 2 * math.pi)
        spire(M, Vector((top.x + math.cos(a) * R * 0.3, top.y + math.sin(a) * R * 0.3, zt)), max(10.0, R * 0.6), r2.randint(0, 9999), r2.uniform(0, 6.28))

def waterfall(M, top, a, R, length, width, seed):
    """From a notch at the top lip (angle a), down `length` m, hugging outward, widening and fraying into spray."""
    r2 = random.Random(seed)
    out = Vector((math.cos(a), math.sin(a), 0.0)); side = Vector((-out.y, out.x, 0.0))
    n = 24
    fv, ff = [], []
    for i in range(n + 1):
        t = i / n
        p = top + out * (R * 1.0 + 2.0 + 0.08 * length * t * t) + Vector((0, 0, -length * t + R * 0.02))
        w = width * (0.5 + 1.3 * t ** 1.4)
        wob = side * math.sin(t * 6.0 + seed) * width * 0.12
        fv.append(p - side * w / 2 + wob); fv.append(p + side * w / 2 + wob)
    for i in range(n):
        ff.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    add_mesh(M["falls"], fv, ff, [(1, 1, 1)] * len(fv))
    foot = top + out * (R + 2.0 + 0.08 * length) + Vector((0, 0, -length))
    for k in range(6):
        bblob(M["spray"], width * r2.uniform(0.7, 1.3), (foot.x + r2.uniform(-width, width), foot.y + r2.uniform(-width, width), foot.z + r2.uniform(-3, 6)), squash=(1.4, 1.4, 0.7), sub=2, seed=r2.randint(0, 9999), jitter=0.25)

def new_scene():
    L.reset(); M = mats()
    M["spray"] = L.mat("valley_spray", "#e8f0ff", 0.5, "#c8e0ff", 0.6)
    M["glowflora"] = L.mat("valley_glowflora", "#b48aff", 0.5, "#9a6aff", 1.6)
    M["falls"] = L.mat("valley_falls", "#d8ecff", 0.3, "#a8d8ff", 1.3)   # sheet: waterfall cyan-white
    M["pool"] = L.mat("valley_pool", "#5a9ad8", 0.2, "#4a8ad0", 0.6)
    return M

def landform(name, cols, falls, huts=(), pools=()):
    """cols: [(x, y, R, H, undercut, (lean x, y), seed)]; falls: [(column index, angle, length frac, width)]."""
    M = new_scene()
    tops = []
    for k, (x, y, R, H, uc, lean, sd) in enumerate(cols):
        top, r = column(M, Vector((x, y, 0)), R, H, sd, undercut=uc, lean=lean)
        tops.append((top, r))
        dress_top(M, top, r, sd + 1, hut=(k in huts))
    for (ci, a, frac, w) in falls:
        top, r = tops[ci]
        waterfall(M, top, a, r, top.z * frac, w * 0.65, ci * 13 + int(a * 10))
    for (ci, pr) in pools:
        top, r = tops[ci]
        vs = [Vector((top.x, top.y, top.z + r * 0.12))] + [Vector((top.x + math.cos(2 * math.pi * j / 20) * r * pr, top.y + math.sin(2 * math.pi * j / 20) * r * pr, top.z + r * 0.11)) for j in range(20)]
        add_mesh(M["pool"], vs, [(0, j + 1, (j + 1) % 20 + 1) for j in range(20)], [(1, 1, 1)] * len(vs))
    flush(name)

F = -math.pi / 2   # front (-Y)
# A tower: a main 350 m column with stepped shoulders and an undercut foot
landform("tower", [(0, 0, 34, 350, 0.0, (0.0, 0.0), 1), (-26, -14, 24, 250, 0.25, (0.0, 0.0), 2), (24, -18, 22, 190, 0.0, (0.0, 0.0), 3),
                   (-8, 22, 26, 300, 0.0, (0.0, 0.0), 4), (30, 14, 18, 140, 0.3, (0.0, 0.0), 5), (-34, 12, 16, 110, 0.0, (0.0, 0.0), 6)],
         falls=[(0, F + 0.15, 0.85, 9.0), (2, F - 0.2, 0.7, 5.0)], huts=(0,))
# B massif: two crowns at 220 and 175 m joined by a saddle at 120-140 m, arch undercuts at the foot, three falls
landform("massif", [(-90, 0, 46, 220, 0.3, (0.0, 0.0), 11), (-120, -30, 30, 170, 0.0, (0.0, 0.0), 12), (-55, 30, 34, 200, 0.0, (0.0, 0.0), 13),
                    (-10, -10, 34, 130, 0.45, (0.0, 0.0), 14), (25, 15, 30, 140, 0.0, (0.0, 0.0), 15),
                    (80, 0, 44, 175, 0.35, (0.0, 0.0), 16), (115, -25, 28, 120, 0.0, (0.0, 0.0), 17), (60, 32, 30, 160, 0.0, (0.0, 0.0), 18), (130, 25, 24, 95, 0.3, (0.0, 0.0), 19)],
         falls=[(0, F + 0.3, 0.9, 16.0), (3, F, 0.85, 22.0), (5, F - 0.25, 0.9, 12.0)], huts=(0, 5))
# C needle: a leaning 250 m spire with stepped shoulders
landform("needle", [(0, 0, 17, 250, 0.0, (0.08, 0.0), 21), (-12, -10, 13, 170, 0.0, (0.05, 0.0), 22), (14, -6, 11, 120, 0.25, (0.03, 0.0), 23), (40, -4, 8, 75, 0.0, (0.0, 0.0), 24)],
         falls=[(0, F + 0.4, 0.55, 4.0)], huts=(0,))
# D low island: a broken ring of low columns, pools on two, waterfalls from them
landform("lowisle", [(-70, 0, 34, 100, 0.4, (0, 0), 31), (-25, -12, 30, 92, 0.3, (0, 0), 32), (20, 6, 34, 96, 0.45, (0, 0), 33), (66, -6, 30, 86, 0.3, (0, 0), 34),
                     (-45, 30, 26, 80, 0.0, (0, 0), 35), (45, 32, 26, 84, 0.0, (0, 0), 36)],
         falls=[(1, F, 0.9, 12.0), (2, F + 0.3, 0.9, 8.0)], huts=(2,), pools=((1, 0.5), (2, 0.55)))

def rise_bridge(name):
    """A long arch bridge from a low ledge (left, deck 72 m) to one 48 m higher (right), S-curved in plan."""
    M = new_scene(); r2 = random.Random(61)
    X0, X1, Z0, Z1, W = -200.0, 200.0, 72.0, 120.0, 8.0
    plan_y = lambda x: 22.0 * math.sin(math.pi * (x - X0) / (X1 - X0) * 2.0) * 0.6
    deck_z = lambda x: Z0 + (Z1 - Z0) * smoothstep(X0, X1, x) + 10.0 * math.sin(math.pi * (x - X0) / (X1 - X0))
    stone_col = lambda p: mix(srgb("#625a78"), srgb("#a294b4"), 0.35 + 0.4 * (p.z / Z1) + 0.2 * noise.noise(Vector((p.x * 0.08, p.y * 0.08, p.z * 0.05))))
    # end ledges: rock columns with mossy tops
    for (x, H, sd) in ((X0 - 10.0, Z0, 71), (X1 + 10.0, Z1, 72)):
        top, r = column(M, Vector((x, plan_y(x), 0)), 26, H, sd, undercut=0.25)
        dress_top(M, top, r, sd + 5, hut=(x > 0))
    # one mid pier, tapered
    xm = 30.0
    zt = deck_z(xm)
    prof = [(14.0, -10.0), (10.0, 0.0), (7.0, zt * 0.3), (4.6, zt * 0.75), (5.2, zt - 4.0), (6.0, zt)]
    vs, fs = [], []
    for j in range(10):
        th = 2 * math.pi * j / 10
        for (rr, z) in prof:
            vs.append(Vector((xm + rr * math.cos(th), plan_y(xm) + rr * 0.7 * math.sin(th), z)))
    m = len(prof)
    for j in range(10):
        j2 = (j + 1) % 10
        for k in range(m - 1):
            fs.append((j * m + k, j2 * m + k, j2 * m + k + 1, j * m + k + 1))
    add_mesh(M["stone"], vs, fs, [stone_col(p) for p in vs])
    # two arches: left ledge -> pier, pier -> right ledge; soffit follows a round curve under the deck
    for (a0, a1) in ((X0 + 12.0, xm - 5.0), (xm + 5.0, X1 - 12.0)):
        n = 30
        av, af = [], []
        span = a1 - a0
        for k in range(n + 1):
            t = k / n; x = a0 + span * t
            z_soffit = min(deck_z(a0), deck_z(a1)) - 8.0 - (1.0 - math.sin(math.pi * t)) * span * 0.32
            z_top = deck_z(x) - 1.0
            for yy in (-W / 2, W / 2):
                av.append(Vector((x, plan_y(x) + yy, z_soffit))); av.append(Vector((x, plan_y(x) + yy, z_top)))
        for k in range(n):
            q0 = k * 4; q1 = (k + 1) * 4
            af.append((q0, q1, q1 + 1, q0 + 1)); af.append((q0 + 3, q1 + 3, q1 + 2, q0 + 2)); af.append((q0 + 2, q1 + 2, q1, q0))
        add_mesh(M["stone"], av, af, [stone_col(p) for p in av], smooth=False)
        for k in range(int(span / 9)):
            t = r2.uniform(0.08, 0.92); x = a0 + span * t
            z_soffit = min(deck_z(a0), deck_z(a1)) - 8.0 - (1.0 - math.sin(math.pi * t)) * span * 0.32
            ln = r2.uniform(5, 18)
            bblob(M["moss"], 1.3, (x, plan_y(x) + r2.choice((-W / 2 - 0.4, W / 2 + 0.4)), z_soffit - ln / 2), squash=(1, 0.6, ln / 2.6), sub=1, seed=r2.randint(0, 9999), col=MOSS_COL, jitter=0.3)
    # deck, parapet rails, lanterns
    N = 80
    dv, df = [], []
    for k in range(N + 1):
        x = X0 - 6.0 + (X1 - X0 + 12.0) * k / N; z = deck_z(x); y = plan_y(x)
        for yy, dz in ((-W / 2 - 0.5, 0.0), (W / 2 + 0.5, 0.0), (W / 2 + 0.5, -2.2), (-W / 2 - 0.5, -2.2)):
            dv.append(Vector((x, y + yy, z + dz)))
    for k in range(N):
        for e in range(4):
            e2 = (e + 1) % 4
            df.append((k * 4 + e, (k + 1) * 4 + e, (k + 1) * 4 + e2, k * 4 + e2))
    add_mesh(M["stone"], dv, df, [stone_col(p) for p in dv], smooth=False)
    for yy in (-W / 2, W / 2):
        pts = [Vector((X0 - 6.0 + (X1 - X0 + 12.0) * k / N, 0, 0)) for k in range(N + 1)]
        btube(M["stone"], [Vector((p.x, plan_y(p.x) + yy, deck_z(p.x) + 1.2)) for p in pts], [0.4] * (N + 1), 4, col=stone_col)
        x = X0
        while x <= X1:
            z = deck_z(x); y = plan_y(x) + yy
            btube(M["bark"], [Vector((x, y, z)), Vector((x, y, z + 2.8))], [0.2, 0.16], 5, col=lambda p: srgb("#3a2a20"))
            bblob(M["lamp"], 0.55, (x, y, z + 3.0), squash=(0.9, 0.9, 1.3), sub=1, jitter=0.0)
            x += r2.uniform(10.0, 15.0)
    flush(name)

rise_bridge("risebridge")

L.reset()
names = ("tower", "massif", "needle", "lowisle", "risebridge")
for i, name in enumerate(names):
    bpy.ops.import_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"))
    for ob in bpy.context.selected_objects:
        ob.location.x += (-560, -200, 120, 330, 720)[i]
files = L.sheet_render(out_png, 1600.0, center=(80, 0, 170), views=[("front", (0, -900, 0), (90, 0, 0))])
print("RENDERS", files)
