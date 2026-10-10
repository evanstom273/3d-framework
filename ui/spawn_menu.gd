class_name SpawnMenu
extends CanvasLayer
## Q opens a tabbed menu of everything spawnable; clicking an item drops it where
## the crosshair points. G spawns a random item there without opening the menu.
## The catalogue fills itself from every PhysicsObjectDefinition and
## VoxelStructureDefinition under props/, so new .tres files appear automatically.

const SCAN_ROOT := "res://props"
const SKIP_DIRS := ["vox", "details", "voxel_materials"]
const TAB_ORDER := ["Tools", "Props", "Balls", "Destructible", "Containers", "Structures"]
## Tabs the random spawn picks from (big anchored structures are left out).
const RANDOM_TABS := ["Tools", "Props", "Balls", "Destructible", "Containers"]
const SPAWN_REACH := 6.0
const SPAWN_MASK := 1 | 2 | 4 | 16

## Tab name -> Array of {name, resource}.
var _entries: Dictionary = {}
var _spawned: Array[Node] = []
var _root: Control
var _panel: PanelContainer
var _status: Label


func _ready() -> void:
	layer = 20
	_scan(SCAN_ROOT)
	for tab in _entries:
		_entries[tab].sort_custom(func(a, b): return a["name"] < b["name"])
	_build_ui()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	_root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_root.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_spawn_menu"):
		if is_open():
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open() and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif not is_open() and event.is_action_pressed("spawn_random") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spawn_random()
		get_viewport().set_input_as_handled()


func spawn_random() -> void:
	var pool: Array = []
	for tab in RANDOM_TABS:
		pool.append_array(_entries.get(tab, []))
	if not pool.is_empty():
		_spawn(pool[randi() % pool.size()])


func clear_spawned() -> void:
	for node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	_set_status("Cleared")


# --- Catalogue

func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		if not SKIP_DIRS.has(sub):
			_scan(dir_path.path_join(sub))
	for file in dir.get_files():
		# Exported builds list resources with a .remap suffix.
		file = file.trim_suffix(".remap")
		if not file.ends_with(".tres"):
			continue
		var resource := load(dir_path.path_join(file))
		var tab := _tab_for(resource)
		if tab.is_empty():
			continue
		if not _entries.has(tab):
			_entries[tab] = []
		_entries[tab].append({"name": resource.get("display_name"), "resource": resource})


func _tab_for(resource: Resource) -> String:
	if resource is PhysicsObjectDefinition:
		var definition := resource as PhysicsObjectDefinition
		if not definition.spawn_category.is_empty():
			return definition.spawn_category
		if definition.tool != null:
			return "Tools"
		if definition.container != null:
			return "Containers"
		if definition.shape_type == PhysicsObjectDefinition.ShapeType.SPHERE:
			return "Balls"
		return "Props"
	if resource is VoxelStructureDefinition:
		var structure := resource as VoxelStructureDefinition
		if not structure.spawn_category.is_empty():
			return structure.spawn_category
		return "Destructible" if structure.anchor_mode == VoxelStructureDefinition.AnchorMode.NONE else "Structures"
	return ""


# --- Spawning

func _spawn(entry: Dictionary) -> void:
	var resource: Resource = entry["resource"]
	var place := _spawn_point()
	if place.is_empty():
		return
	var node: Node3D
	if resource is PhysicsObjectDefinition:
		var definition := resource as PhysicsObjectDefinition
		node = PhysicsProp.create(definition)
		var lift := _lift_for(definition, place["normal"])
		_add_to_world(node, Transform3D(place["basis"], place["position"] + lift))
	elif resource is VoxelStructureDefinition:
		var body := VoxelBody.new()
		body.structure = resource
		body.name = String(entry["name"]).to_pascal_case()
		node = body
		# Structures stand on their bottom layer, so they sit right at the floor point.
		_add_to_world(node, Transform3D(place["basis"], place["position"] + Vector3.UP * 0.005))
	_set_status("Spawned %s" % entry["name"])


func _spawn_skittles() -> void:
	var pin := _find_resource("Skittle")
	var ball := _find_resource("Bowling Ball")
	var place := _spawn_point()
	if pin == null or place.is_empty():
		return
	var basis: Basis = place["basis"]
	# A 1-2-3-4 triangle with its point toward the player, and the ball between.
	var away := basis.z
	var side := basis.x
	var head_pin: Vector3 = place["position"]
	for row in 4:
		for index in row + 1:
			var offset := side * (index - row * 0.5) * 0.3 + away * row * 0.26
			var skittle := PhysicsProp.create(pin)
			_add_to_world(skittle, Transform3D(basis, head_pin + offset + _lift_for(pin, Vector3.UP)))
	if ball != null:
		var bowling := PhysicsProp.create(ball)
		_add_to_world(bowling, Transform3D(basis, head_pin - away * 1.5 + _lift_for(ball, Vector3.UP)))
	_set_status("Spawned skittles")


func _add_to_world(node: Node3D, at: Transform3D) -> void:
	var world := get_tree().current_scene if get_tree().current_scene != null else get_parent()
	world.add_child(node)
	node.global_transform = at
	_spawned.append(node)


## Where the crosshair points (within reach), facing the player. {} if no camera.
func _spawn_point() -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * SPAWN_REACH, SPAWN_MASK)
	var holder := _holder_of(camera)
	if holder != null:
		query.exclude = [holder.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var flat := forward.slide(Vector3.UP)
	var yaw := atan2(flat.x, flat.z) if flat.length_squared() > 0.0001 else 0.0
	# The object's front (-Z) faces back toward the player.
	var basis := Basis(Vector3.UP, yaw)
	if hit.is_empty():
		return {"position": origin + forward * 3.0, "normal": Vector3.UP, "basis": basis}
	return {"position": hit["position"], "normal": hit["normal"], "basis": basis}


## Offset so a spawned prop rests on the surface instead of inside it.
func _lift_for(definition: PhysicsObjectDefinition, normal: Vector3) -> Vector3:
	var bounds := AABB()
	var first := true
	for part in definition.get_collision_parts():
		var shape: Shape3D = part["shape"]
		var shape_bounds: AABB = part["transform"] * shape.get_debug_mesh().get_aabb()
		bounds = shape_bounds if first else bounds.merge(shape_bounds)
		first = false
	if normal.y > 0.7:
		return Vector3.UP * (-bounds.position.y + 0.02)
	return normal * (bounds.size.length() * 0.5 + 0.02)


func _holder_of(node: Node) -> CollisionObject3D:
	while node != null:
		if node is CollisionObject3D:
			return node
		node = node.get_parent()
	return null


func _find_resource(display: String) -> Resource:
	for tab in _entries:
		for entry in _entries[tab]:
			if entry["name"] == display:
				return entry["resource"]
	return null


# --- UI

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# Dims the game and swallows stray clicks, so they can't recapture the mouse.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.35)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	# A centring container keeps the panel in the middle at any window size.
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	_panel = PanelContainer.new()
	var style := _flat(Color(0.08, 0.09, 0.11, 0.96), 10)
	style.set_content_margin_all(16)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)
	centre.add_child(_panel)
	get_viewport().size_changed.connect(_fit_panel)
	_fit_panel()
	var panel := _panel

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Spawn"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var hint := Label.new()
	hint.text = "Click to spawn at the crosshair  ·  G: random spawn  ·  Q / Esc: close"
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	column.add_child(hint)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", _flat(Color(0.12, 0.13, 0.16, 1.0), 6))
	tabs.add_theme_stylebox_override("tab_selected", _flat(Color(0.32, 0.5, 0.78), 6))
	tabs.add_theme_stylebox_override("tab_unselected", _flat(Color(0.18, 0.2, 0.24), 6))
	tabs.add_theme_stylebox_override("tab_hovered", _flat(Color(0.26, 0.3, 0.36), 6))
	column.add_child(tabs)
	for tab in TAB_ORDER:
		if _entries.has(tab):
			tabs.add_child(_build_tab(tab))
	for tab in _entries:
		if not TAB_ORDER.has(tab):
			tabs.add_child(_build_tab(tab))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	actions.add_child(_button("Random", spawn_random))
	actions.add_child(_button("Clear spawned", clear_spawned))
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	actions.add_child(_status)
	actions.add_child(_button("Close", close))


func _build_tab(tab: String) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = tab
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for entry in _entries[tab]:
		grid.add_child(_button(entry["name"], _spawn.bind(entry)))
	if tab == "Balls" and _find_resource("Skittle") != null:
		grid.add_child(_button("Skittles Set", _spawn_skittles))
	return scroll


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = true
	button.add_theme_stylebox_override("normal", _flat(Color(0.2, 0.22, 0.27), 6))
	button.add_theme_stylebox_override("hover", _flat(Color(0.28, 0.32, 0.39), 6))
	button.add_theme_stylebox_override("pressed", _flat(Color(0.32, 0.5, 0.78), 6))
	button.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.pressed.connect(action)
	return button


func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


## Up to 820 x 520, but never bigger than 90% of the visible screen.
func _fit_panel() -> void:
	var screen := get_viewport().get_visible_rect().size
	_panel.custom_minimum_size = Vector2(minf(820.0, screen.x * 0.9), minf(520.0, screen.y * 0.9))


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
