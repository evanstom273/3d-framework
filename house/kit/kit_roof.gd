@tool
class_name KitRoof
extends KitPiece
## A pitched roof over a rectangle of walls: two slopes meeting at a ridge along Z
## (or one slope for a lean-to), each end a gable, a hip, or open to join another
## roof. Tiles are laid in real stepped courses; ridge and hip tiles, bargeboards,
## fascias, gutters and downpipes are added to match.
##
## The origin is the top of the walls at the corner grid point. `span` (X) and
## `length` (Z) are measured between wall centre lines, so a roof on a 6 x 8 m
## house has span 6 and length 8. Crossing two roofs makes a valley naturally.

enum End { GABLE, HIP, OPEN }

@export_range(1.0, 20.0, 0.05, "suffix:m") var span: float = 6.0:
	set(value):
		span = snap(value, 1.0)
		queue_rebuild()
@export_range(0.5, 40.0, 0.05, "suffix:m") var length: float = 8.0:
	set(value):
		length = snap(value, 0.5)
		queue_rebuild()
@export_range(10.0, 60.0, 0.5, "suffix:°") var pitch: float = 38.0:
	set(value):
		pitch = value
		queue_rebuild()
@export var start_end: End = End.GABLE:
	set(value):
		start_end = value
		queue_rebuild()
@export var finish_end: End = End.GABLE:
	set(value):
		finish_end = value
		queue_rebuild()
## One slope rising toward +X, for porches and extensions against a taller wall.
@export var lean_to: bool = false:
	set(value):
		lean_to = value
		queue_rebuild()
@export var tiles: KitMaterials.RoofTile = KitMaterials.RoofTile.CLAY_PLAIN:
	set(value):
		tiles = value
		queue_rebuild()

@export_group("Edges")
@export_range(0.0, 1.0, 0.05, "suffix:m") var eaves_overhang: float = 0.3:
	set(value):
		eaves_overhang = value
		queue_rebuild()
@export_range(0.0, 1.0, 0.05, "suffix:m") var verge_overhang: float = 0.2:
	set(value):
		verge_overhang = value
		queue_rebuild()
## Thickness of the walls below (sets where the outside faces are).
@export_range(0.05, 0.6, 0.005, "suffix:m") var wall_thickness: float = 0.3:
	set(value):
		wall_thickness = value
		queue_rebuild()
@export var fascia_color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		fascia_color = value
		queue_rebuild()
@export var gutters: bool = true:
	set(value):
		gutters = value
		queue_rebuild()
## How far downpipes run below the eaves' wall plate (0 for none), e.g. 3.3 for
## one storey plus the plinth, 6.3 for two.
@export_range(0.0, 20.0, 0.05, "suffix:m") var downpipe_drop: float = 0.0:
	set(value):
		downpipe_drop = value
		queue_rebuild()

@export_group("Gables")
## Fill gable ends with walling to match the walls below.
@export var gable_walls: bool = true:
	set(value):
		gable_walls = value
		queue_rebuild()
@export var gable_facade: KitMaterials.Facade = KitMaterials.Facade.BRICK:
	set(value):
		gable_facade = value
		queue_rebuild()
@export var gable_brick: KitMaterials.Brick = KitMaterials.Brick.RED:
	set(value):
		gable_brick = value
		queue_rebuild()
@export var gable_color: Color = Color(0.93, 0.91, 0.85):
	set(value):
		gable_color = value
		queue_rebuild()

const SEAT := 0.12
const DEPTH := 0.16
const LIP := 0.014
const COURSE := 0.1

var _p: float
var _half: float
var _run: float
var _slope_length: float
var _base: float


func ridge_height() -> float:
	_prepare()
	return _base + _run * tan(_p)


func _prepare() -> void:
	_p = deg_to_rad(pitch)
	_half = wall_thickness * 0.5
	_run = (span + wall_thickness) if lean_to else (span * 0.5 + _half)
	_slope_length = (_run + eaves_overhang) / cos(_p)
	_base = SEAT


func _build(b: KitBuilder) -> void:
	_prepare()
	var courses := maxi(1, roundi(_slope_length / COURSE))
	var course := _slope_length / courses
	var tile := KitMaterials.roof(tiles, course)
	var underside := KitMaterials.paint(fascia_color.darkened(0.04))
	var ridge_material := KitMaterials.terracotta() if tiles == KitMaterials.RoofTile.CLAY_PLAIN else KitMaterials.stone(Color(0.32, 0.32, 0.33) if tiles != KitMaterials.RoofTile.STONE_SLATE else Color(0.55, 0.51, 0.43))
	var start := start_end
	var finish := finish_end
	if lean_to:
		start = End.GABLE if start == End.HIP else start
		finish = End.GABLE if finish == End.HIP else finish
	var c := cos(_p)
	var s := sin(_p)
	var o := eaves_overhang
	var eave_y := _base - o * tan(_p)
	var ridge_y := _base + _run * tan(_p)
	# Left slope (facing -X): u along +Z.
	_slope(b, Vector3(-_half - o, eave_y, 0), Vector3.BACK, Vector3(c, s, 0), Vector2(_z_min(start, 0.0), _z_max(finish, 0.0)),
		Vector2(_z_min(start, _slope_length), _z_max(finish, _slope_length)), courses, course, tile, underside)
	if not lean_to:
		# Right slope (facing +X): u along -Z, so its z range is negated.
		_slope(b, Vector3(span + _half + o, eave_y, 0), Vector3.FORWARD, Vector3(-c, s, 0), Vector2(-_z_max(finish, 0.0), -_z_min(start, 0.0)),
			Vector2(-_z_max(finish, _slope_length), -_z_min(start, _slope_length)), courses, course, tile, underside)
		var ridge_z0 := _z_min(start, _slope_length)
		var ridge_z1 := _z_max(finish, _slope_length)
		_ridge(b, Vector3(span * 0.5, ridge_y, ridge_z0), Vector3(span * 0.5, ridge_y, ridge_z1), Vector3.UP, ridge_material)
	var x_lo := -_half - o
	var x_hi := (span + _half + o) if not lean_to else (span + _half)
	if start == End.HIP:
		var z_e := -_half - o
		# Hip end facing -Z: u along -X.
		_slope(b, Vector3(0, eave_y, z_e), Vector3.LEFT, Vector3(0, s, c), Vector2(-x_hi, -x_lo), Vector2(-span * 0.5, -span * 0.5), courses, course, tile, underside)
		var up := (Vector3(-s, c, 0) + Vector3(0, c, -s)).normalized()
		_ridge(b, Vector3(x_lo, eave_y, z_e), Vector3(span * 0.5, ridge_y, _z_min(start, _slope_length)), up, ridge_material)
		_ridge(b, Vector3(x_hi, eave_y, z_e), Vector3(span * 0.5, ridge_y, _z_min(start, _slope_length)), (Vector3(s, c, 0) + Vector3(0, c, -s)).normalized(), ridge_material)
	if finish == End.HIP:
		var z_e := length + _half + o
		# Hip end facing +Z: u along +X.
		_slope(b, Vector3(0, eave_y, z_e), Vector3.RIGHT, Vector3(0, s, -c), Vector2(x_lo, x_hi), Vector2(span * 0.5, span * 0.5), courses, course, tile, underside)
		_ridge(b, Vector3(x_lo, eave_y, z_e), Vector3(span * 0.5, ridge_y, _z_max(finish, _slope_length)), (Vector3(-s, c, 0) + Vector3(0, c, s)).normalized(), ridge_material)
		_ridge(b, Vector3(x_hi, eave_y, z_e), Vector3(span * 0.5, ridge_y, _z_max(finish, _slope_length)), (Vector3(s, c, 0) + Vector3(0, c, s)).normalized(), ridge_material)
	if gable_walls:
		if start == End.GABLE:
			_gable(b, -_half, true)
		if finish == End.GABLE:
			_gable(b, length + _half, false)
	_verges(b, start, finish)
	_eaves(b, start, finish, eave_y)
	if lean_to:
		_abutment(b, ridge_y)


## Where a side slope's tiles stop at the start (-Z) end, `v` metres up the slope.
func _z_min(end: End, v: float) -> float:
	match end:
		End.GABLE:
			return -_half - verge_overhang
		End.HIP:
			return -_half - eaves_overhang + v * cos(_p)
	return 0.0


func _z_max(end: End, v: float) -> float:
	match end:
		End.GABLE:
			return length + _half + verge_overhang
		End.HIP:
			return length + _half + eaves_overhang - v * cos(_p)
	return length


## One roof plane from its eave line. `bottom`/`top` are the u ranges at the eave
## and at the top; u and v span the plane (u x v points out of the roof).
func _slope(b: KitBuilder, eave: Vector3, u_axis: Vector3, v_axis: Vector3, bottom: Vector2, top: Vector2,
		courses: int, course: float, tile: Material, underside: Material) -> void:
	var normal := u_axis.cross(v_axis).normalized()
	var length_v := _slope_length
	for k in courses:
		var v0 := k * course
		var v1 := (k + 1) * course
		var a := bottom.lerp(top, v0 / length_v)
		var t := bottom.lerp(top, v1 / length_v)
		if a.y - a.x < 0.001 and t.y - t.x < 0.001:
			continue
		var p0 := eave + u_axis * a.x + v_axis * v0 + normal * LIP
		var p1 := eave + u_axis * a.y + v_axis * v0 + normal * LIP
		var p2 := eave + u_axis * t.y + v_axis * v1
		var p3 := eave + u_axis * t.x + v_axis * v1
		# Each course is tilted: proud at its lower edge, tucked under the next at the top.
		b.quad(p0, p1, p2, p3, tile, false, Vector2(a.x, v0), u_axis, v_axis)
		var drop := -0.04 if k == 0 else 0.0
		var l0 := eave + u_axis * a.x + v_axis * v0 + normal * drop
		var l1 := eave + u_axis * a.y + v_axis * v0 + normal * drop
		b.quad(l0, l1, p1, p0, tile, false, Vector2(a.x, v0 - 0.02), u_axis, normal)
	# Underside (soffit and loft side), and one collision plane.
	var corners := PackedVector2Array([Vector2(bottom.x, 0), Vector2(bottom.y, 0), Vector2(top.y, length_v), Vector2(top.x, length_v)])
	if top.y - top.x < 0.001:
		corners = PackedVector2Array([Vector2(bottom.x, 0), Vector2(bottom.y, 0), Vector2(top.x, length_v)])
	var under := eave - normal * DEPTH
	var indices := Geometry2D.triangulate_polygon(corners)
	for i in range(0, indices.size(), 3):
		var q: Array[Vector3] = []
		for k in 3:
			var c := corners[indices[i + k]]
			q.append(under + u_axis * c.x + v_axis * c.y)
		b.tri(q[0], q[2], q[1], underside, false)
		var lift := normal * (DEPTH + LIP * 0.5)
		b.collision_tri(q[0] + lift, q[1] + lift, q[2] + lift)


## Half-round ridge (or hip) tiles from `from` to `to`, sitting astride the line.
func _ridge(b: KitBuilder, from: Vector3, to: Vector3, up: Vector3, material: Material) -> void:
	var profile := arc(Vector2(0, -0.035), 0.11, 0.0, PI, 10)
	var piece := 0.45
	var total := from.distance_to(to)
	var count := maxi(1, ceili(total / piece))
	var direction := (to - from) / total
	for i in count:
		var a := from + direction * (i * total / count)
		var c := from + direction * ((i + 1) * total / count - 0.006)
		b.extrude(profile, a, c, up, material, false, true)


## Brick or rendered infill under a gable, flush with the wall below it.
func _gable(b: KitBuilder, z_outer: float, at_start: bool) -> void:
	var under := DEPTH / cos(_p) + 0.02
	var points := PackedVector2Array([Vector2(-_half, 0.0), Vector2(span + _half, 0.0)])
	if lean_to:
		points.append(Vector2(span + _half, ridge_height() - under))
	else:
		points.append(Vector2(span * 0.5, ridge_height() - under))
	var face := KitMaterials.facade(gable_facade, gable_brick, gable_color)
	var inner := KitMaterials.paint(Color(0.82, 0.8, 0.76))
	# Slab extends from its plane along -(X x Y) = -Z.
	if at_start:
		b.slab(points, Vector3(0, 0, z_outer + wall_thickness), Vector3.RIGHT, Vector3.UP, wall_thickness, inner, face)
	else:
		b.slab(points, Vector3(0, 0, z_outer), Vector3.RIGHT, Vector3.UP, wall_thickness, face, inner)


## Bargeboards along gable verges.
func _verges(b: KitBuilder, start: End, finish: End) -> void:
	var board := KitMaterials.gloss(fascia_color)
	var o := eaves_overhang
	var eave_y := _base - o * tan(_p)
	var ridge_y := _base + _run * tan(_p)
	for end in [[start, -_half - verge_overhang], [finish, length + _half + verge_overhang]]:
		if end[0] != End.GABLE:
			continue
		var z: float = end[1]
		var lines := [[Vector2(-_half - o, eave_y), Vector2(span * 0.5 if not lean_to else span + _half, ridge_y)]]
		if not lean_to:
			lines.append([Vector2(span + _half + o, eave_y), Vector2(span * 0.5, ridge_y)])
		for line in lines:
			var low: Vector2 = line[0]
			var high: Vector2 = line[1]
			var up := Vector2(0, 1) * (0.03 / cos(_p))
			var down := Vector2(0, -1) * (0.24 / cos(_p))
			var poly := PackedVector2Array([low + down, high + down, high + up, low + up])
			b.slab(poly, Vector3(0, 0, z + 0.012), Vector3.RIGHT, Vector3.UP, 0.024, board, board, false)


## Fascias, gutters and downpipes along every eave.
func _eaves(b: KitBuilder, start: End, finish: End, eave_y: float) -> void:
	var board := KitMaterials.gloss(fascia_color)
	var pipe := KitMaterials.metal(Color(0.07, 0.07, 0.08), 0.2)
	var o := eaves_overhang
	var z0 := _z_min(start, 0.0)
	var z1 := _z_max(finish, 0.0)
	var x_lo := -_half - o
	var x_hi := span + _half + o
	# Each eave: outward direction, the fascia line's two ends.
	var eaves := [[Vector3.LEFT, Vector3(x_lo, eave_y, z0), Vector3(x_lo, eave_y, z1)]]
	if not lean_to:
		eaves.append([Vector3.RIGHT, Vector3(x_hi, eave_y, z0), Vector3(x_hi, eave_y, z1)])
	if start == End.HIP:
		eaves.append([Vector3.FORWARD, Vector3(x_lo, eave_y, -_half - o), Vector3(x_hi, eave_y, -_half - o)])
	if finish == End.HIP:
		eaves.append([Vector3.BACK, Vector3(x_lo, eave_y, length + _half + o), Vector3(x_hi, eave_y, length + _half + o)])
	for eave in eaves:
		var out: Vector3 = eave[0]
		var a: Vector3 = eave[1]
		var e: Vector3 = eave[2]
		var low := a.min(e) - Vector3(0.0, 0.25, 0.0)
		var high := a.max(e) + Vector3(0.0, -0.012, 0.0)
		# The fascia board sits just behind the eave line.
		var inset := -out * 0.022
		b.box((low + inset).min(low), (high + inset).max(high) + Vector3(0, 0, 0), board, false)
		if not gutters:
			continue
		var profile := arc(Vector2(0.07, -0.08), 0.065, PI, TAU, 10)
		profile.append_array(arc(Vector2(0.07, -0.08), 0.058, TAU, PI, 10))
		# Pick the extrusion direction that makes "across" point outward.
		var direction := Vector3.UP.cross(out).normalized() * -1.0
		var along := e - a
		var from := a if along.dot(direction) > 0.0 else e
		var to := e if along.dot(direction) > 0.0 else a
		b.extrude(profile, from, to, Vector3.UP, pipe, false)
		if downpipe_drop > 0.0 and absf(out.x) > 0.5:
			for z in [z0 + 0.2, z1 - 0.2]:
				_downpipe(b, a.x + out.x * 0.07, z, out, eave_y, pipe)


func _downpipe(b: KitBuilder, x: float, z: float, out: Vector3, eave_y: float, material: Material) -> void:
	var round := arc(Vector2.ZERO, 0.034, 0.0, TAU * 11.0 / 12.0, 11)
	var wall_x := (-_half if out.x < 0.0 else span + _half) + out.x * 0.06
	var top := Vector3(x, eave_y - 0.12, z)
	var bend := Vector3(wall_x, eave_y - 0.45, z)
	var bottom := Vector3(wall_x, -downpipe_drop + 0.12, z)
	var shoe := Vector3(wall_x + out.x * 0.12, -downpipe_drop + 0.04, z)
	for segment in [[top, bend], [bend, bottom], [bottom, shoe]]:
		var a: Vector3 = segment[0]
		var c: Vector3 = segment[1]
		var up := Vector3.BACK if absf((c - a).normalized().y) > 0.9 else Vector3.UP
		b.extrude(round, a, c, up, material, false, true)
	# Brackets holding the pipe to the wall.
	var y := -downpipe_drop + 0.8
	while y < eave_y - 0.6:
		b.box(Vector3(minf(wall_x, wall_x - out.x * 0.06), y, z - 0.045), Vector3(maxf(wall_x, wall_x - out.x * 0.06), y + 0.03, z + 0.045), material, false)
		y += 1.6


## Lead flashing where a lean-to meets the wall it leans on.
func _abutment(b: KitBuilder, top_y: float) -> void:
	var lead := KitMaterials.lead()
	var x := span + _half
	var z0 := _z_min(start_end, _slope_length)
	var z1 := _z_max(finish_end, _slope_length)
	b.box(Vector3(x - 0.004, top_y - 0.02, z0), Vector3(x, top_y + 0.16, z1), lead, false)
	var back := Vector3(cos(_p), sin(_p), 0)
	var a := Vector3(x, top_y + 0.004, z0) - back * 0.18
	b.quad(a, Vector3(x, top_y + 0.004, z0) - back * 0.18 + Vector3(0, 0, z1 - z0), Vector3(x, top_y + 0.02, z1), Vector3(x, top_y + 0.02, z0), lead, false)
