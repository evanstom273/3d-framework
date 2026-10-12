class_name ObjectManipulator
extends Node
## Physics-driven grab, carry, rotate and throw for RigidBody3D objects.
## A body can be grabbed when it, or an ancestor, is in the "grabbable" group or
## exposes can_be_grabbed(). Held bodies are steered by velocity changes capped by
## a force budget, so they keep colliding normally and heavy bodies respond slowly.
## Optional hooks on the provider: get_grab_name(), on_grabbed(holder),
## on_released(holder, thrown).

signal grabbed(body: RigidBody3D)
signal released(body: RigidBody3D, thrown: bool)

const GRABBABLE_GROUP := &"grabbable"
## End-over-end spin (rad/s) of a fully charged throw, before the feel profile.
const THROW_SPIN := 3.0

## The eye anchor the hold point is measured from. Using the head rather than the
## camera keeps headbob out of the held object.
@export var view: Node3D
@export var camera: Camera3D

@export_group("Carrying")
@export var max_carry_mass: float = 80.0
@export var min_hold_distance: float = 0.75
@export var max_hold_distance: float = 3.5
@export var scroll_step: float = 0.15
## How quickly the body closes the gap to the hold point (1/s).
@export var follow_stiffness: float = 14.0
@export var max_follow_speed: float = 14.0
## Carry strength in newtons. Gravity is paid from this budget, so heavy bodies sag.
@export var max_carry_force: float = 1400.0
## Caps how hard light bodies can shove things, since they need little force.
@export var max_carry_acceleration: float = 80.0
## Loose objects resting on a near-level surface of the held object (a ball in a
## broken crate, things on a plank or pallet) have their motion matched to it at
## this rate (1/s), so walking and sprinting don't shake them off. 0 disables.
@export_range(0.0, 40.0, 0.5) var passenger_stabilisation: float = 12.0
## Surfaces steeper than this don't hold passengers, so tipping still spills them.
@export_range(0.0, 89.0, 1.0, "suffix:°") var passenger_max_slope: float = 40.0
## Drop the body if it is snagged this far from the hold point for break_time.
@export var break_distance: float = 2.5
@export var break_time: float = 0.6

@export_group("Rotation")
@export var rotate_sensitivity: float = 0.006
@export var roll_step_degrees: float = 6.0
@export var rotation_stiffness: float = 16.0
@export var max_angular_speed: float = 12.0
@export var max_angular_acceleration: float = 120.0
## Bodies at or below this mass rotate at full rate; heavier bodies turn slower.
@export var reference_mass: float = 10.0
## Applied to rotation and scroll steps while the precision modifier is held.
@export_range(0.05, 1.0, 0.05) var precision_scale: float = 0.25

@export_group("Throwing")
## Impulse and speed limits of a throw at power 1. Charging scales them by power.
@export var throw_impulse: float = 80.0
@export var min_throw_speed: float = 2.0
@export var max_throw_speed: float = 16.0
## Seconds of holding the throw button to reach full charge. Zero throws instantly.
@export_range(0.0, 3.0, 0.05, "suffix:s") var throw_charge_time: float = 0.8
## Throw power of a quick tap.
@export_range(0.0, 3.0, 0.05) var min_throw_power: float = 0.3
## Throw power at full charge. Raise above 1 for stronger charged throws.
@export_range(0.1, 3.0, 0.05) var max_throw_power: float = 1.0
## How much of the held body's swing (from moving the mouse) is added to a throw.
@export_range(0.0, 2.0, 0.05) var flick_influence: float = 1.0
## Upper limit on the speed a flick adds.
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var max_flick_speed: float = 12.0
## How far the held body draws back toward you at full charge.
@export_range(0.0, 1.0, 0.01, "suffix:m") var charge_pullback: float = 0.25
## Released (not thrown) bodies keep at most this speed, so a strained hold does
## not fling them.
@export var drop_speed_limit: float = 6.0

## Set while the hand is busy with something else, such as an equipped tool.
var locked: bool = false
var _tool_control: bool = false
var _tool_saved: Vector3

var _holder: CollisionObject3D
var _body: RigidBody3D
var _provider: Node
var _hold_distance: float = 0.0
## Hold orientation relative to the holder's yaw, so turning carries it round.
var _hold_basis: Basis = Basis.IDENTITY
var _radius: float = 0.5
var _rotating: bool = false
var _charging: bool = false
var _charge_elapsed: float = 0.0
var _strain_time: float = 0.0
var _last_target: Vector3
var _saved_can_sleep: bool = true
var _saved_contact_monitor: bool = false
var _saved_max_contacts: int = 0
## Reused each tick by _stabilise_passengers.
var _passengers: Dictionary = {}
## Refreshed each tick so contents added or spilled change how the body handles.
var _carried_mass: float = 1.0
## Bodies still overlapping the holder after release keep ignoring it until clear.
var _lingering: Array[RigidBody3D] = []
var _overlap_query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	_holder = get_parent() as CollisionObject3D
	add_to_group(&"object_manipulators")
	# Fall back to the holder's own view nodes when the exports are not assigned.
	# The holder's @onready references only exist once it is ready itself.
	if camera == null or view == null:
		if not _holder.is_node_ready():
			await _holder.ready
		if camera == null:
			camera = _holder.get(&"camera") as Camera3D
		if view == null:
			view = _holder.get(&"head") as Node3D
	if camera == null:
		push_error("ObjectManipulator needs a camera assigned.")


func is_holding() -> bool:
	return is_instance_valid(_body)


func get_held_body() -> RigidBody3D:
	return _body if is_holding() else null


func is_rotating() -> bool:
	return is_holding() and _rotating


## Throw charge from 0 to 1, or -1 when not charging.
func get_charge_ratio() -> float:
	if not (is_holding() and _charging):
		return -1.0
	return clampf(_charge_elapsed / maxf(throw_charge_time, 0.001), 0.0, 1.0)


## Throws with power from the current charge (min_throw_power to max_throw_power).
func release_charged_throw() -> void:
	if is_holding() and _charging:
		release(true, lerpf(min_throw_power, max_throw_power, get_charge_ratio()))


## Returns the RigidBody3D that should be grabbed for a ray collider, or null.
func resolve_grabbable(collider: Object) -> RigidBody3D:
	var node := collider as Node
	# Something can stand in for what was aimed at (grabbing any part of an NPC
	# picks up the whole NPC): the first node up the tree offering a proxy decides.
	var ancestor := node
	while ancestor != null:
		if ancestor.has_method("get_grab_proxy"):
			var proxy: RigidBody3D = ancestor.call("get_grab_proxy", collider)
			if proxy != null:
				return proxy
			break
		ancestor = ancestor.get_parent()
	var body: RigidBody3D = null
	while node != null:
		if body == null and node is RigidBody3D:
			body = node
		if node.has_method("can_be_grabbed"):
			return body if body != null and bool(node.call("can_be_grabbed")) else null
		if node.is_in_group(GRABBABLE_GROUP):
			return body
		node = node.get_parent()
	return null


func is_too_heavy(body: RigidBody3D) -> bool:
	return get_carried_mass(body) > max_carry_mass


## The body's mass plus anything it carries, e.g. a container's contents.
func get_carried_mass(body: RigidBody3D) -> float:
	var world := ContraptionWorld.find(body)
	if world != null: return world.assembly_mass(body)
	var provider := _find_provider(body)
	if provider != null and provider.has_method("get_carried_mass"):
		return float(provider.call("get_carried_mass"))
	return body.mass


func get_grab_name(body: RigidBody3D) -> String:
	var provider := _find_provider(body)
	if provider != null and provider.has_method("get_grab_name"):
		return str(provider.call("get_grab_name"))
	return str(body.name).capitalize()


func get_grab_prompt(body: RigidBody3D) -> String:
	if is_too_heavy(body):
		return "%s (too heavy)" % get_grab_name(body)
	return "[E] Pick up %s" % get_grab_name(body)


## extra_hint lets other hand systems add their keys, e.g. "[F] Equip".
func get_hold_prompt(extra_hint: String = "") -> String:
	if not is_holding():
		return ""
	var title := get_grab_name(_body)
	if _provider != null and _provider.has_method("get_status_text"):
		var status := str(_provider.call("get_status_text"))
		if not status.is_empty():
			title += " (%s)" % status
	var keys := "[E] Drop   [Hold LMB] Throw   [MMB + Mouse] Rotate   [MMB + Wheel] Roll   [Wheel] Distance   [Alt] Fine"
	if not extra_hint.is_empty():
		keys = extra_hint + "   " + keys
	return "%s\n%s" % [title, keys]


func can_grab(body: RigidBody3D) -> bool:
	if (locked and not _tool_control) or camera == null or body == null or is_holding() or body.freeze or is_too_heavy(body):
		return false
	var world := ContraptionWorld.find(body)
	if world != null and world.anchored(body): return false
	# Lifting the body you are standing on would pull it out from under you.
	var character := _holder as CharacterBody3D
	if character != null and character.is_on_floor():
		for index in character.get_slide_collision_count():
			var hit := character.get_slide_collision(index)
			if hit.get_collider() == body and hit.get_normal().dot(character.up_direction) > 0.7:
				return false
	return true


func grab(body: RigidBody3D) -> bool:
	if not can_grab(body):
		return false
	var world := ContraptionWorld.find(body)
	if world != null: world.detach_suction(body)
	_body = body
	_provider = _find_provider(body)
	_lingering.erase(body)
	_radius = _estimate_radius(body)
	_hold_distance = clampf(_eye_position().distance_to(body.global_position), _min_distance(), max_hold_distance)
	_hold_basis = _yaw_basis().inverse() * body.global_basis.orthonormalized()
	_last_target = _compute_target()
	_strain_time = 0.0
	_rotating = false
	_saved_can_sleep = body.can_sleep
	body.can_sleep = false
	# Report enough contacts to find everything riding on or in the held object.
	_saved_contact_monitor = body.contact_monitor
	_saved_max_contacts = body.max_contacts_reported
	body.contact_monitor = true
	body.max_contacts_reported = maxi(_saved_max_contacts, 16)
	body.sleeping = false
	# The holder must not collide with what it carries, or the two push each other.
	_set_holder_exception(body, true)
	if not body.tree_exiting.is_connected(_on_body_tree_exiting):
		body.tree_exiting.connect(_on_body_tree_exiting)
	if _provider != null and _provider.has_method("on_grabbed"):
		_provider.call("on_grabbed", _holder)
	grabbed.emit(body)
	return true


## power scales a throw's speed (1 = the configured throw).
func release(throw: bool = false, power: float = 1.0) -> void:
	_charging = false
	if not is_holding():
		_body = null
		return
	var body := _body
	_body = null
	_rotating = false
	body.can_sleep = _saved_can_sleep
	body.max_contacts_reported = _saved_max_contacts
	body.contact_monitor = _saved_contact_monitor
	if body.tree_exiting.is_connected(_on_body_tree_exiting):
		body.tree_exiting.disconnect(_on_body_tree_exiting)
	if throw:
		var feel := PhysicsFeel.get_active()
		var carried_mass := get_carried_mass(body)
		# How charged the throw was (0 = tap, 1 = full); the feel profile's extra
		# energy only applies as the charge builds.
		var charge := 1.0
		if max_throw_power > min_throw_power:
			charge = clampf(inverse_lerp(min_throw_power, max_throw_power, power), 0.0, 1.0)
		var speed := clampf(throw_impulse / carried_mass, min_throw_speed, max_throw_speed) * power
		speed *= lerpf(1.0, feel.throw_multiplier, charge)
		var before := body.linear_velocity
		var carried := _holder_velocity()
		# Keep the swing the mouse gave it, so flicking while throwing launches it that way.
		var flick := ((before - carried) * flick_influence).limit_length(max_flick_speed)
		var forward := -camera.global_basis.z
		body.linear_velocity = carried + forward * speed + flick
		body.angular_velocity = body.angular_velocity.limit_length(2.0)
		# A charged throw tumbles end over end; light objects more, heavy ones barely.
		var spin_axis := Vector3.UP.cross(forward)
		if spin_axis.length_squared() > 0.01:
			var weight_factor := clampf(sqrt(reference_mass / carried_mass), 0.3, 1.0)
			body.angular_velocity += spin_axis.normalized() * THROW_SPIN * feel.angular_impulse_multiplier * charge * weight_factor
		# Contents leave with the container and spill when it lands, not at the hand.
		if _provider != null and _provider.has_method("get_contents"):
			for content: RigidBody3D in _provider.call("get_contents"):
				content.linear_velocity += body.linear_velocity - before
	else:
		body.linear_velocity = body.linear_velocity.limit_length(drop_speed_limit)
		# Zero spin so the body lands in the orientation it was placed in.
		body.angular_velocity = Vector3.ZERO
	if body.is_inside_tree() and _overlaps_holder(body):
		_lingering.append(body)
	else:
		_set_holder_exception(body, false)
	if _provider != null and is_instance_valid(_provider) and _provider.has_method("on_released"):
		_provider.call("on_released", _holder, throw)
	_provider = null
	released.emit(body, throw)


## Hands the held body to another system (e.g. equipping) without dropping it:
## no velocity changes, and the holder's collision exception is cleared.
func take_held_body() -> RigidBody3D:
	if not is_holding():
		return null
	var body := _body
	_body = null
	_rotating = false
	_charging = false
	body.can_sleep = _saved_can_sleep
	body.max_contacts_reported = _saved_max_contacts
	body.contact_monitor = _saved_contact_monitor
	if body.tree_exiting.is_connected(_on_body_tree_exiting):
		body.tree_exiting.disconnect(_on_body_tree_exiting)
	_lingering.erase(body)
	_set_holder_exception(body, false)
	if _provider != null and is_instance_valid(_provider) and _provider.has_method("on_released"):
		_provider.call("on_released", _holder, false)
	_provider = null
	released.emit(body, false)
	return body


## Returns true when the event was consumed by the held object.
func handle_input(event: InputEvent) -> bool:
	if not is_holding():
		return false
	if event.is_action("rotate_held_object"):
		_rotating = event.is_pressed()
		return true
	if event is InputEventMouseMotion and _rotating:
		var turn: Vector2 = event.screen_relative * rotate_sensitivity * _precision()
		var cam := camera.global_basis.orthonormalized()
		_rotate_world(Basis(cam.y, turn.x) * Basis(cam.x, turn.y))
		return true
	if event.is_action("throw_held_object"):
		if event.is_pressed() and not event.is_echo():
			if throw_charge_time <= 0.0:
				release(true, max_throw_power)
			else:
				_charging = true
				_charge_elapsed = 0.0
		elif not event.is_pressed():
			release_charged_throw()
		return true
	var scroll := 0.0
	if event.is_action("hold_farther"):
		scroll = 1.0
	elif event.is_action("hold_closer"):
		scroll = -1.0
	if scroll != 0.0:
		if event.is_pressed():
			var factor: float = event.factor if event is InputEventMouseButton and event.factor > 0.0 else 1.0
			if _rotating:
				var roll := deg_to_rad(roll_step_degrees) * scroll * factor * _precision()
				_rotate_world(Basis(camera.global_basis.z.normalized(), roll))
			else:
				_hold_distance = clampf(_hold_distance + scroll_step * scroll * factor * _precision(), _min_distance(), max_hold_distance)
		return true
	return false


## Called by the holder after it has moved this tick, so the hold point is current.
func physics_update(delta: float) -> void:
	_update_lingering()
	if not is_holding():
		return
	if _rotating and not Input.is_action_pressed("rotate_held_object"):
		_rotating = false
	if _charging:
		_charge_elapsed += delta
		# A release event can be missed (e.g. focus loss); the button state is authoritative.
		if not Input.is_action_pressed("throw_held_object"):
			release_charged_throw()
			return
	var target := _compute_target()
	var target_velocity := (target - _last_target) / delta
	_last_target = target
	var error := target - _body.global_position
	if error.length() > break_distance:
		_strain_time += delta
		if _strain_time >= break_time:
			release()
			return
	else:
		_strain_time = 0.0
	_carried_mass = get_carried_mass(_body)
	_steer_linear(error, target_velocity, delta)
	_steer_angular(delta)
	_stabilise_passengers(delta)


func _steer_linear(error: Vector3, target_velocity: Vector3, delta: float) -> void:
	# The feel profile sharpens following and the light-object acceleration cap, but
	# never the carry force, so heavy objects keep their weight.
	var response := PhysicsFeel.get_active().held_responsiveness
	var top_speed := max_follow_speed * sqrt(response)
	var desired := (target_velocity.limit_length(top_speed) + error * follow_stiffness * response).limit_length(top_speed)
	# Pre-cancel the gravity the solver adds this step; it is paid from the force budget.
	var change := desired - _body.linear_velocity - _body.get_gravity() * _body.gravity_scale * delta
	var max_acceleration := minf(max_carry_force / _carried_mass, max_carry_acceleration * response)
	var world := ContraptionWorld.find(_body)
	if world != null and world.members(_body).size() > 1:
		_body.apply_central_impulse(change.limit_length(max_acceleration * delta) * _carried_mass)
	else:
		_body.linear_velocity += change.limit_length(max_acceleration * delta)


func begin_tool_control(body: RigidBody3D, reach: float, mass_limit: float, force: float) -> bool:
	if not _tool_control:
		_tool_saved = Vector3(max_hold_distance, max_carry_mass, max_carry_force)
	_tool_control = true
	max_hold_distance = reach; max_carry_mass = mass_limit; max_carry_force = force
	if grab(body): return true
	end_tool_control()
	return false


func end_tool_control() -> void:
	if not _tool_control: return
	release()
	max_hold_distance = _tool_saved.x; max_carry_mass = _tool_saved.y; max_carry_force = _tool_saved.z
	_tool_control = false


func _steer_angular(delta: float) -> void:
	var target_basis := _yaw_basis() * _hold_basis
	var current := _body.global_basis.orthonormalized().get_rotation_quaternion()
	var difference := (target_basis.get_rotation_quaternion() * current.inverse()).normalized()
	if difference.w < 0.0:
		difference = -difference
	var angle := difference.get_angle()
	var desired := Vector3.ZERO
	var mass_factor := clampf(sqrt(reference_mass / _carried_mass), 0.3, 1.0)
	var response := PhysicsFeel.get_active().held_responsiveness
	if angle > 0.0001:
		desired = difference.get_axis() * angle * rotation_stiffness * response * mass_factor
		desired = desired.limit_length(max_angular_speed * sqrt(response) * mass_factor)
	var change := desired - _body.angular_velocity
	_body.angular_velocity += change.limit_length(max_angular_acceleration * response * mass_factor * delta)


## Matches the motion of loose objects resting on the held object to it, so they
## ride along. Only contacts on near-level surfaces count (with the passenger above
## the contact), so walls still have to hold things in and tipping still spills.
func _stabilise_passengers(delta: float) -> void:
	if passenger_stabilisation <= 0.0:
		return
	var state := PhysicsServer3D.body_get_direct_state(_body.get_rid())
	if state == null:
		return
	var min_level := cos(deg_to_rad(passenger_max_slope))
	var blend := 1.0 - exp(-passenger_stabilisation * delta)
	var centre := state.transform.origin + state.center_of_mass
	_passengers.clear()
	for index in state.get_contact_count():
		var other := state.get_contact_collider_object(index) as RigidBody3D
		if other == null or other.freeze or _passengers.has(other):
			continue
		if other.has_method("is_held") and bool(other.call("is_held")):
			continue
		var normal := state.get_contact_local_normal(index)
		var point := state.get_contact_local_position(index)
		if absf(normal.y) < min_level or other.global_position.y < point.y:
			continue
		_passengers[other] = true
		var carried := state.linear_velocity + state.angular_velocity.cross(other.global_position - centre)
		other.linear_velocity = other.linear_velocity.lerp(carried, blend)
		other.angular_velocity = other.angular_velocity.lerp(state.angular_velocity, blend)


func _compute_target() -> Vector3:
	var origin := _eye_position()
	var forward := -camera.global_basis.z.normalized()
	var distance := _hold_distance
	if _charging:
		distance = maxf(_min_distance(), distance - charge_pullback * get_charge_ratio())
	# Keep the hold point on this side of walls, so the body is never pulled into them.
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * distance, _body.collision_mask)
	query.exclude = [_holder.get_rid(), _body.get_rid()]
	var hit := _body.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		distance = maxf(_min_distance(), origin.distance_to(hit.position) - 0.05)
	return origin + forward * distance


func _rotate_world(rotation: Basis) -> void:
	var yaw := _yaw_basis()
	_hold_basis = (yaw.inverse() * rotation * yaw * _hold_basis).orthonormalized()


func _yaw_basis() -> Basis:
	return _holder.global_basis.orthonormalized()


func _eye_position() -> Vector3:
	return view.global_position if view != null else camera.global_position


func _min_distance() -> float:
	return minf(min_hold_distance + _radius * 0.5, max_hold_distance)


func _precision() -> float:
	return precision_scale if Input.is_action_pressed("precision_modifier") else 1.0


func _holder_velocity() -> Vector3:
	if _holder is CharacterBody3D:
		return (_holder as CharacterBody3D).get_real_velocity()
	if _holder is RigidBody3D:
		return (_holder as RigidBody3D).linear_velocity
	return Vector3.ZERO


func _find_provider(body: Node) -> Node:
	var node := body
	while node != null:
		if node.has_method("can_be_grabbed") or node.is_in_group(GRABBABLE_GROUP):
			return node
		node = node.get_parent()
	return body


func _estimate_radius(body: RigidBody3D) -> float:
	if body is VoxelBody:
		var voxel_body := body as VoxelBody
		return voxel_body.get_cell_bounds().size.length() * voxel_body.voxel_size * 0.5 if not voxel_body.cells.is_empty() else 0.5
	var bounds := AABB()
	var found := false
	for owner_id in body.get_shape_owners():
		var shape_transform := body.shape_owner_get_transform(owner_id)
		for index in body.shape_owner_get_shape_count(owner_id):
			var shape := body.shape_owner_get_shape(owner_id, index)
			var shape_bounds := shape_transform * shape.get_debug_mesh().get_aabb()
			bounds = shape_bounds if not found else bounds.merge(shape_bounds)
			found = true
	return bounds.size.length() * 0.5 if found else 0.5


func _set_holder_exception(body: RigidBody3D, enabled: bool) -> void:
	if not is_instance_valid(body) or not (_holder is PhysicsBody3D):
		return
	var holder := _holder as PhysicsBody3D
	if enabled:
		body.add_collision_exception_with(holder)
		holder.add_collision_exception_with(body)
	else:
		body.remove_collision_exception_with(holder)
		holder.remove_collision_exception_with(body)


func _overlaps_holder(body: RigidBody3D) -> bool:
	var space := body.get_world_3d().direct_space_state
	for owner_id in _holder.get_shape_owners():
		if _holder.is_shape_owner_disabled(owner_id):
			continue
		for index in _holder.shape_owner_get_shape_count(owner_id):
			_overlap_query.shape = _holder.shape_owner_get_shape(owner_id, index)
			_overlap_query.transform = _holder.global_transform * _holder.shape_owner_get_transform(owner_id)
			_overlap_query.collision_mask = body.collision_layer
			_overlap_query.exclude = [_holder.get_rid()]
			for result in space.intersect_shape(_overlap_query, 16):
				if result.get("collider") == body:
					return true
	return false


func _update_lingering() -> void:
	for index in range(_lingering.size() - 1, -1, -1):
		var body := _lingering[index]
		if not is_instance_valid(body) or not body.is_inside_tree():
			_lingering.remove_at(index)
		elif not _overlaps_holder(body):
			_set_holder_exception(body, false)
			_lingering.remove_at(index)


func _on_body_tree_exiting() -> void:
	release()
