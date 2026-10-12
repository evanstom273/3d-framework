extends SceneTree
## Blowtorch, saw, grinder on the Assistant and a cabinet; a leaf-blower push.
var _f := 0
var npc: NPCCharacter
var cabinet: VoxelBody
var _phase := 0
var _t0 := 0
func _burn(body: VoxelBody, point: Vector3, op: StringName, steps: int) -> int:
	var removed := 0
	for i in steps:
		removed += VoxelToolSurface.damage(body, Transform3D(Basis.IDENTITY, point), Vector3(0.08, 0.08, 0.08), op, 0.25, 6.0)
	return removed
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
		cabinet = VoxelBody.new()
		cabinet.structure = load("res://furniture/kitchen/base_cabinet.tres")
		cabinet.position = Vector3(4, 0.01, 0)
		root.add_child(cabinet)
		return false
	if npc.life == NPCCharacter.Life.BUILDING:
		return false
	match _phase:
		0:
			var arm := npc.bodies[npc._part("upper_arm_l")]
			var p: Vector3 = arm.global_transform * (npc.definition.parts[npc._part("upper_arm_l")].pivot + Vector3(0, -0.15, -0.06))
			var n0 := arm.cells.size()
			var removed := _burn(arm, p, &"heat", 12)
			print("blowtorch on arm: %d voxels burnt off (of %d), state %s, bark '%s'" % [removed, n0, NPCBrain.State.keys()[npc.brain.state], npc._bark.text])
			var torso := npc.bodies[0]
			var tp: Vector3 = torso.global_transform * Vector3(0.1, 1.2, -0.12)
			print("chainsaw on torso: %d voxels; grinder: %d voxels; blood splats %d" % [_burn(torso, tp, &"saw", 8), _burn(torso, tp + Vector3(-0.2, 0, 0), &"grind", 8), NPCGore._splats.size()])
			var c0 := cabinet.cells.size()
			var space := cabinet.get_world_3d().direct_space_state
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cabinet.global_position + Vector3(0.12, 0.45, -2.0), cabinet.global_position + Vector3(0.12, 0.45, 2.0), 16))
			var cp: Vector3 = hit["position"] if not hit.is_empty() else cabinet.global_position
			print("  cabinet surface hit: %s" % (hit.get("collider") == cabinet))
			print("cabinet: blowtorch %d voxels, saw %d voxels (of %d)" % [_burn(cabinet, cp, &"heat", 8), _burn(cabinet, cp + Vector3(0.1, 0, 0), &"saw", 8), c0])
			_phase = 1
			_t0 = _f
		1:
			# A leaf blower going at him for 2 s.
			if _f - _t0 < 120 and npc.life == NPCCharacter.Life.ALIVE:
				ToolMatter.push(npc.bodies[0], Vector3(0, 0, -8.0), npc.global_position + Vector3.UP)
			elif _f - _t0 == 130 or npc.life != NPCCharacter.Life.ALIVE:
				print("leaf blower: moved to %s, life %s" % [npc.global_position, NPCCharacter.Life.keys()[npc.life]])
				return true
	return false
