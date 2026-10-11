extends RefCounted
## Offline finite stored-coordinate predicates reused from MUSH candidate05.
## Geometry2D owns triangulation/intersections. No runtime or archive dependency.
func _area(poly: PackedVector2Array) -> float:
	var result: float=0.0
	for i: int in range(poly.size()): result+=float(poly[i].x)*poly[(i+1)%poly.size()].y-float(poly[(i+1)%poly.size()].x)*poly[i].y
	return result*.5

# These scalar-f64 stored-coordinate predicates retain candidate05 semantics.
func _annulus_orientation(a: Vector2,b: Vector2,c: Vector2) -> float:
	return (float(b.x)-float(a.x))*(float(c.y)-float(a.y))-(float(b.y)-float(a.y))*(float(c.x)-float(a.x))

func _annulus_on_segment(a: Vector2,b: Vector2,p: Vector2) -> bool:
	return _annulus_orientation(a,b,p)==0.0 and float(p.x)>=minf(float(a.x),float(b.x)) and float(p.x)<=maxf(float(a.x),float(b.x)) and float(p.y)>=minf(float(a.y),float(b.y)) and float(p.y)<=maxf(float(a.y),float(b.y))

func _annulus_contact(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> bool:
	var ac: float=_annulus_orientation(a,b,c); var ad: float=_annulus_orientation(a,b,d)
	var ca: float=_annulus_orientation(c,d,a); var cb: float=_annulus_orientation(c,d,b)
	if (ac==0.0 and _annulus_on_segment(a,b,c)) or (ad==0.0 and _annulus_on_segment(a,b,d)) or (ca==0.0 and _annulus_on_segment(c,d,a)) or (cb==0.0 and _annulus_on_segment(c,d,b)): return true
	return ((ac<0.0 and ad>0.0) or (ac>0.0 and ad<0.0)) and ((ca<0.0 and cb>0.0) or (ca>0.0 and cb<0.0))

func _annulus_only_endpoint(a: Vector2,b: Vector2,c: Vector2,d: Vector2) -> bool:
	var shared: Array[Vector2]=[]
	if a==c or a==d: shared.append(a)
	if b==c or b==d: shared.append(b)
	if shared.size()!=1 or a==b or c==d: return false
	var endpoint: Vector2=shared[0]
	var x: Vector2=b if a==endpoint else a; var y: Vector2=d if c==endpoint else c
	if _annulus_orientation(endpoint,x,y)!=0.0: return true
	# Collinear opposite rays share one endpoint; overlapping same rays refuse.
	return (float(x.x)-float(endpoint.x))*(float(y.x)-float(endpoint.x))+(float(x.y)-float(endpoint.y))*(float(y.y)-float(endpoint.y))<0.0

func _annulus_simple(poly: PackedVector2Array) -> bool:
	if poly.size()<3: return false
	for a: int in range(poly.size()):
		if not is_finite(poly[a].x) or not is_finite(poly[a].y): return false
		for b: int in range(a+1,poly.size()):
			if poly[a]==poly[b]: return false
			var c: Vector2=poly[a]; var d: Vector2=poly[(a+1)%poly.size()]
			var e: Vector2=poly[b]; var f: Vector2=poly[(b+1)%poly.size()]
			if b==a+1 or (a==0 and b==poly.size()-1):
				if not _annulus_only_endpoint(c,d,e,f): return false
			elif _annulus_contact(c,d,e,f): return false
	return true

func _annulus_nested(inner: PackedVector2Array,outer: PackedVector2Array) -> bool:
	if not _annulus_simple(inner) or not _annulus_simple(outer) or _area(inner)<=0.0 or _area(outer)<=_area(inner): return false
	for p: Vector2 in inner:
		if not Geometry2D.is_point_in_polygon(p,outer): return false
	for i: int in range(inner.size()):
		for j: int in range(outer.size()):
			if _annulus_contact(inner[i],inner[(i+1)%inner.size()],outer[j],outer[(j+1)%outer.size()]): return false
	return true
