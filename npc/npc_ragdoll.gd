class_name NPCRagdoll
extends RefCounted
## Knocks an NPC over and stands it back up.
##
## start(): every part still on the NPC goes physical (top-level, unfrozen),
## joined to its parent by a ConeTwistJoint3D at the shared pivot within the
## part's swing / twist limits, and the hit's impulse goes into the part struck.
## The parts can be grabbed and dragged about while it's floppy.
## stand_up(): the NPC moves to where its torso lies, the joints go, and every
## part blends from where it lies back to the standing pose (then re-parents to
## its pivot as a frozen static body again).

const BLEND_TIME := 0.7

var npc: NPCCharacter
var active := false
var still_time := 0.0
var _joints: Array[Joint3D] = []
var _blend := -1.0
var _from: Array[Transform3D] = []


func _init(owner: NPCCharacter) -> void:
	npc = owner


func start(impulse: Vector3, point: Vector3) -> void:
	if active:
		_push(impulse, point)
		return
	active = true
	still_time = 0.0
	_blend = -1.0
	npc.set_capsule_enabled(false)
	var carry := npc.velocity
	for i in npc.bodies.size():
		var body := npc.bodies[i]
		if body == null or not npc.attached[i]:
			continue
		body.top_level = true
		body.freeze = false
		body.linear_velocity = carry
		# Hitting the floor shouldn't break bits off (tools and thrown things still do).
		body.set(&"_impacts_from_frame", Engine.get_physics_frames() + 90)
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false
	for i in npc.bodies.size():
		var part: NPCPart = npc.definition.parts[i]
		if part.parent >= 0 and npc.attached[i] and npc.attached[part.parent]:
			join(npc, part.parent, i)
	_push(impulse, point)


## A cone-twist joint between a part and its parent at the part's pivot, its
## twist axis pointing down the limb.
func join(owner: NPCCharacter, parent: int, child: int) -> void:
	var a := owner.bodies[parent]
	var b := owner.bodies[child]
	if a == null or b == null:
		return
	var part: NPCPart = owner.definition.parts[child]
	var pivot := b.global_transform * part.pivot
	var cells := b.get_cell_bounds()
	var centre := b.global_transform * ((cells.position + cells.size * 0.5) * b.voxel_size)
	var along := (centre - pivot).normalized()
	if along.is_zero_approx():
		along = Vector3.DOWN
	var up := Vector3.FORWARD if absf(along.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var z := along.cross(up).normalized()
	var joint := ConeTwistJoint3D.new()
	joint.name = "Joint_%s" % part.name
	joint.top_level = true
	owner.add_child(joint)
	joint.global_transform = Transform3D(Basis(along, z.cross(along), z), pivot)
	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(part.swing_limit))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(part.twist_limit))
	joint.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.8)
	joint.node_a = joint.get_path_to(a)
	joint.node_b = joint.get_path_to(b)
	joint.set_meta(&"child", child)
	_joints.append(joint)


## Drops every joint (picked up floppy: the parts are held as one piece).
func clear_joints() -> void:
	for joint in _joints:
		if is_instance_valid(joint):
			joint.queue_free()
	_joints.clear()


## Removes the joint holding `child` to its parent (a limb coming off).
func unjoin(child: int) -> void:
	for joint in _joints.duplicate():
		if is_instance_valid(joint) and int(joint.get_meta(&"child", -1)) == child:
			_joints.erase(joint)
			joint.queue_free()


func _push(impulse: Vector3, point: Vector3) -> void:
	if impulse.is_zero_approx():
		return
	var best: VoxelBody = null
	var nearest := INF
	for i in npc.bodies.size():
		var body := npc.bodies[i]
		if body != null and npc.attached[i] and not body.freeze:
			var d := body.global_position.distance_to(point)
			if d < nearest:
				nearest = d
				best = body
	if best != null:
		best.apply_impulse(impulse, point - best.global_position)


## How fast the fastest attached part is moving (to tell when it's lying still).
func motion() -> float:
	var fastest := 0.0
	for i in npc.bodies.size():
		var body := npc.bodies[i]
		if body != null and npc.attached[i] and not body.freeze:
			fastest = maxf(fastest, body.linear_velocity.length() + body.angular_velocity.length() * 0.3)
	return fastest


## Stand back up where the torso lies, then blend the parts into the pose.
func stand_up() -> void:
	var torso := npc.bodies[0]
	if torso == null:
		return
	var hips := torso.global_transform * npc.definition.parts[0].pivot
	# Face the way the head lies from the hips (or the torso's front if upright).
	var spine := torso.global_basis.y
	var facing := Vector3(spine.x, 0, spine.z)
	if facing.length() < 0.3:
		facing = -Vector3(torso.global_basis.z.x, 0, torso.global_basis.z.z)
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var ground := hips
	var query := PhysicsRayQueryParameters3D.create(hips + Vector3.UP * 0.5, hips + Vector3.DOWN * 3.0, 1)
	var hit := npc.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		ground = hit["position"]
	for joint in _joints:
		if is_instance_valid(joint):
			joint.queue_free()
	_joints.clear()
	# Read the pose he's lying in back into the skeleton: every joint's world
	# transform from its body, then each joint's turn relative to its parent.
	var joints: Array[Transform3D] = []
	for i in npc.bodies.size():
		var body := npc.bodies[i]
		joints.append(body.global_transform * Transform3D(Basis.IDENTITY, npc.definition.parts[i].pivot) if body != null else Transform3D())
	npc.global_transform = Transform3D(Basis(Vector3.UP, atan2(-facing.x, -facing.z)), Vector3(hips.x, ground.y, hips.z))
	npc.velocity = Vector3.ZERO
	var turns := {}
	for i in npc.bodies.size():
		var part: NPCPart = npc.definition.parts[i]
		if npc.bodies[i] == null or not npc.attached[i] or part.parent < 0:
			continue
		turns[i] = (joints[part.parent].affine_inverse() * joints[i]).basis.get_rotation_quaternion()
	# The rig's root goes where his hips lie; it rises to standing from there.
	var root := npc.global_transform.affine_inverse() * joints[0] * Transform3D(Basis.IDENTITY, -npc.definition.parts[0].pivot)
	npc.rig.adopt_pose(turns, root)
	# Every part back on its joint, frozen, so the skeleton carries it up.
	for i in npc.bodies.size():
		var body := npc.bodies[i]
		if body != null and npc.attached[i]:
			body.freeze = true
			body.top_level = false
			body.transform = Transform3D(Basis.IDENTITY, -npc.definition.parts[i].pivot)
	_from = [root]
	_blend = 0.0


## Stops a get-up part-way (killed while standing up): back to floppy.
func cancel_blend() -> void:
	if _blend < 0.0:
		return
	_blend = -1.0
	active = false
	npc.rig_base = Transform3D.IDENTITY


## Advances the get-up: the body rises from where it lay while every joint eases
## to standing, all through the skeleton (so limbs stay joined). True once up.
func update_blend(delta: float) -> bool:
	if _blend < 0.0:
		return false
	_blend = minf(_blend + delta / BLEND_TIME, 1.0)
	npc.rig_base = _from[0].interpolate_with(Transform3D.IDENTITY, smoothstep(0.0, 1.0, _blend))
	npc.rig.update(delta, 0.0)
	if _blend < 1.0:
		return false
	npc.rig_base = Transform3D.IDENTITY
	_blend = -1.0
	active = false
	npc.set_capsule_enabled(true)
	return true
