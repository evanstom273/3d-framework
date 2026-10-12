extends SceneTree
## Each gate / garage door in turn: NPC one side, stand-in player the other, following.
var _f := 0
var _s: Node
var npc: NPCCharacter
var player: CharacterBody3D
var doors: Array = []
var _i := -1
var _t := 0
var _side := 1.0
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		var real := _s.get_node_or_null("Player")
		if real != null: real.free()
		player = CharacterBody3D.new()
		_s.add_child(player)
		var cam := Camera3D.new(); cam.position.y = 1.6; player.add_child(cam); cam.current = true
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		npc.position = Vector3(5.6, 0.3, 4.6)
		_s.add_child(npc)
		return false
	if _f == 2:
		for n in _s.find_children("*", "", true, false):
			if n.has_meta(&"door") and n is KitMechanism:
				doors.append(n)
		print("kit doors: ", doors.size())
	if npc.life == NPCCharacter.Life.BUILDING or npc.brain._nav == null or not npc.brain._nav.is_ready:
		return false
	_t -= 1
	if _t <= 0:
		if _i >= 0: _report()
		_i += 1
		if _i >= doors.size(): return true
		_place()
		_t = 60 * 12
	return false

func _box(d: Node) -> AABB:
	return npc.brain._leaves_bounds(d)

func _place() -> void:
	var d: Node3D = doors[_i]
	var b := _box(d)
	var c := b.get_center(); c.y = b.position.y
	var n := Vector3(1, 0, 0) if b.size.x < b.size.z else Vector3(0, 0, 1)
	# which side has floor: try both
	npc.velocity = Vector3.ZERO
	npc.global_position = c + n * 1.3 + Vector3.UP * 0.05
	player.global_position = c - n * 2.5
	npc.home = npc.global_position
	npc.brain.set_following(true)
	_side = n.dot(npc.global_position - c)

func _report() -> void:
	var d: Node3D = doors[_i]
	var b := _box(d); var c := b.get_center()
	var n := Vector3(1, 0, 0) if b.size.x < b.size.z else Vector3(0, 0, 1)
	var crossed := signf(n.dot(npc.global_position - c)) != signf(_side)
	print("%-30s %-8s open=%s crossed=%s npc %s, %.1f m from player" % [d.interaction_name, d.get_path().get_name(d.get_path().get_name_count()-2), d.is_open(), crossed, npc.global_position.snapped(Vector3.ONE*0.01), npc.global_position.distance_to(player.global_position)])
	d.set_open(false)

func _process(_d: float) -> bool:
	if _i >= 0 and _i < doors.size() and _t % 120 == 1:
		var d: Node = doors[_i]
		var r: PackedVector3Array = npc.brain._route

		if false: print("  %s state %s npc %s route %d idx %d actions %s bounds %s" % [d.interaction_name, NPCBrain.State.keys()[npc.brain.state], npc.global_position.snapped(Vector3.ONE*0.01), r.size(), npc.brain._route_index, d.get_interaction_actions().map(func(a): return a["id"]), _box(d)])
	return false

func _dbg() -> void:
	var d: Node = doors[_i]
	var c := _box(d).get_center()
	var dir := c - npc.global_position; dir.y = 0; dir = dir.normalized()
	var space := npc.get_world_3d().direct_space_state
	for h: float in [1.0, 0.5]:
		var from := npc.global_position + Vector3.UP * h
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 1.6, 1 | 16)
		q.exclude = npc.own_rids()
		var hit := space.intersect_ray(q)
		if hit.is_empty(): print("    ", h, " nothing"); continue
		var n: Node = hit["collider"]; var chain := []
		for k in 5:
			if n == null: break
			chain.append(n.name); n = n.get_parent()
		print("    ", h, " ", hit["position"], chain, " door_of=", npc.brain._door_of(hit["collider"]), " shape=", npc.brain._door_shapes.get(d))
