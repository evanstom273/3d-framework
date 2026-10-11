extends SceneTree
var _done := false
func _process(_d: float) -> bool:
	if _done: return true
	_done = true
	VoxelBody.prepare_bake()
	var def := load("res://furniture/garden/flower_pot_large.tres") as VoxelStructureDefinition
	var baked := VoxelBody.bake(def)
	var b := VoxelBody.new()
	b.apply_baked(baked)
	root.add_child(b)
	# Time the pieces of a rebuild in isolation.
	var boxes := []
	for chunk in b._chunk_cells:
		boxes.append_array(VoxelCollider.merge(b._chunk_cells[chunk]))
	var body := RigidBody3D.new()
	root.add_child(body)
	var shape := BoxShape3D.new()
	var t := Time.get_ticks_usec()
	for box in boxes:
		var id := body.create_shape_owner(body)
		body.shape_owner_add_shape(id, shape)
		body.shape_owner_set_transform(id, Transform3D(Basis.IDENTITY, Vector3(box[0])))
	print("%d owners in tree: %.1f ms" % [boxes.size(), (Time.get_ticks_usec() - t) / 1000.0])
	var body2 := RigidBody3D.new()
	t = Time.get_ticks_usec()
	for box in boxes:
		var id := body2.create_shape_owner(body2)
		body2.shape_owner_add_shape(id, shape)
		body2.shape_owner_set_transform(id, Transform3D(Basis.IDENTITY, Vector3(box[0])))
	var mid := Time.get_ticks_usec()
	root.add_child(body2)
	print("%d owners before tree: %.1f ms, then entering tree %.1f ms" % [boxes.size(), (mid - t) / 1000.0, (Time.get_ticks_usec() - mid) / 1000.0])
	t = Time.get_ticks_usec()
	for chunk in b._chunk_cells:
		VoxelCollider.merge(b._chunk_cells[chunk])
	print("box merging: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	t = Time.get_ticks_usec()
	b._ensure_whole()
	return false
