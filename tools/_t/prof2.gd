extends SceneTree

var _frame := 0

func _process(_d: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	var definition: VoxelStructureDefinition = load("res://furniture/living_room/wingback_chair.tres")
	for i in 3:
		var body := VoxelBody.new()
		body.structure = definition
		var t := Time.get_ticks_usec()
		root.add_child(body)
		body.position = Vector3(i * 2, 0, 0)
		print("wingback copy %d: %.1f ms" % [i + 1, (Time.get_ticks_usec() - t) / 1000.0])
	return true
