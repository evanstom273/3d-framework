extends SceneTree
var _f := 0
var npc: NPCCharacter
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(20, 1, 20)
		body.add_child(shape)
		body.position.y = -0.5
		root.add_child(body)
		npc = (load("res://npc/assistant.tscn") as PackedScene).instantiate()
		npc.position = Vector3(1, 0, 2)
		root.add_child(npc)
	if _f == 60:
		print("scene instance: life %s, parts %d, home %s, preview nodes %d" % [NPCCharacter.Life.keys()[npc.life], npc.bodies.size(), npc.home, npc.get_children(true).filter(func(n): return n.name == "EditorPreview").size()])
		return true
	return false
