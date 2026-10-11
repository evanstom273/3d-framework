class_name ContraptionWorld
extends Node3D
## Scene-owned record of everything tools have joined together: fasteners, welds,
## hinges, ropes and springs, plus glue patches, markers, projectiles, foam and
## vacuum cargo. One per scene, created on demand. Definitions never hold
## physical state; it all lives here or on the bodies themselves.
##
## Joint strain is an estimate (Godot doesn't report joint forces): how far a
## joint has been forced from where it was made, plus the weight and leverage of
## anything hanging from it alone. Things resting on the ground or on each other
## don't strain their fasteners, so a staple only fails under real load.

## Newtons per metre of joint drift, and newton-metres per radian of twist.
const DRIFT_STIFFNESS := 40000.0
const TWIST_STIFFNESS := 3000.0
const GRAVITY := 9.8

@export var limits: ContraptionLimits = preload("res://contraptions/config/limits.tres")

var connections: Array[ConnectionRecord] = []
var patches: Array[Dictionary] = []
var markers: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var foam: Array[Dictionary] = []
## Vacuum instance id -> Array of stored entries.
var cargo: Dictionary = {}
## Why the last request was refused (shown in tool prompts).
var reason: String = ""

## Pair key -> {joint, records, a, b, existing}.
var _pairs: Dictionary = {}
var _watched: Dictionary = {}
var _membership: Dictionary = {}
var _clock: float = 0.0
var _ray := PhysicsRayQueryParameters3D.new()

static var _worlds: Dictionary = {}


static func find(node: Node, create: bool = false) -> ContraptionWorld:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return null
	var key := node.get_tree().get_instance_id()
	var existing: ContraptionWorld = _worlds[key].get_ref() if _worlds.has(key) else null
	if is_instance_valid(existing) and not existing.is_queued_for_deletion():
		return existing
	if not create:
		return null
	var service := ContraptionWorld.new()
	service.name = "Contraptions"
	var scene := node.get_tree().current_scene
	if scene == null:
		scene = node.get_tree().root
	scene.add_child(service)
	_worlds[key] = weakref(service)
	return service


func _ready() -> void:
	add_to_group(&"contraption_worlds")
	_worlds[get_tree().get_instance_id()] = weakref(self)


## The tool response profile of whatever is at `point` on `body`.
static func profile(body: CollisionObject3D, point: Vector3, normal: Vector3 = Vector3.UP) -> ToolMaterialProfile:
	if body is PhysicsProp:
		var prop := body as PhysicsProp
		return prop.definition.tool_profile if prop.definition != null else null
	if body is VoxelBody:
		var voxel := body as VoxelBody
		var cell := voxel.world_to_cell(point - normal * voxel.voxel_size * 0.25)
		if voxel.cells.has(cell):
			return voxel.palette[voxel.cells[cell]].tool_profile
	return null


# --- Bodies and assemblies

## Tracks a body so connections follow its voxels and clean up when it goes.
func watch(endpoint: AttachmentPoint) -> void:
	var body := endpoint.body()
	if not is_instance_valid(body) or _watched.has(body.get_instance_id()):
		return
	_watched[body.get_instance_id()] = weakref(body)
	if body is VoxelBody:
		var voxel := body as VoxelBody
		voxel.cells_transferred.connect(_transfer.bind(voxel))
		voxel.geometry_changed.connect(_geometry_changed.bind(voxel))
	body.tree_exiting.connect(_body_exiting.bind(body), CONNECT_ONE_SHOT)


func _transfer(target: VoxelBody, mapping: Dictionary, source: VoxelBody) -> void:
	for entry in foam.duplicate():
		if entry["body"] != source:
			continue
		var moved_cells: Array = []
		for cell in entry["owned_cells"].duplicate():
			if mapping.has(cell):
				moved_cells.append(mapping[cell])
				entry["owned_cells"].erase(cell)
		if moved_cells.is_empty():
			continue
		var moved: Dictionary = entry.duplicate()
		moved["body"] = target
		moved["owned_cells"] = moved_cells
		foam.append(moved)
	if not target.surface_state.is_empty():
		ToolMatter.track_heat(self, target)
	var affected: Array[ConnectionRecord] = []
	for record in connections:
		var changed := record.a.migrate(source, target, mapping)
		changed = record.b.migrate(source, target, mapping) or changed
		if record.strand != null:
			for guide in record.strand.guides:
				changed = guide.migrate(source, target, mapping) or changed
		if changed:
			affected.append(record)
	for entry in patches + markers:
		var endpoint: AttachmentPoint = entry["point"]
		endpoint.migrate(source, target, mapping)
	for record in affected:
		_remove_joint(record)
		watch(record.a)
		watch(record.b)
		if record.valid() and record.strand == null:
			_add_joint(record)
	_membership.clear()


func _geometry_changed(_body: VoxelBody) -> void:
	for record in connections.duplicate():
		if not record.valid():
			remove(record)
		elif record.strand != null:
			record.strand.wake()
	_membership.clear()
	for entry in markers.duplicate():
		if not entry["point"].valid():
			erase_marker(entry)
	for entry in patches.duplicate():
		if not entry["point"].valid():
			erase_patch(entry)


func _body_exiting(body: CollisionObject3D) -> void:
	for record in connections.duplicate():
		if record.a.body() == body or record.b.body() == body:
			remove(record)
	if cargo.has(body.get_instance_id()):
		release_cargo(body, true)
	_watched.erase(body.get_instance_id())
	_membership.clear()


## Every body rigidly joined to `body` (ropes and suction don't count), cached.
func members(body: CollisionObject3D) -> Array:
	var id := body.get_instance_id()
	if _membership.has(id):
		return _membership[id]
	var result: Array = [body]
	var index := 0
	while index < result.size() and result.size() <= limits.assembly_bodies:
		var current: CollisionObject3D = result[index]
		for record in connections:
			if record.definition.is_strand() or record.definition.kind == ConnectionDefinition.Kind.SUCTION:
				continue
			var next: CollisionObject3D = null
			if record.a.body() == current:
				next = record.b.body()
			elif record.b.body() == current:
				next = record.a.body()
			if is_instance_valid(next) and not result.has(next):
				result.append(next)
		index += 1
	for item: CollisionObject3D in result:
		_membership[item.get_instance_id()] = result
	return result


## Mass of an assembly, counting each body once, plus container contents and
## anything stored in a vacuum.
func assembly_mass(body: RigidBody3D) -> float:
	var queue := members(body).duplicate()
	var visited := {}
	var total := 0.0
	while not queue.is_empty():
		var item: Node = queue.pop_back()
		if not is_instance_valid(item) or visited.has(item.get_instance_id()):
			continue
		visited[item.get_instance_id()] = true
		if item is RigidBody3D:
			total += (item as RigidBody3D).mass
		if item.has_method("get_contents"):
			queue.append_array(item.call("get_contents"))
		for entry in cargo.get(item.get_instance_id(), []):
			if is_instance_valid(entry["body"]):
				queue.append(entry["body"])
	return total


## True if anything in the assembly is fixed (frozen or static).
func anchored(body: RigidBody3D) -> bool:
	for item: CollisionObject3D in members(body):
		if not item is RigidBody3D or (item as RigidBody3D).freeze:
			return true
	return false


func attached(body: RigidBody3D) -> bool:
	for record in connections:
		if record.a.body() == body or record.b.body() == body:
			return true
	return false


func detach_suction(body: RigidBody3D) -> void:
	for record in connections.duplicate():
		if record.definition.kind == ConnectionDefinition.Kind.SUCTION and (record.a.body() == body or record.b.body() == body):
			remove(record)


# --- Making and breaking connections

func create(a: AttachmentPoint, b: AttachmentPoint, definition: ConnectionDefinition, axis: Vector3 = Vector3.UP,
		length: float = 2.0, guides: Array[AttachmentPoint] = []) -> ConnectionRecord:
	reason = ""
	if not a.valid() or not b.valid() or a.body() == b.body():
		reason = "Choose two different objects"
		return null
	if connections.size() >= limits.connections:
		reason = "Connection limit reached"
		return null
	if not definition.is_strand() and not _rigid_allowed(a, b, definition):
		return null
	var record := ConnectionRecord.new()
	record.a = a
	record.b = b
	record.definition = definition
	record.axis = axis
	record.rest_separation = a.body().global_basis.inverse() * (b.position() - a.position())
	record.rest_rotation = (a.body().global_basis.inverse() * b.body().global_basis).get_rotation_quaternion()
	if definition.is_strand():
		var strand := _make_strand(record, guides, length)
		if strand == null:
			return null
		record.strand = strand
		add_child(strand)
	else:
		_add_joint(record)
	connections.append(record)
	watch(a)
	watch(b)
	for guide in guides:
		watch(guide)
	_membership.clear()
	return record


func _rigid_allowed(a: AttachmentPoint, b: AttachmentPoint, definition: ConnectionDefinition) -> bool:
	if a.position().distance_to(b.position()) > definition.maximum_gap:
		reason = "The surfaces must be touching"
		return false
	var bodies := members(a.body()).duplicate()
	for item in members(b.body()):
		if not bodies.has(item):
			bodies.append(item)
	if bodies.size() > limits.assembly_bodies:
		reason = "Too many objects joined together"
		return false
	var count := 0
	var key := _key(a, b)
	for other in connections:
		if _key(other.a, other.b) != key:
			continue
		if other.definition.kind != definition.kind:
			reason = "Remove the existing join first"
			return false
		count += 1
	if count >= limits.fasteners_per_pair:
		reason = "These two are already fastened %d times" % count
		return false
	if definition.kind == ConnectionDefinition.Kind.SUCTION:
		return true
	for endpoint in [a, b]:
		var material := profile(endpoint.body(), endpoint.position(), endpoint.normal())
		if material == null or not material.fastening:
			reason = "That material can't be fastened"
			return false
		if definition.metal_only and not material.weldable:
			reason = "Welding needs metal on both sides"
			return false
		if definition.soft_only and not material.stapleable:
			reason = "Staples only go into wood and soft materials"
			return false
	return true


func _make_strand(record: ConnectionRecord, guides: Array[AttachmentPoint], length: float) -> ToolStrand:
	var active := 0
	var particles := 0
	for other in connections:
		if other.strand != null:
			active += 1
			particles += other.strand.points.size()
	if active >= limits.strands:
		reason = "Strand limit reached"
		return null
	if guides.size() > 4:
		reason = "At most four pulleys"
		return null
	var route: Array[Vector3] = [record.a.position()]
	for guide in guides:
		route.append(guide.position())
	route.append(record.b.position())
	var exclude: Array[RID] = [record.a.body().get_rid(), record.b.body().get_rid()]
	for guide in guides:
		exclude.append(guide.body().get_rid())
	var route_length := 0.0
	var space := get_world_3d().direct_space_state
	for index in range(1, route.size()):
		route_length += route[index - 1].distance_to(route[index])
		_ray.from = route[index - 1]
		_ray.to = route[index]
		_ray.collision_mask = 1 | 2 | 16
		_ray.exclude = exclude
		if not space.intersect_ray(_ray).is_empty():
			reason = "Something is in the way"
			return null
	var total := maxf(length, route_length)
	if total > record.definition.maximum_length:
		reason = "Too long (%.0f m maximum)" % record.definition.maximum_length
		return null
	var count := clampi(ceili(total / limits.spacing) + 1, 4, limits.particles_per_strand)
	if particles + count > limits.particles:
		reason = "Too much rope in the scene"
		return null
	var strand := ToolStrand.new()
	strand.setup(record, guides, total, count, limits)
	return strand


func _key(a: AttachmentPoint, b: AttachmentPoint) -> String:
	var x := a.body().get_instance_id()
	var y := b.body().get_instance_id()
	return "%d:%d" % [mini(x, y), maxi(x, y)]


## One joint per pair of bodies; extra fasteners reinforce it instead of stacking joints.
func _add_joint(record: ConnectionRecord) -> void:
	var key := _key(record.a, record.b)
	record.joint_key = key
	if _pairs.has(key):
		_pairs[key]["records"].append(record)
		return
	var a := record.a.body()
	var b := record.b.body()
	var joint: Joint3D
	if record.definition.kind == ConnectionDefinition.Kind.HINGE:
		var hinge := HingeJoint3D.new()
		hinge.set_flag(HingeJoint3D.FLAG_USE_LIMIT, true)
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_LOWER, -deg_to_rad(record.definition.hinge_limit_degrees))
		hinge.set_param(HingeJoint3D.PARAM_LIMIT_UPPER, deg_to_rad(record.definition.hinge_limit_degrees))
		joint = hinge
	else:
		joint = _rigid_joint(record.definition)
	add_child(joint)
	joint.global_position = (record.a.position() + record.b.position()) * 0.5
	var axis := record.axis.normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	joint.global_basis = Basis(side, axis.cross(side).normalized(), axis)
	joint.exclude_nodes_from_collision = false
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)
	var existing := a is PhysicsBody3D and (a as PhysicsBody3D).get_collision_exceptions().has(b)
	if a is PhysicsBody3D and b is PhysicsBody3D:
		(a as PhysicsBody3D).add_collision_exception_with(b)
		(b as PhysicsBody3D).add_collision_exception_with(a)
	_pairs[key] = {"joint": joint, "records": [record], "a": weakref(a), "b": weakref(b), "existing": existing}


## Locked on all axes; sealant gets a little springy give instead.
static func _rigid_joint(definition: ConnectionDefinition) -> Generic6DOFJoint3D:
	var joint := Generic6DOFJoint3D.new()
	var springy := definition.kind == ConnectionDefinition.Kind.SEALANT
	for axis in 3:
		var flag_method: StringName = [&"set_flag_x", &"set_flag_y", &"set_flag_z"][axis]
		var param_method: StringName = [&"set_param_x", &"set_param_y", &"set_param_z"][axis]
		joint.call(flag_method, Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_LIMIT, true)
		joint.call(flag_method, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_LIMIT, true)
		if not springy:
			continue
		joint.call(param_method, Generic6DOFJoint3D.PARAM_LINEAR_LOWER_LIMIT, -0.025)
		joint.call(param_method, Generic6DOFJoint3D.PARAM_LINEAR_UPPER_LIMIT, 0.025)
		joint.call(param_method, Generic6DOFJoint3D.PARAM_ANGULAR_LOWER_LIMIT, -0.12)
		joint.call(param_method, Generic6DOFJoint3D.PARAM_ANGULAR_UPPER_LIMIT, 0.12)
		joint.call(flag_method, Generic6DOFJoint3D.FLAG_ENABLE_LINEAR_SPRING, true)
		joint.call(flag_method, Generic6DOFJoint3D.FLAG_ENABLE_ANGULAR_SPRING, true)
		joint.call(param_method, Generic6DOFJoint3D.PARAM_LINEAR_SPRING_STIFFNESS, 1.0 / maxf(definition.compliance, 0.0001))
		joint.call(param_method, Generic6DOFJoint3D.PARAM_LINEAR_SPRING_DAMPING, definition.damping)
		joint.call(param_method, Generic6DOFJoint3D.PARAM_ANGULAR_SPRING_STIFFNESS, definition.torque_resistance)
	return joint


func _remove_joint(record: ConnectionRecord) -> void:
	if not _pairs.has(record.joint_key):
		return
	var entry: Dictionary = _pairs[record.joint_key]
	entry["records"].erase(record)
	if not entry["records"].is_empty():
		return
	var a := entry["a"].get_ref() as PhysicsBody3D
	var b := entry["b"].get_ref() as PhysicsBody3D
	# Only restore collision if this joint added the exception in the first place.
	if not entry["existing"] and is_instance_valid(a) and is_instance_valid(b):
		a.remove_collision_exception_with(b)
		b.remove_collision_exception_with(a)
	entry["joint"].queue_free()
	_pairs.erase(record.joint_key)


func remove(record: ConnectionRecord) -> void:
	if record == null:
		return
	_remove_joint(record)
	if is_instance_valid(record.strand):
		record.strand.queue_free()
	connections.erase(record)
	_membership.clear()


## Damages the connection nearest `point` (within 35 cm); breaks it when used up.
## `only` limits it to one kind of connection (e.g. screws for the drill).
func weaken(point: Vector3, amount: float, only: ConnectionDefinition = null) -> bool:
	var best: ConnectionRecord = null
	var distance := 0.35
	for record in connections:
		if only != null and record.definition != only:
			continue
		var d := minf(record.a.position().distance_to(point), record.b.position().distance_to(point))
		if record.strand != null:
			for particle in record.strand.points:
				d = minf(d, particle.distance_to(point))
		if d < distance:
			distance = d
			best = record
	if best == null:
		return false
	best.damage += amount
	if best.remaining_strength() <= 0.0:
		remove(best)
	return true


func remove_aimed_strand(origin: Vector3, direction: Vector3, reach: float) -> bool:
	var nearest: ConnectionRecord = null
	var depth := reach
	var space := get_world_3d().direct_space_state
	for record in connections:
		if record.strand == null:
			continue
		for particle in record.strand.points:
			var along := (particle - origin).dot(direction)
			if along < 0.0 or along > depth:
				continue
			if particle.distance_to(origin + direction * along) > 0.12:
				continue
			_ray.from = origin
			_ray.to = particle
			_ray.collision_mask = 1 | 2 | 16
			_ray.exclude = []
			var blocked := space.intersect_ray(_ray)
			if not blocked.is_empty() and blocked["position"].distance_to(particle) > 0.15:
				continue
			nearest = record
			depth = along
	if nearest == null:
		return false
	remove(nearest)
	return true


## Hard knocks to a fastened body wear its connections (called from ImpactBreaker).
func impact(body: RigidBody3D, impulse: float) -> void:
	for record in connections:
		if record.a.body() != body and record.b.body() != body:
			continue
		if impulse > record.remaining_strength() * 0.12:
			record.damage += impulse / maxf(record.definition.strength, 1.0) * record.definition.removal_resistance


# --- Each tick

func _physics_process(delta: float) -> void:
	_clock += delta
	for record in connections.duplicate():
		if not record.valid():
			remove(record)
			continue
		record.age += delta
		if record.definition.lifetime > 0.0 and record.age > record.definition.lifetime:
			remove(record)
			continue
		if record.strand != null:
			if record.strand.broken or maxf(record.strand.tension, record.strand.rider_tension) > record.definition.strength:
				record.overload += delta if not record.strand.broken else 1000.0
			else:
				record.overload = maxf(0.0, record.overload - delta * 2.0)
		else:
			_check_joint(record, delta)
		if record.overload > record.definition.overload_duration:
			remove(record)
	if _clock >= 0.05:
		ToolMatter.update(self, _clock)
		_clock = 0.0


func _check_joint(record: ConnectionRecord, delta: float) -> void:
	var load := _joint_load(record)
	# Fasteners joining the same pair share the load (up to eight times one's strength).
	var strength := record.remaining_strength()
	if _pairs.has(record.joint_key):
		strength = 0.0
		for fastener: ConnectionRecord in _pairs[record.joint_key]["records"]:
			strength += fastener.remaining_strength()
		strength = minf(strength, record.definition.strength * limits.fasteners_per_pair)
	if strength <= 0.0:
		record.overload = 1000.0
		return
	var reinforcement := maxf(1.0, strength / maxf(record.definition.strength, 1.0))
	var overloaded := load.x > strength
	if record.definition.kind != ConnectionDefinition.Kind.HINGE:
		overloaded = overloaded or load.y > record.definition.torque_resistance * reinforcement
	if overloaded:
		record.overload += delta
	else:
		record.overload = maxf(0.0, record.overload - delta * 2.0)


## Estimated (force, torque) on a joint.
func _joint_load(record: ConnectionRecord) -> Vector2:
	var a := record.a.body()
	var b := record.b.body()
	var joint_point := (record.a.position() + record.b.position()) * 0.5
	# How far the joint has been forced from where it was made.
	var drift := (record.b.position() - record.a.position() - a.global_basis * record.rest_separation).length()
	var force := drift * DRIFT_STIFFNESS
	var torque := 0.0
	if record.definition.kind != ConnectionDefinition.Kind.HINGE:
		var relative := (a.global_basis.inverse() * b.global_basis).get_rotation_quaternion()
		torque = relative.angle_to(record.rest_rotation) * TWIST_STIFFNESS
	# Anything hanging from this joint alone pulls with its weight, levered out from it.
	for pair in [[a, b], [b, a]]:
		var hanging := pair[0] as RigidBody3D
		if hanging == null or hanging.freeze or not _hangs_from(hanging, pair[1]):
			continue
		var weight := hanging.mass * GRAVITY
		force += weight
		torque += weight * (hanging.global_position - joint_point).slide(Vector3.UP).length()
	return Vector2(force, torque)


## True when `body` touches nothing but its partner, so the joint carries it.
static func _hangs_from(body: RigidBody3D, partner: Object) -> bool:
	if not body.contact_monitor:
		return false
	for other in body.get_colliding_bodies():
		if other != partner:
			return false
	return not (body.has_method("is_held") and bool(body.call("is_held")))


# --- Patches, markers, cargo, reset

func prepare_patch(point: AttachmentPoint, definition: ConnectionDefinition) -> bool:
	if patches.size() >= limits.patches:
		reason = "Too many glue patches"
		return false
	var visual := ToolMatter.patch_mesh(definition.color, 0.075)
	add_child(visual)
	ToolMatter.orient(visual, point)
	patches.append({"point": point, "definition": definition, "visual": visual})
	watch(point)
	return true


func erase_patch(entry: Dictionary) -> void:
	if is_instance_valid(entry["visual"]):
		entry["visual"].queue_free()
	patches.erase(entry)


func erase_marker(entry: Dictionary) -> void:
	if is_instance_valid(entry["visual"]):
		entry["visual"].queue_free()
	markers.erase(entry)


func forget_projectile(body: RigidBody3D) -> void:
	for entry in projectiles.duplicate():
		if entry["body"] == body:
			projectiles.erase(entry)


func release_cargo(vacuum: CollisionObject3D, deleting: bool = false) -> void:
	ToolMatter.release_cargo(self, vacuum, deleting)


func reset() -> void:
	for record in connections.duplicate():
		remove(record)
	for entry in patches.duplicate():
		erase_patch(entry)
	for entry in markers.duplicate():
		erase_marker(entry)
	for id in cargo.keys():
		var holder := instance_from_id(id) as CollisionObject3D
		if is_instance_valid(holder):
			release_cargo(holder, true)
	for entry in projectiles:
		if is_instance_valid(entry["body"]):
			entry["body"].queue_free()
	projectiles.clear()
	for entry in foam:
		if is_instance_valid(entry["body"]):
			for cell in entry["owned_cells"]:
				entry["body"]._remove_cell(cell)
	foam.clear()
	ToolMatter.clear_surfaces(self)


func _exit_tree() -> void:
	reset()
