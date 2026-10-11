@tool
extends Node3D
## Window, door, gate and fence gallery: every style and shape on its own labelled
## wall section, plus edge cases. Built at runtime so the scene file stays tiny;
## copy any opening's settings into your own walls.

const SECTION := 4.0
const ROW_GAP := 7.0


@export var physics_feel: PhysicsFeel = preload("res://physics/feel/playful.tres")


func _ready() -> void:
	_start_map()
	var z := 0.0
	_row("Window styles", z, _window_styles())
	z += ROW_GAP
	_row("Window shapes", z, _window_shapes())
	z += ROW_GAP
	_row("Window edge cases", z, _window_edge_cases())
	z += ROW_GAP
	_row("Doors", z, _doors())
	z += ROW_GAP
	_row("Gates in garden walls", z, _gates())
	z += ROW_GAP
	_fences(z)


## Places one wall section per entry along +X, each with a sign in front.
func _row(title: String, z: float, entries: Array) -> void:
	_sign(title, Vector3(-3.0, 2.2, z - 1.5), 64)
	var x := 0.0
	for entry in entries:
		var wall: KitWall = entry["wall"]
		var width: float = wall.length
		wall.position = Vector3(x, 0.0, z)
		wall.name = String(entry["label"]).validate_node_name()
		add_child(wall)
		_sign(entry["label"], Vector3(x + width * 0.5, 0.25, z - 1.2), 28)
		x += width + 1.0


func _sign(text: String, at: Vector3, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.004
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = at
	add_child(label)


func _wall(o: KitOpening, length := SECTION, type := KitWall.WallType.EXTERIOR, height := 2.8) -> KitWall:
	var wall := KitWall.new()
	wall.wall_type = type
	wall.length = length
	wall.height = height
	wall.plinth_drop = 0.0
	o.position = length * 0.5
	wall.openings = [o]
	return wall


func _window_styles() -> Array:
	var entries := []
	for style in KitOpening.WindowStyle.values():
		var o := KitOpening.window(0.0, 1.4, 1.3, 0.8)
		o.window_style = style
		var length := SECTION
		match style:
			KitOpening.WindowStyle.FULL_HEIGHT:
				o.sill_height = 0.0
				o.height = 2.5
				o.width = 1.0
			KitOpening.WindowStyle.GLAZED_WALL:
				o.sill_height = 0.0
				o.height = 2.6
				o.width = 3.4
				length = 4.5
			KitOpening.WindowStyle.BAY, KitOpening.WindowStyle.BOW:
				o.width = 2.4
				o.height = 1.5
				o.sill_height = 0.5
		entries.append({"label": _nice(KitOpening.WindowStyle.keys()[style]), "wall": _wall(o, length)})
	return entries


func _window_shapes() -> Array:
	var entries := []
	for shape in KitOpening.Shape.values():
		var o := KitOpening.window(0.0, 1.2, 1.4, 0.8)
		o.shape = shape
		if shape == KitOpening.Shape.POLYGON:
			o.polygon_sides = 6
		if shape in [KitOpening.Shape.CIRCLE, KitOpening.Shape.SQUARE, KitOpening.Shape.POLYGON]:
			o.height = 1.2
		entries.append({"label": _nice(KitOpening.Shape.keys()[shape]), "wall": _wall(o)})
	return entries


func _window_edge_cases() -> Array:
	var entries := []
	var custom := KitOpening.window(0.0, 2.2, 1.5, 0.8)
	custom.panel_layout = "L,F,TT"
	custom.panel_widths = PackedFloat32Array([1, 2, 1])
	custom.transom_height = 0.35
	custom.top_light_layout = "T,T"
	custom.glazing_bars = Vector2i(1, 2)
	entries.append({"label": "Custom layout + transom", "wall": _wall(custom)})
	var tiny := KitOpening.window(0.0, 0.4, 0.4, 1.6)
	tiny.shape = KitOpening.Shape.CIRCLE
	entries.append({"label": "Tiny round", "wall": _wall(tiny)})
	var frosted := KitOpening.window(0.0, 0.7, 1.0, 1.2)
	frosted.obscured = true
	frosted.window_style = KitOpening.WindowStyle.TOP_HUNG_AWNING
	entries.append({"label": "Obscured (bathroom)", "wall": _wall(frosted)})
	var tinted := KitOpening.window(0.0, 1.6, 1.4, 0.8)
	tinted.window_style = KitOpening.WindowStyle.PICTURE
	tinted.glass_tint = Color(0.35, 0.45, 0.4, 0.5)
	tinted.frame_color = Color(0.15, 0.15, 0.16)
	tinted.frame_width = 0.04
	entries.append({"label": "Tinted, slim frame", "wall": _wall(tinted)})
	var wide_arch := KitOpening.window(0.0, 2.4, 2.0, 0.6)
	wide_arch.shape = KitOpening.Shape.ARCHED
	wide_arch.arch_rise = 0.35
	wide_arch.panel_layout = "L,F,R"
	entries.append({"label": "Segmental arch, 3 panels", "wall": _wall(wide_arch)})
	var gable := KitOpening.window(0.0, 1.4, 1.8, 0.6)
	gable.shape = KitOpening.Shape.GABLE
	gable.panel_layout = "L,R"
	entries.append({"label": "Gable, opening panels", "wall": _wall(gable)})
	var interior := KitOpening.window(0.0, 1.2, 1.0, 1.0)
	interior.shape = KitOpening.Shape.OVAL
	entries.append({"label": "Oval, interior wall", "wall": _wall(interior, SECTION, KitWall.WallType.INTERIOR)})
	# A glazed corner: two walls meeting with their glass running round it.
	var corner := KitOpening.window(0.0, 1.6, 1.4, 0.8)
	corner.corner = KitOpening.CornerGlazing.AT_END
	var wall := _wall(corner, 3.0)
	corner.position = 2.2
	wall.end_join = KitWall.Join.CORNER
	var other := KitOpening.window(0.8, 1.6, 1.4, 0.8)
	other.corner = KitOpening.CornerGlazing.AT_START
	var return_wall := KitWall.new()
	return_wall.length = 3.0
	return_wall.height = 2.8
	return_wall.plinth_drop = 0.0
	return_wall.start_join = KitWall.Join.BUTT_EXTERIOR
	return_wall.openings = [other]
	return_wall.rotation_degrees.y = 90.0
	return_wall.position = Vector3(3.0 - 0.15, 0.0, 0.15)
	wall.add_child(return_wall)
	entries.append({"label": "Corner glazing", "wall": wall})
	return entries


func _doors() -> Array:
	var entries := []
	for style in KitOpening.DoorStyle.values():
		var o := KitOpening.door(0.0, 0.9, style)
		if o.is_gate():
			continue
		var length := SECTION
		match style:
			KitOpening.DoorStyle.DOUBLE, KitOpening.DoorStyle.FRENCH, KitOpening.DoorStyle.BIFOLD, KitOpening.DoorStyle.SHED_DOUBLE:
				o.width = 1.6
			KitOpening.DoorStyle.SLIDING_PATIO:
				o.width = 2.4
			KitOpening.DoorStyle.GARAGE_UP_AND_OVER, KitOpening.DoorStyle.GARAGE_SECTIONAL, KitOpening.DoorStyle.ROLLER_SHUTTER:
				o.width = 2.4
				o.powered = style != KitOpening.DoorStyle.GARAGE_UP_AND_OVER
				length = 4.5
			KitOpening.DoorStyle.BARN, KitOpening.DoorStyle.POCKET:
				o.width = 1.0
				length = 4.5
		var type := KitWall.WallType.INTERIOR if style in [KitOpening.DoorStyle.POCKET, KitOpening.DoorStyle.BARN, KitOpening.DoorStyle.GLAZED_INTERIOR, KitOpening.DoorStyle.LABORATORY] else KitWall.WallType.EXTERIOR
		entries.append({"label": _nice(KitOpening.DoorStyle.keys()[style]), "wall": _wall(o, length, type)})
	return entries


func _gates() -> Array:
	var entries := []
	for style in KitOpening.DoorStyle.values():
		var o := KitOpening.door(0.0, 1.0, style)
		if not o.is_gate():
			continue
		o.height = 1.8
		var length := SECTION
		if style in [KitOpening.DoorStyle.GATE_DOUBLE_DRIVEWAY, KitOpening.DoorStyle.GATE_SLIDING]:
			o.width = 3.0
			length = 6.0
		o.head = KitOpening.Head.NONE
		entries.append({"label": _nice(KitOpening.DoorStyle.keys()[style]), "wall": _wall(o, length, KitWall.WallType.GARDEN, 1.8)})
	return entries


func _fences(z: float) -> void:
	_sign("Fences with gates", Vector3(-3.0, 2.2, z - 1.5), 64)
	var gate_styles := [KitOpening.DoorStyle.GATE_TIMBER, KitOpening.DoorStyle.GATE_PICKET, KitOpening.DoorStyle.GATE_SOLID,
		KitOpening.DoorStyle.GATE_TIMBER, KitOpening.DoorStyle.GATE_CHAIN_LINK, KitOpening.DoorStyle.GATE_METAL]
	var x := 0.0
	for style in KitFence.Style.values():
		var fence := KitFence.new()
		fence.style = style
		fence.length = 7.0
		fence.height = 1.0 if style in [KitFence.Style.PICKET, KitFence.Style.POST_AND_RAIL] else 1.8
		if style == KitFence.Style.PICKET:
			fence.color = Color(0.95, 0.95, 0.92)
		var gate := KitOpening.door(3.5, 1.0, gate_styles[style])
		gate.height = fence.height
		fence.gates = [gate]
		fence.position = Vector3(x, 0.0, z)
		fence.name = _nice(KitFence.Style.keys()[style]).validate_node_name()
		add_child(fence)
		_sign(_nice(KitFence.Style.keys()[style]), Vector3(x + 3.5, 0.25, z - 1.2), 28)
		x += 8.0


static func _nice(key: String) -> String:
	return key.capitalize()


## What res://house/house.gd does for the other maps (in game only).
func _start_map() -> void:
	if Engine.is_editor_hint():
		return
	PhysicsFeel.set_active(physics_feel)
	add_child(SpawnMenu.new())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_playground"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene.call_deferred()
