## Glacial erratics for the prototype meadows: angular granite blocks, not lathe gumdrops.
## A subdivided icosphere is projected radially onto a seeded set of cutting planes (a convex,
## faceted block with a flat-ish top and a buried flat base), lightly weathered, flat-shaded.
## Unit space: about 1 m radius, base near y = -0.4; scale and bury per instance.
static func erratic_mesh(seed: int, subdivisions: int = 2) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = []
	for v: Vector3 in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		verts.append(v.normalized())
	var faces: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for s: int in subdivisions:
		var mids: Dictionary = {}
		var next: Array = []
		for f: Array in faces:
			var ab: int = _erratic_mid(verts, mids, f[0], f[1])
			var bc: int = _erratic_mid(verts, mids, f[1], f[2])
			var ca: int = _erratic_mid(verts, mids, f[2], f[0])
			next.append([f[0], ab, ca]); next.append([f[1], bc, ab]); next.append([f[2], ca, bc]); next.append([ab, bc, ca])
		faces = next
	# Cutting planes: a tilted top, a buried base, and 6-8 side joints of uneven depth.
	var normals: Array[Vector3] = [Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)).normalized(), Vector3.DOWN]
	var depths: Array[float] = [rng.randf_range(0.5, 0.72), 0.4]
	var sides: int = rng.randi_range(6, 8)
	var turn: float = rng.randf_range(0.0, TAU)
	for k: int in sides:
		var a: float = turn + TAU * float(k) / float(sides) + rng.randf_range(-0.35, 0.35)
		normals.append(Vector3(cos(a), rng.randf_range(-0.35, 0.55), sin(a)).normalized())
		depths.append(rng.randf_range(0.62, 0.9))
	var noise := FastNoiseLite.new()
	noise.seed = seed + 17
	noise.frequency = 1.6
	for i: int in verts.size():
		var p: Vector3 = verts[i]
		var scale: float = 1.0
		for k: int in normals.size():
			var facing: float = normals[k].dot(p)
			if facing > 0.0001: scale = minf(scale, depths[k] / facing)
		p *= scale * (1.0 + 0.035 * noise.get_noise_3dv(p * 2.0))
		verts[i] = p
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Smooth normals: sub-rounded, weathered edges (flat facets read as low-poly props, sweep 185540).
	for f: Array in faces:
		var a: Vector3 = verts[f[0]]
		var b: Vector3 = verts[f[1]]
		var c: Vector3 = verts[f[2]]
		# Godot front faces wind clockwise seen from outside: cross(b - a, c - a) points inward.
		if (b - a).cross(c - a).dot(a + b + c) > 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
		st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
	st.generate_normals()
	return st.commit()

static func _erratic_mid(verts: Array[Vector3], mids: Dictionary, i: int, j: int) -> int:
	var key := Vector2i(mini(i, j), maxi(i, j))
	if mids.has(key): return mids[key]
	verts.append((verts[i] + verts[j]).normalized())
	mids[key] = verts.size() - 1
	return verts.size() - 1
