class_name GrabberBehaviour
extends ToolBehaviour
## Physics grabber: hold LMB on something up to 10 m away to take it with the
## ordinary hand system (same force budget and mass limit), steer it with the
## view, rotate with MMB, set distance with the wheel; release LMB to let go.


func press() -> void:
	if not runtime.aimed_in_reach():
		runtime.say("Nothing in range")
		return
	var manipulator := runtime.handler.manipulator
	var collider: Object = runtime.aimed["collider"]
	var target := manipulator.resolve_grabbable(collider)
	if target == null and collider is PhysicsProp and (collider as PhysicsProp).definition.grabbable:
		target = collider as RigidBody3D
	if target == null:
		runtime.say("Can't grab that")
		return
	if not manipulator.begin_tool_control(target, action.range_metres, action.mass_limit, action.force):
		runtime.say("Too heavy, or fixed in place")


func release() -> void:
	if runtime.handler != null:
		runtime.handler.manipulator.end_tool_control()


func is_working() -> bool:
	return runtime.handler != null and runtime.handler.manipulator.is_holding()


## While something is held, rotation and distance go to the hand.
func extra_input(event: InputEvent) -> bool:
	if event.is_action("use_tool") or not is_working():
		return false
	return runtime.handler.manipulator.handle_input(event)


func contact() -> Dictionary:
	if not is_working():
		return {}
	var held := runtime.handler.manipulator.get_held_body()
	return {"position": held.global_position, "normal": Vector3.UP} if held != null else {}


func detail() -> String:
	var held: RigidBody3D = runtime.handler.manipulator.get_held_body() if runtime.handler != null else null
	if held != null:
		return "%s · holding %s" % [action.verb, runtime.handler.manipulator.get_grab_name(held)]
	return action.verb


func hints() -> String:
	if is_working():
		return "[Release LMB] Drop   [MMB] Rotate   [Wheel] Distance"
	return action.primary_hint


func unbind() -> void:
	release()
