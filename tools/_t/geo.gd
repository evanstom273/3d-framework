extends SceneTree
var _f := 0
var _s: Node
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		return false
	if _f == 30:
		var space := _s.get_viewport().find_world_3d().direct_space_state
		for z in [9.6, 10.0, 10.5, 11.0, 11.5]:
			for dir in [Vector3.LEFT, Vector3.RIGHT]:
				var q := PhysicsRayQueryParameters3D.create(Vector3(5.45, 1.0, z), Vector3(5.45, 1.0, z) + dir * 6.0, 1)
				var h := space.intersect_ray(q)
				print("z %.1f %s: %s" % [z, "W" if dir.x < 0 else "E", "%s %s" % [h["position"].snapped(Vector3.ONE*0.01), h["collider"].name] if h else "none"])
		var d: Node = _s.find_child("WingEastWall", true, false)
		for n in d.get_children():
			if n.has_meta(&"door"):
				print("open angle ", n.get("open_angle_degrees"), " hinge ", n.get_node("Hinge").global_position if n.has_node("Hinge") else "?")
		return true
	return false
