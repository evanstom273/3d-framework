@tool
class_name VoxelBody
extends RigidBody3D
## A destructible body made of voxels. Frozen bodies are fixed structures (walls,
## pillars); unfrozen ones are free pieces that can be grabbed, thrown and broken.
## Voxels live in a sparse grid; each 16³ chunk owns one mesh and a set of merged
## collision boxes, rebuilt only when that chunk changes.
## Tools damage it through receive_tool_impact(), using the impact's damage, power
## and the tool's voxel_damage_radius.

const CHUNK_SIZE := 16
## log2(CHUNK_SIZE): chunk index by arithmetic shift (floors negatives correctly).
const CHUNK_SHIFT := 4
const RUBBLE_LIMIT := 60
## Furniture, props and debris stop drawing beyond this (metres), and stop
## casting shadows beyond SHADOW_DISTANCE. Fixed structures (house walls,
## doors) always draw.
const VIEW_DISTANCE := 40.0
const SHADOW_DISTANCE := 20.0
## Rebuilding collision in this many chunks at once takes the body out of the
## physics world while its shapes are added (see _flush_dirty).
const BULK_REBUILD_CHUNKS := 4
## Most rubble pieces one hit or collision can create.
const RUBBLE_PER_EVENT := 10
const NEIGHBOURS: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1),
]

enum HandState { WORLD, HELD }

## Emitted after the cells' meshes, collision and support state have been rebuilt.
signal geometry_changed
## Mounts migrate before geometry_changed validates the source's remaining cells.
signal cells_transferred(target: VoxelBody, mapping: Dictionary)
## Voxels were knocked out (cell -> palette index), e.g. for blood or dust effects.
signal cells_removed(removed: Dictionary, direction: Vector3, strength: float)
## Something hit this body (a tool, or a moving object striking it while frozen).
## `strength` is roughly the impulse in newton-seconds.
signal impacted(strength: float, point: Vector3, direction: Vector3)
## An advanced tool (blowtorch, saw, grinder, drill, shovel...) worked on this
## body: the operation, where, and the cells it removed (cell -> palette index).
signal tool_worked(operation: StringName, point: Vector3, removed: Dictionary)
## A tool or spray pushed this body while it was frozen (so it couldn't move):
## whatever carries it (an NPC) can react.
signal pushed(impulse: Vector3, point: Vector3)
var surface_state: Dictionary = {}
var _body_properties_dirty: bool = true

## Optional appearance for a whole body (e.g. a glass-only window pane).
## Collision and voxel damage still use the normal material palette.
@export var mesh_material_override: Material

## Live rubble pieces, oldest first, so the count can be capped.
static var _rubble: Array[VoxelBody] = []
## Meshes and collision boxes of undamaged structures, per structure and chunk:
## every untouched copy of the same piece shares them instead of rebuilding.
static var _pristine_chunks: Dictionary = {}
## The combined mesh of each untouched structure (see _ensure_whole).
static var _pristine_whole: Dictionary = {}
## One BoxShape3D per box size, shared by every body's collision.
static var _box_shapes: Dictionary = {}

@export var structure: VoxelStructureDefinition:
	set(value):
		if structure != null and structure.changed.is_connected(_on_structure_changed):
			structure.changed.disconnect(_on_structure_changed)
		structure = value
		if structure != null:
			structure.changed.connect(_on_structure_changed)
		if is_node_ready() and not _building_quietly:
			_build_from_structure()
			_build_parts()
## Free pieces falling below this height are removed.
@export var respawn_below_y: float = -25.0

var voxel_size: float = 0.1
var palette: Array[VoxelMaterialDefinition] = []
## Cell -> palette index.
var cells: Dictionary[Vector3i, int] = {}
## Cell -> remaining health (missing means full health).
var health: Dictionary[Vector3i, float] = {}
## Cells fixed to the world.
var anchors: Dictionary[Vector3i, bool] = {}
var hand_state: HandState = HandState.WORLD
var is_rubble: bool = false

## Chunk -> {cell: true}.
var _chunk_cells: Dictionary[Vector3i, Dictionary] = {}
## Chunk -> nodes built for it.
var _chunk_nodes: Dictionary[Vector3i, Array] = {}
var _dirty: Dictionary[Vector3i, bool] = {}
## Health/colour changes and neighbouring mesh faces do not change collision.
var _collision_dirty: Dictionary[Vector3i, bool] = {}
var _cached_main_material: VoxelMaterialDefinition
var _main_material_dirty: bool = true
var _bounds_min: Vector3i
var _bounds_max: Vector3i
var _bounds_dirty: bool = false
var _flush_queued: bool = false
## Set when voxels are removed, so the next flush checks what is still supported.
var _check_support: bool = false
## Spawned at runtime (rubble, broken pieces, built structures), so reset removes it.
var _spawned: bool = false
## Scales the mass the voxels add up to (from the structure's density_scale;
## carried over to pieces that break off).
var mass_scale: float = 1.0
## True while the voxels are exactly as built from `structure` (see _pristine_chunks).
var _pristine: bool = false
## Set while apply_baked() assigns `structure`, so the setter does not rebuild.
var _building_quietly: bool = false
## Pre-baked moving parts from apply_baked(), used once by FurnitureAssembly.
var baked_parts: Array = []
## Forces distance culling on (e.g. furniture doors, whose structure has no category).
var distance_culled: bool = false
## Frozen and anchorless, it stays frozen when a hit splits it (the biggest
## piece stays put; the rest falls away). For bodies carried by something else.
var hold_when_split: bool = false
## Mesh nodes of the combined mesh while untouched (empty once split into chunks).
var _whole_nodes: Array = []
## Chunk geometry gathered during a first build, for the combined mesh.
var _whole_surfaces: Dictionary = {}
## Chunk -> collision shape owner ids.
var _chunk_owners: Dictionary = {}
## Physics frame until which collisions do no damage (settling in after a build).
var _impacts_from_frame: int = 0
var _spawn_transform: Transform3D
var _impact_memory: Dictionary = {}
## Voxels touched by the last damage_sphere() call.
var _last_damaged_count: int = 0
var _impact_point: Vector3
var _impact_direction: Vector3 = Vector3.DOWN
var _impact_strength: float = 0.0
var _impact_time: int = -100000

## Pieces breaking off within this long of a hit inherit its momentum.
const IMPACT_MEMORY_MSEC := 500


## A free piece holding the given cells, e.g. rubble or a broken-off section.
static func create_piece(piece_cells: Dictionary[Vector3i, int], piece_health: Dictionary[Vector3i, float],
		piece_palette: Array[VoxelMaterialDefinition], size: float) -> VoxelBody:
	var body := VoxelBody.new()
	body.voxel_size = size
	body.palette = piece_palette.duplicate()
	for cell in piece_cells:
		body._set_cell(cell, piece_cells[cell], piece_health.get(cell, -1.0))
	body._spawned = true
	body.name = "VoxelPiece"
	return body


func _ready() -> void:
	if structure != null and cells.is_empty():
		_build_from_structure()
	else:
		_flush_dirty()
	_build_parts()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group(&"physics_props")
	add_to_group(&"voxel_bodies")
	_spawn_transform = global_transform
	collision_layer = 16
	collision_mask = 31
	continuous_cd = cells.size() < 64
	# Needed so hard collisions can break voxels (see ImpactBreaker).
	contact_monitor = true
	max_contacts_reported = 4
	if _body_properties_dirty:
		_update_body()
	if not _spawned:
		# Let a freshly built piece settle without contact jitter counting as a crash.
		_impacts_from_frame = Engine.get_physics_frames() + 90


# --- Prop contract (ObjectManipulator, containers)

func can_be_grabbed() -> bool:
	return not freeze and not cells.is_empty()


func get_grab_name() -> String:
	var material := _main_material()
	var name_part := material.display_name if material != null else "Voxel"
	if is_rubble or cells.size() == 1:
		return "%s Rubble" % name_part
	return "%s Chunk (%d voxels)" % [name_part, cells.size()]


func get_carried_mass(_depth: int = 0) -> float:
	return mass


func is_held() -> bool:
	return hand_state == HandState.HELD


func on_grabbed(_holder: Node) -> void:
	hand_state = HandState.HELD


func on_released(_holder: Node, _thrown: bool) -> void:
	hand_state = HandState.WORLD


func reset_to_spawn() -> void:
	if _spawned:
		queue_free()
	elif structure != null:
		global_transform = _spawn_transform
		_build_from_structure()
		_build_parts()


# --- Damage

func receive_tool_impact(impact: ToolImpact) -> void:
	var radius := impact.tool_definition.voxel_damage_radius * sqrt(maxf(impact.power, 0.0))
	if radius <= 0.0 or cells.is_empty():
		return
	# Step slightly inside the surface so the struck voxel is the one under the hit.
	var centre := to_local(impact.position - impact.normal * voxel_size * 0.25) / voxel_size
	var removed := damage_sphere(centre, radius / voxel_size, impact.damage, impact.impact_type)
	var material := _main_material()
	if material != null:
		impact.feedback_color = material.color
		impact.feedback_sound = material.impact_sound
	if freeze:
		impact.handled = true
	_remember_impact(impact.position, impact.direction, impact.damage)
	_spawn_rubble(removed, impact.direction, impact.damage)
	if not removed.is_empty():
		cells_removed.emit(removed, impact.direction, impact.damage)
	impacted.emit(maxf(impact.impulse.length(), impact.damage), impact.position, impact.direction)


func get_impact_sound() -> int:
	var material := _main_material()
	return material.impact_sound if material != null else ImpactFeedback.Sound.STONE


## Breakage shortly after a hit inherits its momentum (see _detach).
func _remember_impact(point: Vector3, direction: Vector3, strength: float) -> void:
	_impact_point = point
	_impact_direction = direction.normalized() if not direction.is_zero_approx() else Vector3.DOWN
	_impact_strength = strength
	_impact_time = Time.get_ticks_msec()


## Damages voxels around a world point (e.g. a collision). Returns the struck
## material's colour, or a transparent colour if no voxel was in range.
func damage_at(point: Vector3, radius: float, damage: float, direction: Vector3) -> Color:
	if cells.is_empty() or damage <= 0.0:
		return Color(0, 0, 0, 0)
	var removed := damage_sphere(to_local(point) / voxel_size, radius / voxel_size, damage)
	_remember_impact(point, direction, damage)
	_spawn_rubble(removed, direction, damage)
	if not removed.is_empty():
		cells_removed.emit(removed, direction, damage)
	var material := _main_material()
	if material == null or _last_damaged_count == 0:
		return Color(0, 0, 0, 0)
	return material.color


## Damages cells within `radius` (in cells) of `centre` (cell space), falling off
## to nothing at the edge. Returns the removed cells with their materials.
func damage_sphere(centre: Vector3, radius: float, damage: float,
		impact_type: PhysicsToolDefinition.ImpactType = PhysicsToolDefinition.ImpactType.BLUNT) -> Dictionary[Vector3i, int]:
	var removed: Dictionary[Vector3i, int] = {}
	_last_damaged_count = 0
	var low := Vector3i((centre - Vector3.ONE * radius).floor())
	var high := Vector3i((centre + Vector3.ONE * radius).floor())
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for z in range(low.z, high.z + 1):
				var cell := Vector3i(x, y, z)
				if not cells.has(cell):
					continue
				var distance := (Vector3(cell) + Vector3.ONE * 0.5).distance_to(centre)
				if distance > radius:
					continue
				_last_damaged_count += 1
				var material := palette[cells[cell]]
				var strength := material.strength
				var dealt := damage * material.damage_multiplier(impact_type) * (1.0 - distance / radius)
				var remaining := float(health.get(cell, strength)) - dealt
				if remaining <= 0.0:
					removed[cell] = cells[cell]
					_remove_cell(cell)
				else:
					health[cell] = remaining
					_mark_dirty(cell)
	return removed


func cell_to_world(cell: Vector3i) -> Vector3:
	return to_global((Vector3(cell) + Vector3.ONE * 0.5) * voxel_size)


## The cell containing a world position.
func world_to_cell(point: Vector3) -> Vector3i:
	return Vector3i((to_local(point) / voxel_size).floor())


## Adds a voxel (construction, repair, cementing). Anchors only apply to fixed
## structures, where they mark voxels resting on the world.
func add_voxel(cell: Vector3i, material: VoxelMaterialDefinition, anchored: bool = false, cell_health: float = -1.0, surfaces: Dictionary = {}) -> void:
	if cells.has(cell) or material == null:
		return
	var index := palette.find(material)
	if index < 0:
		palette.append(material)
		index = palette.size() - 1
	_set_cell(cell, index, cell_health)
	if not surfaces.is_empty(): surface_state[cell] = surfaces.duplicate(true)
	if anchored and freeze:
		anchors[cell] = true


## Removes a voxel and returns [material, health], e.g. to move it into another body.
func take_voxel(cell: Vector3i) -> Array:
	if not cells.has(cell):
		return []
	var material := palette[cells[cell]]
	var cell_health: float = health.get(cell, material.strength)
	var surfaces: Dictionary = surface_state.get(cell, {}).duplicate(true)
	_remove_cell(cell)
	return [material, cell_health, surfaces]


## Starts a new fixed structure (or a free piece if not anchored) with one voxel.
static func create_built(parent: Node, world_cell: Vector3i, size: float, material: VoxelMaterialDefinition, anchored: bool) -> VoxelBody:
	var body := VoxelBody.new()
	body.voxel_size = size
	body.name = "BuiltStructure"
	body._spawned = true
	body.palette = [material]
	body._set_cell(Vector3i.ZERO, 0)
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = anchored
	if anchored:
		body.anchors[Vector3i.ZERO] = true
	parent.add_child(body)
	body.global_transform = Transform3D(Basis(), Vector3(world_cell) * size)
	return body


# --- Grid editing

func _set_cell(cell: Vector3i, palette_index: int, cell_health: float = -1.0) -> void:
	_body_properties_dirty = true
	if not cells.has(cell):
		_collision_dirty[_chunk_of(cell)] = true
		if cells.is_empty():
			_bounds_min = cell
			_bounds_max = cell
			_bounds_dirty = false
		else:
			_bounds_min = _bounds_min.min(cell)
			_bounds_max = _bounds_max.max(cell)
	_main_material_dirty = true
	cells[cell] = palette_index
	if cell_health >= 0.0 and cell_health < palette[palette_index].strength:
		health[cell] = cell_health
	else:
		health.erase(cell)
	var chunk := _chunk_of(cell)
	if not _chunk_cells.has(chunk):
		_chunk_cells[chunk] = {}
	_chunk_cells[chunk][cell] = true
	_mark_dirty(cell)


func _remove_cell(cell: Vector3i) -> void:
	if not cells.has(cell):
		return
	_body_properties_dirty = true
	surface_state.erase(cell)
	_main_material_dirty = true
	if cell.x == _bounds_min.x or cell.y == _bounds_min.y or cell.z == _bounds_min.z \
			or cell.x == _bounds_max.x or cell.y == _bounds_max.y or cell.z == _bounds_max.z:
		_bounds_dirty = true
	cells.erase(cell)
	health.erase(cell)
	anchors.erase(cell)
	_check_support = true
	var chunk := _chunk_of(cell)
	_collision_dirty[chunk] = true
	if _chunk_cells.has(chunk):
		_chunk_cells[chunk].erase(cell)
	_mark_dirty(cell)


## Queues the cell's chunk (and any neighbouring chunk whose faces it hid) for rebuild.
func _mark_dirty(cell: Vector3i) -> void:
	# Any edit (damage, paint, building) means this body no longer matches its structure.
	_pristine = false
	_dirty[_chunk_of(cell)] = true
	for offset in NEIGHBOURS:
		var neighbour_chunk := _chunk_of(cell + offset)
		if not _dirty.has(neighbour_chunk) and _chunk_cells.has(neighbour_chunk):
			_dirty[neighbour_chunk] = true
	if not _flush_queued and is_inside_tree():
		_flush_queued = true
		_flush_dirty.call_deferred()


func _chunk_of(cell: Vector3i) -> Vector3i:
	return Vector3i(cell.x >> CHUNK_SHIFT, cell.y >> CHUNK_SHIFT, cell.z >> CHUNK_SHIFT)


## Rebuilds the mesh and collision of every changed chunk, once per frame at most.
func _flush_dirty() -> void:
	_flush_queued = false
	if _check_support and not Engine.is_editor_hint():
		_check_support = false
		_split_disconnected()
	if _dirty.is_empty():
		return
	# First change to an untouched piece: switch from the combined mesh to chunk
	# meshes before rebuilding, reusing the cached meshes of untouched chunks.
	if not _pristine and not _whole_nodes.is_empty():
		_split_whole()
	# Adding shapes to a body already in the physics world is slow (the engine
	# rebuilds its shape after each one: ~40 ms for 500 boxes, against under 1 ms
	# outside it), so a big rebuild briefly takes the body out of the world.
	var space := RID()
	var velocity := Vector3.ZERO
	var spin := Vector3.ZERO
	if is_inside_tree() and _collision_dirty.size() >= BULK_REBUILD_CHUNKS:
		space = PhysicsServer3D.body_get_space(get_rid())
		velocity = linear_velocity
		spin = angular_velocity
		PhysicsServer3D.body_set_space(get_rid(), RID())
	for chunk in _dirty:
		_rebuild_chunk(chunk)
	_dirty.clear()
	if space.is_valid():
		PhysicsServer3D.body_set_space(get_rid(), space)
		PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
		linear_velocity = velocity
		angular_velocity = spin
	if _pristine:
		_ensure_whole()
	if not Engine.is_editor_hint():
		if _body_properties_dirty: _update_body()
		if cells.is_empty():
			_on_emptied()
	geometry_changed.emit()


func _rebuild_chunk(chunk: Vector3i) -> void:
	var rebuild_collision := _collision_dirty.has(chunk)
	_collision_dirty.erase(chunk)
	var nodes: Array = []
	for node in _chunk_nodes.get(chunk, []):
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_chunk_nodes.erase(chunk)
	if rebuild_collision:
		for owner_id in _chunk_owners.get(chunk, []):
			remove_shape_owner(owner_id)
		_chunk_owners.erase(chunk)
	var chunk_cells: Dictionary = _chunk_cells.get(chunk, {})
	if chunk_cells.is_empty():
		_chunk_cells.erase(chunk)
		return
	# An untouched copy of a structure reuses the first copy's mesh and boxes.
	var shared: Dictionary = {}
	if _pristine and structure != null:
		var per_structure: Dictionary = _pristine_chunks.get(structure, {})
		if per_structure.is_empty():
			_pristine_chunks[structure] = per_structure
		if not per_structure.has(chunk):
			var surfaces := VoxelMesher.build_surfaces(chunk_cells, cells, health, palette, voxel_size, surface_state)
			per_structure[chunk] = {"mesh": VoxelMesher.to_mesh(surfaces), "boxes": VoxelCollider.merge(chunk_cells)}
			# Gathered for the combined mesh (see _ensure_whole).
			VoxelMesher.merge(_whole_surfaces, surfaces)
		shared = per_structure[chunk]
	else:
		var mesh := VoxelMesher.build(chunk_cells, cells, health, palette, voxel_size, surface_state)
		if mesh != null:
			nodes.append_array(_add_mesh_nodes(mesh))
	if not rebuild_collision:
		_chunk_nodes[chunk] = nodes
		return
	var boxes: Array = shared["boxes"] if not shared.is_empty() else VoxelCollider.merge(chunk_cells)
	# Boxes go straight to the physics server as shape owners: no scene node per
	# box (a piece has hundreds), and equal-sized boxes share one shape.
	var owners: Array = []
	for box in boxes:
		var low: Vector3i = box[0]
		var high: Vector3i = box[1]
		var size := Vector3(high - low + Vector3i.ONE) * voxel_size
		var shape: BoxShape3D = _box_shapes.get(size)
		if shape == null:
			shape = BoxShape3D.new()
			shape.size = size
			_box_shapes[size] = shape
		var owner_id := create_shape_owner(self)
		shape_owner_add_shape(owner_id, shape)
		shape_owner_set_transform(owner_id, Transform3D(Basis.IDENTITY, (Vector3(low) + size / voxel_size * 0.5) * voxel_size))
		owners.append(owner_id)
	_chunk_owners[chunk] = owners
	_chunk_nodes[chunk] = nodes


## Mesh nodes for one mesh: distance-culled furniture and debris get a view
## range and a shorter-range, shadow-only copy (see VIEW_DISTANCE).
func _add_mesh_nodes(mesh: ArrayMesh) -> Array:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mesh_material_override
	add_child(mesh_instance, false, Node.INTERNAL_MODE_BACK)
	if not _is_distance_culled():
		return [mesh_instance]
	# Seen up to VIEW_DISTANCE, but casting shadows only up to SHADOW_DISTANCE.
	mesh_instance.visibility_range_end = VIEW_DISTANCE
	# A hard cut-off: fading would draw it see-through, a separate shader
	# variant that compiles (and stalls) the first time it's needed.
	mesh_instance.visibility_range_end_margin = 2.0
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shadow := MeshInstance3D.new()
	shadow.mesh = mesh
	shadow.material_override = mesh_material_override
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow.visibility_range_end = SHADOW_DISTANCE
	add_child(shadow, false, Node.INTERNAL_MODE_BACK)
	return [mesh_instance, shadow]


## An untouched piece draws as one combined mesh (one draw call, not one per
## chunk), shared by every untouched copy. Its chunk meshes stay cached, and its
## collision boxes are the usual per-chunk ones, so nothing physical changes.
func _ensure_whole() -> void:
	if not _whole_nodes.is_empty() or structure == null:
		_whole_surfaces.clear()
		return
	var whole: ArrayMesh = _pristine_whole.get(structure)
	if whole == null:
		var per_structure: Dictionary = _pristine_chunks.get(structure, {})
		var complete := not _whole_surfaces.is_empty()
		# Chunks cached by an earlier copy weren't gathered this time: build them.
		for chunk in _chunk_cells:
			if not per_structure.has(chunk):
				complete = false
		if not complete or _whole_surfaces.is_empty():
			_whole_surfaces.clear()
			for chunk in _chunk_cells:
				VoxelMesher.merge(_whole_surfaces, VoxelMesher.build_surfaces(_chunk_cells[chunk], cells, health, palette, voxel_size, surface_state))
		whole = VoxelMesher.to_mesh(_whole_surfaces)
		if whole != null:
			_pristine_whole[structure] = whole
	_whole_surfaces.clear()
	if whole != null:
		_whole_nodes = _add_mesh_nodes(whole)


## The first change to an untouched piece: give every chunk its own mesh node
## from the cache (no rebuilding), then drop the combined mesh, all within this
## one update, so no frame shows both or neither. Only the changed chunks are
## then rebuilt by the caller.
func _split_whole() -> void:
	var per_structure: Dictionary = _pristine_chunks.get(structure, {}) if structure != null else {}
	for chunk in _chunk_cells:
		if _dirty.has(chunk):
			continue
		var shared: Dictionary = per_structure.get(chunk, {})
		if shared.is_empty():
			# Not cached (unexpected): rebuild just its mesh, keeping its collision.
			_dirty[chunk] = true
			continue
		if shared["mesh"] != null:
			var nodes: Array = _chunk_nodes.get(chunk, [])
			nodes.append_array(_add_mesh_nodes(shared["mesh"]))
			_chunk_nodes[chunk] = nodes
	_free_whole()


func _clear_owners() -> void:
	for chunk in _chunk_owners:
		for owner_id in _chunk_owners[chunk]:
			remove_shape_owner(owner_id)
	_chunk_owners.clear()


func _free_whole() -> void:
	for node in _whole_nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_whole_nodes.clear()


## Mass and surface follow the voxels that remain.
func _update_body() -> void:
	_body_properties_dirty = false
	var total := 0.0
	var volume := pow(voxel_size, 3.0)
	for cell in cells:
		total += palette[cells[cell]].density * volume
	total *= mass_scale
	mass = maxf(total, 0.01)
	var material := _main_material()
	if material != null:
		physics_material_override = material.get_physics_material()
	sleeping = false


func _build_from_structure() -> void:
	_free_whole()
	for chunk in _chunk_nodes:
		for node in _chunk_nodes[chunk]:
			if is_instance_valid(node):
				remove_child(node)
				node.queue_free()
	_chunk_nodes.clear()
	_clear_owners()
	_chunk_cells.clear()
	cells.clear()
	surface_state.clear()
	health.clear()
	anchors.clear()
	palette.clear()
	_dirty.clear()
	_collision_dirty.clear()
	_main_material_dirty = true
	_cached_main_material = null
	_bounds_dirty = false
	if structure == null:
		return
	voxel_size = structure.voxel_size
	mass_scale = structure.density_scale
	var lowest := 1 << 30
	for box in structure.get_boxes():
		if box == null or box.material == null:
			continue
		var material := box.get_effective_material()
		var index := palette.find(material)
		if index < 0:
			palette.append(material)
			index = palette.size() - 1
		# Bulk fill: the per-voxel bookkeeping in _set_cell is for edits, not whole builds.
		lowest = mini(lowest, box.min_cell.y)
		for x in range(box.min_cell.x, box.min_cell.x + box.size.x):
			for y in range(box.min_cell.y, box.min_cell.y + box.size.y):
				for z in range(box.min_cell.z, box.min_cell.z + box.size.z):
					var cell := Vector3i(x, y, z)
					cells[cell] = index
					var chunk := Vector3i(x >> CHUNK_SHIFT, y >> CHUNK_SHIFT, z >> CHUNK_SHIFT)
					var members: Dictionary = _chunk_cells.get(chunk, {})
					if members.is_empty():
						_chunk_cells[chunk] = members
					members[cell] = true
	for chunk in _chunk_cells:
		_dirty[chunk] = true
		_collision_dirty[chunk] = true
	_bounds_dirty = true
	_body_properties_dirty = true
	_main_material_dirty = true
	if structure.anchor_mode == VoxelStructureDefinition.AnchorMode.BOTTOM_LAYER:
		for cell in cells:
			if cell.y == lowest:
				anchors[cell] = true
	if not Engine.is_editor_hint():
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = not anchors.is_empty()
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	_pristine = not Engine.is_editor_hint()
	_flush_dirty()


## Does all the heavy work of building `definition` (voxel fill, chunk meshes,
## collision boxes, mass, bounds) without touching the scene, so it can run on a
## WorkerThreadPool thread. Hand the result to apply_baked() on the main thread.
## Call prepare_bake() on the main thread first.
static func bake(definition: VoxelStructureDefinition) -> Dictionary:
	var baked_palette: Array[VoxelMaterialDefinition] = []
	var baked_cells: Dictionary[Vector3i, int] = {}
	var baked_chunks: Dictionary[Vector3i, Dictionary] = {}
	var lowest := 1 << 30
	var low := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var high := -low
	for box in definition.get_boxes():
		if box == null or box.material == null:
			continue
		var material := box.get_effective_material()
		var index := baked_palette.find(material)
		if index < 0:
			baked_palette.append(material)
			index = baked_palette.size() - 1
		lowest = mini(lowest, box.min_cell.y)
		low = low.min(box.min_cell)
		high = high.max(box.min_cell + box.size - Vector3i.ONE)
		for x in range(box.min_cell.x, box.min_cell.x + box.size.x):
			for y in range(box.min_cell.y, box.min_cell.y + box.size.y):
				for z in range(box.min_cell.z, box.min_cell.z + box.size.z):
					var cell := Vector3i(x, y, z)
					baked_cells[cell] = index
					var chunk := Vector3i(x >> CHUNK_SHIFT, y >> CHUNK_SHIFT, z >> CHUNK_SHIFT)
					var members: Dictionary = baked_chunks.get(chunk, {})
					if members.is_empty():
						baked_chunks[chunk] = members
					members[cell] = true
	var size := definition.voxel_size
	var shared := {}
	var whole_surfaces := {}
	for chunk in baked_chunks:
		var members: Dictionary = baked_chunks[chunk]
		var surfaces := VoxelMesher.build_surfaces(members, baked_cells, {}, baked_palette, size)
		shared[chunk] = {"mesh": VoxelMesher.to_mesh(surfaces), "boxes": VoxelCollider.merge(members)}
		VoxelMesher.merge(whole_surfaces, surfaces)
	var total := 0.0
	var counts := {}
	for cell in baked_cells:
		counts[baked_cells[cell]] = counts.get(baked_cells[cell], 0) + 1
	for index in counts:
		total += baked_palette[index].density * pow(size, 3.0) * counts[index]
	# Doors, drawers and lids too, so a whole piece of furniture is ready at once.
	var parts := []
	for part in definition.moving_parts:
		parts.append(bake(part.structure) if part != null and part.structure != null else {})
	return {"structure": definition, "palette": baked_palette, "cells": baked_cells, "chunks": baked_chunks, "parts": parts, "whole": VoxelMesher.to_mesh(whole_surfaces),
		"shared": shared, "lowest": lowest, "low": low, "high": high, "mass": total * definition.density_scale}


## Lazily created statics the bake reads; create them before any thread does.
static func prepare_bake() -> void:
	VoxelMesher.get_material()
	VoxelMesher._prepare()


## Takes over a bake() result (before or after entering the tree). Its meshes and
## boxes go into the pristine cache, so later copies of the same piece reuse them.
func apply_baked(baked: Dictionary) -> void:
	var definition: VoxelStructureDefinition = baked["structure"]
	var per_structure: Dictionary = _pristine_chunks.get(definition, {})
	if per_structure.is_empty():
		_pristine_chunks[definition] = per_structure
	var shared: Dictionary = baked["shared"]
	for chunk in shared:
		if not per_structure.has(chunk):
			per_structure[chunk] = shared[chunk]
	if not _pristine_whole.has(definition) and baked.get("whole") != null:
		_pristine_whole[definition] = baked["whole"]
	# Assigned quietly: the setter would build it all again on the main thread.
	_set_structure_quietly(definition)
	_free_whole()
	for chunk in _chunk_nodes:
		for node in _chunk_nodes[chunk]:
			if is_instance_valid(node):
				remove_child(node)
				node.queue_free()
	_chunk_nodes.clear()
	_clear_owners()
	surface_state.clear()
	health.clear()
	anchors.clear()
	_dirty.clear()
	_collision_dirty.clear()
	voxel_size = definition.voxel_size
	mass_scale = definition.density_scale
	palette = baked["palette"]
	cells = baked["cells"]
	_chunk_cells = baked["chunks"]
	_bounds_min = baked["low"]
	_bounds_max = baked["high"]
	_bounds_dirty = false
	_main_material_dirty = true
	_cached_main_material = null
	for chunk in _chunk_cells:
		_dirty[chunk] = true
		_collision_dirty[chunk] = true
	if definition.anchor_mode == VoxelStructureDefinition.AnchorMode.BOTTOM_LAYER:
		for cell in cells:
			if cell.y == int(baked["lowest"]):
				anchors[cell] = true
	if not Engine.is_editor_hint():
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = not anchors.is_empty()
	mass = maxf(float(baked["mass"]), 0.01)
	var material := _main_material()
	if material != null:
		physics_material_override = material.get_physics_material()
	_body_properties_dirty = false
	baked_parts = baked.get("parts", [])
	_pristine = not Engine.is_editor_hint()
	# Built now even outside the tree: shapes are cheap to add before the body
	# joins the physics world.
	_flush_dirty()


func _set_structure_quietly(definition: VoxelStructureDefinition) -> void:
	_building_quietly = true
	structure = definition
	_building_quietly = false


## Whether any voxel's centre lies inside `region` (this body's local space,
## metres). Used to test what holds a hinge, joint or mounting together.
func has_cells_in(region: AABB) -> bool:
	var low := Vector3i((region.position / voxel_size).floor())
	var high := Vector3i((region.end / voxel_size).ceil())
	for x in range(low.x, high.x):
		for y in range(low.y, high.y):
			for z in range(low.z, high.z):
				var cell := Vector3i(x, y, z)
				if cells.has(cell) and region.has_point((Vector3(cell) + Vector3.ONE * 0.5) * voxel_size):
					return true
	return false


## Exact occupied bounds in cell coordinates, shared by pickup and construction.
## Movement does not invalidate them; removing an outer cell refreshes them lazily.
func get_cell_bounds() -> AABB:
	if cells.is_empty():
		return AABB()
	if _bounds_dirty:
		var first := true
		for cell in cells:
			_bounds_min = cell if first else _bounds_min.min(cell)
			_bounds_max = cell if first else _bounds_max.max(cell)
			first = false
		_bounds_dirty = false
	return AABB(Vector3(_bounds_min), Vector3(_bounds_max - _bounds_min + Vector3i.ONE))


func _main_material() -> VoxelMaterialDefinition:
	if not _main_material_dirty:
		return _cached_main_material
	_main_material_dirty = false
	if palette.is_empty():
		_cached_main_material = null
		return null
	if palette.size() == 1:
		_cached_main_material = palette[0]
		return _cached_main_material
	var counts := {}
	for cell in cells:
		counts[cells[cell]] = counts.get(cells[cell], 0) + 1
	var best := 0
	for index in counts:
		if counts[index] > counts.get(best, 0):
			best = index
	_cached_main_material = palette[best]
	return _cached_main_material


## Nothing left (all knocked out or cemented elsewhere). Runtime pieces go away;
## authored ones stay dormant so reset can rebuild them.
func _on_emptied() -> void:
	if is_held():
		get_tree().call_group(&"object_manipulators", &"release")
	if _spawned:
		queue_free()
	else:
		freeze = true


# --- Structural support

## Breaks off every group of voxels that has lost its support. A fixed structure
## keeps the groups still touching an anchor (and comes loose entirely if none
## are left); a free piece keeps its largest group. Everything else becomes a
## new free piece that falls under physics.
## Where broken-off pieces and rubble go: beside this body, unless it rides on
## something that moves (an NPC limb, a furniture door), then into the scene.
func _debris_parent() -> Node:
	if hold_when_split and is_inside_tree():
		var tree := get_tree()
		return tree.current_scene if tree.current_scene != null else tree.root
	return get_parent()


func _split_disconnected() -> void:
	if cells.is_empty():
		return
	var groups := VoxelConnectivity.components(cells)
	var keep: Array[int] = []
	if freeze:
		for index in groups.size():
			if _touches_anchor(groups[index]):
				keep.append(index)
		# Frozen with nothing holding it to the world: normally it all comes loose,
		# but bodies that ride on something (NPC limbs, furniture doors) keep their
		# biggest piece fixed in place and only shed the bits cut off.
		if keep.is_empty() and not (hold_when_split and anchors.is_empty()):
			freeze = false
	if keep.is_empty():
		var largest := 0
		for index in groups.size():
			if groups[index].size() > groups[largest].size():
				largest = index
		keep.append(largest)
	for index in groups.size():
		if not keep.has(index):
			_detach(groups[index])
	_check_support = false


func _touches_anchor(group: Array) -> bool:
	if anchors.is_empty():
		return false
	for cell in group:
		if anchors.has(cell):
			return true
	return false


## Moves `group` into a new free VoxelBody occupying the same place in the world.
func _detach(group: Array) -> void:
	var parent := _debris_parent()
	if parent == null:
		return
	# Re-centre on a whole-cell offset: the grid stays aligned and the new body's
	# origin sits near its mass, so it is held and thrown sensibly.
	var centre := Vector3.ZERO
	for cell in group:
		centre += Vector3(cell)
	var offset := Vector3i((centre / group.size()).round())
	var piece_cells: Dictionary[Vector3i, int] = {}
	var piece_health: Dictionary[Vector3i, float] = {}
	for cell: Vector3i in group:
		piece_cells[cell - offset] = cells[cell]
		if health.has(cell):
			piece_health[cell - offset] = health[cell]
	var piece := VoxelBody.create_piece(piece_cells, piece_health, palette, voxel_size)
	piece.mass_scale = mass_scale
	var mapping := {}
	for cell: Vector3i in group:
		mapping[cell] = cell - offset
		if surface_state.has(cell): piece.surface_state[cell - offset] = surface_state[cell].duplicate(true)
	piece.mesh_material_override = mesh_material_override
	var piece_transform := global_transform * Transform3D(Basis(), Vector3(offset) * voxel_size)
	var velocity := Vector3.ZERO
	var spin := Vector3.ZERO
	if not freeze:
		velocity = linear_velocity + angular_velocity.cross(piece_transform.origin - global_position)
		spin = angular_velocity
	var kicked := _add_impact_kick(group.size(), piece_transform.origin, velocity, spin)
	velocity = kicked[0]
	spin = kicked[1]
	var material := palette[cells[group[0]]]
	for cell in group:
		_remove_cell(cell)
	parent.add_child(piece)
	piece.global_transform = piece_transform
	piece.linear_velocity = velocity
	piece.angular_velocity = spin
	cells_transferred.emit(piece, mapping)
	if group.size() <= 2:
		piece.is_rubble = true
		_register_rubble(piece)
	elif group.size() >= 8:
		# A real section breaking away: a puff of dust and, if it's big, a thud.
		var piece_mass := group.size() * pow(voxel_size, 3.0) * material.density
		ImpactFeedback.spawn(parent, piece_transform.origin, Vector3.UP, PhysicsToolDefinition.ImpactType.BLUNT,
			clampf(group.size() / 80.0, 0.3, 1.0), material.color, material.impact_sound)
		CameraShake.shake_at(get_tree(), piece_transform.origin, minf(piece_mass * 1.5, 150.0))


## A piece breaking off right after a hit is flung along the hit's direction with
## some outward scatter and spin: strongest near the hit, weaker for big or
## distant pieces, so collapses far from the blow still just fall.
func _add_impact_kick(count: int, centre: Vector3, velocity: Vector3, spin: Vector3) -> Array:
	if _impact_strength <= 0.0 or Time.get_ticks_msec() - _impact_time > IMPACT_MEMORY_MSEC:
		return [velocity, spin]
	var feel := PhysicsFeel.get_active()
	var away := centre - _impact_point
	var distance := away.length()
	var outward := away / distance if distance > 0.01 else Vector3.UP
	var falloff := clampf(1.0 - distance / 2.0, 0.15, 1.0)
	var size_factor := 1.0 / sqrt(maxf(1.0, count / 8.0))
	var kick := minf(_impact_strength * 0.06, 5.0) * feel.debris_launch_multiplier * falloff * size_factor
	velocity += (_impact_direction * 0.7 + outward * 0.3).normalized() * kick
	var axis := _impact_direction.cross(outward)
	if axis.length_squared() > 0.0001:
		spin += axis.normalized() * minf(kick * 1.2, 8.0)
	return [velocity, spin]


# --- Rubble

## `strength` is the hit's damage: harder hits throw rubble further.
func _spawn_rubble(removed: Dictionary[Vector3i, int], direction: Vector3, strength: float) -> void:
	var parent := _debris_parent()
	if parent == null or removed.is_empty():
		return
	var energy := clampf(strength / 30.0, 0.3, 1.5) * PhysicsFeel.get_active().debris_launch_multiplier
	# Fine voxels can lose hundreds of cells to one blow: only a handful become
	# physical rubble (picked at random), the rest are just particles.
	var order := removed.keys()
	order.shuffle()
	var spawned := 0
	for cell: Vector3i in order:
		if spawned >= RUBBLE_PER_EVENT:
			break
		var material := palette[removed[cell]]
		if randf() >= material.rubble_fraction:
			continue
		spawned += 1
		var piece_cells: Dictionary[Vector3i, int] = {Vector3i.ZERO: 0}
		var piece_palette: Array[VoxelMaterialDefinition] = [material]
		var piece := VoxelBody.create_piece(piece_cells, {}, piece_palette, voxel_size)
		piece.mass_scale = mass_scale
		piece.mesh_material_override = mesh_material_override
		piece.is_rubble = true
		piece.name = "Rubble"
		var spot := cell_to_world(cell)
		parent.add_child(piece)
		# The piece's cell spans its origin to +1 voxel, so offset to keep it centred.
		piece.global_transform = Transform3D(global_basis.orthonormalized(), spot - global_basis.orthonormalized() * Vector3.ONE * voxel_size * 0.5)
		var scatter := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)) * 1.2
		piece.linear_velocity = (direction * randf_range(1.2, 3.0) + scatter) * energy
		piece.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * energy
		_register_rubble(piece)


static func _register_rubble(piece: VoxelBody) -> void:
	for index in range(_rubble.size() - 1, -1, -1):
		if not is_instance_valid(_rubble[index]):
			_rubble.remove_at(index)
	_rubble.append(piece)
	while _rubble.size() > RUBBLE_LIMIT:
		var oldest: VoxelBody = null
		for candidate in _rubble:
			if not candidate.is_held() and not candidate.get_meta(&"vacuum_stored", false):
				oldest = candidate
				break
		if oldest == null:
			break
		_rubble.erase(oldest)
		oldest._fade_away()


func _fade_away() -> void:
	set_meta(&"despawning", true)
	collision_layer = 0
	var meshes: Array[Node3D] = []
	for nodes in _chunk_nodes.values():
		for node in nodes:
			if node is MeshInstance3D:
				meshes.append(node)
	if meshes.is_empty():
		queue_free()
		return
	var tween := create_tween()
	for mesh in meshes:
		tween.parallel().tween_property(mesh, "scale", Vector3.ONE * 0.01, 0.4)
	tween.finished.connect(queue_free)


func _physics_process(_delta: float) -> void:
	if not freeze and global_position.y < respawn_below_y:
		queue_free()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if Engine.is_editor_hint():
		return
	ImpactBreaker.process(self, state, _impact_memory, 1.0, not freeze and Engine.get_physics_frames() >= _impacts_from_frame)


func _on_structure_changed() -> void:
	if is_node_ready():
		_build_from_structure()
		_build_parts()


## Small loose things (furniture and its parts, spawned props, rubble, broken
## pieces) are culled with distance; fixed structures are not.
func _is_distance_culled() -> bool:
	return distance_culled or is_rubble or _spawned or (structure != null and not structure.spawn_category.is_empty())


## Furniture doors, drawers and lids (see FurnitureAssembly).
func _build_parts() -> void:
	if not _spawned and structure != null and (not structure.moving_parts.is_empty() or get_node_or_null(^"Assembly") != null):
		FurnitureAssembly.build(self)
