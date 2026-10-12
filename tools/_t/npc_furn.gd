extends SceneTree
## Follow soak: the stand-in player hops to random walkable spots on the ground
## floor every 12 s; how often does the Assistant catch up, and how long is he stuck?
var _f := 0
var _s: Node
var npc: NPCCharacter
var player: CharacterBody3D
var _hops := 0
var _reached := 0
var _got_there := false
var _stuck := 0
var _last := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_rng.seed = 7
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		var real := _s.get_node_or_null("Player")
		if real != null: real.free()
		player = CharacterBody3D.new(); player.position = Vector3(5.6, 0.3, 3.2); _s.add_child(player)
		var cam := Camera3D.new(); cam.position.y = 1.6; player.add_child(cam); cam.current = true
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		npc.position = Vector3(5.6, 0.3, 4.6); _s.add_child(npc)
		return false
	if npc.life == NPCCharacter.Life.BUILDING or npc.brain._nav == null or not npc.brain._nav.is_ready:
		return false
	if not npc.brain.following: npc.brain.set_following(true)
	if (_f % (60 * 12)) == 0:
		if _got_there: _reached += 1
		var p := Vector3.INF
		while not p.is_finite():
			p = npc.brain._nav.random_near(Vector3(_rng.randf_range(0, 12), 0.3, _rng.randf_range(0, 12)), 4.0)
			if p.is_finite() and npc.brain._nav.path(npc.global_position, p).size() < 2: p = Vector3.INF
		player.global_position = p
		_hops += 1
		_got_there = false
		print("hop %d -> %s  (npc at %s)" % [_hops, p.snapped(Vector3.ONE*0.1), npc.global_position.snapped(Vector3.ONE*0.1)])
	var dist := npc.global_position.distance_to(player.global_position)
	if dist < 2.2: _got_there = true
	if _f % 30 == 0:
		if dist > 3.0 and npc.global_position.distance_to(_last) < 0.1: _stuck += 1
		_last = npc.global_position
	if false:
		var b := npc.brain
		print("   %s %s route %d/%d stuck %.1f rs %d unstick %s fallback-trail %d vel %s" % [NPCBrain.State.keys()[b.state], npc.global_position.snapped(Vector3.ONE*0.01), b._route_index, b._route.size(), b._stuck_time, b._route_stuck, Time.get_ticks_msec() < b._unstick_until, b._trail.size(), npc.velocity.snapped(Vector3.ONE*0.01)])
	if _hops > 15:
		print("reached %d of %d hops; stuck half-seconds %d; route_stuck now %d" % [_reached, _hops - 1, _stuck, npc.brain._route_stuck])
		return true
	return false

var _rs := 0
func _process(_d: float) -> bool:
	if npc == null or npc.brain == null: return false
	if npc.brain._route_stuck > _rs:
		var near := []
		for n in _s.find_children("*", "VoxelBody", true, false):
			var b := NPCNavigation._bounds(n)
			if b.grow(0.35).has_point(npc.global_position + Vector3.UP * 0.9):
				var p: Node = n.get_parent(); var chain := n.name
				for k in 3:
					if p == null: break
					chain = p.name + "/" + chain; p = p.get_parent()
				near.append(chain)
		print("   STUCK at %s heading %s: touching %s" % [npc.global_position.snapped(Vector3.ONE*0.01), npc.brain._route[npc.brain._route_index].snapped(Vector3.ONE*0.01) if npc.brain._route_index < npc.brain._route.size() else "-", near])
	_rs = npc.brain._route_stuck
	return false
