@tool
class_name KitStairs
extends KitPiece
## A straight flight of stairs. The first riser is at the origin, the flight is
## `width` wide along +X and climbs along +Z to `rise` above the origin (the next
## floor). Each side is against a wall (with a wall handrail) or open (with a
## balustrade: newels, balusters and a handrail). A KitFloor at the top of the
## flight cuts its own stairwell over it automatically.

enum StairSide { WALL, OPEN, NONE }

@export_range(0.6, 2.0, 0.05, "suffix:m") var width: float = 0.9:
	set(value):
		width = snap(value, 0.6)
		queue_rebuild()
## Floor to floor.
@export_range(0.3, 6.0, 0.05, "suffix:m") var rise: float = 3.0:
	set(value):
		rise = snap(value, 0.3)
		queue_rebuild()
## Depth of each tread.
@export_range(0.2, 0.35, 0.005, "suffix:m") var going: float = 0.25:
	set(value):
		going = value
		queue_rebuild()
@export_range(0.15, 0.22, 0.005, "suffix:m") var max_riser: float = 0.2:
	set(value):
		max_riser = value
		queue_rebuild()
@export var left_side: StairSide = StairSide.WALL:
	set(value):
		left_side = value
		queue_rebuild()
@export var right_side: StairSide = StairSide.OPEN:
	set(value):
		right_side = value
		queue_rebuild()
@export var tread_color: Color = Color(0.55, 0.37, 0.22):
	set(value):
		tread_color = value
		queue_rebuild()
@export var paint_color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		paint_color = value
		queue_rebuild()
## A carpet runner up the middle of the treads.
@export var runner: bool = false:
	set(value):
		runner = value
		queue_rebuild()
@export var runner_color: Color = Color(0.45, 0.12, 0.14):
	set(value):
		runner_color = value
		queue_rebuild()
## Plaster under the flight (closed) rather than open treads.
@export var soffit: bool = true:
	set(value):
		soffit = value
		queue_rebuild()
## Cut a stairwell through any KitFloor at the top of the flight.
@export var cut_floor_above: bool = true:
	set(value):
		cut_floor_above = value
		queue_rebuild()

const HEADROOM := 2.1
## The player's capsule reaches ahead of their feet: open the well this much earlier.
const HEAD_REACH := 0.5

var _built_once := false


func _enter_tree() -> void:
	add_to_group(&"kit_stairs")
	if Engine.is_editor_hint():
		set_notify_transform(true)


func _exit_tree() -> void:
	_refresh_floors()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_refresh_floors()


## The stairwell this flight needs in `floor` (in the floor's local x, z), or an
## empty rect if the flight doesn't arrive at that floor.
func stairwell_in(floor: KitFloor) -> Rect2:
	if not cut_floor_above or not is_inside_tree() or not floor.is_inside_tree():
		return Rect2()
	var relative := floor.global_transform.affine_inverse() * global_transform
	var total_run := run()
	if absf((relative * Vector3(width * 0.5, rise, total_run)).y) > 0.1:
		return Rect2()
	# Open from where a person climbing needs headroom, up to the top riser.
	var start := clampf(total_run * (rise - floor.thickness - HEADROOM) / rise - HEAD_REACH, 0.0, total_run)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in [Vector3(-0.01, 0, start), Vector3(width + 0.01, 0, start), Vector3(width + 0.01, 0, total_run), Vector3(-0.01, 0, total_run)]:
		var p: Vector3 = relative * corner
		low = low.min(Vector2(p.x, p.z))
		high = high.max(Vector2(p.x, p.z))
	return Rect2(low, high - low).intersection(Rect2(Vector2.ZERO, floor.size))


func _refresh_floors() -> void:
	if not is_inside_tree():
		return
	for floor in get_tree().get_nodes_in_group(&"kit_floors"):
		if floor is KitFloor:
			floor.queue_rebuild()


func step_count() -> int:
	return maxi(2, ceili(rise / max_riser))


func run() -> float:
	return (step_count() - 1) * going


func _build(b: KitBuilder) -> void:
	var n := step_count()
	var riser := rise / n
	var total_run := run()
	var oak := KitMaterials.timber(tread_color)
	var paint := KitMaterials.gloss(paint_color)
	var carpet := KitMaterials.carpet(runner_color)
	var string_w := 0.035
	var x0 := string_w
	var x1 := width - string_w
	for k in range(n - 1):
		var z := k * going
		var top := (k + 1) * riser
		# Tread with a rounded nosing over the riser below.
		b.box(Vector3(x0, top - 0.03, z - 0.02), Vector3(x1, top, z + going), oak, false)
		b.extrude(arc(Vector2(0.0, -0.015), 0.015, -PI * 0.5, PI * 0.5, 5), Vector3(x1, top, z - 0.02), Vector3(x0, top, z - 0.02), Vector3.UP, oak, false)
		b.box(Vector3(x0, top - riser, z), Vector3(x1, top - 0.03, z + 0.018), paint, false)
		if runner:
			b.box(Vector3(width * 0.2, top, z - 0.022), Vector3(width * 0.8, top + 0.008, z + going), carpet, false)
			b.box(Vector3(width * 0.2, top - riser, z - 0.03), Vector3(width * 0.8, top - 0.03, z - 0.022), carpet, false)
	# Last riser up to the landing.
	b.box(Vector3(x0, rise - riser, total_run), Vector3(x1, rise, total_run + 0.018), paint, false)
	# Strings: boards running with the pitch on each side.
	var pitch_line := [Vector2(-0.02, 0.0), Vector2(total_run, rise)]
	for side in [[0.0, left_side], [width - string_w, right_side]]:
		if side[1] == StairSide.NONE:
			continue
		var low: Vector2 = pitch_line[0]
		var high: Vector2 = pitch_line[1]
		var string_poly := PackedVector2Array([Vector2(low.x, low.y - 0.12), Vector2(high.x + 0.02, high.y - 0.12 - 0.05), Vector2(high.x + 0.02, high.y + 0.06), Vector2(low.x, low.y + 0.18)])
		# Polygon in (z, y), slab thickness along -(Z x Y) = +X from its plane.
		b.slab(string_poly, Vector3(side[0], 0, 0), Vector3.BACK, Vector3.UP, string_w, paint, paint, false)
	if soffit:
		var under := KitMaterials.paint(Color(0.95, 0.95, 0.93))
		var drop := 0.22
		# Faces down, toward someone standing underneath.
		b.quad(Vector3(x0, -drop + riser, 0.0), Vector3(x1, -drop + riser, 0.0), Vector3(x1, rise - drop, total_run), Vector3(x0, rise - drop, total_run), under, false)
	# Walk up a smooth ramp through the nosings instead of bumping up each step.
	b.collision_quad(Vector3(0, 0.0, -0.05), Vector3(width, 0.0, -0.05), Vector3(width, rise, total_run + 0.02), Vector3(0, rise, total_run + 0.02))
	for side in [[0.0, left_side, -1.0], [width, right_side, 1.0]]:
		match side[1]:
			StairSide.OPEN:
				_balustrade(b, side[0] - side[2] * string_w * 0.5, riser, total_run)
			StairSide.WALL:
				_wall_rail(b, side[0] + side[2] * -0.06, total_run)
	# Floors rebuilt at load find the stairs themselves; later edits tell them.
	if _built_once:
		_refresh_floors.call_deferred()
	_built_once = true


func _balustrade(b: KitBuilder, x: float, riser: float, total_run: float) -> void:
	var paint := KitMaterials.gloss(paint_color)
	var oak := KitMaterials.timber(tread_color)
	var rail_height := 0.9
	var bottom := Vector3(x, 0.0, -0.05)
	var top := Vector3(x, rise, total_run + 0.05)
	KitStairs.newel(b, bottom, 1.15, paint, oak)
	KitStairs.newel(b, top, 1.0, paint, oak)
	var rail_from := bottom + Vector3(0, rail_height + 0.05, 0.06)
	var rail_to := top + Vector3(0, rail_height, -0.06)
	b.extrude(KitStairs.handrail_profile(), rail_from, rail_to, Vector3.UP, oak, false)
	var n := step_count()
	for k in range(n - 1):
		for half in 2:
			var z := k * going + going * (0.25 + 0.5 * half)
			var tread_y := (k + 1) * riser
			var rail_y := lerpf(rail_from.y, rail_to.y, clampf((z - rail_from.z) / (rail_to.z - rail_from.z), 0.0, 1.0))
			b.bevel_box(Vector3(x - 0.016, tread_y, z - 0.016), Vector3(x + 0.016, rail_y - 0.03, z + 0.016), 0.005, paint, false)
	# A guard so you can't walk off the open side.
	b.collision_quad(Vector3(x, 0, -0.05), Vector3(x, rise, total_run), Vector3(x, rise + rail_height, total_run), Vector3(x, rail_height, -0.05))


func _wall_rail(b: KitBuilder, x: float, total_run: float) -> void:
	var oak := KitMaterials.timber(tread_color)
	var metal := KitMaterials.metal(Color(0.7, 0.62, 0.4), 0.8)
	var from := Vector3(x, 0.95, 0.1)
	var to := Vector3(x, rise + 0.9, total_run - 0.1)
	b.extrude(arc(Vector2.ZERO, 0.024, 0.0, TAU * 11.0 / 12.0, 11), from, to, Vector3.UP, oak, false, true)
	var count := maxi(2, ceili(from.distance_to(to) / 1.2) + 1)
	for i in count:
		var at := from.lerp(to, float(i) / (count - 1))
		var wall_side := -0.06 if x < width * 0.5 else 0.06
		b.box(Vector3(minf(at.x, at.x + wall_side), at.y - 0.05, at.z - 0.008), Vector3(maxf(at.x, at.x + wall_side), at.y - 0.035, at.z + 0.008), metal, false)


## A square newel post with a chamfered shaft and a moulded cap, standing at `base`.
static func newel(b: KitBuilder, base: Vector3, height: float, paint: Material, cap: Material) -> void:
	var half := 0.045
	b.bevel_box(base + Vector3(-half, 0, -half), base + Vector3(half, height - 0.06, half), 0.008, paint)
	b.box(base + Vector3(-half - 0.01, height - 0.08, -half - 0.01), base + Vector3(half + 0.01, height - 0.06, half + 0.01), cap, false)
	b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.05, 0.01), Vector2(0.035, 0.02), Vector2(0.045, 0.045), Vector2(0.03, 0.075), Vector2(0.0, 0.085)]), base + Vector3(0, height - 0.06, 0), 12, cap)


## Mopstick-style handrail section (across, up), centred on the rail line.
static func handrail_profile() -> PackedVector2Array:
	var profile := PackedVector2Array([Vector2(-0.025, -0.03), Vector2(0.025, -0.03), Vector2(0.03, -0.01)])
	profile.append_array(KitPiece.arc(Vector2(0, 0.0), 0.03, 0.0, PI, 8))
	profile.append(Vector2(-0.03, -0.01))
	return profile
