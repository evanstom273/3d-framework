extends SceneTree

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	var definition: VoxelStructureDefinition = load("res://furniture/living_room/wingback_chair.tres")
	var t := Time.get_ticks_usec()
	var boxes := definition.get_boxes()
	print("parse+merge vox: %.1f ms, %d boxes" % [(Time.get_ticks_usec() - t) / 1000.0, boxes.size()])
	var body := VoxelBody.new()
	body.structure = definition
	t = Time.get_ticks_usec()
	root.add_child(body)
	print("add_child total: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	var all := 0.0
	var coll := 0.0
	var shapes := 0
	for chunk in body._chunk_cells:
		t = Time.get_ticks_usec()
		VoxelMesher.build(body._chunk_cells[chunk], body.cells, body.health, body.palette, body.voxel_size, body.surface_state)
		all += Time.get_ticks_usec() - t
		t = Time.get_ticks_usec()
		shapes += VoxelCollider.merge(body._chunk_cells[chunk]).size()
		coll += Time.get_ticks_usec() - t
	print("mesher %.1f ms, collider merge %.1f ms, %d boxes, %d chunks, palette %d" % [all / 1000.0, coll / 1000.0, shapes, body._chunk_cells.size(), body.palette.size()])
	return true
