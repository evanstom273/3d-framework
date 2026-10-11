extends SceneTree
var _f := 0
var _bodies: Array[VoxelBody] = []
var _before := {}
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var floor := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(50, 1, 50)
		floor.add_child(shape)
		floor.position.y = -0.5
		root.add_child(floor)
		var x := 0.0
		for p in ["kitchen/base_cabinet", "bedroom/chest_of_drawers", "bedroom/wardrobe_double", "kitchen/corner_cabinet"]:
			var body := VoxelBody.new()
			body.structure = load("res://furniture/%s.tres" % p)
			body.name = p.get_file()
			body.position = Vector3(x, 0.01, 0)
			x += 3.0
			root.add_child(body)
			_bodies.append(body)
			var mechs := _mechs(body)
			print("%s: %d parts" % [body.name, mechs.size()])
			for m in mechs:
				var leaf := m.get_node("Pivot/Leaf") as VoxelBody
				print("   %-8s leaf %5d voxels  frozen %s  closed at %s" % [m.interaction_name, leaf.cells.size(), leaf.freeze, leaf.global_position])
	if _f == 60:
		for body in _bodies:
			for m in _mechs(body):
				var leaf := m.get_node("Pivot/Leaf") as Node3D
				_before[m] = leaf.global_transform
				for a in m.get_interaction_actions():
					m.perform_interaction_action(a["id"], null)
	if _f == 120:
		for body in _bodies:
			for m in _mechs(body):
				var leaf := m.get_node("Pivot/Leaf") as Node3D
				var t: Transform3D = _before[m]
				print("%s %s: open %s, moved %.3f m, turned %.0f deg" % [body.name, m.interaction_name, m.is_open(), leaf.global_position.distance_to(t.origin), rad_to_deg(leaf.global_basis.get_rotation_quaternion().angle_to(t.basis.get_rotation_quaternion()))])
		# Carry test: lift and turn the first piece; its parts must follow.
		var b := _bodies[0]
		b.freeze = true
		b.global_transform = Transform3D(Basis(Vector3.UP, 0.7), b.global_position + Vector3(0, 1.0, 0))
	if _f == 125:
		var b := _bodies[0]
		for m in _mechs(b):
			var leaf := m.get_node("Pivot/Leaf") as Node3D
			var pivot := m.get_node("Pivot") as Node3D
			print("carried: leaf offset from pivot %.4f (expected %.4f)" % [leaf.global_position.distance_to(pivot.global_position), (leaf.position).length()])
		b.freeze = false
		# Smash the hinge edge of the wardrobe's first door.
		var w := _bodies[2]
		var m := _mechs(w)[0]
		var part: FurniturePart = w.structure.moving_parts[0]
		var hinge_world := w.global_transform * part.pivot
		var leaf := m.get_node("Pivot/Leaf") as VoxelBody
		var n0 := leaf.cells.size()
		print("wardrobe at ", w.global_transform, "
 pivot node ", (m.get_node("Pivot") as Node3D).global_transform, "
 leaf ", leaf.global_transform)
		print("hinge in leaf cells: ", leaf.to_local(hinge_world) / leaf.voxel_size, " leaf bounds ", leaf.get_cell_bounds(), " pivot ", part.pivot)
		for y in range(0, 25):
			leaf.damage_at(w.global_transform * (part.pivot + Vector3(0, -1.0 + y * 0.09, 0)), 0.12, 999.0, Vector3.FORWARD)
		print("door voxels %d -> %d" % [n0, leaf.cells.size()])
	if _f == 200:
		var w := _bodies[2]
		var released := 0
		for c in root.get_children():
			if c is VoxelBody and c.name.begins_with("Leaf"):
				released += 1
		print("wardrobe door released into world: %d, its menu functional: %s" % [released, _mechs(w)[0]._functional])
		return true
	return false

func _mechs(n: Node) -> Array[KitMechanism]:
	var out: Array[KitMechanism] = []
	for c in n.get_children(true):
		if c is KitMechanism:
			out.append(c)
		out.append_array(_mechs(c))
	return out
