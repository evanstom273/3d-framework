@tool
class_name KitLight
extends KitPiece
## A light fitting: ceiling pendant, flush dome, wall light or outdoor lantern.
## Ceiling lights hang from the origin (put it on the ceiling); wall lights mount
## on the wall at the origin and face +Z. Lights sharing a `circuit` name are
## switched together by a KitSwitch with the same name.

enum Style { PENDANT, FLUSH_DOME, WALL_LIGHT, LANTERN }

@export var style: Style = Style.PENDANT:
	set(value):
		style = value
		queue_rebuild()
## KitSwitches with the same circuit name turn this on and off.
@export var circuit: String = "":
	set(value):
		if is_inside_tree() and not circuit.is_empty():
			remove_from_group(circuit_group(circuit))
		circuit = value
		if is_inside_tree() and not circuit.is_empty():
			add_to_group(circuit_group(circuit))
@export var on: bool = true:
	set(value):
		on = value
		_apply_state()
## Pendant cord length.
@export_range(0.1, 2.0, 0.05, "suffix:m") var drop: float = 0.5:
	set(value):
		drop = value
		queue_rebuild()
@export var light_color: Color = Color(1.0, 0.85, 0.66):
	set(value):
		light_color = value
		queue_rebuild()
@export_range(0.0, 8.0, 0.05) var energy: float = 1.4:
	set(value):
		energy = value
		_apply_state()
@export_range(1.0, 30.0, 0.5, "suffix:m") var light_range: float = 7.0:
	set(value):
		light_range = value
		queue_rebuild()
@export var shadows: bool = true:
	set(value):
		shadows = value
		queue_rebuild()
@export var shade_color: Color = Color(0.9, 0.86, 0.76):
	set(value):
		shade_color = value
		queue_rebuild()

var _omni: OmniLight3D
var _glow: StandardMaterial3D


static func circuit_group(name: String) -> StringName:
	return StringName("kit_circuit_" + name)


func _enter_tree() -> void:
	add_to_group(&"kit_lights")
	if not circuit.is_empty():
		add_to_group(circuit_group(circuit))


func toggle() -> void:
	on = not on


func _build(b: KitBuilder) -> void:
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(1.0, 0.97, 0.9)
	_glow.emission_enabled = true
	_glow.emission = light_color
	_glow.roughness = 0.3
	var bulb_at := Vector3.ZERO
	var white := KitMaterials.gloss(Color(0.95, 0.95, 0.93))
	var brass := KitMaterials.metal(Color(0.72, 0.58, 0.32), 0.8)
	var black := KitMaterials.metal(Color(0.05, 0.05, 0.05), 0.4)
	var shade := StandardMaterial3D.new()
	shade.albedo_color = shade_color
	shade.roughness = 0.9
	shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Light glows through the fabric when lit.
	shade.backlight_enabled = true
	shade.backlight = shade_color * 0.6
	match style:
		Style.PENDANT:
			b.lathe(PackedVector2Array([Vector2(0.0, -0.03), Vector2(0.05, -0.03), Vector2(0.06, -0.012), Vector2(0.06, 0.0), Vector2(0.0, 0.0)]), Vector3.ZERO, 16, white)
			b.lathe(PackedVector2Array([Vector2(0.0, -drop), Vector2(0.003, -drop), Vector2(0.003, -0.03), Vector2(0.0, -0.03)]), Vector3.ZERO, 6, black)
			b.lathe(PackedVector2Array([Vector2(0.0, -drop - 0.05), Vector2(0.016, -drop - 0.05), Vector2(0.016, -drop), Vector2(0.0, -drop)]), Vector3.ZERO, 10, brass)
			# A drum shade with a slight taper, open top and bottom.
			b.lathe(PackedVector2Array([Vector2(0.19, -drop - 0.22), Vector2(0.15, -drop + 0.0)]), Vector3.ZERO, 28, shade)
			bulb_at = Vector3(0, -drop - 0.09, 0)
			b.lathe(_bulb_profile(0.035), bulb_at - Vector3(0, 0.035, 0), 12, _glow)
		Style.FLUSH_DOME:
			b.lathe(PackedVector2Array([Vector2(0.0, -0.02), Vector2(0.17, -0.02), Vector2(0.17, 0.0), Vector2(0.0, 0.0)]), Vector3.ZERO, 24, white)
			var dome := PackedVector2Array()
			for i in 9:
				var angle := PI * 0.5 * i / 8.0
				dome.append(Vector2(cos(angle) * 0.15, -0.02 - sin(angle) * 0.09))
			dome.reverse()
			b.lathe(dome, Vector3.ZERO, 24, _glow)
			bulb_at = Vector3(0, -0.06, 0)
		Style.WALL_LIGHT:
			b.box(Vector3(-0.05, -0.08, 0.0), Vector3(0.05, 0.08, 0.015), brass, false)
			b.extrude(KitPiece.arc(Vector2.ZERO, 0.008, 0.0, TAU * 7.0 / 8.0, 7), Vector3(0, 0, 0.015), Vector3(0, 0.0, 0.15), Vector3.UP, brass, false, true)
			b.lathe(PackedVector2Array([Vector2(0.06, 0.0), Vector2(0.11, 0.16)]), Vector3(0, -0.02, 0.17), 20, shade)
			bulb_at = Vector3(0, 0.04, 0.17)
			b.lathe(_bulb_profile(0.03), bulb_at - Vector3(0, 0.03, 0), 12, _glow)
		Style.LANTERN:
			# Coach lantern on a bracket: black frame, glowing panes.
			b.box(Vector3(-0.04, 0.05, 0.0), Vector3(0.04, 0.2, 0.012), black, false)
			b.box(Vector3(-0.012, 0.12, 0.012), Vector3(0.012, 0.135, 0.17), black, false)
			var c := Vector3(0, 0.0, 0.17)
			b.box(c + Vector3(-0.08, -0.16, -0.08), c + Vector3(0.08, -0.14, 0.08), black, false)
			b.box(c + Vector3(-0.09, 0.1, -0.09), c + Vector3(0.09, 0.12, 0.09), black, false)
			b.lathe(PackedVector2Array([Vector2(0.0, 0.2), Vector2(0.1, 0.12), Vector2(0.0, 0.12)]), c, 4, black)
			for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p := c + Vector3(corner.x * 0.072, 0, corner.y * 0.072)
				b.box(p + Vector3(-0.008, -0.14, -0.008), p + Vector3(0.008, 0.1, 0.008), black, false)
			b.box(c + Vector3(-0.07, -0.14, -0.07), c + Vector3(0.07, 0.1, 0.07), _glow, false)
			bulb_at = c
	_omni = OmniLight3D.new()
	_omni.position = bulb_at
	_omni.light_color = light_color
	_omni.omni_range = light_range
	_omni.shadow_enabled = shadows
	_omni.omni_attenuation = 1.2
	add_generated(_omni)
	_apply_state()


func _apply_state() -> void:
	if is_instance_valid(_omni):
		_omni.light_energy = energy if on else 0.0
		_omni.visible = on
	if _glow != null:
		_glow.emission_energy_multiplier = 2.5 if on else 0.0
		_glow.albedo_color = Color(1.0, 0.97, 0.9) if on else Color(0.75, 0.74, 0.72)


static func _bulb_profile(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 9:
		var angle := -PI * 0.5 + PI * i / 8.0
		points.append(Vector2(cos(angle) * radius, radius + sin(angle) * radius))
	return points
