"""Mushroom cottage V2 from ChatGPT sheet mush-sheet-cottage-02 (v2, capture pr62: the roof read saturated purple
with the spots lost and grey walls: browner mauve, raised larger spots, warmer plaster) (after review: V1 read as a tall round yurt under a
huge purple dome; the goal's is a wide, low timber cottage under a smaller lumpy dusky-mauve cap with pale spots,
a mushroom chimney cap, a canvas awning on a timber frame with a hanging lantern, a wraparound plank deck with
railings, lantern posts at the deck corners, a round window, an arched door and stone steps).
About 11 m wide (deck), 7 m deep, 7.5 m to the roof top. Front faces -Y (glTF +Z); right is +X.
Usage: blender -b -P cottage2.py -- <out.glb> <render_prefix.png>"""
import bpy, bmesh, sys, math, random, os
sys.path.insert(0, os.path.dirname(__file__))
import mushlib as L
from mathutils import Vector, noise

out_glb, out_png = sys.argv[sys.argv.index("--") + 1:][:2]
L.reset()
rnd = random.Random(11)

M = {
    "cap": L.mat("cap", "#ae8890", 0.75),
    "cap_under": L.mat("cap_under", "#5e5062", 0.85),
    "spot": L.mat("spot", "#f2dcd8", 0.8),
    "plaster": L.mat("plaster", "#d9b98a", 0.9),
    "wood": L.mat("timber", "#9a6236", 0.8),
    "wood_dark": L.mat("timber_dark", "#6a4024", 0.85),
    "deck": L.mat("deck", "#a46b3c", 0.85),
    "glass": L.mat("glass", "#fcbe67", 0.3, "#ffb040", 4.0),
    "canvas": L.mat("canvas", "#eadfc6", 0.9),
    "stone": L.mat("stone", "#a59d93", 0.9),
    "stone_dark": L.mat("stone_dark", "#7d756e", 0.9),
    "moss": L.mat("moss", "#7a9140", 0.95),
    "leaf": L.mat("leaf", "#5b7c34", 0.85),
    "leaf2": L.mat("leaf_light", "#7a9a3c", 0.85),
    "metal": L.mat("metal", "#3a3230", 0.5),
}

DECK_Z = 0.6
WALL_TOP = 4.2
# house footprint: a rounded rectangle (superellipse), centre (0.1, 0.1)
HX, HY, HC = 3.5, 2.5, (0.1, 0.1)
def house_pt(th, grow=0.0):
    c, s = math.cos(th), math.sin(th)
    ex = abs(c) ** 0.45 * (1 if c >= 0 else -1)
    ey = abs(s) ** 0.45 * (1 if s >= 0 else -1)
    return (HC[0] + (HX + grow) * ex, HC[1] + (HY + grow) * ey)

# ---- walls -------------------------------------------------------------------------------------------------
N = 64
verts, faces = [], []
zs = [DECK_Z, DECK_Z + 1.0, 2.6, 3.6, WALL_TOP]
for zi, z in enumerate(zs):
    bulge = 0.06 * math.sin(math.pi * zi / (len(zs) - 1))
    for i in range(N):
        x, y = house_pt(2 * math.pi * i / N, bulge)
        verts.append((x, y, z))
for zi in range(len(zs) - 1):
    for i in range(N):
        i2 = (i + 1) % N
        faces.append((zi * N + i, zi * N + i2, (zi + 1) * N + i2, (zi + 1) * N + i))
L.obj_from("walls", verts, faces, M["plaster"])
# timber frame: corner and door posts, a sill and a top beam all round
for k in range(16):
    th = 2 * math.pi * k / 16
    x, y = house_pt(th, 0.08)
    L.box("wpost%d" % k, (0.22, 0.22, WALL_TOP - DECK_Z), (x, y, (WALL_TOP + DECK_Z) / 2), M["wood"], rot=(0, 0, th), bevel=0.03)
for z, h in ((WALL_TOP - 0.12, 0.26), (DECK_Z + 0.1, 0.2)):
    verts, faces = [], []
    for i in range(N):
        x0, y0 = house_pt(2 * math.pi * i / N, 0.04); x1, y1 = house_pt(2 * math.pi * i / N, 0.16)
        verts += [(x0, y0, z - h / 2), (x1, y1, z - h / 2), (x1, y1, z + h / 2), (x0, y0, z + h / 2)]
    for i in range(N):
        a, b = i * 4, ((i + 1) % N) * 4
        for q in range(4):
            faces.append((a + q, b + q, b + (q + 1) % 4, a + (q + 1) % 4))
    L.obj_from("beam%d" % int(z * 10), verts, faces, M["wood"], smooth=False)
# diagonal braces on the front wall
for x0, x1 in ((-3.0, -2.2), (2.3, 3.1)):
    L.box("brace%d" % int(x0), (0.14, 0.12, 1.6), ((x0 + x1) / 2, -HY + HC[1] - 0.08, 3.2), M["wood"], rot=(0, math.radians(35 if x0 < 0 else -35), 0))

FRONT_Y = -HY + HC[1] - 0.02
# ---- door --------------------------------------------------------------------------------------------------
def arch_pts(w, h, n=16):
    r = w / 2
    return [(-r, 0.0)] + [(-r * math.cos(math.pi * i / n), h - r + r * math.sin(math.pi * i / n)) for i in range(n + 1)] + [(r, 0.0)]
DOOR_X = 0.9
dp = arch_pts(1.4, 2.4)
L.extrude_outline("door", [(x + DOOR_X, z + DECK_Z) for x, z in dp], 0.12, FRONT_Y + 0.02, M["wood"])
fo = arch_pts(1.9, 2.75)
L.extrude_outline("door_frame", [(x + DOOR_X, z + DECK_Z) for x, z in fo], 0.08, FRONT_Y + 0.08, M["wood_dark"])
for k, x in enumerate((-0.35, 0.0, 0.35)):
    L.box("door_groove%d" % k, (0.03, 0.02, 1.9), (DOOR_X + x, FRONT_Y - 0.11, DECK_Z + 1.0), M["wood_dark"])
for z in (1.0, 2.0):
    L.box("strap%d" % int(z), (0.55, 0.03, 0.08), (DOOR_X - 0.35, FRONT_Y - 0.12, DECK_Z + z), M["metal"])
# arched timber hood over the door
L.lathe("door_hood", [(1.0, 0.0), (1.12, 0.0)], 24, M["wood"], arc=(0.0, math.pi),
        deform=lambda x, y, z, th, i: (x + DOOR_X, FRONT_Y - 0.25 + z * 0, DECK_Z + 1.95 + y))

# ---- round window, side windows ----------------------------------------------------------------------------
def round_window(name, at, normal_rot, r=0.6):
    L.cyl(name, r, 0.06, at, M["glass"], rot=normal_rot, verts=28)
    L.torus(name + "_frame", r + 0.06, 0.09, at, normal_rot, M["wood"], 32, 8)
    L.box(name + "_bv", (0.06, 0.06, 2 * r), at, M["wood_dark"], rot=(0, 0, normal_rot[2]))
    L.box(name + "_bh", (2 * r, 0.06, 0.06), at, M["wood_dark"], rot=(0, 0, normal_rot[2]))
round_window("win_round", (-1.5, FRONT_Y - 0.06, 2.45), (math.radians(90), 0, 0))
for k, y in enumerate((-0.9, 1.1)):
    x = HX + HC[0] - 0.02
    L.box("win_side%d" % k, (0.06, 0.8, 0.8), (x + 0.04, y, 2.4), M["glass"])
    for dz in (-0.45, 0.45):
        L.box("win_side_f%d_%d" % (k, int(dz * 10)), (0.12, 1.0, 0.12), (x + 0.08, y, 2.4 + dz), M["wood"])
    for dy in (-0.45, 0.45):
        L.box("win_side_g%d_%d" % (k, int(dy * 10)), (0.12, 0.12, 1.0), (x + 0.08, y + dy, 2.4), M["wood"])
    L.box("win_side_bar%d" % k, (0.1, 0.05, 0.8), (x + 0.1, y, 2.4), M["wood_dark"])

# ---- roof: a lumpy, wide mushroom cap ------------------------------------------------------------------------
RX, RY = 4.7, 4.0          # rim half-extents (1.1 m overhang)
RIM_Z, TOP_Z = 3.85, 7.0
NA, NS = 96, 14
verts, faces = [], []
def roof_xyz(i, j):
    th = 2 * math.pi * i / NA
    s = j / (NS - 1)
    c, sn = math.cos(th), math.sin(th)
    ex = abs(c) ** 0.7 * (1 if c >= 0 else -1)
    ey = abs(sn) ** 0.7 * (1 if sn >= 0 else -1)
    lobe = 1.0 + 0.05 * math.cos(5 * th + 0.7) + 0.03 * math.cos(9 * th)
    x = HC[0] + RX * ex * s * lobe
    y = HC[1] + RY * ey * s * lobe
    # v3 (capture pr63: seen from below the flat dome showed only its rim, spots lost): a steeper crown, so
    # its spotted slope faces a camera below the promontory
    z = RIM_Z + (TOP_Z - RIM_Z) * (1 - s ** 1.6) ** 0.9
    # drooping lumpy rim lobes; the front-left leans lower like the sheet
    z -= 0.35 * s ** 6 * (0.5 + 0.5 * math.cos(5 * th + 0.7)) + 0.25 * s ** 4 * (0.5 + 0.5 * math.cos(th - math.radians(-135)))
    z += 0.18 * noise.noise(Vector((x * 0.6, y * 0.6, 1.3))) * s
    return (x, y, z)
for i in range(NA):
    for j in range(NS):
        verts.append(roof_xyz(i, j))
for i in range(NA):
    i2 = (i + 1) % NA
    for j in range(NS - 1):
        faces.append((i * NS + j, i2 * NS + j, i2 * NS + j + 1, i * NS + j + 1))
roof = L.obj_from("roof", verts, faces, M["cap"])
sol = roof.modifiers.new("solid", "SOLIDIFY"); sol.thickness = 0.28; sol.offset = 1.0
# underside shadow disc
verts, faces = [(HC[0], HC[1], RIM_Z + 0.05)], []
for i in range(NA):
    x, y, z = roof_xyz(i, NS - 2)
    verts.append((x, y, z - 0.22))
for i in range(NA):
    faces.append((0, 1 + (i + 1) % NA, 1 + i))
L.obj_from("roof_under", verts, faces, M["cap_under"])
# pale spots on the cap
for k in range(34):
    th = rnd.uniform(0, 2 * math.pi); s = math.sqrt(rnd.uniform(0.15, 0.85)); sz = rnd.uniform(0.35, 0.7) * (1.2 if s < 0.5 else 1.0)
    i = int(th / (2 * math.pi) * NA) % NA; j = min(NS - 2, int(s * (NS - 1)))
    p = Vector(roof_xyz(i, j))
    # the roof faces point down, so its solidify thickness grows inward and the top surface stays at roof_xyz
    L.blob("spot%d" % k, sz, (p.x, p.y, p.z + 0.07), M["spot"], squash=(1.0, 0.85, 0.14), sub=2, seed=40 + k, jitter=0.05)

# ---- chimney with a mushroom cap ---------------------------------------------------------------------------
CH = (2.1, 1.3)
for row in range(9):
    for col in range(2):
        z = 4.6 + row * 0.34
        off = 0.17 if row % 2 else 0.0
        L.box("chim%d_%d" % (row, col), (0.4, 0.75, 0.32), (CH[0] - 0.2 + col * 0.4 + off * 0.3, CH[1], z),
              M["stone"] if (row + col) % 2 else M["stone_dark"], bevel=0.04)
L.lathe("chim_cap", [(0.0, 7.55), (0.85, 7.55), (0.92, 7.68), (0.8, 7.95), (0.5, 8.18), (0.0, 8.26)], 28, M["cap"], close_top=True, close_bottom=True,
        deform=lambda x, y, z, th, i: (x + CH[0], y + CH[1], z))
L.lathe("chim_stalk", [(0.3, 7.3), (0.28, 7.56)], 16, M["plaster"], deform=lambda x, y, z, th, i: (x + CH[0], y + CH[1], z))

# ---- deck --------------------------------------------------------------------------------------------------
DX0, DX1, DY0, DY1 = -5.1, 4.7, -3.4, 2.9
n_planks = 22
for i in range(n_planks):
    y0 = DY0 + (DY1 - DY0) * i / n_planks + 0.02
    y1 = DY0 + (DY1 - DY0) * (i + 1) / n_planks - 0.02
    L.box("plank%d" % i, (DX1 - DX0 + rnd.uniform(-0.1, 0.1), y1 - y0, 0.14), ((DX0 + DX1) / 2 + rnd.uniform(-0.05, 0.05), (y0 + y1) / 2, DECK_Z - 0.07 + rnd.uniform(-0.01, 0.01)), M["deck"])
for (cx, cy, sx, sy) in (((DX0 + DX1) / 2, DY0, DX1 - DX0, 0.14), ((DX0 + DX1) / 2, DY1, DX1 - DX0, 0.14), (DX0, (DY0 + DY1) / 2, 0.14, DY1 - DY0), (DX1, (DY0 + DY1) / 2, 0.14, DY1 - DY0)):
    L.box("fascia%d" % int(cx * 10 + cy), (sx, sy, DECK_Z - 0.05), (cx, cy, (DECK_Z - 0.05) / 2), M["wood_dark"])
# rails: front (gap for the steps at the door), both sides
def rail(name, a, b):
    a, b = Vector(a), Vector(b)
    d = b - a; ln = d.length; ang = math.atan2(d.y, d.x)
    n = max(2, int(ln / 1.4) + 1)
    for k in range(n):
        p = a.lerp(b, k / (n - 1))
        L.box("%s_post%d" % (name, k), (0.18, 0.18, 1.25), (p.x, p.y, DECK_Z + 0.6), M["wood"], bevel=0.03)
    for z in (DECK_Z + 0.45, DECK_Z + 1.0):
        L.box("%s_rail%d" % (name, int(z * 10)), (ln, 0.1, 0.12), ((a.x + b.x) / 2, (a.y + b.y) / 2, z), M["wood"], rot=(0, 0, ang))
rail("rf_l", (DX0 + 0.1, DY0 + 0.05), (DOOR_X - 1.4, DY0 + 0.05))
rail("rf_r", (DOOR_X + 1.4, DY0 + 0.05), (DX1 - 0.1, DY0 + 0.05))
rail("rs_l", (DX0 + 0.05, DY0 + 0.1), (DX0 + 0.05, DY1 - 0.1))
rail("rs_r", (DX1 - 0.05, DY0 + 0.1), (DX1 - 0.05, DY1 - 0.4))
# stone steps down from the deck gap
for k, (dy, top, w) in enumerate([(-0.55, 0.42, 2.1), (-1.25, 0.22, 2.3), (-2.0, 0.08, 1.8)]):
    c = (DOOR_X + rnd.uniform(-0.15, 0.15), DY0 + dy, top / 2)
    L.blob("step%d" % k, 1.0, c, M["stone"], squash=(w / 2, 0.45, max(top, 0.12) / 2 + 0.05), sub=2, seed=60 + k, jitter=0.08)

# ---- lanterns ------------------------------------------------------------------------------------------------
def lantern(name, p):
    p = Vector(p)
    L.box(name + "_glass", (0.26, 0.26, 0.36), tuple(p), M["glass"])
    for sx in (-1, 1):
        for sy in (-1, 1):
            L.box(name + "_rod%d%d" % (sx, sy), (0.04, 0.04, 0.44), (p.x + sx * 0.14, p.y + sy * 0.14, p.z), M["metal"])
    L.box(name + "_base", (0.36, 0.36, 0.06), (p.x, p.y, p.z - 0.22), M["metal"])
    L.lathe(name + "_roof", [(0.0, 0.0), (0.26, 0.0), (0.0, 0.2)], 4, M["metal"], close_bottom=True,
            deform=lambda x, y, z, th, i: (x + p.x, y + p.y, z + p.z + 0.2), smooth=False)
# awning frame on the left: a post at the deck's front-left and one at the back, a beam to the house, the canvas
# v3 (capture pr64: the canvas hid under the roof rim): the frame stands 1 m beyond the deck, the canvas lower
AW_X = DX0 - 1.1
for k, y in enumerate((DY0 + 0.2, DY1 - 0.6)):
    L.box("aw_post%d" % k, (0.26, 0.26, DECK_Z + 3.6), (AW_X, y, (DECK_Z + 3.6) / 2), M["wood"], bevel=0.04)
    L.box("aw_beam%d" % k, (3.0, 0.22, 0.22), (AW_X + 1.35, y, DECK_Z + 3.3), M["wood"], bevel=0.03)
    L.box("aw_knee%d" % k, (0.12, 0.12, 0.9), (AW_X + 0.35, y, DECK_Z + 2.95), M["wood"], rot=(0, math.radians(-45), 0))
L.box("aw_cross", (0.22, DY1 - DY0 - 0.8, 0.22), (AW_X, (DY0 + DY1) / 2 - 0.2, DECK_Z + 3.45), M["wood"])
# canvas: from the house wall (high) to the frame (lower), sagging between, a ragged front hem
cv_verts, cv_faces = [], []
NU, NV = 12, 8
x_wall = HC[0] - HX + 0.25
for u in range(NU):
    for v in range(NV):
        tu, tv = u / (NU - 1), v / (NV - 1)
        x = AW_X + (x_wall - AW_X) * tu
        y = DY0 + 0.25 + (DY1 - 0.7 - DY0 - 0.25) * tv
        z = DECK_Z + 3.0 + 0.5 * tu - 0.3 * math.sin(math.pi * tu) * (0.6 + 0.4 * math.sin(math.pi * tv))
        if v == 0: z -= 0.12 * (1 + math.sin(7 * tu))
        cv_verts.append((x, y, z))
for u in range(NU - 1):
    for v in range(NV - 1):
        cv_faces.append((u * NV + v, (u + 1) * NV + v, (u + 1) * NV + v + 1, u * NV + v + 1))
cv = L.obj_from("canvas", cv_verts, cv_faces, M["canvas"])
s2 = cv.modifiers.new("solid", "SOLIDIFY"); s2.thickness = 0.04
L.box("aw_arm", (0.7, 0.06, 0.06), (AW_X - 0.3, DY0 + 0.2, DECK_Z + 2.9), M["metal"])
lantern("lant_aw", (AW_X - 0.6, DY0 + 0.2, DECK_Z + 2.55))
# lantern post at the front-right deck corner
LP = (DX1 + 0.05, DY0 + 0.1)
L.box("lp_base", (0.4, 0.4, 0.5), (LP[0], LP[1], DECK_Z + 0.25), M["stone"], bevel=0.05)
L.box("lp_post", (0.22, 0.22, 3.0), (LP[0], LP[1], DECK_Z + 2.0), M["wood"], bevel=0.03)
L.box("lp_arm", (0.8, 0.12, 0.12), (LP[0] - 0.35, LP[1], DECK_Z + 3.35), M["wood"])
L.box("lp_knee", (0.1, 0.1, 0.6), (LP[0] - 0.18, LP[1], DECK_Z + 3.1), M["wood"], rot=(0, math.radians(45), 0))
lantern("lant_post", (LP[0] - 0.65, LP[1], DECK_Z + 2.95))
# a lantern beside the door
L.box("door_lamp_arm", (0.05, 0.4, 0.05), (DOOR_X + 1.15, FRONT_Y - 0.2, DECK_Z + 2.4), M["metal"])
lantern("lant_door", (DOOR_X + 1.15, FRONT_Y - 0.4, DECK_Z + 2.15))

# ---- greenery ----------------------------------------------------------------------------------------------
k = 0
for _ in range(46):
    side = rnd.random()
    if side < 0.45: p = (rnd.uniform(DX0, DX1), DY0 - rnd.uniform(0.2, 0.7))
    elif side < 0.7: p = (DX0 - rnd.uniform(0.2, 0.6), rnd.uniform(DY0, DY1))
    elif side < 0.9: p = (DX1 + rnd.uniform(0.2, 0.6), rnd.uniform(DY0, DY1))
    else: p = (rnd.uniform(DX0, DX1), DY1 + rnd.uniform(0.2, 0.6))
    if abs(p[0] - DOOR_X) < 1.3 and p[1] < DY0: continue
    L.blob("bush%d" % k, rnd.uniform(0.3, 0.6), (p[0], p[1], rnd.uniform(0.15, 0.35)), M["leaf"] if rnd.random() < 0.65 else M["leaf2"], squash=(1.2, 1.2, 0.8), seed=100 + k)
    k += 1
# ivy up the right wall and the awning post
for j in range(9):
    L.blob("ivy%d" % j, 0.22, (HX + HC[0] + 0.12, rnd.uniform(-1.5, 2.2), DECK_Z + 0.4 + j * 0.38), M["leaf"], squash=(0.6, 1.2, 1.1), seed=200 + j)
for j in range(5):
    L.blob("ivy_aw%d" % j, 0.18, (AW_X + 0.1, DY0 + 0.25, DECK_Z + 0.4 + j * 0.5), M["leaf2"], squash=(1, 0.8, 1.2), seed=220 + j)
# flower pots on the deck
for j, x in enumerate((-3.6, -2.6)):
    L.lathe("pot%d" % j, [(0.0, 0.0), (0.22, 0.0), (0.3, 0.4), (0.0, 0.4)], 12, M["wood_dark"], close_top=True,
            deform=lambda xx, yy, zz, th, i, x=x: (xx + x, yy + DY0 + 0.5, zz + DECK_Z))
    L.blob("potleaf%d" % j, 0.32, (x, DY0 + 0.5, DECK_Z + 0.6), M["leaf2"], squash=(1, 1, 0.8), seed=240 + j)

print("TRIS_BEFORE_JOIN", L.tri_count())
names = list(L.join_by_material())
print("MATERIAL_OBJECTS", names)
print("TRIS", L.tri_count())
L.export_glb(out_glb)
print("EXPORTED", out_glb, os.path.getsize(out_glb))
files = L.sheet_render(out_png, 14.0, center=(0, 0, 3.6),
                       views=[("front", (0, -60, 0), (90, 0, 0)), ("right", (60, 0, 0), (90, 0, 90)), ("top", (0, 0, 60), (0, 0, 0)),
                              ("hero", (-26, -34, 16), None), ("back", (0, 60, 0), (90, 0, 180))])
print("RENDERS", files)
