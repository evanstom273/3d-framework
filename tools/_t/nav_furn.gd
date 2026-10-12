extends SceneTree
## Is furniture in the navmesh as obstacles? For each furniture piece on the ground floor: is its centre walkable?
var _f := 0
var _s: Node
var nav: NPCNavigation
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		return false
	if _f == 60:
		nav = NPCNavigation.new(); nav.name = "NPCNavigation"; _s.add_child(nav); nav.start(Vector3(5, 0, 5))
		var n := 0
		for b in _s.find_children("*", "RigidBody3D", true, false):
			if not nav._skip(b): n += 1
		print("rigid bodies counted as obstacles: ", n)
	if _f > 60 and nav.is_ready and _f % 30 == 0:
		var map := nav._map
		var on := 0; var off := 0; var lines := []
		for fa in _s.find_children("*", "FurnitureAssembly", true, false):
			var box := AABB(); var first := true
			for b in fa.find_children("*", "RigidBody3D", true, false):
				var bb := NPCNavigation._bounds(b)
				box = bb if first else box.merge(bb); first = false
			if first or box.position.y > 1.0 or box.size.y < 0.3: continue
			var c := box.get_center(); c.y = box.position.y
			var p := NavigationServer3D.map_get_closest_point(map, c)
			var walk := Vector2(p.x - c.x, p.z - c.z).length() < 0.05
			if walk: on += 1; lines.append("%s centre %s box %s" % [fa.name, c.snapped(Vector3.ONE*0.01), box.size.snapped(Vector3.ONE*0.01)])
			else: off += 1
		print("furniture with walkable centre: %d, blocked: %d" % [on, off])
		for l in lines.slice(0, 12): print("  ", l)
		# Also: one leaf's raw cell bounds vs transform
		var fa0: Node = _s.find_children("*", "FurnitureAssembly", true, false)[0]
		var leaf: VoxelBody = fa0.find_children("*", "VoxelBody", true, false)[0]
		print(fa0.name, " leaf ", leaf.name, " cells ", leaf.get_cell_bounds(), " vs ", leaf.voxel_size, " pos ", leaf.global_position, " -> ", NPCNavigation._bounds(leaf))
		return true
	return _f > 2000
