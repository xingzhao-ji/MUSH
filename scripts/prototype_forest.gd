## Distant forest tree meshes (unit space): base at y = 0, top at y ~1.04-1.08, footprint radius <= 0.62-0.65.
## UV.y = y / top (normalized height). COLOR = baked grey crown AO in 0.35-1.0 (multiplies the instance green).
## Normals: smooth, area-weighted, blended with a whole-crown "envelope" normal so the crown reads as one
## light/dark mass at 10-40 px. Triangles are auto-oriented against a known interior point so the face normal
## (c - a) x (b - a) points outward, i.e. Godot's clockwise-from-outside front face. Deterministic per seed.
## Usage: these are static funcs; paste into any script (no class_name/extends here).


## Conifer: 6-7 stacked, slightly drooping, irregular tiers tapering to a sharp leader; a short visible trunk.
## <= 201 triangles.
static func conifer_mesh(seed: int = 11) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var g: Dictionary = _forest_geo()
	var tiers: int = rng.randi_range(6, 7)
	var segs: int = 7
	var y_lo: float = rng.randf_range(0.11, 0.15) # rim height of the lowest tier
	var y_hi: float = rng.randf_range(0.74, 0.80) # rim height of the top tier
	var apex_y: float = 1.0 # leader tip (pre-normalization)
	var r_lo: float = rng.randf_range(0.50, 0.56)
	var r_hi: float = rng.randf_range(0.14, 0.18)
	var lean := Vector2(rng.randf_range(-0.035, 0.035), rng.randf_range(-0.035, 0.035))
	var spacing: float = (y_hi - y_lo) / float(tiers - 1)
	_forest_trunk(g, 5, 0.055, y_lo + 1.5 * spacing, 0.36)
	for t: int in tiers:
		var f: float = float(t) / float(tiers - 1)
		var yb: float = lerpf(y_lo, y_hi, pow(f, 0.92))
		if t > 0 and t < tiers - 1:
			yb += rng.randf_range(-0.18, 0.18) * spacing
		var rr: float = lerpf(r_lo, r_hi, pow(f, 0.8)) * rng.randf_range(0.9, 1.08)
		var c2: Vector2 = lean * f + Vector2(rng.randf_range(-0.012, 0.012), rng.randf_range(-0.012, 0.012))
		var yt: float = apex_y
		if t < tiers - 1:
			yt = minf(yb + spacing * rng.randf_range(1.5, 1.8), apex_y - 0.08)
		# Underside closes to the trunk BELOW every rim tip, so its normals stay outward-and-down.
		var yu: float = maxf(yb - spacing * 0.5, 0.02)
		var rot: float = rng.randf() * TAU
		var inside := Vector3(c2.x, yb, c2.y)
		var apex: int = _forest_vert(g, Vector3(c2.x, yt, c2.y), 0.62)
		var under: int = _forest_vert(g, Vector3(c2.x, yu, c2.y), 0.42)
		var rim: Array = []
		var mid: Array = []
		for s: int in segs:
			var ang: float = rot + TAU * (float(s) + rng.randf_range(-0.22, 0.22)) / float(segs)
			var tip: float = rr * (1.0 + (0.1 if s % 2 == 0 else -0.07) + rng.randf_range(-0.09, 0.09))
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var yr: float = yb - spacing * rng.randf_range(0.1, 0.24) * (tip / rr) # longer tips droop more
			var hint: Vector3 = (dir * 0.87 + Vector3.UP * 0.5).normalized()
			rim.append(_forest_vert(g, Vector3(c2.x, yr, c2.y) + dir * tip, rng.randf_range(0.9, 1.0), hint, 0.45))
			var ym: float = yt - 0.37 * (yt - yr) # arched: mid ring sits above the apex-rim line (droop)
			mid.append(_forest_vert(g, Vector3(c2.x, ym, c2.y) + dir * (tip * 0.5), 0.8, hint, 0.45))
		_forest_fan(g, apex, mid, inside)
		_forest_band(g, mid, rim, inside)
		_forest_fan(g, under, rim, inside)
	return _forest_finish(g, 1.08, 0.62)


## Broadleaf: an irregular cluster of 5-9 noisy, flat-bottomed sub-crowns spaced unevenly (notches on the
## outline), darker underside and inner crown baked into vertex colour; short trunk under the crown.
## <= 300 triangles (hidden faces culled).
static func broadleaf_mesh(seed: int = 23) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var k: int = rng.randi_range(7, 9)
	var blobs: Array = []
	blobs.append([Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(0.74, 0.8), rng.randf_range(-0.04, 0.04)), rng.randf_range(0.23, 0.27)])
	var n_out: int = k - 1
	var weights: Array = []
	var wsum: float = 0.0
	for j: int in n_out:
		var w: float = rng.randf_range(0.35, 1.65)
		weights.append(w)
		wsum += w
	var ang: float = rng.randf() * TAU
	for j: int in n_out:
		var d: float = rng.randf_range(0.2, 0.36)
		var h: float = rng.randf_range(0.6, 0.76) if j % 2 == 0 else rng.randf_range(0.42, 0.58)
		var r: float = rng.randf_range(0.14, 0.24)
		blobs.append([Vector3(cos(ang) * d, h, sin(ang) * d), r])
		ang += TAU * float(weights[j]) / wsum
	# Hidden faces (inside a neighbouring sub-crown) are culled; drop outer sub-crowns until within budget.
	while true:
		var g: Dictionary = _forest_geo()
		_forest_trunk(g, 5, 0.05, 0.55, 0.36)
		var jitter := RandomNumberGenerator.new()
		jitter.seed = seed * 7919 + 17
		_forest_blob_crown(g, jitter, blobs, 6, 1.0, 0.72, INF, Vector3(0.0, 0.64, 0.0), Vector3(0.52, 0.36, 0.52))
		if (g["i"] as Array).size() / 3 <= 300 or blobs.size() <= 5:
			return _forest_finish(g, 1.06, 0.62)
		blobs.pop_back()
	return null


## Spreading: wide, flat-topped umbrella crown (acacia / old oak) of 5-9 squashed sub-crowns on a short
## trunk with two limbs. <= 300 triangles (hidden faces culled).
static func spreading_mesh(seed: int = 37) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var k: int = rng.randi_range(7, 9)
	var limbs: Array = []
	var la: float = rng.randf() * TAU
	for j: int in 2:
		var a: float = la + PI * float(j) + rng.randf_range(-0.5, 0.5)
		var d: float = rng.randf_range(0.2, 0.28)
		limbs.append([Vector3(0.0, rng.randf_range(0.36, 0.46), 0.0), Vector3(cos(a) * d, 0.74, sin(a) * d)])
	var blobs: Array = []
	blobs.append([Vector3(rng.randf_range(-0.04, 0.04), 0.8, rng.randf_range(-0.04, 0.04)), rng.randf_range(0.27, 0.31)])
	var ang: float = rng.randf() * TAU
	for j: int in k - 1:
		var d: float = rng.randf_range(0.28, 0.42)
		blobs.append([Vector3(cos(ang) * d, rng.randf_range(0.6, 0.72), sin(ang) * d), rng.randf_range(0.17, 0.25)])
		ang += TAU / float(k - 1) * rng.randf_range(0.55, 1.45)
	while true:
		var g: Dictionary = _forest_geo()
		_forest_trunk(g, 5, 0.05, 0.78, 0.36)
		for l: Array in limbs:
			_forest_limb(g, l[0], l[1], 0.03, 4, 0.36)
		var jitter := RandomNumberGenerator.new()
		jitter.seed = seed * 7919 + 29
		_forest_blob_crown(g, jitter, blobs, 6, 0.85, 0.6, 0.9, Vector3(0.0, 0.72, 0.0), Vector3(0.62, 0.28, 0.62))
		if (g["i"] as Array).size() / 3 <= 300 or blobs.size() <= 5:
			return _forest_finish(g, 1.04, 0.65)
		blobs.pop_back()
	return null


# ---------------------------------------------------------------- helpers

static func _forest_geo() -> Dictionary:
	return {"v": [], "a": [], "h": [], "w": [], "i": []}


## Adds a vertex: position, grey AO, optional normal hint direction and blend weight. Returns its index.
static func _forest_vert(g: Dictionary, p: Vector3, ao: float, hint: Vector3 = Vector3.ZERO, hw: float = 0.0) -> int:
	var v: Array = g["v"]
	v.append(p)
	(g["a"] as Array).append(ao)
	(g["h"] as Array).append(hint)
	(g["w"] as Array).append(hw)
	return v.size() - 1


## Adds a triangle oriented so its face normal (c - a) x (b - a) points away from `inside`
## (Godot front face = clockwise seen from outside). `axial`: use the point on the vertical line
## through `inside` at the triangle's centroid height.
static func _forest_tri(g: Dictionary, ia: int, ib: int, ic: int, inside: Vector3, axial: bool = false) -> void:
	var v: Array = g["v"]
	var a: Vector3 = v[ia]
	var b: Vector3 = v[ib]
	var c: Vector3 = v[ic]
	var n: Vector3 = (c - a).cross(b - a)
	var cen: Vector3 = (a + b + c) / 3.0
	var ref: Vector3 = inside
	if axial:
		ref = Vector3(inside.x, cen.y, inside.z)
	var idx: Array = g["i"]
	if n.dot(cen - ref) < 0.0:
		idx.append_array([ia, ic, ib])
	else:
		idx.append_array([ia, ib, ic])


static func _forest_fan(g: Dictionary, hub: int, ring: Array, inside: Vector3, axial: bool = false) -> void:
	var n: int = ring.size()
	for k: int in n:
		_forest_tri(g, hub, ring[k], ring[(k + 1) % n], inside, axial)


static func _forest_band(g: Dictionary, ra: Array, rb: Array, inside: Vector3, axial: bool = false) -> void:
	var n: int = ra.size()
	for k: int in n:
		var k2: int = (k + 1) % n
		_forest_tri(g, ra[k], rb[k], rb[k2], inside, axial)
		_forest_tri(g, ra[k], rb[k2], ra[k2], inside, axial)


## Thin vertical cone from the ground to y_top (its top is buried in the crown). No base cap (underground).
static func _forest_trunk(g: Dictionary, segs: int, r0: float, y_top: float, ao: float) -> void:
	var ring: Array = []
	for s: int in segs:
		var a: float = TAU * float(s) / float(segs)
		var dir := Vector3(cos(a), 0.0, sin(a))
		ring.append(_forest_vert(g, dir * r0, ao, dir, 0.7))
	var top: int = _forest_vert(g, Vector3(0.0, y_top, 0.0), ao)
	_forest_fan(g, top, ring, Vector3.ZERO, true)


## Thin tilted cone (a limb) from `base` (radius r) to `tip`.
static func _forest_limb(g: Dictionary, base: Vector3, tip: Vector3, r: float, segs: int, ao: float) -> void:
	var ax: Vector3 = (tip - base).normalized()
	var u: Vector3 = ax.cross(Vector3.FORWARD if absf(ax.z) < 0.9 else Vector3.RIGHT).normalized()
	var w: Vector3 = ax.cross(u).normalized()
	var ring: Array = []
	for s: int in segs:
		var a: float = TAU * float(s) / float(segs)
		var dir: Vector3 = u * cos(a) + w * sin(a)
		ring.append(_forest_vert(g, base + dir * r, ao, dir, 0.7))
	var it: int = _forest_vert(g, tip, ao)
	var v: Array = g["v"]
	for k: int in segs:
		var ia: int = ring[k]
		var ib: int = ring[(k + 1) % segs]
		var cen: Vector3 = (tip + (v[ia] as Vector3) + (v[ib] as Vector3)) / 3.0
		_forest_tri(g, it, ia, ib, base + ax * (cen - base).dot(ax))


## Low-poly noisy sub-crowns (3 latitude rings x segs + 2 poles = 6*segs triangles each, before culling).
## sq_up/sq_down squash the upper/lower halves; flat_cap compresses anything above that height (flat tops).
## cc/cr: whole-crown ellipsoid (centre, radii) used for the AO depth term and the normal hint.
## Triangles whose three corners all lie inside another sub-crown (with a 10% margin) are culled: never visible.
static func _forest_blob_crown(g: Dictionary, rng: RandomNumberGenerator, blobs: Array, segs: int, sq_up: float, sq_down: float, flat_cap: float, cc: Vector3, cr: Vector3) -> void:
	var lats: Array = [-0.95, -0.15, 0.62]
	var v: Array = g["v"]
	var all_tris: Array = []
	for bi: int in blobs.size():
		var c: Vector3 = blobs[bi][0]
		var r: float = blobs[bi][1]
		var rot: float = rng.randf() * TAU
		var rings: Array = []
		for li: int in lats.size():
			var lat: float = float(lats[li]) + rng.randf_range(-0.12, 0.12)
			var ring: Array = []
			for s: int in segs:
				var lon: float = rot + TAU * (float(s) + 0.5 * float(li % 2)) / float(segs)
				var dir := Vector3(cos(lat) * cos(lon), sin(lat), cos(lat) * sin(lon))
				ring.append(_forest_blob_vert(g, rng, c, r, dir, sq_up, sq_down, flat_cap, cc, cr))
			rings.append(ring)
		var bot: int = _forest_blob_vert(g, rng, c, r, Vector3.DOWN, sq_up, sq_down, flat_cap, cc, cr)
		var top: int = _forest_blob_vert(g, rng, c, r, Vector3.UP, sq_up, sq_down, flat_cap, cc, cr)
		var tris: Array = []
		for k: int in segs:
			var k2: int = (k + 1) % segs
			tris.append([bot, rings[0][k], rings[0][k2]])
			tris.append([top, rings[2][k], rings[2][k2]])
			for li: int in 2:
				tris.append([rings[li][k], rings[li + 1][k], rings[li + 1][k2]])
				tris.append([rings[li][k], rings[li + 1][k2], rings[li][k2]])
		all_tris.append(tris)
	for bi: int in blobs.size():
		var c: Vector3 = blobs[bi][0]
		for t: Array in all_tris[bi]:
			var hidden: bool = false
			for bj: int in blobs.size():
				if bj == bi:
					continue
				if _forest_inside(v[t[0]], v, all_tris[bj], blobs[bj][0]) and _forest_inside(v[t[1]], v, all_tris[bj], blobs[bj][0]) and _forest_inside(v[t[2]], v, all_tris[bj], blobs[bj][0]):
					hidden = true
					break
			if not hidden:
				_forest_tri(g, t[0], t[1], t[2], c)


## True if p is inside the star-shaped blob (triangles `tris`, centre c) with a 10% margin.
static func _forest_inside(p: Vector3, v: Array, tris: Array, c: Vector3) -> bool:
	var d: Vector3 = p - c
	var dist: float = d.length()
	if dist < 1e-6:
		return true
	var dir: Vector3 = d / dist
	for t: Array in tris:
		var hit: Variant = Geometry3D.ray_intersects_triangle(c, dir, v[t[0]], v[t[1]], v[t[2]])
		if hit != null:
			return dist < 0.9 * ((hit as Vector3) - c).length()
	return false


static func _forest_blob_vert(g: Dictionary, rng: RandomNumberGenerator, c: Vector3, r: float, dir: Vector3, sq_up: float, sq_down: float, flat_cap: float, cc: Vector3, cr: Vector3) -> int:
	var off: Vector3 = dir * (r * rng.randf_range(0.78, 1.22))
	off.y *= sq_up if off.y > 0.0 else sq_down
	var p: Vector3 = c + off
	if p.y > flat_cap:
		p.y = flat_cap + (p.y - flat_cap) * 0.3
	var q: Vector3 = (p - cc) / cr
	var outer: float = clampf((q.length() - 0.35) / 0.7, 0.0, 1.0)
	var ao: float = clampf((0.62 + 0.38 * (dir.y * 0.5 + 0.5)) * (0.5 + 0.5 * outer), 0.36, 1.0)
	var hint: Vector3 = Vector3(q.x / cr.x, q.y / cr.y, q.z / cr.z).normalized()
	return _forest_vert(g, p, ao, hint, 0.72)


## Normalizes to unit space (base y = 0, top = `top`, radius <= rcap), builds smooth normals, UV, COLOR.
static func _forest_finish(g: Dictionary, top: float, rcap: float) -> ArrayMesh:
	# Compact: drop vertices no triangle references (left over by culling).
	var src_i: Array = g["i"]
	var remap := PackedInt32Array()
	remap.resize((g["v"] as Array).size())
	remap.fill(-1)
	var src: Array = []
	var hints: Array = []
	var hw: Array = []
	var aos: Array = []
	var idx := PackedInt32Array()
	for o: int in src_i:
		if remap[o] < 0:
			remap[o] = src.size()
			src.append(g["v"][o])
			hints.append(g["h"][o])
			hw.append(g["w"][o])
			aos.append(g["a"][o])
		idx.append(remap[o])
	var n: int = src.size()
	var ymin: float = INF
	var ymax: float = -INF
	var rmax: float = 0.0
	for p: Vector3 in src:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
		rmax = maxf(rmax, Vector2(p.x, p.z).length())
	var sy: float = top / (ymax - ymin)
	var sxz: float = minf(1.0, rcap / rmax)
	var verts := PackedVector3Array()
	verts.resize(n)
	for k: int in n:
		var p: Vector3 = src[k]
		verts[k] = Vector3(p.x * sxz, (p.y - ymin) * sy, p.z * sxz)
	var acc := PackedVector3Array()
	acc.resize(n)
	for t: int in range(0, idx.size(), 3):
		var a: Vector3 = verts[idx[t]]
		var b: Vector3 = verts[idx[t + 1]]
		var c: Vector3 = verts[idx[t + 2]]
		var fn: Vector3 = (c - a).cross(b - a) # outward (clockwise front face), area-weighted
		acc[idx[t]] += fn
		acc[idx[t + 1]] += fn
		acc[idx[t + 2]] += fn
	var normals := PackedVector3Array()
	normals.resize(n)
	var colors := PackedColorArray()
	colors.resize(n)
	var uvs := PackedVector2Array()
	uvs.resize(n)
	for k: int in n:
		var geo: Vector3 = acc[k].normalized()
		var h: Vector3 = hints[k]
		var w: float = hw[k]
		var nn: Vector3 = geo
		if w > 0.0 and h.length_squared() > 0.0:
			var hs: Vector3 = Vector3(h.x / sxz, h.y / sy, h.z / sxz).normalized() # inverse-transpose of the scale
			nn = (geo * (1.0 - w) + hs * w).normalized()
			if nn.length_squared() < 0.25:
				nn = geo
		normals[k] = nn
		var ao: float = clampf(aos[k], 0.36, 1.0) # >= 0.35 after 8-bit vertex colour storage
		colors[k] = Color(ao, ao, ao, 1.0)
		var p: Vector3 = verts[k]
		uvs[k] = Vector2(atan2(p.z, p.x) / TAU + 0.5, clampf(p.y / top, 0.0, 1.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
