extends CharacterBody3D

const PlayerStats = preload("res://player_stats.gd")
const InteractionMenu = preload("res://interaction_menu.gd")


@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.5
@export var acceleration: float = 30.0
@export var deceleration: float = 40.0
@export var air_acceleration: float = 10.0
@export_range(0.0, 0.25, 0.01) var coyote_time: float = 0.1
@export_range(0.0, 0.25, 0.01) var jump_buffer_time: float = 0.12
## Highest ledge the grounded player can walk up. Zero disables automatic stepping.
@export_range(0.0, 0.6, 0.01) var max_step_height: float = 0.3

@export_group("Crouching")
@export_range(0.6, 1.8, 0.05) var crouch_height: float = 1.0
@export_range(0.05, 0.5, 0.01) var crouch_transition_time: float = 0.22

@export_group("View")
@export var mouse_sensitivity: float = 0.0025
@export_range(1.0, 89.0) var pitch_limit: float = 85.0

@export_group("Field of View")
@export_range(50.0, 110.0, 1.0) var base_fov: float = 75.0
@export_range(0.0, 20.0, 0.5) var sprint_fov_boost: float = 10.0
@export_range(0.0, 10.0, 0.5) var crouch_fov_reduction: float = 3.0
@export_range(1.0, 20.0, 0.5) var fov_response: float = 8.0

@export_group("Camera Motion")
## Set to zero to disable headbob, strafe tilt, and landing dip.
@export_range(0.0, 1.0, 0.05) var camera_motion_strength: float = 1.0
@export var headbob_enabled: bool = true
@export_range(0.0, 0.08, 0.005) var headbob_amplitude: float = 0.035
## Steps per second at walking speed; cadence follows actual movement speed.
@export_range(0.5, 4.0, 0.1) var headbob_frequency: float = 1.8
@export_range(1.0, 25.0, 0.5) var camera_motion_response: float = 12.0
@export_range(0.0, 4.0, 0.1) var strafe_tilt_degrees: float = 1.5
@export_range(0.0, 1.0, 0.05) var landing_strength: float = 0.6
@export_range(0.0, 0.15, 0.01) var max_landing_dip: float = 0.1
@export_range(8.0, 30.0, 1.0) var landing_return_speed: float = 18.0

@export_group("Interaction")
@export var interaction_distance: float = 3.0
## Force applied to loose rigid bodies the player walks into; heavy ones barely move.
@export var push_force: float = 300.0

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $MeshInstance3D
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var interaction_prompt: Label = $HUD/InteractionPrompt
@onready var interaction_menu: InteractionMenu = $HUD/InteractionMenu
@onready var crosshair: Label = $HUD/Crosshair
@onready var charge_bar: ProgressBar = $HUD/ChargeBar
@onready var stats: PlayerStats = $Stats
@onready var manipulator: ObjectManipulator = $ObjectManipulator
@onready var tool_handler: ToolHandler = $ToolHandler

var gameplay_enabled: bool = true
var is_crouching: bool = false
var _capsule: CapsuleShape3D
var _capsule_mesh: CapsuleMesh
var _standing_height: float
var _standing_eye_height: float
var _standing_query: PhysicsShapeQueryParameters3D
var _step_collision := KinematicCollision3D.new()
var _step_ray := PhysicsRayQueryParameters3D.new()
var _crouch_progress: float = 0.0
var _crouch_blend: float = 0.0
var _coyote_remaining: float = 0.0
var _jump_buffer_remaining: float = 0.0
var _bob_phase: float = 0.0
var _bob_offset: Vector3 = Vector3.ZERO
var _landing_offset: float = 0.0
var _landing_velocity: float = 0.0
var _camera_rest_position: Vector3
var _camera_rest_roll: float
var _click_interact_requested: bool = false
var _crosshair_was_visible: bool = true
var climber: RopeClimber


func _ready() -> void:
	# Each player needs its own shape so crouching cannot resize another player.
	_capsule = collision.shape.duplicate() as CapsuleShape3D
	collision.shape = _capsule
	_standing_height = _capsule.height
	collision.position.y = _standing_height * 0.5
	_capsule_mesh = body_mesh.mesh.duplicate() as CapsuleMesh
	body_mesh.mesh = _capsule_mesh
	_capsule_mesh.radius = _capsule.radius
	_capsule_mesh.height = _standing_height
	body_mesh.position.y = collision.position.y
	_standing_eye_height = head.position.y
	_camera_rest_position = camera.position
	_camera_rest_roll = camera.rotation.z
	camera.fov = base_fov
	# Restrained shake from big nearby impacts (strength set by the PhysicsFeel profile).
	camera.add_child(CameraShake.new())
	crouch_height = clampf(crouch_height, _capsule.radius * 2.0, _standing_height)
	_standing_query = PhysicsShapeQueryParameters3D.new()
	_standing_query.shape = _capsule.duplicate()
	_standing_query.exclude = [get_rid()]
	_step_ray.exclude = [get_rid()]
	interaction_ray.add_exception(self)
	interaction_ray.target_position = Vector3(0.0, 0.0, -interaction_distance)
	climber = RopeClimber.new()
	add_child(climber)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_enabled:
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return
	# The hand holds at most one thing: an equipped tool claims its use input, a held
	# object claims throw, rotate and scroll input, and mouse look while rotating.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (tool_handler.handle_input(event) or manipulator.handle_input(event)):
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				_click_interact_requested = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_object_local(Vector3.UP, -event.screen_relative.x * mouse_sensitivity)
		head.rotation.x = clampf(
			head.rotation.x - event.screen_relative.y * mouse_sensitivity,
			-deg_to_rad(pitch_limit), deg_to_rad(pitch_limit)
		)


func _physics_process(delta: float) -> void:
	if not gameplay_enabled:
		return
	var controls_active: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if climber.is_climbing():
		_climb(delta, controls_active)
		return
	var was_on_floor := is_on_floor()
	_update_crouch(controls_active and Input.is_action_pressed("crouch"), delta)
	_coyote_remaining = coyote_time if was_on_floor else maxf(0.0, _coyote_remaining - delta)
	_jump_buffer_remaining = maxf(0.0, _jump_buffer_remaining - delta)
	var jump_pressed: bool = controls_active and Input.is_action_just_pressed("jump")
	if jump_pressed and not is_crouching:
		_jump_buffer_remaining = jump_buffer_time
	if not controls_active or is_crouching:
		_jump_buffer_remaining = 0.0

	if not was_on_floor:
		velocity += get_gravity() * delta

	var can_jump: bool = (was_on_floor or _coyote_remaining > 0.0) and _crouch_progress == 0.0
	if controls_active and not is_crouching and can_jump and (jump_pressed or _jump_buffer_remaining > 0.0):
		velocity += up_direction * (jump_velocity - velocity.dot(up_direction))
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0

	var input_dir := Vector2.ZERO
	if controls_active:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	var speed := walk_speed
	var sprinting: bool = controls_active and Input.is_action_pressed("sprint") and not is_crouching and not input_dir.is_zero_approx() and stats.can_sprint()
	if sprinting:
		speed = sprint_speed
	speed = lerpf(speed, crouch_speed, _crouch_blend)
	var response := deceleration if input_dir.is_zero_approx() else acceleration
	if not was_on_floor:
		response = air_acceleration
	var vertical_velocity := velocity.dot(up_direction)
	var horizontal_velocity := velocity.slide(up_direction).move_toward(direction.slide(up_direction) * speed, response * delta)
	velocity = horizontal_velocity + up_direction * vertical_velocity
	var falling_speed := -vertical_velocity
	var intended_velocity := velocity
	if was_on_floor and vertical_velocity <= 0.0:
		_try_step_up(horizontal_velocity * delta)
	move_and_slide()
	_push_rigid_bodies(intended_velocity, delta)
	var actual_velocity := get_real_velocity()
	var moving := Vector2(actual_velocity.x, actual_velocity.z).length() > 0.1
	stats.update_stamina(delta, sprinting and moving)
	if is_on_floor() and not was_on_floor and falling_speed > 1.5:
		# A critically damped spring gives the landing weight without bouncing.
		_landing_velocity = -minf(
			falling_speed * landing_strength,
			max_landing_dip * landing_return_speed * exp(1.0)
		)
	_update_camera_motion(delta, controls_active, input_dir)
	_update_interaction(controls_active)
	manipulator.physics_update(delta)
	tool_handler.physics_update(delta)
	_update_charge_bar()


## Movement while hanging on a rope: the climber swings and climbs the player.
func _climb(delta: float, controls_active: bool) -> void:
	var input_dir := Vector2.ZERO
	if controls_active:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump"):
			climber.jump_off(-camera.global_transform.basis.z)
		elif Input.is_action_just_pressed("crouch"):
			climber.release()
	if climber.is_climbing():
		climber.physics_update(delta, input_dir, controls_active and Input.is_action_pressed("sprint"))
	_update_camera_motion(delta, controls_active, Vector2.ZERO)
	_update_interaction(controls_active)
	manipulator.physics_update(delta)
	tool_handler.physics_update(delta)
	_update_charge_bar()


func _try_step_up(motion: Vector3) -> void:
	if max_step_height <= 0.0 or motion.is_zero_approx():
		return
	# Only probe a step when ordinary movement encounters a steep obstacle.
	if not test_move(global_transform, motion, _step_collision, safe_margin):
		return
	if _step_collision.get_normal().dot(up_direction) >= cos(floor_max_angle):
		return
	var obstacle := _step_collision.get_collider()
	# Loose objects retain the existing pushing behaviour instead of becoming stairs.
	if obstacle is RigidBody3D and not obstacle.freeze:
		return
	var lift := up_direction * (max_step_height + safe_margin)
	if test_move(global_transform, lift, _step_collision, safe_margin):
		lift = _step_collision.get_travel()
	if lift.dot(up_direction) <= safe_margin:
		return
	var raised := global_transform.translated(lift)
	if test_move(raised, motion, _step_collision, safe_margin):
		return
	if not test_move(raised.translated(motion), -lift, _step_collision, safe_margin):
		return
	# A capsule can first touch a tread's edge with a steep normal. Check the
	# surface just inside that edge, rather than rejecting valid steps at low speed.
	var tread_point := _step_collision.get_position() + motion.normalized() * 0.02
	_step_ray.from = tread_point + up_direction * 0.02
	_step_ray.to = tread_point - up_direction * 0.02
	_step_ray.collision_mask = collision_mask
	var tread := get_world_3d().direct_space_state.intersect_ray(_step_ray)
	if tread.is_empty() or tread["normal"].dot(up_direction) < cos(floor_max_angle):
		return
	var support: Object = tread["collider"]
	if support is RigidBody3D and not support.freeze:
		return
	var height: float = (tread["position"] - global_position).dot(up_direction)
	if height <= safe_margin or height > max_step_height + safe_margin:
		return
	var rise := up_direction * (height + safe_margin)
	if test_move(global_transform, rise, _step_collision, safe_margin):
		return
	global_position += rise
	velocity = velocity.slide(up_direction)


func _update_charge_bar() -> void:
	var charge := maxf(manipulator.get_charge_ratio(), tool_handler.get_charge_ratio())
	charge_bar.visible = charge >= 0.0
	if charge_bar.visible:
		charge_bar.value = charge
		# Warm up as it fills, so full charge reads at a glance.
		charge_bar.modulate = Color(1.0, 0.55, 0.15) if charge >= 1.0 else Color(1.0, 1.0, 1.0 - charge * 0.5)


func _push_rigid_bodies(intended_velocity: Vector3, delta: float) -> void:
	for index in get_slide_collision_count():
		var hit := get_slide_collision(index)
		var body := hit.get_collider() as RigidBody3D
		# Standing on a body should not shove it along.
		if body == null or body.freeze or hit.get_normal().dot(up_direction) > 0.7:
			continue
		var push := -hit.get_normal().slide(up_direction).normalized()
		# Only push until the body keeps pace, so light objects are not launched.
		if push.is_zero_approx() or body.linear_velocity.dot(push) >= intended_velocity.dot(push):
			continue
		body.apply_impulse(push * push_force * delta, hit.get_position() - body.global_position)


func _update_crouch(wants_crouch: bool, delta: float) -> void:
	# Check every frame while rising, in case we move beneath a low ceiling.
	if not wants_crouch and _crouch_progress > 0.0 and not _can_stand():
		wants_crouch = true
	is_crouching = wants_crouch
	_crouch_progress = move_toward(
		_crouch_progress, 1.0 if is_crouching else 0.0,
		delta / maxf(crouch_transition_time, 0.001)
	)
	_crouch_blend = smoothstep(0.0, 1.0, _crouch_progress)
	_capsule.height = lerpf(_standing_height, crouch_height, _crouch_blend)
	# Smooth the body and eyes together so the camera stays inside the capsule.
	collision.position.y = _capsule.height * 0.5
	_capsule_mesh.height = _capsule.height
	body_mesh.position.y = collision.position.y
	head.position.y = _standing_eye_height - (_standing_height - _capsule.height)


func _can_stand() -> bool:
	_standing_query.collision_mask = collision_mask
	# A small upward offset avoids treating the floor as blocked headroom.
	_standing_query.transform = global_transform.translated_local(
		Vector3.UP * (_standing_height * 0.5 + 0.01)
	)
	return get_world_3d().direct_space_state.intersect_shape(_standing_query, 1).is_empty()


func _update_camera_motion(delta: float, controls_active: bool, input_dir: Vector2) -> void:
	var actual_velocity := get_real_velocity() - get_platform_velocity()
	var actual_speed := actual_velocity.slide(up_direction).length()
	var moving_on_floor := controls_active and is_on_floor() and not input_dir.is_zero_approx() and actual_speed > 0.1
	var motion_weight := 1.0 - exp(-camera_motion_response * delta)
	var bob_target := Vector3.ZERO
	var tilt_target := 0.0
	var sprint_blend := 0.0
	if moving_on_floor:
		var speed_ratio := clampf(actual_speed / maxf(walk_speed, 0.01), 0.0, 1.6)
		if headbob_enabled:
			# Wrap after two vertical steps to preserve the slower side-to-side cycle.
			_bob_phase = fposmod(_bob_phase + TAU * headbob_frequency * speed_ratio * delta, TAU * 2.0)
			var amplitude := headbob_amplitude * speed_ratio * lerpf(1.0, 0.65, _crouch_blend)
			bob_target = Vector3(sin(_bob_phase * 0.5) * amplitude * 0.5, sin(_bob_phase) * amplitude, 0.0)
		var local_velocity := global_basis.inverse() * actual_velocity
		tilt_target = -deg_to_rad(strafe_tilt_degrees) * clampf(local_velocity.x / maxf(walk_speed, 0.01), -1.0, 1.0)
		sprint_blend = clampf((actual_speed - walk_speed) / maxf(sprint_speed - walk_speed, 0.01), 0.0, 1.0)
	_bob_offset = _bob_offset.lerp(bob_target, motion_weight)
	if not moving_on_floor and _bob_offset.length_squared() < 0.000001:
		_bob_phase = 0.0
		_bob_offset = Vector3.ZERO

	# Exact spring integration stays stable at different physics tick rates.
	var spring_decay := exp(-landing_return_speed * delta)
	var spring_step := (_landing_velocity + landing_return_speed * _landing_offset) * delta
	_landing_offset = clampf((_landing_offset + spring_step) * spring_decay, -max_landing_dip, max_landing_dip)
	_landing_velocity = (_landing_velocity - landing_return_speed * spring_step) * spring_decay
	camera.position = _camera_rest_position + (_bob_offset + Vector3.UP * _landing_offset) * camera_motion_strength
	camera.rotation.z = lerp_angle(camera.rotation.z, _camera_rest_roll + tilt_target * camera_motion_strength, motion_weight)
	var target_fov := base_fov + sprint_fov_boost * sprint_blend - crouch_fov_reduction * _crouch_blend
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-fov_response * delta))


func _update_interaction(controls_active: bool) -> void:
	var clicked := _click_interact_requested
	_click_interact_requested = false
	interaction_prompt.hide()
	if not controls_active:
		interaction_menu.close_menu()
		return
	if climber.is_climbing():
		interaction_menu.close_menu()
		interaction_prompt.text = climber.prompt()
		interaction_prompt.show()
		if Input.is_action_just_pressed("interact"):
			climber.release()
		return
	if tool_handler.is_equipped():
		interaction_menu.close_menu()
		interaction_prompt.text = tool_handler.get_prompt()
		interaction_prompt.show()
		if Input.is_action_just_pressed("equip_tool"):
			tool_handler.unequip()
		elif Input.is_action_just_pressed("interact"):
			tool_handler.drop()
		return
	if manipulator.is_holding():
		var held := manipulator.get_held_body()
		# A held voxel piece can be cemented into a structure it is pressed against.
		var can_cement := held is VoxelBody and VoxelConstruction.has_cement_target(held)
		var hints := tool_handler.get_equip_hint(held)
		if can_cement:
			hints = "[C] Cement" + ("" if hints.is_empty() else "   " + hints)
		interaction_menu.close_menu()
		interaction_prompt.text = manipulator.get_hold_prompt(hints)
		interaction_prompt.show()
		if Input.is_action_just_pressed("equip_tool"):
			tool_handler.equip_held()
		elif can_cement and Input.is_action_just_pressed("cement_held"):
			var cement_target := VoxelConstruction.find_cement_target(held as VoxelBody)
			if cement_target != null:
				VoxelConstruction.cement(held as VoxelBody, cement_target)
		elif Input.is_action_just_pressed("interact"):
			manipulator.release()
		return
	interaction_ray.force_raycast_update()
	var grabbable := manipulator.resolve_grabbable(interaction_ray.get_collider())
	if grabbable != null:
		interaction_menu.close_menu()
		var prompt := manipulator.get_grab_prompt(grabbable)
		var equip_hint := tool_handler.get_equip_hint(grabbable)
		interaction_prompt.text = prompt if equip_hint.is_empty() else "%s   %s" % [prompt, equip_hint]
		interaction_prompt.show()
		if Input.is_action_just_pressed("interact"):
			manipulator.grab(grabbable)
		elif Input.is_action_just_pressed("equip_tool"):
			tool_handler.equip(grabbable)
		return
	# Ropes are thin, so they're found by aim rather than by the interaction ray.
	var rope := climber.find_target(camera.global_position, -camera.global_transform.basis.z)
	var ray_depth := INF
	if interaction_ray.is_colliding():
		ray_depth = camera.global_position.distance_to(interaction_ray.get_collision_point())
	if not rope.is_empty() and rope["depth"] < ray_depth + 0.1:
		interaction_menu.close_menu()
		interaction_prompt.text = "[E] Climb %s" % rope["strand"].record.definition.display_name.to_lower()
		interaction_prompt.show()
		if Input.is_action_just_pressed("interact"):
			climber.grab(rope)
		return
	var target := interaction_ray.get_collider() as Node
	# The interaction script may live on the collider or its scene root.
	while target != null and not target.has_method("interact"):
		target = target.get_parent()
	if target == null:
		interaction_menu.close_menu()
		return
	var available := not target.has_method("can_interact") or bool(target.call("can_interact"))
	if target.has_method("get_interaction_actions") and target.has_method("perform_interaction_action"):
		if available:
			open_interaction_menu(target)
			if Input.is_action_just_pressed("interact"):
				interaction_menu.perform_selected_action()
		else:
			interaction_menu.close_menu()
		return
	interaction_menu.close_menu()
	var prompt := "Interact"
	if target.has_method("get_interaction_prompt"):
		prompt = str(target.call("get_interaction_prompt"))
	var clickable := target.has_method("allows_click_interaction") and bool(target.call("allows_click_interaction"))
	var key_hint := "[E / Left click] " if clickable else "[E] "
	interaction_prompt.text = (key_hint if available else "") + prompt
	interaction_prompt.show()
	if available and (Input.is_action_just_pressed("interact") or (clicked and clickable)):
		target.call("interact", self)


func open_interaction_menu(target: Node) -> void:
	if gameplay_enabled:
		interaction_menu.open_for(target, self)


func set_gameplay_enabled(enabled: bool) -> void:
	if gameplay_enabled == enabled:
		return
	gameplay_enabled = enabled
	_click_interact_requested = false
	_jump_buffer_remaining = 0.0
	_coyote_remaining = 0.0
	Input.action_release("jump")
	Input.action_release("interact")
	set_physics_process(enabled)
	set_process_unhandled_input(enabled)
	if enabled:
		crosshair.visible = _crosshair_was_visible
	else:
		velocity = Vector3.ZERO
		manipulator.release()
		tool_handler.cancel_action()
		charge_bar.hide()
		_crosshair_was_visible = crosshair.visible
		crosshair.hide()
		interaction_prompt.hide()
		interaction_menu.close_menu()
