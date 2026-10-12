extends SceneTree
## The real player grabs the Assistant by the arm (ObjectManipulator), carries,
## throws; checks grab point, clipboard and pose after he gets up.
var _f := 0
var npc: NPCCharacter
var player: CharacterBody3D
var man: Node
var _phase := 0
var _t0 := 0
var _grab_local := Vector3.ZERO
var _clip_local := Transform3D()
func _pose_error() -> float:
	var worst := 0.0
	for k in npc.bodies.size():
		if npc.bodies[k] != null and npc.attached[k]:
			var want: Transform3D = npc.global_transform * Transform3D(Basis.IDENTITY, Vector3.ZERO)
			var rel := npc.global_transform.affine_inverse() * npc.bodies[k].global_transform
			worst = maxf(worst, rel.origin.length())
	return worst
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(40, 1, 40)
		body.add_child(shape)
		body.position.y = -0.5
		root.add_child(body)
		player = (load("res://player.tscn") as PackedScene).instantiate()
		root.add_child(player)
		player.global_position = Vector3(0, 0.05, 2.0)
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		root.add_child(npc)
		return false
	if npc.life == NPCCharacter.Life.BUILDING or _f < 30:
		return false
	man = player.get("manipulator")
	match _phase:
		0:
			# Aim the camera at his left upper arm.
			var cam := root.get_viewport().get_camera_3d()
			var arm := npc.bodies[npc._part("upper_arm_l")]
			var aim: Vector3 = arm.global_transform * (npc.definition.parts[npc._part("upper_arm_l")].pivot + Vector3(0, -0.12, 0))
			cam.look_at(aim)
			var proxy: RigidBody3D = man.resolve_grabbable(npc.bodies[npc._part("upper_arm_l")])
			var ok: bool = man.grab(proxy)
			_grab_local = npc.carry_handle.global_position
			_clip_local = npc.bodies[npc._part("forearm_r")].global_transform.affine_inverse() * npc.held.global_transform
			print("grab ok %s; handle placed %.2f m from the aimed point (arm), %.2f m above his feet" % [ok, npc.carry_handle.global_position.distance_to(aim), npc.carry_handle.global_position.y - npc.global_position.y])
			_phase = 1
			_t0 = _f
		1:
			if _f - _t0 == 60:
				var cam := root.get_viewport().get_camera_3d()
				var held_pt: Vector3 = npc.carry_handle.global_position
				var clip_now: Transform3D = npc.bodies[npc._part("forearm_r")].global_transform.affine_inverse() * npc.held.global_transform
				print("held 1 s: handle %.2f m in front of the eye; arm voxel still at the handle: %.2f m; clipboard drift in hand %.3f m; torso-to-handle %s" % [cam.global_position.distance_to(held_pt), held_pt.distance_to(npc.bodies[npc._part("upper_arm_l")].global_transform * (npc.definition.parts[npc._part("upper_arm_l")].pivot + Vector3(0, -0.12, 0))), clip_now.origin.distance_to(_clip_local.origin), npc.bodies[0].global_position - held_pt])
				man.release(true, 1.0)
				print("thrown: life %s, handle speed %.1f" % [NPCCharacter.Life.keys()[npc.life], npc.carry_handle.linear_velocity.length()])
				_phase = 2
				_t0 = _f
		2:
			if _f - _t0 == 30:
				var clip_now: Transform3D = npc.bodies[npc._part("forearm_r")].global_transform.affine_inverse() * npc.held.global_transform
				print("in flight: clipboard drift in hand %.3f m (held frozen %s)" % [clip_now.origin.distance_to(_clip_local.origin), npc.held.freeze])
			if npc.life == NPCCharacter.Life.ALIVE:
				var worst := 0.0
				for k in npc.bodies.size():
					if npc.bodies[k] != null and npc.attached[k]:
						var want: Transform3D = npc.pivots[k].global_transform * Transform3D(Basis.IDENTITY, -npc.definition.parts[k].pivot)
						worst = maxf(worst, want.origin.distance_to(npc.bodies[k].global_transform.origin) + (want.basis.get_rotation_quaternion().angle_to(npc.bodies[k].global_basis.get_rotation_quaternion())))
				var clip_now: Transform3D = npc.bodies[npc._part("forearm_r")].global_transform.affine_inverse() * npc.held.global_transform
				print("got up after %.1f s: parts off pose %.3f, rig_root %s, pivots ok %s, clipboard drift %.3f" % [(_f - _t0) / 60.0, worst, npc.rig_root.transform, npc.pivots[0].transform, clip_now.origin.distance_to(_clip_local.origin)])
				_phase = 3
				_t0 = _f
			elif _f - _t0 > 900:
				print("never got up")
				return true
		3:
			if _f - _t0 == 120:
				var worst := 0.0
				for k in npc.bodies.size():
					if npc.bodies[k] != null and npc.attached[k]:
						var want: Transform3D = npc.pivots[k].global_transform * Transform3D(Basis.IDENTITY, -npc.definition.parts[k].pivot)
						worst = maxf(worst, want.origin.distance_to(npc.bodies[k].global_transform.origin))
				print("2 s later: parts off pose %.3f, local transforms %s" % [worst, npc.bodies[0].transform])
				return true
	return false
