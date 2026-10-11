extends RefCounted
## Shared look for the game's menus (dark panels, rounded buttons).


static func flat(color: Color, radius: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


static func panel_style() -> StyleBoxFlat:
	var style := flat(Color(0.08, 0.09, 0.11, 0.96), 10)
	style.set_content_margin_all(20)
	style.border_color = Color(1, 1, 1, 0.12)
	style.set_border_width_all(1)
	return style


static func button(text: String, action: Callable, height: int = 40) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(0, height)
	result.focus_mode = Control.FOCUS_NONE
	result.add_theme_font_size_override("font_size", 18)
	result.add_theme_stylebox_override("normal", flat(Color(0.2, 0.22, 0.27)))
	result.add_theme_stylebox_override("hover", flat(Color(0.28, 0.32, 0.39)))
	result.add_theme_stylebox_override("pressed", flat(Color(0.32, 0.5, 0.78)))
	result.add_theme_color_override("font_color", Color(0.95, 0.95, 0.97))
	result.add_theme_color_override("font_hover_color", Color.WHITE)
	result.pressed.connect(action)
	return result


static func spacer(height: int) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	return gap
