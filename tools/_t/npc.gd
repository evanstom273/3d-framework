extends SceneTree
## Spawns the Assistant in a walled room and runs it through its paces.
var _f := 0
var npc: NPCCharacter
var _last := 0
var _worst := 0.0
var _log := []
func _process(_d: float) -> bool:
	var now := Time.get_ticks_usec()
	if _last > 0 and _f > 2:
		_worst = maxf(_worst, (now - _last) / 1000.0)
	_last = now
	return false
func _box(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = pos
	root.add_child(body)
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_box(Vector3(0, -0.5, 0), Vector3(20, 1, 20))
		for wall in [[Vector3(0, 1, -5), Vector3(10, 2, 0.3)], [Vector3(0, 1, 5), Vector3(10, 2, 0.3)], [Vector3(-5, 1, 0), Vector3(0.3, 2, 10)], [Vector3(5, 1, 0), Vector3(0.3, 2, 10)], [Vector3(1.5, 0.5, 1), Vector3(1, 1, 1)]]:
			_box(wall[0], wall[1])
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"))
		root.add_child(npc)
	if _f < 400 and npc.life == NPCCharacter.Life.BUILDING:
		return false
	if not has_meta("built"):
		set_meta("built", _f)
		print("built after %d frames; worst frame so far %.1f ms; parts %d, held %s" % [_f, _worst, npc.bodies.size(), npc.held != null])
		_worst = 0.0
	var t: int = _f - int(get_meta("built"))
	if t > 0 and t % 120 == 0 and t <= 600:
		var torso := npc.bodies[0]
		print("t=%ds pos %s state %s upright %.2f worst %.1f ms" % [t / 60, npc.global_position, NPCBrain.State.keys()[npc.brain.state], torso.global_basis.y.dot(Vector3.UP), _worst])
	if t == 620:
		# Smash the left elbow.
		var i := npc._part("forearm_l")
		var p: Vector3 = npc.bodies[i].global_transform * npc.definition.parts[i].pivot
		npc.bodies[i].damage_at(p, 0.09, 200.0, Vector3.FORWARD)
		npc.bodies[npc.definition.parts[i].parent].damage_at(p, 0.09, 200.0, Vector3.FORWARD)
	if t == 640:
		print("elbow: forearm_l attached %s, life %s, gore splats %d" % [npc.attached[npc._part("forearm_l")], NPCCharacter.Life.keys()[npc.life], NPCGore._splats.size()])
		var i := npc._part("shin_r")
		var p: Vector3 = npc.bodies[i].global_transform * npc.definition.parts[i].pivot
		npc.bodies[i].damage_at(p, 0.1, 200.0, Vector3.FORWARD)
	if t == 700:
		print("knee: shin_r attached %s, gait %s, life %s" % [npc.attached[npc._part("shin_r")], NPCRig.Gait.keys()[npc.rig.gait(1.0)], NPCCharacter.Life.keys()[npc.life]])
		npc._on_hit(200.0, npc.global_position + Vector3.UP * 1.2, Vector3.BACK, 0)
	if t == 720:
		print("knocked: life %s" % NPCCharacter.Life.keys()[npc.life])
	if t > 720 and t < 1200 and npc.life == NPCCharacter.Life.ALIVE and not has_meta("up"):
		set_meta("up", t)
		print("back up after %.1f s, upright %.2f" % [(t - 720) / 60.0, npc.bodies[0].global_basis.y.dot(Vector3.UP)])
	if t == 1210:
		var i := npc._part("head")
		var p: Vector3 = npc.bodies[i].global_transform * (npc.definition.parts[i].pivot + Vector3.UP * 0.18)
		for k in 4:
			npc.bodies[i].damage_at(p + Vector3(0, -0.05 * k, 0), 0.14, 300.0, Vector3.FORWARD)
	if t == 1260:
		var loose := 0
		for c in root.get_children():
			if c is VoxelBody: loose += 1
		print("head: life %s, held dropped %s, splats %d, bursts live %d, worst frame %.1f ms" % [NPCCharacter.Life.keys()[npc.life], not npc.held.freeze, NPCGore._splats.size(), NPCGore._bursts, _worst])
		return true
	return false
