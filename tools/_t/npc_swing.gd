extends SceneTree
## Hinged doors: (a) approach from the side they swing towards, (b) start pinned behind the open door.
var _f := 0
var _s: Node
var npc: NPCCharacter
var player: CharacterBody3D
var doors: Array = []
var info := {}
var _i := -1
var _phase := 0  # 0 approach, 1 pocket
var _t := 0
var _goal := Vector3.ZERO
var _min_leaf := INF

func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		var real := _s.get_node_or_null("Player")
		if real != null: real.free()
		player = CharacterBody3D.new(); _s.add_child(player)
		var cam := Camera3D.new(); cam.position.y = 1.6; player.add_child(cam); cam.current = true
		npc = NPCCharacter.create(load("res://npc/definitions/assistant.tres"), false)
		npc.position = Vector3(5.6, 0.3, 4.6); _s.add_child(npc)
		return false
	if _f == 2:
		for n in _s.find_children("*", "", true, false):
			if n.has_meta(&"door") and n.has_method("set_open") or n.has_meta(&"door") and n.get_script() and n.get_script().resource_path.ends_with("breakable_hinge.gd"):
				doors.append(n)
		return false
	if _f == 3:
		for d in doors: info[d] = [npc.brain._leaves_bounds(d).get_center()]
		for d in doors: _open(d, true)
		return false
	if _f == 120:
		for d in doors: info[d].append(npc.brain._leaves_bounds(d).get_center())
		for d in doors: _open(d, false)
		var hinged := []
		for d in doors:
			var c: Vector3 = info[d][0]; var o: Vector3 = info[d][1]
			var b := npc.brain._leaves_bounds(d)
			var n: Vector3 = (d as Node3D).global_basis.z; n.y = 0; n = n.normalized()
			var along := n.cross(Vector3.UP)
			if absf((o - c).dot(n)) > 0.2 and absf((o - c).dot(along)) > 0.1 and b.size.y > 1.5:
				info[d] = [c, o, n * signf((o - c).dot(n)), along * signf((o - c).dot(along))]
				hinged.append(d)
		doors = hinged
		print("hinged doors: ", doors.size())
		if npc.brain._nav != null: npc.brain._nav._bake()
		for d in doors:
			if only == String(d.get("interaction_name")): print("   centre ", info[d][0], " open centre ", info[d][1], " swing ", info[d][2])
		return false
	if _f < 200 or npc.life == NPCCharacter.Life.BUILDING or not npc.brain._nav.is_ready:
		return false
	_t -= 1
	if _t > 0:
		var d: Node = doors[_i]
		_min_leaf = minf(_min_leaf, npc.brain._leaf_distance(d))
	if _t <= 0:
		if _i >= 0: _report()
		_phase = 1 - _phase if _i >= 0 else 0
		if _phase == 0: _i += 1
		if _i >= doors.size() or only != "" and _i > 0 and String(doors[_i - 1].get("interaction_name")) == only: return true
		_place()
		_t = 60 * 12
	return false

func _open(d: Node, open: bool) -> void:
	if d.has_method("set_open"): d.set_open(open)
	else:
		for a in d.get_interaction_actions():
			if String(a["id"]) == ("open" if open else "close"): d.perform_interaction_action(a["id"], null)

func _place() -> void:
	var d: Node = doors[_i]
	var c: Vector3 = info[d][0]; var o: Vector3 = info[d][1]; var swing: Vector3 = info[d][2]; var lateral: Vector3 = info[d][3]
	var floor_y := npc.brain._leaves_bounds(d).position.y if false else c.y - 1.0
	var at: Vector3
	if _phase == 0:
		_open(d, false)
		at = c + swing * 1.4
	else:
		_open(d, true)
		at = o + lateral * 0.42 - swing * 0.0
	at.y = c.y - 0.95
	npc.velocity = Vector3.ZERO
	npc.global_position = at
	npc.home = at
	player.global_position = Vector3(c.x, at.y, c.z) - swing * 2.5
	_goal = player.global_position
	npc.brain.set_following(true)
	_min_leaf = INF

func _report() -> void:
	var d: Node = doors[_i]
	var c: Vector3 = info[d][0]; var swing: Vector3 = info[d][2]
	var through := (npc.global_position - c).dot(swing) < 0.0
	if only == "" or String(d.get("interaction_name")) == only: print("%-22s %-8s through=%s  %.1f m from player  closest to leaf %.2f m  open=%s" % [d.get("interaction_name"), "approach" if _phase == 0 else "pocket", through, npc.global_position.distance_to(player.global_position), _min_leaf, NPCNavigation.is_open(d)])

var only := ""
func _initialize() -> void:
	for a in OS.get_cmdline_user_args(): only = a
func _process(_d: float) -> bool:
	if only != "" and _i >= 0 and _i < doors.size() and String(doors[_i].get("interaction_name")) == only and _phase == 0 and _f % 30 == 0:
		var b := npc.brain
		print("   %s %s route %d/%d leaf %.2f swing %s stuck %.2f rs %d sees %s open %s" % [NPCBrain.State.keys()[b.state], npc.global_position.snapped(Vector3.ONE*0.01), b._route_index, b._route.size(), b._leaf_distance(doors[_i]), b._swing_door != null, b._stuck_time, b._route_stuck, b._sees_last, NPCNavigation.is_open(doors[_i])])
	return false
