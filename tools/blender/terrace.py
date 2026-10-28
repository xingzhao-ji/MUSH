"""Concept-1 home terrace (design-reference/mush-concept-1.png, left half; ChatGPT sheet mush-c1-sheet-terrace-01):
a hobbit-style home dug into a mossy turf mound with a big round-arched glowing window and an arched door, a
stone-and-plank patio with sofas, armchairs and a low table under a cream canvas awning, rustic railings and
lantern posts, steps down to a winding flagstone path edged by a wooden fence and flower beds with glowing blue
lilies, a vine-hung stone wall under the patio, a rock skirt below the cliff edge, and a huge ancient tree whose
canopy spreads overhead with hanging lanterns.

Authored in the vista camera's frame: the camera stands at (0, 0, CAM_H) looking along +Y (glTF -Z, Godot's
forward), pitched down PITCH, vertical FOV 60, 16:9. Key points are given in concept-1 pixels (1280 x 720) with a
height and converted by ray-plane intersection (px()), so the set piece lands where the concept draws it.
Usage: blender -b -P terrace.py -- <out.glb> <render_prefix.png>"""
import bpy, bmesh, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector, noise

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(1040)

CAM_H = 7.0
PITCH = math.radians(15.3)
TX = math.tan(math.radians(30.0)) * 16.0 / 9.0
TY = math.tan(math.radians(30.0))
F = Vector((0.0, math.cos(PITCH), -math.sin(PITCH)))
U = Vector((0.0, math.sin(PITCH), math.cos(PITCH)))
R = Vector((1.0, 0.0, 0.0))
CAM = Vector((0.0, 0.0, CAM_H))

def ray(px_, py_):
    sx = (px_ - 640.0) / 640.0; sy = (360.0 - py_) / 360.0
    return (F + R * (sx * TX) + U * (sy * TY)).normalized()

def px(px_, py_, z):
    """World point where the ray through concept pixel (px_, py_) meets height z."""
    d = ray(px_, py_)
    t = (z - CAM.z) / d.z
    return CAM + d * t

def px_depth(px_, py_, depth):
    """World point on the ray through (px_, py_) at forward depth `depth` (along F)."""
    d = ray(px_, py_)
    return CAM + d * (depth / d.dot(F))

def srgb(h):
    h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
def mix(a, b, t):
    t = max(0.0, min(1.0, t)); return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))

_vm = {}
def vmat(name, rough=0.8, emit=None, strength=0.0):
    """Vertex-coloured material (Godot: hero_* names read COLOR_0 as albedo)."""
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
    mw = ob.matrix_world
    for i, v in enumerate(me.vertices):
        c = fn(mw @ v.co, i)
        attr.data[i].color_srgb = (c[0], c[1], c[2], 1.0)
    me.color_attributes.active_color = attr


# ---- batched blobs and tubes: one mesh per material (bpy.ops per petal slowed ~7000 primitives to many minutes) ----
_ico = {}
def ico_template(sub):
    if sub not in _ico:
        bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
        _ico[sub] = ([v.co.copy() for v in bm.verts], [tuple(v.index for v in f.verts) for f in bm.faces]); bm.free()
    return _ico[sub]

BATCH = {}
def _batch(mat_):
    return BATCH.setdefault(mat_.name, (mat_, [], [], []))

def bblob(mat_, r, loc, squash=(1, 1, 1), sub=1, seed=0, jitter=0.18, col=None):
    verts, faces = ico_template(sub)
    b = _batch(mat_); base = len(b[1]); r2 = random.Random(seed)
    for v in verts:
        k = 1.0 + r2.uniform(-jitter, jitter)
        p = Vector((loc[0] + v.x * r * squash[0] * k, loc[1] + v.y * r * squash[1] * k, loc[2] + v.z * r * squash[2] * k))
        b[1].append(p); b[3].append(col(p) if col else (1.0, 1.0, 1.0))
    for f in faces: b[2].append(tuple(base + i for i in f))

def bcyl(mat_, r, a, c, sides=6, col=None):
    a = Vector(a); c = Vector(c); d = c - a
    if d.length < 1e-5: return
    t = d.normalized(); u = t.orthogonal().normalized(); w = t.cross(u)
    b = _batch(mat_); base = len(b[1])
    for end in (a, c):
        for k in range(sides):
            th = 2 * math.pi * k / sides
            p = end + (u * math.cos(th) + w * math.sin(th)) * r
            b[1].append(p); b[3].append(col(p) if col else (1.0, 1.0, 1.0))
    for k in range(sides):
        k2 = (k + 1) % sides
        b[2].append((base + k, base + k2, base + sides + k2, base + sides + k))

def flush_batches():
    for name, (mat_, v, f, c) in BATCH.items():
        if not v: continue
        ob = L.obj_from("batch_" + name, v, f, mat_)
        if name.startswith("hero_"):
            attr = ob.data.color_attributes.new(name="Col", type="BYTE_COLOR", domain="POINT")
            for i, cc in enumerate(c): attr.data[i].color_srgb = (cc[0], cc[1], cc[2], 1.0)
            ob.data.color_attributes.active_color = attr

M = {
    "ground": vmat("hero_terrace_ground", 0.95),
    "rock": vmat("hero_terrace_rock", 0.9),
    "turf": vmat("hero_terrace_turf", 0.95),
    "leaf": vmat("hero_terrace_leaf", 0.85),
    "canopy": vmat("hero_terrace_canopy", 0.85),
    "bark": vmat("hero_terrace_bark", 0.85),
    "flag": vmat("hero_terrace_flag", 0.85),
    "timber": L.mat("terrace_timber", "#65412f", 0.8),
    "timber_dark": L.mat("terrace_timber_dark", "#4e321e", 0.85),
    "plank": L.mat("terrace_plank", "#8a6440", 0.85),
    "plaster": L.mat("terrace_plaster", "#8e6c4c", 0.9),
    # v3 (cell analysis c1v11: the concept's house cell is warm orange, L34 a17 b30; ours read pale yellow-white)
    "window": L.mat("terrace_window_glow", "#f6b66d", 0.5, "#ff9038", 3.6),
    "interior": L.mat("terrace_interior_glow", "#b86020", 0.7, "#e07028", 2.2),
    "canvas": L.mat("terrace_canvas", "#cdb494", 0.9, "#e0a060", 0.25),
    "sofa": L.mat("terrace_sofa", "#cdb090", 0.9),
    "cushion_r": L.mat("terrace_cushion_red", "#c0603c", 0.9),
    "cushion_g": L.mat("terrace_cushion_green", "#6e8a44", 0.9),
    "cushion_c": L.mat("terrace_cushion_cream", "#e8d4b0", 0.9),
    "rug": L.mat("terrace_rug", "#a8503c", 0.95),
    "lamp": L.mat("terrace_lantern_glow", "#ffd080", 0.4, "#ffa840", 6.0),
    "iron": L.mat("terrace_iron", "#2e2420", 0.6),
    "pot": L.mat("terrace_pot", "#a8603c", 0.85),
    "lav": L.mat("terrace_flower_lavender", "#8462e0", 0.6, "#7a58e0", 0.6),
    "pink": L.mat("terrace_flower_pink", "#e070bc", 0.6, "#d860b0", 0.4),
    "white": L.mat("terrace_flower_white", "#e8e2e6", 0.6),
    "wisteria2": L.mat("terrace_wisteria_deep", "#7a5ac8", 0.7, "#6a48c0", 0.4),
    "blue": L.mat("terrace_flower_blue_glow", "#58a8ff", 0.4, "#3c8cff", 1.3),
    "wisteria": L.mat("terrace_wisteria", "#a68ae8", 0.7, "#9078e0", 0.6),
    "mcap": L.mat("terrace_mushroom_cap", "#a878dc", 0.6, "#9a60e0", 1.0),
    "mstem": L.mat("terrace_mushroom_stem", "#ece0d4", 0.7),
}

# ---------------------------------------------------------------------------------------------------------
# Layout in concept pixels (x, y, height). The patio floor stands at PATIO_Z, the path falls to the frame bottom.
PATIO_Z = 1.4
HOUSE_NORMAL = Vector((0.62, -0.78, 0.0)).normalized()      # the front faces the camera, slightly right
HOUSE_TANGENT = Vector((-HOUSE_NORMAL.y, HOUSE_NORMAL.x, 0.0))  # along the front, toward the right
WIN_C = px_depth(135, 330, 18.0)                              # main window centre
FRONT_BASE = Vector((WIN_C.x, WIN_C.y, PATIO_Z))               # the front wall's foot under the window
PATIO_PTS = [px(185, 432, PATIO_Z), px(300, 446, PATIO_Z), px(440, 446, PATIO_Z), px(566, 424, PATIO_Z), px(574, 394, PATIO_Z),
             px(500, 374, PATIO_Z), px(380, 372, PATIO_Z)]
PATH_PTS = [(250, 455, 0.9), (232, 500, -0.2), (236, 540, -1.0), (300, 578, -1.6), (400, 616, -2.3), (500, 662, -3.0), (580, 720, -3.7), (620, 790, -4.3)]
PATH = [px(x, y, z) for x, y, z in PATH_PTS]

def catmull(pts, n_per=8):
    out = []
    P = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n_per):
            t = k / n_per
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-1])
    return out

PATH_C = catmull(PATH, 10)

def seg_dist(p, a, b):
    ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return (p - (a + ab * t)).length, t

def path_info(x, y):
    """(horizontal distance to the path centreline, path height there)."""
    p = Vector((x, y, 0.0)); best = (1e9, 0.0)
    for i in range(len(PATH_C) - 1):
        a = PATH_C[i].copy(); b = PATH_C[i + 1].copy(); za, zb = a.z, b.z; a.z = b.z = 0.0
        d, t = seg_dist(p, a, b)
        if d < best[0]: best = (d, za + (zb - za) * t)
    return best

def in_poly(x, y, poly):
    c = False; n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        if (a.y > y) != (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y + 1e-12) + a.x: c = not c
    return c

def poly_dist(x, y, poly):
    p = Vector((x, y, 0.0)); best = 1e9
    for i in range(len(poly)):
        a = poly[i].copy(); b = poly[(i + 1) % len(poly)].copy(); a.z = b.z = 0.0
        best = min(best, seg_dist(p, a, b)[0])
    return -best if in_poly(x, y, poly) else best

# Mound: an earth dome behind the front wall, top MOUND_TOP; its foot follows the front wall.
MOUND_C = FRONT_BASE - HOUSE_NORMAL * 6.5 + HOUSE_TANGENT * 1.0
MOUND_R = (10.5, 7.5)   # along the front, depth
MOUND_TOP = 7.4   # v4 (ChatGPT checkpoint: the broad dark mound hid the glowing facade): lower

def mound_h(x, y):
    d = Vector((x, y, 0.0)) - Vector((MOUND_C.x, MOUND_C.y, 0.0))
    a = d.dot(HOUSE_TANGENT) / MOUND_R[0]; b = d.dot(-HOUSE_NORMAL) / MOUND_R[1]
    r2 = a * a + b * b
    if r2 >= 1.0: return None
    return PATIO_Z + (MOUND_TOP - PATIO_Z) * (1.0 - r2) ** 0.55

# Ground: a heightfield inside the landform outline (world xy); outside the patio, mound and path, it eases
# between the patio level, the path's descent and the cliff edge, with low noise.
# World xy outline (v2: v1 converted far points above the horizon with px(), which put them behind the camera).
# The right side follows the concept's cliff edge (patio's right end, then down past the fence to the frame bottom).
EDGE = [Vector(v) for v in [(-42.0, 42.0, 0), (-30.0, 16.0, 0), (-24.0, 8.0, 0), (-12.0, 4.0, 0), (-4.0, 3.0, 0), (4.0, 6.0, 0), (6.5, 11.5, 0),
        (4.8, 12.6, 0), (1.8, 13.8, 0), (0.3, 16.0, 0), (-0.9, 16.6, 0), (-1.5, 18.5, 0), (-3.0, 25.0, 0), (-8.0, 36.0, 0), (-22.0, 46.0, 0)]]

def ground_h(x, y):
    pd, pz = path_info(x, y)
    # base: a gentle slope down toward the camera and the right edge, following the path's level
    base = pz + 0.5 * max(0.0, 3.0 - pd) * 0.0 + min(2.5, max(0.0, pd - 1.6) * 0.32)
    # rises behind toward the patio and the mound
    if in_poly(x, y, PATIO_PTS) or poly_dist(x, y, PATIO_PTS) < 1.2:
        base = PATIO_Z - 0.1
    else:
        dp = poly_dist(x, y, PATIO_PTS)
        if dp < 9.0:
            k = max(0.0, 1.0 - dp / 9.0) ** 1.5
            base = base * (1 - k) + (PATIO_Z - 0.2) * k
    # v3 (preview t3: the lower left sat at patio level, lifting the beds and lilies in front of the window): the
    # ground left of the path falls toward the camera, as in the concept.
    if not in_poly(x, y, PATIO_PTS):
        base = min(base, -4.2 + 0.55 * (y - 9.0) + 0.04 * (x + 10.0))
    mh = mound_h(x, y)
    if mh is not None: base = max(base, mh)
    # the cliff edge falls away on the right
    de = -poly_dist(x, y, EDGE)
    if de < 2.0: base -= (2.0 - de) * 0.6
    base += 0.25 * noise.noise(Vector((x * 0.15, y * 0.15, 3.1))) + 0.08 * noise.noise(Vector((x * 0.6, y * 0.6, 7.7)))
    if pd < 1.9: base = pz - 0.05
    return base

def build_ground():
    xs = [p.x for p in EDGE]; ys = [p.y for p in EDGE]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    step = 0.7
    nx = int((x1 - x0) / step) + 1; ny = int((y1 - y0) / step) + 1
    verts, faces, idx = [], [], {}
    for j in range(ny):
        for i in range(nx):
            x = x0 + i * step; y = y0 + j * step
            if poly_dist(x, y, EDGE) > step * 1.5: continue
            idx[(i, j)] = len(verts); verts.append((x, y, ground_h(x, y)))
    for j in range(ny - 1):
        for i in range(nx - 1):
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if all(k in idx for k in q):
                faces.append(tuple(idx[k] for k in q))
    ob = L.obj_from("ground", verts, faces, M["ground"])
    def col(co, i):
        pd, _ = path_info(co.x, co.y)
        n = noise.noise(Vector((co.x * 0.3, co.y * 0.3, 1.0)))
        c = mix(srgb("#2c4430"), srgb("#4c6a3a"), 0.5 + 0.6 * n)   # v3 palette: dark teal-greens (concept cell L25-34)
        if pd < 2.2: c = mix(srgb("#6a5a3c"), c, (pd - 1.4) / 0.8)
        mh = mound_h(co.x, co.y)
        if mh is not None and co.z > PATIO_Z + 1.0: c = mix(c, srgb("#3c5a30"), 0.5)
        return c
    paint(ob, col)
    return ob

def skirt():
    """Rock below the outline: a tapering wall to z -70 with faceted noise, then boulders on the visible lip."""
    pts = EDGE
    n = 160
    ring = []
    per = []
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        per.append((a - b).length)
    tot = sum(per)
    for k in range(n):
        s = tot * k / n
        i = 0
        while s > per[i]: s -= per[i]; i += 1
        a, b = pts[i], pts[(i + 1) % len(pts)]
        ring.append(a.lerp(b, s / per[i]))
    rows = [0.0, -1.5, -4.0, -8.0, -14.0, -24.0, -40.0, -70.0]
    verts, faces = [], []
    cx = sum(p.x for p in ring) / n; cy = sum(p.y for p in ring) / n
    for r_i, dz in enumerate(rows):
        for k, p in enumerate(ring):
            top = ground_h(p.x, p.y) - 0.2
            out = Vector((p.x - cx, p.y - cy, 0.0)).normalized()
            w = 0.6 * noise.noise(Vector((k * 0.21, r_i * 0.7, 2.0))) * min(1.0, -dz / 4.0 + 0.2)
            spread = 0.08 * (-dz) + w * 2.5
            verts.append((p.x + out.x * spread, p.y + out.y * spread, top + dz))
    for r_i in range(len(rows) - 1):
        for k in range(n):
            k2 = (k + 1) % n
            faces.append((r_i * n + k, r_i * n + k2, (r_i + 1) * n + k2, (r_i + 1) * n + k))
    ob = L.obj_from("skirt", verts, faces, M["rock"], smooth=False)
    paint(ob, lambda co, i: mix(srgb("#8a8296"), srgb("#5c5668"), 0.5 + 0.7 * noise.noise(Vector((co.x * 0.25, co.y * 0.25, co.z * 0.25)))))
    return ob

def rock(name, loc, size, seed, n=14):
    r2 = random.Random(seed)
    bm = bmesh.new()
    for _ in range(n):
        th = r2.uniform(0, 2 * math.pi); ph = math.acos(r2.uniform(-1, 1)); rr = r2.uniform(0.8, 1.0)
        bm.verts.new((rr * math.sin(ph) * math.cos(th) * size[0] * 0.5, rr * math.sin(ph) * math.sin(th) * size[1] * 0.5, rr * math.cos(ph) * size[2] * 0.5))
    bmesh.ops.convex_hull(bm, input=bm.verts[:])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(ob)
    ob.data.materials.append(M["rock"])
    ob.location = loc; ob.rotation_euler = (r2.uniform(-0.2, 0.2), r2.uniform(-0.2, 0.2), r2.uniform(0, 6.28))
    bpy.context.view_layer.update()
    tone = r2.uniform(0.0, 1.0)
    paint(ob, lambda co, i: mix(mix(srgb("#968ea0"), srgb("#6a6276"), tone), srgb("#5a7a30"), 0.85 if co.z > loc[2] + size[2] * 0.32 else 0.0))
    return ob

# ---------------------------------------------------------------------------------------------------------
build_ground()
skirt()
# boulders along the visible cliff lip and under the patio's front (the sheet's grey stones)
lip = [(600, 430, 0.0), (640, 480, -1.2), (690, 540, -2.2), (735, 590, -3.0), (800, 640, -4.0), (860, 690, -4.8), (20, 440, 0.4), (0, 500, -0.8), (-20, 600, -2.6),
       (560, 470, -0.2), (480, 480, -0.6), (380, 470, -0.4), (300, 475, -0.5)]
for k, (x, y, z) in enumerate(lip):
    p = px(x, y, z)
    s = rnd.uniform(1.6, 3.2)
    rock("lip%d" % k, (p.x, p.y, p.z - s * 0.25), (s * 1.3, s * 1.1, s * 0.9), 300 + k)

# ---- the house: curved timber front wall, round-arched window, arched door, beams, turf roof -------------------
def front_frame():
    """Local frame at the front wall foot: origin FRONT_BASE, x along the front (right), y into the camera."""
    return FRONT_BASE, HOUSE_TANGENT, HOUSE_NORMAL

def wall_pt(u, z, out=0.0):
    o, t, n = front_frame()
    # the front bows outward a little (a hobbit hole's curved face)
    bow = 0.6 * math.cos(max(-1.0, min(1.0, (u - 1.5) / 7.0)) * math.pi / 2)
    return o + t * u + n * (bow + out) + Vector((0, 0, z))

def arch_hole_panel(name, u0, u1, h, out, mat_, n=18):
    """A flat arched panel on the wall (window glass or door leaf)."""
    w = u1 - u0; r = w / 2; uc = (u0 + u1) / 2
    pts = [(u0, 0.0), (u1, 0.0)] + [(uc + r * math.cos(math.pi * i / n), h - r + r * math.sin(math.pi * i / n)) for i in range(n + 1)][::-1]
    pts = [(u0, 0.0)] + [(uc - r * math.cos(math.pi * i / n), h - r + r * math.sin(math.pi * i / n)) for i in range(n + 1)] + [(u1, 0.0)]
    verts = [wall_pt(u, z + 0.35, out) for u, z in pts]
    c = wall_pt(uc, h * 0.45 + 0.35, out)
    verts.append(c)
    m = len(pts)
    faces = [(i, i + 1, m) for i in range(m - 1)] + [(m - 1, 0, m)]
    return L.obj_from(name, verts, faces, mat_, smooth=False), pts

def frame_tube(name, pts, out, r, mat_):
    for k in range(len(pts) - 1):
        a = wall_pt(pts[k][0], pts[k][1] + 0.35, out); b = wall_pt(pts[k + 1][0], pts[k + 1][1] + 0.35, out)
        d = b - a
        if d.length < 1e-4: continue
        ob = L.cyl("%s_%d" % (name, k), r, d.length + r * 0.6, (a + b) / 2, mat_, verts=8)
        ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()

# wall plaster face from u -4.5 to 7.5, up to the arch beam line, set in the mound
wall_verts, wall_faces = [], []
US = [-4.6 + 0.4 * i for i in range(31)]
ZS = [0.0, 1.0, 2.0, 3.0, 3.8, 4.4]
for z in ZS:
    for u in US:
        top = 4.4 - 0.9 * ((u - 1.5) / 6.1) ** 2
        wall_verts.append(wall_pt(u, min(z, top), -0.15))
nu = len(US)
for j in range(len(ZS) - 1):
    for i in range(nu - 1):
        wall_faces.append((j * nu + i, j * nu + i + 1, (j + 1) * nu + i + 1, (j + 1) * nu + i))
L.obj_from("front_wall", wall_verts, wall_faces, M["plaster"])

# main window: 3.6 x 2.8 m round-arched, warm glow with mullions; interior glow plane set back
win, wpts = arch_hole_panel("window", -2.2, 2.2, 3.3, 0.02, M["window"])
inside, _ = arch_hole_panel("window_back", -2.2, 2.2, 3.3, -0.5, M["interior"])
frame_tube("window_frame", wpts, 0.08, 0.16, M["timber"])
for u in (-0.95, 0.0, 0.95):
    a = wall_pt(u, 0.35, 0.1); b = wall_pt(u, 0.35 + 2.8 - (1.9 - math.sqrt(max(0.0, 1.9 ** 2 - u * u))), 0.1)
    ob = L.cyl("mullion", 0.05, (b - a).length, (a + b) / 2, M["timber_dark"], verts=6)
for z in (1.1, 2.0):
    a = wall_pt(-1.85, z + 0.35, 0.1); b = wall_pt(1.85, z + 0.35, 0.1)
    ob = L.cyl("transom", 0.045, (b - a).length, (a + b) / 2, M["timber_dark"], verts=6); ob.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
# shelves and a warm lamp silhouette inside
for k, z in enumerate((0.6, 1.3, 2.0)):
    a = wall_pt(-1.6, z + 0.35, -0.42); b = wall_pt(1.6, z + 0.35, -0.42)
    ob = L.cyl("shelf%d" % k, 0.05, (b - a).length, (a + b) / 2, M["timber_dark"], verts=6); ob.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
# door: 1.6 x 2.0 arched, timber leaf with a round glowing window
door, dpts = arch_hole_panel("door", 3.4, 5.0, 2.3, 0.04, M["timber"])
frame_tube("door_frame", dpts, 0.1, 0.13, M["timber_dark"])
L.blob("door_window", 0.28, tuple(wall_pt(4.2, 1.85, 0.08)), M["window"], squash=(1, 1, 1), sub=2, jitter=0.0)
# small side window left of the main window
sw, swp = arch_hole_panel("side_window", -3.9, -2.9, 1.5, 0.02, M["window"])
frame_tube("side_frame", swp, 0.08, 0.1, M["timber"])
# curved beams over the openings
for k, (u0, u1, h) in enumerate([(-2.3, 2.3, 3.4), (3.1, 5.3, 2.75)]):
    pts = [(u0 + (u1 - u0) * i / 12, 0.0) for i in range(13)]
    arc = [(u, h - (h * 0.18) * ((2 * (u - u0) / (u1 - u0) - 1) ** 2) + 0.15) for u, _ in pts]
    frame_tube("beam%d" % k, arc, 0.18, 0.2, M["timber"])
# turf overhang: a thick mossy lip over the front, then the mound
lip_verts, lip_faces = [], []
for i, u in enumerate([-5.0 + 0.5 * k for k in range(27)]):
    top = 4.4 - 0.9 * ((u - 1.5) / 6.1) ** 2
    for z, out in ((top - 0.25, 0.55), (top + 0.35, 0.45), (top + 0.6, -0.4), (top + 0.4, -1.2)):
        lip_verts.append(wall_pt(u, z + 0.15 * noise.noise(Vector((u, z, 0.0))), out))
for i in range(26):
    for k in range(3):
        lip_faces.append((i * 4 + k, (i + 1) * 4 + k, (i + 1) * 4 + k + 1, i * 4 + k + 1))
lipob = L.obj_from("turf_lip", lip_verts, lip_faces, M["turf"])
paint(lipob, lambda co, i: mix(srgb("#2e4628"), srgb("#5a7a3a"), 0.5 + 0.5 * noise.noise(Vector((co.x, co.y, co.z)))))

# ---- patio: flagstone floor, planks, rug, railing, furniture, awning --------------------------------------
cx = sum(p.x for p in PATIO_PTS) / len(PATIO_PTS); cy = sum(p.y for p in PATIO_PTS) / len(PATIO_PTS)
pv = [Vector((cx, cy, PATIO_Z))] + [p.copy() for p in PATIO_PTS]
pf = [(0, i + 1, (i + 1) % len(PATIO_PTS) + 1) for i in range(len(PATIO_PTS))]
floor = L.obj_from("patio_floor", pv, pf, M["flag"], smooth=False)
paint(floor, lambda co, i: srgb("#a89480"))
# flagstones over the floor
for k in range(70):
    a = rnd.random(); b = rnd.random()
    if a + b > 1.0: a, b = 1 - a, 1 - b
    i = rnd.randrange(len(PATIO_PTS))
    p = Vector((cx, cy, 0)) + (PATIO_PTS[i] - Vector((cx, cy, 0))) * a * 0.95 + (PATIO_PTS[(i + 1) % len(PATIO_PTS)] - Vector((cx, cy, 0))) * b * 0.95
    s = rnd.uniform(0.8, 1.5)
    st = L.lathe("flag%d" % k, [(s, PATIO_Z + 0.02), (s * 0.96, PATIO_Z + 0.09), (0.0, PATIO_Z + 0.1)], 9, M["flag"], close_top=True, smooth=False,
                 deform=lambda x, y, z, th, i_, p=p, s=s, k=k: (p.x + x * (1 + 0.25 * math.sin(3 * th + k)), p.y + y * (0.8 + 0.2 * math.cos(2 * th + k)), z))
    tone = rnd.uniform(0, 1)
    paint(st, lambda co, i_, tone=tone: mix(srgb("#c2b09c"), srgb("#968878"), tone))
rug_c = Vector((cx, cy, PATIO_Z + 0.12)) - HOUSE_NORMAL * 0.4
L.box("rug", (3.4, 2.4, 0.03), tuple(rug_c), M["rug"], rot=(0, 0, math.atan2(HOUSE_TANGENT.y, HOUSE_TANGENT.x)))

def rail_line(name, pts, z0, posts_every=1.8, h=1.0):
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        n = max(1, int((b - a).length / posts_every))
        for k in range(n + 1):
            p = a.lerp(b, k / n)
            gz = z0(p) if callable(z0) else z0
            L.cyl("%s_post%d_%d" % (name, i, k), 0.09, h + 0.2, (p.x, p.y, gz + (h + 0.2) / 2), M["timber"], verts=7)
        for hh in (h * 0.5, h):
            za = (z0(a) if callable(z0) else z0) + hh; zb = (z0(b) if callable(z0) else z0) + hh
            A = Vector((a.x, a.y, za)); B = Vector((b.x, b.y, zb)); d = B - A
            wob = Vector((0, 0, 0.05 * math.sin(i + hh * 7)))
            ob = L.cyl("%s_rail%d_%d" % (name, i, int(hh * 10)), 0.06, d.length, (A + B) / 2 + wob, M["timber"], verts=6)
            ob.rotation_euler = d.to_track_quat("Z", "Y").to_euler()

rail_line("patio_rail", [PATIO_PTS[1], PATIO_PTS[2], PATIO_PTS[3], PATIO_PTS[4]], PATIO_Z + 0.1)

def lantern(name, p, hanging=False):
    L.box(name + "_cap", (0.32, 0.32, 0.08), (p.x, p.y, p.z + 0.32), M["iron"])
    L.blob(name + "_glow", 0.2, (p.x, p.y, p.z), M["lamp"], squash=(0.85, 0.85, 1.25), sub=2, jitter=0.0)
    L.box(name + "_base", (0.28, 0.28, 0.06), (p.x, p.y, p.z - 0.3), M["iron"])
    if hanging:
        L.cyl(name + "_chain", 0.02, 1.2, (p.x, p.y, p.z + 0.95), M["iron"], verts=4)

def lantern_post(name, g):
    L.cyl(name + "_post", 0.1, 2.5, (g.x, g.y, g.z + 1.25), M["timber_dark"], verts=8)
    arm_end = g + Vector((0.55, 0.0, 2.4))
    ob = L.cyl(name + "_arm", 0.05, 0.6, (g.x + 0.28, g.y, g.z + 2.42), M["timber_dark"], rot=(0, math.pi / 2, 0), verts=6)
    lantern(name, Vector((arm_end.x, arm_end.y, g.z + 1.95)))

for k, p in enumerate([PATIO_PTS[3], PATIO_PTS[1], PATIO_PTS[4]]):
    lantern_post("patio_lp%d" % k, Vector((p.x, p.y, PATIO_Z)))
# sofas, armchairs, table
def sofa(name, c, facing, w=2.4):
    t = Vector((-facing.y, facing.x, 0)); yaw = math.atan2(t.y, t.x)
    base = c + Vector((0, 0, PATIO_Z))
    L.box(name + "_seat", (w, 0.9, 0.42), tuple(base + Vector((0, 0, 0.32))), M["sofa"], rot=(0, 0, yaw), bevel=0.06)
    L.box(name + "_back", (w, 0.25, 0.6), tuple(base - facing * 0.4 + Vector((0, 0, 0.78))), M["timber"], rot=(0, 0, yaw), bevel=0.05)
    for k, mm in enumerate((M["cushion_c"], M["cushion_r"], M["cushion_g"])):
        L.blob(name + "_cush%d" % k, 0.3, tuple(base - facing * 0.25 + t * (w * (k - 1) * 0.32) + Vector((0, 0, 0.8))), mm, squash=(1.1, 0.55, 0.9), sub=2, jitter=0.05)
    for s in (-1, 1):
        L.box(name + "_arm%d" % s, (0.22, 0.9, 0.55), tuple(base + t * (s * w / 2) + Vector((0, 0, 0.45))), M["timber"], rot=(0, 0, yaw), bevel=0.05)

sofa("sofa1", Vector((cx, cy, 0)) - HOUSE_NORMAL * 1.2 + HOUSE_TANGENT * 1.2, HOUSE_NORMAL)
sofa("sofa2", Vector((cx, cy, 0)) + HOUSE_NORMAL * 1.6 + HOUSE_TANGENT * 2.6, Vector((-0.2, 1.0, 0)).normalized(), 2.0)
sofa("chair1", Vector((cx, cy, 0)) - HOUSE_TANGENT * 2.0 + HOUSE_NORMAL * 0.6, (HOUSE_TANGENT + HOUSE_NORMAL * 0.3).normalized(), 1.0)
tc = Vector((cx, cy, PATIO_Z)) + HOUSE_TANGENT * 0.8 + HOUSE_NORMAL * 0.2
L.box("table", (1.4, 0.8, 0.12), tuple(tc + Vector((0, 0, 0.45))), M["timber"], rot=(0, 0, math.atan2(HOUSE_TANGENT.y, HOUSE_TANGENT.x)), bevel=0.03)
for s in (-1, 1):
    for q in (-1, 1):
        L.cyl("tleg", 0.05, 0.42, tuple(tc + HOUSE_TANGENT * 0.55 * s + HOUSE_NORMAL * 0.3 * q + Vector((0, 0, 0.21))), M["timber_dark"], verts=6)
# pots with plants
for k, u in enumerate((-3.0, 2.6, 6.2)):
    p = wall_pt(u, 0.0, 0.7)
    L.cyl("pot%d" % k, 0.3, 0.5, (p.x, p.y, p.z + 0.25), M["pot"], verts=10)
    for j in range(5):
        bblob(M["leaf"], 0.28, (p.x + rnd.uniform(-0.2, 0.2), p.y + rnd.uniform(-0.2, 0.2), p.z + 0.65 + rnd.uniform(0, 0.4)), squash=(1, 1, 0.8), sub=1, col=lambda q: srgb("#4e7a32"))
# awning: cream canvas from the wall top over the patio on two poles, sagging
# v2 (preview t1: the canvas covered the whole patio; the concept's awning runs from above the window's right
# shoulder over the patio's back-right only)
aw_u0, aw_u1 = 2.6, 6.8   # v4: a smaller awning (ChatGPT: it out-shouted the entrance)
aw_poles = [wall_pt(7.0, 0.0, 2.6), wall_pt(2.8, 0.0, 2.4)]
for k, p in enumerate(aw_poles):
    L.cyl("aw_pole%d" % k, 0.08, 2.7, (p.x, p.y, PATIO_Z + 1.35), M["timber"], verts=8)
av, af = [], []
NU, NV = 14, 6
for i in range(NU + 1):
    t = i / NU
    back = wall_pt(aw_u0 + (aw_u1 - aw_u0) * t, 4.1 - 0.5 * t, 0.3)
    front = aw_poles[1].lerp(aw_poles[0], t) + Vector((0, 0, 2.7 - 0.4 * t))
    for j in range(NV + 1):
        s = j / NV
        p = back.lerp(front, s) - Vector((0, 0, 0.35 * math.sin(math.pi * s) + 0.15 * math.sin(math.pi * t)))
        av.append(p)
for i in range(NU):
    for j in range(NV):
        af.append((i * (NV + 1) + j, (i + 1) * (NV + 1) + j, (i + 1) * (NV + 1) + j + 1, i * (NV + 1) + j + 1))
canvas = L.obj_from("awning", av, af, M["canvas"])
md = canvas.modifiers.new("solid", "SOLIDIFY"); md.thickness = 0.05

# ---- retaining wall below the patio front with wisteria --------------------------------------------------
wall_line = [PATIO_PTS[0], PATIO_PTS[1], PATIO_PTS[2], PATIO_PTS[3]]
for i in range(len(wall_line) - 1):
    a, b = wall_line[i], wall_line[i + 1]
    n = int((b - a).length / 0.9) + 1
    for k in range(n):
        p = a.lerp(b, (k + 0.5) / n)
        g = ground_h(p.x + rnd.uniform(-0.3, 0.3), p.y - 1.0)
        h = PATIO_Z - g
        if h < 0.3: continue
        rock("rw%d_%d" % (i, k), (p.x, p.y, (PATIO_Z + g) / 2 - 0.1), (1.1, 0.9, h + 0.4), 500 + i * 40 + k, n=12)
        if rnd.random() < 0.7:
            # v2 (capture c1v07: big pale icicles): clusters of small blossoms in two violets, tapering down
            for j in range(rnd.randint(3, 6)):
                q = p + Vector((rnd.uniform(-0.5, 0.5), rnd.uniform(-0.6, -0.2), 0))
                ln = rnd.uniform(0.5, min(1.8, h + 0.3))
                mm = M["wisteria"] if rnd.random() < 0.5 else M["wisteria2"]
                for b_i in range(5):
                    t = b_i / 5
                    bblob(mm, 0.11 * (1.0 - 0.6 * t), (q.x + rnd.uniform(-0.05, 0.05), q.y, PATIO_Z - 0.1 - ln * t), squash=(1, 1, 1.3), sub=1, jitter=0.3)

# ---- steps and flagstone path ----------------------------------------------------------------------------
for k in range(len(PATH_C) - 1):
    if k % 2: continue
    a, b = PATH_C[k], PATH_C[k + 1]
    d = (b - a); d.z = 0
    yaw = math.atan2(d.y, d.x)
    # v4 (ChatGPT: path narrow and fragmented; concept ~2-3 m of large overlapping flagstones)
    for j in range(3 if k > 18 else 1):
        off = Vector((-d.y, d.x, 0)).normalized() * ((j - 1) * 0.85 + rnd.uniform(-0.2, 0.2) if k > 18 else 0.0)
        p = a + off
        s = rnd.uniform(0.6, 0.95) if k > 18 else 1.05
        z = p.z + (0.05 if k > 18 else 0.0)
        st = L.lathe("pstone%d_%d" % (k, j), [(s, z - 0.15), (s * 0.97, z + 0.06), (0.0, z + 0.08)], 10, M["flag"], close_top=True, smooth=False,
                     deform=lambda x, y, zz, th, i_, p=p, s=s, k=k, yaw=yaw: (p.x + (x * 1.5 * math.cos(yaw) - y * math.sin(yaw)) * (1 + 0.15 * math.sin(3 * th + k)),
                                                                              p.y + (x * 1.5 * math.sin(yaw) + y * math.cos(yaw)) * (1 + 0.15 * math.sin(3 * th + k)), zz))
        tone = rnd.uniform(0, 1)
        paint(st, lambda co, i_, tone=tone: mix(srgb("#968878"), srgb("#6c6258"), tone))   # v5: darker (capture c1v21: the lit path out-shone the concept's)
# risers under the steps between the patio and the path
for k in range(4):
    p = PATH_C[min(k * 2, len(PATH_C) - 1)]
    rock("riser%d" % k, (p.x, p.y, p.z - 0.45), (1.9, 1.0, 0.8), 700 + k)

# fence on the path's right, lantern posts along it
def side(k, off):
    a, b = PATH_C[k], PATH_C[min(k + 1, len(PATH_C) - 1)]
    d = b - a; d.z = 0; nrm = Vector((d.y, -d.x, 0)).normalized()
    return a + nrm * off
fence_pts = [side(k, 1.6) for k in range(22, len(PATH_C) - 6, 6)]
rail_line("fence", fence_pts, lambda p: ground_h(p.x, p.y) - 0.05, posts_every=2.0, h=0.95)
for k, (x, y, z) in enumerate([(125, 468, 0.3), (350, 512, -0.9), (565, 520, -1.0), (450, 588, -1.9), (680, 650, -3.0)]):
    g = px(x, y, z); g.z = ground_h(g.x, g.y)
    lantern_post("path_lp%d" % k, g)

# ---- flower beds -----------------------------------------------------------------------------------------
LEAF_COL = lambda q: srgb("#3e6428")
def flower(name, p, mat_, size, petals=6):
    for j in range(petals):
        a = 2 * math.pi * j / petals
        bblob(mat_, size * 0.45, (p.x + math.cos(a) * size * 0.5, p.y + math.sin(a) * size * 0.5, p.z), squash=(1.0, 0.6, 0.35), sub=1, jitter=0.1)
    g = ground_h(p.x, p.y)
    bcyl(M["leaf"], size * 0.06, (p.x, p.y, g - 0.1), (p.x, p.y, p.z), 4, LEAF_COL)

def lily(name, p, size):
    """Glowing blue lily: an upturned cup of 5 petals with a bright core."""
    for j in range(5):
        a = 2 * math.pi * j / 5
        bblob(M["blue"], size * 0.42, (p.x + math.cos(a) * size * 0.42, p.y + math.sin(a) * size * 0.42, p.z + size * 0.2), squash=(0.9, 0.45, 0.6), sub=2, jitter=0.05)
    bblob(M["white"], size * 0.18, (p.x, p.y, p.z + 0.1 * size), sub=1)
    g = ground_h(p.x, p.y)
    bcyl(M["leaf"], size * 0.05, (p.x, p.y, g), (p.x, p.y, p.z), 5, LEAF_COL)
    for j in range(3):
        a = rnd.uniform(0, 6.28)
        bblob(M["leaf"], size * 0.5, (p.x + math.cos(a) * size * 0.5, p.y + math.sin(a) * size * 0.5, g + size * 0.3), squash=(1.2, 0.4, 0.35), sub=1, col=LEAF_COL)

def bush(name, p, s, seed):
    r2 = random.Random(seed)
    for j in range(5):
        q = p + Vector((r2.uniform(-0.6, 0.6) * s, r2.uniform(-0.6, 0.6) * s, r2.uniform(0.2, 0.7) * s))
        bblob(M["leaf"], s * r2.uniform(0.45, 0.7), tuple(q), squash=(1, 1, 0.85), sub=2, seed=seed + j, jitter=0.2,
              col=lambda co, q=q, s=s: mix(srgb("#16242a"), srgb("#3a5848"), 0.5 + (co.z - q.z) / (s * 0.9)))   # v5: bluer, the concept's violet-dark foreground

beds = [  # (px, py, z guess, count, spread m)
    (90, 600, -2.0, 220, 4.5), (260, 640, -2.6, 150, 3.5), (380, 690, -3.2, 90, 2.5), (150, 500, -0.6, 110, 3.0), (30, 680, -3.4, 120, 3.0),
    (430, 560, -1.6, 50, 1.8), (330, 470, 0.4, 40, 2.0), (40, 470, -0.2, 60, 2.5), (520, 470, 0.0, 30, 1.6), (200, 700, -3.4, 90, 2.5)]
fk = 0
for (x, y, z, cnt, spread) in beds:
    c = px(x, y, z)
    for _ in range(cnt):
        p = c + Vector((rnd.uniform(-spread, spread), rnd.uniform(-spread, spread), 0))
        pd, _ = path_info(p.x, p.y)
        if pd < 1.9 or in_poly(p.x, p.y, PATIO_PTS) or poly_dist(p.x, p.y, EDGE) > -0.5: continue
        g = ground_h(p.x, p.y)
        r = rnd.random()
        if r < 0.55:
            flower("fl%d" % fk, Vector((p.x, p.y, g + rnd.uniform(0.3, 0.8))), M["lav"], rnd.uniform(0.22, 0.42))
        elif r < 0.55:
            flower("fl%d" % fk, Vector((p.x, p.y, g + rnd.uniform(0.3, 0.7))), M["pink"], rnd.uniform(0.2, 0.36))
        elif r < 0.62:
            flower("fl%d" % fk, Vector((p.x, p.y, g + rnd.uniform(0.25, 0.5))), M["white"], rnd.uniform(0.12, 0.18))
        else:
            bush("fb%d" % fk, Vector((p.x, p.y, g)), rnd.uniform(0.5, 1.1), 900 + fk)
        fk += 1
# big glowing lilies in the frame's lower left (concept: luminous blue lilies at the corner)
for k, (x, y, z, s) in enumerate([(50, 600, -2.6, 1.25), (140, 650, -3.0, 1.0), (10, 700, -3.6, 1.1), (180, 560, -2.0, 0.7), (380, 700, -3.4, 0.8), (240, 610, -2.4, 0.6),
                                   (300, 690, -3.2, 0.55), (90, 520, -1.2, 0.6), (420, 640, -2.6, 0.45)]):
    g = px(x, y, z)
    lily("lily%d" % k, Vector((g.x, g.y, ground_h(g.x, g.y) + s * 1.4)), s)
# shrubs along the right cliff edge
for k, (x, y, z) in enumerate([(700, 610, -3.2), (760, 640, -3.8), (840, 690, -4.6), (640, 560, -2.2), (900, 730, -5.2), (600, 500, -1.0)]):
    g = px(x, y, z)
    bush("edge%d" % k, Vector((g.x, g.y, ground_h(g.x, g.y))), rnd.uniform(1.0, 1.6), 1200 + k)

# ---- the mound top: turf dome with flowers, ferns, purple mushrooms ---------------------------------------
mv, mf = [], []
NA, NR = 40, 10
for i in range(NR + 1):
    rr = i / NR
    for j in range(NA):
        a = 2 * math.pi * j / NA
        lx = math.cos(a) * rr * MOUND_R[0]; ly = math.sin(a) * rr * MOUND_R[1]
        p = Vector((MOUND_C.x, MOUND_C.y, 0)) + HOUSE_TANGENT * lx - HOUSE_NORMAL * ly
        z = PATIO_Z + (MOUND_TOP - PATIO_Z) * max(0.0, 1.0 - rr * rr) ** 0.55 + 0.3 * noise.noise(Vector((p.x * 0.3, p.y * 0.3, 5.0)))
        mv.append((p.x, p.y, z))
for i in range(NR):
    for j in range(NA):
        j2 = (j + 1) % NA
        mf.append((i * NA + j, i * NA + j2, (i + 1) * NA + j2, (i + 1) * NA + j))
mound = L.obj_from("mound", mv, mf, M["turf"])
paint(mound, lambda co, i: mix(srgb("#2a4228"), srgb("#56743a"), 0.5 + 0.6 * noise.noise(Vector((co.x * 0.4, co.y * 0.4, co.z * 0.4)))))
for k in range(170):
    a = rnd.uniform(0, 2 * math.pi); rr = math.sqrt(rnd.uniform(0.0, 0.85))
    p = Vector((MOUND_C.x, MOUND_C.y, 0)) + HOUSE_TANGENT * math.cos(a) * rr * MOUND_R[0] - HOUSE_NORMAL * math.sin(a) * rr * MOUND_R[1]
    z = PATIO_Z + (MOUND_TOP - PATIO_Z) * max(0.0, 1.0 - rr * rr) ** 0.55
    r = rnd.random()
    if r < 0.4: bush("mb%d" % k, Vector((p.x, p.y, z - 0.2)), rnd.uniform(0.5, 1.1), 1500 + k)
    elif r < 0.75: flower("mf%d" % k, Vector((p.x, p.y, z + 0.3)), rnd.choice([M["lav"], M["pink"], M["white"], M["lav"]]), 0.3)
# purple mushrooms on the mound's left shoulder (sheet)
for k, (u, d, h) in enumerate([(-6.5, 2.5, 2.4), (-5.2, 3.6, 1.7), (-7.4, 4.2, 1.3)]):
    p = Vector((MOUND_C.x, MOUND_C.y, 0)) + HOUSE_TANGENT * (u + 1.0) - HOUSE_NORMAL * (d - 6.5)
    g = (mound_h(p.x, p.y) or PATIO_Z) - 0.2
    L.cyl("mst%d" % k, 0.12 * h, h, (p.x, p.y, g + h / 2), M["mstem"], verts=10)
    L.lathe("mcap%d" % k, [(0.75 * h, g + h - 0.1), (0.65 * h, g + h + 0.18 * h), (0.35 * h, g + h + 0.33 * h), (0.0, g + h + 0.37 * h)], 20, M["mcap"], close_top=True,
            deform=lambda x, y, z, th, i, p=p: (x + p.x, y + p.y, z))

# ---- the ancient tree behind the mound -------------------------------------------------------------------
# v2 (preview t1: the canopy sat above the frame): base on the mound's back near eye level, a 16 m trunk,
# limbs reaching toward the camera and right at 10-15 m so the canopy fills the frame's top-left band.
TREE_BASE = Vector((-21.0, 28.5, 0.0)); TREE_BASE.z = (mound_h(TREE_BASE.x, TREE_BASE.y) or 6.5) - 1.0
def tree_col(co, i):
    return mix(srgb("#4a3a2e"), srgb("#8a7058"), 0.5 + 0.6 * noise.noise(Vector((co.x * 0.8, co.y * 0.8, co.z * 0.2))))

def tube(name, pts, radii, mat_, colf, sides=10):
    verts, faces = [], []
    n = len(pts)
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        a = t.orthogonal().normalized(); b = t.cross(a)
        for k in range(sides):
            th = 2 * math.pi * k / sides
            rr = radii[i] * (1.0 + 0.12 * math.sin(3 * th + i * 0.7))
            verts.append(p + (a * math.cos(th) + b * math.sin(th)) * rr)
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
    ob = L.obj_from(name, verts, faces, mat_)
    paint(ob, colf)
    return ob

trunk_pts = [TREE_BASE + Vector((0.6 * math.sin(t * 2.0) + 1.2 * t, -0.8 * math.sin(t * 1.3), t * 16.0)) for t in [i / 10 for i in range(11)]]
tube("trunk", trunk_pts, [2.8 - 1.3 * (i / 10) ** 0.7 for i in range(11)], M["bark"], tree_col, sides=14)
# buttress roots over the mound
for k in range(7):
    a = 2 * math.pi * k / 7 + 0.3
    pts = [TREE_BASE + Vector((math.cos(a) * 1.5, math.sin(a) * 1.5, 2.5)), TREE_BASE + Vector((math.cos(a) * 3.5, math.sin(a) * 3.5, 0.6)), TREE_BASE + Vector((math.cos(a) * 5.5, math.sin(a) * 5.5, -1.0))]
    tube("root%d" % k, pts, [1.0, 0.6, 0.25], M["bark"], tree_col, sides=8)
# branches: big limbs spreading toward the front-right over the terrace, and left
leaf_centres = []
# v3 (cell analysis c1v10: the canopy darkened the concept's bright sky at x 320-640): shorter right-hand limbs
limbs = [((0.45, -0.9), 12.5, 12.5, 1.4), ((1.0, -0.35), 13.5, 9.0, 1.3), ((-0.8, -0.6), 12.0, 12.0, 1.2), ((0.2, 0.9), 15.0, 9.0, 1.0), ((-0.5, 0.8), 13.0, 8.0, 1.0), ((0.1, -1.0), 11.5, 15.0, 1.1)]
for k, (d2, ztop, length, r0) in enumerate(limbs):
    d = Vector((d2[0], d2[1], 0)).normalized()
    start = trunk_pts[5 + (k % 4)]
    pts = []
    for i in range(9):
        t = i / 8
        pts.append(start + d * length * t + Vector((0, 0, (ztop - start.z) * math.sin(t * math.pi * 0.55) - 3.0 * t * t)))
    tube("limb%d" % k, pts, [r0 * (1 - 0.75 * i / 8) for i in range(9)], M["bark"], tree_col, sides=9)
    for i in (3, 5, 7, 8):
        leaf_centres.append(pts[i] + Vector((0, 0, 2.5)))
        # twigs
        for j in range(2):
            a = rnd.uniform(0, 6.28)
            q = pts[i] + Vector((math.cos(a) * 3.0, math.sin(a) * 3.0, rnd.uniform(0.5, 2.5)))
            tube("twig%d_%d_%d" % (k, i, j), [pts[i], pts[i].lerp(q, 0.5) + Vector((0, 0, 0.6)), q], [0.35, 0.22, 0.1], M["bark"], tree_col, sides=6)
            leaf_centres.append(q + Vector((0, 0, 1.0)))
    # hanging lanterns from the front limbs
    if k in (0, 1, 5):
        for i in (4, 6):
            p = pts[i] - Vector((0, 0, 2.2))
            lantern("hl%d_%d" % (k, i), p, hanging=True)
leaf_centres.append(trunk_pts[-1] + Vector((0, 0, 3.0)))
# canopy: clusters of squashed blobs, dark under, lit on top
for k, c in enumerate(leaf_centres):
    for j in range(5):
        q = c + Vector((rnd.uniform(-2.4, 2.4), rnd.uniform(-2.4, 2.4), rnd.uniform(-0.8, 1.6)))
        s = rnd.uniform(1.8, 3.0)
        bblob(M["canopy"], s, tuple(q), squash=(1.0, 1.0, 0.7), sub=2, seed=k * 10 + j, jitter=0.22,
              col=lambda co, q=q, s=s: mix(srgb("#22341e"), srgb("#5a7a40"), 0.45 + 0.75 * (co.z - q.z) / (s * 0.7)))

# ---------------------------------------------------------------------------------------------------------
# v4 facade (ChatGPT checkpoint: make the glowing home front the centrepiece): a great curved timber arch framing
# window and door, wall lanterns either side of the window, vines from the turf lip, roots draping over the top.
arc_pts = []
for i in range(25):
    t = i / 24
    u = -4.7 + 10.9 * t
    z = 4.75 * math.sin(math.pi * t) ** 0.7 - 0.2   # v5: hugs the wall top (capture c1v15: the arch towered over the house)
    arc_pts.append((u, z))
frame_tube("great_arch", arc_pts, 0.35, 0.42, M["timber"])
frame_tube("great_arch_in", [(u * 0.93 + 0.08, z * 0.93) for u, z in arc_pts], 0.42, 0.22, M["timber_dark"])
for i in range(0, 25, 3):
    u, z = arc_pts[i]
    a = wall_pt(u, z + 0.35, 0.35); b = wall_pt(u * 0.86 + 0.2, z * 0.86 + 0.35, 0.45)
    ob = L.cyl("arch_spoke%d" % i, 0.09, (b - a).length, (a + b) / 2, M["timber_dark"], verts=6); ob.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
for u in (-2.9, 2.75):
    lantern("wall_lamp%d" % int(u * 10), wall_pt(u, 2.7, 0.6))
for k in range(26):
    u = rnd.choice((rnd.uniform(-5.0, -2.7), rnd.uniform(2.4, 3.1), rnd.uniform(5.4, 6.4)))   # not across the window or door
    top = 4.4 - 0.9 * ((u - 1.5) / 6.1) ** 2
    ln = rnd.uniform(0.6, 2.0)
    base = wall_pt(u, top - 0.2, 0.62)
    for b_i in range(7):
        t = b_i / 7
        q = base + Vector((0, 0, -ln * t)) + HOUSE_NORMAL * (0.05 * math.sin(b_i))
        bblob(M["leaf"] if rnd.random() < 0.8 else M["wisteria"], 0.12 * (1.0 - 0.4 * t), tuple(q), squash=(1.2, 1.2, 1.0), sub=1, jitter=0.3,
              col=lambda co: srgb("#2c4a2c"))
for k in range(4):
    u0 = -4.5 + 2.2 * k + rnd.uniform(-0.3, 0.3)
    top = 4.4 - 0.9 * ((u0 - 1.5) / 6.1) ** 2
    pts = [wall_pt(u0 + 0.4, top + 1.6, -1.5), wall_pt(u0 + 0.2, top + 0.9, 0.2), wall_pt(u0, top - 0.2, 0.75), wall_pt(u0 - 0.1, top - 1.2, 0.7)]
    tube("facade_root%d" % k, pts, [0.32, 0.26, 0.18, 0.08], M["bark"], lambda co, i: srgb("#5a4634"), sides=7)

flush_batches()
print("TRIS_BEFORE_JOIN", L.tri_count())
names = list(L.join_by_material())
print("MATERIAL_OBJECTS", names)
print("TRIS", L.tri_count())
bpy.ops.export_scene.gltf(filepath=out_glb, export_format="GLB", export_apply=True, export_yup=True, export_vertex_color="ACTIVE")
print("EXPORTED", out_glb, os.path.getsize(out_glb))

# vista-camera preview (1280 x 720, vertical FOV 60) against a dusk backdrop, for comparison with concept-1
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = L.hexcol("#8a86c0")
world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
sc.view_settings.view_transform = "Standard"
sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
sun.data.energy = 1.6; sun.data.color = (1.0, 0.78, 0.6); sun.rotation_euler = (math.radians(75), 0, math.radians(200))
sc.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.sensor_fit = "VERTICAL"; cam.data.angle_y = math.radians(60.0); cam.data.clip_end = 2000
cam.location = CAM; cam.rotation_euler = (math.radians(90.0) - PITCH, 0, 0)
sc.collection.objects.link(cam); sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.render.film_transparent = True
sc.render.filepath = out_png.replace(".png", "-vista.png")
bpy.ops.render.render(write_still=True)
print("VISTA", sc.render.filepath)
sc.render.film_transparent = False
files = L.sheet_render(out_png, 46.0, center=(MOUND_C.x + 4, MOUND_C.y - 4, 6.0), views=[("hero", (30, -40, 22), None), ("top", (0, 0, 80), (0, 0, 0))])
print("RENDERS", files)
