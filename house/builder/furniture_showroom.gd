@tool
extends Node3D
## Furniture showroom: one room per category, laid out along +X. A room's
## furniture is only spawned when the player first comes near it. Pieces are
## built on worker threads (VoxelBody.bake) and added one a frame, so loading a
## room never stalls the game.

const CATEGORIES := ["living_room", "kitchen", "bedroom", "bathroom", "office", "laboratory", "workshop", "garden", "utility"]
const ROOM := Vector2(14.0, 12.0)
## Rooms within this distance of the player are filled.
const LOAD_DISTANCE := 16.0
## Pieces being built on worker threads at once.
const MAX_BAKES := 2
const GAP := 0.6

var _queue: Array[Dictionary] = []
## Entries being baked, oldest first: {path, cursor, definition, task, result}.
var _baking: Array[Dictionary] = []
var _loaded: Dictionary = {}
var _player: Node3D


@export var physics_feel: PhysicsFeel = preload("res://physics/feel/playful.tres")
## Fill every room in the editor (built gradually, a couple of pieces a frame).
@export var preview_in_editor: bool = true


func _ready() -> void:
	_start_map()
	VoxelBody.prepare_bake()
	_player = get_node_or_null(^"Player") as Node3D
	for i in CATEGORIES.size():
		var x := i * ROOM.x
		var category: String = CATEGORIES[i]
		# Partition walls between rooms, open to the corridor at -Z.
		var wall := KitWall.new()
		wall.wall_type = KitWall.WallType.INTERIOR
		wall.length = ROOM.y
		wall.height = 2.6
		wall.ceiling_height = 2.6
		wall.rotation_degrees.y = -90.0
		wall.position = Vector3(x, 0.0, 0.0)
		add_child(wall)
		var label := Label3D.new()
		label.text = category.capitalize()
		label.font_size = 72
		label.pixel_size = 0.005
		label.outline_size = 10
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.position = Vector3(x + ROOM.x * 0.5, 2.4, -0.5)
		add_child(label)
	var back := KitWall.new()
	back.wall_type = KitWall.WallType.INTERIOR
	back.length = ROOM.x * CATEGORIES.size()
	back.height = 2.6
	back.position = Vector3(0.0, 0.0, ROOM.y)
	back.rotation_degrees.y = 180.0
	back.position.x = ROOM.x * CATEGORIES.size()
	add_child(back)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if preview_in_editor and _loaded.is_empty():
			for i in CATEGORIES.size():
				_loaded[i] = true
				_queue_room(i)
	elif _player != null:
		for i in CATEGORIES.size():
			if _loaded.has(i):
				continue
			var centre := Vector3((i + 0.5) * ROOM.x, 0.0, ROOM.y * 0.5)
			var flat := _player.global_position * Vector3(1, 0, 1)
			if flat.distance_to(centre) < LOAD_DISTANCE:
				_loaded[i] = true
				_queue_room(i)
	while _baking.size() < MAX_BAKES and not _queue.is_empty():
		_start_bake(_queue.pop_front())
	# Finished pieces join in order (so the layout is stable), one per frame.
	if not _baking.is_empty() and WorkerThreadPool.is_task_completed(_baking[0]["task"]):
		var entry: Dictionary = _baking.pop_front()
		WorkerThreadPool.wait_for_task_completion(entry["task"])
		_spawn(entry)


## Worker tasks must be waited for before the scene goes.
func _exit_tree() -> void:
	for entry in _baking:
		WorkerThreadPool.wait_for_task_completion(entry["task"])
	_baking.clear()


func _start_bake(entry: Dictionary) -> void:
	var definition := load(entry["path"]) as VoxelStructureDefinition
	if definition == null:
		return
	var result := {}
	entry["definition"] = definition
	entry["result"] = result
	entry["task"] = WorkerThreadPool.add_task(func() -> void: result["baked"] = VoxelBody.bake(definition))
	_baking.append(entry)


## Queues a room's pieces, laid out in rows (the layout is decided as each
## piece spawns, once its real size is known).
func _queue_room(index: int) -> void:
	var dir := "res://furniture/%s/" % CATEGORIES[index]
	var files := DirAccess.get_files_at(dir)
	files.sort()
	var cursor := {"x": index * ROOM.x + 1.0, "z": 1.5, "row": 0.0, "room": index}
	for file in files:
		var path := dir + file.trim_suffix(".remap")
		if path.ends_with(".tres"):
			_queue.append({"path": path, "cursor": cursor})


func _spawn(entry: Dictionary) -> void:
	var definition: VoxelStructureDefinition = entry["definition"]
	var baked: Dictionary = entry["result"].get("baked", {})
	if baked.is_empty():
		return
	var cursor: Dictionary = entry["cursor"]
	var body := VoxelBody.new()
	body.name = definition.display_name.validate_node_name()
	body.apply_baked(baked)
	var bounds := body.get_cell_bounds()
	var size := bounds.size * definition.voxel_size
	var room_end: float = (int(cursor["room"]) + 1) * ROOM.x - 1.0
	if float(cursor["x"]) + size.x > room_end:
		cursor["x"] = int(cursor["room"]) * ROOM.x + 1.0
		cursor["z"] = float(cursor["z"]) + float(cursor["row"]) + GAP * 2.0
		cursor["row"] = 0.0
	# Line the piece's own bounds up with the cursor, front edge facing the corridor.
	var low := bounds.position * definition.voxel_size
	body.position = Vector3(float(cursor["x"]) - low.x, 0.005 - low.y, float(cursor["z"]) - low.z)
	add_child(body)
	if not Engine.is_editor_hint():
		# It stands exactly on the floor: start asleep, so a room full of
		# furniture costs no contacts until something touches it.
		body.sleeping = true
	cursor["x"] = float(cursor["x"]) + size.x + GAP
	cursor["row"] = maxf(float(cursor["row"]), size.z)
	var label := Label3D.new()
	label.text = definition.display_name
	label.font_size = 24
	label.pixel_size = 0.004
	label.outline_size = 6
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = Vector3(float(cursor["x"]) - GAP - size.x * 0.5, 0.05, float(cursor["z"]) - 0.25)
	add_child(label)


## What res://house/house.gd does for the other maps (in game only).
func _start_map() -> void:
	if Engine.is_editor_hint():
		return
	PhysicsFeel.set_active(physics_feel)
	add_child(SpawnMenu.new())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_playground"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene.call_deferred()
