extends SceneTree
## Authors the advanced tools (and pulley, plunger, nail) as ordinary data: one
## PhysicsObjectDefinition per tool with its own parts, grip, nozzle, hold and use
## poses, and a ToolActionDefinition describing how it behaves and feels.
## Model coordinates put the hand grip at the origin with -Z pointing forward.
## Voxel models come afterwards from:
##   godot --headless --path . -s res://tools/generate_prop_vox.gd -- new
## Run: godot --headless --path . -s res://tools/generate_advanced_tools.gd
## Rewrites only the files listed here, keeping their uids so scenes still find them.

const TOOLS_DIR := "res://props/tools/advanced/"
const CONFIG := "res://contraptions/config/"
const STEEL_PROFILE := "res://contraptions/materials/profiles/steel.tres"

const BOX := PhysicsShapePart.ShapeType.BOX
const SPHERE := PhysicsShapePart.ShapeType.SPHERE
const CYL := PhysicsShapePart.ShapeType.CYLINDER
const ALONG_Z := Vector3(90, 0, 0)
const ALONG_X := Vector3(0, 0, 90)

const FX := ToolActionDefinition.Effect
const LOOP := ToolActionDefinition.LoopSound
const SHOT := ToolActionDefinition.ShotSound

const BLACK := Color(0.07, 0.07, 0.08)
const DARK := Color(0.18, 0.19, 0.21)
const STEEL := Color(0.62, 0.64, 0.67)
const BRASS := Color(0.8, 0.62, 0.26)
const COPPER := Color(0.78, 0.45, 0.25)
const WOOD := Color(0.62, 0.43, 0.24)
const RUBBER_RED := Color(0.72, 0.13, 0.1)

## Standard pistol hold and squeeze.
const PISTOL_REST := [Vector3(0.2, -0.24, -0.36), Vector3.ZERO]
const PISTOL_USE := [Vector3(0.17, -0.21, -0.42), Vector3(-3, 0, 0)]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TOOLS_DIR))
	for spec in _tool_specs():
		_save_tool(spec)
	_save_components()
	_save_pry()
	print("Advanced tools authored. Now run generate_prop_vox.gd -- new")
	quit()


# --- Builders

func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _box(size: Vector3, position: Vector3, color: Color, rotation := Vector3.ZERO, collides := true, metallic := 0.0) -> PhysicsShapePart:
	return _part(BOX, size, position, color, rotation, collides, metallic)


func _cyl(radius: float, height: float, position: Vector3, color: Color, rotation := Vector3.ZERO, collides := true, metallic := 0.0) -> PhysicsShapePart:
	return _part(CYL, Vector3(radius, height, 0), position, color, rotation, collides, metallic)


func _ball(radius: float, position: Vector3, color: Color, collides := true, metallic := 0.0) -> PhysicsShapePart:
	return _part(SPHERE, Vector3(radius, 0, 0), position, color, Vector3.ZERO, collides, metallic)


func _part(type: int, dims: Vector3, position: Vector3, color: Color, rotation: Vector3, collides: bool, metallic: float) -> PhysicsShapePart:
	var part := PhysicsShapePart.new()
	part.shape_type = type
	if type == BOX:
		part.size = dims
	else:
		part.radius = dims.x
		part.height = dims.y
	part.position = position
	part.rotation_degrees = rotation
	part.material = _mat(color, metallic, 0.35 if metallic > 0.3 else 0.75)
	part.collides = collides
	return part


## Pistol grip, tilted back a little, with its trigger.
func _grip(color: Color) -> Array:
	return [
		_box(Vector3(0.034, 0.11, 0.045), Vector3(0, -0.02, 0.005), color, Vector3(-14, 0, 0)),
		_box(Vector3(0.012, 0.035, 0.016), Vector3(0, 0.0, -0.035), BLACK, Vector3.ZERO, false),
	]


func _save_tool(spec: Dictionary) -> void:
	var definition := PhysicsObjectDefinition.new()
	definition.display_name = spec["name"]
	definition.shape_type = PhysicsObjectDefinition.ShapeType.COMPOUND
	var parts: Array[PhysicsShapePart] = []
	parts.assign(spec["parts"])
	definition.parts = parts
	definition.mass = spec["mass"]
	definition.friction = 0.7
	definition.bounce = 0.05
	definition.angular_damp = 0.25
	definition.impact_sound = spec.get("sound", ImpactFeedback.Sound.METAL)
	definition.tool_profile = load(STEEL_PROFILE)
	definition.material = _mat(Color.WHITE, spec.get("shine", 0.25), 0.5)

	var tool := PhysicsToolDefinition.new()
	tool.category = PhysicsToolDefinition.Category.UTILITY
	tool.action_name = spec["action"].get("verb", "Use")
	tool.motion_strikes = false
	tool.charge_time = 0.0
	tool.equip_time = 0.3
	tool.pitch_follow = 1.0
	var rest: Array = spec.get("rest", PISTOL_REST)
	var use: Array = spec.get("use", PISTOL_USE)
	tool.rest_position = rest[0]
	tool.rest_rotation_degrees = rest[1]
	tool.windup_position = rest[0]
	tool.windup_rotation_degrees = rest[1]
	tool.strike_position = use[0]
	tool.strike_rotation_degrees = use[1]

	var action := ToolActionDefinition.new()
	action.operation = spec["op"]
	action.nozzle = spec["nozzle"]
	action.moving_part_position = spec.get("moving", spec["nozzle"])
	for key in spec["action"]:
		action.set(key, spec["action"][key])
	var connection_path: String = CONFIG + ("suction" if spec["op"] == "plunger" else spec["op"]) + ".tres"
	if ResourceLoader.exists(connection_path):
		action.connection = load(connection_path)
	tool.advanced_action = action
	definition.tool = tool

	if spec.has("container"):
		definition.container = spec["container"]
		definition.equipped_collision_parts = spec["scoop_parts"]
	_save(definition, TOOLS_DIR + spec["key"] + ".tres")


# --- The tools

func _tool_specs() -> Array:
	var specs := []

	# Blowtorch: hand on the blue gas canister, brass burner and nozzle on top.
	var blue := Color(0.15, 0.32, 0.78)
	specs.append({"key": "blowtorch", "name": "Blowtorch", "mass": 1.0, "op": "heat",
		"parts": [
			_cyl(0.034, 0.17, Vector3(0, -0.02, 0), blue),
			_cyl(0.035, 0.02, Vector3(0, -0.04, 0), Color(0.9, 0.9, 0.9), Vector3.ZERO, false),
			_cyl(0.028, 0.025, Vector3(0, 0.075, 0), STEEL, Vector3.ZERO, true, 0.8),
			_cyl(0.016, 0.1, Vector3(0, 0.1, -0.04), BRASS, ALONG_Z, true, 0.8),
			_cyl(0.014, 0.02, Vector3(0.028, 0.1, -0.01), BLACK, ALONG_X, false),
			_cyl(0.011, 0.11, Vector3(0, 0.1, -0.14), STEEL, ALONG_Z, true, 0.9),
			_cyl(0.014, 0.025, Vector3(0, 0.1, -0.2), DARK, ALONG_Z, false, 0.6),
		],
		"nozzle": Vector3(0, 0.1, -0.215),
		"rest": [Vector3(0.22, -0.3, -0.42), Vector3.ZERO], "use": [Vector3(0.18, -0.26, -0.5), Vector3(-4, 0, 0)],
		"action": {"verb": "Torch", "primary_hint": "[Hold LMB] Burn / scorch", "secondary_hint": "",
			"range_metres": 1.1, "rate": 14.0, "region_size": Vector3(0.16, 0.16, 0.14),
			"effect": FX.FLAME, "contact_effect": FX.SMOKE, "effect_color": Color(0.55, 0.7, 1.0),
			"loop_sound": LOOP.ROAR, "sound_pitch": 1.7, "sound_volume_db": -10.0,
			"use_shake": 0.0012, "light_color": Color(1.0, 0.6, 0.3)}})

	# Chainsaw: rear handle at the hand, orange engine, wrap handle, long bar.
	var orange := Color(0.95, 0.45, 0.08)
	specs.append({"key": "chainsaw", "name": "Chainsaw", "mass": 5.2, "op": "saw",
		"parts": [
			_box(Vector3(0.035, 0.035, 0.15), Vector3(0, 0, 0.03), BLACK),
			_box(Vector3(0.14, 0.17, 0.27), Vector3(0, 0.03, -0.17), orange),
			_box(Vector3(0.12, 0.035, 0.2), Vector3(0, 0.13, -0.16), DARK, Vector3.ZERO, false),
			_box(Vector3(0.05, 0.05, 0.06), Vector3(0.09, 0.0, -0.1), DARK, Vector3.ZERO, false),
			_box(Vector3(0.2, 0.028, 0.028), Vector3(0, 0.15, -0.3), BLACK),
			_box(Vector3(0.028, 0.15, 0.028), Vector3(0.1, 0.08, -0.3), BLACK),
			_box(Vector3(0.018, 0.07, 0.52), Vector3(0, -0.01, -0.56), STEEL, Vector3.ZERO, true, 0.8),
			_box(Vector3(0.024, 0.012, 0.5), Vector3(0, 0.03, -0.56), DARK, Vector3.ZERO, false, 0.6),
			_box(Vector3(0.024, 0.012, 0.5), Vector3(0, -0.05, -0.56), DARK, Vector3.ZERO, false, 0.6),
			_cyl(0.035, 0.02, Vector3(0, -0.01, -0.82), STEEL, ALONG_X, false, 0.8),
		],
		"nozzle": Vector3(0, -0.01, -0.6), "moving": Vector3(0, -0.01, -0.56),
		"rest": [Vector3(0.2, -0.38, -0.14), Vector3(-8, 0, 0)], "use": [Vector3(0.16, -0.33, -0.22), Vector3(-14, 0, 0)],
		"action": {"verb": "Cut", "primary_hint": "[Hold LMB] Cut", "secondary_hint": "",
			"range_metres": 1.7, "rate": 30.0, "force": 60.0, "region_size": Vector3(0.05, 0.14, 0.44),
			"effect": FX.SMOKE, "contact_effect": FX.SAWDUST, "effect_color": Color(0.35, 0.33, 0.3),
			"loop_sound": LOOP.MOTOR, "sound_pitch": 1.25, "sound_volume_db": -6.0, "idles": true,
			"use_shake": 0.004}})

	# Angle grinder: grip around the motor body, head with a flat disc and guard.
	var teal := Color(0.1, 0.5, 0.55)
	specs.append({"key": "angle_grinder", "name": "Angle Grinder", "mass": 2.4, "op": "grind",
		"parts": [
			_cyl(0.034, 0.26, Vector3(0, 0, -0.08), teal, ALONG_Z),
			_cyl(0.026, 0.05, Vector3(0, 0, 0.07), BLACK, ALONG_Z),
			_box(Vector3(0.07, 0.06, 0.07), Vector3(0, 0.005, -0.24), DARK, Vector3.ZERO, true, 0.5),
			_box(Vector3(0.14, 0.012, 0.07), Vector3(0, -0.025, -0.22), DARK, Vector3.ZERO, false, 0.5),
			_cyl(0.065, 0.006, Vector3(0, -0.038, -0.27), STEEL, Vector3.ZERO, true, 0.7),
			_cyl(0.014, 0.12, Vector3(0.08, 0.005, -0.24), BLACK, ALONG_X),
		],
		"nozzle": Vector3(0, -0.038, -0.27), "moving": Vector3(0, -0.042, -0.27),
		"rest": [Vector3(0.2, -0.3, -0.34), Vector3.ZERO], "use": [Vector3(0.16, -0.27, -0.42), Vector3(-10, 0, 0)],
		"action": {"verb": "Grind", "primary_hint": "[Hold LMB] Grind (cuts fasteners too)", "secondary_hint": "",
			"range_metres": 1.5, "rate": 26.0, "force": 40.0, "region_size": Vector3(0.12, 0.03, 0.12),
			"effect": FX.NONE, "contact_effect": FX.SPARKS,
			"loop_sound": LOOP.WHINE, "sound_pitch": 1.15, "sound_volume_db": -8.0, "idles": true,
			"use_shake": 0.0025}})

	# Pressure washer gun: pistol grip, yellow body, long lance, hose underneath.
	var yellow := Color(0.95, 0.8, 0.15)
	specs.append({"key": "pressure_washer", "name": "Pressure Washer", "mass": 2.2, "op": "wash",
		"parts": _grip(BLACK) + [
			_box(Vector3(0.05, 0.06, 0.13), Vector3(0, 0.065, -0.03), yellow),
			_cyl(0.011, 0.7, Vector3(0, 0.07, -0.44), STEEL, ALONG_Z, true, 0.9),
			_cyl(0.017, 0.045, Vector3(0, 0.07, -0.8), BLACK, ALONG_Z),
			_cyl(0.012, 0.08, Vector3(0, -0.08, 0.03), BLACK),
		],
		"nozzle": Vector3(0, 0.07, -0.83),
		"rest": [Vector3(0.2, -0.28, -0.28), Vector3.ZERO], "use": [Vector3(0.18, -0.26, -0.32), Vector3(-2, 0, 0)],
		"action": {"verb": "Wash", "primary_hint": "[Hold LMB] Spray (washes paint and scorch off)", "secondary_hint": "",
			"range_metres": 6.0, "cone_degrees": 9.0, "force": 140.0, "rate": 2.5,
			"effect": FX.WATER, "contact_effect": FX.MIST,
			"loop_sound": LOOP.SPRAY, "sound_volume_db": -8.0, "use_shake": 0.001}})

	# Glue gun: blue-grey body, brass nozzle, glue stick out of the back.
	var slate := Color(0.22, 0.32, 0.45)
	specs.append({"key": "glue_gun", "name": "Glue Gun", "mass": 0.5, "op": "glue", "sound": ImpactFeedback.Sound.PLASTIC,
		"parts": _grip(slate) + [
			_box(Vector3(0.04, 0.075, 0.17), Vector3(0, 0.065, -0.04), slate),
			_cyl(0.009, 0.05, Vector3(0, 0.055, -0.15), BRASS, ALONG_Z, true, 0.8),
			_cyl(0.007, 0.09, Vector3(0, 0.08, 0.08), Color(0.92, 0.9, 0.78), ALONG_Z, false),
		],
		"nozzle": Vector3(0, 0.055, -0.18),
		"action": {"verb": "Glue", "primary_hint": "[LMB] Apply glue patch", "secondary_hint": "[RMB] Clear patch",
			"range_metres": 2.5, "effect_color": Color(0.95, 0.92, 0.8), "shot_sound": SHOT.CLICK, "shot_kick": 0.2}})

	# Welding torch (MIG gun): black handle, copper neck and nozzle, cable behind.
	specs.append({"key": "welding_torch", "name": "Welding Torch", "mass": 1.4, "op": "weld",
		"parts": [
			_cyl(0.02, 0.14, Vector3(0, -0.01, 0.0), BLACK, Vector3(-20, 0, 0)),
			_box(Vector3(0.012, 0.03, 0.016), Vector3(0, -0.01, -0.03), RUBBER_RED, Vector3.ZERO, false),
			_cyl(0.012, 0.15, Vector3(0, 0.04, -0.1), COPPER, Vector3(70, 0, 0), true, 0.8),
			_cyl(0.017, 0.05, Vector3(0, 0.015, -0.19), COPPER, Vector3(70, 0, 0), true, 0.8),
			_cyl(0.012, 0.12, Vector3(0, -0.09, 0.05), BLACK, Vector3(-30, 0, 0), false),
		],
		"nozzle": Vector3(0, 0.005, -0.215),
		"action": {"verb": "Weld", "primary_hint": "[LMB] Pick two touching metal surfaces", "secondary_hint": "[RMB] Cancel / remove",
			"range_metres": 2.5, "effect_color": Color(0.7, 0.85, 1.0), "shot_sound": SHOT.ZAP, "shot_kick": 0.2,
			"light_color": Color(0.6, 0.8, 1.0)}})

	# Nail gun: chunky red body, angled magazine, nose, air fitting.
	var red := Color(0.78, 0.14, 0.1)
	specs.append({"key": "nail_gun", "name": "Nail Gun", "mass": 3.1, "op": "nail",
		"parts": _grip(BLACK) + [
			_box(Vector3(0.06, 0.13, 0.19), Vector3(0, 0.08, -0.06), red),
			_box(Vector3(0.03, 0.04, 0.27), Vector3(0, -0.03, -0.12), STEEL, Vector3(-18, 0, 0), true, 0.8),
			_box(Vector3(0.036, 0.11, 0.036), Vector3(0, 0.03, -0.17), DARK),
			_cyl(0.008, 0.03, Vector3(0, -0.08, 0.04), BRASS, ALONG_Z, false, 0.8),
		],
		"nozzle": Vector3(0, -0.02, -0.2),
		"action": {"verb": "Nail", "primary_hint": "[LMB] Fire nail (fastens to what's behind)", "secondary_hint": "",
			"range_metres": 30.0, "projectile_speed": 40.0, "probe_depth": 0.2,
			"shot_sound": SHOT.THUNK, "shot_kick": 0.7, "sound_volume_db": -4.0}})

	# Power drill: green body, black grip, battery pack, chuck and bit.
	var green := Color(0.2, 0.55, 0.25)
	specs.append({"key": "power_drill", "name": "Power Drill", "mass": 1.8, "op": "screw", "sound": ImpactFeedback.Sound.PLASTIC,
		"parts": _grip(BLACK) + [
			_box(Vector3(0.05, 0.07, 0.17), Vector3(0, 0.07, -0.03), green),
			_box(Vector3(0.07, 0.045, 0.09), Vector3(0, -0.09, 0.02), DARK),
			_cyl(0.018, 0.04, Vector3(0, 0.07, -0.135), BLACK, ALONG_Z),
			_cyl(0.004, 0.07, Vector3(0, 0.07, -0.19), STEEL, ALONG_Z, false, 0.9),
		],
		"nozzle": Vector3(0, 0.07, -0.225), "moving": Vector3(0, 0.07, -0.19),
		"action": {"verb": "Drill", "primary_hint": "[Hold LMB] Drive screw", "secondary_hint": "[RMB] Back out screw",
			"range_metres": 2.5, "dwell_seconds": 0.7, "effect": FX.NONE, "contact_effect": FX.DUST,
			"loop_sound": LOOP.MOTOR, "sound_pitch": 2.7, "sound_volume_db": -10.0, "use_shake": 0.0015}})

	# Staple gun: steel body, red squeeze lever on top.
	specs.append({"key": "staple_gun", "name": "Staple Gun", "mass": 0.8, "op": "staple",
		"parts": [
			_box(Vector3(0.035, 0.055, 0.17), Vector3(0, 0.0, -0.03), STEEL, Vector3.ZERO, true, 0.7),
			_box(Vector3(0.03, 0.022, 0.16), Vector3(0, 0.05, 0.0), RUBBER_RED, Vector3(8, 0, 0)),
			_box(Vector3(0.036, 0.035, 0.024), Vector3(0, -0.02, -0.11), DARK),
		],
		"nozzle": Vector3(0, -0.03, -0.125),
		"rest": [Vector3(0.2, -0.22, -0.36), Vector3.ZERO],
		"action": {"verb": "Staple", "primary_hint": "[LMB] Staple (wood and soft materials)", "secondary_hint": "",
			"range_metres": 2.2, "probe_depth": 0.09, "shot_sound": SHOT.CLICK, "shot_kick": 0.35}})

	# Caulking gun: skeleton frame, white cartridge, pointed nozzle, red trigger.
	specs.append({"key": "caulking_gun", "name": "Caulking Gun", "mass": 1.2, "op": "sealant",
		"parts": [
			_box(Vector3(0.03, 0.11, 0.04), Vector3(0, -0.02, 0.03), BLACK, Vector3(-10, 0, 0)),
			_box(Vector3(0.018, 0.1, 0.02), Vector3(0, -0.02, -0.015), RUBBER_RED, Vector3(10, 0, 0), false),
			_cyl(0.006, 0.32, Vector3(0, 0.035, -0.1), STEEL, ALONG_Z, true, 0.9),
			_cyl(0.026, 0.22, Vector3(0, 0.065, -0.15), Color(0.93, 0.92, 0.88), ALONG_Z),
			_cyl(0.009, 0.06, Vector3(0, 0.065, -0.29), Color(0.93, 0.92, 0.88), ALONG_Z),
			_box(Vector3(0.06, 0.06, 0.012), Vector3(0, 0.05, -0.27), STEEL, Vector3.ZERO, false, 0.8),
		],
		"nozzle": Vector3(0, 0.065, -0.325),
		"action": {"verb": "Seal", "primary_hint": "[LMB] Apply sealant (flexible bond)", "secondary_hint": "[RMB] Clear",
			"range_metres": 2.5, "effect_color": Color(0.93, 0.92, 0.88), "shot_sound": SHOT.CLICK, "shot_kick": 0.15}})

	# Rope, chain and cable reels: drum between coloured flanges, guide eyelet.
	for reel in [["rope_tool", "Rope Tool", "rope", Color(0.62, 0.46, 0.26), Color(0.2, 0.45, 0.25), 2.0, "Rope"],
			["chain_tool", "Chain Tool", "chain", STEEL, Color(0.9, 0.72, 0.1), 4.0, "Chain"],
			["cable_tool", "Cable Tool", "cable", DARK, Color(0.75, 0.15, 0.12), 2.8, "Cable"]]:
		specs.append({"key": reel[0], "name": reel[1], "mass": reel[5], "op": reel[2],
			"parts": _grip(BLACK) + [
				_cyl(0.055, 0.08, Vector3(0, 0.07, -0.08), reel[3], ALONG_X, true, 0.6 if reel[2] != "rope" else 0.0),
				_cyl(0.075, 0.012, Vector3(-0.046, 0.07, -0.08), reel[4], ALONG_X),
				_cyl(0.075, 0.012, Vector3(0.046, 0.07, -0.08), reel[4], ALONG_X),
				_box(Vector3(0.02, 0.025, 0.08), Vector3(0, 0.07, -0.17), DARK),
				_cyl(0.014, 0.02, Vector3(0, 0.07, -0.215), STEEL, ALONG_Z, false, 0.8),
			],
			"nozzle": Vector3(0, 0.07, -0.225),
			"action": {"verb": reel[6], "range_metres": 6.0, "rest_length": 2.0, "shot_sound": SHOT.CLICK, "shot_kick": 0.15}})

	# Spring tool: a steel coil on the front of a green body.
	var spring_parts: Array = _grip(green) + [_box(Vector3(0.04, 0.05, 0.09), Vector3(0, 0.06, -0.02), green)]
	for i in 9:
		spring_parts.append(_cyl(0.03, 0.006, Vector3(0, 0.065, -0.09 - i * 0.014), STEEL, ALONG_Z, i == 0, 0.9))
	specs.append({"key": "spring_tool", "name": "Spring Tool", "mass": 1.2, "op": "spring",
		"parts": spring_parts, "nozzle": Vector3(0, 0.065, -0.22),
		"action": {"verb": "Spring", "range_metres": 6.0, "rest_length": 1.0, "shot_sound": SHOT.CLICK, "shot_kick": 0.15}})

	# Elastic band tool: a slingshot fork with a red band across it.
	specs.append({"key": "elastic_band_tool", "name": "Elastic Band Tool", "mass": 0.5, "op": "elastic", "sound": ImpactFeedback.Sound.WOOD,
		"parts": [
			_box(Vector3(0.03, 0.11, 0.035), Vector3(0, -0.02, 0), WOOD, Vector3(-10, 0, 0)),
			_box(Vector3(0.025, 0.09, 0.025), Vector3(-0.035, 0.07, -0.02), WOOD, Vector3(0, 0, 18)),
			_box(Vector3(0.025, 0.09, 0.025), Vector3(0.035, 0.07, -0.02), WOOD, Vector3(0, 0, -18)),
			_box(Vector3(0.11, 0.012, 0.008), Vector3(0, 0.11, -0.02), RUBBER_RED, Vector3.ZERO, false),
		],
		"nozzle": Vector3(0, 0.11, -0.03),
		"action": {"verb": "Elastic", "range_metres": 6.0, "rest_length": 1.0, "shot_sound": SHOT.CLICK, "shot_kick": 0.15}})

	# Hinge tool: grip with a big brass hinge (two leaves and a knuckle) in front.
	specs.append({"key": "hinge_tool", "name": "Hinge Tool", "mass": 1.0, "op": "hinge",
		"parts": _grip(DARK) + [
			_box(Vector3(0.035, 0.05, 0.08), Vector3(0, 0.06, -0.03), DARK),
			_box(Vector3(0.07, 0.11, 0.006), Vector3(-0.036, 0.07, -0.1), BRASS, Vector3(0, 20, 0), true, 0.8),
			_box(Vector3(0.07, 0.11, 0.006), Vector3(0.036, 0.07, -0.1), BRASS, Vector3(0, -20, 0), true, 0.8),
			_cyl(0.01, 0.12, Vector3(0, 0.07, -0.088), STEEL, Vector3.ZERO, false, 0.9),
		],
		"nozzle": Vector3(0, 0.07, -0.12),
		"action": {"verb": "Hinge", "range_metres": 4.0, "shot_sound": SHOT.CLICK, "shot_kick": 0.15}})

	# Fire extinguisher: hand on the top lever, red cylinder below, hose and horn.
	var fire_red := Color(0.8, 0.08, 0.06)
	specs.append({"key": "fire_extinguisher", "name": "Fire Extinguisher", "mass": 6.0, "op": "extinguish",
		"parts": [
			_box(Vector3(0.03, 0.015, 0.13), Vector3(0, 0.01, 0.02), BLACK),
			_box(Vector3(0.035, 0.05, 0.035), Vector3(0, -0.025, 0), DARK, Vector3.ZERO, true, 0.6),
			_cyl(0.07, 0.38, Vector3(0, -0.24, 0), fire_red),
			_cyl(0.071, 0.09, Vector3(0, -0.26, 0), Color(0.95, 0.95, 0.92), Vector3.ZERO, false),
			_cyl(0.012, 0.008, Vector3(0.03, -0.03, -0.02), Color(0.95, 0.95, 0.95), ALONG_Z, false),
			_cyl(0.01, 0.3, Vector3(0.06, -0.03, -0.15), BLACK, ALONG_Z, false),
			_cyl(0.024, 0.1, Vector3(0.06, -0.03, -0.33), BLACK, ALONG_Z),
		],
		"nozzle": Vector3(0.06, -0.03, -0.39),
		"rest": [Vector3(0.24, -0.34, -0.4), Vector3.ZERO], "use": [Vector3(0.2, -0.3, -0.46), Vector3(-4, 0, 0)],
		"action": {"verb": "Spray", "primary_hint": "[Hold LMB] Spray (cools and pushes light things)", "secondary_hint": "",
			"range_metres": 4.5, "cone_degrees": 18.0, "force": 70.0, "rate": 3.0,
			"effect": FX.MIST, "contact_effect": FX.MIST,
			"loop_sound": LOOP.HISS, "sound_pitch": 0.9, "sound_volume_db": -6.0, "use_shake": 0.002}})

	# Leaf blower: top handle at the hand, engine and fan housing, long tube.
	var blower_red := Color(0.85, 0.25, 0.1)
	specs.append({"key": "leaf_blower", "name": "Leaf Blower", "mass": 4.5, "op": "blow",
		"parts": [
			_box(Vector3(0.03, 0.03, 0.18), Vector3(0, 0, 0.02), BLACK),
			_box(Vector3(0.15, 0.17, 0.2), Vector3(0, -0.11, 0.04), blower_red),
			_cyl(0.1, 0.09, Vector3(0.1, -0.14, 0.03), DARK, ALONG_X),
			_cyl(0.04, 0.55, Vector3(0, -0.16, -0.3), blower_red, Vector3(80, 0, 0)),
			_cyl(0.045, 0.04, Vector3(0, -0.205, -0.58), BLACK, Vector3(80, 0, 0)),
		],
		"nozzle": Vector3(0, -0.21, -0.61),
		"rest": [Vector3(0.24, -0.3, -0.2), Vector3.ZERO], "use": [Vector3(0.21, -0.27, -0.26), Vector3(-5, 0, 0)],
		"action": {"verb": "Blow", "primary_hint": "[Hold LMB] Blow", "secondary_hint": "",
			"range_metres": 6.0, "cone_degrees": 14.0, "force": 260.0,
			"effect": FX.AIR, "loop_sound": LOOP.ROAR, "sound_pitch": 0.9, "sound_volume_db": -6.0, "idles": true,
			"use_shake": 0.003}})

	# Vacuum: purple motor body with handle, clear bin, tube and nozzle.
	var purple := Color(0.45, 0.22, 0.65)
	specs.append({"key": "vacuum_cleaner", "name": "Vacuum Cleaner", "mass": 3.0, "op": "vacuum", "sound": ImpactFeedback.Sound.PLASTIC,
		"parts": [
			_box(Vector3(0.03, 0.03, 0.14), Vector3(0, 0, 0.03), BLACK),
			_box(Vector3(0.09, 0.11, 0.16), Vector3(0, -0.08, 0.05), purple),
			_cyl(0.045, 0.14, Vector3(0, -0.11, -0.09), Color(0.75, 0.8, 0.85), ALONG_Z),
			_cyl(0.022, 0.42, Vector3(0, -0.13, -0.36), STEEL, Vector3(85, 0, 0), true, 0.8),
			_cyl(0.03, 0.05, Vector3(0, -0.15, -0.6), BLACK, Vector3(85, 0, 0)),
		],
		"nozzle": Vector3(0, -0.153, -0.63),
		"rest": [Vector3(0.22, -0.32, -0.22), Vector3.ZERO], "use": [Vector3(0.19, -0.29, -0.28), Vector3(-5, 0, 0)],
		"action": {"verb": "Vacuum", "primary_hint": "[Hold LMB] Suck up loose things", "secondary_hint": "[RMB] Empty",
			"range_metres": 4.0, "cone_degrees": 16.0, "force": 160.0,
			"effect": FX.INTAKE, "loop_sound": LOOP.WHINE, "sound_pitch": 0.7, "sound_volume_db": -8.0,
			"use_shake": 0.0015}})

	# Magnet gun: red and white body, horseshoe magnet with steel pole tips, copper coils.
	var white := Color(0.92, 0.92, 0.9)
	var magnet_parts: Array = _grip(DARK) + [
		_box(Vector3(0.07, 0.075, 0.2), Vector3(0, 0.07, -0.05), white),
		_box(Vector3(0.025, 0.025, 0.11), Vector3(-0.04, 0.07, -0.2), fire_red),
		_box(Vector3(0.025, 0.025, 0.11), Vector3(0.04, 0.07, -0.2), fire_red),
		_box(Vector3(0.027, 0.027, 0.025), Vector3(-0.04, 0.07, -0.265), STEEL, Vector3.ZERO, false, 0.9),
		_box(Vector3(0.027, 0.027, 0.025), Vector3(0.04, 0.07, -0.265), STEEL, Vector3.ZERO, false, 0.9),
	]
	for z in [-0.0, -0.04, -0.08]:
		magnet_parts.append(_cyl(0.042, 0.012, Vector3(0, 0.07, z), COPPER, ALONG_Z, false, 0.8))
	specs.append({"key": "magnet_gun", "name": "Magnet Gun", "mass": 3.0, "op": "magnet",
		"parts": magnet_parts, "nozzle": Vector3(0, 0.07, -0.28),
		"action": {"verb": "Magnet", "primary_hint": "[Hold LMB] Pull magnetic metal", "secondary_hint": "",
			"range_metres": 6.0, "cone_degrees": 12.0, "force": 260.0,
			"effect": FX.BEAM, "effect_color": Color(0.65, 0.45, 1.0), "light_color": Color(0.6, 0.4, 1.0),
			"loop_sound": LOOP.HUM, "sound_volume_db": -8.0}})

	# Physics grabber: grey body with orange accents, three prongs round a cyan core.
	var accent := Color(0.95, 0.55, 0.1)
	var grabber_parts: Array = _grip(DARK) + [
		_box(Vector3(0.085, 0.09, 0.24), Vector3(0, 0.07, -0.05), Color(0.45, 0.47, 0.5), Vector3.ZERO, true, 0.5),
		_box(Vector3(0.09, 0.02, 0.12), Vector3(0, 0.125, -0.06), accent),
		_ball(0.03, Vector3(0, 0.07, -0.2), Color(0.3, 0.9, 1.0), false),
	]
	for angle in [0.0, 120.0, 240.0]:
		var offset := Vector3(0, 0.045, 0).rotated(Vector3.BACK, deg_to_rad(angle))
		grabber_parts.append(_box(Vector3(0.016, 0.016, 0.1), Vector3(offset.x, 0.07 + offset.y, -0.22), accent, Vector3.ZERO, false))
	specs.append({"key": "physics_grabber", "name": "Physics Grabber", "mass": 4.0, "op": "grabber",
		"parts": grabber_parts, "nozzle": Vector3(0, 0.07, -0.24),
		"action": {"verb": "Grab", "primary_hint": "[Hold LMB] Grab at a distance", "secondary_hint": "",
			"range_metres": 10.0, "force": 1400.0, "mass_limit": 80.0,
			"effect": FX.BEAM, "effect_color": Color(0.3, 0.9, 1.0), "light_color": Color(0.3, 0.85, 1.0),
			"loop_sound": LOOP.HUM, "sound_pitch": 1.6, "sound_volume_db": -10.0}})

	# Shovel: D-handle at the hand, wooden shaft, steel scoop with low side walls.
	var scoop := PhysicsContainerDefinition.new()
	scoop.form = PhysicsContainerDefinition.Form.CUSTOM
	scoop.inner_center = Vector3(0, 0.01, -1.02)
	scoop.inner_size = Vector3(0.22, 0.1, 0.26)
	scoop.stabilise_when_equipped = true
	specs.append({"key": "shovel", "name": "Shovel", "mass": 2.6, "op": "shovel", "sound": ImpactFeedback.Sound.METAL,
		"parts": [
			_box(Vector3(0.1, 0.02, 0.02), Vector3(0, 0, 0.02), BLACK),
			_cyl(0.016, 0.9, Vector3(0, 0, -0.45), WOOD, ALONG_Z),
			_box(Vector3(0.24, 0.012, 0.28), Vector3(0, -0.02, -1.02), STEEL, Vector3.ZERO, true, 0.7),
			_box(Vector3(0.012, 0.05, 0.28), Vector3(-0.12, 0.0, -1.02), STEEL, Vector3.ZERO, true, 0.7),
			_box(Vector3(0.012, 0.05, 0.28), Vector3(0.12, 0.0, -1.02), STEEL, Vector3.ZERO, true, 0.7),
			_box(Vector3(0.24, 0.05, 0.012), Vector3(0, 0.0, -0.88), STEEL, Vector3.ZERO, true, 0.7),
		],
		"container": scoop, "scoop_parts": PackedInt32Array([2, 3, 4, 5]),
		"nozzle": Vector3(0, -0.02, -1.1),
		"rest": [Vector3(0.24, -0.34, 0.06), Vector3(-14, 0, 6)], "use": [Vector3(0.2, -0.44, -0.08), Vector3(-30, 0, 4)],
		"action": {"verb": "Shovel", "range_metres": 1.9, "rate": 30.0, "region_size": Vector3(0.3, 0.15, 0.3),
			"contact_effect": FX.DUST, "effect_color": Color(0.45, 0.33, 0.2), "shot_sound": SHOT.CLICK, "shot_kick": 0.5}})

	# Paint sprayer: silver gun with a top-feed paint cup.
	specs.append({"key": "paint_sprayer", "name": "Paint Sprayer", "mass": 1.2, "op": "paint",
		"parts": _grip(DARK) + [
			_box(Vector3(0.04, 0.065, 0.12), Vector3(0, 0.075, -0.04), STEEL, Vector3.ZERO, true, 0.8),
			_cyl(0.04, 0.09, Vector3(0, 0.155, -0.04), Color(0.85, 0.85, 0.8)),
			_cyl(0.012, 0.045, Vector3(0, 0.075, -0.12), BRASS, ALONG_Z, true, 0.8),
		],
		"nozzle": Vector3(0, 0.075, -0.145),
		"action": {"verb": "Paint", "primary_hint": "[Hold LMB] Spray paint", "secondary_hint": "",
			"range_metres": 3.5, "cone_degrees": 10.0,
			"effect": FX.PAINT, "loop_sound": LOOP.SPRAY, "sound_pitch": 1.35, "sound_volume_db": -10.0, "use_shake": 0.0008}})

	# Label gun: yellow body, little screen, white tape slot.
	specs.append({"key": "marker_gun", "name": "Marker / Label Gun", "mass": 0.8, "op": "marker", "sound": ImpactFeedback.Sound.PLASTIC,
		"parts": _grip(DARK) + [
			_box(Vector3(0.07, 0.05, 0.16), Vector3(0, 0.055, -0.04), Color(0.95, 0.78, 0.1)),
			_box(Vector3(0.045, 0.004, 0.045), Vector3(0, 0.082, 0.0), Color(0.2, 0.35, 0.25), Vector3.ZERO, false),
			_box(Vector3(0.04, 0.008, 0.03), Vector3(0, 0.05, -0.13), Color.WHITE, Vector3.ZERO, false),
		],
		"nozzle": Vector3(0, 0.05, -0.145),
		"action": {"verb": "Mark", "range_metres": 4.0, "effect_color": Color(1.0, 0.85, 0.1),
			"shot_sound": SHOT.CLICK, "shot_kick": 0.15}})

	# Spray foam gun: upside-down can on top, thin black barrel.
	specs.append({"key": "spray_foam_gun", "name": "Spray Foam Gun", "mass": 1.3, "op": "foam",
		"parts": _grip(DARK) + [
			_box(Vector3(0.035, 0.05, 0.14), Vector3(0, 0.05, -0.04), Color(0.3, 0.45, 0.75)),
			_cyl(0.034, 0.2, Vector3(0, 0.175, -0.02), Color(0.95, 0.85, 0.3)),
			_cyl(0.007, 0.18, Vector3(0, 0.05, -0.2), BLACK, ALONG_Z),
		],
		"nozzle": Vector3(0, 0.05, -0.29),
		"action": {"verb": "Foam", "primary_hint": "[Hold LMB] Spray foam (hardens, then expires)", "secondary_hint": "",
			"range_metres": 3.0, "effect": FX.FOAM, "loop_sound": LOOP.SPRAY, "sound_pitch": 0.7, "sound_volume_db": -10.0}})

	# Plunger launcher: fat green tube, stock behind the hand, a plunger in the muzzle.
	var olive := Color(0.3, 0.42, 0.22)
	specs.append({"key": "plunger_launcher", "name": "Plunger Launcher", "mass": 2.5, "op": "plunger",
		"parts": _grip(BLACK) + [
			_cyl(0.045, 0.5, Vector3(0, 0.08, -0.16), olive, ALONG_Z),
			_cyl(0.05, 0.03, Vector3(0, 0.08, -0.42), BLACK, ALONG_Z),
			_cyl(0.044, 0.03, Vector3(0, 0.08, -0.45), RUBBER_RED, ALONG_Z, false),
			_box(Vector3(0.04, 0.08, 0.17), Vector3(0, 0.03, 0.16), olive),
			_box(Vector3(0.01, 0.025, 0.04), Vector3(0, 0.135, -0.1), BLACK, Vector3.ZERO, false),
		],
		"nozzle": Vector3(0, 0.08, -0.47),
		"rest": [Vector3(0.2, -0.26, -0.22), Vector3.ZERO], "use": [Vector3(0.2, -0.26, -0.22), Vector3.ZERO],
		"action": {"verb": "Launch", "primary_hint": "[LMB] Fire plunger", "secondary_hint": "[RMB] Reload a nearby plunger",
			"range_metres": 30.0, "projectile_speed": 22.0, "shot_sound": SHOT.POP, "shot_kick": 1.0, "sound_volume_db": -4.0}})
	return specs


# --- Components and the crowbar's pry mode

func _save_components() -> void:
	var pulley := _component("Pulley", 1.5, [
		_cyl(0.1, 0.045, Vector3(0, 0.12, 0), STEEL, ALONG_Z, true, 0.8),
		_cyl(0.03, 0.06, Vector3(0, 0.12, 0), DARK, ALONG_Z, false, 0.7),
		_box(Vector3(0.05, 0.3, 0.012), Vector3(0, 0.2, -0.035), Color(0.9, 0.7, 0.1)),
		_box(Vector3(0.05, 0.3, 0.012), Vector3(0, 0.2, 0.035), Color(0.9, 0.7, 0.1)),
		_box(Vector3(0.06, 0.03, 0.09), Vector3(0, 0.36, 0), DARK, Vector3.ZERO, true, 0.6),
	])
	pulley.contraption_component = "pulley"
	_save(pulley, "res://props/advanced/pulley.tres")
	var plunger := _component("Plunger", 0.2, [
		_ball(0.065, Vector3(0, 0, 0.0), RUBBER_RED),
		_cyl(0.02, 0.28, Vector3(0, 0, 0.17), WOOD, ALONG_Z),
	])
	plunger.contraption_component = "plunger"
	plunger.impact_sound = ImpactFeedback.Sound.RUBBER
	_save(plunger, "res://props/advanced/plunger.tres")
	var nail := _component("Nail", 0.015, [
		_cyl(0.004, 0.08, Vector3(0, 0, 0.01), STEEL, ALONG_Z, true, 0.9),
		_cyl(0.009, 0.004, Vector3(0, 0, 0.05), STEEL, ALONG_Z, false, 0.9),
	])
	_save(nail, "res://contraptions/assets/nail_projectile.tres")


func _component(display: String, mass: float, parts: Array) -> PhysicsObjectDefinition:
	var definition := PhysicsObjectDefinition.new()
	definition.display_name = display
	definition.shape_type = PhysicsObjectDefinition.ShapeType.COMPOUND
	var typed: Array[PhysicsShapePart] = []
	typed.assign(parts)
	definition.parts = typed
	definition.mass = mass
	definition.continuous_cd = true
	definition.tool_profile = load(STEEL_PROFILE)
	definition.impact_sound = ImpactFeedback.Sound.METAL
	return definition


func _save_pry() -> void:
	var path := CONFIG + "crowbar_pry.tres"
	var pry := ToolActionDefinition.new()
	pry.operation = "pry"
	pry.verb = "Pry"
	pry.primary_hint = "[Hold LMB] Pry fastenings apart"
	pry.secondary_hint = ""
	pry.range_metres = 1.8
	pry.rate = 120.0
	pry.force = 80.0
	pry.contact_effect = FX.DUST
	pry.effect_color = Color(0.6, 0.55, 0.5)
	pry.use_shake = 0.0015
	_save(pry, path)


# --- Saving

## Saves `resource`, keeping the existing file's uid so scenes referencing it still resolve.
func _save(resource: Resource, path: String) -> void:
	var uid_line := ""
	if FileAccess.file_exists(path):
		var match := RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"").search(FileAccess.get_file_as_string(path).get_slice("\n", 0))
		if match != null:
			uid_line = match.get_string()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	ResourceSaver.save(resource, path)
	if uid_line.is_empty():
		return
	var saved := FileAccess.get_file_as_string(path)
	var header := saved.get_slice("\n", 0)
	if header.contains("uid=\"uid://"):
		header = RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"").sub(header, uid_line)
	else:
		header = header.trim_suffix("]") + " " + uid_line + "]"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(header + saved.substr(saved.find("\n")))
