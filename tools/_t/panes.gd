extends SceneTree
## For every wall opening: the hole it cuts, and where its door/window leaves
## and panes actually are (world space), to spot leaves outside their hole.
var _f := 0
var _s: Node
func _walls(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is KitWall: out.append(c)
		_walls(c, out)
func _bodies(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is VoxelBody: out.append(c)
		_bodies(c, out)
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
	if _f == 3:
		var walls := []
		_walls(_s, walls)
		for w: KitWall in walls:
			var bodies := []
			_bodies(w, bodies)
			if bodies.is_empty(): continue
			print("== %s/%s" % [w.get_parent().name, w.name])
			for i in w.openings.size():
				var o: KitOpening = w.openings[i]
				var hole: Rect2 = w._holes[i]
				var a := w.global_transform * Vector3(hole.position.x, hole.position.y, 0)
				var b := w.global_transform * Vector3(hole.end.x, hole.end.y, 0)
				print("   hole %-14s %s  y %.2f..%.2f  world x %.2f..%.2f z %.2f..%.2f" % [o.display_name if o.display_name else KitOpening.Kind.keys()[o.kind], KitOpening.DoorStyle.keys()[o.door_style] if o.kind == 0 else KitOpening.WindowStyle.keys()[o.window_style] + "/" + KitOpening.Shape.keys()[o.shape], a.y, b.y, minf(a.x, b.x), maxf(a.x, b.x), minf(a.z, b.z), maxf(a.z, b.z)])
			for body: VoxelBody in bodies:
				var cells := body.get_cell_bounds()
				var box := body.global_transform * AABB(cells.position * body.voxel_size, cells.size * body.voxel_size)
				print("      %-26s y %.2f..%.2f  x %.2f..%.2f  z %.2f..%.2f  frozen %s" % [body.get_parent().name + "/" + body.name, box.position.y, box.end.y, box.position.x, box.end.x, box.position.z, box.end.z, body.freeze])
		return true
	return false
