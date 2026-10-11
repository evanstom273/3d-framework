extends CanvasLayer
## Global pause menu (autoload "PauseMenu"). Esc pauses any level; the main menu
## is left alone, and an open spawn menu gets Esc first so it can close itself.

const UiStyle := preload("res://ui/ui_style.gd")
const MAIN_MENU := "res://ui/main_menu.tscn"
const SettingsMenu := preload("res://ui/settings_menu.gd")

var _root: Control


func _ready() -> void:
	layer = 50
	# Keeps working while the rest of the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Audio buses and saved volumes, for every scene (this autoload always loads first).
	GameSettings.load_and_apply()
	# Graphics settings, applied to each scene as it loads.
	VideoSettings.watch(get_tree())
	# F9: record 30 s of performance metrics to perf_logs/.
	add_child(preload("res://ui/perf_recorder.gd").new())
	# Compiles voxel and furniture shaders while each map loads.
	add_child(preload("res://ui/shader_warmup.gd").new())
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo() or _settings_open():
		return
	if is_open():
		resume()
		get_viewport().set_input_as_handled()
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path == MAIN_MENU or _spawn_menu_open():
		return
	open()
	get_viewport().set_input_as_handled()


func open() -> void:
	get_tree().paused = true
	_root.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func restart() -> void:
	_root.hide()
	get_tree().paused = false
	get_tree().reload_current_scene()


func to_main_menu() -> void:
	_root.hide()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func open_settings() -> void:
	if not _settings_open():
		_root.add_child(SettingsMenu.new())


func _settings_open() -> bool:
	for child in _root.get_children():
		if child.get_script() == SettingsMenu and not child.is_queued_for_deletion():
			return true
	return false


func _spawn_menu_open() -> bool:
	for menu in get_tree().get_nodes_in_group(&"spawn_menus"):
		if menu.has_method("is_open") and bool(menu.call("is_open")):
			return true
	return false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(300, 0)
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "Paused"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)
	column.add_child(UiStyle.spacer(6))
	column.add_child(UiStyle.button("Resume", resume))
	column.add_child(UiStyle.button("Restart level", restart))
	column.add_child(UiStyle.button("Settings", open_settings))
	column.add_child(UiStyle.button("Main menu", to_main_menu))
	column.add_child(UiStyle.button("Quit to desktop", get_tree().quit))
