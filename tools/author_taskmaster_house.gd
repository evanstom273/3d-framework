extends SceneTree
## Builds res://house/builder/taskmaster_house.tscn: a Taskmaster-style house and
## grounds made only from the house kit (house/kit/kit_*.gd) and the generated
## furniture library (res://furniture/).
##
##   godot --headless --path . -s res://tools/author_taskmaster_house.gd
##
## The saved scene holds kit settings and furniture placements only (kit pieces
## rebuild their geometry when loaded), so it can be opened and edited as normal.
##
## Plan (metres; the front of the house faces -Z, the garden is toward +Z):
##   House, an L: a two-storey main wing (x 0..12, z 0..7) and a single-storey
##   rear wing (x 0..6, z 7..14).
##     Ground floor: living room (bay window, fireplace), hall and stairs,
##     study, the Task Lab; kitchen and utility room in the rear wing.
##     First floor: master bedroom, second bedroom, bathroom, landing.
##   Garage / workshop (x 14..20, z 0..7) on a gravel drive.
##   Shed (x 16..19.5, z 19..22) at the end of the garden path.
##   Raised patio behind the house, lawns, paths, a brick front wall with a
##   pedestrian gate and driveway gates, close-board fences with side gates.

const OUT := "res://house/builder/taskmaster_house.tscn"
## Fingerprint of the scene this script last wrote. If the scene no longer
## matches it (edited by hand), the script refuses to overwrite it unless run
## with `-- --force`.
const STAMP := "res://tools/author_taskmaster_house.stamp"
## Finished floor levels: house ground floor, first floor, garage, shed.
const F := 0.3
const U := 3.3
const G := 0.1
const S := 0.15
const EXT := 0.15
const INT := 0.06
const GAP := 0.04

var estate: Node3D
var created: Array[Node] = []
var furniture_paths: Dictionary = {}
var placed: Array[Dictionary] = []
var stacked: Array[Dictionary] = []
var groups: Dictionary = {}
var landing_floor: KitFloor
var stairs: KitStairs
var _frame := 0


func _physics_process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		1:
			if not _may_overwrite():
				return true
			_scan_furniture()
			_build()
		4:
			_place_stacked()
		6:
			_finish()
			return true
	return false


## False (and says why) when the scene has been edited since this script wrote it.
func _may_overwrite() -> bool:
	if not FileAccess.file_exists(OUT) or OS.get_cmdline_user_args().has("--force"):
		return true
	var recorded := FileAccess.get_file_as_string(STAMP).strip_edges() if FileAccess.file_exists(STAMP) else ""
	if recorded == FileAccess.get_md5(OUT):
		return true
	print("NOT WRITTEN: %s has been edited since it was generated (hand changes would be lost). Re-run with `-- --force` to overwrite it anyway." % OUT)
	return false


# --- Scene plumbing

func _add(parent: Node, node: Node) -> Node:
	parent.add_child(node)
	created.append(node)
	return node


func _group(path: String) -> Node3D:
	if groups.has(path):
		return groups[path]
	var parent: Node = estate
	var parts := path.split("/")
	var key := ""
	for part in parts:
		key = part if key.is_empty() else key + "/" + part
		if not groups.has(key):
			var node := Node3D.new()
			node.name = part
			_add(parent, node)
			groups[key] = node
		parent = groups[key]
	return groups[path]


## A transform running along +X from `a` to `b` (kit convention: -Z is outside).
static func _along(a: Vector2, b: Vector2, y: float) -> Transform3D:
	var d := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
	return Transform3D(Basis(d, Vector3.UP, d.cross(Vector3.UP)), Vector3(a.x, y, a.y))


## A yaw that turns local +Z toward `facing` (switches, wall lights).
static func _face_z(facing: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(facing.x, facing.z))


static func _yaw(facing: String) -> float:
	match facing:
		"+z": return PI
		"+x": return -PI * 0.5
		"-x": return PI * 0.5
	return 0.0


static func _dir(facing: String) -> Vector3:
	match facing:
		"+z": return Vector3.BACK
		"+x": return Vector3.RIGHT
		"-x": return Vector3.LEFT
	return Vector3.FORWARD


# --- Kit helpers

func _wall(group: String, label: String, a: Vector2, b: Vector2, y: float, settings: Dictionary = {}) -> KitWall:
	var wall := KitWall.new()
	wall.name = label
	wall.length = a.distance_to(b)
	for key in settings:
		wall.set(key, settings[key])
	wall.transform = _along(a, b, y)
	_add(_group(group), wall)
	return wall


## Exterior walls: each starts BUTT_EXTERIOR and ends CORNER, going round.
func _ext(group: String, label: String, a: Vector2, b: Vector2, y: float, height: float, openings: Array, settings: Dictionary = {}) -> KitWall:
	var all := {"wall_type": KitWall.WallType.EXTERIOR, "height": height, "start_join": KitWall.Join.BUTT_EXTERIOR,
		"end_join": KitWall.Join.CORNER, "openings": _openings(openings), "quoins": true}
	all.merge(settings, true)
	return _wall(group, label, a, b, y, all)


func _int(group: String, label: String, a: Vector2, b: Vector2, y: float, joins: Vector2i, openings: Array, settings: Dictionary = {}) -> KitWall:
	var all := {"wall_type": KitWall.WallType.INTERIOR, "height": 3.0, "start_join": joins.x, "end_join": joins.y,
		"openings": _openings(openings)}
	all.merge(settings, true)
	return _wall(group, label, a, b, y, all)


static func _openings(list: Array) -> Array[KitOpening]:
	var typed: Array[KitOpening] = []
	for o in list:
		typed.append(o)
	return typed


static func _door(at: float, width := 0.9, style := KitOpening.DoorStyle.FOUR_PANEL, settings: Dictionary = {}) -> KitOpening:
	var o := KitOpening.door(at, width, style)
	for key in settings:
		o.set(key, settings[key])
	return o


static func _window(at: float, width: float, height: float, sill: float, settings: Dictionary = {}) -> KitOpening:
	var o := KitOpening.window(at, width, height, sill)
	for key in settings:
		o.set(key, settings[key])
	return o


static func _doorway(at: float, width: float, height := 2.15) -> KitOpening:
	var o := KitOpening.new()
	o.kind = KitOpening.Kind.OPEN_DOORWAY
	o.position = at
	o.width = width
	o.height = height
	return o


func _floor(group: String, label: String, x: float, z: float, sx: float, sz: float, y: float, finish: KitMaterials.FloorFinish, color: Color, settings: Dictionary = {}) -> KitFloor:
	var floor := KitFloor.new()
	floor.name = label
	floor.size = Vector2(sx, sz)
	floor.finish = finish
	floor.finish_color = color
	for key in settings:
		floor.set(key, settings[key])
	floor.position = Vector3(x, y, z)
	_add(_group(group), floor)
	return floor


## A ground-bearing slab floor (no ceiling under it).
func _slab_floor(group: String, label: String, x: float, z: float, sx: float, sz: float, y: float, finish: KitMaterials.FloorFinish, color: Color, settings: Dictionary = {}) -> KitFloor:
	var all := {"structure": KitFloor.Structure.CONCRETE_SLAB, "ceiling": false, "thickness": 0.3}
	all.merge(settings, true)
	return _floor(group, label, x, z, sx, sz, y, finish, color, all)


func _slab(group: String, label: String, x: float, z: float, sx: float, sz: float, top: float, surface: KitSlab.Surface, thickness := 0.08, settings: Dictionary = {}) -> KitSlab:
	var slab := KitSlab.new()
	slab.name = label
	slab.size = Vector2(sx, sz)
	slab.surface = surface
	slab.thickness = thickness
	for key in settings:
		slab.set(key, settings[key])
	slab.position = Vector3(x, top, z)
	_add(_group(group), slab)
	return slab


## External steps whose top edge is at `top` (x, z) and which run down toward `run`.
func _steps(group: String, label: String, top: Vector3, run: Vector3, width: float, rise: float, settings: Dictionary = {}) -> KitSteps:
	var steps := KitSteps.new()
	steps.name = label
	steps.width = width
	steps.total_rise = rise
	for key in settings:
		steps.set(key, settings[key])
	steps.transform = Transform3D(Basis(Vector3.UP, atan2(-run.x, -run.z)), top)
	_add(_group(group), steps)
	return steps


func _light(group: String, label: String, at: Vector3, circuit: String, style := KitLight.Style.PENDANT, facing := Vector3.BACK, settings: Dictionary = {}) -> KitLight:
	var light := KitLight.new()
	light.name = label
	light.style = style
	light.circuit = circuit
	light.light_range = 6.5
	light.energy = 1.1
	light.shadows = false
	for key in settings:
		light.set(key, settings[key])
	light.transform = Transform3D(_face_z(facing), at)
	_add(_group(group), light)
	return light


func _switch(group: String, label: String, at: Vector3, facing: Vector3, circuit: String, text := "Light switch") -> KitSwitch:
	var switch := KitSwitch.new()
	switch.name = label
	switch.circuit = circuit
	switch.label = text
	switch.transform = Transform3D(_face_z(facing), at)
	_add(_group(group), switch)
	return switch


func _fence(label: String, a: Vector2, b: Vector2, settings: Dictionary = {}) -> KitFence:
	var fence := KitFence.new()
	fence.name = label
	fence.length = a.distance_to(b)
	for key in settings:
		fence.set(key, settings[key])
	fence.transform = _along(a, b, 0.0)
	_add(_group("Grounds/Boundary"), fence)
	return fence


# --- Furniture

func _scan_furniture() -> void:
	for folder in DirAccess.get_directories_at("res://furniture/"):
		if folder in ["vox", "materials"]:
			continue
		for file in DirAccess.get_files_at("res://furniture/%s/" % folder):
			file = file.trim_suffix(".remap")
			if file.ends_with(".tres"):
				furniture_paths[file.get_basename()] = "res://furniture/%s/%s" % [folder, file]


## Places a furniture piece. "center": its footprint is centred on (x, z).
## "back": its back sits GAP off a wall face at `x` (facing ±x) or `z` (facing
## ±z), centred along the wall on the other coordinate. Its base sits at `y`.
func _put(room: String, id: String, x: float, z: float, y: float, facing := "-z", mode := "center", label := "") -> VoxelBody:
	assert(furniture_paths.has(id), "No furniture '%s'" % id)
	var body := VoxelBody.new()
	body.structure = load(furniture_paths[id])
	body.name = label if not label.is_empty() else id.to_pascal_case()
	_add(_group("Furniture/" + room), body)
	body.freeze = true
	body.global_transform = Transform3D(Basis(Vector3.UP, _yaw(facing)), Vector3(x, y, z))
	var box := _world_box(body)
	var shift := Vector3(x - box.get_center().x, y + 0.005 - box.position.y, z - box.get_center().z)
	if mode == "back":
		var d := _dir(facing)
		# The back is the side opposite the front.
		if absf(d.x) > 0.5:
			shift.x = (x + GAP - box.position.x) if d.x > 0.0 else (x - GAP - box.end.x)
		else:
			shift.z = (z + GAP - box.position.z) if d.z > 0.0 else (z - GAP - box.end.z)
	body.global_position += shift
	placed.append({"body": body, "transform": body.global_transform, "room": room})
	return body


## A small item set down on whatever is under (x, z) — a counter, desk or shelf
## top — found by a ray once the big pieces are in. `floor` is the room's floor.
func _on(room: String, id: String, x: float, z: float, floor: float, facing := "-z", label := "") -> void:
	stacked.append({"room": room, "id": id, "x": x, "z": z, "floor": floor, "facing": facing, "label": label})


static func _world_box(body: VoxelBody) -> AABB:
	var cells := body.get_cell_bounds()
	var local := AABB(cells.position * body.voxel_size, cells.size * body.voxel_size)
	return body.global_transform * local


func _place_stacked() -> void:
	var space := estate.get_world_3d().direct_space_state
	for item in stacked:
		var from := Vector3(item["x"], float(item["floor"]) + 2.2, item["z"])
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.4, 1 | 16)
		var hit := space.intersect_ray(query)
		var y: float = hit["position"].y if not hit.is_empty() else float(item["floor"])
		if hit.is_empty() or y < float(item["floor"]) + 0.2:
			push_warning("Nothing to stand %s on at (%.2f, %.2f); placed on the floor" % [item["id"], item["x"], item["z"]])
		_put(item["room"], item["id"], item["x"], item["z"], y + 0.003, item["facing"], "center", item["label"])


func _finish() -> void:
	# Overlap check between footprints (stacked items sit on top, so compare
	# only pieces whose boxes overlap in height by more than a few centimetres).
	var boxes: Array[AABB] = []
	for entry in placed:
		boxes.append(_world_box(entry["body"]).grow(-0.01))
	var clashes := 0
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			var overlap := boxes[i].intersection(boxes[j])
			if overlap.has_volume() and overlap.size.y > 0.05 and overlap.size.x > 0.03 and overlap.size.z > 0.03:
				clashes += 1
				print("  CLASH %s / %s  %s" % [placed[i]["body"].name, placed[j]["body"].name, overlap.size])
	# Put everything back exactly where it was placed and let it be dynamic.
	for entry in placed:
		var body: VoxelBody = entry["body"]
		body.global_transform = entry["transform"]
		body.freeze = false
	for node in created:
		node.owner = estate
	var scene := PackedScene.new()
	var error := scene.pack(estate)
	if error == OK:
		error = ResourceSaver.save(scene, OUT)
	if error == OK:
		var stamp := FileAccess.open(STAMP, FileAccess.WRITE)
		stamp.store_string(FileAccess.get_md5(OUT))
		stamp.close()
	var rooms := {}
	for entry in placed:
		rooms[entry["room"]] = int(rooms.get(entry["room"], 0)) + 1
	print("Saved %s (error %d): %d furniture pieces, %d footprint clashes" % [OUT, error, placed.size(), clashes])
	for room in rooms:
		print("  %-22s %d" % [room, rooms[room]])


# --- The estate

func _build() -> void:
	estate = Node3D.new()
	estate.name = "TaskmasterHouse"
	estate.set_script(load("res://house/house.gd"))
	get_root().add_child(estate)
	_environment()
	_house()
	_garage()
	_shed()
	_grounds()
	_furnish()


func _environment() -> void:
	var template := (load("res://house/builder/house_builder.tscn") as PackedScene).instantiate()
	for label in ["WorldEnvironment", "Sun", "Ground"]:
		var node := template.get_node(label).duplicate()
		_add(estate, node)
		# Copied with its children (the ground's mesh and collision), so save those too.
		for child in node.find_children("*", "", true, false):
			created.append(child)
	# Ground top at y = 0, centred on the plot.
	(estate.get_node("Ground") as Node3D).transform = Transform3D(Basis().scaled(Vector3(2, 1, 2)), Vector3(10, -0.5, 10))
	template.free()
	var player := (load("res://player.tscn") as PackedScene).instantiate() as Node3D
	player.name = "Player"
	_add(estate, player)
	player.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(6.0, 0.05, -9.5))


func _house() -> void:
	var gf := "House/GroundFloor"
	var ff := "House/FirstFloor"
	var brick := {"plinth_drop": 0.35, "band_course_height": 3.0}
	var frame := Color(0.95, 0.95, 0.92)
	# --- Ground floor exterior, going round (L-shaped plan).
	var bay := _window(2.25, 2.4, 1.6, 0.55, {"window_style": KitOpening.WindowStyle.BAY, "projection": 0.6, "display_name": "Bay window"})
	var front_door := _door(6.0, 1.1, KitOpening.DoorStyle.SIX_PANEL, {"door_color": Color(0.12, 0.2, 0.16), "handle": KitOpening.Handle.KNOB, "head": KitOpening.Head.STONE_KEYSTONE, "display_name": "Front door"})
	_ext(gf, "FrontWall", Vector2(0, 0), Vector2(12, 0), F, 3.0, [bay, front_door,
		_window(9.75, 1.5, 1.5, 0.8, {"window_style": KitOpening.WindowStyle.GEORGIAN_BARS})], brick)
	_ext(gf, "EastWall", Vector2(12, 0), Vector2(12, 7), F, 3.0, [
		_window(1.75, 1.2, 1.4, 0.85),
		_window(5.25, 1.0, 1.0, 1.1, {"shape": KitOpening.Shape.CIRCLE, "display_name": "Lab porthole"})], brick)
	_ext(gf, "RearWallMain", Vector2(12, 7), Vector2(6, 7), F, 3.0, [
		_door(1.55, 1.5, KitOpening.DoorStyle.FRENCH, {"display_name": "Lab French doors"}),
		_window(5.25, 0.6, 1.2, 1.0)], brick.merged({"end_join": KitWall.Join.INSIDE_CORNER}))
	_ext(gf, "WingEastWall", Vector2(6, 7), Vector2(6, 14), F, 3.0, [
		_window(2.25, 1.5, 1.2, 1.05),
		_door(3.75, 1.0, KitOpening.DoorStyle.HALF_GLAZED, {"display_name": "Kitchen door"}),
		_window(5.75, 0.9, 1.0, 1.05)], brick)
	_ext(gf, "WingRearWall", Vector2(6, 14), Vector2(0, 14), F, 3.0, [
		_door(1.5, 1.0, KitOpening.DoorStyle.LEDGED_PLANK, {"display_name": "Back door"}),
		_window(4.5, 1.0, 1.0, 1.05)], brick)
	_ext(gf, "WestWall", Vector2(0, 14), Vector2(0, 0), F, 3.0, [
		_window(4.75, 1.2, 1.2, 1.05),
		_window(10.5, 1.5, 1.5, 0.8, {"window_style": KitOpening.WindowStyle.GEORGIAN_BARS})], brick)
	# --- Ground floor interior walls.
	var BE := KitWall.Join.BUTT_EXTERIOR
	var BI := KitWall.Join.BUTT_INTERIOR
	_int(gf, "LivingHallWall", Vector2(4.5, 0), Vector2(4.5, 7), F, Vector2i(BE, BI), [_door(5.0, 1.0, KitOpening.DoorStyle.FOUR_PANEL, {"display_name": "Living room door"})])
	_int(gf, "HallStudyWall", Vector2(7.5, 0), Vector2(7.5, 7), F, Vector2i(BE, BE), [
		_door(0.9, 1.0, KitOpening.DoorStyle.SIX_PANEL, {"display_name": "Study door", "opens_inward": false}),
		_door(6.2, 1.0, KitOpening.DoorStyle.LABORATORY, {"display_name": "Task Lab door"})])
	_int(gf, "KitchenWall", Vector2(0, 7), Vector2(6, 7), F, Vector2i(BE, BE), [
		_doorway(3.6, 1.1),
		_door(5.2, 1.0, KitOpening.DoorStyle.HALF_GLAZED, {"display_name": "Kitchen door", "opens_inward": false})])
	_int(gf, "StudyLabWall", Vector2(7.5, 3.5), Vector2(12, 3.5), F, Vector2i(BI, BE), [])
	_int(gf, "UtilityWall", Vector2(0, 11.5), Vector2(6, 11.5), F, Vector2i(BE, BE), [_door(3.0, 1.0, KitOpening.DoorStyle.FLUSH, {"display_name": "Utility door"})])
	# --- Ground floor floors (concrete slab, one finish per room).
	_slab_floor(gf, "LivingFloor", 0, 0, 4.5, 7, F, KitMaterials.FloorFinish.FLOORBOARDS, Color(0.55, 0.38, 0.24))
	_slab_floor(gf, "HallFloor", 4.5, 0, 3, 7, F, KitMaterials.FloorFinish.CHECKER_TILES, Color(0.85, 0.83, 0.78), {"boards_along_z": true})
	_slab_floor(gf, "StudyFloor", 7.5, 0, 4.5, 3.5, F, KitMaterials.FloorFinish.OAK_PARQUET, Color(0.6, 0.42, 0.26))
	_slab_floor(gf, "LabFloor", 7.5, 3.5, 4.5, 3.5, F, KitMaterials.FloorFinish.TILES, Color(0.9, 0.92, 0.92))
	_slab_floor(gf, "KitchenFloor", 0, 7, 6, 4.5, F, KitMaterials.FloorFinish.CHECKER_TILES, Color(0.2, 0.22, 0.24))
	_slab_floor(gf, "UtilityFloor", 0, 11.5, 6, 2.5, F, KitMaterials.FloorFinish.TILES, Color(0.7, 0.66, 0.6))
	# --- Stairs up the east side of the hall.
	stairs = KitStairs.new()
	stairs.name = "Stairs"
	stairs.width = 0.9
	stairs.left_side = KitStairs.StairSide.OPEN
	stairs.right_side = KitStairs.StairSide.WALL
	stairs.runner = true
	stairs.runner_color = Color(0.42, 0.1, 0.13)
	stairs.position = Vector3(6.5, F, 1.8)
	_add(_group(gf), stairs)
	# --- Fireplace and chimney on the living room's west wall, up through the ridge.
	var chimney := KitChimney.new()
	chimney.name = "Chimney"
	chimney.size = Vector2(1.1, 0.6)
	chimney.height = 9.4
	chimney.breast_height = 5.75
	chimney.fireplace = KitChimney.Fireplace.CAST_IRON
	chimney.pots = 2
	chimney.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(EXT + 0.3, F, 3.5))
	_add(_group(gf), chimney)
	# --- Porch, steps.
	var porch := KitPorch.new()
	porch.name = "Porch"
	porch.width = 2.2
	porch.depth = 1.4
	porch.roof_style = KitPorch.RoofStyle.GABLE
	porch.supports = KitPorch.Supports.TIMBER_POSTS
	porch.platform_drop = F
	porch.position = Vector3(6.0, F, 0.0)
	_add(_group(gf), porch)
	_steps(gf, "FrontSteps", Vector3(6.0, F, -1.4), Vector3.FORWARD, 1.5, F)
	_steps(gf, "BackDoorSteps", Vector3(1.5, F, 14.0 + EXT), Vector3.BACK, 1.2, F)

	# --- First floor exterior.
	_ext(ff, "FrontWall", Vector2(0, 0), Vector2(12, 0), U, 3.0, [
		_window(2.25, 1.5, 1.4, 0.8, {"window_style": KitOpening.WindowStyle.GEORGIAN_BARS}),
		_window(6.0, 0.9, 0.9, 1.0, {"shape": KitOpening.Shape.CIRCLE}),
		_window(9.75, 1.5, 1.4, 0.8, {"window_style": KitOpening.WindowStyle.GEORGIAN_BARS})], {"plinth_drop": 0.0})
	_ext(ff, "EastWall", Vector2(12, 0), Vector2(12, 7), U, 3.0, [
		_window(1.75, 1.0, 1.2, 0.9),
		_window(5.25, 0.8, 1.0, 1.3, {"obscured": true, "window_style": KitOpening.WindowStyle.TOP_HUNG_AWNING})], {"plinth_drop": 0.0})
	_ext(ff, "RearWall", Vector2(12, 7), Vector2(0, 7), U, 3.0, [
		_window(2.25, 0.8, 1.0, 1.3, {"obscured": true, "window_style": KitOpening.WindowStyle.TOP_HUNG_AWNING}),
		_window(5.25, 0.8, 1.2, 1.0)], {"plinth_drop": 0.0})
	_ext(ff, "WestWall", Vector2(0, 7), Vector2(0, 0), U, 3.0, [_window(1.5, 1.0, 1.2, 0.9)], {"plinth_drop": 0.0})
	_int(ff, "BedroomLandingWall", Vector2(4.5, 0), Vector2(4.5, 7), U, Vector2i(BE, BE), [_door(5.6, 1.0, KitOpening.DoorStyle.FOUR_PANEL, {"display_name": "Master bedroom door"})])
	_int(ff, "LandingEastWall", Vector2(7.5, 0), Vector2(7.5, 7), U, Vector2i(BE, BE), [
		_door(0.8, 1.0, KitOpening.DoorStyle.FOUR_PANEL, {"display_name": "Bedroom door", "opens_inward": false}),
		_door(6.0, 1.0, KitOpening.DoorStyle.FLUSH, {"display_name": "Bathroom door", "opens_inward": false})])
	_int(ff, "BedroomBathWall", Vector2(7.5, 3.5), Vector2(12, 3.5), U, Vector2i(BI, BE), [])
	_floor(ff, "MasterBedroomFloor", 0, 0, 4.5, 7, U, KitMaterials.FloorFinish.CARPET, Color(0.55, 0.6, 0.66))
	landing_floor = _floor(ff, "LandingFloor", 4.5, 0, 3, 7, U, KitMaterials.FloorFinish.FLOORBOARDS, Color(0.55, 0.38, 0.24), {"boards_along_z": true})
	_floor(ff, "BedroomFloor", 7.5, 0, 4.5, 3.5, U, KitMaterials.FloorFinish.CARPET, Color(0.7, 0.62, 0.5))
	_floor(ff, "BathroomFloor", 7.5, 3.5, 4.5, 3.5, U, KitMaterials.FloorFinish.TILES, Color(0.92, 0.93, 0.92))
	# Ceilings: a loft floor over the first floor, and over the single-storey wing.
	_floor("House/Roof", "LoftFloor", 0, 0, 12, 7, U + 3.0, KitMaterials.FloorFinish.FLOORBOARDS, Color(0.5, 0.4, 0.3))
	_floor("House/Roof", "WingCeiling", 0, 7, 6, 7, F + 3.0, KitMaterials.FloorFinish.FLOORBOARDS, Color(0.5, 0.4, 0.3))
	# --- Roofs: the main ridge runs along X; the wing's along Z, open where it meets the house.
	var main_roof := KitRoof.new()
	main_roof.name = "MainRoof"
	main_roof.span = 7.0
	main_roof.length = 12.0
	main_roof.tiles = KitMaterials.RoofTile.SLATE
	main_roof.downpipe_drop = U + 3.0
	main_roof.transform = Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), Vector3(12, U + 3.0, 0))
	_add(_group("House/Roof"), main_roof)
	var wing_roof := KitRoof.new()
	wing_roof.name = "WingRoof"
	wing_roof.span = 6.0
	wing_roof.length = 7.0
	wing_roof.tiles = KitMaterials.RoofTile.SLATE
	wing_roof.start_end = KitRoof.End.OPEN
	wing_roof.downpipe_drop = F + 3.0
	wing_roof.position = Vector3(0, F + 3.0, 7)
	_add(_group("House/Roof"), wing_roof)

	# --- Lights (ceilings 0.25 under the floor above) and switches by the doors.
	var warm := {"light_color": Color(1.0, 0.84, 0.64)}
	var c0 := U - 0.25
	var c1 := U + 3.0 - 0.25
	_light(gf, "LivingLight", Vector3(2.4, c0, 3.5), "living", KitLight.Style.PENDANT, Vector3.BACK, warm)
	_light(gf, "HallLight", Vector3(5.5, c0, 3.0), "hall", KitLight.Style.PENDANT, Vector3.BACK, warm)
	_light(gf, "StudyLight", Vector3(9.75, c0, 1.75), "study", KitLight.Style.PENDANT, Vector3.BACK, warm)
	_light(gf, "LabLight", Vector3(9.75, c0, 5.25), "lab", KitLight.Style.FLUSH_DOME, Vector3.BACK, {"light_color": Color(0.95, 0.97, 1.0), "energy": 1.4})
	_light(gf, "KitchenLight", Vector3(3.0, c0, 9.25), "kitchen", KitLight.Style.FLUSH_DOME, Vector3.BACK, warm)
	_light(gf, "UtilityLight", Vector3(3.0, c0, 12.75), "utility", KitLight.Style.FLUSH_DOME, Vector3.BACK, warm)
	_light(ff, "MasterBedroomLight", Vector3(2.4, c1, 3.5), "master_bedroom", KitLight.Style.PENDANT, Vector3.BACK, warm)
	_light(ff, "LandingLight", Vector3(5.5, c1, 3.0), "hall", KitLight.Style.PENDANT, Vector3.BACK, warm)
	_light(ff, "BedroomLight", Vector3(9.75, c1, 1.75), "bedroom", KitLight.Style.PENDANT, Vector3.BACK, warm)
	_light(ff, "BathroomLight", Vector3(9.75, c1, 5.25), "bathroom", KitLight.Style.FLUSH_DOME, Vector3.BACK, warm)
	var h0 := F + 1.2
	var h1 := U + 1.2
	_switch(gf, "LivingSwitch", Vector3(4.5 - INT, h0, 4.3), Vector3.LEFT, "living")
	_switch(gf, "HallSwitch", Vector3(5.15, h0, EXT), Vector3.BACK, "hall", "Hall and landing lights")
	_switch(gf, "OutsideSwitch", Vector3(6.85, h0, EXT), Vector3.BACK, "outside", "Outside lights")
	_switch(gf, "StudySwitch", Vector3(7.5 + INT, h0, 1.6), Vector3.RIGHT, "study")
	_switch(gf, "LabSwitch", Vector3(7.5 + INT, h0, 5.5), Vector3.RIGHT, "lab")
	_switch(gf, "KitchenSwitch", Vector3(4.5, h0, 7 + INT), Vector3.BACK, "kitchen")
	_switch(gf, "UtilitySwitch", Vector3(2.35, h0, 11.5 + INT), Vector3.BACK, "utility")
	_switch(ff, "LandingSwitch", Vector3(4.5 + INT, h1, 4.8), Vector3.RIGHT, "hall", "Hall and landing lights")
	_switch(ff, "MasterBedroomSwitch", Vector3(4.5 - INT, h1, 4.9), Vector3.LEFT, "master_bedroom")
	_switch(ff, "BedroomSwitch", Vector3(7.5 + INT, h1, 1.4), Vector3.RIGHT, "bedroom")
	_switch(ff, "BathroomSwitch", Vector3(7.5 + INT, h1, 5.35), Vector3.RIGHT, "bathroom")
	var lantern := {"light_color": Color(1.0, 0.8, 0.55), "energy": 1.6, "light_range": 7.0}
	_light("Grounds/Lights", "PorchLantern", Vector3(6.95, F + 2.0, -EXT), "outside", KitLight.Style.LANTERN, Vector3.FORWARD, lantern)
	_light("Grounds/Lights", "KitchenDoorLantern", Vector3(6.0 + EXT, F + 2.0, 11.5), "outside", KitLight.Style.LANTERN, Vector3.RIGHT, lantern)
	_light("Grounds/Lights", "LabDoorLantern", Vector3(9.3, F + 2.2, 7.0 + EXT), "outside", KitLight.Style.WALL_LIGHT, Vector3.BACK, lantern)


func _balustrades() -> void:
	# Round the open sides of the stairwell on the landing.
	var well := stairs.stairwell_in(landing_floor)
	if not well.has_area():
		push_warning("No stairwell found in the landing floor")
		return
	var x0 := landing_floor.position.x + well.position.x
	var z0 := landing_floor.position.z + well.position.y
	var z1 := z0 + well.size.y
	var side := KitBalustrade.new()
	side.name = "StairwellBalustrade"
	side.length = z1 - z0
	side.end_newel = true
	side.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(x0 - 0.05, U, z0))
	_add(_group("House/FirstFloor"), side)
	var end := KitBalustrade.new()
	end.name = "StairwellEndBalustrade"
	end.length = 7.5 - INT - x0
	end.start_newel = false
	end.position = Vector3(x0, U, z0 - 0.05)
	_add(_group("House/FirstFloor"), end)


func _garage() -> void:
	var g := "Garage"
	var walls := {"plinth_drop": 0.2}
	_ext(g, "FrontWall", Vector2(14, 0), Vector2(20, 0), G, 2.8, [
		_door(3.0, 2.5, KitOpening.DoorStyle.GARAGE_SECTIONAL, {"height": 2.1, "powered": true, "door_color": Color(0.85, 0.86, 0.84), "display_name": "Garage door"})], walls)
	_ext(g, "EastWall", Vector2(20, 0), Vector2(20, 7), G, 2.8, [_window(2.0, 1.2, 1.0, 1.0)], walls)
	_ext(g, "RearWall", Vector2(20, 7), Vector2(14, 7), G, 2.8, [
		_door(1.5, 1.0, KitOpening.DoorStyle.LEDGED_PLANK, {"height": 2.0, "door_color": Color(0.3, 0.38, 0.3), "display_name": "Workshop back door"})], walls)
	_ext(g, "WestWall", Vector2(14, 7), Vector2(14, 0), G, 2.8, [
		_window(3.5, 1.2, 1.0, 1.0),
		_door(5.5, 1.0, KitOpening.DoorStyle.HALF_GLAZED, {"height": 2.0, "display_name": "Workshop side door"})], walls)
	_slab_floor(g, "Floor", 14, 0, 6, 7, G, KitMaterials.FloorFinish.CONCRETE, Color(0.62, 0.62, 0.6), {"thickness": 0.2})
	var roof := KitRoof.new()
	roof.name = "Roof"
	roof.span = 6.0
	roof.length = 7.0
	roof.pitch = 35.0
	roof.tiles = KitMaterials.RoofTile.CONCRETE_INTERLOCKING
	roof.downpipe_drop = G + 2.8
	roof.position = Vector3(14, G + 2.8, 0)
	_add(_group(g), roof)
	_light(g, "WorkshopLight", Vector3(17, G + 2.8, 3.5), "garage", KitLight.Style.PENDANT, Vector3.BACK, {"drop": 0.7, "energy": 1.6, "light_color": Color(0.95, 0.96, 1.0)})
	_light(g, "BenchLight", Vector3(17, G + 2.8, 5.8), "garage", KitLight.Style.PENDANT, Vector3.BACK, {"drop": 0.9, "energy": 1.2})
	_switch(g, "Switch", Vector3(14 + EXT, G + 1.2, 2.25), Vector3.RIGHT, "garage", "Workshop lights")
	_light("Grounds/Lights", "GarageLantern", Vector3(17.0, G + 2.45, -EXT), "outside", KitLight.Style.LANTERN, Vector3.FORWARD, {"energy": 1.6})


func _shed() -> void:
	var s := "Shed"
	var cladding := {"facade": KitMaterials.Facade.TIMBER_CLADDING, "facade_color": Color(0.42, 0.33, 0.24), "plinth_drop": 0.15, "quoins": false}
	_ext(s, "FrontWall", Vector2(16, 19), Vector2(19.5, 19), S, 2.3, [
		_door(1.75, 1.4, KitOpening.DoorStyle.SHED_DOUBLE, {"height": 1.95, "door_color": Color(0.36, 0.44, 0.34), "head": KitOpening.Head.NONE, "display_name": "Shed doors"})], cladding)
	_ext(s, "EastWall", Vector2(19.5, 19), Vector2(19.5, 22), S, 2.3, [_window(1.5, 0.9, 0.6, 1.1, {"head": KitOpening.Head.NONE, "frame_color": Color(0.36, 0.44, 0.34)})], cladding)
	_ext(s, "RearWall", Vector2(19.5, 22), Vector2(16, 22), S, 2.3, [], cladding)
	_ext(s, "WestWall", Vector2(16, 22), Vector2(16, 19), S, 2.3, [], cladding)
	_slab_floor(s, "Floor", 16, 19, 3.5, 3, S, KitMaterials.FloorFinish.FLOORBOARDS, Color(0.5, 0.4, 0.3), {"thickness": 0.15})
	var roof := KitRoof.new()
	roof.name = "Roof"
	roof.span = 3.5
	roof.length = 3.0
	roof.pitch = 30.0
	roof.tiles = KitMaterials.RoofTile.SLATE
	roof.eaves_overhang = 0.2
	roof.gable_facade = KitMaterials.Facade.TIMBER_CLADDING
	roof.gable_color = Color(0.42, 0.33, 0.24)
	roof.position = Vector3(16, S + 2.3, 19)
	_add(_group(s), roof)
	_light(s, "Light", Vector3(17.75, S + 2.3, 20.5), "shed", KitLight.Style.PENDANT, Vector3.BACK, {"drop": 0.3, "energy": 1.0})
	_switch(s, "Switch", Vector3(16.6, S + 1.2, 19 + EXT), Vector3.BACK, "shed", "Shed light")


func _grounds() -> void:
	var g := "Grounds"
	# Brick front wall to the lane, with a pedestrian gate and driveway gates.
	_wall("Grounds/Boundary", "FrontGardenWall", Vector2(-3, -7), Vector2(23, -7), 0.0, {
		"wall_type": KitWall.WallType.GARDEN, "height": 1.0, "plinth_drop": 0.0,
		"openings": _openings([
			_door(9.0, 1.1, KitOpening.DoorStyle.GATE_PICKET, {"height": 1.0, "head": KitOpening.Head.NONE, "door_color": Color(0.94, 0.94, 0.9), "display_name": "Front gate"}),
			_door(20.0, 3.6, KitOpening.DoorStyle.GATE_DOUBLE_DRIVEWAY, {"height": 1.1, "head": KitOpening.Head.NONE, "door_color": Color(0.12, 0.13, 0.14), "display_name": "Driveway gates"})])})
	var fence := {"height": 1.8}
	_fence("WestFence", Vector2(-3, 26), Vector2(-3, -6.85), fence)
	_fence("EastFence", Vector2(23, -6.85), Vector2(23, 26), fence)
	var rear := fence.duplicate()
	rear["gates"] = _openings([_door(13.0, 1.0, KitOpening.DoorStyle.GATE_TIMBER, {"height": 1.8, "display_name": "Back gate"})])
	_fence("RearFence", Vector2(-3, 26), Vector2(23, 26), rear)
	# Side fences with gates between the front and back gardens.
	for spec in [["WestSideFence", Vector2(-3, 3.5), Vector2(-EXT, 3.5)], ["PassageFence", Vector2(12 + EXT, 3.5), Vector2(14 - EXT, 3.5)], ["EastSideFence", Vector2(20 + EXT, 3.5), Vector2(23, 3.5)]]:
		var a: Vector2 = spec[1]
		var b: Vector2 = spec[2]
		var side := fence.duplicate()
		side["gates"] = _openings([_door(a.distance_to(b) * 0.5, minf(1.0, a.distance_to(b) - 0.5), KitOpening.DoorStyle.GATE_TIMBER, {"height": 1.8, "display_name": "Side gate"})])
		_fence(spec[0], a, b, side)
	# Paths, drive and the raised patio.
	_slab(g, "FrontPath", 5.4, -6.85, 1.2, 4.85, 0.03, KitSlab.Surface.PAVING_FLAGS, 0.06)
	_slab(g, "Driveway", 14.0, -6.85, 6.0, 6.85, 0.04, KitSlab.Surface.GRAVEL, 0.08)
	_slab(g, "Patio", 6.0 + EXT, 7.0 + EXT, 6.15, 3.85, F, KitSlab.Surface.PAVING_FLAGS, F + 0.05, {"edging": true})
	_steps(g, "PatioSteps", Vector3(9.2, F, 11.0), Vector3.BACK, 2.0, F)
	_slab(g, "GardenPath", 8.7, 11.7, 1.0, 7.3, 0.03, KitSlab.Surface.PAVING_FLAGS, 0.06)
	_slab(g, "ShedPath", 9.7, 18.0, 8.5, 1.0, 0.03, KitSlab.Surface.PAVING_FLAGS, 0.06)
	_slab(g, "BinStore", 12.0 + EXT, -2.0, 1.7, 1.6, 0.03, KitSlab.Surface.CONCRETE, 0.06)
	_light("Grounds/Lights", "ShedLantern", Vector3(16.7, S + 1.9, 19 - EXT), "outside", KitLight.Style.LANTERN, Vector3.FORWARD, {"energy": 1.2})


func _furnish() -> void:
	_balustrades()
	_living_room()
	_hall()
	_study()
	_lab()
	_kitchen()
	_utility()
	_master_bedroom()
	_bedroom()
	_bathroom()
	_landing()
	_workshop()
	_shed_contents()
	_garden()


func _living_room() -> void:
	var r := "LivingRoom"
	_put(r, "sofa_three_seater", 4.5 - INT, 3.2, F, "-x", "back")
	_put(r, "coffee_table", 2.6, 3.4, F, "+x")
	_put(r, "wingback_chair", 1.45, 5.35, F, "+x", "center", "TaskmastersThrone")
	_put(r, "footstool", 2.3, 5.35, F, "+x")
	_put(r, "armchair", 1.45, 1.55, F, "+x")
	_put(r, "tv_cabinet", 1.3, 7.0 - INT, F, "-z", "back")
	_put(r, "bookcase_tall", 4.5 - INT, 0.75, F, "-x", "back")
	_put(r, "side_table", 3.95, 1.75, F, "-x")
	_put(r, "floor_lamp", 2.55, 6.5, F)
	_put(r, "magazine_rack", 3.25, 1.2, F, "+x")
	_on(r, "television", 1.3, 6.72, F, "-z")
	_on(r, "table_lamp", 3.95, 1.75, F)
	_on(r, "mantel_clock", EXT + 0.62, 3.5, F, "+x")


func _hall() -> void:
	var r := "Hall"
	_put(r, "console_table", 4.5 + INT, 2.5, F, "+x", "back")
	_put(r, "coat_stand", 4.95, 0.6, F)
	_on(r, "table_lamp", 4.75, 2.1, F)


func _study() -> void:
	var r := "Study"
	_put(r, "executive_desk", 10.3, 1.85, F, "-x")
	_put(r, "office_chair", 11.25, 1.85, F, "-x")
	_put(r, "visitor_chair", 9.05, 1.85, F, "+x")
	_put(r, "office_bookshelf", 8.5, 3.5 - INT, F, "-z", "back")
	_put(r, "storage_cupboard", 9.65, 3.5 - INT, F, "-z", "back")
	_put(r, "filing_cabinet_tall", 11.35, 3.5 - INT, F, "-z", "back")
	_put(r, "whiteboard", 8.05, 2.42, F, "+x")
	_on(r, "computer_monitor", 10.45, 1.85, F, "-x")
	_on(r, "keyboard", 10.05, 1.85, F, "-x")
	_on(r, "desk_lamp", 10.4, 1.15, F, "-x")
	_on(r, "printer", 11.35, 3.1, F, "-z")


func _lab() -> void:
	var r := "TaskLab"
	# Kept clear of the lab door (west) and the French doors' swing (north-east).
	_put(r, "lab_sink", 8.25, 3.5 + INT, F, "+z", "back")
	_put(r, "fume_cupboard", 9.8, 3.5 + INT, F, "+z", "back")
	_put(r, "chemical_cabinet", 12.0 - EXT, 4.25, F, "-x", "back")
	_put(r, "equipment_trolley", 12.0 - EXT, 5.3, F, "-x", "back")
	_put(r, "lab_terminal", 12.0 - EXT, 6.3, F, "-x", "back")
	_put(r, "lab_workbench", 8.85, 5.0, F, "+z")
	_put(r, "lab_stool", 9.1, 5.9, F, "-z")
	_on(r, "microscope", 8.1, 5.22, F, "+z")
	_on(r, "test_tube_stand", 8.45, 5.25, F, "+z")
	_on(r, "glassware_rack", 8.85, 5.25, F, "+z")
	_on(r, "centrifuge", 9.35, 5.15, F, "+z")
	_on(r, "oscilloscope", 11.5, 5.3, F, "-x")


func _kitchen() -> void:
	var r := "Kitchen"
	# Run of units along the west wall, facing into the room.
	var x := EXT
	_put(r, "fridge", x, 7.45, F, "+x", "back")
	_put(r, "base_cabinet", x, 8.08, F, "+x", "back")
	_put(r, "sink_unit", x, 8.92, F, "+x", "back")
	_put(r, "dishwasher", x, 9.74, F, "+x", "back")
	_put(r, "cooker", x, 10.36, F, "+x", "back")
	_put(r, "drawer_cabinet", x, 10.98, F, "+x", "back")
	_put(r, "pantry_cabinet", 1.4, 7.0 + INT, F, "+z", "back")
	_put(r, "bin", 2.3, 7.3, F, "+z")
	# Clear of the hall door, the living-room opening and the utility door.
	_put(r, "dining_table", 4.0, 9.4, F, "+x")
	_put(r, "dining_chair", 3.1, 9.0, F, "+x")
	_put(r, "dining_chair", 3.1, 9.8, F, "+x", "center", "DiningChair2")
	_put(r, "dining_chair", 4.9, 9.0, F, "-x", "center", "DiningChair3")
	_put(r, "dining_chair", 4.9, 9.8, F, "-x", "center", "DiningChair4")
	_on(r, "kettle", 0.5, 8.08, F, "+x")
	_on(r, "toaster", 0.5, 10.95, F, "+x")
	_on(r, "dish_rack", 0.55, 9.2, F, "+x")


func _utility() -> void:
	var r := "Utility"
	_put(r, "washing_machine", 6.0 - EXT, 11.9, F, "-x", "back")
	_put(r, "tumble_dryer", 6.0 - EXT, 12.52, F, "-x", "back")
	_put(r, "freezer", 6.0 - EXT, 13.37, F, "-x", "back")
	_put(r, "utility_shelf", 0.75, 14.0 - EXT, F, "-z", "back")
	_put(r, "coat_rack_wall", 2.85, 14.0 - EXT, F, "-z", "back")
	_put(r, "kitchen_trolley", 0.85, 11.5 + INT, F, "+z", "back")
	_put(r, "laundry_basket", 1.75, 13.55, F)
	_put(r, "plastic_storage_box", 0.55, 12.9, F, "+x")


func _master_bedroom() -> void:
	var r := "MasterBedroom"
	_put(r, "bed_king", 4.5 - INT, 2.6, U, "-x", "back")
	_put(r, "bedside_cabinet", 4.5 - INT, 1.3, U, "-x", "back")
	_put(r, "bedside_cabinet", 4.5 - INT, 3.9, U, "-x", "back", "BedsideCabinet2")
	_put(r, "blanket_chest", 1.9, 2.6, U, "-x")
	_put(r, "wardrobe_double", 1.5, 7.0 - EXT, U, "-z", "back")
	_put(r, "chest_of_drawers", 2.85, 7.0 - EXT, U, "-z", "back")
	_put(r, "dressing_table", EXT, 1.45, U, "+x", "back")
	_put(r, "dressing_stool", 0.95, 1.45, U, "-x")
	_put(r, "mirror_full_length", 0.5, 5.2, U, "+x")
	_on(r, "table_lamp", 4.2, 1.3, U, "-x")
	_on(r, "table_lamp", 4.2, 3.9, U, "-x", "TableLamp2")


func _bedroom() -> void:
	var r := "Bedroom"
	_put(r, "bed_single", 11.2, 3.5 - INT, U, "-z", "back")
	_put(r, "bedside_table", 10.3, 3.5 - INT, U, "-z", "back")
	_put(r, "bedroom_desk", 7.5 + INT, 2.6, U, "+x", "back")
	_put(r, "bedroom_desk_chair", 8.45, 2.6, U, "-x")
	_put(r, "wardrobe_single", 12.0 - EXT, 0.5, U, "-x", "back")
	_put(r, "bedroom_bookshelf", 9.4, 3.5 - INT, U, "-z", "back")
	_put(r, "laundry_basket", 10.0, 0.45, U)
	_on(r, "desk_lamp", 7.9, 2.2, U, "+x")


func _bathroom() -> void:
	var r := "Bathroom"
	_put(r, "bathtub", 10.75, 3.5 + INT, U, "+z", "back")
	_put(r, "toilet", 11.3, 7.0 - EXT, U, "-z", "back")
	_put(r, "pedestal_sink", 9.75, 7.0 - EXT, U, "-z", "back")
	_put(r, "shower_enclosure", 8.05, 3.5 + INT, U, "+z", "back")
	_put(r, "towel_rail_heated", 12.0 - EXT, 6.25, U, "-x", "back")
	_put(r, "bathroom_shelf", 7.5 + INT, 4.95, U, "+x", "back")
	_put(r, "laundry_hamper", 9.35, 4.0, U)
	_put(r, "bathroom_stool", 9.4, 5.3, U)
	_put(r, "toilet_roll_holder", 11.85, 5.9, U, "-x")


func _landing() -> void:
	var r := "Landing"
	_put(r, "bookcase_short", 4.5 + INT, 2.6, U, "+x", "back")


func _workshop() -> void:
	var r := "Workshop"
	_put(r, "workbench_wood", 16.2, 7.0 - EXT, G, "-z", "back")
	_put(r, "shelving_metal", 14.7, 7.0 - EXT, G, "-z", "back")
	_put(r, "tool_chest", 17.65, 7.0 - EXT, G, "-z", "back")
	_put(r, "workbench_metal", 20.0 - EXT, 5.0, G, "-x", "back")
	_put(r, "tool_cabinet", 20.0 - EXT, 3.2, G, "-x", "back")
	_put(r, "storage_rack", 14.0 + EXT, 5.6, G, "+x", "back")
	_put(r, "metal_locker", 14.7, EXT, G, "+z", "back")
	_put(r, "ladder", 19.35, 0.75, G, "-x")
	_put(r, "sawhorse", 16.0, 3.9, G, "-z")
	_put(r, "sawhorse", 17.6, 3.9, G, "-z", "center", "Sawhorse2")
	_put(r, "workshop_stool", 16.2, 5.75, G, "+z")
	_on(r, "pegboard", 16.2, 6.55, G, "-z")
	_on(r, "vice", 15.5, 6.2, G, "-z")
	_on(r, "toolbox", 16.95, 6.15, G, "-z")


func _shed_contents() -> void:
	var r := "Shed"
	_put(r, "workshop_shelving_wood", 16.75, 22.0 - EXT, S, "-z", "back")
	_put(r, "garden_tool_rack", 18.35, 22.0 - EXT, S, "-z", "back")
	_put(r, "wooden_crate_large", 19.5 - EXT, 20.0, S, "-x", "back")
	_put(r, "plastic_storage_box", 16.6, 20.4, S, "+x")
	_put(r, "pallet", 17.85, 20.55, S, "-z")
	_put(r, "folding_chair", 16.55, 19.75, S, "+x")


func _garden() -> void:
	var r := "Garden"
	_put(r, "outdoor_dining_table", 8.0, 9.0, F)
	_put(r, "outdoor_chair", 7.6, 8.1, F, "+z")
	_put(r, "outdoor_chair", 8.4, 8.1, F, "+z", "center", "OutdoorChair2")
	_put(r, "outdoor_chair", 7.6, 9.9, F, "-z", "center", "OutdoorChair3")
	_put(r, "outdoor_chair", 8.4, 9.9, F, "-z", "center", "OutdoorChair4")
	_put(r, "garden_storage_chest", 6.0 + EXT, 8.0, F, "+x", "back")
	_put(r, "flower_pot_large", 11.6, 7.65, F)
	_put(r, "flower_pot_large", 11.6, 10.55, F, "-z", "center", "FlowerPotLarge2")
	_put(r, "picnic_table", 3.0, 19.5, 0.0)
	_put(r, "sun_lounger", 13.4, 14.5, 0.0, "-z")
	_put(r, "sun_lounger", 14.4, 14.5, 0.0, "-z", "center", "SunLounger2")
	_put(r, "garden_bench", 5.0, 26.0, 0.0, "-z", "back")
	_put(r, "garden_planter", -3.0, 16.0, 0.0, "+x", "back")
	_put(r, "garden_planter", -3.0, 18.5, 0.0, "+x", "back", "GardenPlanter2")
	_put(r, "compost_bin", 21.9, 24.9, 0.0)
	_put(r, "wheelbarrow", 20.6, 20.4, 0.0, "-z")
	_put(r, "garden_bench", 1.2, -5.2, 0.0, "+z", "center", "FrontGardenBench")
	_put(r, "flower_pot_large", 4.35, -1.0, 0.0, "-z", "center", "PorchPot")
	_put(r, "flower_pot_large", 7.65, -1.0, 0.0, "-z", "center", "PorchPot2")
	_put(r, "recycling_bin", 12.6, -1.2, 0.03, "-z")
	_put(r, "recycling_bin", 13.4, -1.2, 0.03, "-z", "center", "RecyclingBin2")
