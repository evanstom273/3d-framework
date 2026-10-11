extends SceneTree
var _f := 0
var _b: VoxelBody
var _shapes_before := {}
var _hit_frame := 0
func _visible_meshes(b: Node) -> Array:
	var out := []
	for c in b.get_children(true):
		if c is MeshInstance3D and is_instance_valid(c) and not c.is_queued_for_deletion() and c.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			out.append(c)
	return out
func _shapes(b: Node) -> Dictionary:
	var out := {}
	for id in b.get_shape_owners():
		out["%s|%s" % [b.shape_owner_get_transform(id).origin, b.shape_owner_get_shape(id, 0).size]] = true
	return out
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var floor := StaticBody3D.new()
		var s := CollisionShape3D.new()
		s.shape = BoxShape3D.new()
		s.shape.size = Vector3(20, 1, 20)
		floor.add_child(s)
		floor.position.y = -0.5
		root.add_child(floor)
		_b = VoxelBody.new()
		_b.structure = load("res://furniture/living_room/sofa_three_seater.tres")
		root.add_child(_b)
		print("untouched: %d visible mesh node(s), %d chunks, %d collision shapes" % [_visible_meshes(_b).size(), _b._chunk_cells.size(), _shapes(_b).size()])
		# A second copy shares the combined mesh.
		var copy := VoxelBody.new()
		copy.structure = _b.structure
		root.add_child(copy)
		copy.global_position = Vector3(5, 0, 0)
		print("second copy shares the combined mesh: %s" % (_visible_meshes(copy)[0].mesh == _visible_meshes(_b)[0].mesh))
	if _f == 30:
		_shapes_before = _shapes(_b)
		var t := Time.get_ticks_usec()
		_b.damage_at(_b.global_position + Vector3(0.6, 0.5, -0.4), 0.1, 50.0, Vector3.FORWARD)
		_b._flush_dirty()
		var first := (Time.get_ticks_usec() - t) / 1000.0
		var after := _shapes(_b)
		var kept := 0
		for k in _shapes_before:
			if after.has(k): kept += 1
		print("first hit: %.1f ms | visible mesh nodes now %d, combined left: %d | collision shapes kept %d of %d (now %d)" % [first, _visible_meshes(_b).size(), _b._whole_nodes.size(), kept, _shapes_before.size(), after.size()])
		t = Time.get_ticks_usec()
		_b.damage_at(_b.global_position + Vector3(-0.6, 0.5, -0.4), 0.1, 50.0, Vector3.FORWARD)
		_b._flush_dirty()
		print("second hit: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	if _f > 28 and _f < 34:
		print("frame %d: visible mesh nodes %d" % [_f, _visible_meshes(_b).size()])
	return _f > 36
