extends Control
## Title screen: pick a level or quit. Levels are listed in the Inspector, so new
## environments can be added without touching code.

const UiStyle := preload("res://ui/ui_style.gd")

@export var title: String = "Physics Sandbox"
@export var subtitle: String = "Grab it. Throw it. Break it. Build it."
## Level buttons, shown in order. Names and scene paths are paired by index.
@export var level_names: PackedStringArray = ["Playground", "House"]
@export var level_paths: PackedStringArray = [
	"res://playground/physics_playground.tscn",
	"res://house/house.tscn",
]


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color(0.07, 0.08, 0.1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(340, 0)
	column.add_theme_constant_override("separation", 12)
	centre.add_child(column)

	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	column.add_child(heading)
	var tagline := Label.new()
	tagline.text = subtitle
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	column.add_child(tagline)
	column.add_child(UiStyle.spacer(18))

	for index in mini(level_names.size(), level_paths.size()):
		column.add_child(UiStyle.button(level_names[index], _open_level.bind(level_paths[index]), 46))
	column.add_child(UiStyle.spacer(6))
	column.add_child(UiStyle.button("Quit", get_tree().quit, 40))


func _open_level(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("Main menu: level not found: %s" % path)
		return
	get_tree().change_scene_to_file(path)
