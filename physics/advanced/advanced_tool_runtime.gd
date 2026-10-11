class_name AdvancedToolRuntime
extends Node
## Runs an equipped advanced tool. Aiming comes from the crosshair; effects,
## sprays and projectiles leave from the tool's own nozzle. This node owns the
## feel (use pose blend, recoil, vibration), the prompt and the preview; the
## per-category ToolBehaviour decides what each input actually does.
## Lives under the tool body, so all state belongs to that physical instance.

const AIM_MASK := 1 | 2 | 4 | 16

var action: ToolActionDefinition
var handler: ToolHandler
var body: RigidBody3D
var world: ContraptionWorld
var feedback: ToolFeedback
var behaviour: ToolBehaviour
var held: bool = false
## 0..1 blend from the rest pose toward the use pose.
var use_blend: float = 0.0
## Recoil from the last shot; decays quickly.
var kick: float = 0.0
## Crosshair ray result this tick ({} when nothing is in range).
var aimed: Dictionary = {}

var _message: String = ""
var _message_time: float = 0.0
var _time: float = 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _preview: MeshInstance3D
var _preview_mesh := ImmediateMesh.new()


func bind(owner_handler: ToolHandler, definition: ToolActionDefinition) -> void:
	handler = owner_handler
	body = get_parent() as RigidBody3D
	world = ContraptionWorld.find(body, true)
	if action != definition or behaviour == null:
		if behaviour != null:
			behaviour.unbind()
		action = definition
		behaviour = ToolBehaviour.create(action.operation)
		behaviour.setup(self)
	if feedback == null:
		feedback = ToolFeedback.new()
		feedback.name = "ToolFeedback"
		body.add_child(feedback)
	feedback.setup(action)
	feedback.set_equipped(true)
	_ensure_preview()


func unbind() -> void:
	stop()
	if behaviour != null:
		behaviour.unbind()
	if is_instance_valid(feedback):
		feedback.set_equipped(false)
	if is_instance_valid(_preview):
		_preview.hide()
	use_blend = 0.0
	kick = 0.0
	handler = null


## Stops a held action (button released, focus lost, tool put away).
func stop() -> void:
	if held:
		held = false
		if behaviour != null:
			behaviour.release()


## A scripted primary press (ToolHandler.use_primary).
func press_primary() -> void:
	held = true
	behaviour.press()


func input(event: InputEvent) -> bool:
	if behaviour.extra_input(event):
		return true
	if event.is_action("use_tool"):
		if event.is_pressed() and not event.is_echo():
			press_primary()
		elif not event.is_pressed():
			stop()
		return true
	if event.is_action_pressed("tool_secondary"):
		behaviour.secondary()
		return true
	if event.is_action_pressed("tool_mode") and behaviour.cycle_mode():
		return true
	var scroll := int(event.is_action_pressed("hold_farther")) - int(event.is_action_pressed("hold_closer"))
	if scroll != 0 and behaviour.scroll(scroll):
		return true
	return false


func tick(delta: float) -> void:
	if handler == null:
		return
	_time += delta
	_message_time = maxf(0.0, _message_time - delta)
	# The button state is authoritative; a release can be missed on focus loss.
	if held and (Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not Input.is_action_pressed("use_tool")):
		stop()
	_update_aim()
	behaviour.tick(delta)
	var working := behaviour.is_working()
	use_blend = move_toward(use_blend, 1.0 if working else 0.0, delta * 6.0)
	kick *= exp(-12.0 * delta)
	feedback.update(delta, working, self)
	_update_preview()


# --- Aiming and geometry

func aim_transform() -> Transform3D:
	return handler._crosshair_transform()


## Where the crosshair lands, or a point at `fallback` metres when it hits nothing.
func aim_point(fallback: float = -1.0) -> Vector3:
	if not aimed.is_empty():
		return aimed["position"]
	var aim := aim_transform()
	return aim.origin - aim.basis.z * (fallback if fallback > 0.0 else action.range_metres)


## Distance from the eye to the aimed surface (INF when nothing is aimed at).
func aim_distance() -> float:
	return aim_transform().origin.distance_to(aimed["position"]) if not aimed.is_empty() else INF


## True when the crosshair is on something within the tool's reach.
func aimed_in_reach(reach: float = -1.0) -> bool:
	return not aimed.is_empty() and aim_distance() <= (reach if reach > 0.0 else action.range_metres)


func nozzle_position() -> Vector3:
	return body.global_transform * action.nozzle


## From the nozzle toward what the crosshair is on, so sprays and shots converge.
func nozzle_direction() -> Vector3:
	var direction := aim_point() - nozzle_position()
	if direction.length_squared() < 0.0001:
		return -aim_transform().basis.z
	return direction.normalized()


func exclusions() -> Array[RID]:
	var result: Array[RID] = [body.get_rid()]
	if handler != null and handler._holder != null:
		result.append(handler._holder.get_rid())
	return result


func _update_aim() -> void:
	var aim := aim_transform()
	_ray.from = aim.origin
	_ray.to = aim.origin - aim.basis.z * maxf(action.range_metres, 1.0)
	_ray.collision_mask = AIM_MASK
	_ray.exclude = exclusions()
	aimed = body.get_world_3d().direct_space_state.intersect_ray(_ray)


# --- Feel

## Short status line shown under the tool name for a couple of seconds.
func say(text: String, seconds: float = 2.0) -> void:
	if text.is_empty():
		return
	_message = text
	_message_time = seconds


## Recoil and shot sound for one-off actions (fasteners, launchers, clicks).
func shot(strength: float = 1.0) -> void:
	kick = minf(1.6, kick + action.shot_kick * strength)
	feedback.play_shot()


## The hand pose ToolHandler uses: rest blended toward use, plus kick and vibration.
func hand_pose(settings: PhysicsToolDefinition) -> Transform3D:
	var blend := smoothstep(0.0, 1.0, use_blend)
	var position := settings.rest_position.lerp(settings.strike_position, blend)
	var rotation := settings.rest_rotation_degrees.lerp(settings.strike_rotation_degrees, blend)
	# Recoil pushes the tool back and tips the muzzle up.
	position += Vector3(0.0, 0.015, 0.07) * kick
	rotation += Vector3(14.0, 0.0, 0.0) * kick
	if action.use_shake > 0.0 and blend > 0.0:
		position += Vector3(sin(_time * 67.0), sin(_time * 59.0 + 1.3), sin(_time * 71.0 + 2.1) * 0.5) * action.use_shake * blend
	return Transform3D(Basis.from_euler(rotation * (PI / 180.0)), position)


func prompt(has_alternate: bool) -> String:
	var keys := behaviour.hints()
	if has_alternate:
		keys += "   [Q] Switch mode"
	var text := "%s\n%s   [F] Unequip   [E] Drop" % [behaviour.detail(), keys]
	if _message_time > 0.0:
		text += "\n" + _message
	return text


# --- Preview

func _ensure_preview() -> void:
	if is_instance_valid(_preview):
		return
	_preview = MeshInstance3D.new()
	_preview.name = "Preview"
	_preview.mesh = _preview_mesh
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.4, 1.0, 0.7)
	material.no_depth_test = true
	_preview.material_override = material
	# Not a Node3D parent, so the preview's transform is in world space.
	add_child(_preview)


func _update_preview() -> void:
	var lines := behaviour.preview_lines()
	if lines.is_empty():
		_preview.hide()
		return
	_preview_mesh.clear_surfaces()
	_preview_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point in lines:
		_preview_mesh.surface_add_vertex(point)
	_preview_mesh.surface_end()
	_preview.show()


## A small three-axis cross at `point`, for previews.
static func cross_at(point: Vector3, size: float = 0.06) -> PackedVector3Array:
	return PackedVector3Array([
		point - Vector3(size, 0, 0), point + Vector3(size, 0, 0),
		point - Vector3(0, size, 0), point + Vector3(0, size, 0),
		point - Vector3(0, 0, size), point + Vector3(0, 0, size),
	])


func _exit_tree() -> void:
	stop()
	if behaviour != null:
		behaviour.unbind()
