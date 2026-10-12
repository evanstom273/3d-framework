class_name NPCRig
extends RefCounted
## Procedural animation for an NPC's joints (no animation files): each frame it
## works out a pose for every pivot from the NPC's state, speed and missing
## limbs, and blends toward it. Part names decide what each pivot does:
## head, torso, upper_arm_r/l, forearm_r/l, thigh_r/l, shin_r/l.
##
## Axes: the NPC faces -Z. Turning a hanging limb by +angle about X swings it
## forward; turning the torso by -angle about X leans it forward.

enum Gait { STAND, WALK, RUN, HOP, CRAWL }

var npc: NPCCharacter
var phase := 0.0
var time := 0.0
## Where to look (world space), or INF for straight ahead.
var look_at := Vector3.INF
var flinch := 0.0
var panic := false
## Wary: clipboard raised like a shield, other hand up (a tool waved about nearby).
var guard := false
## Picked up and carried: legs kicking, arms flapping.
var carried := false
var holding := true
var _index := {}
var _rest: Array[Transform3D] = []
var _current: Array[Quaternion] = []
var _root_offset := Vector3.ZERO


func _init(owner: NPCCharacter) -> void:
	npc = owner
	for i in npc.definition.parts.size():
		var part: NPCPart = npc.definition.parts[i]
		_index[part.name] = i
		var parent_pivot := Vector3.ZERO if part.parent < 0 else npc.definition.parts[part.parent].pivot
		_rest.append(Transform3D(Basis.IDENTITY, part.pivot - parent_pivot))
		_current.append(Quaternion.IDENTITY)


func rest_transform(i: int) -> Transform3D:
	return _rest[i]


## Starts from a given pose: joint turns (part index -> Quaternion) and where
## the rig's root sits (getting up from wherever he lay).
func adopt_pose(turns: Dictionary, root: Transform3D) -> void:
	for i in _current.size():
		_current[i] = turns.get(i, Quaternion.IDENTITY)
		npc.pivots[i].transform = Transform3D(Basis(_current[i]), _rest[i].origin)
	_root_offset = Vector3.ZERO
	npc.rig_base = root
	npc.rig_root.transform = root


## Snaps every joint to standing (after getting up).
func reset() -> void:
	for i in _current.size():
		_current[i] = Quaternion.IDENTITY
		npc.pivots[i].transform = _rest[i]
	_root_offset = Vector3.ZERO
	npc.rig_base = Transform3D.IDENTITY
	npc.rig_root.transform = Transform3D.IDENTITY


func has(part: String) -> bool:
	return _index.has(part) and npc.attached[_index[part]]


func gait(speed: float) -> Gait:
	var legs := int(has("thigh_r") and has("shin_r")) + int(has("thigh_l") and has("shin_l"))
	if legs == 0:
		return Gait.CRAWL
	if legs == 1:
		return Gait.HOP if speed > 0.05 else Gait.STAND
	if speed < 0.05:
		return Gait.STAND
	return Gait.RUN if speed > npc.definition.walk_speed * 1.4 else Gait.WALK


func update(delta: float, speed: float) -> void:
	time += delta
	flinch = maxf(flinch - delta * 2.2, 0.0)
	var mode := gait(speed)
	match mode:
		Gait.WALK: phase += delta * speed * 4.2
		Gait.RUN: phase += delta * speed * 3.0
		Gait.HOP: phase += delta * 7.0
		Gait.CRAWL: phase += delta * 4.0
		_: phase = lerpf(phase, roundf(phase / PI) * PI, minf(delta * 4.0, 1.0))
	var pose := {}
	var root := Vector3.ZERO
	var s := sin(phase)
	var stride := 0.5 if mode == Gait.WALK else 0.85
	match mode:
		Gait.STAND:
			pose["torso"] = Vector3(sin(time * 1.6) * 0.015, 0.0, 0.0)
			pose["upper_arm_r"] = Vector3(0.05, 0.0, 0.06)
			pose["upper_arm_l"] = Vector3(0.05, 0.0, -0.06)
		Gait.WALK, Gait.RUN:
			pose["thigh_r"] = Vector3(s * stride, 0, 0)
			pose["thigh_l"] = Vector3(-s * stride, 0, 0)
			pose["shin_r"] = Vector3(-maxf(0.0, -sin(phase - 0.9)) * stride * 1.6, 0, 0)
			pose["shin_l"] = Vector3(-maxf(0.0, sin(phase - 0.9)) * stride * 1.6, 0, 0)
			pose["upper_arm_r"] = Vector3(-s * stride * 0.8, 0, 0.08)
			pose["upper_arm_l"] = Vector3(s * stride * 0.8, 0, -0.08)
			pose["forearm_r"] = Vector3(0.35, 0, 0)
			pose["forearm_l"] = Vector3(0.35, 0, 0)
			pose["torso"] = Vector3(-0.05 if mode == Gait.WALK else -0.22, s * 0.06, 0)
			root.y = -absf(cos(phase)) * (0.025 if mode == Gait.WALK else 0.05)
		Gait.HOP:
			# One leg left: hop on it, the stump side waving about.
			var hop := absf(sin(phase))
			root.y = hop * 0.13 - 0.02
			for side in ["r", "l"]:
				if has("thigh_" + side):
					pose["thigh_" + side] = Vector3(0.15 - hop * 0.3, 0, 0)
					pose["shin_" + side] = Vector3(-0.4 + hop * 0.35, 0, 0)
			pose["torso"] = Vector3(-0.1, 0, (0.12 if has("thigh_r") else -0.12))
			pose["upper_arm_r"] = Vector3(-0.4 + sin(phase * 2.0) * 0.5, 0, 0.6)
			pose["upper_arm_l"] = Vector3(-0.4 - sin(phase * 2.0) * 0.5, 0, -0.6)
		Gait.CRAWL:
			# No legs: flat on the front, dragging along by the arms.
			root.y = -0.78
			pose["torso"] = Vector3(-1.35, 0, 0)
			pose["head"] = Vector3(1.0, 0, 0)
			pose["upper_arm_r"] = Vector3(2.4 + s * 0.5, 0, 0.3)
			pose["upper_arm_l"] = Vector3(2.4 - s * 0.5, 0, -0.3)
			pose["forearm_r"] = Vector3(-0.4 - maxf(s, 0.0) * 0.6, 0, 0)
			pose["forearm_l"] = Vector3(-0.4 - maxf(-s, 0.0) * 0.6, 0, 0)
	# Holding the clipboard up to read it (calm walking or standing).
	if holding and not panic and mode != Gait.CRAWL:
		pose["upper_arm_r"] = Vector3(0.25, 0, 0.12)
		pose["forearm_r"] = Vector3(1.35, 0, 0)
	# Fleeing: arms flung up and flailing.
	if panic and mode != Gait.CRAWL:
		pose["upper_arm_r"] = Vector3(-2.7 + sin(time * 17.0) * 0.45, 0, 0.35)
		pose["upper_arm_l"] = Vector3(-2.7 + sin(time * 17.0 + 1.7) * 0.45, 0, -0.35)
		pose["forearm_r"] = Vector3(sin(time * 13.0) * 0.6, 0, 0)
		pose["forearm_l"] = Vector3(sin(time * 13.0 + 2.0) * 0.6, 0, 0)
		pose["head"] = Vector3(0.0, sin(time * 9.0) * 0.5, 0)
	# Carried: legs bicycling, arms flapping, a bit of a wriggle.
	if carried:
		var k := time * 11.0
		pose["thigh_r"] = Vector3(0.6 + sin(k) * 0.7, 0, 0.1)
		pose["thigh_l"] = Vector3(0.6 - sin(k) * 0.7, 0, -0.1)
		pose["shin_r"] = Vector3(-0.9 - cos(k) * 0.5, 0, 0)
		pose["shin_l"] = Vector3(-0.9 + cos(k) * 0.5, 0, 0)
		pose["upper_arm_r"] = Vector3(-1.2 + sin(k * 1.3) * 0.8, 0, 0.7)
		pose["upper_arm_l"] = Vector3(-1.2 - sin(k * 1.3) * 0.8, 0, -0.7)
		pose["forearm_r"] = Vector3(0.6 + sin(k * 1.7) * 0.5, 0, 0)
		pose["forearm_l"] = Vector3(0.6 + cos(k * 1.7) * 0.5, 0, 0)
		pose["torso"] = Vector3(0.1, sin(time * 5.0) * 0.15, sin(time * 4.0) * 0.1)
	# Guarded: clipboard up in front, the other palm out, leaning away a touch.
	if guard and mode != Gait.CRAWL:
		pose["torso"] = Vector3(0.08, 0, 0)
		pose["upper_arm_r"] = Vector3(1.1, 0, 0.2)
		pose["forearm_r"] = Vector3(1.2, 0, 0)
		pose["upper_arm_l"] = Vector3(1.0, 0, -0.35)
		pose["forearm_l"] = Vector3(1.5, 0, 0)
	# Flinch: lean back, arms up to the face, head ducked.
	if flinch > 0.0:
		var f := flinch
		pose["torso"] = Vector3(0.3 * f, 0, 0)
		pose["upper_arm_r"] = Vector3(lerpf(0.0, 2.2, f), 0, 0.5 * f)
		pose["upper_arm_l"] = Vector3(lerpf(0.0, 2.2, f), 0, -0.5 * f)
		pose["forearm_r"] = Vector3(1.9 * f, 0, 0)
		pose["forearm_l"] = Vector3(1.9 * f, 0, 0)
		pose["head"] = Vector3(0.4 * f, 0, 0)
	# Look at something (head turns, within a comfortable range).
	if look_at.is_finite() and not panic and mode != Gait.CRAWL and has("head"):
		var head: Node3D = npc.pivots[_index["head"]]
		var local := npc.global_transform.affine_inverse() * look_at
		var from := head.global_transform.origin
		var to := npc.global_transform.affine_inverse() * from
		var d := local - to
		var yaw := clampf(atan2(-d.x, -d.z), -1.1, 1.1)
		var pitch := clampf(atan2(d.y, Vector2(d.x, d.z).length()), -0.5, 0.4)
		var base: Vector3 = pose.get("head", Vector3.ZERO)
		pose["head"] = base + Vector3(pitch, yaw, 0)
	# Blend toward the pose.
	var blend := minf(delta * (16.0 if panic or flinch > 0.0 else 9.0), 1.0)
	for name in _index:
		var i: int = _index[name]
		if not npc.attached[i]:
			continue
		var euler: Vector3 = pose.get(name, Vector3.ZERO)
		var target := Quaternion.from_euler(euler)
		_current[i] = _current[i].slerp(target, blend)
		npc.pivots[i].transform = Transform3D(Basis(_current[i]), _rest[i].origin)
	_root_offset = _root_offset.lerp(root, minf(delta * 10.0, 1.0))
	# Offsets the rig from its base (identity, or where it was grabbed while carried).
	npc.rig_root.transform = npc.rig_base * Transform3D(Basis.IDENTITY, _root_offset)
