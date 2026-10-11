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
const RUBBLE_LIMIT := 60
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
var surface_state: Dictionary = {}
var _body_properties_dirty: bool = true

## Optional appearance for a whole body (e.g. a glass-only window pane).
## Collision and voxel damage still use the normal material palette.
@export var mesh_material_override: Material

## Live rubble pieces, oldest first, so the count can be capped.
static var _rubble: Array[VoxelBody] = []

@export var structure: VoxelStructureDefinition:
	set(value):
		if structure != null and structure.changed.is_connected(_on_structure_changed):
			structure.changed.disconnect(_on_structure_changed)
		structure = value
		if structure != null:
			structure.changed.connect(_on_structure_changed)
		if is_node_ready():
			_build_from_structure()
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
	_update_body()


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
	_dirty[_chunk_of(cell)] = true
	for offset in NEIGHBOURS:
		var neighbour_chunk := _chunk_of(cell + offset)
		if not _dirty.has(neighbour_chunk) and _chunk_cells.has(neighbour_chunk):
			_dirty[neighbour_chunk] = true
	if not _flush_queued and is_inside_tree():
		_flush_queued = true
		_flush_dirty.call_deferred()


func _chunk_of(cell: Vector3i) -> Vector3i:
	return Vector3i(floori(float(cell.x) / CHUNK_SIZE), floori(float(cell.y) / CHUNK_SIZE), floori(float(cell.z) / CHUNK_SIZE))


## Rebuilds the mesh and collision of every changed chunk, once per frame at most.
func _flush_dirty() -> void:
	_flush_queued = false
	if _check_support and not Engine.is_editor_hint():
		_check_support = false
		_split_disconnected()
	if _dirty.is_empty():
		return
	for chunk in _dirty:
		_rebuild_chunk(chunk)
	_dirty.clear()
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
			if node is CollisionShape3D and not rebuild_collision:
				nodes.append(node)
				continue
			remove_child(node)
			node.queue_free()
	_chunk_nodes.erase(chunk)
	var chunk_cells: Dictionary = _chunk_cells.get(chunk, {})
	if chunk_cells.is_empty():
		_chunk_cells.erase(chunk)
		return
	var mesh := VoxelMesher.build(chunk_cells, cells, health, palette, voxel_size, surface_state)
	if mesh != null:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.material_override = mesh_material_override
		add_child(mesh_instance, false, Node.INTERNAL_MODE_BACK)
		nodes.append(mesh_instance)
	if not rebuild_collision:
		_chunk_nodes[chunk] = nodes
		return
	for box in VoxelCollider.merge(chunk_cells):
		var low: Vector3i = box[0]
		var high: Vector3i = box[1]
		var shape := BoxShape3D.new()
		shape.size = Vector3(high - low + Vector3i.ONE) * voxel_size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = (Vector3(low) + Vector3(high - low + Vector3i.ONE) * 0.5) * voxel_size
		add_child(collision, false, Node.INTERNAL_MODE_BACK)
		nodes.append(collision)
	_chunk_nodes[chunk] = nodes


## Mass and surface follow the voxels that remain.
func _update_body() -> void:
	_body_properties_dirty = false
	var total := 0.0
	var volume := pow(voxel_size, 3.0)
	for cell in cells:
		total += palette[cells[cell]].density * volume
	mass = maxf(total, 0.01)
	var material := _main_material()
	if material != null:
		physics_material_override = material.get_physics_material()
	sleeping = false


func _build_from_structure() -> void:
	for chunk in _chunk_nodes:
		for node in _chunk_nodes[chunk]:
			if is_instance_valid(node):
				remove_child(node)
				node.queue_free()
	_chunk_nodes.clear()
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
	var lowest := 1 << 30
	for box in structure.get_boxes():
		if box == null or box.material == null:
			continue
		var material := box.get_effective_material()
		var index := palette.find(material)
		if index < 0:
			palette.append(material)
			index = palette.size() - 1
		for x in range(box.min_cell.x, box.min_cell.x + box.size.x):
			for y in range(box.min_cell.y, box.min_cell.y + box.size.y):
				for z in range(box.min_cell.z, box.min_cell.z + box.size.z):
					_set_cell(Vector3i(x, y, z), index)
					lowest = mini(lowest, y)
	if structure.anchor_mode == VoxelStructureDefinition.AnchorMode.BOTTOM_LAYER:
		for cell in cells:
			if cell.y == lowest:
				anchors[cell] = true
	if not Engine.is_editor_hint():
		freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		freeze = not anchors.is_empty()
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	_flush_dirty()


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
func _split_disconnected() -> void:
	if cells.is_empty():
		return
	var groups := VoxelConnectivity.components(cells)
	var keep: Array[int] = []
	if freeze:
		for index in groups.size():
			if _touches_anchor(groups[index]):
				keep.append(index)
		if keep.is_empty():
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
	var parent := get_parent()
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
	var parent := get_parent()
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
	ImpactBreaker.process(self, state, _impact_memory, 1.0, not freeze)


func _on_structure_changed() -> void:
	if is_node_ready():
		_build_from_structure()
