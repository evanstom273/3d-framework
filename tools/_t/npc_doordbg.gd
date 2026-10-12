extends SceneTree
var _f := 0
var _s: Node
var npc: NPCCharacter
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		npc.position = Vector3(5.22, 0.3, 6.7)
		_s.add_child(npc)
		return false
	if npc.life == NPCCharacter.Life.BUILDING:
		return false
	if _f % 60 != 0: return false
	var space := npc.get_world_3d().direct_space_state
	for h: float in [1.0, 0.5]:
		var from := npc.global_position + Vector3.UP * h
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0,0,1) * 0.9, 1 | 16)
		q.exclude = npc.own_rids()
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			print(h, " no hit"); continue
		var n: Node = hit["collider"]
		var chain := []
		for i in 8:
			if n == null: break
			chain.append("%s(%s%s)" % [n.name, n.get_class(), " door-meta" if n.has_meta(&"door") else ""])
			n = n.get_parent()
		print(h, " ", hit["position"], " ", chain, " -> ", npc.brain._door_of(hit["collider"]))
	var wall := _s.find_child("KitchenWall", true, false)
	for n in wall.find_children("*", "", true, false):
		if n.has_method("get_interaction_actions"):
			print(n.get_path(), " ", n.get_script().resource_path if n.get_script() else "", " ", npc.brain._leaves_bounds(n), " actions ", n.call("get_interaction_actions"))
	return _f > 130
