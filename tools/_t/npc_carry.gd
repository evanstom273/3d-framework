extends SceneTree
## Picking the Assistant up, carrying, setting down, throwing; a mid-limb cut;
## carrying him while floppy.
var _f := 0
var npc: NPCCharacter
var handle: NPCCarryHandle
var _t0 := 0
var _phase := 0
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
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		root.add_child(npc)
		return false
	if npc.life == NPCCharacter.Life.BUILDING:
		return false
	match _phase:
		0:
			var proxy := ObjectManipulatorStub.resolve(npc.bodies[npc._part("forearm_l")])
			print("aim at forearm -> grabs %s" % (proxy.name if proxy != null else "nothing"))
			handle = proxy
			handle.on_grabbed(null)
			_phase = 1
			_t0 = _f
		1:
			# Carry him along and up a bit.
			handle.linear_velocity = Vector3(1.0, 0.3 if _f - _t0 < 30 else 0.0, 0.0)
			if _f - _t0 == 60:
				var torso_off := npc.bodies[0].global_position.distance_to(handle.global_position)
				print("carried: life %s, torso stays %.2f m from handle (rigid), parts frozen %s" % [NPCCharacter.Life.keys()[npc.life], torso_off, npc.bodies[0].freeze])
				handle.linear_velocity = Vector3.ZERO
				handle.on_released(null, false)
				print("set down: life %s, upright %.2f, height %.2f" % [NPCCharacter.Life.keys()[npc.life], npc.bodies[0].global_basis.y.dot(Vector3.UP), npc.global_position.y])
				_phase = 2
				_t0 = _f
		2:
			if _f - _t0 == 30:
				handle = ObjectManipulatorStub.resolve(npc.bodies[0])
				handle.on_grabbed(null)
				handle.linear_velocity = Vector3(0, 2, -7)
				handle.on_released(null, true)
				print("thrown: life %s" % NPCCharacter.Life.keys()[npc.life])
				_phase = 3
				_t0 = _f
		3:
			if npc.life == NPCCharacter.Life.ALIVE:
				var worst := 0.0
				for k in npc.bodies.size():
					if npc.bodies[k] != null and npc.attached[k]:
						var want: Transform3D = npc.pivots[k].global_transform * Transform3D(Basis.IDENTITY, -npc.definition.parts[k].pivot)
						worst = maxf(worst, want.origin.distance_to(npc.bodies[k].global_transform.origin))
				print("  parts off their places by at most %.3f m; clipboard %.2f m from the forearm" % [worst, npc.held.global_position.distance_to(npc.bodies[npc._part("forearm_r")].global_position)])
				print("got up %.1f s after the throw, %.1f m away, upright %.2f" % [(_f - _t0) / 60.0, npc.global_position.length(), npc.bodies[0].global_basis.y.dot(Vector3.UP)])
				# A cut through the middle of the left forearm.
				var i := npc._part("forearm_l")
				var b := npc.bodies[i]
				var mid: Vector3 = b.global_transform * (npc.definition.parts[i].pivot + Vector3.DOWN * 0.12)
				b.damage_at(mid, 0.1, 400.0, Vector3.FORWARD)
				_phase = 4
				_t0 = _f
			elif _f - _t0 > 600:
				print("never got up: life %s" % NPCCharacter.Life.keys()[npc.life])
				return true
		4:
			if _f - _t0 == 20:
				var i := npc._part("forearm_l")
				var loose := 0
				for c in root.get_children():
					if c is VoxelBody and c.cells.size() >= 8: loose += 1
				print("mid-forearm cut: stump still frozen %s & attached %s (%d voxels left), loose pieces in the scene %d" % [npc.bodies[i].freeze, npc.attached[i], npc.bodies[i].cells.size(), loose])
				npc.knock_over(Vector3(0, 0, -60), npc.global_position + Vector3.UP)
				_phase = 5
				_t0 = _f
		5:
			if _f - _t0 == 90:
				handle = ObjectManipulatorStub.resolve(npc.bodies[0])
				print("floppy: life %s, aim at torso grabs %s" % [NPCCharacter.Life.keys()[npc.life], handle.name if handle != null else "nothing"])
				handle.on_grabbed(null)
				_t0 = _f
				_phase = 6
		6:
			handle.linear_velocity = Vector3(0.8, 0, 0)
			if _f - _t0 == 40:
				print("carried floppy: torso %.2f m from handle" % npc.bodies[0].global_position.distance_to(handle.global_position))
				handle.linear_velocity = Vector3.ZERO
				handle.on_released(null, false)
				print("let go floppy: life %s" % NPCCharacter.Life.keys()[npc.life])
				_t0 = _f
				_phase = 7
		7:
			if npc.life == NPCCharacter.Life.ALIVE or _f - _t0 > 600:
				print("after floppy carry: life %s after %.1f s" % [NPCCharacter.Life.keys()[npc.life], (_f - _t0) / 60.0])
				return true
	return false

class ObjectManipulatorStub:
	static func resolve(collider: Object) -> RigidBody3D:
		var manipulator: Node = load("res://physics/object_manipulator.gd").new()
		var result: RigidBody3D = manipulator.resolve_grabbable(collider)
		manipulator.free()
		return result
