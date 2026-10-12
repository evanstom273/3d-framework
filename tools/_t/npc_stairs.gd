extends SceneTree
## The Assistant follows a stand-in player up the Taskmaster house stairs.
var _f := 0
var _s: Node
var npc: NPCCharacter
var player: CharacterBody3D
var _path := [Vector3(5.6, 0.3, 3.2), Vector3(6.95, 0.3, 1.2), Vector3(6.95, 0.3, 1.75), Vector3(6.95, 3.3, 5.4), Vector3(6.95, 3.3, 6.1), Vector3(5.5, 3.3, 6.2), Vector3(5.5, 3.3, 3.5)]
var _leg := 0
var _top_y := 0.0
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		# Remove the real player; use a stand-in we can steer.
		var real := _s.get_node_or_null("Player")
		if real != null:
			real.free()
		player = CharacterBody3D.new()
		player.position = _path[0]
		_s.add_child(player)
		var cam := Camera3D.new()
		cam.position.y = 1.6
		player.add_child(cam)
		cam.current = true
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		npc.position = Vector3(5.3, 0.3, 4.2)
		_s.add_child(npc)
		return false
	if npc.life == NPCCharacter.Life.BUILDING:
		return false
	if not npc.brain.following:
		npc.brain.set_following(true)
	# Walk the stand-in along the path at 1.2 m/s (after a short wait).
	if _f > 60 and _leg < _path.size() - 1:
		var a: Vector3 = player.global_position
		var b: Vector3 = _path[_leg + 1]
		var step := 1.2 / 60.0
		if a.distance_to(b) <= step:
			player.global_position = b
			_leg += 1
		else:
			player.global_position = a + (b - a).normalized() * step
	_top_y = maxf(_top_y, npc.global_position.y)
	if _f % 120 == 0:
		print("t=%ds player %s  npc %s  state %s  crumbs %d" % [_f / 60, player.global_position.snapped(Vector3.ONE * 0.01), npc.global_position.snapped(Vector3.ONE * 0.01), NPCBrain.State.keys()[npc.brain.state], npc.brain._trail.size()])
	if _f == 60 * 30:
		print("highest he got: y %.2f (first floor is 3.30); ended %.1f m from the player" % [_top_y, npc.global_position.distance_to(player.global_position)])
		return true
	return false
