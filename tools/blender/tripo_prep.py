"""Prepare a Tripo Studio image-to-3D export for Godot: join the parts, decimate to a triangle budget (UVs and
textures kept), put the origin at the base centre, scale to a target height in metres, and export a glb with its
textures plus a turntable preview.
Usage: blender -b -P tripo_prep.py -- <in.glb> <out.glb> <target_tris> <height_m> [preview.png]"""
import bpy, sys, os, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, dst, target, height = args[0], args[1], int(args[2]), float(args[3])
preview = args[4] if len(args) > 4 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in bpy.context.scene.objects: o.select_set(False)
for o in meshes: o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1: bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
# unparent and apply the import's axis transform
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# TRIPO_PRUNE=1: drop small loose pieces in the bottom 30% of the model (background patches the input cut-out filled
# between roots come back as stray blobs), keeping thin drips and leaves higher up
if os.environ.get("TRIPO_PRUNE"):
    zs = [v.co.z for v in ob.data.vertices]
    z0, z1, total = min(zs), max(zs), len(zs)
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.separate(type="LOOSE"); bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    dropped = 0
    for o in parts:
        n = len(o.data.vertices)
        top = max(v.co.z for v in o.data.vertices)
        if n < 0.01 * total and (top - z0) < 0.3 * (z1 - z0):
            bpy.data.objects.remove(o, do_unlink=True); dropped += 1
    keep = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in bpy.context.scene.objects: o.select_set(False)
    for o in keep: o.select_set(True)
    bpy.context.view_layer.objects.active = keep[0]
    if len(keep) > 1: bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    print("TRIPO_PRUNE parts", len(parts), "dropped", dropped)
tris0 = sum(len(p.vertices) - 2 for p in ob.data.polygons)
if tris0 > target:
    md = ob.modifiers.new("dec", "DECIMATE")
    md.decimate_type = "COLLAPSE"
    md.ratio = target / tris0
    md.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=md.name)
tris1 = sum(len(p.vertices) - 2 for p in ob.data.polygons)
# origin at the base centre, height in metres
co = [ob.matrix_world @ v.co for v in ob.data.vertices]
mn = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
mx = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
k = height / max(mx.z - mn.z, 1e-6)
centre = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
for v in ob.data.vertices:
    v.co = (v.co - centre) * k
ob.data.update()
for o in list(bpy.context.scene.objects):
    if o is not ob: bpy.data.objects.remove(o, do_unlink=True)
size = (mx - mn) * k
print("TRIPO_PREP", os.path.basename(src), "tris", tris0, "->", tris1, "size_m", [round(s, 1) for s in size], "materials", [m.name for m in ob.data.materials])
bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB", export_apply=True, export_yup=True, export_image_format="JPEG", export_jpeg_quality=88)
print("EXPORTED", dst, os.path.getsize(dst))
if preview:
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    w = bpy.data.worlds.new("w"); sc.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.7, 0.7, 0.72, 1)
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30)); sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = 50; cam.data.clip_end = 100000
    r = max(size.x, size.y, size.z) * 1.6
    sc.render.resolution_x, sc.render.resolution_y = 768, 768
    files = []
    for i, ang in enumerate((0, 90, 180, 270)):
        a = math.radians(ang - 90)
        cam.location = Vector((math.cos(a) * r, math.sin(a) * r, size.z * 0.55))
        d = Vector((0, 0, size.z * 0.45)) - cam.location
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        f = preview.replace(".png", "-%d.png" % ang)
        sc.render.filepath = f
        bpy.ops.render.render(write_still=True)
        files.append(f)
    print("PREVIEWS", files)
