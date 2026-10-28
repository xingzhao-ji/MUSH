"""Concept-1 valley kit from the ChatGPT sheet mush-c1-sheet-valley-01 (drawn from design-reference/mush-concept-1.png,
centre and right): (A) a tall cliff pillar island of faceted grey-violet basalt columns with mossy ledges, a flat
grassy top with dark round trees and a mushroom spire hut, two thin waterfalls; (B) a wide low island; (C) an arched
stone viaduct with slender piers, round arches, a parapet and warm lanterns; (D) a mushroom spire hut.
One glb per piece in <out_dir>: pillar.glb (100 m tall, ~44 m wide), island.glb (60 m tall, ~200 x 80 m),
bridge.glb (5 spans, 300 m long, deck at 90 m), spire.glb (24 m). Origin at the base centre, Z up, front -Y.
Materials hero_valley_* carry vertex colours (Godot _blender_mat reads COLOR_0 for hero_* names).
Usage: blender -b -P valley.py -- <out_dir> <render_prefix.png>"""
import bpy, bmesh, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector, noise

if "--" in sys.argv:
    out_dir, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
    os.makedirs(out_dir, exist_ok=True)

def srgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
def mix(a, b, t):
    t = max(0.0, min(1.0, t)); return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

_vm = {}
def vmat(name, rough=0.85, emit=None, strength=0.0):
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

_ico = {}
def ico_template(sub):
    if sub not in _ico:
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
        _ico[sub] = ([v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces]); bm.free()
    return _ico[sub]

BATCH = {}
def _batch(mat_):
    return BATCH.setdefault(mat_.name, [mat_, [], [], [], True])

def add_mesh(mat_, verts, faces, cols, smooth=True):
    b = _batch(mat_); base = len(b[1])
    b[1].extend(verts); b[3].extend(cols); b[2].extend(tuple(base + i for i in f) for f in faces)
    if not smooth: b[4] = False

def bblob(mat_, r, loc, squash=(1, 1, 1), sub=1, seed=0, jitter=0.18, col=None):
    verts, faces = ico_template(sub)
    r2 = random.Random(seed); vs = []
    for v in verts:
        k = 1.0 + r2.uniform(-jitter, jitter)
        vs.append(Vector((loc[0] + v.x * r * squash[0] * k, loc[1] + v.y * r * squash[1] * k, loc[2] + v.z * r * squash[2] * k)))
    add_mesh(mat_, vs, faces, [col(p) if col else (1.0, 1.0, 1.0) for p in vs])

def btube(mat_, pts, radii, sides=6, col=None):
    vs, fs = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized(); b = t.cross(a)
        for k in range(sides):
            th = 2 * math.pi * k / sides
            vs.append(p + (a * math.cos(th) + b * math.sin(th)) * radii[i])
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            fs.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
    add_mesh(mat_, vs, fs, [col(p) if col else (1.0, 1.0, 1.0) for p in vs])

def flush(name):
    obs = []
    for mname, (mat_, v, f, c, smooth) in BATCH.items():
        if not v: continue
        ob = L.obj_from(mname, v, f, mat_, smooth=smooth)
        if mname.startswith("hero_"):
            attr = ob.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="POINT")
            for i, cc in enumerate(c): attr.data[i].color_srgb = (cc[0], cc[1], cc[2], 1.0)
            ob.data.color_attributes.active_color = attr
        obs.append(ob)
    BATCH.clear()
    tris = sum(len(p.vertices) - 2 for ob in obs for p in ob.data.polygons)
    path = os.path.join(out_dir, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True, export_vertex_color="ACTIVE")
    print("EXPORTED", path, os.path.getsize(path), "TRIS", tris)

def mats():
    _vm.clear()   # L.reset() removed the cached materials
    return {
        "rock": vmat("hero_valley_rock", 0.92),
        "moss": vmat("hero_valley_moss", 0.95),
        "leaf": vmat("hero_valley_leaf", 0.85),
        "bark": vmat("hero_valley_bark", 0.9),
        "stone": vmat("hero_valley_stone", 0.9),
        "falls": L.mat("valley_falls", "#d8e0ff", 0.3, "#a8c0ff", 1.1),
        "hut_glow": L.mat("valley_hut_glow", "#ffc070", 0.5, "#ffa040", 4.0),
        "cap": vmat("hero_valley_spire_cap", 0.6, "#7a50d8", 0.5),
        "under": L.mat("valley_spire_under", "#ffb860", 0.6, "#ff9840", 2.2),
        "lamp": L.mat("valley_lantern_glow", "#ffd080", 0.4, "#ffa840", 6.0),
        "tower": vmat("hero_valley_tower", 0.85),
    }

# v2 (capture c1v07: grey-violet vertex colours under the lavender fill read saturated indigo): warm greys, which
# the dusk fill turns grey-lavender as in the concept.
ROCK_LO, ROCK_HI, ROCK_DARK = srgb("#746c7c"), srgb("#b2a8bc"), srgb("#4e4858")   # v3: lavender-grey (cells b -12..-20)
def rock_col(p, h):
    n = noise.noise(Vector((p.x * 0.05, p.y * 0.05, p.z * 0.012)))
    streak = 0.5 + 0.5 * math.sin(p.x * 0.7 + p.y * 0.55 + 3.0 * n)
    c = mix(ROCK_LO, ROCK_HI, 0.35 + 0.35 * (p.z / h) + 0.25 * n)
    return mix(c, ROCK_DARK, 0.25 * streak)
MOSS_COL = lambda p: mix(srgb("#2e4628"), srgb("#5a7a40"), 0.5 + 0.6 * noise.noise(Vector((p.x * 0.2, p.y * 0.2, p.z * 0.2))))

def basalt_mass(M, cx, cy, rx, ry, h, seed, n_cols=30, top_jitter=0.16):
    """Clustered faceted columns (irregular 5-7 sided prisms) inside an ellipse, stepped tops; returns column tops."""
    r2 = random.Random(seed)
    tops = []
    for k in range(n_cols):
        a = r2.uniform(0, 2 * math.pi); rr = math.sqrt(r2.uniform(0.0, 1.0))
        x = cx + math.cos(a) * rr * rx * 0.82; y = cy + math.sin(a) * rr * ry * 0.82
        edge = rr
        cr = r2.uniform(0.16, 0.26) * min(rx, ry) * (1.15 - 0.3 * edge)
        top = h * (1.0 - r2.uniform(0.0, top_jitter) * (0.3 + edge)) - (h * 0.12 if edge > 0.85 and r2.random() < 0.5 else 0.0)
        bot = -h * 0.08 - r2.uniform(0, 6)
        sides = r2.choice((5, 6, 6, 7))
        ph = r2.uniform(0, 6.28)
        ring_b, ring_t = [], []
        for s in range(sides):
            th = ph + 2 * math.pi * s / sides + r2.uniform(-0.2, 0.2)
            rk = cr * r2.uniform(0.85, 1.1)
            flare = 1.0 + 0.22 * (1.0 - 0.0)
            ring_b.append(Vector((x + math.cos(th) * rk * flare, y + math.sin(th) * rk * flare, bot)))
            ring_t.append(Vector((x + math.cos(th) * rk, y + math.sin(th) * rk, top)))
        # a mid ring so the column bulges and leans a little
        lean = Vector((r2.uniform(-1, 1), r2.uniform(-1, 1), 0)) * cr * 0.15
        ring_m = [p.lerp(q, 0.55) + lean + (p - Vector((x, y, p.z))) * 0.06 for p, q in zip(ring_b, ring_t)]
        vs = ring_b + ring_m + ring_t + [Vector((x, y, top + cr * 0.08))]
        fs = []
        for s in range(sides):
            s2 = (s + 1) % sides
            fs.append((s, s2, sides + s2, sides + s))
            fs.append((sides + s, sides + s2, 2 * sides + s2, 2 * sides + s))
            fs.append((2 * sides + s, 2 * sides + s2, 3 * sides))
        add_mesh(M["rock"], vs, fs, [rock_col(p, h) for p in vs], smooth=False)
        tops.append((Vector((x, y, top)), cr, edge))
    return tops

def moss_cap(M, tops, seed):
    r2 = random.Random(seed)
    for (p, cr, edge) in tops:
        for j in range(3):
            q = p + Vector((r2.uniform(-0.5, 0.5) * cr, r2.uniform(-0.5, 0.5) * cr, cr * 0.1))
            bblob(M["moss"], cr * r2.uniform(0.55, 0.8), tuple(q), squash=(1.0, 1.0, 0.32), sub=1, seed=r2.randint(0, 9999), col=MOSS_COL)
        # drapes down the outer columns
        if edge > 0.6 and r2.random() < 0.7:
            ln = r2.uniform(0.06, 0.2) * p.z
            ang = math.atan2(p.y, p.x)
            q = p + Vector((math.cos(ang) * cr * 0.9, math.sin(ang) * cr * 0.9, -ln / 2))
            bblob(M["moss"], cr * 0.35, tuple(q), squash=(1.0, 1.0, ln / (cr * 0.7)), sub=1, seed=r2.randint(0, 9999), col=MOSS_COL, jitter=0.3)

def tree(M, p, s, seed):
    r2 = random.Random(seed)
    btube(M["bark"], [p, p + Vector((0, 0, s * 0.5)), p + Vector((r2.uniform(-0.1, 0.1) * s, r2.uniform(-0.1, 0.1) * s, s * 0.9))], [s * 0.07, s * 0.05, s * 0.035], 6,
          col=lambda q: srgb("#3a2e28"))
    for j in range(5):
        q = p + Vector((r2.uniform(-0.3, 0.3) * s, r2.uniform(-0.3, 0.3) * s, s * r2.uniform(0.75, 1.15)))
        rr = s * r2.uniform(0.28, 0.42)
        bblob(M["leaf"], rr, tuple(q), squash=(1, 1, 0.8), sub=2, seed=r2.randint(0, 9999), jitter=0.2,
              col=lambda co, q=q, rr=rr: mix(srgb("#16281e"), srgb("#3e5e36"), 0.45 + 0.7 * (co.z - q.z) / rr))

def spire(M, p, h, seed, rot=0.0):
    """Mushroom spire hut: a tapering tower with glowing windows, a balcony, a conical violet cap over a glowing gill rim."""
    r2 = random.Random(seed)
    r0 = h * 0.11
    prof = [(r0 * 1.25, 0.0), (r0 * 1.0, h * 0.08), (r0 * 0.82, h * 0.35), (r0 * 0.7, h * 0.6), (r0 * 0.8, h * 0.66)]
    segs = 12
    vs, fs = [], []
    for j in range(segs):
        th = 2 * math.pi * j / segs + rot
        for (rr, z) in prof:
            vs.append(Vector((p.x + rr * math.cos(th), p.y + rr * math.sin(th), p.z + z)))
    m = len(prof)
    for j in range(segs):
        j2 = (j + 1) % segs
        for i in range(m - 1):
            fs.append((j * m + i, j2 * m + i, j2 * m + i + 1, j * m + i + 1))
    add_mesh(M["tower"], vs, fs, [mix(srgb("#8a7a90"), srgb("#b8a8b8"), (q.z - p.z) / h) for q in vs])
    # windows: glowing arched slots
    for k in range(4):
        th = rot + k * 1.7 + 0.3; z = h * (0.12 + 0.13 * k)
        rr = r0 * (1.0 - 0.6 * (z / h)) * 0.98 + 0.05
        c = Vector((p.x + rr * math.cos(th), p.y + rr * math.sin(th), p.z + z))
        bblob(M["hut_glow"], h * 0.035, tuple(c), squash=(0.6, 0.6, 1.5), sub=1, jitter=0.0)
    # balcony ring
    bz = p.z + h * 0.42
    btube(M["bark"], [Vector((p.x + r0 * 1.15 * math.cos(2 * math.pi * k / 12), p.y + r0 * 1.15 * math.sin(2 * math.pi * k / 12), bz)) for k in range(13)], [h * 0.012] * 13, 4,
          col=lambda q: srgb("#4a3626"))
    # cap
    cap_r = h * 0.38; cz = p.z + h * 0.64
    capprof = [(cap_r, cz), (cap_r * 0.92, cz + h * 0.05), (cap_r * 0.6, cz + h * 0.12), (cap_r * 0.25, cz + h * 0.24), (cap_r * 0.06, cz + h * 0.34), (0.0, cz + h * 0.36)]
    vs, fs = [], []
    segs = 16
    for j in range(segs):
        th = 2 * math.pi * j / segs
        for (rr, z) in capprof:
            vs.append(Vector((p.x + rr * math.cos(th), p.y + rr * math.sin(th), z)))
    m = len(capprof)
    for j in range(segs):
        j2 = (j + 1) % segs
        for i in range(m - 1):
            fs.append((j * m + i, j2 * m + i, j2 * m + i + 1, j * m + i + 1))
    add_mesh(M["cap"], vs, fs, [mix(srgb("#5a3cb0"), srgb("#9a7ae8"), 0.4 + 0.6 * ((q.z - cz) / (h * 0.36))) for q in vs])
    # glowing underside disc
    vs = [Vector((p.x, p.y, cz - h * 0.01))] + [Vector((p.x + cap_r * 0.98 * math.cos(2 * math.pi * j / segs), p.y + cap_r * 0.98 * math.sin(2 * math.pi * j / segs), cz)) for j in range(segs)]
    add_mesh(M["under"], vs, [(0, j % segs + 1, j + 1 if False else (j + 1) % segs + 1) for j in range(segs)], [(1, 1, 1)] * len(vs))

def waterfall(M, top, out_dir_xy, height, width, seed):
    """A thin ribbon falling from `top`, wandering a little, widening and fraying into spray toward the foot."""
    r2 = random.Random(seed)
    n = 24
    vs, fs = [], []
    side = Vector((-out_dir_xy.y, out_dir_xy.x, 0.0))
    for i in range(n + 1):
        t = i / n
        c = top + out_dir_xy * (2.0 + 4.0 * t * t) + Vector((0, 0, -height * t)) + side * (math.sin(t * 5 + seed) * width * 0.3)
        w = width * (0.5 + 1.4 * t * t)
        vs.append(c - side * w / 2); vs.append(c + side * w / 2)
    for i in range(n):
        fs.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    add_mesh(M["falls"], vs, fs, [(1, 1, 1)] * len(vs))

def island_piece(name, rx, ry, h, n_cols, n_trees, n_spires, n_falls, seed):
    L.reset(); M = mats(); r2 = random.Random(seed)
    tops = basalt_mass(M, 0.0, 0.0, rx, ry, h, seed, n_cols=n_cols)
    moss_cap(M, tops, seed + 1)
    # grassy top: an irregular dome over the highest columns
    vs, fs = [], []
    NA, NR = 36, 5
    for i in range(NR + 1):
        rr = i / NR
        for j in range(NA):
            a = 2 * math.pi * j / NA
            w = 0.78 + 0.08 * noise.noise(Vector((math.cos(a) * 2, math.sin(a) * 2, seed)))
            vs.append(Vector((math.cos(a) * rr * rx * w, math.sin(a) * rr * ry * w, h * (0.985 - 0.04 * rr * rr) + 1.0 * noise.noise(Vector((a, rr, seed))))))
    for i in range(NR):
        for j in range(NA):
            j2 = (j + 1) % NA
            fs.append((i * NA + j, i * NA + j2, (i + 1) * NA + j2, (i + 1) * NA + j))
    add_mesh(M["moss"], vs, fs, [MOSS_COL(p) for p in vs])
    # moss ledges on the flanks
    for k in range(int(n_cols * 1.2)):
        a = r2.uniform(0, 2 * math.pi); z = h * r2.uniform(0.25, 0.85)
        q = Vector((math.cos(a) * rx * 0.86, math.sin(a) * ry * 0.86, z))
        s = min(rx, ry) * r2.uniform(0.1, 0.18)
        bblob(M["moss"], s, tuple(q), squash=(1.2, 1.2, 0.45), sub=1, seed=r2.randint(0, 9999), col=MOSS_COL)
        if r2.random() < 0.5: tree(M, q + Vector((0, 0, s * 0.3)), s * 1.6, r2.randint(0, 9999))
    for k in range(n_trees):
        a = r2.uniform(0, 2 * math.pi); rr = math.sqrt(r2.uniform(0.05, 1.0)) * 0.72
        tree(M, Vector((math.cos(a) * rr * rx, math.sin(a) * rr * ry, h * 0.98)), min(rx, ry) * r2.uniform(0.28, 0.42), r2.randint(0, 9999))
    for k in range(n_spires):
        a = r2.uniform(0, 2 * math.pi); rr = r2.uniform(0.0, 0.45)
        spire(M, Vector((math.cos(a) * rr * rx, math.sin(a) * rr * ry, h * 0.97)), min(rx, ry) * r2.uniform(0.7, 1.0), r2.randint(0, 9999), r2.uniform(0, 6.28))
    for k in range(n_falls):
        a = -math.pi / 2 + r2.uniform(-0.9, 0.9)    # on the front (-Y) side
        d = Vector((math.cos(a), math.sin(a), 0.0))
        top = Vector((d.x * rx * 0.86, d.y * ry * 0.86, h * r2.uniform(0.86, 0.95)))
        waterfall(M, top, d, h * r2.uniform(0.55, 0.85), min(rx, ry) * r2.uniform(0.07, 0.12), r2.randint(0, 9999))
    flush(name)

def spire_piece():
    L.reset(); M = mats()
    # a mossy footing rock
    tops = basalt_mass(M, 0.0, 0.0, 4.0, 4.0, 3.0, 77, n_cols=6, top_jitter=0.3)
    moss_cap(M, tops, 78)
    spire(M, Vector((0, 0, 2.6)), 24.0, 79)
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        tree(M, Vector((math.cos(a) * 4.0, math.sin(a) * 4.0, 2.8)), 4.0, 80 + k)
    flush("spire")

def bridge_piece():
    """Five round arches on slender piers; deck at DECK, parapet with lantern posts."""
    L.reset(); M = mats(); r2 = random.Random(91)
    SPANS, SPAN, DECK, W = 5, 60.0, 90.0, 9.0
    xs = [-SPANS * SPAN / 2 + SPAN * i for i in range(SPANS + 1)]
    stone_col = lambda p: mix(srgb("#746c68"), srgb("#aaa09a"), 0.4 + 0.4 * (p.z / DECK) + 0.2 * noise.noise(Vector((p.x * 0.08, p.y * 0.08, p.z * 0.05))))
    for i, x in enumerate(xs):
        # pier: tapering, flaring into a rocky foot
        pw = 7.0 if 0 < i < SPANS else 9.0
        vs, fs = [], []
        prof = [(pw * 1.9, -12.0), (pw * 1.5, 0.0), (pw * 1.0, 14.0), (pw * 0.72, 40.0), (pw * 0.62, DECK - 20.0), (pw * 0.75, DECK - 6.0), (pw * 0.8, DECK)]
        sides = 8
        for j in range(sides):
            th = 2 * math.pi * j / sides + 0.39
            for (rr, z) in prof:
                vs.append(Vector((x + rr * math.cos(th), rr * 0.75 * math.sin(th), z)))
        m = len(prof)
        for j in range(sides):
            j2 = (j + 1) % sides
            for k in range(m - 1):
                fs.append((j * m + k, j2 * m + k, j2 * m + k + 1, j * m + k + 1))
        add_mesh(M["stone"], vs, fs, [stone_col(p) for p in vs], smooth=False)
        # rocky foot and moss
        for k in range(5):
            q = Vector((x + r2.uniform(-1, 1) * pw * 1.3, r2.uniform(-1, 1) * pw, r2.uniform(-6, 6)))
            bblob(M["rock"], pw * r2.uniform(0.6, 1.0), tuple(q), squash=(1, 0.8, 1.3), sub=1, seed=r2.randint(0, 9999), col=lambda p: rock_col(p, DECK))
        bblob(M["moss"], pw * 0.7, (x, 0, DECK - 8), squash=(1.1, 1.2, 0.6), sub=1, seed=i, col=MOSS_COL)
    # arches: a thick ring segment between neighbouring piers, plus spandrel fill up to the deck
    for i in range(SPANS):
        x0, x1 = xs[i] + 4.0, xs[i + 1] - 4.0
        cx = (x0 + x1) / 2; r = (x1 - x0) / 2
        spring = DECK - 12.0 - r
        n = 20
        vs, fs = [], []
        for k in range(n + 1):
            a = math.pi * k / n
            inner = Vector((cx - r * math.cos(a), 0, spring + r * math.sin(a)))
            outer_z = DECK - 1.0
            for yy in (-W / 2, W / 2):
                vs.append(Vector((inner.x, yy, inner.z)))
                vs.append(Vector((inner.x, yy, outer_z)))
        for k in range(n):
            a0 = k * 4; a1 = (k + 1) * 4
            fs.append((a0, a1, a1 + 1, a0 + 1))          # front face (y -W/2)
            fs.append((a0 + 3, a1 + 3, a1 + 2, a0 + 2))  # back face
            fs.append((a0 + 2, a1 + 2, a1, a0))          # soffit
        add_mesh(M["stone"], vs, fs, [stone_col(p) for p in vs], smooth=False)
        # vines hanging from the arch
        for k in range(6):
            a = r2.uniform(0.15, 0.85) * math.pi
            q = Vector((cx - r * math.cos(a), r2.choice((-W / 2, W / 2)), spring + r * math.sin(a)))
            ln = r2.uniform(4, 14)
            bblob(M["moss"], 1.2, (q.x, q.y, q.z - ln / 2), squash=(1, 0.6, ln / 2.4), sub=1, seed=r2.randint(0, 9999), col=MOSS_COL, jitter=0.3)
    # deck and parapet
    x0, x1 = xs[0] - 6.0, xs[-1] + 6.0
    vs = [Vector((x0, -W / 2 - 0.6, DECK)), Vector((x1, -W / 2 - 0.6, DECK)), Vector((x1, W / 2 + 0.6, DECK)), Vector((x0, W / 2 + 0.6, DECK)),
          Vector((x0, -W / 2 - 0.6, DECK - 2.5)), Vector((x1, -W / 2 - 0.6, DECK - 2.5)), Vector((x1, W / 2 + 0.6, DECK - 2.5)), Vector((x0, W / 2 + 0.6, DECK - 2.5))]
    fs = [(0, 1, 2, 3), (4, 5, 1, 0), (6, 7, 3, 2), (5, 6, 2, 1), (7, 4, 0, 3)]
    add_mesh(M["stone"], vs, fs, [stone_col(p) for p in vs], smooth=False)
    for yy in (-W / 2, W / 2):
        btube(M["stone"], [Vector((x0, yy, DECK + 1.3)), Vector((x1, yy, DECK + 1.3))], [0.5, 0.5], 4, col=stone_col)
        x = x0
        while x <= x1:
            btube(M["stone"], [Vector((x, yy, DECK)), Vector((x, yy, DECK + 1.4))], [0.35, 0.35], 4, col=stone_col)
            if abs((x - x0) % 15.0) < 0.01:
                btube(M["bark"], [Vector((x, yy, DECK)), Vector((x, yy, DECK + 3.2))], [0.22, 0.18], 5, col=lambda p: srgb("#3a2a20"))
                bblob(M["lamp"], 0.55, (x, yy, DECK + 3.4), squash=(0.9, 0.9, 1.3), sub=1, jitter=0.0)
            x += 3.0
    # kiosks: small spires at the ends and the middle pier
    for x in (xs[0], xs[SPANS // 2 + 1], xs[-1]):
        spire(M, Vector((x, 0, DECK)), 14.0, int(x) + 500)
    flush("bridge")

if __name__ == "__main__" and os.path.basename(sys.argv[sys.argv.index("-P") + 1]) == "valley.py":
    island_piece("pillar", 22.0, 20.0, 100.0, 34, 7, 1, 2, 11)
    island_piece("island", 100.0, 40.0, 60.0, 70, 22, 3, 3, 23)
    spire_piece()
    bridge_piece()

    # contact render of the kit
    L.reset()
    for i, name in enumerate(("pillar", "island", "bridge", "spire")):
        bpy.ops.import_scene.gltf(filepath=os.path.join(out_dir, name + ".glb"))
        for ob in bpy.context.selected_objects:
            ob.location.x += (-260, -80, 180, 400)[i]
    files = L.sheet_render(out_png, 820.0, center=(60, 0, 60), views=[("front", (0, -900, 0), (90, 0, 0)), ("hero", (-400, -700, 300), None)])
    print("RENDERS", files)
