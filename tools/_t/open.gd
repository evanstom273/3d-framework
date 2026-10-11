extends SceneTree
## Builds a wall per window style / shape and door style, then opens, closes,
## locks and pries every mechanism, checking that its movers actually move.

var _walls: Array[KitWall] = []
var _frame := 0
var _phase := 0
var _snap: Dictionary = {}
var _problems := 0


func _build_all() -> void:
	var specs: Array[KitOpening] = []
	for style in KitOpening.WindowStyle.values():
		var o := KitOpening.window(1.6, 1.4, 1.3, 0.8)
		o.window_style = style
		o.display_name = "W style %s" % KitOpening.WindowStyle.keys()[style]
		if style == KitOpening.WindowStyle.FULL_HEIGHT or style == KitOpening.WindowStyle.GLAZED_WALL:
			o.sill_height = 0.0
			o.height = 2.4
			o.width = 2.4
		specs.append(o)
	for shape in KitOpening.Shape.values():
		var o := KitOpening.window(1.6, 1.2, 1.4, 0.8)
		o.shape = shape
		o.display_name = "W shape %s" % KitOpening.Shape.keys()[shape]
		specs.append(o)
	var extra := KitOpening.window(1.6, 1.8, 1.5, 0.8)
	extra.panel_layout = "L,F,TT"
	extra.panel_widths = PackedFloat32Array([1, 2, 1])
	extra.transom_height = 0.35
	extra.top_light_layout = "T,T"
	extra.glazing_bars = Vector2i(1, 2)
	extra.display_name = "W custom"
	specs.append(extra)
	var corner := KitOpening.window(2.5, 1.4, 1.3, 0.8)
	corner.corner = KitOpening.CornerGlazing.AT_END
	corner.display_name = "W corner"
	specs.append(corner)
	for style in KitOpening.DoorStyle.values():
		var o := KitOpening.door(1.6, 0.9, style)
		o.display_name = "D %s" % KitOpening.DoorStyle.keys()[style]
		if style in [KitOpening.DoorStyle.DOUBLE, KitOpening.DoorStyle.FRENCH, KitOpening.DoorStyle.SLIDING_PATIO, KitOpening.DoorStyle.BIFOLD, KitOpening.DoorStyle.SHED_DOUBLE, KitOpening.DoorStyle.GATE_DOUBLE_DRIVEWAY]:
			o.width = 1.6
		if style in [KitOpening.DoorStyle.GARAGE_UP_AND_OVER, KitOpening.DoorStyle.GARAGE_SECTIONAL, KitOpening.DoorStyle.ROLLER_SHUTTER]:
			o.width = 2.4
			o.height = 2.1
			o.powered = true
		if style == KitOpening.DoorStyle.GATE_DOUBLE_DRIVEWAY or style == KitOpening.DoorStyle.GATE_SLIDING:
			o.width = 2.6
		specs.append(o)
	var x := 0.0
	for o in specs:
		var wall := KitWall.new()
		wall.length = 3.4
		wall.height = 2.8
		if o.is_gate():
			wall.wall_type = KitWall.WallType.GARDEN
			wall.height = 2.2
		wall.openings = [o]
		wall.position = Vector3(x, 0, 0)
		x += 4.0
		var t0 := Time.get_ticks_usec()
		root.add_child(wall)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		_walls.append(wall)
		var mechs := _mechs(wall)
		var climb := 0
		for c in wall.get_children():
			if c is KitWindowOpening:
				climb += 1
		print("%-34s build %6.1f ms  mechanisms %d  climbable %d" % [o.display_name, ms, mechs.size(), climb])
		if mechs.is_empty() and not o.window_style in [KitOpening.WindowStyle.FIXED, KitOpening.WindowStyle.PICTURE, KitOpening.WindowStyle.GLAZED_WALL] and o.kind == KitOpening.Kind.DOOR:
			print("   !! no mechanism")
			_problems += 1


func _mechs(n: Node) -> Array[KitMechanism]:
	var out: Array[KitMechanism] = []
	for c in n.get_children():
		if c is KitMechanism:
			out.append(c)
		out.append_array(_mechs(c))
	return out


func _poses(m: KitMechanism) -> Array:
	var out := []
	for mover in m.movers:
		out.append(mover.node.transform if is_instance_valid(mover.node) else Transform3D())
	return out


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_build_all()
		return false
	if _frame == 3:
		for wall in _walls:
			for m in _mechs(wall):
				_snap[m] = _poses(m)
				var acts := m.get_interaction_actions()
				var opened := false
				for a in acts:
					if String(a["id"]).begins_with("open:"):
						m.perform_interaction_action(a["id"], null)
						opened = true
				if not opened:
					print("   !! %s: no open action (%s)" % [m.interaction_name, acts])
					_problems += 1
	elif _frame == 120:
		for wall in _walls:
			for m in _mechs(wall):
				var before: Array = _snap[m]
				var after := _poses(m)
				var moved := 0
				for i in after.size():
					if not after[i].is_equal_approx(before[i]):
						moved += 1
				if moved == 0 or not m.is_open():
					print("   !! %s: open moved %d/%d movers, is_open %s" % [m.interaction_name, moved, after.size(), m.is_open()])
					_problems += 1
				var climbers := 0
				for c in wall.get_children():
					if c is KitWindowOpening and c.is_open():
						climbers += 1
				for a in m.get_interaction_actions():
					if String(a["id"]).begins_with("close:"):
						m.perform_interaction_action(a["id"], null)
	elif _frame == 240:
		for wall in _walls:
			for m in _mechs(wall):
				var before: Array = _snap[m]
				var after := _poses(m)
				for i in after.size():
					if not after[i].is_equal_approx(before[i]):
						print("   !! %s: mover %d did not return when closed" % [m.interaction_name, i])
						_problems += 1
				if m.is_open():
					print("   !! %s still open" % m.interaction_name)
					_problems += 1
				if m.lockable:
					m.perform_interaction_action(&"lock", null)
					if not m.is_locked():
						print("   !! %s won't lock" % m.interaction_name)
						_problems += 1
					if not m.force_open():
						print("   !! %s: force_open refused" % m.interaction_name)
						_problems += 1
	elif _frame == 360:
		for wall in _walls:
			for m in _mechs(wall):
				if m.lockable and (not m.is_open() or m.is_locked()):
					print("   !! %s: not open after prying" % m.interaction_name)
					_problems += 1
		print("DONE problems: %d" % _problems)
		return true
	return false
