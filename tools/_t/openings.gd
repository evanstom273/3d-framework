extends SceneTree
var _f := 0
func _walls(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is KitWall: out.append(c)
		_walls(c, out)
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var s := (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		var walls := []
		_walls(s, walls)
		for w: KitWall in walls:
			var spans := []
			for o: KitOpening in w.openings:
				var kind: String = KitOpening.Kind.keys()[o.kind]
				var style: String = KitOpening.DoorStyle.keys()[o.door_style] if o.kind == KitOpening.Kind.DOOR else KitOpening.WindowStyle.keys()[o.window_style]
				print("%-34s %-12s %-22s at %5.2f  w %.2f  h %.2f  bottom %.2f  %s" % [w.get_parent().name + "/" + w.name, kind, style, o.position, o.width, o.height, o.bottom(), o.display_name])
				spans.append([o.position - o.width * 0.5, o.position + o.width * 0.5, o])
			for i in spans.size():
				for j in range(i + 1, spans.size()):
					if spans[i][0] < spans[j][1] and spans[j][0] < spans[i][1]:
						print("   !! OVERLAP in %s" % w.name)
		s.free()
		return true
	return false
