extends SceneTree
var _f := 0
var _s: Node
var npc: NPCCharacter
var player: CharacterBody3D
var door: Node
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		var real := _s.get_node_or_null("Player")
		if real != null: real.free()
		player = CharacterBody3D.new(); player.position = Vector3(5.6, 0.3, 8.0); _s.add_child(player)
		var cam := Camera3D.new(); cam.position.y = 1.6; player.add_child(cam); cam.current = true
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		npc.position = Vector3(5.0, 0.3, 7.6); _s.add_child(npc)
		return false
	if npc.life == NPCCharacter.Life.BUILDING or npc.brain._nav == null or not npc.brain._nav.is_ready:
		return false
	if door == null:
		var wall := _s.find_child("WingEastWall", true, false)
		for n in wall.get_children():
			if n.has_meta(&"door"): door = n
		print("door ", door.get("interaction_name"), " bounds ", npc.brain._leaves_bounds(door), " hinge? ", door.get_script().resource_path)
		npc.brain.set_following(true)
		player.global_position = Vector3(7.2, 0.4, 10.6)
	if _f % 30 == 0:
		var b := npc.brain
		var hit_door = null
		print("t=%.2f %s npc %s open %s leafdist %.2f swing %s stuck %.2f rs %d route %d/%d door_of_shape %s cd %d" % [_f / 60.0, NPCBrain.State.keys()[b.state], npc.global_position.snapped(Vector3.ONE*0.01), door.get("_is_open"), b._leaf_distance(door), b._swing_door != null, b._stuck_time, b._route_stuck, b._route_index, b._route.size(), b._door_shapes.get(door), b._door_cooldown - Time.get_ticks_msec()])
	return _f > 60 * 14
