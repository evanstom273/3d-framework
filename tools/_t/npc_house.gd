extends SceneTree
## The Assistant pottering about the Taskmaster house living room for 90 s.
var _f := 0
var _s: Node
var npc: NPCCharacter
var _states := {}
var _distance := 0.0
var _last := Vector3.ZERO
var _grind := 0
var _max_speed := 0.0
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
	if _f == 3:
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		npc.position = Vector3(2.4, 0.3, 4.6)
		_s.add_child(npc)
	if _f > 30 and npc != null and npc.life == NPCCharacter.Life.ALIVE:
		var key: String = NPCBrain.State.keys()[npc.brain.state]
		_states[key] = int(_states.get(key, 0)) + 1
		var step := npc.global_position.distance_to(_last) if _last != Vector3.ZERO else 0.0
		_distance += step
		_max_speed = maxf(_max_speed, step * 60.0)
		# Trying to walk but not getting anywhere.
		if npc.brain._heading.length() > 0.3 and step * 60.0 < 0.1:
			_grind += 1
		_last = npc.global_position
		if _f % 900 == 0:
			print("t=%ds at %s state %s" % [_f / 60, npc.global_position, key])
	if _f == 30 + 90 * 60:
		print("walked %.1f m, top speed %.2f m/s, frames grinding %d, states %s, home %s, now %s, upright %.2f" % [_distance, _max_speed, _grind, _states, npc.home, npc.global_position, npc.bodies[0].global_basis.y.dot(Vector3.UP)])
		return true
	return false
