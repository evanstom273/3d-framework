class_name LauncherBehaviour
extends ToolBehaviour
## Nail gun and plunger launcher: fire a real physical projectile from the
## muzzle toward the crosshair. Nails fasten what they hit to whatever is behind
## it; plungers stick with weak suction. RMB reloads a plunger lying nearby.

var loaded_plunger: RigidBody3D
var _cooldown: float = 0.0


func is_working() -> bool:
	return false


func press() -> void:
	if _cooldown > 0.0:
		return
	var direction := runtime.nozzle_direction()
	var up := Vector3.UP if absf(direction.y) < 0.95 else Vector3.BACK
	var pose := Transform3D(Basis.looking_at(direction, up), runtime.nozzle_position() + direction * 0.04)
	var world := runtime.world
	world.reason = ""
	if ToolMatter.launch(world, runtime.body, pose, action, loaded_plunger):
		loaded_plunger = null
		runtime.shot()
		_cooldown = 0.6 if action.operation == "plunger" else 0.18
	else:
		runtime.say(world.reason)


func tick(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)


func secondary() -> void:
	if action.operation != "plunger":
		return
	if loaded_plunger != null:
		runtime.say("Already loaded")
		return
	if runtime.aimed.is_empty():
		return
	var plunger := runtime.aimed["collider"] as PhysicsProp
	if plunger == null or plunger.definition == null or plunger.definition.contraption_component != "plunger":
		runtime.say("Aim at a plunger to reload")
		return
	if plunger.global_position.distance_to(runtime.body.global_position) > 3.0:
		runtime.say("Get closer to the plunger")
		return
	var world := runtime.world
	world.detach_suction(plunger)
	world.forget_projectile(plunger)
	loaded_plunger = plunger
	plunger.freeze = true
	plunger.hide()
	plunger.collision_layer = 0
	plunger.collision_mask = 0
	runtime.shot(0.2)
	runtime.say("Reloaded")


func detail() -> String:
	if action.operation == "plunger":
		return "%s · %s" % [action.verb, "loaded" if loaded_plunger != null else "new plunger"]
	return action.verb


## Putting the launcher away drops a loaded plunger back into the world.
func unbind() -> void:
	if not is_instance_valid(loaded_plunger):
		loaded_plunger = null
		return
	loaded_plunger.global_position = runtime.body.global_position + Vector3.UP * 0.25
	loaded_plunger.freeze = false
	loaded_plunger.show()
	loaded_plunger.collision_layer = 16
	loaded_plunger.collision_mask = 31
	loaded_plunger = null
