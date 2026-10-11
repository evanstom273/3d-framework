extends Control
## Settings overlay (audio volumes, video quality), shared by the main menu and
## the pause menu. Changes apply live and are saved when the panel closes.

signal closed

const UiStyle := preload("res://ui/ui_style.gd")

var _sliders: Dictionary = {}
var _values: Dictionary = {}
var _pages: Array[Control] = []
var _video_controls: Dictionary = {}
var _preset_buttons: Dictionary = {}
var _preset_status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameSettings.load_and_apply()
	_build()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	GameSettings.save()
	closed.emit()
	queue_free()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.55)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	centre.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(480, 0)
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var heading := Label.new()
	heading.text = "Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)
	# Tabs: one page shown at a time.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	var audio := _audio_page()
	var video := _video_page()
	for page in [["Audio", audio], ["Video", video]]:
		# Each page scrolls inside a box that fits the window (mouse wheel or drag).
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.custom_minimum_size = Vector2(0, clampf(get_viewport_rect().size.y - 260.0, 200.0, 620.0))
		page[1].size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(page[1])
		var tab := UiStyle.button(page[0], _show_page.bind(scroll), 34)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab)
		_pages.append(scroll)
		column.add_child(scroll)
	_show_page(_pages[0])
	column.add_child(UiStyle.spacer(6))
	column.add_child(UiStyle.button("Back", close))


func _show_page(page: Control) -> void:
	for other in _pages:
		other.visible = other == page


func _section(text: String) -> Label:
	var section := Label.new()
	section.text = text
	section.add_theme_font_size_override("font_size", 18)
	section.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	return section


# --- Audio

func _audio_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	page.add_child(_section("Volume"))
	for bus in GameSettings.BUSES:
		page.add_child(_slider_row(bus[1], 0.0, 1.0, GameSettings.volume(bus[0]), _on_volume.bind(bus[0]), _percent_or_off, bus[0]))
	page.add_child(UiStyle.button("Reset audio", _reset_audio, 34))
	return page


func _on_volume(value: float, bus: StringName) -> void:
	GameSettings.set_volume(bus, value)


func _reset_audio() -> void:
	GameSettings.reset_audio()
	for bus in GameSettings.BUSES:
		_set_slider(bus[0], GameSettings.volume(bus[0]))


# --- Video

func _video_page() -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 8)
	var preset_label := Label.new()
	preset_label.text = "Preset"
	preset_label.custom_minimum_size = Vector2(110, 0)
	presets.add_child(preset_label)
	for preset in VideoSettings.PRESETS:
		var button := UiStyle.button(preset, _on_preset.bind(preset), 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		presets.add_child(button)
		_preset_buttons[preset] = button
	page.add_child(presets)
	_preset_status = Label.new()
	_preset_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	page.add_child(_preset_status)

	page.add_child(_section("Effects"))
	for key in VideoSettings.TOGGLES:
		page.add_child(_toggle(VideoSettings.TOGGLES[key][0], key))

	page.add_child(_section("Quality"))
	page.add_child(_option_row("Shadows", "shadows", VideoSettings.SHADOWS))
	page.add_child(_option_row("Anti-aliasing", "aa", VideoSettings.ANTI_ALIASING))
	page.add_child(_slider_row("Render scale", 0.5, 1.0, VideoSettings.get_value("render_scale"), _on_video.bind("render_scale"), _percent, "render_scale"))

	page.add_child(_section("Display"))
	page.add_child(_toggle("V-Sync", "vsync"))
	var limits: Array = []
	for fps in VideoSettings.FPS_LIMITS:
		limits.append("Unlimited" if fps == 0 else "%d FPS" % fps)
	page.add_child(_option_row("Frame limit", "max_fps", limits, VideoSettings.FPS_LIMITS))
	_refresh_preset()
	return page


func _toggle(text: String, key: String) -> CheckButton:
	var toggle := CheckButton.new()
	toggle.text = text
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.button_pressed = VideoSettings.get_value(key)
	toggle.toggled.connect(_on_video.bind(key))
	_video_controls[key] = toggle
	return toggle


## A dropdown. Without `values`, the stored setting is the item index.
func _option_row(label_text: String, key: String, labels: Array, values: Array = []) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_NONE
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item in labels:
		option.add_item(item)
	option.set_meta(&"values", values)
	_select(option, VideoSettings.get_value(key))
	option.item_selected.connect(func(index: int) -> void: _on_video(values[index] if not values.is_empty() else index, key))
	row.add_child(option)
	_video_controls[key] = option
	return row


func _select(option: OptionButton, value: Variant) -> void:
	var values: Array = option.get_meta(&"values")
	option.selected = maxi(0, values.find(value)) if not values.is_empty() else int(value)


func _on_video(value: Variant, key: String) -> void:
	VideoSettings.set_value(key, value)
	_refresh_preset()


func _on_preset(preset: String) -> void:
	VideoSettings.apply_preset(preset)
	# Show the preset's choices without applying each one again.
	for key in VideoSettings.PRESETS[preset]:
		var control: Control = _video_controls.get(key)
		var value: Variant = VideoSettings.get_value(key)
		if control is CheckButton:
			(control as CheckButton).set_pressed_no_signal(value)
		elif control is OptionButton:
			_select(control as OptionButton, value)
		elif _sliders.has(key):
			_set_slider(key, value)
	_refresh_preset()


func _refresh_preset() -> void:
	var current := VideoSettings.current_preset()
	_preset_status.text = "Current: %s" % current
	for preset in _preset_buttons:
		_preset_buttons[preset].modulate = Color(1, 1, 1) if preset == current else Color(1, 1, 1, 0.6)


# --- Shared

func _slider_row(label_text: String, from: float, to: float, initial: float, on_change: Callable, format: Callable, id: Variant) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = from
	slider.max_value = to
	slider.step = 0.01 if from == 0.0 else 0.05
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# A visible track, filled in the accent blue up to the handle.
	var track := UiStyle.flat(Color(0.22, 0.24, 0.29), 3)
	track.set_content_margin_all(3)
	var fill := UiStyle.flat(Color(0.32, 0.5, 0.78), 3)
	fill.set_content_margin_all(3)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.value = initial
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(56, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	_sliders[id] = slider
	_values[id] = [value, format]
	slider.value_changed.connect(func(new_value: float) -> void:
		on_change.call(new_value)
		_show_value(id))
	_show_value(id)
	return row


func _set_slider(id: Variant, value: float) -> void:
	_sliders[id].set_value_no_signal(value)
	_show_value(id)


func _show_value(id: Variant) -> void:
	var entry: Array = _values[id]
	(entry[0] as Label).text = (entry[1] as Callable).call(_sliders[id].value)


static func _percent_or_off(value: float) -> String:
	return "Off" if value <= 0.001 else "%d%%" % roundi(value * 100.0)


static func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)
