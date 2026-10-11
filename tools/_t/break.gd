extends SceneTree

const CASES := [
	["garden/outdoor_dining_table", Vector3(0.0, 0.73, 0.0), "glass top"],
	["office/filing_cabinet", Vector3(0.0, 0.4, -0.3), "steel front"],
	["living_room/sofa_three_seater", Vector3(-0.95, 0.45, 0.0), "fabric arm"],
	["kitchen/dining_chair", Vector3(-0.19, 0.2, -0.2), "oak leg"],
	["bathroom/toilet", Vector3(0.0, 0.7, 0.28), "ceramic cistern"],
	["laboratory/lab_workbench", Vector3(0.0, 0.92, 0.0), "epoxy top"],
]

var _frame := 0
var _bodies := []
var _cells := []


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		var floor_body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(200, 1, 200)
		shape.shape = box
		floor_body.add_child(shape)
		floor_body.position.y = -0.5
		root.add_child(floor_body)
		var x := 0.0
		for c in CASES:
			var body := VoxelBody.new()
			body.structure = load("res://furniture/%s.tres" % c[0])
			root.add_child(body)
			body.global_position = Vector3(x, 0.02, 0.0)
			_bodies.append(body)
			x += 4.0
	if _frame == 120:
		for i in CASES.size():
			var body: VoxelBody = _bodies[i]
			_cells.append(body.cells.size())
			var bounds := body.get_cell_bounds()
			# Aim relative to the piece's centre (offsets are rough, in metres).
			var centre := body.global_transform * ((bounds.position + bounds.size * 0.5) * body.voxel_size)
			var target: Vector3 = Vector3(centre.x, body.global_position.y, centre.z) + CASES[i][1]
			body.damage_at(target, 0.12, 60.0, Vector3.FORWARD)
	if _frame == 300:
		for i in CASES.size():
			var body: VoxelBody = _bodies[i]
			var pieces := 0
			for node in root.get_children():
				if node is VoxelBody and node.name != "Rubble" and not _bodies.has(node):
					pieces += 0
			print("%-22s %-16s removed %4d of %5d voxels   upright %.2f" % [CASES[i][0].get_file(), CASES[i][2], _cells[i] - body.cells.size(), _cells[i], body.global_basis.y.normalized().dot(Vector3.UP)])
		var loose := 0
		for node in root.get_children():
			if node is VoxelBody and not _bodies.has(node):
				loose += 1
		print("loose pieces and rubble in the scene: %d" % loose)
		return true
	return false
