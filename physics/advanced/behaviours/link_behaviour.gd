class_name LinkBehaviour
extends ToolBehaviour
## Joins two chosen points: welding torch (rigid, touching metal), hinge tool,
## and the rope, chain, cable, spring and elastic tools. Click the first point,
## optionally click pulleys to route a strand over them, then click the second.
## The wheel sets strand length; RMB cancels or removes what you aim at.

const AXIS_NAMES := ["surface normal", "vertical", "horizontal"]

var first: AttachmentPoint
var guides: Array[AttachmentPoint] = []
var length: float = 2.0


func setup(owner_runtime: AdvancedToolRuntime) -> void:
	super(owner_runtime)
	length = maxf(action.rest_length, 0.5)


func _is_strand() -> bool:
	return action.connection != null and action.connection.is_strand()


func is_working() -> bool:
	return false


func press() -> void:
	if not runtime.aimed_in_reach():
		runtime.say("Aim at something within reach")
		return
	var hit := runtime.aimed
	var point := AttachmentPoint.at(hit["collider"], hit["position"], hit["normal"])
	if first == null:
		first = point
		runtime.shot(0.3)
		runtime.say("First point set. Now pick the second%s." % (" (or a pulley to route over)" if _is_strand() else ""))
		return
	var pulley := point.body() as PhysicsProp
	if _is_strand() and pulley != null and pulley.definition != null and pulley.definition.contraption_component == "pulley":
		if guides.size() >= 4:
			runtime.say("A strand can run over four pulleys at most")
			return
		guides.append(AttachmentPoint.at(pulley, pulley.to_global(Vector3(0, 0.12, 0)), Vector3.UP))
		runtime.shot(0.2)
		runtime.say("Routed over pulley %d" % guides.size())
		return
	var world := runtime.world
	world.reason = ""
	if world.create(first, point, action.connection, _axis(hit), length, guides) != null:
		runtime.shot()
		if action.operation == "weld":
			runtime.feedback.burst(hit["position"], hit["normal"])
		runtime.say("Connected")
		_clear()
	else:
		runtime.say(world.reason)


func secondary() -> void:
	if first != null:
		_clear()
		runtime.say("Cancelled")
		return
	var world := runtime.world
	if _is_strand():
		var aim := runtime.aim_transform()
		if world.remove_aimed_strand(aim.origin, -aim.basis.z, action.range_metres):
			runtime.say("Removed")
			return
	if runtime.aimed_in_reach() and world.weaken(runtime.aimed["position"], 1000000.0, action.connection):
		runtime.say("Removed")


func cycle_mode() -> bool:
	if action.operation != "hinge":
		return false
	mode = (mode + 1) % 3
	runtime.say("Hinge axis: %s" % AXIS_NAMES[mode])
	return true


func scroll(direction: int) -> bool:
	if not _is_strand():
		return false
	length = clampf(length + direction * 0.25, 0.25, 12.0)
	return true


func tick(_delta: float) -> void:
	if first != null and not first.valid():
		_clear()
		runtime.say("The first point was destroyed")


func detail() -> String:
	var text := action.verb
	if _is_strand():
		text += " · %.2f m" % length
	if action.operation == "hinge":
		text += " · axis: %s" % AXIS_NAMES[mode]
	if first != null:
		text += " · pick the second point"
		if not guides.is_empty():
			text += " (%d pulley%s)" % [guides.size(), "" if guides.size() == 1 else "s"]
	return text


func hints() -> String:
	var keys := "[LMB] Pick point   [RMB] Cancel / remove"
	if _is_strand():
		keys += "   [Wheel] Length"
	if action.operation == "hinge":
		keys += "   [Q] Axis"
	return keys


func preview_lines() -> PackedVector3Array:
	var lines := PackedVector3Array()
	var target := runtime.aim_point(action.range_metres)
	if first != null:
		var previous := first.position()
		for guide in guides:
			lines.append(previous)
			lines.append(guide.position())
			previous = guide.position()
		lines.append(previous)
		lines.append(target)
	if runtime.aimed_in_reach():
		if action.operation == "hinge":
			var axis := _axis(runtime.aimed)
			lines.append(target - axis * 0.15)
			lines.append(target + axis * 0.15)
		lines.append_array(AdvancedToolRuntime.cross_at(target, 0.04))
	return lines


func _axis(hit: Dictionary) -> Vector3:
	match mode:
		1:
			return Vector3.UP
		2:
			return runtime.aim_transform().basis.x
	return hit["normal"]


func _clear() -> void:
	first = null
	guides.clear()
