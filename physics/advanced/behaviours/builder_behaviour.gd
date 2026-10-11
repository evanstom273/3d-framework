class_name BuilderBehaviour
extends ToolBehaviour
## Marker / label gun (arrows, numbers or a text label that stick to surfaces and
## follow them, even onto broken-off pieces) and the spray foam gun (grows foam
## voxels that harden into a light, breakable material, then expire).

const STYLES := ["arrow", "number", "label"]
const FOAM_INTERVAL := 0.12

var serial: int = 1
var angle: float = 0.0
var _foam_clock: float = 0.0


func is_working() -> bool:
	return action.operation == "foam" and runtime.held


func press() -> void:
	if action.operation == "foam":
		_foam_clock = FOAM_INTERVAL
		return
	if not runtime.aimed_in_reach():
		runtime.say("Aim at a surface within reach")
		return
	var hit := runtime.aimed
	var text: String = ["➜", str(serial), action.label_text][mode]
	var world := runtime.world
	world.reason = ""
	if ToolMatter.marker(world, AttachmentPoint.at(hit["collider"], hit["position"], hit["normal"]), text, angle, action.effect_color):
		if mode == 1:
			serial += 1
		runtime.shot()
	else:
		runtime.say(world.reason)


func tick(delta: float) -> void:
	if action.operation != "foam" or not runtime.held:
		return
	_foam_clock += delta
	if _foam_clock < FOAM_INTERVAL:
		return
	_foam_clock = 0.0
	var world := runtime.world
	world.reason = ""
	if not ToolMatter.grow_foam(world, runtime.aim_transform(), action, runtime.exclusions()):
		runtime.say(world.reason, 0.6)


func secondary() -> void:
	if action.operation != "marker" or not runtime.aimed_in_reach():
		return
	var point: Vector3 = runtime.aimed["position"]
	var world := runtime.world
	for entry in world.markers.duplicate():
		if entry["point"].position().distance_to(point) < 0.3:
			world.erase_marker(entry)
			runtime.say("Marker removed")
			return


func cycle_mode() -> bool:
	if action.operation != "marker":
		return false
	mode = (mode + 1) % STYLES.size()
	return true


func scroll(direction: int) -> bool:
	if action.operation != "marker":
		return false
	angle = wrapf(angle + direction * deg_to_rad(15.0), -PI, PI)
	return true


func detail() -> String:
	if action.operation == "marker":
		var style: String = ["arrow", "number %d" % serial, "\"%s\"" % action.label_text][mode]
		return "%s · %s · %d°" % [action.verb, style, roundi(rad_to_deg(angle))]
	return action.verb


func hints() -> String:
	if action.operation == "marker":
		return "[LMB] Place   [RMB] Remove   [Q] Style   [Wheel] Rotate"
	return action.primary_hint


func preview_lines() -> PackedVector3Array:
	if action.operation != "marker" or not runtime.aimed_in_reach():
		return PackedVector3Array()
	return AdvancedToolRuntime.cross_at(runtime.aimed["position"], 0.05)
