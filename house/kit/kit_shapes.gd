@tool
class_name KitShapes
extends RefCounted
## Opening outlines for windows: one polygon per shape, in the opening's own 2D
## frame (x across from the centre, y up from the bottom), counter-clockwise.
## The wall cut-out, infill, reveals, frame, glass and collision are all built
## from the same outline, so they always agree.


static func outline(o: KitOpening, width: float, height: float, segments := 32) -> PackedVector2Array:
	var hw := width * 0.5
	match o.shape:
		KitOpening.Shape.SQUARE:
			var s := minf(width, height)
			return rect(-s * 0.5, 0.0, s * 0.5, s)
		KitOpening.Shape.CIRCLE:
			var r := minf(width, height) * 0.5
			return ellipse(Vector2(0.0, r), Vector2(r, r), segments)
		KitOpening.Shape.OVAL:
			return ellipse(Vector2(0.0, height * 0.5), Vector2(hw, height * 0.5), segments)
		KitOpening.Shape.ARCHED:
			return arched(hw, height, o.arch_rise, segments)
		KitOpening.Shape.SEMICIRCLE:
			var r := minf(hw, height)
			var points := PackedVector2Array()
			for i in segments + 1:
				var angle := PI * i / segments
				points.append(Vector2(cos(angle) * r, sin(angle) * r))
			return points
		KitOpening.Shape.TRIANGLE:
			return PackedVector2Array([Vector2(-hw, 0.0), Vector2(hw, 0.0), Vector2(0.0, height)])
		KitOpening.Shape.GABLE:
			var rise := o.arch_rise if o.arch_rise > 0.0 else minf(hw, height * 0.6)
			return PackedVector2Array([Vector2(-hw, 0.0), Vector2(hw, 0.0), Vector2(hw, height - rise), Vector2(0.0, height), Vector2(-hw, height - rise)])
		KitOpening.Shape.TRAPEZOID:
			var top := hw * o.taper
			return PackedVector2Array([Vector2(-hw, 0.0), Vector2(hw, 0.0), Vector2(top, height), Vector2(-top, height)])
		KitOpening.Shape.POLYGON:
			var n := clampi(o.polygon_sides, 3, 12)
			var r := minf(width, height) * 0.5
			var points := PackedVector2Array()
			# A flat edge along the bottom.
			var start := -PI * 0.5 + PI / n
			for i in n:
				var angle := start + TAU * i / n
				points.append(Vector2(cos(angle) * r, r + sin(angle) * r))
			return points
	return rect(-hw, 0.0, hw, height)


static func rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func ellipse(centre: Vector2, radii: Vector2, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := -PI * 0.5 + TAU * i / segments
		points.append(centre + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


## A rectangle with a round (or segmental, if `rise` is less than half the
## width) arch on top.
static func arched(hw: float, height: float, rise: float, segments: int) -> PackedVector2Array:
	if rise <= 0.0 or rise > hw:
		rise = minf(hw, height * 0.6)
	var spring := height - rise
	var radius := (rise * rise + hw * hw) / (2.0 * rise)
	var centre := Vector2(0.0, height - radius)
	var start := atan2(spring - centre.y, hw)
	var finish := PI - start
	var points := PackedVector2Array([Vector2(-hw, 0.0), Vector2(hw, 0.0)])
	for i in segments + 1:
		var angle := lerpf(start, finish, float(i) / segments)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Height where an arched or gable top begins (the top of its rectangular part).
static func spring_height(o: KitOpening, width: float, height: float) -> float:
	var hw := width * 0.5
	match o.shape:
		KitOpening.Shape.ARCHED:
			var rise := o.arch_rise if o.arch_rise > 0.0 and o.arch_rise <= hw else minf(hw, height * 0.6)
			return height - rise
		KitOpening.Shape.GABLE:
			return height - (o.arch_rise if o.arch_rise > 0.0 else minf(hw, height * 0.6))
	return height


## Whether the shape's rectangular part can be divided into panels (the curved
## or pointed top becomes a fixed top light).
static func supports_panels(o: KitOpening) -> bool:
	return o.shape in [KitOpening.Shape.RECTANGLE, KitOpening.Shape.SQUARE, KitOpening.Shape.ARCHED, KitOpening.Shape.GABLE]


## Moves every edge of a convex outline inward by `distance` (outward if negative).
static func inset(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var count := points.size()
	var result := PackedVector2Array()
	if count < 3:
		return result
	var ccw := _area(points) > 0.0
	for i in count:
		var prev := points[(i - 1 + count) % count]
		var here := points[i]
		var next := points[(i + 1) % count]
		var e0 := (here - prev).normalized()
		var e1 := (next - here).normalized()
		# Inward normals of the two edges meeting here.
		var n0 := Vector2(-e0.y, e0.x) if ccw else Vector2(e0.y, -e0.x)
		var n1 := Vector2(-e1.y, e1.x) if ccw else Vector2(e1.y, -e1.x)
		var bisector := (n0 + n1).normalized()
		var cos_half := maxf(bisector.dot(n0), 0.2)
		result.append(here + bisector * distance / cos_half)
	return result


## Area of `outer` minus the convex `inner`, as simple polygons without holes,
## found by clipping each quadrant around `centre` separately.
static func ring(outer: PackedVector2Array, inner: PackedVector2Array) -> Array[PackedVector2Array]:
	var pieces: Array[PackedVector2Array] = []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in outer:
		lo = lo.min(p)
		hi = hi.max(p)
	var centre := Vector2.ZERO
	for p in inner:
		centre += p
	centre /= maxf(1.0, inner.size())
	var quads := [rect(lo.x - 0.01, lo.y - 0.01, centre.x, centre.y), rect(centre.x, lo.y - 0.01, hi.x + 0.01, centre.y),
		rect(lo.x - 0.01, centre.y, centre.x, hi.y + 0.01), rect(centre.x, centre.y, hi.x + 0.01, hi.y + 0.01)]
	for quad in quads:
		for part in Geometry2D.intersect_polygons(outer, quad):
			for piece in Geometry2D.clip_polygons(part, inner):
				if not Geometry2D.is_polygon_clockwise(piece) and absf(_area(piece)) > 0.00001:
					pieces.append(piece)
	return pieces


## Cells (x, y), `cell` metres square with cell (0, 0) at `origin`, whose centres
## lie inside the outline: for voxelised glass and sashes in shaped windows.
static func cells_inside(points: PackedVector2Array, origin: Vector2, cell: float, nx: int, ny: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in ny:
		for x in nx:
			var p := origin + (Vector2(x, y) + Vector2.ONE * 0.5) * cell
			if Geometry2D.is_point_in_polygon(p, points):
				result.append(Vector2i(x, y))
	return result


static func bounds(points: PackedVector2Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	return Rect2(lo, hi - lo)


static func _area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		area += p.x * q.y - q.x * p.y
	return area * 0.5
