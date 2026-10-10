extends SceneTree
## Generates the extra tools, props and destructible objects as ordinary data:
## PhysicsObjectDefinition / VoxelStructureDefinition / VoxelMaterialDefinition
## .tres files (editable in the Inspector) plus .vox models for destructibles.
## Props and tools get their voxel art afterwards from:
##   godot --headless --path . -s res://tools/generate_prop_vox.gd -- new
## Run this script with: godot --headless --path . -s res://tools/generate_content.gd
## Re-running overwrites these generated files (not the original playground props).

const TOOLS_DIR := "res://props/tools/"
const OBJECTS_DIR := "res://props/objects/"
const STRUCTURES_DIR := "res://props/voxel_structures/"
const MATERIALS_DIR := "res://props/voxel_materials/"
const VOX_DIR := "res://props/vox/"

const BOX := PhysicsShapePart.ShapeType.BOX
const SPHERE := PhysicsShapePart.ShapeType.SPHERE
const CYL := PhysicsShapePart.ShapeType.CYLINDER

const S := ImpactFeedback.Sound
const T := PhysicsToolDefinition.ImpactType

# Colours used in several places.
const WOOD := Color(0.62, 0.44, 0.26)
const WOOD_LIGHT := Color(0.8, 0.64, 0.42)
const STEEL := Color(0.34, 0.35, 0.38)
const STEEL_BRIGHT := Color(0.66, 0.68, 0.72)
const BLACK := Color(0.08, 0.08, 0.09)
const WHITE := Color(0.95, 0.95, 0.94)


func _initialize() -> void:
	for dir in [TOOLS_DIR, OBJECTS_DIR, STRUCTURES_DIR, MATERIALS_DIR, VOX_DIR]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_make_tools()
	_make_props()
	_make_destructibles()
	print("Content generated.")
	quit()


# --- Builders

func _mat(color: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


## A shape piece. `dims` is size for boxes, (radius, height) for cylinders and
## (radius) for spheres.
func _part(type: int, dims: Vector3, position: Vector3, color: Color, rotation := Vector3.ZERO,
		collides := true, metallic := 0.0, roughness := 0.8) -> PhysicsShapePart:
	var part := PhysicsShapePart.new()
	part.shape_type = type
	if type == BOX:
		part.size = dims
	else:
		part.radius = dims.x
		part.height = dims.y
	part.position = position
	part.rotation_degrees = rotation
	part.material = _mat(color, metallic, roughness)
	part.collides = collides
	return part


func _save_object(dir: String, file: String, display: String, parts: Array, mass: float, options := {}) -> void:
	var definition := PhysicsObjectDefinition.new()
	definition.display_name = display
	definition.shape_type = PhysicsObjectDefinition.ShapeType.COMPOUND
	var typed: Array[PhysicsShapePart] = []
	typed.assign(parts)
	definition.parts = typed
	definition.mass = mass
	definition.friction = options.get("friction", 0.6)
	definition.bounce = options.get("bounce", 0.1)
	definition.linear_damp = options.get("linear_damp", 0.05)
	definition.angular_damp = options.get("angular_damp", 0.15)
	definition.impact_sound = options.get("sound", S.GENERIC)
	definition.impact_damage_scale = options.get("impact", 1.0)
	definition.spawn_category = options.get("category", "")
	# The object's surface material shapes how its voxel model shines (metal, plastic).
	definition.material = options.get("surface", null)
	if options.has("tool"):
		definition.tool = options["tool"]
	ResourceSaver.save(definition, dir + file + ".tres")


const POSES := {
	"overhead": [Vector3(0.32, -0.42, -0.4), Vector3(-22, 0, 10), Vector3(0.24, -0.2, -0.3),
		Vector3(65, 0, 8), Vector3(0.16, -0.48, -0.5), Vector3(-100, 0, 4)],
	"side": [Vector3(0.3, -0.32, -0.38), Vector3(-30, 0, 8), Vector3(0.34, -0.28, -0.3),
		Vector3(0, 30, -80), Vector3(0, -0.32, -0.45), Vector3(0, 160, -90)],
}


## A tool using one of the pose templates. "low" tools are held head-down like the
## golf club, with the hands set so the head skims the floor for this length.
func _tool(template: String, grip: Vector3, strike: Vector3, settings: Dictionary) -> PhysicsToolDefinition:
	var tool := PhysicsToolDefinition.new()
	tool.grip_position = grip
	tool.strike_point = strike
	if template == "low":
		var length := grip.distance_to(strike)
		var hand := -(1.54 - length * 0.94)
		tool.pitch_follow = 0.0
		tool.rest_position = Vector3(0, hand, -0.32)
		tool.rest_rotation_degrees = Vector3(20, 0, 0)
		tool.windup_position = Vector3(0.18, hand + 0.04, -0.26)
		tool.windup_rotation_degrees = Vector3(20, 0, 110)
		tool.strike_position = Vector3(-0.18, hand + 0.04, -0.26)
		tool.strike_rotation_degrees = Vector3(20, 0, -115)
		tool.impact_moment = 0.67
		tool.aim_mode = PhysicsToolDefinition.AimMode.VIEW_FORWARD_FLAT
	else:
		var pose: Array = POSES[template]
		tool.rest_position = pose[0]
		tool.rest_rotation_degrees = pose[1]
		tool.windup_position = pose[2]
		tool.windup_rotation_degrees = pose[3]
		tool.strike_position = pose[4]
		tool.strike_rotation_degrees = pose[5]
	for key in settings:
		tool.set(key, settings[key])
	return tool


# --- Tools

func _make_tools() -> void:
	_save_object(TOOLS_DIR, "frying_pan", "Frying Pan", [
		_part(CYL, Vector3(0.014, 0.26, 0), Vector3.ZERO, Color(0.25, 0.17, 0.1)),
		_part(CYL, Vector3(0.13, 0.03, 0), Vector3(0, 0.27, 0), Color(0.12, 0.12, 0.13), Vector3(90, 0, 0), true, 0.5, 0.4),
	], 1.6, {"sound": S.METAL, "tool": _tool("side", Vector3(0, -0.08, 0), Vector3(0, 0.27, 0), {
		"action_name": "Bonk", "strike_radius": 0.15, "impact_impulse": 40.0, "max_launch_speed": 16.0,
		"damage": 6.0, "voxel_damage_radius": 0.12, "swing_path_influence": 0.3, "windup_time": 0.14,
		"strike_time": 0.1, "recover_time": 0.22, "cooldown": 0.06, "charge_time": 0.5, "reach": 2.2})})

	_save_object(TOOLS_DIR, "axe", "Axe", [
		_part(CYL, Vector3(0.018, 0.75, 0), Vector3.ZERO, WOOD),
		_part(BOX, Vector3(0.035, 0.12, 0.13), Vector3(0, 0.33, -0.035), STEEL, Vector3.ZERO, true, 0.8, 0.4),
		_part(BOX, Vector3(0.012, 0.16, 0.05), Vector3(0, 0.33, -0.12), STEEL_BRIGHT, Vector3.ZERO, true, 0.9, 0.25),
	], 2.0, {"sound": S.METAL, "tool": _tool("overhead", Vector3(0, -0.3, 0), Vector3(0, 0.33, -0.13), {
		"action_name": "Chop", "impact_type": T.SHARP, "strike_radius": 0.1, "impact_impulse": 22.0,
		"max_launch_speed": 8.0, "damage": 30.0, "voxel_damage_radius": 0.2, "swing_path_influence": 0.6,
		"windup_time": 0.22, "strike_time": 0.12, "recover_time": 0.3, "charge_time": 0.7, "reach": 2.3})})

	_save_object(TOOLS_DIR, "pickaxe", "Pickaxe", [
		_part(CYL, Vector3(0.018, 0.8, 0), Vector3.ZERO, WOOD),
		_part(BOX, Vector3(0.035, 0.04, 0.5), Vector3(0, 0.37, 0), STEEL, Vector3.ZERO, true, 0.8, 0.4),
		_part(BOX, Vector3(0.02, 0.025, 0.06), Vector3(0, 0.37, -0.27), STEEL_BRIGHT, Vector3.ZERO, false, 0.9, 0.25),
		_part(BOX, Vector3(0.02, 0.025, 0.06), Vector3(0, 0.37, 0.27), STEEL_BRIGHT, Vector3.ZERO, false, 0.9, 0.25),
	], 3.0, {"sound": S.METAL, "tool": _tool("overhead", Vector3(0, -0.32, 0), Vector3(0, 0.37, -0.27), {
		"action_name": "Dig", "impact_type": T.PIERCE, "strike_radius": 0.08, "impact_impulse": 20.0,
		"max_launch_speed": 7.0, "damage": 45.0, "voxel_damage_radius": 0.16, "windup_time": 0.3,
		"strike_time": 0.14, "recover_time": 0.36, "cooldown": 0.12, "charge_time": 0.9, "reach": 2.3})})

	_save_object(TOOLS_DIR, "rubber_mallet", "Rubber Mallet", [
		_part(CYL, Vector3(0.016, 0.38, 0), Vector3.ZERO, WOOD_LIGHT),
		_part(CYL, Vector3(0.055, 0.15, 0), Vector3(0, 0.2, 0), BLACK, Vector3(90, 0, 0)),
	], 1.0, {"sound": S.RUBBER, "tool": _tool("overhead", Vector3(0, -0.12, 0), Vector3(0, 0.2, -0.07), {
		"action_name": "Boing", "strike_radius": 0.1, "impact_impulse": 35.0, "max_launch_speed": 14.0,
		"damage": 3.0, "voxel_damage_radius": 0.08, "windup_time": 0.12, "strike_time": 0.1,
		"recover_time": 0.18, "charge_time": 0.4})})

	_save_object(TOOLS_DIR, "hockey_stick", "Hockey Stick", [
		_part(CYL, Vector3(0.014, 1.1, 0), Vector3.ZERO, WOOD_LIGHT),
		_part(BOX, Vector3(0.02, 0.07, 0.22), Vector3(0, -0.57, -0.08), BLACK),
		_part(CYL, Vector3(0.016, 0.15, 0), Vector3(0, 0.48, 0), BLACK, Vector3.ZERO, false),
	], 0.6, {"sound": S.WOOD, "tool": _tool("low", Vector3(0, 0.45, 0), Vector3(0, -0.57, -0.1), {
		"action_name": "Slap", "impact_type": T.SWEEP, "strike_radius": 0.08, "impact_impulse": 9.0,
		"max_launch_speed": 18.0, "loft_degrees": 4.0, "swing_path_influence": 0.15, "damage": 4.0,
		"voxel_damage_radius": 0.06, "windup_time": 0.3, "strike_time": 0.13, "recover_time": 0.3,
		"charge_time": 0.8, "reach": 2.6})})

	_save_object(TOOLS_DIR, "tennis_racket", "Tennis Racket", [
		_part(CYL, Vector3(0.016, 0.28, 0), Vector3.ZERO, WHITE),
		_part(CYL, Vector3(0.01, 0.1, 0), Vector3(0, 0.18, 0), Color(0.75, 0.1, 0.1)),
		_part(CYL, Vector3(0.14, 0.02, 0), Vector3(0, 0.36, 0), Color(0.75, 0.1, 0.1), Vector3(90, 0, 0)),
		_part(CYL, Vector3(0.12, 0.024, 0), Vector3(0, 0.36, 0), Color(0.92, 0.92, 0.82), Vector3(90, 0, 0), false),
	], 0.35, {"sound": S.PLASTIC, "tool": _tool("side", Vector3(0, -0.1, 0), Vector3(0, 0.36, 0), {
		"action_name": "Serve", "impact_type": T.SWEEP, "strike_radius": 0.15, "impact_impulse": 8.0,
		"max_launch_speed": 24.0, "loft_degrees": 35.0, "swing_path_influence": 0.2, "damage": 1.0,
		"voxel_damage_radius": 0.0, "windup_time": 0.1, "strike_time": 0.1, "recover_time": 0.2,
		"cooldown": 0.05, "charge_time": 0.5})})

	_save_object(TOOLS_DIR, "crowbar", "Crowbar", [
		_part(CYL, Vector3(0.012, 0.7, 0), Vector3.ZERO, Color(0.7, 0.1, 0.08), Vector3.ZERO, true, 0.5, 0.4),
		_part(BOX, Vector3(0.024, 0.024, 0.09), Vector3(0, 0.36, -0.035), Color(0.7, 0.1, 0.08), Vector3(20, 0, 0), true, 0.5, 0.4),
		_part(BOX, Vector3(0.03, 0.008, 0.05), Vector3(0, -0.36, -0.01), STEEL_BRIGHT, Vector3.ZERO, true, 0.9, 0.3),
	], 1.6, {"sound": S.METAL, "tool": _tool("overhead", Vector3(0, -0.25, 0), Vector3(0, 0.35, -0.06), {
		"action_name": "Whack", "strike_radius": 0.09, "impact_impulse": 20.0, "max_launch_speed": 9.0,
		"damage": 22.0, "voxel_damage_radius": 0.16, "windup_time": 0.15, "strike_time": 0.1,
		"recover_time": 0.2, "cooldown": 0.06, "charge_time": 0.5})})

	_save_object(TOOLS_DIR, "broom", "Broom", [
		_part(CYL, Vector3(0.014, 1.2, 0), Vector3.ZERO, WOOD_LIGHT),
		_part(BOX, Vector3(0.06, 0.05, 0.32), Vector3(0, -0.62, 0), Color(0.75, 0.15, 0.12)),
		_part(BOX, Vector3(0.05, 0.1, 0.3), Vector3(0, -0.69, 0), Color(0.85, 0.72, 0.4)),
	], 0.8, {"sound": S.CARDBOARD, "tool": _tool("low", Vector3(0, 0.5, 0), Vector3(0, -0.7, 0), {
		"action_name": "Sweep", "impact_type": T.SWEEP, "strike_radius": 0.2, "impact_impulse": 4.0,
		"max_launch_speed": 5.0, "loft_degrees": 10.0, "damage": 0.0, "voxel_damage_radius": 0.0,
		"windup_time": 0.25, "strike_time": 0.2, "recover_time": 0.25, "charge_time": 0.0,
		"motion_strike_min_speed": 3.0, "motion_strike_full_speed": 10.0, "motion_strike_cooldown": 0.1})})

	_save_object(TOOLS_DIR, "foam_hand", "Giant Foam Hand", [
		_part(CYL, Vector3(0.02, 0.3, 0), Vector3.ZERO, Color(0.15, 0.35, 0.8)),
		_part(BOX, Vector3(0.22, 0.24, 0.06), Vector3(0, 0.28, 0), Color(1.0, 0.55, 0.1)),
		_part(BOX, Vector3(0.06, 0.2, 0.06), Vector3(-0.05, 0.5, 0), Color(1.0, 0.55, 0.1)),
		_part(BOX, Vector3(0.06, 0.1, 0.06), Vector3(0.13, 0.3, 0), Color(1.0, 0.55, 0.1), Vector3(0, 0, -30)),
	], 0.5, {"sound": S.RUBBER, "tool": _tool("side", Vector3(0, -0.1, 0), Vector3(0, 0.35, 0), {
		"action_name": "Slap", "strike_radius": 0.18, "impact_impulse": 30.0, "max_launch_speed": 18.0,
		"damage": 0.0, "voxel_damage_radius": 0.0, "windup_time": 0.12, "strike_time": 0.1,
		"recover_time": 0.2, "charge_time": 0.5, "motion_strike_min_speed": 4.0})})

	_save_object(TOOLS_DIR, "wrecking_mallet", "Wrecking Mallet", [
		_part(CYL, Vector3(0.03, 1.0, 0), Vector3.ZERO, WOOD),
		_part(CYL, Vector3(0.17, 0.44, 0), Vector3(0, 0.55, 0), Color(0.75, 0.15, 0.1), Vector3(90, 0, 0)),
		_part(CYL, Vector3(0.175, 0.04, 0), Vector3(0, 0.55, -0.18), Color(0.25, 0.25, 0.27), Vector3(90, 0, 0), false),
		_part(CYL, Vector3(0.175, 0.04, 0), Vector3(0, 0.55, 0.18), Color(0.25, 0.25, 0.27), Vector3(90, 0, 0), false),
	], 9.0, {"sound": S.WOOD, "impact": 2.0, "tool": _tool("overhead", Vector3(0, -0.4, 0), Vector3(0, 0.55, -0.22), {
		"action_name": "Demolish", "strike_radius": 0.2, "impact_impulse": 90.0, "max_launch_speed": 10.0,
		"damage": 70.0, "voxel_damage_radius": 0.5, "windup_time": 0.45, "strike_time": 0.16,
		"recover_time": 0.5, "cooldown": 0.2, "charge_time": 1.2, "min_charge_power": 0.4, "reach": 2.6,
		"motion_strike_min_speed": 7.0, "motion_strike_full_speed": 15.0, "motion_strike_cooldown": 0.5})})


# --- Props

func _make_props() -> void:
	var o := OBJECTS_DIR
	_save_object(o, "bowling_ball", "Bowling Ball", [
		_part(SPHERE, Vector3(0.108, 0, 0), Vector3.ZERO, Color(0.15, 0.2, 0.55)),
		_part(SPHERE, Vector3(0.014, 0, 0), Vector3(-0.02, 0.07, -0.08), BLACK, Vector3.ZERO, false),
		_part(SPHERE, Vector3(0.014, 0, 0), Vector3(0.02, 0.07, -0.08), BLACK, Vector3.ZERO, false),
		_part(SPHERE, Vector3(0.016, 0, 0), Vector3(0, 0.03, -0.1), BLACK, Vector3.ZERO, false),
	], 7.0, {"category": "Balls", "friction": 0.3, "bounce": 0.05, "sound": S.STONE, "impact": 2.0,
		"surface": _mat(Color.WHITE, 0.2, 0.2)})

	var football: Array = [_part(SPHERE, Vector3(0.11, 0, 0), Vector3.ZERO, WHITE)]
	for spot in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		football.append(_part(SPHERE, Vector3(0.04, 0, 0), spot * 0.085, BLACK, Vector3.ZERO, false))
	_save_object(o, "football", "Football", football, 0.43,
		{"category": "Balls", "friction": 0.7, "bounce": 0.65, "linear_damp": 0.1, "sound": S.RUBBER, "impact": 0.3})

	_save_object(o, "basketball", "Basketball", [
		_part(SPHERE, Vector3(0.12, 0, 0), Vector3.ZERO, Color(0.85, 0.4, 0.1)),
		_part(CYL, Vector3(0.122, 0.006, 0), Vector3.ZERO, BLACK, Vector3.ZERO, false),
		_part(CYL, Vector3(0.122, 0.006, 0), Vector3.ZERO, BLACK, Vector3(90, 0, 0), false),
		_part(CYL, Vector3(0.122, 0.006, 0), Vector3.ZERO, BLACK, Vector3(0, 0, 90), false),
	], 0.6, {"category": "Balls", "friction": 0.8, "bounce": 0.82, "sound": S.RUBBER, "impact": 0.4})

	_save_object(o, "beach_ball", "Beach Ball", [
		_part(SPHERE, Vector3(0.25, 0, 0), Vector3.ZERO, WHITE),
		_part(CYL, Vector3(0.252, 0.08, 0), Vector3.ZERO, Color(0.9, 0.15, 0.15), Vector3(90, 0, 0), false),
		_part(CYL, Vector3(0.252, 0.08, 0), Vector3.ZERO, Color(1.0, 0.85, 0.1), Vector3(90, 60, 0), false),
		_part(CYL, Vector3(0.252, 0.08, 0), Vector3.ZERO, Color(0.15, 0.4, 0.9), Vector3(90, 120, 0), false),
	], 0.12, {"category": "Balls", "friction": 0.6, "bounce": 0.75, "linear_damp": 1.0, "angular_damp": 0.6,
		"sound": S.RUBBER, "impact": 0.0, "surface": _mat(Color.WHITE, 0.0, 0.35)})

	_save_object(o, "tennis_ball", "Tennis Ball", [
		_part(SPHERE, Vector3(0.033, 0, 0), Vector3.ZERO, Color(0.8, 0.95, 0.2)),
		_part(CYL, Vector3(0.034, 0.005, 0), Vector3.ZERO, WHITE, Vector3(0, 0, 30), false),
	], 0.058, {"category": "Balls", "friction": 0.8, "bounce": 0.75, "sound": S.RUBBER, "impact": 0.0})

	_save_object(o, "hockey_puck", "Hockey Puck", [
		_part(CYL, Vector3(0.038, 0.025, 0), Vector3.ZERO, BLACK),
	], 0.17, {"category": "Balls", "friction": 0.1, "bounce": 0.2, "sound": S.RUBBER, "impact": 0.3})

	_save_object(o, "rubber_duck", "Rubber Duck", [
		_part(SPHERE, Vector3(0.07, 0, 0), Vector3.ZERO, Color(1.0, 0.85, 0.1)),
		_part(SPHERE, Vector3(0.045, 0, 0), Vector3(0, 0.075, -0.035), Color(1.0, 0.85, 0.1)),
		_part(BOX, Vector3(0.04, 0.014, 0.035), Vector3(0, 0.07, -0.085), Color(1.0, 0.5, 0.05)),
		_part(SPHERE, Vector3(0.008, 0, 0), Vector3(-0.02, 0.09, -0.07), BLACK, Vector3.ZERO, false),
		_part(SPHERE, Vector3(0.008, 0, 0), Vector3(0.02, 0.09, -0.07), BLACK, Vector3.ZERO, false),
	], 0.12, {"bounce": 0.5, "sound": S.RUBBER, "impact": 0.0, "surface": _mat(Color.WHITE, 0.0, 0.35)})

	var orange := Color(1.0, 0.45, 0.05)
	_save_object(o, "traffic_cone", "Traffic Cone", [
		_part(BOX, Vector3(0.32, 0.03, 0.32), Vector3(0, -0.22, 0), Color(0.85, 0.35, 0.05)),
		_part(CYL, Vector3(0.12, 0.1, 0), Vector3(0, -0.15, 0), orange),
		_part(CYL, Vector3(0.095, 0.1, 0), Vector3(0, -0.05, 0), WHITE),
		_part(CYL, Vector3(0.07, 0.1, 0), Vector3(0, 0.05, 0), orange),
		_part(CYL, Vector3(0.045, 0.1, 0), Vector3(0, 0.15, 0), WHITE),
		_part(CYL, Vector3(0.025, 0.06, 0), Vector3(0, 0.23, 0), orange),
	], 1.5, {"bounce": 0.3, "sound": S.PLASTIC, "surface": _mat(Color.WHITE, 0.0, 0.45)})

	_save_object(o, "tyre", "Car Tyre", [
		_part(CYL, Vector3(0.3, 0.2, 0), Vector3.ZERO, BLACK, Vector3(0, 0, 90)),
		_part(CYL, Vector3(0.15, 0.205, 0), Vector3.ZERO, Color(0.5, 0.5, 0.52), Vector3(0, 0, 90), false),
	], 9.0, {"friction": 1.0, "bounce": 0.55, "sound": S.RUBBER, "impact": 0.8})

	_save_object(o, "oil_barrel", "Oil Barrel", [
		_part(CYL, Vector3(0.28, 0.85, 0), Vector3.ZERO, Color(0.15, 0.3, 0.6)),
		_part(CYL, Vector3(0.29, 0.03, 0), Vector3(0, 0.2, 0), Color(0.1, 0.18, 0.35), Vector3.ZERO, false),
		_part(CYL, Vector3(0.29, 0.03, 0), Vector3(0, -0.2, 0), Color(0.1, 0.18, 0.35), Vector3.ZERO, false),
		_part(CYL, Vector3(0.26, 0.012, 0), Vector3(0, 0.43, 0), Color(0.55, 0.55, 0.58), Vector3.ZERO, false),
	], 20.0, {"friction": 0.5, "bounce": 0.1, "sound": S.METAL, "impact": 1.5, "surface": _mat(Color.WHITE, 0.5, 0.45)})

	var iron := Color(0.18, 0.18, 0.2)
	_save_object(o, "anvil", "Anvil", [
		_part(BOX, Vector3(0.3, 0.1, 0.22), Vector3(0, -0.12, 0), iron),
		_part(BOX, Vector3(0.14, 0.1, 0.12), Vector3(0, -0.02, 0), iron),
		_part(BOX, Vector3(0.4, 0.09, 0.16), Vector3(0, 0.075, 0), iron),
		_part(BOX, Vector3(0.16, 0.06, 0.08), Vector3(-0.27, 0.08, 0), iron),
	], 70.0, {"friction": 0.6, "bounce": 0.0, "sound": S.METAL, "impact": 3.0, "surface": _mat(Color.WHITE, 0.7, 0.4)})

	var die: Array = [_part(BOX, Vector3(0.36, 0.36, 0.36), Vector3.ZERO, Color(0.85, 0.1, 0.1))]
	var pip := Vector3(0.06, 0.06, 0.01)
	die.append(_part(BOX, pip, Vector3(0, 0, -0.182), WHITE, Vector3.ZERO, false))
	for offset in [Vector2(-0.08, -0.08), Vector2(0.08, 0.08)]:
		die.append(_part(BOX, pip, Vector3(0.182, offset.x, offset.y), WHITE, Vector3(0, 90, 0), false))
	for offset in [Vector2(-0.09, -0.09), Vector2(0, 0), Vector2(0.09, 0.09)]:
		die.append(_part(BOX, pip, Vector3(offset.x, 0.182, offset.y), WHITE, Vector3(90, 0, 0), false))
	_save_object(o, "foam_die", "Giant Foam Die", die, 0.35,
		{"bounce": 0.45, "linear_damp": 0.2, "sound": S.CARDBOARD, "impact": 0.1})

	_save_object(o, "coffee_mug", "Coffee Mug", [
		_part(CYL, Vector3(0.045, 0.1, 0), Vector3.ZERO, WHITE),
		_part(BOX, Vector3(0.02, 0.065, 0.025), Vector3(0.055, 0, 0), WHITE),
		_part(CYL, Vector3(0.04, 0.005, 0), Vector3(0, 0.05, 0), Color(0.3, 0.17, 0.08), Vector3.ZERO, false),
	], 0.35, {"sound": S.STONE, "impact": 0.3, "surface": _mat(Color.WHITE, 0.0, 0.25)})

	var china := Color(0.85, 0.9, 1.0)
	_save_object(o, "teapot", "Teapot", [
		_part(SPHERE, Vector3(0.1, 0, 0), Vector3.ZERO, china),
		_part(CYL, Vector3(0.055, 0.03, 0), Vector3(0, 0.09, 0), china),
		_part(SPHERE, Vector3(0.018, 0, 0), Vector3(0, 0.115, 0), Color(0.3, 0.4, 0.8)),
		_part(CYL, Vector3(0.016, 0.11, 0), Vector3(0.11, 0.02, 0), china, Vector3(0, 0, -50)),
		_part(BOX, Vector3(0.02, 0.1, 0.03), Vector3(-0.11, 0.02, 0), china),
	], 1.2, {"sound": S.STONE, "impact": 0.4, "surface": _mat(Color.WHITE, 0.0, 0.25)})

	var hat := Color(0.85, 0.12, 0.1)
	_save_object(o, "garden_gnome", "Garden Gnome", [
		_part(CYL, Vector3(0.07, 0.03, 0), Vector3(0, -0.14, 0), Color(0.25, 0.55, 0.2)),
		_part(CYL, Vector3(0.065, 0.14, 0), Vector3(0, -0.06, 0), Color(0.2, 0.35, 0.75)),
		_part(CYL, Vector3(0.066, 0.015, 0), Vector3(0, -0.02, 0), BLACK, Vector3.ZERO, false),
		_part(SPHERE, Vector3(0.055, 0, 0), Vector3(0, 0.06, 0), Color(0.95, 0.8, 0.65)),
		_part(BOX, Vector3(0.09, 0.07, 0.04), Vector3(0, 0.03, -0.05), WHITE),
		_part(CYL, Vector3(0.055, 0.06, 0), Vector3(0, 0.12, 0), hat),
		_part(CYL, Vector3(0.035, 0.06, 0), Vector3(0, 0.17, 0), hat),
		_part(CYL, Vector3(0.015, 0.05, 0), Vector3(0, 0.22, 0), hat),
	], 2.5, {"sound": S.STONE, "impact": 0.8})

	var gold := Color(0.95, 0.75, 0.2)
	_save_object(o, "trophy", "Golden Trophy", [
		_part(BOX, Vector3(0.14, 0.05, 0.14), Vector3(0, -0.15, 0), Color(0.3, 0.2, 0.12)),
		_part(BOX, Vector3(0.1, 0.04, 0.1), Vector3(0, -0.105, 0), gold),
		_part(CYL, Vector3(0.018, 0.09, 0), Vector3(0, -0.04, 0), gold),
		_part(CYL, Vector3(0.07, 0.12, 0), Vector3(0, 0.07, 0), gold),
		_part(CYL, Vector3(0.075, 0.015, 0), Vector3(0, 0.13, 0), gold),
		_part(BOX, Vector3(0.02, 0.07, 0.02), Vector3(-0.085, 0.07, 0), gold),
		_part(BOX, Vector3(0.02, 0.07, 0.02), Vector3(0.085, 0.07, 0), gold),
	], 1.5, {"sound": S.METAL, "impact": 0.5, "surface": _mat(Color.WHITE, 0.9, 0.25)})

	_save_object(o, "brick", "Brick", [
		_part(BOX, Vector3(0.215, 0.065, 0.1), Vector3.ZERO, Color(0.66, 0.3, 0.22)),
	], 2.3, {"friction": 0.8, "bounce": 0.05, "sound": S.STONE, "impact": 1.2})

	_save_object(o, "plank", "Wooden Plank", [
		_part(BOX, Vector3(1.2, 0.03, 0.15), Vector3.ZERO, WOOD_LIGHT),
	], 2.5, {"sound": S.WOOD, "impact": 0.6})

	var pallet: Array = []
	for z in [-0.44, -0.22, 0.0, 0.22, 0.44]:
		pallet.append(_part(BOX, Vector3(1.0, 0.02, 0.12), Vector3(0, 0.05, z), Color(0.72, 0.58, 0.38)))
	for x in [-0.45, 0.0, 0.45]:
		pallet.append(_part(BOX, Vector3(0.1, 0.08, 1.0), Vector3(x, 0, 0), Color(0.6, 0.47, 0.3)))
	for z in [-0.45, 0.0, 0.45]:
		pallet.append(_part(BOX, Vector3(1.0, 0.02, 0.1), Vector3(0, -0.05, z), Color(0.72, 0.58, 0.38)))
	_save_object(o, "pallet", "Pallet", pallet, 15.0, {"sound": S.WOOD, "impact": 0.8})

	_save_object(o, "skittle", "Skittle", [
		_part(CYL, Vector3(0.04, 0.12, 0), Vector3(0, -0.1, 0), WHITE),
		_part(SPHERE, Vector3(0.048, 0, 0), Vector3(0, -0.07, 0), WHITE),
		_part(CYL, Vector3(0.022, 0.09, 0), Vector3(0, 0.03, 0), WHITE),
		_part(SPHERE, Vector3(0.032, 0, 0), Vector3(0, 0.1, 0), WHITE),
		_part(CYL, Vector3(0.024, 0.02, 0), Vector3(0, 0.02, 0), Color(0.85, 0.1, 0.1), Vector3.ZERO, false),
	], 1.5, {"friction": 0.4, "bounce": 0.3, "sound": S.WOOD, "impact": 0.3, "surface": _mat(Color.WHITE, 0.0, 0.3)})


# --- Destructibles

func _material(file: String, display: String, color: Color, strength: float, density: float,
		rubble: float, sound: int, multipliers: Vector3, friction := 0.6, bounce := 0.05) -> VoxelMaterialDefinition:
	var material := VoxelMaterialDefinition.new()
	material.display_name = display
	material.color = color
	material.strength = strength
	material.density = density
	material.rubble_fraction = rubble
	material.impact_sound = sound
	material.blunt_multiplier = multipliers.x
	material.sharp_multiplier = multipliers.y
	material.pierce_multiplier = multipliers.z
	material.friction = friction
	material.bounce = bounce
	ResourceSaver.save(material, MATERIALS_DIR + file + ".tres")
	return load(MATERIALS_DIR + file + ".tres")


## Writes a .vox from `paint(x, y, z) -> Color` (alpha 0 = empty) and a structure
## definition using it.
func _vox_structure(file: String, display: String, size: Vector3i, voxel_size: float,
		paint: Callable, material: VoxelMaterialDefinition, extras: Array = [], anchored := false) -> void:
	var cells := {}
	for x in size.x:
		for y in size.y:
			for z in size.z:
				var color: Color = paint.call(x, y, z)
				if color.a > 0.0:
					cells[Vector3i(x, y, z)] = Color8(color.r8, color.g8, color.b8)
	var vox_path := VOX_DIR + file + ".vox"
	VoxFile.write_cells(ProjectSettings.globalize_path(vox_path), size, cells)
	var structure := VoxelStructureDefinition.new()
	structure.display_name = display
	structure.voxel_size = voxel_size
	structure.anchor_mode = VoxelStructureDefinition.AnchorMode.BOTTOM_LAYER if anchored \
		else VoxelStructureDefinition.AnchorMode.NONE
	structure.spawn_category = "Destructible"
	structure.vox_file = vox_path
	structure.vox_material = material
	var typed: Array[VoxelMaterialDefinition] = []
	typed.assign(extras)
	structure.vox_extra_materials = typed
	ResourceSaver.save(structure, STRUCTURES_DIR + file + ".tres")


func _box_structure(file: String, display: String, boxes: Array, anchored: bool, category: String) -> void:
	var structure := VoxelStructureDefinition.new()
	structure.display_name = display
	structure.voxel_size = 0.1
	structure.anchor_mode = VoxelStructureDefinition.AnchorMode.BOTTOM_LAYER if anchored \
		else VoxelStructureDefinition.AnchorMode.NONE
	structure.spawn_category = category
	var typed: Array[VoxelFillBox] = []
	typed.assign(boxes)
	structure.boxes = typed
	ResourceSaver.save(structure, STRUCTURES_DIR + file + ".tres")


func _fill(min_cell: Vector3i, size: Vector3i, material: VoxelMaterialDefinition, tint := Color(0, 0, 0, 0)) -> VoxelFillBox:
	var box := VoxelFillBox.new()
	box.min_cell = min_cell
	box.size = size
	box.material = material
	box.color_override = tint
	return box


## Stable pseudo-random 0..1 per cell, so models are the same every run.
func _noise(x: int, y: int, z: int, salt := 0) -> float:
	return float(absi((x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (salt * 2654435)) % 1000) / 999.0


func _make_destructibles() -> void:
	var wood: VoxelMaterialDefinition = load(MATERIALS_DIR + "wood.tres")
	var brick: VoxelMaterialDefinition = load(MATERIALS_DIR + "brick.tres")
	var concrete: VoxelMaterialDefinition = load(MATERIALS_DIR + "concrete.tres")
	var glass := _material("glass", "Glass", Color8(175, 220, 235), 1.5, 2500.0, 0.6, S.GLASS, Vector3(2, 2, 2), 0.4, 0.1)
	var melon := _material("melon", "Watermelon", Color8(205, 45, 55), 2.5, 350.0, 0.4, S.CARDBOARD, Vector3(1.5, 2, 1.5), 0.7, 0.15)
	var pumpkin := _material("pumpkin", "Pumpkin", Color8(235, 120, 30), 3.5, 400.0, 0.35, S.CARDBOARD, Vector3(1.2, 2, 1.2), 0.7, 0.1)
	var snow := _material("snow", "Snow", Color8(240, 244, 250), 1.5, 150.0, 0.35, S.CARDBOARD, Vector3(1.5, 1.5, 1.5), 0.3, 0.0)

	var dark_wood := Color(0.45, 0.3, 0.17)
	_vox_structure("chair", "Wooden Chair", Vector3i(9, 18, 9), 0.05, func(x: int, y: int, z: int) -> Color:
		var corner_leg := (x == 0 or x == 8) and (z == 0 or z == 8) and y < 8
		if corner_leg:
			return dark_wood
		if y == 8:
			return WOOD_LIGHT
		if z == 8 and y > 8 and (x <= 1 or x >= 7 or y >= 15):
			return WOOD
		return Color(0, 0, 0, 0)
	, wood)

	_vox_structure("stool", "Stool", Vector3i(8, 10, 8), 0.05, func(x: int, y: int, z: int) -> Color:
		var centre := Vector2(x - 3.5, z - 3.5)
		if y == 9 and centre.length() <= 3.9:
			return WOOD_LIGHT
		if y < 9 and Vector2i(x, z) in [Vector2i(1, 2), Vector2i(6, 2), Vector2i(3, 6)]:
			return dark_wood
		return Color(0, 0, 0, 0)
	, wood)

	var book_colors := [Color(0.7, 0.15, 0.15), Color(0.15, 0.3, 0.65), Color(0.2, 0.5, 0.25),
		Color(0.85, 0.7, 0.2), Color(0.45, 0.25, 0.15), Color(0.9, 0.9, 0.85)]
	_vox_structure("bookshelf", "Bookshelf", Vector3i(16, 24, 6), 0.05, func(x: int, y: int, z: int) -> Color:
		if x == 0 or x == 15 or y == 0 or y == 23 or y == 8 or y == 16 or z == 5:
			return WOOD
		# Books: two-voxel-wide spines of varying height in each compartment.
		if z >= 4:
			return Color(0, 0, 0, 0)
		var shelf_base := 1 if y < 8 else (9 if y < 16 else 17)
		var spine := x / 2
		var height := 4 + int(_noise(spine, shelf_base, 0) * 3.0)
		if y - shelf_base < height and _noise(spine, shelf_base, 1) > 0.12:
			return book_colors[int(_noise(spine, shelf_base, 2) * book_colors.size()) % book_colors.size()]
		return Color(0, 0, 0, 0)
	, wood)

	_vox_structure("breakable_crate", "Breakable Crate", Vector3i(10, 10, 10), 0.05, func(x: int, y: int, z: int) -> Color:
		var edges := int(x == 0 or x == 9) + int(y == 0 or y == 9) + int(z == 0 or z == 9)
		if edges == 0:
			return Color(0, 0, 0, 0)
		if edges >= 2:
			return dark_wood
		return WOOD_LIGHT if (x + y + z) / 3 % 2 == 0 else WOOD
	, wood)

	_vox_structure("watermelon", "Watermelon", Vector3i(11, 9, 9), 0.04, func(x: int, y: int, z: int) -> Color:
		var p := Vector3((x - 5.0) / 5.5, (y - 4.0) / 4.5, (z - 4.0) / 4.5)
		var d := p.length()
		if d > 1.0:
			return Color(0, 0, 0, 0)
		if d > 0.82:
			var stripe := int(floor((atan2(p.y, p.z) + PI) / TAU * 12.0)) % 2 == 0
			return Color(0.15, 0.45, 0.15) if stripe else Color(0.25, 0.6, 0.22)
		if d > 0.74:
			return Color(0.85, 0.95, 0.75)
		if _noise(x, y, z, 7) > 0.93:
			return BLACK
		return Color8(205, 45, 55)
	, melon)

	_vox_structure("pumpkin", "Pumpkin", Vector3i(11, 11, 11), 0.04, func(x: int, y: int, z: int) -> Color:
		if y >= 9:
			return Color(0.35, 0.45, 0.15) if x == 5 and z == 5 else Color(0, 0, 0, 0)
		var p := Vector3((x - 5.0) / 5.5, (y - 4.0) / 4.5, (z - 5.0) / 5.5)
		var d := p.length()
		if d > 1.0 or d < 0.68:
			return Color(0, 0, 0, 0)
		if d > 0.84:
			var rib := int(floor((atan2(p.z, p.x) + PI) / TAU * 10.0)) % 2 == 0
			return Color8(235, 120, 30) if rib else Color(0.82, 0.4, 0.08)
		return Color(1.0, 0.8, 0.45)
	, pumpkin)

	_vox_structure("glass_pane", "Glass Pane", Vector3i(16, 20, 1), 0.05, func(x: int, y: int, z: int) -> Color:
		if x == 0 or x == 15 or y == 0 or y == 19:
			return WOOD
		return Color8(175, 220, 235)
	, wood, [glass], true)

	_vox_structure("snowman", "Snowman", Vector3i(11, 23, 11), 0.05, func(x: int, y: int, z: int) -> Color:
		var c := Vector3(x, y, z)
		# Face, buttons and nose sit on the front (-Z side).
		if Vector2i(x, z) in [Vector2i(4, 2), Vector2i(6, 2)] and y == 20:
			return BLACK
		if x == 5 and z in [0, 1] and y == 19:
			return Color(1.0, 0.5, 0.05)
		if x == 5 and z == 1 and y in [12, 14]:
			return BLACK
		if y == 13 and (x <= 1 or x >= 9) and z == 5:
			return Color(0.4, 0.25, 0.12)
		if c.distance_to(Vector3(5, 5, 5)) <= 5.0 or c.distance_to(Vector3(5, 13, 5)) <= 3.8 \
				or c.distance_to(Vector3(5, 19.5, 5)) <= 2.8:
			return Color8(240, 244, 250)
		return Color(0, 0, 0, 0)
	, snow)

	_box_structure("brick_chimney", "Brick Chimney", [
		_fill(Vector3i(-3, 0, -3), Vector3i(6, 24, 1), brick),
		_fill(Vector3i(-3, 0, 2), Vector3i(6, 24, 1), brick),
		_fill(Vector3i(-3, 0, -2), Vector3i(1, 24, 4), brick),
		_fill(Vector3i(2, 0, -2), Vector3i(1, 24, 4), brick),
		_fill(Vector3i(-4, 22, -4), Vector3i(8, 2, 8), concrete),
	], true, "Structures")

	_box_structure("concrete_bollard", "Concrete Bollard", [
		_fill(Vector3i(-2, 0, -2), Vector3i(4, 9, 4), concrete),
		_fill(Vector3i(-2, 6, -2), Vector3i(4, 1, 4), concrete, Color(1.0, 0.8, 0.1)),
	], true, "Structures")
