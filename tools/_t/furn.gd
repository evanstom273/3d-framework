extends SceneTree

var _frame := 0
var _bodies: Dictionary = {}
var _start_cells: Dictionary = {}


func _initialize() -> void:
	pass


func _setup() -> void:
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, 1, 60)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	root.add_child(floor_body)
	var x := 0.0
	for id in ["sofa_three_seater", "wingback_chair", "coffee_table", "bookcase_tall", "display_cabinet", "floor_lamp"]:
		var path := "res://furniture/living_room/%s.tres" % id
		var start := Time.get_ticks_usec()
		var body := VoxelBody.new()
		body.structure = load(path)
		root.add_child(body)
		body.global_position = Vector3(x, 0.02, 0)
		print("%-20s built in %5.1f ms  cells %5d  mass %5.1f kg" % [id, (Time.get_ticks_usec() - start) / 1000.0, body.cells.size(), body.mass])
		_bodies[id] = body
		_start_cells[id] = body.cells.size()
		x += 3.0


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_setup()
		return false
	if _frame == 240:
		for id in _bodies:
			var body: VoxelBody = _bodies[id]
			var up := body.global_basis.y.normalized().dot(Vector3.UP)
			print("%-20s after 4 s: lost %d voxels, upright %.2f, asleep %s" % [id, _start_cells[id] - body.cells.size(), up, body.sleeping])
		# Smash one coffee table leg.
		var table: VoxelBody = _bodies["coffee_table"]
		var leg := table.global_transform * Vector3(-0.5, 0.2, -0.25)
		var before := root.get_child_count()
		table.damage_at(leg, 0.06, 300.0, Vector3.BACK)
		print("smashed a leg: table cells %d" % table.cells.size())
	if _frame == 360:
		var table: VoxelBody = _bodies["coffee_table"]
		var pieces := 0
		for node in root.get_children():
			if node is VoxelBody and node.name != "Rubble" and not _bodies.values().has(node):
				pieces += 1
		print("after the leg break: %d free pieces, table upright %.2f" % [pieces, table.global_basis.y.normalized().dot(Vector3.UP)])
		return true
	return false
