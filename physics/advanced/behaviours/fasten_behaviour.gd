class_name FastenBehaviour
extends ToolBehaviour
## Glue gun and caulking gun leave a patch that bonds whatever is pressed onto it
## next; the staple gun fastens instantly into a backing object; the drill drives
## a screw over a short hold (RMB backs it out). All connections are real joints
## between real bodies, made only where surfaces actually meet.

var _dwell: float = 0.0
var _dwell_target: int = 0


func press() -> void:
	if action.operation == "screw":
		_dwell = 0.0
		return
	if not runtime.aimed_in_reach():
		runtime.say("Aim at a surface within reach")
		return
	var world := runtime.world
	var hit := runtime.aimed
	world.reason = ""
	match action.operation:
		"glue", "sealant":
			if world.prepare_patch(AttachmentPoint.at(hit["collider"], hit["position"], hit["normal"]), action.connection):
				runtime.shot()
				runtime.say("Press another object onto the patch")
			else:
				runtime.say(world.reason)
		"staple":
			if ToolMatter.fasten(world, hit, action.connection, action.probe_depth):
				runtime.shot()
			else:
				runtime.say(world.reason)


func release() -> void:
	_dwell = 0.0


func is_working() -> bool:
	return action.operation == "screw" and runtime.held


func tick(delta: float) -> void:
	if action.operation != "screw" or not runtime.held:
		_dwell = 0.0
		return
	if not runtime.aimed_in_reach():
		_dwell = 0.0
		return
	var hit := runtime.aimed
	var id: int = hit["collider"].get_instance_id()
	if id != _dwell_target:
		_dwell_target = id
		_dwell = 0.0
	_dwell += delta
	if _dwell < action.dwell_seconds:
		return
	_dwell = 0.0
	runtime.stop()
	runtime.world.reason = ""
	if ToolMatter.fasten(runtime.world, hit, action.connection, action.probe_depth):
		runtime.shot(0.5)
		runtime.say("Screwed in")
	else:
		runtime.say(runtime.world.reason)


func secondary() -> void:
	if not runtime.aimed_in_reach():
		return
	var world := runtime.world
	var point: Vector3 = runtime.aimed["position"]
	match action.operation:
		"glue", "sealant":
			for patch in world.patches.duplicate():
				if patch["point"].position().distance_to(point) < 0.2:
					world.erase_patch(patch)
			runtime.say("Patch cleared")
		"screw":
			if world.weaken(point, action.connection.removal_resistance, action.connection):
				runtime.say("Screw backed out")
			else:
				runtime.say("No screw here")
		"staple":
			runtime.say("Use the crowbar's pry mode to pull staples")


func detail() -> String:
	if action.operation == "screw" and _dwell > 0.0:
		return "%s · %d%%" % [action.verb, mini(100, int(_dwell / action.dwell_seconds * 100.0))]
	return action.verb


func preview_lines() -> PackedVector3Array:
	if not runtime.aimed_in_reach():
		return PackedVector3Array()
	return AdvancedToolRuntime.cross_at(runtime.aimed["position"], 0.04)


func contact() -> Dictionary:
	if is_working() and runtime.aimed_in_reach():
		return {"position": runtime.aimed["position"], "normal": runtime.aimed["normal"]}
	return {}
