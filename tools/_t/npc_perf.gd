extends SceneTree
var _f := 0
var _last := 0
var _frames: Array = []
var _count := int(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 5
func _process(_d: float) -> bool:
	var now := Time.get_ticks_usec()
	if _last > 0 and _f > 60:
		_frames.append((now - _last) / 1000.0)
	_last = now
	return false
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
		for i in _count:
			var npc := NPCCharacter.create(load("res://npc/definitions/assistant.tres"))
			npc.position = Vector3((i % 5) * 2.0 - 4.0, 0, int(i / 5) * 2.0)
			root.add_child(npc)
	if _f == 60 + 600:
		_frames.sort()
		var total := 0.0
		for f in _frames: total += f
		print("%d NPCs: avg frame %.2f ms, p99 %.2f ms, worst %.2f ms (headless, includes physics)" % [_count, total / _frames.size(), _frames[int(_frames.size() * 0.99)], _frames.back()])
		return true
	return false
