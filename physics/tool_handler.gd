class_name ToolHandler
extends Node
## Equips tool objects into a first-person hold and runs their primary actions.
## Shares the holder's single hand with ObjectManipulator: one RigidBody3D moves
## between world, held and equipped states and is never duplicated. Equipped tools
## are frozen kinematic bodies with collision off (so they cannot shove the player
## or snag on walls); strikes are found by sweeping the tool's own strike point.
## Any body whose provider returns a PhysicsToolDefinition from
## get_tool_definition() can be equipped; providers may implement
## on_equipped(holder) and on_unequipped(holder).

signal equipped(body: RigidBody3D)
signal unequipped(body: RigidBody3D)
signal impacted(impact: ToolImpact)

@export var manipulator: ObjectManipulator
## The eye anchor poses are measured from (the head, so headbob is ignored).
@export var view: Node3D
## How quickly an equipped tool catches up with the camera when turning (1/s).
## Higher is tighter; 0 glues the tool to the camera.
@export_range(0.0, 60.0, 0.5) var sway_response: float = 16.0
## The furthest an equipped tool can trail behind the camera. 0 disables sway.
@export_range(0.0, 30.0, 0.5, "suffix:°") var max_sway_degrees: float = 8.0

var _holder: CollisionObject3D
var _tool: RigidBody3D
var _provider: Node
var _settings: PhysicsToolDefinition
var _saved_layer: int = 0
var _saved_mask: int = 0
var _saved_freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC
var _equip_progress: float = 1.0
var _equip_from: Transform3D
## Seconds into the current action, or negative when idle.
var _action_time: float = -1.0
var _charging: bool = false
var _charge_elapsed: float = 0.0
## Power of the current action, fixed when the charge is released.
var _power: float = 1.0
## Ghost box for placing tools.
var _preview: MeshInstance3D
var _last_strike_point: Vector3
var _tracking_strike_point: bool = false
var _motion_cooldown: float = 0.0
var _sway: Quaternion = Quaternion.IDENTITY
var _sway_ready: bool = false
var _hit_done: bool = false
var _query := PhysicsShapeQueryParameters3D.new()
var _sphere := SphereShape3D.new()
var _advanced: AdvancedToolRuntime
var _alternate: bool = false


func _ready() -> void:
	_holder = get_parent() as CollisionObject3D
	add_to_group(&"tool_handlers")
	if view == null:
		if not _holder.is_node_ready():
			await _holder.ready
		view = _holder.get(&"head") as Node3D
	if manipulator == null:
		manipulator = _holder.get_node_or_null(^"ObjectManipulator") as ObjectManipulator
	set_process(false)


func is_equipped() -> bool:
	return is_instance_valid(_tool)


func get_equipped_body() -> RigidBody3D:
	return _tool if is_equipped() else null


func is_busy() -> bool:
	return is_equipped() and (_action_time >= 0.0 or _equip_progress < 1.0)


func get_tool_definition(body: RigidBody3D) -> PhysicsToolDefinition:
	var node: Node = body
	while node != null:
		if node.has_method("get_tool_definition"):
			return node.call("get_tool_definition") as PhysicsToolDefinition
		node = node.get_parent()
	return null


func can_equip(body: RigidBody3D) -> bool:
	if body != null:
		var world := ContraptionWorld.find(body)
		if world != null and world.attached(body): return false
	return body != null and view != null and not is_equipped() and get_tool_definition(body) != null


## Key hint for prompts about a body in or near the hand, or "".
func get_equip_hint(body: RigidBody3D) -> String:
	return "[F] Equip" if can_equip(body) else ""


func get_prompt() -> String:
	if not is_equipped():
		return ""
	var title := str(_provider.call("get_grab_name")) if _provider.has_method("get_grab_name") else str(_tool.name)
	if _advanced != null:
		return "%s (equipped)\n%s" % [title, _advanced.prompt(_settings.alternate_action != null)]
	var use := "[Hold LMB]" if _settings.charge_time > 0.0 else "[LMB]"
	return "%s (equipped)\n%s %s   [F] Unequip   [E] Drop%s" % [title, use, _settings.action_name, "   [Q] Pry mode" if _settings.alternate_action != null else ""]


## Equips the body currently held by the manipulator.
func equip_held() -> bool:
	var body := manipulator.get_held_body()
	if not can_equip(body):
		return false
	_equip(manipulator.take_held_body())
	return true


## Equips a body straight from the world, when the hand is empty.
func equip(body: RigidBody3D) -> bool:
	if manipulator.is_holding() or not can_equip(body) or body.freeze:
		return false
	_equip(body)
	return true


## Returns the tool to ordinary physical manipulation in the hand.
func unequip() -> void:
	var body := _release_tool()
	if body != null and not manipulator.grab(body):
		body.linear_velocity = _holder_velocity()


## Unequips and lets go, leaving the tool to world physics.
func drop() -> void:
	var body := _release_tool()
	if body == null:
		return
	if manipulator.grab(body):
		manipulator.release()
	else:
		body.linear_velocity = _holder_velocity()


## Starts the primary action immediately at the given power. Ignored while busy.
func use_primary(power: float = 1.0) -> bool:
	if not is_equipped() or is_busy():
		return false
	if _advanced != null:
		_advanced.press_primary()
		return true
	if _is_placing():
		var target := _place_target()
		if target.is_empty() or not target["valid"]:
			return false
		VoxelConstruction.place(target, _settings.place_material, _holder.get_parent())
	_action_time = 0.0
	_hit_done = false
	_charging = false
	_power = power
	return true


## Starts winding up; the strike happens on release_charge(), scaled by how long
## it was held. Tools with no charge time strike straight away at max power.
func begin_charge() -> bool:
	if not is_equipped() or is_busy():
		return false
	if _settings.charge_time <= 0.0:
		return use_primary(_settings.max_charge_power)
	use_primary()
	_charging = true
	_charge_elapsed = 0.0
	return true


func release_charge() -> void:
	if not _charging:
		return
	_charging = false
	_power = lerpf(_settings.min_charge_power, _settings.max_charge_power, get_charge_ratio_unchecked())


## Charge from 0 to 1, or -1 when not charging.
func get_charge_ratio() -> float:
	return get_charge_ratio_unchecked() if is_equipped() and _charging else -1.0


func get_charge_ratio_unchecked() -> float:
	return clampf(_charge_elapsed / maxf(_settings.charge_time, 0.001), 0.0, 1.0)


func cancel_action() -> void:
	if _advanced != null: _advanced.stop()
	_action_time = -1.0
	_charging = false


## Returns true when the event was consumed by the equipped tool.
func handle_input(event: InputEvent) -> bool:
	if not is_equipped():
		return false
	if _settings.alternate_action != null and event.is_action_pressed("tool_mode"):
		cancel_action()
		_alternate = not _alternate
		_tool.set_meta(&"alternate_tool_mode", _alternate)
		_bind_advanced()
		return true
	if _advanced != null: return _advanced.input(event)
	if event.is_action("use_tool"):
		if event.is_pressed() and not event.is_echo():
			begin_charge()
		elif not event.is_pressed():
			release_charge()
		return true
	return false


## Called by the holder after it has moved this tick.
func physics_update(delta: float) -> void:
	if not is_equipped():
		return
	_equip_progress = minf(1.0, _equip_progress + delta / maxf(_settings.equip_time, 0.01))
	if _advanced != null:
		_tool.global_transform = _current_transform(0.0)
		_advanced.tick(delta)
		return
	if _charging:
		_charge_elapsed += delta
		# A release event can be missed (e.g. focus loss); the button state is authoritative.
		if not Input.is_action_pressed("use_tool"):
			release_charge()
	if _action_time >= 0.0:
		var previous := _action_time
		_action_time += delta
		if _charging:
			# Hold at the top of the windup until the button is released.
			_action_time = minf(_action_time, _settings.windup_time)
		var strike_start := _settings.windup_time
		var strike_end := strike_start + _settings.strike_time
		# Placing tools act when used, so only striking tools look for hits.
		var strikes := not _is_placing()
		if strikes and _settings.hit_detection == PhysicsToolDefinition.HitDetection.CROSSHAIR:
			var impact_at := strike_start + _settings.strike_time * _settings.impact_moment
			if not _hit_done and previous < impact_at and _action_time >= impact_at:
				_crosshair_hit(impact_at)
		elif strikes and not _hit_done and _action_time > strike_start and previous < strike_end:
			_sweep(clampf(previous, strike_start, strike_end), clampf(_action_time, strike_start, strike_end))
		if _action_time >= _settings.get_total_action_time():
			_action_time = -1.0
	# Placing tools keep building while the button is held, one voxel per cycle.
	if _is_placing() and _action_time < 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and Input.is_action_pressed("use_tool"):
		use_primary()
	_update_motion_strike(delta)
	_tool.global_transform = _current_transform(0.0)


func _is_placing() -> bool:
	return _settings != null and _settings.primary_action == PhysicsToolDefinition.PrimaryAction.PLACE_VOXEL


func _place_target() -> Dictionary:
	var aim := _crosshair_transform()
	var exclude: Array[RID] = [_holder.get_rid(), _tool.get_rid()]
	return VoxelConstruction.find_place_target(_tool.get_world_3d(), aim.origin, -aim.basis.z.normalized(),
		_settings.reach, exclude, _settings.place_voxel_size)


## Translucent box showing where the next voxel goes: green if it fits, red if blocked.
func _update_place_preview() -> void:
	if not (is_equipped() and _is_placing()):
		if _preview != null:
			_preview.hide()
		return
	var target := _place_target()
	if target.is_empty():
		if _preview != null:
			_preview.hide()
		return
	if _preview == null:
		_preview = MeshInstance3D.new()
		_preview.mesh = BoxMesh.new()
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = false
		_preview.material_override = material
		_preview.top_level = true
		_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_preview)
	(_preview.mesh as BoxMesh).size = Vector3.ONE * float(target["size"]) * 1.02
	(_preview.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.4, 0.35) if target["valid"] else Color(1.0, 0.25, 0.2, 0.35)
	_preview.global_transform = target["transform"]
	_preview.show()


func _process(delta: float) -> void:
	if not is_equipped():
		set_process(false)
		return
	_update_sway(delta)
	# Render between physics ticks so the tool stays glued to the camera at any frame rate.
	var ahead := Engine.get_physics_interpolation_fraction() / Engine.physics_ticks_per_second
	_tool.global_transform = _current_transform(ahead)
	_update_place_preview()


func _equip(body: RigidBody3D) -> void:
	_tool = body
	_provider = _find_provider(body)
	_settings = get_tool_definition(body)
	_saved_layer = body.collision_layer
	_saved_mask = body.collision_mask
	_saved_freeze_mode = body.freeze_mode
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	_equip_from = body.global_transform
	_equip_progress = 0.0
	_tracking_strike_point = false
	_sway_ready = false
	_action_time = -1.0
	manipulator.locked = true
	if not body.tree_exiting.is_connected(_on_tool_tree_exiting):
		body.tree_exiting.connect(_on_tool_tree_exiting)
	if _provider.has_method("on_equipped"):
		_provider.call("on_equipped", _holder)
	_alternate = bool(body.get_meta(&"alternate_tool_mode", false))
	_bind_advanced()
	if body is PhysicsProp: body.set_equipped_collisions(true)
	# Tools that stay solid while equipped (the shovel's scoop) must never shove their holder.
	body.add_collision_exception_with(_holder)
	_holder.add_collision_exception_with(body)
	set_process(true)
	equipped.emit(body)


func _release_tool() -> RigidBody3D:
	if not is_equipped():
		return null
	var body := _tool
	if _advanced != null: _advanced.unbind(); _advanced = null
	if body is PhysicsProp: body.set_equipped_collisions(false)
	body.remove_collision_exception_with(_holder)
	_holder.remove_collision_exception_with(body)
	_tool = null
	_action_time = -1.0
	_charging = false
	if _preview != null:
		_preview.hide()
	manipulator.locked = false
	if body.tree_exiting.is_connected(_on_tool_tree_exiting):
		body.tree_exiting.disconnect(_on_tool_tree_exiting)
	body.collision_layer = _saved_layer
	body.collision_mask = _saved_mask
	body.freeze = false
	body.freeze_mode = _saved_freeze_mode
	body.sleeping = false
	if is_instance_valid(_provider) and _provider.has_method("on_unequipped"):
		_provider.call("on_unequipped", _holder)
	_provider = null
	set_process(false)
	unequipped.emit(body)
	return body


func _current_transform(ahead: float) -> Transform3D:
	var time := _action_time + ahead if _action_time >= 0.0 else -1.0
	if _charging:
		time = minf(time, _settings.windup_time)
	var target: Transform3D
	if _advanced != null:
		# Advanced tools blend between their rest and use poses, with recoil and vibration.
		var grip := Transform3D(Basis.from_euler(_settings.grip_rotation_degrees * (PI / 180.0)), _settings.grip_position)
		target = _anchor() * _advanced.hand_pose(_settings) * grip.affine_inverse()
	else:
		target = _tool_transform_at(time)
	var progress := minf(1.0, _equip_progress + ahead / maxf(_settings.equip_time, 0.01))
	if progress >= 1.0:
		return target
	var blend := smoothstep(0.0, 1.0, progress)
	return Transform3D(
		_equip_from.basis.orthonormalized().slerp(target.basis.orthonormalized(), blend),
		_equip_from.origin.lerp(target.origin, blend))


func _bind_advanced() -> void:
	if _advanced != null: _advanced.unbind(); _advanced = null
	var definition := _settings.alternate_action if _alternate else _settings.advanced_action
	if definition == null: return
	_advanced = _tool.get_node_or_null("AdvancedAction") as AdvancedToolRuntime
	if _advanced == null:
		_advanced = AdvancedToolRuntime.new()
		_advanced.name = "AdvancedAction"
		_tool.add_child(_advanced)
	_advanced.bind(self, definition)


## The anchor follows yaw fully and pitch by the tool's pitch_follow, trailing a
## little behind fast turns (sway) so the tool feels held rather than glued on.
func _anchor() -> Transform3D:
	var rotation := _sway if _sway_ready else _target_anchor_rotation()
	return Transform3D(Basis(rotation), view.global_position)


func _target_anchor_rotation() -> Quaternion:
	var yaw := Quaternion(_holder.global_basis.orthonormalized())
	var look := Quaternion(view.global_basis.orthonormalized())
	return yaw.slerp(look, _settings.pitch_follow)


## Eases the sway toward the view each frame, never trailing more than max_sway_degrees.
func _update_sway(delta: float) -> void:
	var target := _target_anchor_rotation()
	if not _sway_ready or sway_response <= 0.0 or max_sway_degrees <= 0.0:
		_sway = target
		_sway_ready = true
		return
	_sway = _sway.slerp(target, 1.0 - exp(-sway_response * delta))
	var lag := (target.inverse() * _sway).get_angle()
	var limit := deg_to_rad(max_sway_degrees)
	if lag > limit:
		_sway = target.slerp(_sway, limit / lag)


func _tool_transform_at(time: float) -> Transform3D:
	var grip := Transform3D(Basis.from_euler(_settings.grip_rotation_degrees * (PI / 180.0)), _settings.grip_position)
	return _anchor() * _hand_pose_at(time) * grip.affine_inverse()


func _hand_pose_at(time: float) -> Transform3D:
	var s := _settings
	var from_position := s.rest_position
	var from_rotation := s.rest_rotation_degrees
	var to_position := s.rest_position
	var to_rotation := s.rest_rotation_degrees
	var weight := 0.0
	if time >= 0.0:
		if time < s.windup_time:
			to_position = s.windup_position
			to_rotation = s.windup_rotation_degrees
			weight = ease(time / s.windup_time, 0.5)
		elif time < s.windup_time + s.strike_time:
			from_position = s.windup_position
			from_rotation = s.windup_rotation_degrees
			to_position = s.strike_position
			to_rotation = s.strike_rotation_degrees
			weight = ease((time - s.windup_time) / s.strike_time, 1.8)
		elif time < s.windup_time + s.strike_time + s.recover_time:
			from_position = s.strike_position
			from_rotation = s.strike_rotation_degrees
			weight = smoothstep(0.0, 1.0, (time - s.windup_time - s.strike_time) / s.recover_time)
	# Interpolating angles (not quaternions) keeps long swings on their authored path.
	var rotation := from_rotation.lerp(to_rotation, weight) * (PI / 180.0)
	return Transform3D(Basis.from_euler(rotation), from_position.lerp(to_position, weight))


func _strike_point_at(time: float) -> Vector3:
	return _tool_transform_at(time) * _settings.strike_point


## Hits what the crosshair is on: an exact ray first, then a wider sphere as aim assist.
func _crosshair_hit(impact_time: float) -> void:
	_hit_done = true
	var aim := _crosshair_transform()
	var forward := -aim.basis.z.normalized()
	var space := _tool.get_world_3d().direct_space_state
	var exclude: Array[RID] = [_holder.get_rid(), _tool.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin + forward * _settings.reach, _settings.hit_mask, exclude)
	var hit := space.intersect_ray(ray)
	var point: Vector3
	var normal: Vector3
	if not hit.is_empty():
		point = hit["position"]
		normal = hit["normal"]
	elif _settings.aim_assist_radius > 0.0:
		_sphere.radius = _settings.aim_assist_radius
		_query.shape = _sphere
		_query.collision_mask = _settings.hit_mask
		_query.exclude = exclude
		_query.transform = Transform3D(Basis(), aim.origin)
		_query.motion = forward * (_settings.reach - _settings.aim_assist_radius)
		var fractions := space.cast_motion(_query)
		if fractions.is_empty() or fractions[1] >= 1.0:
			return
		_query.transform = Transform3D(Basis(), aim.origin + _query.motion * fractions[1])
		_query.motion = Vector3.ZERO
		hit = space.get_rest_info(_query)
		if hit.is_empty():
			return
		hit["collider"] = instance_from_id(hit["collider_id"])
		point = hit["point"]
		normal = hit["normal"]
	else:
		return
	var collider: Object = hit["collider"]
	if collider == null:
		return
	# Report the swing's own direction and speed, so impacts still feel like the tool's.
	var step := 1.0 / Engine.physics_ticks_per_second
	var path := _strike_point_at(impact_time) - _strike_point_at(impact_time - step)
	_register_hit(collider, point, normal, path.normalized() if not path.is_zero_approx() else forward, path.length() / step)


## Where the crosshair points from: the camera when the holder has one, else the head.
func _crosshair_transform() -> Transform3D:
	if manipulator != null and manipulator.camera != null:
		return manipulator.camera.global_transform
	return view.global_transform


func _sweep(from_time: float, to_time: float) -> void:
	if _sweep_path(_strike_point_at(from_time), _strike_point_at(to_time), to_time - from_time):
		_hit_done = true


## Casts the strike sphere from `from` to `to` and registers the first hit.
func _sweep_path(from: Vector3, to: Vector3, duration: float) -> bool:
	var motion := to - from
	if motion.length_squared() < 0.000001:
		return false
	var space := _tool.get_world_3d().direct_space_state
	_sphere.radius = _settings.strike_radius
	_query.shape = _sphere
	_query.collision_mask = _settings.hit_mask
	_query.exclude = [_holder.get_rid(), _tool.get_rid()]
	_query.transform = Transform3D(Basis(), from)
	_query.motion = motion
	var fractions := space.cast_motion(_query)
	if fractions.is_empty() or fractions[1] >= 1.0:
		return false
	_query.transform = Transform3D(Basis(), from + motion * fractions[1])
	_query.motion = Vector3.ZERO
	var info := space.get_rest_info(_query)
	if info.is_empty():
		return false
	var collider := instance_from_id(info["collider_id"])
	if collider == null:
		return false
	_register_hit(collider, info["point"], info["normal"], motion.normalized(),
		motion.length() / maxf(duration, 0.0001))
	return true


## Swinging the tool with the mouse: if the strike point moves fast enough (beyond
## the holder's own movement), its path is swept for hits, with power from speed.
func _update_motion_strike(delta: float) -> void:
	var point := _strike_point_at(-1.0)
	var previous := _last_strike_point
	_last_strike_point = point
	var s := _settings
	if not s.motion_strikes or _is_placing() or _action_time >= 0.0 or _equip_progress < 1.0 \
			or not _tracking_strike_point:
		_tracking_strike_point = true
		return
	_motion_cooldown = maxf(0.0, _motion_cooldown - delta)
	if _motion_cooldown > 0.0:
		return
	var speed := ((point - previous) / delta - _holder_velocity()).length()
	if speed < s.motion_strike_min_speed:
		return
	var swing := inverse_lerp(s.motion_strike_min_speed, s.motion_strike_full_speed, speed)
	_power = lerpf(s.min_charge_power, s.max_charge_power, clampf(swing, 0.0, 1.0))
	if _sweep_path(previous, point, delta):
		_motion_cooldown = s.motion_strike_cooldown


func _register_hit(collider: Object, point: Vector3, normal: Vector3, swing_direction: Vector3, speed: float) -> void:
	var s := _settings
	var aim := -view.global_basis.z.normalized()
	if s.aim_mode == PhysicsToolDefinition.AimMode.VIEW_FORWARD_FLAT:
		aim = -_holder.global_basis.z.slide(Vector3.UP).normalized()
	var right := aim.cross(Vector3.UP)
	if not right.is_zero_approx():
		aim = aim.rotated(right.normalized(), deg_to_rad(s.loft_degrees))
	var impact := ToolImpact.new()
	impact.tool = _tool
	impact.tool_definition = s
	impact.user = _holder
	impact.collider = collider
	impact.position = point
	impact.normal = normal
	impact.direction = aim.lerp(swing_direction, s.swing_path_influence).normalized()
	impact.strike_speed = speed
	impact.power = _power
	impact.damage = s.damage * _power
	impact.impact_type = s.impact_type
	var receiver := collider as Node
	while receiver != null and not receiver.has_method("receive_tool_impact"):
		receiver = receiver.get_parent()
	var feel := PhysicsFeel.get_active()
	var body := collider as RigidBody3D
	if body != null and not body.freeze:
		var plain := minf(s.impact_impulse, body.mass * s.max_launch_speed) * _power
		# Strong hits get the feel profile's extra push (the launch cap scales with it).
		impact.impulse = impact.direction * plain * feel.impulse_scale(plain)
	if receiver != null:
		receiver.call("receive_tool_impact", impact)
	if body != null and not body.freeze and not impact.handled:
		body.sleeping = false
		body.apply_impulse(impact.impulse, point - body.global_position)
		feel.tumble(body, impact.impulse)
	if impact.feedback_sound < 0 and collider is Node and (collider as Node).has_method("get_impact_sound"):
		impact.feedback_sound = int((collider as Node).call("get_impact_sound"))
	# Fixed targets take no impulse, so judge their hits by damage instead.
	var force := maxf(impact.impulse.length(), impact.damage * 3.0)
	ImpactFeedback.spawn(_holder.get_parent(), point, normal, s.impact_type, clampf(force / 40.0, 0.25, 1.0),
		impact.feedback_color, impact.feedback_sound)
	CameraShake.shake_at(get_tree(), point, force)
	impacted.emit(impact)


func _find_provider(body: Node) -> Node:
	var node := body
	while node != null:
		if node.has_method("get_tool_definition"):
			return node
		node = node.get_parent()
	return body


func _holder_velocity() -> Vector3:
	if _holder is CharacterBody3D:
		return (_holder as CharacterBody3D).get_real_velocity()
	return Vector3.ZERO


func _on_tool_tree_exiting() -> void:
	_release_tool()
