extends SceneTree
## A stand-in player holding a tool walks up to the Assistant; how far does he go?
class FakeTools extends RefCounted:
	func is_equipped() -> bool:
		return true
var _f := 0
var npc: NPCCharacter
var player: CharacterBody3D
var _start := Vector3.ZERO
var _max_speed := 0.0
var _last := Vector3.ZERO
var _states := {}
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(30, 1, 30)
		body.add_child(shape)
		body.position.y = -0.5
		root.add_child(body)
		player = CharacterBody3D.new()
		player.set_script(load("res://tools/_t/fake_player.gd"))
		player.position = Vector3(0, 0, -6)
		root.add_child(player)
		var camera := Camera3D.new()
		camera.position.y = 1.6
		player.add_child(camera)
		camera.current = true
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		root.add_child(npc)
	if npc.life != NPCCharacter.Life.ALIVE:
		return false
	if _start == Vector3.ZERO:
		_start = npc.global_position
		_last = _start
	# Walk the player straight at him, stopping 1 m away.
	var to := npc.global_position - player.global_position
	to.y = 0
	if to.length() > 1.0:
		player.global_position += to.normalized() * 2.0 / 60.0
	var speed := npc.global_position.distance_to(_last) * 60.0
	_max_speed = maxf(_max_speed, speed)
	_last = npc.global_position
	var key: String = NPCBrain.State.keys()[npc.brain.state]
	_states[key] = int(_states.get(key, 0)) + 1
	if _f == 420:
		print("armed player approach: NPC moved %.2f m, top speed %.2f m/s, guard %s, states %s" % [npc.global_position.distance_to(_start), _max_speed, npc.rig.guard, _states])
		return true
	return false
