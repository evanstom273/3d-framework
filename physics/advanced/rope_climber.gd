class_name RopeClimber
extends Node
## Lets the player hang from and climb ropes, chains, cables and elastic bands.
## The player swings as a pendulum on the rope above their hands; the rope pins
## to the hands, and the player's weight pulls on whatever the rope is tied to
## (light things get dragged, weak ropes snap).

## Rope speed when climbing, in metres per second.
@export_range(0.2, 4.0, 0.1) var climb_speed: float = 1.4
@export_range(0.2, 4.0, 0.1) var slide_speed: float = 2.6
## How hard A/D (and Shift+W/S) pump the swing.
@export_range(0.0, 20.0, 0.5) var swing_acceleration: float = 5.0
@export_range(0.0, 2.0, 0.05) var air_drag: float = 0.15
@export_range(20.0, 200.0, 1.0, "suffix:kg") var player_mass: float = 75.0
## Hands, measured up from the player's feet.
@export_range(1.0, 2.5, 0.05, "suffix:m") var hand_height: float = 1.95
## Closest the hands climb to the point the rope hangs from.
@export_range(0.1, 1.0, 0.05, "suffix:m") var top_clearance: float = 0.35
@export_range(1.0, 5.0, 0.1, "suffix:m") var reach: float = 2.6
## How far beside the crosshair a rope still counts as aimed at.
@export_range(0.05, 0.6, 0.01, "suffix:m") var aim_tolerance: float = 0.3
@export_range(0.0, 10.0, 0.5) var jump_off_speed: float = 4.0

var player: CharacterBody3D
var strand: ToolStrand
var distance: float = 0.0
## Fastest the rope pulls the player back onto its length, in metres per second.
@export_range(0.5, 10.0, 0.5) var max_correction_speed: float = 4.0

var _ray := PhysicsRayQueryParameters3D.new()
var _grab_point: Vector3
var _pin_blend: float = 1.0
var _tension: float = 0.0
## Negative when not climbing.
var _saved_snap: float = -1.0


func _ready() -> void:
	player = get_parent() as CharacterBody3D
	_ray.exclude = [player.get_rid()]
	_ray.collision_mask = 1 | 2 | 16


func is_climbing() -> bool:
	return strand != null


func hand_position() -> Vector3:
	return player.global_position + player.up_direction * hand_height


## The climbable strand under the crosshair: {"strand", "distance"}, or empty.
func find_target(origin: Vector3, direction: Vector3) -> Dictionary:
	var world := ContraptionWorld.find(player)
	if world == null:
		return {}
	var best := {}
	var depth := reach
	for record in world.connections:
		var candidate := record.strand
		if not is_instance_valid(candidate) or candidate.broken or not candidate.climbable():
			continue
		for i in range(candidate.points.size() - 1):
			var hit := _closest_on_segment(origin, direction, candidate.points[i], candidate.points[i + 1])
			var along := (hit - origin).dot(direction)
			if along < 0.0 or along > depth or hit.distance_to(origin + direction * along) > aim_tolerance:
				continue
			_ray.from = origin
			_ray.to = hit
			var blocked := player.get_world_3d().direct_space_state.intersect_ray(_ray)
			if not blocked.is_empty() and blocked["position"].distance_to(hit) > 0.15:
				continue
			depth = along
			best = {"strand": candidate, "distance": candidate.nearest_distance(hit).x, "depth": along, "point": hit}
	return best


func grab(target: Dictionary) -> void:
	strand = target["strand"]
	distance = target["distance"]
	_grab_point = target.get("point", hand_position())
	strand.set_rider(distance, _grab_point)
	# Take hold low enough that the rope above reaches the hands without stretching.
	var supports := strand.rider_supports()
	if supports.size() == 2:
		var up_is_a: bool = supports[0]["position"].y >= supports[1]["position"].y
		var upper: Dictionary = supports[0] if up_is_a else supports[1]
		var short := hand_position().distance_to(upper["position"]) - float(upper["length"])
		if short > 0.0:
			distance = clampf(distance + (short if up_is_a else -short), 0.0, strand.rest_length)
			strand.rider_distance = distance
	_pin_blend = 0.0
	# Floor snapping would hold the player down against the rope's pull.
	_saved_snap = player.floor_snap_length
	player.floor_snap_length = 0.0
	_tension = 0.0


func release() -> void:
	if is_instance_valid(strand):
		strand.clear_rider()
		strand.rider_tension = 0.0
	if _saved_snap >= 0.0:
		player.floor_snap_length = _saved_snap
		_saved_snap = -1.0
	strand = null


func jump_off(look: Vector3) -> void:
	release()
	var push := look.slide(player.up_direction).normalized()
	player.velocity += player.up_direction * jump_off_speed * 0.8 + push * jump_off_speed * 0.6


func prompt() -> String:
	return "Climbing %s\n[W/S] Climb   [A/D] Swing   [Shift + W/S] Swing   [Space] Jump off   [E / Ctrl] Let go" % strand.record.definition.display_name.to_lower()


## Replaces the player's normal movement while climbing.
func physics_update(delta: float, input_dir: Vector2, swinging: bool) -> void:
	if not is_instance_valid(strand) or strand.broken or not strand.record.valid():
		release()
		return
	var supports := strand.rider_supports()
	if supports.size() < 2:
		release()
		return
	# supports[0] is the pin toward end A (less rope distance), supports[1] toward end B.
	# Up the rope means toward whichever of them hangs from higher up.
	var up_is_a: bool = supports[0]["position"].y >= supports[1]["position"].y
	var climb := 0.0 if swinging else -input_dir.y
	if climb != 0.0:
		var speed := climb_speed if climb > 0.0 else slide_speed
		distance += (-1.0 if up_is_a else 1.0) * climb * speed * delta
	# Keep the hands clear of the top and on the rope.
	if up_is_a:
		var top: float = strand.rider_distance - supports[0]["length"]
		distance = clampf(distance, minf(top + top_clearance, strand.rest_length), strand.rest_length)
	else:
		var top: float = strand.rider_distance + supports[1]["length"]
		distance = clampf(distance, 0.0, maxf(top - top_clearance, 0.0))

	var basis := player.global_transform.basis
	var push := basis.x * input_dir.x
	if swinging:
		push += basis.z * input_dir.y
	if player.is_on_floor():
		var flat := player.velocity.slide(player.up_direction).move_toward(Vector3.ZERO, 20.0 * delta)
		player.velocity = flat + player.up_direction * player.velocity.dot(player.up_direction)
		# Stepping back off a slack rope lets go.
		if input_dir.y > 0.5 and not swinging and _slack(strand.rider_supports()):
			release()
			return
	else:
		player.velocity += player.get_gravity() * delta
		player.velocity *= 1.0 - air_drag * delta
	player.velocity += push.slide(player.up_direction) * swing_acceleration * delta
	player.move_and_slide()

	# The rope above can't stretch: pull the player back onto it and its anchor toward them.
	strand.rider_distance = distance
	supports = strand.rider_supports()
	var tension := 0.0
	for pass_index in 2:
		for support in supports:
			tension = maxf(tension, _constrain(support, delta))
	# The rope eases into the hands rather than snapping there.
	_pin_blend = minf(1.0, _pin_blend + delta / 0.2)
	strand.rider_point = _grab_point.lerp(hand_position(), _pin_blend)
	# Smoothed so a single jerky frame doesn't count as an overload.
	_tension = lerpf(_tension, tension, 1.0 - exp(-6.0 * delta))
	strand.rider_tension = _tension


func _constrain(support: Dictionary, delta: float) -> float:
	var anchor: Vector3 = support["position"]
	var length: float = support["length"]
	var offset := hand_position() - anchor
	var gap := offset.length()
	if gap <= length or gap < 0.001:
		return 0.0
	var normal := offset / gap
	var attachment: AttachmentPoint = support["point"]
	var body := attachment.body() as RigidBody3D
	var dynamic := body != null and not body.freeze
	var share := 1.0
	var reduced := player_mass
	var anchor_velocity := Vector3.ZERO
	if dynamic:
		share = body.mass / (body.mass + player_mass)
		reduced = player_mass * body.mass / (player_mass + body.mass)
		anchor_velocity = body.linear_velocity + body.angular_velocity.cross(anchor - body.global_position)
	# Pulled back gradually: fast enough to follow climbing, never a teleport.
	player.move_and_collide(-normal * minf((gap - length) * share, max_correction_speed * delta))
	var closing := (player.velocity - anchor_velocity).dot(normal)
	if closing <= 0.0:
		return 0.0
	var impulse := reduced * closing
	player.velocity -= normal * impulse / player_mass
	if dynamic:
		body.apply_impulse(normal * impulse, anchor - body.global_position)
	return impulse / maxf(delta, 0.001)


func _slack(supports: Array[Dictionary]) -> bool:
	for support in supports:
		if hand_position().distance_to(support["position"]) > support["length"] - 0.05:
			return false
	return true


func _closest_on_segment(origin: Vector3, direction: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var segment := b - a
	var w := a - origin
	var aa := segment.dot(segment)
	var ab := segment.dot(direction)
	var aw := segment.dot(w)
	var bw := direction.dot(w)
	var denominator := aa - ab * ab
	var t := 0.0 if denominator < 0.000001 else clampf((ab * bw - aw) / denominator, 0.0, 1.0)
	return a + segment * t
