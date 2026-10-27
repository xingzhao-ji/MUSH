## Ridged glacial horn for the prototype's ice peak (replaces the 48-segment lathe cone, which read
## as a smooth white cone). Unit space: summit y = 1.0, buried skirt y <= 0, footprint radius 1.12.
## Built once at startup by prototype_scenery.gd; never per frame. Proven headless: 34,416
## triangles, all finite, every normal up, 4 aretes + spurs (see reports for the proof JSON).

## Returns a unit-space alpine horn: apex (summit) y = 1.0, base skirt y <= 0.0, footprint radius <= 1.2.
## Outward-facing triangles; smooth normals generated; finite vertices.
## Heightfield over a square grid (resolution cells across [-1.2, 1.2]), cropped to a disc of radius 1.12.
## Macro shape: polar "reach" field around an off-centre summit. Four unequal, curving aretes plus five
## spurs are angular cusps in the reach; between them the reach collapses into concave cirque faces that
## end on raised, snow-catching cirque floors. Detail: multi-octave ridged FastNoiseLite (1 - |n|) erosion
## plus ridged polar noise carving radial couloirs into the faces. Deterministic for a given seed.
static func ridged_horn_mesh(seed: int = 4207, resolution: int = 160) -> ArrayMesh:
	var n: int = clampi(resolution, 16, 400)
	var row: int = n + 1
	var half: float = 1.2
	var keep_r: float = 1.12
	var step: float = 2.0 * half / float(n)
	var sx: float = 0.06 # summit offset (x)
	var sz: float = -0.05 # summit offset (z)
	var r0: float = 0.6 # cirque reach (how far the faces between aretes extend)
	var prof_p: float = 0.85 # radial profile exponent (< 1 = concave, steep headwalls)
	var tip: float = 0.035 # summit rounding radius

	# Main aretes: base angle (rad, atan2(z, x) about the summit), extra reach, angular half-width,
	# curvature (rad per unit r), wiggle amplitude, wiggle frequency, wiggle phase.
	var a_ang := PackedFloat32Array([0.35, 1.95, 3.70, 5.00])
	var a_amp := PackedFloat32Array([0.50, 0.34, 0.55, 0.30])
	var a_wid := PackedFloat32Array([0.34, 0.28, 0.38, 0.26])
	var a_crv := PackedFloat32Array([0.35, -0.45, 0.25, -0.30])
	var a_wig := PackedFloat32Array([0.10, 0.12, 0.08, 0.14])
	var a_wfq := PackedFloat32Array([6.0, 7.5, 5.0, 8.5])
	var a_wph := PackedFloat32Array([0.0, 1.7, 3.1, 4.4])
	# Spurs: parent arete, branch radius, divergence (rad per unit r past the branch), reach, half-width.
	var s_par := PackedInt32Array([0, 2, 2, 1, 3])
	var s_rb := PackedFloat32Array([0.38, 0.30, 0.55, 0.25, 0.32])
	var s_div := PackedFloat32Array([1.1, -1.3, 1.0, 1.4, -1.2])
	var s_amp := PackedFloat32Array([0.30, 0.36, 0.28, 0.22, 0.20])
	var s_wid := PackedFloat32Array([0.20, 0.22, 0.18, 0.20, 0.18])

	var erosion := FastNoiseLite.new()
	erosion.seed = seed
	erosion.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	erosion.frequency = 3.2
	erosion.fractal_type = FastNoiseLite.FRACTAL_RIDGED # per octave: 1 - 2|n|
	erosion.fractal_octaves = 4
	erosion.fractal_lacunarity = 2.17
	erosion.fractal_gain = 0.5
	var gully := FastNoiseLite.new()
	gully.seed = seed + 101
	gully.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	gully.frequency = 1.0
	gully.fractal_type = FastNoiseLite.FRACTAL_NONE

	var total: int = row * row
	var remap := PackedInt32Array()
	remap.resize(total)
	remap.fill(-1)
	var verts := PackedVector3Array()
	var hts := PackedFloat32Array()
	hts.resize(total)
	var p_ang := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var h_max: float = -INF
	var count: int = 0

	for j: int in row:
		var z: float = -half + step * float(j)
		for i: int in row:
			var x: float = -half + step * float(i)
			var rho: float = sqrt(x * x + z * z)
			if rho > keep_r:
				continue
			var dx: float = x - sx
			var dz: float = z - sz
			var r: float = sqrt(dx * dx + dz * dz)
			var th: float = atan2(dz, dx)
			# Reach field: max of angular cusps (aretes and spurs) over the cirque reach r0.
			var lobe: float = 0.0
			for k: int in 4:
				var ak: float = a_ang[k] + a_crv[k] * r + a_wig[k] * sin(r * a_wfq[k] + a_wph[k])
				p_ang[k] = ak
				var d: float = absf(fposmod(th - ak + PI, TAU) - PI)
				lobe = maxf(lobe, a_amp[k] * exp(-d / a_wid[k]))
			for k: int in 5:
				var rb: float = s_rb[k]
				if r <= rb:
					continue
				var sa: float = p_ang[s_par[k]] + s_div[k] * (r - rb)
				var d2: float = absf(fposmod(th - sa + PI, TAU) - PI)
				var gate: float = clampf((r - rb) * 12.0, 0.0, 1.0)
				lobe = maxf(lobe, s_amp[k] * gate * exp(-d2 / s_wid[k]))
			var reach: float = r0 + lobe
			var re: float = sqrt(r * r + tip * tip) - tip
			var h: float = 1.0 - pow(re / reach, prof_p)
			# Raised cirque floors (glacier bowls) joined to the faces with a smooth max (bergschrund fillet).
			var fl: float = 0.17 * (1.0 - clampf((rho - 0.35) / 0.7, 0.0, 1.0)) * (0.75 + 0.25 * sin(2.0 * th + 1.3))
			var kf: float = 0.05
			var bf: float = clampf(0.5 + 0.5 * (h - fl) / kf, 0.0, 1.0)
			h = lerpf(fl, h, bf) + kf * bf * (1.0 - bf)
			# Erosion: multi-octave ridged noise, faded out at the summit so it stays the high point.
			var face: float = 1.0 - clampf(lobe / 0.22, 0.0, 1.0) # 1 on cirque faces, 0 on arete crests
			var near: float = clampf((r - 0.03) / 0.25, 0.0, 1.0)
			var e: float = erosion.get_noise_2d(x * 1.0, z * 1.0)
			h += 0.055 * near * e * (0.5 + 0.5 * clampf(h * 1.5, 0.0, 1.0))
			# Couloirs: ridged polar noise, stretched along the fall line, cut as sharp V grooves.
			var g: float = 1.0 - absf(gully.get_noise_3d(cos(th) * 4.0, sin(th) * 4.0, r * 2.5))
			g = g * g
			g = g * g
			h -= 0.05 * g * face * clampf((r - 0.08) / 0.2, 0.0, 1.0) * (1.0 - clampf((rho - 0.75) / 0.3, 0.0, 1.0))
			# Buried skirt: smooth min against a steep ramp that is below zero past rho = 1.05.
			var sk: float = 1.5 * (1.05 - rho)
			var ks: float = 0.04
			var bs: float = clampf(0.5 + 0.5 * (sk - h) / ks, 0.0, 1.0)
			h = lerpf(sk, h, bs) - ks * bs * (1.0 - bs)
			h = maxf(h, -0.1)
			var v: int = j * row + i
			hts[v] = h
			remap[v] = count
			count += 1
			verts.append(Vector3(x, h, z))
			if h > h_max:
				h_max = h

	# Normalise so the summit is exactly y = 1.0 (scale preserves the sign of the buried skirt).
	var inv: float = 1.0 / h_max
	for q: int in count:
		var vv: Vector3 = verts[q]
		verts[q] = Vector3(vv.x, vv.y * inv, vv.z)

	# Triangles: keep cells whose four corners are inside the disc; split along the flatter diagonal so
	# ridge crests and gully floors stay crisp. Both splits wind clockwise seen from above (normals +y).
	var idx := PackedInt32Array()
	idx.resize(n * n * 6)
	var c: int = 0
	for j: int in n:
		for i: int in n:
			var v00: int = j * row + i
			var v10: int = v00 + 1
			var v01: int = v00 + row
			var v11: int = v01 + 1
			var m00: int = remap[v00]
			var m10: int = remap[v10]
			var m01: int = remap[v01]
			var m11: int = remap[v11]
			if m00 < 0 or m10 < 0 or m01 < 0 or m11 < 0:
				continue
			if absf(hts[v10] - hts[v01]) <= absf(hts[v00] - hts[v11]):
				idx[c] = m00; idx[c + 1] = m10; idx[c + 2] = m01
				idx[c + 3] = m10; idx[c + 4] = m11; idx[c + 5] = m01
			else:
				idx[c] = m00; idx[c + 1] = m10; idx[c + 2] = m11
				idx[c + 3] = m00; idx[c + 4] = m11; idx[c + 5] = m01
			c += 6
	idx.resize(c)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var st := SurfaceTool.new()
	st.create_from_arrays(arrays, Mesh.PRIMITIVE_TRIANGLES)
	st.generate_normals()
	return st.commit()
