@tool
class_name NPCCharacter
extends CharacterBody3D
## An NPC: a capsule that walks about, carrying a jointed voxel body.
##
## Each body part (NPCPart) is a VoxelBody under a pivot node of a procedural
## rig (NPCRig). While alive the parts are frozen STATIC bodies that just follow
## their pivots, so tools, thrown things and the crosshair hit them and the
## player can't walk through them. Hits, lost voxels and joints decide the rest:
##   a part losing the voxels round a joint drops off (with everything below it)
##   a hard enough hit knocks it over (NPCRagdoll) and it gets back up
##   losing the head or most of the torso kills it (it stays a ragdoll)
## NPCBrain decides where to go; NPCGore does the comedy blood.
##
## Spawn one with NPCCharacter.create(definition), or from the spawn menu.

signal interaction_actions_changed
signal died

const CAPSULE_RADIUS := 0.24
const CAPSULE_HEIGHT := 1.8
## Half-size of the region round a joint that must still have voxels on both sides.
const JOINT_REACH := Vector3(0.09, 0.05, 0.09)
## A part losing this share of its voxels drops off whatever's left of its joint.
const PART_LOSS_LIMIT := 0.7
const BARK_TIME := 1.8
const BARK_COOLDOWN := 2.2
## Lines for occasions a definition doesn't cover (so a hand-tuned definition
## doesn't have to be regenerated to get new ones).
const DEFAULT_BARKS := {
	"door": ["After you!", "Allow me.", "I'll get that.", "Door's open!"],
	"locked": ["Locked. Of course it is.", "Hmm, locked.", "Has anyone got a key?"],
}

enum Life { BUILDING, ALIVE, KNOCKED, GETTING_UP, DEAD, CARRIED }

## Let go at least this fast (m/s), a carried NPC goes flying as a ragdoll;
## slower, he's set down on his feet.
const THROW_SPEED := 2.5

@export var definition: NPCDefinition:
	set(value):
		definition = value
		if Engine.is_editor_hint() and is_inside_tree():
			_editor_preview()

var life := Life.BUILDING
var home := Vector3.ZERO
var rig_root: Node3D
## Where the rig sits relative to its parent before the animation's bob: identity,
## or (while carried) wherever he was grabbed relative to the carry handle.
var rig_base := Transform3D.IDENTITY
var pivots: Array[Node3D] = []
var bodies: Array[VoxelBody] = []
var attached: Array[bool] = []
var rig: NPCRig
var brain: NPCBrain
var ragdoll: NPCRagdoll
var held: VoxelBody
var _start_cells: Array[int] = []
var _bakes: Array = []
var _held_bake := {}
var _capsule: CollisionShape3D
var _check_queued := false
var _bark: Label3D
var _bark_until := 0
var _bark_ready := 0
var _player: Node3D
var _spawned_from_menu := false
## Picking him up holds this (see NPCCarryHandle); what he was before, and
## whether he died while being carried.
var carry_handle: NPCCarryHandle
var _carried_from := Life.ALIVE
var _died_carried := false
var _part_layers: Array[int] = []
## Pushes from tools and sprays (m/s), worn off over a second or so.
var _shove := Vector3.ZERO
## A shove this fast bowls him over.
const SHOVE_KNOCKDOWN := 3.0
## Highest ledge he steps up (doorsteps, kerbs, patio edges).
const MAX_STEP := 0.32


static func create(npc_definition: NPCDefinition, from_menu := true) -> NPCCharacter:
	var npc := NPCCharacter.new()
	npc.definition = npc_definition
	npc.name = npc_definition.display_name.to_pascal_case()
	npc._spawned_from_menu = from_menu
	return npc


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_preview()
		return
	if definition == null or definition.parts.is_empty():
		push_warning("%s: no NPC definition set (assign one, e.g. res://npc/definitions/assistant.tres)" % name)
		set_physics_process(false)
		return
	add_to_group(&"physics_props")
	add_to_group(&"npcs")
	collision_layer = 0
	collision_mask = 1 | 16
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50.0)
	# Same pace up the stairs ramp as on the flat.
	floor_constant_speed = true
	_capsule = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = CAPSULE_RADIUS
	shape.height = CAPSULE_HEIGHT
	_capsule.shape = shape
	_capsule.position.y = CAPSULE_HEIGHT * 0.5
	add_child(_capsule, false, Node.INTERNAL_MODE_BACK)
	rig_root = Node3D.new()
	rig_root.name = "Rig"
	add_child(rig_root, false, Node.INTERNAL_MODE_BACK)
	for i in definition.parts.size():
		var part: NPCPart = definition.parts[i]
		var pivot := Node3D.new()
		pivot.name = part.name
		var parent: Node3D = rig_root if part.parent < 0 else pivots[part.parent]
		parent.add_child(pivot)
		var parent_pivot := Vector3.ZERO if part.parent < 0 else definition.parts[part.parent].pivot
		pivot.position = part.pivot - parent_pivot
		pivots.append(pivot)
		bodies.append(null)
		attached.append(true)
		_start_cells.append(0)
	rig = NPCRig.new(self)
	brain = NPCBrain.new(self)
	ragdoll = NPCRagdoll.new(self)
	home = global_position
	# Build every part's voxels on worker threads, then put them together.
	VoxelBody.prepare_bake()
	for part: NPCPart in definition.parts:
		var result := {}
		var structure := part.structure
		_bakes.append([WorkerThreadPool.add_task(func() -> void: result["baked"] = VoxelBody.bake(structure)), result])
	if definition.held_prop != null:
		var prop := definition.held_prop
		var held_result := _held_bake
		_held_bake["task"] = WorkerThreadPool.add_task(func() -> void: held_result["baked"] = VoxelBody.bake(prop))
	_bark = Label3D.new()
	_bark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bark.font_size = 44
	_bark.pixel_size = 0.004
	_bark.outline_size = 10
	_bark.position = Vector3(0, 2.15, 0)
	_bark.no_depth_test = true
	_bark.hide()
	add_child(_bark, false, Node.INTERNAL_MODE_BACK)


func _exit_tree() -> void:
	for bake in _bakes:
		WorkerThreadPool.wait_for_task_completion(bake[0])
	_bakes.clear()
	if _held_bake.has("task"):
		WorkerThreadPool.wait_for_task_completion(_held_bake["task"])
		_held_bake.erase("task")


func _assemble() -> bool:
	for bake in _bakes:
		if not WorkerThreadPool.is_task_completed(bake[0]):
			return false
	if _held_bake.has("task") and not WorkerThreadPool.is_task_completed(_held_bake["task"]):
		return false
	for i in _bakes.size():
		WorkerThreadPool.wait_for_task_completion(_bakes[i][0])
		var part: NPCPart = definition.parts[i]
		var body := VoxelBody.new()
		body.name = "Part_" + part.name
		body.set(&"_spawned", true)
		body.hold_when_split = true
		body.distance_culled = true
		body.apply_baked(_bakes[i][1]["baked"])
		body.position = -part.pivot
		pivots[i].add_child(body)
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.freeze = true
		add_collision_exception_with(body)
		body.impacted.connect(_on_hit.bind(i))
		body.cells_removed.connect(_on_cells_removed.bind(body))
		body.geometry_changed.connect(_queue_check)
		body.cells_transferred.connect(_on_chunk_lost.bind(i))
		body.tool_worked.connect(_on_tool.bind(i))
		body.pushed.connect(_on_pushed.bind(i))
		bodies[i] = body
		_start_cells[i] = body.cells.size()
	_bakes.clear()
	if _held_bake.has("task"):
		WorkerThreadPool.wait_for_task_completion(_held_bake["task"])
		_held_bake.erase("task")
		var holder := _part(definition.held_by)
		if holder >= 0:
			held = VoxelBody.new()
			held.name = "HeldProp"
			held.set(&"_spawned", true)
			held.distance_culled = true
			held.hold_when_split = true
			held.apply_baked(_held_bake["baked"])
			# In the hand itself (not the rig), so it goes wherever the forearm goes:
			# carried, thrown, knocked flat, or cut off.
			held.transform = definition.held_transform
			bodies[holder].add_child(held)
			for body in bodies:
				if body != null:
					held.add_collision_exception_with(body)
			held.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			held.freeze = true
			add_collision_exception_with(held)
	# Placed by now (the spawn menu positions it after adding it).
	home = global_position
	carry_handle = NPCCarryHandle.new(self)
	add_child(carry_handle, false, Node.INTERNAL_MODE_BACK)
	add_collision_exception_with(carry_handle)
	for body in bodies:
		carry_handle.add_collision_exception_with(body)
	if held != null:
		carry_handle.add_collision_exception_with(held)
	life = Life.ALIVE
	return true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	match life:
		Life.BUILDING:
			_assemble()
		Life.ALIVE:
			var wanted := brain.update(delta) + _shove
			_shove = _shove.move_toward(Vector3.ZERO, delta * 4.0)
			velocity.x = wanted.x
			velocity.z = wanted.z
			if not is_on_floor():
				velocity.y -= 18.0 * delta
			else:
				velocity.y = -0.5
			# Up doorsteps, kerbs and patio edges (the stairs themselves are a ramp).
			if is_on_floor():
				_try_step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
			move_and_slide()
			var flat := Vector2(velocity.x, velocity.z)
			# Walking somewhere: face the way he's going (stepping back, he keeps facing the player).
			if flat.length() > 0.1 and brain.state in [NPCBrain.State.POTTER, NPCBrain.State.FOLLOW]:
				face_towards(global_position + Vector3(velocity.x, 0, velocity.z), delta, 8.0)
			rig.carried = false
			rig.holding = held != null and held.freeze
			rig.update(delta, flat.length())
		Life.KNOCKED:
			if ragdoll.motion() < 0.35:
				ragdoll.still_time += delta
			else:
				ragdoll.still_time = 0.0
			if ragdoll.still_time > definition.get_up_delay and _can_stand():
				ragdoll.stand_up()
				life = Life.GETTING_UP
		Life.GETTING_UP:
			if ragdoll.update_blend(delta):
				life = Life.ALIVE
				brain.set_following(brain.following)
				bark("up")
		Life.CARRIED:
			# Kicking and protesting (only if he was picked up alive and standing).
			if _carried_from == Life.ALIVE and not _died_carried:
				var player := find_player()
				rig.look_at = player.global_position + Vector3.UP * 1.5 if player != null else Vector3.INF
				rig.carried = true
				rig.update(delta, 0.0)
	# The carry handle shadows him while it isn't held.
	if carry_handle != null and life != Life.CARRIED:
		carry_handle.follow(_carry_transform())
	if _bark.visible and Time.get_ticks_msec() > _bark_until:
		_bark.hide()


# --- Damage

func _on_hit(strength: float, point: Vector3, direction: Vector3, index: int) -> void:
	if life == Life.BUILDING or life == Life.DEAD or not attached[index]:
		return
	if life == Life.CARRIED:
		bark("hit")
		return
	if strength >= definition.knockdown_impulse and life == Life.ALIVE:
		knock_over(direction.normalized() * strength * 0.6, point)
		return
	if life == Life.ALIVE:
		rig.flinch = 1.0
		brain.hit(point - direction)
		bark("hit")


## A blowtorch, saw, grinder or drill working on him: wince, back off, complain.
func _on_tool(operation: StringName, point: Vector3, _removed: Dictionary, index: int) -> void:
	if not attached[index]:
		return
	if life == Life.CARRIED:
		bark(_tool_bark(operation))
		return
	if life != Life.ALIVE:
		return
	rig.flinch = 1.0
	var player := find_player()
	brain.hit(player.global_position if player != null else point)
	bark(_tool_bark(operation))


static func _tool_bark(operation: StringName) -> String:
	match String(operation):
		"heat", "weld":
			return "burn"
		"saw", "grind", "dig":
			return "cut"
	return "hit"


## Blown, sprayed or shoved by a tool while standing: he staggers with it, and
## a strong enough push bowls him over.
func _on_pushed(impulse: Vector3, point: Vector3, index: int) -> void:
	if not attached[index] or life != Life.ALIVE:
		return
	var push := Vector3(impulse.x, 0.0, impulse.z) / 60.0
	_shove += push
	if _shove.length() > SHOVE_KNOCKDOWN:
		_shove = Vector3.ZERO
		knock_over(push.normalized() * definition.knockdown_impulse, point)
	elif push.length() > 0.05:
		rig.flinch = maxf(rig.flinch, 0.5)
		bark("pushed")


func _on_cells_removed(removed: Dictionary, direction: Vector3, strength: float, body: VoxelBody) -> void:
	NPCGore.on_cells_removed(body, removed, direction, strength)


## A hit cut a lump off a part (through the middle of a limb, say): it falls
## away as a loose piece already; add the spurts, a pop and a line.
func _on_chunk_lost(piece: VoxelBody, mapping: Dictionary, index: int) -> void:
	if mapping.size() < 8 or life == Life.BUILDING or not is_instance_valid(piece):
		return
	var stump := bodies[index]
	var cut := piece.global_position
	if piece.is_inside_tree():
		var cells := piece.get_cell_bounds()
		cut = piece.global_transform * ((cells.position + cells.size * 0.5) * piece.voxel_size)
		NPCGore.spurt(piece, piece.to_local(cut), Vector3.UP, 1.6)
		NPCGore.play(piece, cut, "pop", 1.0)
	if stump != null and is_instance_valid(stump) and life != Life.DEAD:
		NPCGore.spurt(stump, stump.to_local(cut), Vector3.DOWN, 2.0)
		bark("limb")


func _queue_check() -> void:
	if not _check_queued:
		_check_queued = true
		_check_integrity.call_deferred()


## Joints still holding? Vital parts still intact?
func _check_integrity() -> void:
	_check_queued = false
	if life == Life.BUILDING:
		return
	for i in range(1, definition.parts.size()):
		if not attached[i] or bodies[i] == null:
			continue
		var part: NPCPart = definition.parts[i]
		var body := bodies[i]
		var parent := bodies[part.parent] if part.parent >= 0 else null
		var region := AABB(part.pivot - JOINT_REACH, JOINT_REACH * 2.0)
		var lost := 1.0 - float(body.cells.size()) / maxf(_start_cells[i], 1)
		var severed := body.cells.is_empty() or lost > PART_LOSS_LIMIT or not body.has_cells_in(region)
		if parent != null and attached[part.parent] and not parent.has_cells_in(region):
			severed = true
		if severed:
			sever(i)
	if life == Life.DEAD:
		return
	for i in definition.parts.size():
		var part: NPCPart = definition.parts[i]
		if not part.vital:
			continue
		var body := bodies[i]
		var lost := 1.0 if body == null or not is_instance_valid(body) else 1.0 - float(body.cells.size()) / maxf(_start_cells[i], 1)
		if not attached[i] or lost > definition.vital_loss_limit:
			die()
			return


## A part comes off at its joint, taking everything below it.
func sever(index: int) -> void:
	if not attached[index]:
		return
	var chain := _descendants(index)
	var part: NPCPart = definition.parts[index]
	var stump := bodies[part.parent] if part.parent >= 0 else null
	for i in chain:
		attached[i] = false
		var body := bodies[i]
		if body == null or not is_instance_valid(body):
			continue
		body.top_level = true
		body.freeze = false
		body.linear_velocity = velocity + Vector3(randf_range(-1, 1), 1.5, randf_range(-1, 1))
		body.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
		body.sleeping = false
	ragdoll.unjoin(index)
	# The severed chain stays in one piece (an arm with its hand, a leg with its foot).
	for i in chain:
		var parent: int = definition.parts[i].parent
		if i != index and chain.has(parent):
			ragdoll.join(self, parent, i)
	if held != null and held.freeze and chain.has(_part(definition.held_by)):
		drop_held()
	# Spurts both ends; a pop and a line.
	var limb := bodies[index]
	if limb != null and is_instance_valid(limb):
		# Out of the severed end: up a hanging limb, down a head.
		NPCGore.spurt(limb, part.pivot, Vector3.DOWN if part.name == "head" else Vector3.UP)
		NPCGore.play(limb, limb.global_transform * part.pivot, "pop", 2.0)
	if stump != null and is_instance_valid(stump) and life != Life.DEAD:
		NPCGore.spurt(stump, part.pivot, Vector3.UP if part.name == "head" else Vector3.DOWN)
	if life != Life.DEAD:
		bark("limb")
		if part.vital:
			die()


func knock_over(impulse: Vector3, point: Vector3) -> void:
	if life == Life.DEAD:
		ragdoll.start(impulse, point)
		return
	life = Life.KNOCKED
	ragdoll.start(impulse + Vector3.UP * impulse.length() * 0.2, point)
	bark("knocked")


func die() -> void:
	if life == Life.DEAD:
		return
	if life == Life.CARRIED:
		# Goes limp in your hands; a ragdoll once let go.
		_died_carried = true
		bark("death")
		_x_eyes()
		if held != null and held.freeze:
			drop_held()
		died.emit()
		interaction_actions_changed.emit()
		return
	var was_standing := life == Life.ALIVE or life == Life.GETTING_UP
	life = Life.DEAD
	bark("death")
	_x_eyes()
	if held != null and held.freeze:
		drop_held()
	ragdoll.cancel_blend()
	if was_standing or not ragdoll.active:
		ragdoll.start(-global_basis.z * 20.0, global_position + Vector3.UP * 1.2)
	died.emit()
	interaction_actions_changed.emit()


func drop_held() -> void:
	if held == null:
		return
	# Out of his hand and into the world.
	var tree := get_tree()
	held.reparent(tree.current_scene if tree.current_scene != null else tree.root, true)
	held.freeze = false
	held.linear_velocity = velocity + Vector3(0, 1.0, 0) - global_basis.z * 0.8
	held.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	held.sleeping = false
	remove_collision_exception_with(held)


# --- Picking him up

## ObjectManipulator asks this when a part is aimed at: grab the whole NPC (the
## carry handle) rather than the part. Severed parts are grabbed as themselves.
func get_grab_proxy(collider: Object) -> RigidBody3D:
	var index := bodies.find(collider as VoxelBody)
	if index < 0 or not attached[index] or not can_be_carried():
		return null
	return carry_handle


func can_be_carried() -> bool:
	return carry_handle != null and attached[0] and life in [Life.ALIVE, Life.KNOCKED, Life.DEAD, Life.CARRIED]


## Where the handle waits: at his chest when standing, at his hips when floppy.
func _carry_transform() -> Transform3D:
	if life in [Life.KNOCKED, Life.DEAD] and bodies[0] != null:
		return Transform3D(Basis.IDENTITY, bodies[0].global_transform * definition.parts[0].pivot)
	return global_transform.translated_local(Vector3.UP * 1.1)


## Where the player's crosshair is on him (so he's held by the bit you grabbed).
func _grab_point(fallback: Vector3) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return fallback
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 6.0, 16)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not bodies.has(hit["collider"] as VoxelBody):
		return fallback
	return hit["position"]


func start_carry(handle: NPCCarryHandle) -> void:
	_carried_from = life
	_died_carried = false
	if life == Life.ALIVE:
		# Picked up standing: the whole rig rides on the handle, kicking.
		handle.global_transform = Transform3D(global_basis, _grab_point(_carry_transform().origin))
		handle.shape_for(true, handle.global_transform.affine_inverse() * (global_position + Vector3.UP * 0.9))
		rig_root.reparent(handle, true)
		rig_base = rig_root.transform
		bark("carried")
	else:
		# Picked up floppy: hold the pose he's in, as one piece.
		var hips := _carry_transform().origin
		handle.global_transform = Transform3D(Basis.IDENTITY, _grab_point(hips))
		handle.shape_for(false, handle.global_transform.affine_inverse() * hips)
		ragdoll.clear_joints()
		for i in bodies.size():
			if bodies[i] != null and attached[i]:
				bodies[i].freeze = true
				bodies[i].reparent(handle, true)
				bodies[i].top_level = false
	set_capsule_enabled(false)
	velocity = Vector3.ZERO
	# The handle does the colliding; the parts just ride along.
	_part_layers.clear()
	for i in bodies.size():
		var body := bodies[i]
		_part_layers.append(body.collision_layer if body != null else 16)
		if body != null and attached[i]:
			body.collision_layer = 0
	if held != null and held.freeze:
		held.collision_layer = 0
	handle.set_active(true)
	life = Life.CARRIED


func end_carry(handle: NPCCarryHandle, thrown: bool) -> void:
	if life != Life.CARRIED:
		return
	var speed := handle.linear_velocity
	handle.set_active(false)
	for i in bodies.size():
		if bodies[i] != null and attached[i]:
			bodies[i].collision_layer = _part_layers[i] if i < _part_layers.size() else 16
	if held != null and held.freeze:
		held.collision_layer = 16
	if _carried_from == Life.ALIVE:
		var flung := thrown or speed.length() > THROW_SPEED or _died_carried
		var where := handle.global_transform
		rig_root.reparent(self, true)
		rig_base = Transform3D.IDENTITY
		if not flung:
			# Set down gently: back on his feet where he was put.
			var forward := -where.basis.z
			forward.y = 0.0
			if forward.length() < 0.1:
				forward = -global_basis.z
			var ground := where.origin
			var query := PhysicsRayQueryParameters3D.create(where.origin + Vector3.UP * 0.5, where.origin + Vector3.DOWN * 3.0, 1 | 16)
			query.exclude = own_rids()
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty():
				ground = hit["position"]
			global_transform = Transform3D(Basis(Vector3.UP, atan2(-forward.x, -forward.z)), ground)
			rig_root.transform = Transform3D.IDENTITY
			set_capsule_enabled(true)
			life = Life.ALIVE
			brain.set_following(brain.following)
			bark("up")
			return
		# Thrown: off he goes as a ragdoll, and gets up where he lands.
		global_position = where.origin
		velocity = speed
		life = Life.DEAD if _died_carried else Life.KNOCKED
		ragdoll.active = false
		ragdoll.start(Vector3.ZERO, where.origin)
		ragdoll.still_time = 0.0
		if not _died_carried:
			bark("thrown")
		return
	# Was floppy: back to a ragdoll, carrying the handle's speed.
	for i in bodies.size():
		if bodies[i] != null and attached[i]:
			bodies[i].reparent(pivots[i], true)
			bodies[i].top_level = true
	velocity = speed
	life = Life.DEAD if (_carried_from == Life.DEAD or _died_carried) else Life.KNOCKED
	ragdoll.active = false
	ragdoll.start(Vector3.ZERO, handle.global_position)
	ragdoll.still_time = 0.0


## Repaints each eye's 3x3 front face as an X (dark corners and centre).
func _x_eyes() -> void:
	var head_index := _part("head")
	if head_index < 0 or not attached[head_index]:
		return
	var head := bodies[head_index]
	if head == null:
		return
	var eye := -1
	var pupil := -1
	for p in head.palette.size():
		match head.palette[p].display_name:
			"Eye": eye = p
			"Pupil": pupil = p
	if eye < 0 or pupil < 0:
		return
	var by_eye := {}
	for cell in head.cells:
		var index: int = head.cells[cell]
		if index == eye or index == pupil:
			var side := 1 if (Vector3(cell) * head.voxel_size).x > 0.0 else -1
			if not by_eye.has(side):
				by_eye[side] = []
			by_eye[side].append(cell)
	for side in by_eye:
		var cells: Array = by_eye[side]
		var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
		var hi := -lo
		for c: Vector3i in cells:
			lo = lo.min(c)
			hi = hi.max(c)
		for c: Vector3i in cells:
			var u := c.x - lo.x
			var v := c.y - lo.y
			var w := hi.x - lo.x
			var cross := u == v or u == w - v
			head.call(&"_set_cell", c, pupil if cross else eye)


func _can_stand() -> bool:
	if not attached[0]:
		return false
	return (attached[_part("thigh_r")] and attached[_part("shin_r")]) or (attached[_part("thigh_l")] and attached[_part("shin_l")]) or attached[_part("upper_arm_r")] or attached[_part("upper_arm_l")]


## Steps up a ledge in the way (the same check the player uses): only for
## steep, fixed obstacles no higher than MAX_STEP, landing on walkable ground.
func _try_step_up(motion: Vector3) -> void:
	if motion.is_zero_approx():
		return
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit, safe_margin):
		return
	if hit.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
		return
	var obstacle := hit.get_collider()
	if obstacle is RigidBody3D and not obstacle.freeze:
		return
	var lift := Vector3.UP * (MAX_STEP + safe_margin)
	if test_move(global_transform, lift, hit, safe_margin):
		lift = hit.get_travel()
	if lift.y <= safe_margin:
		return
	var raised := global_transform.translated(lift)
	if test_move(raised, motion, hit, safe_margin):
		return
	if not test_move(raised.translated(motion), -lift, hit, safe_margin):
		return
	var tread_point := hit.get_position() + motion.normalized() * 0.02
	var query := PhysicsRayQueryParameters3D.create(tread_point + Vector3.UP * 0.02, tread_point - Vector3.UP * 0.02, collision_mask)
	query.exclude = own_rids()
	var tread := get_world_3d().direct_space_state.intersect_ray(query)
	if tread.is_empty() or tread["normal"].dot(Vector3.UP) < cos(floor_max_angle):
		return
	var support: Object = tread["collider"]
	if support is RigidBody3D and not support.freeze:
		return
	var height: float = tread["position"].y - global_position.y
	if height <= safe_margin or height > MAX_STEP + safe_margin:
		return
	if test_move(global_transform, Vector3.UP * (height + safe_margin), hit, safe_margin):
		return
	global_position.y += height + safe_margin
	velocity.y = 0.0


# --- Helpers used by the rig and brain

func set_capsule_enabled(enabled: bool) -> void:
	_capsule.disabled = not enabled


func speed_factor() -> float:
	match rig.gait(1.0):
		NPCRig.Gait.HOP: return 0.45
		NPCRig.Gait.CRAWL: return 0.25 if (rig.has("upper_arm_r") or rig.has("upper_arm_l")) else 0.0
	return 1.0


func face_towards(point: Vector3, delta: float, rate: float) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var target := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, target, minf(delta * rate, 1.0))


func find_player() -> Node3D:
	if is_instance_valid(_player):
		return _player
	var camera := get_viewport().get_camera_3d()
	var node: Node = camera
	while node != null and not node is CharacterBody3D:
		node = node.get_parent()
	_player = node as Node3D
	return _player


func own_rids() -> Array[RID]:
	var rids: Array[RID] = [get_rid()]
	for body in bodies:
		if body != null and is_instance_valid(body):
			rids.append(body.get_rid())
	if held != null and is_instance_valid(held):
		rids.append(held.get_rid())
	return rids


func bark(kind: String) -> void:
	var lines: Array = definition.barks.get(kind, DEFAULT_BARKS.get(kind, []))
	var now := Time.get_ticks_msec()
	if lines.is_empty() or (now < _bark_ready and kind != "death"):
		return
	_bark.text = lines[randi() % lines.size()]
	_bark.show()
	_bark_until = now + int(BARK_TIME * 1000.0)
	_bark_ready = now + int(BARK_COOLDOWN * 1000.0)
	# Follow the head (it may be on the floor).
	var head := _part("head")
	if head >= 0 and bodies[head] != null and is_instance_valid(bodies[head]):
		_bark.top_level = true
		_bark.global_position = bodies[head].global_transform * (definition.parts[head].pivot + Vector3.UP * 0.55)


func _part(part_name: String) -> int:
	for i in definition.parts.size():
		if definition.parts[i].name == part_name:
			return i
	return -1


func _descendants(index: int) -> Array[int]:
	var result: Array[int] = [index]
	var grew := true
	while grew:
		grew = false
		for i in definition.parts.size():
			if not result.has(i) and result.has(definition.parts[i].parent):
				result.append(i)
				grew = true
	return result


# --- Interaction (the player's E menu) and resets

func get_interaction_prompt() -> String:
	return definition.display_name + (" (dead)" if life == Life.DEAD else "")


func get_interaction_actions() -> Array[Dictionary]:
	if life != Life.ALIVE:
		return []
	return [{"id": &"talk", "label": "Talk", "enabled": true},
		{"id": &"wait" if brain.following else &"follow", "label": "Wait here" if brain.following else "Follow me", "enabled": true}]


func can_interact() -> bool:
	return life == Life.ALIVE


func perform_interaction_action(action_id: StringName, _actor: Node) -> void:
	if life != Life.ALIVE:
		return
	_bark_ready = 0
	match action_id:
		&"talk":
			bark("talk")
		&"follow":
			brain.set_following(true)
			bark("follow")
		&"wait":
			brain.set_following(false)
			bark("wait")
	interaction_actions_changed.emit()


func interact(actor: Node) -> void:
	actor.call("open_interaction_menu", self)


## R reset: menu-spawned NPCs vanish; placed ones rebuild where they started.
func reset_to_spawn() -> void:
	if _spawned_from_menu:
		queue_free()
		return
	var fresh := NPCCharacter.create(definition, false)
	fresh.transform = Transform3D(global_basis.orthonormalized(), home)
	var parent := get_parent()
	queue_free()
	parent.add_child.call_deferred(fresh)


## In the editor: just the model, standing, so it can be placed (nothing here is
## saved into the scene; the game builds the real thing).
func _editor_preview() -> void:
	var old := get_node_or_null(^"EditorPreview")
	if old != null:
		remove_child(old)
		old.queue_free()
	if definition == null:
		return
	var preview := Node3D.new()
	preview.name = "EditorPreview"
	add_child(preview, false, Node.INTERNAL_MODE_BACK)
	for part: NPCPart in definition.parts:
		if part.structure == null:
			continue
		var body := VoxelBody.new()
		body.structure = part.structure
		preview.add_child(body)
	if definition.held_prop != null:
		var prop := VoxelBody.new()
		prop.structure = definition.held_prop
		# Shown where it hangs at rest (the game raises it to read it).
		prop.transform = definition.held_transform
		preview.add_child(prop)
