extends SceneTree
var _done := false
func _process(_d: float) -> bool:
	if _done:
		return true
	_done = true
	VoxelBody.prepare_bake()
	var rows := []
	for folder in ["living_room", "kitchen", "bedroom", "bathroom", "office", "laboratory", "workshop", "garden", "utility"]:
		for file in DirAccess.get_files_at("res://furniture/%s/" % folder):
			if not file.ends_with(".tres"): continue
			var def := load("res://furniture/%s/%s" % [folder, file]) as VoxelStructureDefinition
			var baked := VoxelBody.bake(def)
			var b := VoxelBody.new()
			var t0 := Time.get_ticks_usec()
			b.apply_baked(baked)
			var t1 := Time.get_ticks_usec()
			root.add_child(b)
			var t2 := Time.get_ticks_usec()
			var shapes := 0
			shapes = b.get_shape_owners().size()
			rows.append([(t2 - t0) / 1000.0, file.get_basename(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, shapes, b.cells.size(), def.moving_parts.size()])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows.slice(0, 12):
		print("%-24s total %5.1f ms  apply %5.1f  enter tree %5.1f  shapes %4d  voxels %6d  parts %d" % [r[1], r[0], r[2], r[3], r[4], r[5], r[6]])
	var sum := 0.0
	for r in rows: sum += r[0]
	print("average %.1f ms" % (sum / rows.size()))
	return false
