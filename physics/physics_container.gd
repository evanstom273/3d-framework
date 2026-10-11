class_name PhysicsContainer
extends Area3D
## Runtime side of a container. Contents stay in through real collision with the
## host body's walls; this only tracks which bodies are inside (for weight and
## spilling), and while the host is carried upright gently matches their motion to
## it so walking does not shake them out. Tilting past the limit or throwing the
## host turns that off, so contents slide and spill naturally.
## Works on any RigidBody3D host; the host may expose is_held() for carry detection.

var settings: PhysicsContainerDefinition
var _host: RigidBody3D
var _overlapping: Array[RigidBody3D] = []


func setup(host: RigidBody3D, container_settings: PhysicsContainerDefinition) -> void:
	_host = host
	settings = container_settings
	collision_layer = 0
	# Track the same kinds of bodies the host collides with, minus the player.
	collision_mask = host.collision_mask & ~8
	monitorable = false
	var volume := settings.build_volume_shape()
	var shape := CollisionShape3D.new()
	shape.shape = volume["shape"]
	shape.transform = volume["transform"]
	add_child(shape)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Rigid bodies currently resting inside (centre within the inner volume plus heap).
func get_contents() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	if _host == null:
		return result
	var to_local := _host.global_transform.affine_inverse()
	for body in _overlapping:
		if not is_instance_valid(body) or body == _host or body.freeze:
			continue
		if settings.contains_local_point(to_local * body.global_position):
			result.append(body)
	return result


## Mass of the contents, including anything nested in contained containers.
func get_contents_mass(depth: int = 0) -> float:
	var total := 0.0
	for body in get_contents():
		if depth < 4 and body.has_method("get_carried_mass"):
			total += float(body.call("get_carried_mass", depth + 1))
		else:
			total += body.mass
	return total


func _physics_process(delta: float) -> void:
	if _host == null or settings.carry_stabilisation <= 0.0:
		return
	var equipped_scoop: bool = settings.stabilise_when_equipped and _host is PhysicsProp and _host.hand_state == PhysicsProp.HandState.EQUIPPED
	if not equipped_scoop and not (_host.has_method("is_held") and bool(_host.call("is_held"))):
		return
	var min_upright := cos(deg_to_rad(settings.stabilise_max_tilt))
	var upright := _host.global_basis.y.normalized().dot(Vector3.UP)
	if upright <= min_upright:
		return
	# Fade out approaching the tilt limit, so spilling starts smoothly.
	var weight := clampf((upright - min_upright) / maxf(1.0 - min_upright, 0.001), 0.0, 1.0)
	var blend := 1.0 - exp(-settings.carry_stabilisation * weight * delta)
	var centre := _host.global_transform * _host.center_of_mass
	for body in get_contents():
		if body.has_method("is_held") and bool(body.call("is_held")):
			continue
		var carried := _host.linear_velocity + _host.angular_velocity.cross(body.global_position - centre)
		body.linear_velocity = body.linear_velocity.lerp(carried, blend)
		body.angular_velocity = body.angular_velocity.lerp(_host.angular_velocity, blend)


func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D and body != _host and not _overlapping.has(body):
		_overlapping.append(body)


func _on_body_exited(body: Node3D) -> void:
	# Static scenery can pass through the sensing area too; only rigid bodies are tracked.
	if body is RigidBody3D:
		_overlapping.erase(body)
