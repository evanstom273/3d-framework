class_name NPCNavigation
extends Node
## Route planning for NPCs: one per scene, made by the first NPC that needs it.
##
## Bakes a navigation mesh from the scene's fixed geometry (StaticBody3D
## colliders on the world layer: walls, floors, stair ramps, fences, steps) on a
## worker thread. Furniture and loose things (rigid bodies) are stamped in as
## obstructions where they stood at bake time, and the mesh is rebaked when an
## NPC finds itself stuck (something's been moved). Doors, gates and garage
## doors aren't, so doorways stay walkable; NPCs open them as they reach them.
## A door found locked is blocked off (its doorway carved out of the mesh and
## rebaked) so routes go another way; it's opened up again once unlocked.

const AGENT_RADIUS := 0.3
const AGENT_HEIGHT := 1.75
const MAX_CLIMB := 0.35
const MAX_SLOPE := 45.0
const CELL := 0.1
const CELL_HEIGHT := 0.05
## Baked area round the first NPC (half-size, metres).
const REACH := 50.0
## Locked doors are re-checked this often (seconds) in case someone unlocked them.
const RECHECK := 5.0
## Rebakes asked for (an NPC stuck on something moved) at most this often.
const REBAKE_GAP := 4.0
## Lower than this he steps over or nudges aside; bigger than this isn't furniture.
const MIN_OBSTACLE := 0.3
const MAX_OBSTACLE := 6.0

var is_ready := false
## Goes up with every bake, so NPCs know to plan their routes again.
var bakes := 0
var _map: RID
var _region: RID
var _mesh: NavigationMesh
var _source: NavigationMeshSourceGeometryData3D
var _baking := false
var _rebake := false
var _blocked: Dictionary = {}
var _recheck := RECHECK
var _last_bake := -INF
var _bake_at := INF


## The scene's navigator, created (and its first bake started) on first use.
static func for_scene(context: Node) -> NPCNavigation:
	var tree := context.get_tree()
	var scene: Node = tree.current_scene if tree.current_scene != null else tree.root
	var existing := scene.get_node_or_null(^"NPCNavigation") as NPCNavigation
	if existing != null:
		return existing
	var navigation := NPCNavigation.new()
	navigation.name = "NPCNavigation"
	scene.add_child(navigation)
	navigation.start((context as Node3D).global_position if context is Node3D else Vector3.ZERO)
	return navigation


func start(centre: Vector3) -> void:
	_map = get_viewport().find_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(_map, CELL)
	NavigationServer3D.map_set_cell_height(_map, CELL_HEIGHT)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)
	_mesh = NavigationMesh.new()
	_mesh.agent_radius = AGENT_RADIUS
	_mesh.agent_height = AGENT_HEIGHT
	_mesh.agent_max_climb = MAX_CLIMB
	_mesh.agent_max_slope = MAX_SLOPE
	_mesh.cell_size = CELL
	_mesh.cell_height = CELL_HEIGHT
	_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_mesh.geometry_collision_mask = 1
	_mesh.filter_baking_aabb = AABB(centre - Vector3(REACH, 20.0, REACH), Vector3(REACH * 2.0, 40.0, REACH * 2.0))
	_source = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(_mesh, _source, get_parent())
	_bake()


func _exit_tree() -> void:
	if _region.is_valid():
		NavigationServer3D.free_rid(_region)


func _bake() -> void:
	if _baking:
		_rebake = true
		return
	_baking = true
	_last_bake = Time.get_ticks_msec() / 1000.0
	var source := _source.duplicate() as NavigationMeshSourceGeometryData3D
	_add_obstacles(source)
	# Locked doorways are carved out, so routes avoid them.
	for door in _blocked:
		var box: AABB = _blocked[door]
		var low := box.position
		var high := box.end
		source.add_projected_obstruction(PackedVector3Array([Vector3(low.x, 0, low.z), Vector3(high.x, 0, low.z),
			Vector3(high.x, 0, high.z), Vector3(low.x, 0, high.z)]), low.y - 0.2, box.size.y + 0.4, true)
	var mesh := _mesh.duplicate() as NavigationMesh
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _baked.bind(mesh))


func _baked(mesh: NavigationMesh) -> void:
	_baking = false
	if not is_inside_tree():
		return
	NavigationServer3D.region_set_navigation_mesh(_region, mesh)
	is_ready = true
	bakes += 1
	if _rebake:
		_rebake = false
		_bake()


func _physics_process(delta: float) -> void:
	if Time.get_ticks_msec() / 1000.0 >= _bake_at:
		_bake_at = INF
		_bake()
	_recheck -= delta
	if _recheck > 0.0 or _blocked.is_empty():
		return
	_recheck = RECHECK
	var changed := false
	for door in _blocked.keys():
		if not is_instance_valid(door) or not (door.has_method(&"is_locked") and bool(door.call(&"is_locked"))):
			_blocked.erase(door)
			changed = true
	if changed:
		_bake()


## Furniture and loose things, as footprints where they stand now. Anything
## overhead within a body's height of the floor counts too (a table top).
func _add_obstacles(source: NavigationMeshSourceGeometryData3D) -> void:
	for node in get_parent().find_children("*", "RigidBody3D", true, false):
		var body := node as RigidBody3D
		if body is NPCCarryHandle or not body.is_inside_tree() or _skip(body):
			continue
		var box := _bounds(body)
		if box.size.y < MIN_OBSTACLE or box.size.x > MAX_OBSTACLE or box.size.z > MAX_OBSTACLE:
			continue
		var low := box.position
		var high := box.end
		var bottom := low.y - AGENT_HEIGHT * 0.9
		source.add_projected_obstruction(PackedVector3Array([Vector3(low.x, 0, low.z), Vector3(high.x, 0, low.z),
			Vector3(high.x, 0, high.z), Vector3(low.x, 0, high.z)]), bottom, high.y - bottom, false)


## NPC bodies aren't obstacles; nor are doors, gates and windows while shut (he opens
## them). Open ones are: a door standing open is in the way like anything else.
func _skip(body: Node) -> bool:
	var node := body.get_parent()
	for depth in 6:
		if node == null or node is FurnitureAssembly:
			return false
		if node is NPCCharacter:
			return true
		if node.has_meta(&"door") or node.has_method(&"is_open") and node.has_method(&"get_interaction_actions"):
			return not is_open(node)
		node = node.get_parent()
	return false


static func is_open(door: Node) -> bool:
	if door.has_method(&"is_open"):
		return bool(door.call(&"is_open"))
	return bool(door.get(&"_is_open"))


## A door's just been opened (or shut): rebake once it's finished moving.
func door_moved(seconds: float) -> void:
	_bake_at = Time.get_ticks_msec() / 1000.0 + seconds


static func _bounds(body: RigidBody3D) -> AABB:
	if body is VoxelBody:
		var voxels := body as VoxelBody
		var cells := voxels.get_cell_bounds()
		return body.global_transform * AABB(cells.position * voxels.voxel_size, cells.size * voxels.voxel_size)
	var box := AABB()
	var first := true
	for owner_id in body.get_shape_owners():
		var at := body.global_transform * body.shape_owner_get_transform(owner_id)
		for index in body.shape_owner_get_shape_count(owner_id):
			var shape_box := at * body.shape_owner_get_shape(owner_id, index).get_debug_mesh().get_aabb()
			box = shape_box if first else box.merge(shape_box)
			first = false
	return box


## Something's in the way that wasn't when the mesh was baked: bake it again.
func request_rebake() -> void:
	if Time.get_ticks_msec() / 1000.0 - _last_bake > REBAKE_GAP:
		_bake()


func is_baking() -> bool:
	return _baking


## A route (corner points) from `from` to `to`, or empty if there isn't one yet.
func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not is_ready or NavigationServer3D.map_get_iteration_id(_map) == 0:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(_map, from, to, true)


## Somewhere walkable within `radius` of `origin` (on the mesh), or INF.
func random_near(origin: Vector3, radius: float) -> Vector3:
	if not is_ready:
		return Vector3.INF
	for attempt in 6:
		var angle := randf() * TAU
		var candidate := origin + Vector3(cos(angle), 0, sin(angle)) * randf_range(1.0, radius)
		var point := NavigationServer3D.map_get_closest_point(_map, candidate)
		if point.distance_to(candidate) < 0.6 and absf(point.y - origin.y) < 0.4:
			return point
	return Vector3.INF


## Marks a door as locked: its doorway (the leaves' bounds) is carved out of the
## mesh and rebaked, so routes go round. Unblocked again once it's unlocked.
func block_door(door: Node, bounds: AABB) -> void:
	if _blocked.has(door):
		return
	_blocked[door] = bounds.grow(0.15)
	_recheck = RECHECK
	_bake()


func is_blocked(door: Node) -> bool:
	return _blocked.has(door)
