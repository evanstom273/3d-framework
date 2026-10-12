extends SceneTree
## Opens every gate in the Taskmaster house, then sweeps a player-sized capsule
## (radius 0.3, height 1.8) through each gate opening and reports what blocks it.
var _f := 0
var _s: Node
var _gates: Array = []
func _find(n: Node) -> void:
	for c in n.get_children():
		if c is KitWall or c is KitFence:
			var list: Array = c.openings if c is KitWall else c.gates
			for o: KitOpening in list:
				if o != null and o.is_gate():
					_gates.append([c, o])
		_find(c)
func _mechs(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is KitMechanism: out.append(c)
		_mechs(c, out)
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
	if _f == 3:
		_find(_s)
		for g in _gates:
			var ms := []
			_mechs(g[0], ms)
			for m: KitMechanism in ms:
				m.set_open(true)
	if _f == 150:
		var space := (_s as Node3D).get_world_3d().direct_space_state
		for g in _gates:
			var piece: Node3D = g[0]
			var o: KitOpening = g[1]
			var shape := CapsuleShape3D.new()
			shape.radius = 0.3
			shape.height = 1.8
			var names := {}
			for step in 9:
				var z := -1.0 + step * 0.25
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = shape
				query.transform = piece.global_transform * Transform3D(Basis.IDENTITY, Vector3(o.position, 0.92, z))
				query.collision_mask = 1 | 16
				for hit in space.intersect_shape(query, 8):
					var node: Node = hit["collider"]
					if node is KitSlab or node.name == "Ground": continue
					var shape_id: int = hit["shape"]
					names["%s (%s)" % [node.name, node.get_class()]] = true
			print("%-18s %-22s %s" % [piece.name, o.display_name, "CLEAR" if names.is_empty() else "BLOCKED by " + str(names.keys())])
		return true
	return false
