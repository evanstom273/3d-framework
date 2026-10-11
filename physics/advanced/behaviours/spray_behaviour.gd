class_name SprayBehaviour
extends ToolBehaviour
## A cone from the nozzle toward the crosshair: leaf blower, pressure washer, fire
## extinguisher, vacuum, magnet gun and paint sprayer. Forces apply at 20 Hz with
## pooled queries and a line-of-sight check, so walls shelter what's behind them.
## Every body gets the same force, so heavy things simply move less.

const STEP := 0.05
const COLOR_NAMES := ["red", "blue", "yellow", "white", "green", "black"]

var color_index: int = 0
var _clock: float = 0.0
var _query := PhysicsShapeQueryParameters3D.new()
var _sphere := SphereShape3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _contact: Dictionary = {}


func cycle_mode() -> bool:
	if action.operation != "magnet":
		return false
	mode = 1 - mode
	runtime.say("Repel" if mode == 1 else "Attract")
	return true


func scroll(direction: int) -> bool:
	if action.operation != "paint" or action.colors.is_empty():
		return false
	color_index = posmod(color_index + direction, action.colors.size())
	return true


func secondary() -> void:
	if action.operation == "vacuum":
		runtime.world.release_cargo(runtime.body)
		runtime.say(runtime.world.reason if not runtime.world.reason.is_empty() else "Emptied")


func detail() -> String:
	match action.operation:
		"magnet":
			return "Magnet · %s" % ("Repel" if mode == 1 else "Attract")
		"vacuum":
			return "Vacuum · %d / %d items" % [runtime.world.cargo.get(runtime.body.get_instance_id(), []).size(), action.cargo_items]
		"paint":
			return "Paint · %s" % _color_name()
	return action.verb


func hints() -> String:
	match action.operation:
		"magnet":
			return "%s   [Q] Attract / repel" % action.primary_hint
		"paint":
			return "%s   [Wheel] Colour" % action.primary_hint
	return "%s   %s" % [action.primary_hint, action.secondary_hint] if not action.secondary_hint.is_empty() else action.primary_hint


## The paint colour, so the spray particles match it.
func current_color() -> Color:
	if action.operation == "paint" and not action.colors.is_empty():
		return action.colors[color_index]
	return action.effect_color


func release() -> void:
	_clock = 0.0
	_contact = {}


func contact() -> Dictionary:
	return _contact


func tick(delta: float) -> void:
	_contact = {}
	if not runtime.held:
		_clock = 0.0
		return
	var hit := runtime.aimed
	var reaches := not hit.is_empty() and runtime.nozzle_position().distance_to(hit["position"]) <= action.range_metres
	if reaches and action.operation in ["wash", "extinguish", "paint"]:
		_contact = {"position": hit["position"], "normal": hit["normal"], "color": current_color()}
	_clock += delta
	if _clock < STEP:
		return
	var step := _clock
	_clock = 0.0
	if action.operation != "paint":
		_push(step)
	if reaches:
		_treat_surface(hit, step)


func _push(step: float) -> void:
	var world := runtime.world
	var origin := runtime.nozzle_position()
	var direction := runtime.nozzle_direction()
	var space := runtime.body.get_world_3d().direct_space_state
	_sphere.radius = action.range_metres
	_query.shape = _sphere
	_query.transform = Transform3D(Basis(), origin)
	_query.collision_mask = 1 | 2 | 16
	_query.exclude = runtime.exclusions()
	var cone := cos(deg_to_rad(action.cone_degrees))
	for overlap in space.intersect_shape(_query, 24):
		var target := overlap["collider"] as RigidBody3D
		if target == null or target.freeze:
			continue
		var offset := target.global_position - origin
		var distance := offset.length()
		if distance < 0.01 or (offset / distance).dot(direction) < cone:
			continue
		_ray.from = origin
		_ray.to = target.global_position
		_ray.collision_mask = 1 | 2 | 16
		_ray.exclude = runtime.exclusions()
		var sight := space.intersect_ray(_ray)
		if sight.is_empty() or sight["collider"] != target:
			continue
		var push := offset / distance
		match action.operation:
			"vacuum":
				if target.mass > action.cargo_mass:
					continue
				push = -push
				if distance < 0.55 and ToolMatter.collect(world, runtime.body, target, action):
					continue
			"magnet":
				var profile := ContraptionWorld.profile(target, sight["position"], sight["normal"])
				if profile == null or not profile.magnetic:
					continue
				if mode == 0:
					push = -push
		var falloff := clampf(1.0 - distance / action.range_metres, 0.15, 1.0)
		target.apply_impulse(push * action.force * falloff * step, sight["position"] - target.global_position)


func _treat_surface(hit: Dictionary, step: float) -> void:
	var world := runtime.world
	match action.operation:
		"paint":
			ToolMatter.surface(world, hit, "paint", step, current_color())
		"wash":
			ToolMatter.surface(world, hit, "wash", action.rate * step, Color.WHITE)
		"extinguish":
			ToolMatter.surface(world, hit, "cool", action.rate * step, Color.WHITE)
			var target: Object = hit["collider"]
			if target.has_method("cool_surface"):
				target.call("cool_surface", hit["position"], action.rate * step)
			if target.has_method("extinguish"):
				target.call("extinguish", hit["position"], action.rate * step)


func _color_name() -> String:
	return COLOR_NAMES[color_index] if color_index < COLOR_NAMES.size() else "colour %d" % (color_index + 1)
