extends SceneTree
var _f := 0
var _s: Node
var _last := 0
var _worst := 0.0
var _slow := 0
var _frames: Array = []
func _process(_d: float) -> bool:
	var now := Time.get_ticks_usec()
	if _last > 0 and _f > 3:
		var ms := (now - _last) / 1000.0
		_worst = maxf(_worst, ms)
		if ms > 25.0:
			_slow += 1
	_last = now
	return false
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/furniture_showroom.tscn") as PackedScene).instantiate()
		root.add_child(_s)
	if _f == 3:
		for i in range(1, 9):
			_s._loaded[i] = true
			_s._queue_room(i)
	if _f == 700:
		var stats := {"bodies": 0, "mesh_instances": 0, "shapes": 0, "triangles": 0, "surfaces": 0}
		_count(root, stats)
		print("worst frame %.1f ms, frames over 25 ms: %d" % [_worst, _slow])
		print(stats)
		var t0 := Time.get_ticks_usec()
		for i in 60:
			physics_frame.emit()
		return true
	return false
func _count(n: Node, stats: Dictionary) -> void:
	for c in n.get_children(true):
		if c is VoxelBody: stats["bodies"] += 1
		if c is CollisionObject3D: stats["shapes"] += c.get_shape_owners().size()
		if c is MeshInstance3D and c.mesh is ArrayMesh:
			stats["mesh_instances"] += 1
			for s in c.mesh.get_surface_count():
				stats["surfaces"] += 1
				stats["triangles"] += c.mesh.surface_get_array_len(s) / 3
		_count(c, stats)
