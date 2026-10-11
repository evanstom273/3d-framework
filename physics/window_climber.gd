class_name WindowClimber
extends Node
## Climbing through open windows: stand at an open window, look through it and
## press jump. The player is carried up onto the sill, ducks through and drops
## down the other side. It's a scripted move (collision is off for it), not
## physics, so it's quick and forgiving.

## Furthest the player can stand from the window's wall line.
@export_range(0.3, 3.0, 0.05, "suffix:m") var reach: float = 1.3
@export_range(0.3, 3.0, 0.05, "suffix:s") var duration: float = 0.9
## Open casements at least this tall, starting within a step of the floor, are
## simply walked through, so they don't offer a climb.
@export_range(1.0, 3.0, 0.05, "suffix:m") var walk_through_height: float = 1.85

var player: CharacterBody3D
## The open window the player could climb through right now, or null.
var target: KitWindowOpening
## Which of its casements' openings (see KitWindowOpening.lights).
var target_light: Rect2

var _opening: KitWindowOpening
var _light: Rect2
var _active: bool = false
var _time: float = 0.0
var _path: Array[Vector3] = []
var _head_rest: float = 0.0
var _head: Node3D
var _collision: CollisionShape3D


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_head = player.get(&"head") as Node3D
	_collision = player.get(&"collision") as CollisionShape3D


func is_active() -> bool:
	return _active


## How high the player can step up without climbing.
func _step_height() -> float:
	var step: Variant = player.get(&"max_step_height")
	return float(step) if step != null else 0.3


## Picks the nearest open window the player is beside and looking through.
func find_target(look: Vector3) -> void:
	target = null
	var flat_look := look.slide(Vector3.UP)
	if flat_look.length_squared() < 0.0001:
		return
	flat_look = flat_look.normalized()
	var best := INF
	for node in player.get_tree().get_nodes_in_group(&"climbable_openings"):
		var opening := node as KitWindowOpening
		if opening == null or not opening.is_inside_tree():
			continue
		var outward := opening.outward()
		# Each open casement is its own way through (not the mullions between them).
		for light in opening.open_lights():
			var base := opening.light_base(light)
			var offset := player.global_position - base
			var across := absf(offset.dot(outward))
			var sideways := absf(offset.dot(opening.along()))
			if across > reach or sideways > light.size.x * 0.5 + 0.2:
				continue
			# Low and tall enough to walk through (a full-height window): no climbing needed.
			var floor_y := opening.global_position.y - opening.sill_height
			if base.y - floor_y <= _step_height() + 0.02 and light.size.y >= walk_through_height:
				continue
			# The sill must be within a climb of the feet.
			var sill := base.y - player.global_position.y
			if sill < -0.5 or sill > 1.6:
				continue
			# Looking toward the window, from whichever side we're on.
			var toward := outward * (-1.0 if offset.dot(outward) > 0.0 else 1.0)
			if flat_look.dot(toward) < 0.45:
				continue
			var score := across + sideways
			if score < best:
				best = score
				target = opening
				target_light = light


func start() -> void:
	if target == null or _active:
		return
	_opening = target
	_light = target_light
	var outward := _opening.outward()
	# Through the middle of the open casement, at its bottom.
	var base := _opening.light_base(_light)
	var side := 1.0 if (player.global_position - base).dot(outward) >= 0.0 else -1.0
	var half := _opening.depth * 0.5
	var near := base + outward * side * (half + 0.3)
	var far := base - outward * side * (half + 0.55)
	near.y = base.y + 0.02
	far.y = base.y + 0.02
	# Land at floor level; outside, gravity takes the player the rest of the way down.
	var landing := far
	landing.y = _opening.global_position.y - _opening.sill_height + 0.02
	_path = [player.global_position, near, far, landing]
	_time = 0.0
	_active = true
	_head_rest = _head.position.y if _head != null else 0.0
	if _collision != null:
		_collision.disabled = true
	player.velocity = Vector3.ZERO


## Moves the player along the climb. Call instead of normal movement while active.
func update(delta: float) -> void:
	if not _active:
		return
	_time += delta
	var t := clampf(_time / maxf(duration, 0.05), 0.0, 1.0)
	# Up onto the sill, through the opening, down the far side.
	var position: Vector3
	if t < 0.3:
		position = _path[0].lerp(_path[1], smoothstep(0.0, 1.0, t / 0.3))
	elif t < 0.8:
		position = _path[1].lerp(_path[2], smoothstep(0.0, 1.0, (t - 0.3) / 0.5))
	else:
		position = _path[2].lerp(_path[3], smoothstep(0.0, 1.0, (t - 0.8) / 0.2))
	player.global_position = position
	# Duck so the eyes pass under the head of the window.
	if _head != null and is_instance_valid(_opening):
		var duck := sin(clampf((t - 0.15) / 0.75, 0.0, 1.0) * PI)
		var low := minf(_head_rest, _light.size.y - 0.3)
		_head.position.y = lerpf(_head_rest, low, duck)
	if t >= 1.0:
		_finish()


func _finish() -> void:
	_active = false
	if _collision != null:
		_collision.disabled = false
	if _head != null:
		_head.position.y = _head_rest
	player.velocity = Vector3.ZERO
	_opening = null
