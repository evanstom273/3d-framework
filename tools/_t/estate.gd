extends SceneTree
## Loads the Taskmaster house, lets it settle for 5 s, and reports furniture
## that moved, tipped, lost voxels or dropped a door.
var _f := 0
var _scene: Node
var _start := {}
func _bodies(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is VoxelBody:
			out.append(c)
		_bodies(c, out)
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var t := Time.get_ticks_msec()
		_scene = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_scene)
		print("loaded in %d ms" % (Time.get_ticks_msec() - t))
	if _f == 3:
		var list := []
		_bodies(_scene.get_node("Furniture"), list)
		for b in list:
			_start[b] = [b.global_position, b.cells.size(), b.global_basis, String(b.get_parent().name) + "/" + String(b.name)]
			b.tree_exiting.connect(func(): print("EXITING %s at frame %d pos %s cells %d" % [String(b.get_parent().name) + "/" + String(b.name), _f, b.global_position, b.cells.size()]))
		print("furniture bodies: %d" % list.size())
	if _f == 300:
		var bad := 0
		for b in _start:
			if not is_instance_valid(b):
				print("FREED ", b); bad += 1; continue
			var s: Array = _start[b]
			var moved: float = b.global_position.distance_to(s[0])
			var lost: int = s[1] - b.cells.size()
			var tilt := rad_to_deg(acos(clampf(b.global_basis.y.normalized().dot(Vector3.UP), -1, 1)))
			if moved > 0.08 or lost > 0 or tilt > 3.0:
				bad += 1
				print("%-34s moved %.2f  lost %d  tilt %.1f  at %s" % [b.get_parent().name + "/" + b.name, moved, lost, tilt, b.global_position])
		var loose := 0
		for c in _scene.get_children():
			if c is VoxelBody: loose += 1
		print("problems %d, loose pieces in scene root %d" % [bad, loose])
		return true
	return false
