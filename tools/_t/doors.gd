extends SceneTree
## Checks the space in front of and behind every door and doorway in the
## Taskmaster house for furniture, stairs or walls in the way.
var _f := 0
var _scene: Node
func _walls(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is KitWall: out.append(c)
		_walls(c, out)
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_scene = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_scene)
	if _f == 4:
		var space := (_scene as Node3D).get_world_3d().direct_space_state
		var walls := []
		_walls(_scene, walls)
		var blocked := 0
		var checked := 0
		for wall: KitWall in walls:
			for o: KitOpening in wall.openings:
				if o == null or o.kind == KitOpening.Kind.WINDOW or o.is_gate():
					continue
				checked += 1
				# Clear width between the frame jambs against the player capsule (0.6 m).
				var clear := o.width - 0.12 if o.kind == KitOpening.Kind.DOOR else o.width
				if clear < 0.8:
					blocked += 1
					print("%-28s %-22s too narrow: %.2f m clear" % [wall.name, o.display_name, clear])
				var half := wall.thickness() * 0.5
				for side in [-1.0, 1.0]:
					var shape := BoxShape3D.new()
					# A pair of leaves each swings half the opening.
					var pair := o.door_style in [KitOpening.DoorStyle.FRENCH, KitOpening.DoorStyle.DOUBLE, KitOpening.DoorStyle.SHED_DOUBLE]
					var depth := (o.width * 0.5 if pair else o.width) + 0.2
					shape.size = Vector3(o.width - 0.1, 1.6, depth)
					var local := Vector3(o.position, o.bottom() + 0.25 + 0.8, side * (half + 0.03 + depth * 0.5))
					var query := PhysicsShapeQueryParameters3D.new()
					query.shape = shape
					query.transform = wall.global_transform * Transform3D(Basis.IDENTITY, local)
					query.collision_mask = 1 | 16
					query.exclude = [wall.get_rid()]
					var names := []
					for hit in space.intersect_shape(query, 16):
						var node: Node = hit["collider"]
						if node is KitFloor or node is KitSlab or node is KitSteps or node is KitPorch: continue
						# Door leaves and frames of this opening belong to the wall's own fixtures.
						if wall.is_ancestor_of(node): continue
						names.append(node.name)
					if not names.is_empty():
						blocked += 1
						print("%-28s %-22s %s side: %s" % [wall.get_parent().name + "/" + wall.name, o.display_name if o.display_name != "" else "doorway", ("inside" if side > 0 else "outside") + (" (swings this way)" if (side > 0) == o.opens_inward and o.kind == KitOpening.Kind.DOOR else ""), names])
		print("doors checked %d, blocked sides %d" % [checked, blocked])
		return true
	return false
