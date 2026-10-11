extends SceneTree
## Spawns every furniture piece, a category at a time, lets them settle for 4 s,
## and reports any that lose voxels, tip over or fail to sleep.

const FOLDERS := ["living_room", "kitchen", "bedroom", "bathroom", "office", "laboratory", "workshop", "garden", "utility"]

var _frame := 0
var _folder := -1
var _bodies: Dictionary = {}
var _cells: Dictionary = {}
var _floor: StaticBody3D
var _problems := 0
var _total := 0
var _build_ms := 0.0


func _physics_process(_delta: float) -> bool:
	if _floor == null:
		_floor = StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(200, 1, 200)
		shape.shape = box
		_floor.add_child(shape)
		_floor.position.y = -0.5
		root.add_child(_floor)
	_frame += 1
	if _folder < 0 or _frame > 240:
		_report()
		_folder += 1
		if _folder >= FOLDERS.size():
			print("TOTAL %d pieces, %d with problems, first builds %.0f ms in all" % [_total, _problems, _build_ms])
			return true
		_spawn(FOLDERS[_folder])
		_frame = 0
	return false


func _spawn(folder: String) -> void:
	var dir := "res://furniture/%s/" % folder
	var x := 0.0
	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".tres"):
			continue
		var body := VoxelBody.new()
		body.structure = load(dir + file)
		var start := Time.get_ticks_usec()
		root.add_child(body)
		_build_ms += (Time.get_ticks_usec() - start) / 1000.0
		body.global_position = Vector3(x, 0.02, 0.0)
		x += 3.0
		_bodies[file.get_basename()] = body
		_cells[file.get_basename()] = body.cells.size()


func _report() -> void:
	for id in _bodies:
		var body: VoxelBody = _bodies[id]
		_total += 1
		var lost: int = _cells[id] - body.cells.size()
		var up := body.global_basis.y.normalized().dot(Vector3.UP)
		if lost > 0 or rad_to_deg(acos(clampf(up, -1.0, 1.0))) > 1.5 or not body.sleeping:
			_problems += 1
			print("PROBLEM %-26s lost %d  leaning %.1f deg  asleep %s" % [id, lost, rad_to_deg(acos(clampf(up, -1.0, 1.0))), body.sleeping])
		body.queue_free()
	for node in root.get_children():
		if node is VoxelBody:
			node.queue_free()
	_bodies.clear()
	_cells.clear()
