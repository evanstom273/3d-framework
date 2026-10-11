extends SceneTree
## Explicit advanced-only authoring manifest. Run with --script; never touches
## existing hand-authored props. Re-authoring requires -- --replace-owned.
const TOOLS = {
	"blowtorch": ["Blowtorch", "heat", 1.6], "chainsaw": ["Chainsaw", "saw", 5.2],
	"angle_grinder": ["Angle Grinder", "grind", 2.5], "pressure_washer": ["Pressure Washer", "wash", 3.0],
	"glue_gun": ["Glue Gun", "glue", 0.7], "welding_torch": ["Welding Torch", "weld", 1.6],
	"nail_gun": ["Nail Gun", "nail", 3.1], "power_drill": ["Power Drill", "screw", 1.8],
	"staple_gun": ["Staple Gun", "staple", 0.8], "caulking_gun": ["Caulking Gun", "sealant", 1.2],
	"rope_tool": ["Rope Tool", "rope", 2.0], "chain_tool": ["Chain Tool", "chain", 4.0],
	"cable_tool": ["Cable Tool", "cable", 2.8], "spring_tool": ["Spring Tool", "spring", 1.4],
	"elastic_band_tool": ["Elastic Band Tool", "elastic", 0.6], "hinge_tool": ["Hinge Tool", "hinge", 1.2],
	"fire_extinguisher": ["Fire Extinguisher", "extinguish", 6.0], "leaf_blower": ["Leaf Blower", "blow", 4.5],
	"vacuum_cleaner": ["Vacuum Cleaner", "vacuum", 4.0], "magnet_gun": ["Magnet Gun", "magnet", 3.5],
	"physics_grabber": ["Physics Grabber", "grabber", 4.0], "shovel": ["Shovel", "shovel", 2.6],
	"paint_sprayer": ["Paint Sprayer", "paint", 1.2], "marker_gun": ["Marker / Label Gun", "marker", 0.8],
	"spray_foam_gun": ["Spray Foam Gun", "foam", 1.3], "plunger_launcher": ["Plunger Launcher", "plunger", 2.5],
}
const CONNECTIONS = {
	"staple": [0, 150.0, 15.0], "sealant": [2, 250.0, 25.0], "glue": [0, 350.0, 35.0],
	"nail": [0, 800.0, 80.0], "screw": [0, 1400.0, 140.0], "weld": [0, 8000.0, 800.0],
	"rope": [3, 2500.0, 250.0], "cable": [5, 5000.0, 500.0], "chain": [4, 6500.0, 650.0],
	"spring": [6, 2000.0, 200.0], "elastic": [7, 1000.0, 100.0], "hinge": [1, 1800.0, 180.0],
	"suction": [8, 180.0, 18.0],
}
const PROFILES = {
	"wood": [1.5, 2.0, 0.3, 0.0, false, true, false, true],
	"soft": [2.0, 2.5, 0.15, 0.0, false, true, false, true],
	"steel": [0.25, 0.08, 1.5, 0.0, true, true, true, false],
	"nonmagnetic_metal": [0.35, 0.1, 1.2, 0.0, false, true, true, false],
	"masonry": [0.03, 0.0, 0.7, 0.0, false, true, false, false],
	"glass": [0.08, 0.0, 2.0, 0.0, false, false, false, false],
	"plastic": [0.9, 1.0, 0.4, 0.0, false, true, false, true],
	"soil": [0.0, 0.1, 0.1, 3.0, false, false, false, false],
}
const EXTRA_MODELS = ["pulley", "plunger", "nail_projectile"]
const SAMPLE_NAMES = ["wood_sample", "steel_sample", "diggable_pile", "support"]
var manifest: Array[String] = []
var replace_owned: bool = false
var profiles: Dictionary = {}
var connections: Dictionary = {}
var definitions: Dictionary = {}
var cells: Dictionary = {}
var parts: Array[PhysicsShapePart] = []
var color: Color
var grid_origin := Vector3(-0.8, -0.9, -1.0)
const CELL = 0.025
const DARK = Color(0.12, 0.14, 0.16)
const SILVER = Color(0.57, 0.6, 0.62)
const WOOD = Color(0.55, 0.35, 0.18)

func _initialize() -> void:
	replace_owned = OS.get_cmdline_user_args().has("--replace-owned")
	# Tools, pulley, plunger, nail and crowbar_pry belong to tools/generate_advanced_tools.gd;
	# this script only loads them for the lab.
	for key in CONNECTIONS: manifest.append("res://contraptions/config/%s.tres" % key)
	for key in PROFILES: manifest.append("res://contraptions/materials/profiles/%s.tres" % key)
	for key in ["foam", "foam_soft", "soil"]: manifest.append("res://contraptions/materials/%s.tres" % key)
	for key in SAMPLE_NAMES: manifest.append("res://contraptions/assets/%s.tres" % key)
	manifest.append("res://contraptions/contraption_lab.tscn")
	for path in manifest:
		if FileAccess.file_exists(path) and not replace_owned:
			push_error("Refusing overwrite; use --replace-owned for the explicit manifest: " + path); quit(1); return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	for key in PROFILES:
		var values: Array = PROFILES[key]
		var profile := ToolMaterialProfile.new()
		var properties := ["heat_response", "saw_response", "grind_response", "dig_response", "magnetic", "fastening", "weldable", "stapleable"]
		for i in properties.size(): profile.set(properties[i], values[i])
		_save(profile, "res://contraptions/materials/profiles/%s.tres" % key); profiles[key] = profile
	for key in CONNECTIONS:
		var definition := ConnectionDefinition.new()
		definition.display_name = key.capitalize(); definition.kind = CONNECTIONS[key][0]
		definition.strength = CONNECTIONS[key][1]; definition.torque_resistance = CONNECTIONS[key][2]
		definition.removal_resistance = sqrt(definition.strength) * 0.8
		definition.metal_only = key == "weld"; definition.soft_only = key == "staple"
		if key in ["rope", "chain", "cable"]: definition.compliance = 0.000005
		if key == "chain": definition.strand_mass_per_metre = 0.8; definition.color = SILVER
		if key == "cable": definition.strand_mass_per_metre = 0.3; definition.color = Color(0.2, 0.2, 0.22)
		if key == "spring": definition.compliance = 0.004; definition.color = SILVER
		if key == "elastic": definition.compliance = 0.012; definition.maximum_stretch = 2.5; definition.color = Color(0.7, 0.18, 0.12)
		if key == "sealant": definition.compliance = 0.004; definition.damping = 0.8
		if key == "suction": definition.lifetime = 30
		if key == "nail": definition.maximum_gap = 0.25
		_save(definition, "res://contraptions/config/%s.tres" % key); connections[key] = definition
	for key in ["foam", "foam_soft", "soil"]:
		var material := VoxelMaterialDefinition.new()
		material.display_name = key.capitalize(); material.color = Color(0.92, 0.86, 0.58) if key != "soil" else Color(0.3, 0.2, 0.1)
		material.strength = 2.5 if key == "foam" else 0.6
		material.density = 35 if key != "soil" else 900
		material.tool_profile = profiles.soft if key != "soil" else profiles.soil
		material.rubble_fraction = 0.1
		_save(material, "res://contraptions/materials/%s.tres" % key)
	for key in TOOLS:
		definitions[key] = load("res://props/tools/advanced/%s.tres" % key)
	definitions.pulley = load("res://props/advanced/pulley.tres")
	_make_samples()
	_make_lab()
	print("ADVANCED CATALOGUE: 26 tools, 3 component models, profiles, connection presets and lab authored")
	quit()

func _save(resource: Resource, path: String) -> void:
	assert(manifest.has(path), "Output absent from manifest: " + path)
	assert(ResourceSaver.save(resource, path) == OK)
	resource.take_over_path(path)

func _box(center: Vector3, size: Vector3, tint: Color, collision: bool = true) -> void:
	var low := Vector3i(((center - size * 0.5 - grid_origin) / CELL).floor())
	var high := Vector3i(((center + size * 0.5 - grid_origin) / CELL).ceil())
	for x in range(low.x, high.x):
		for y in range(low.y, high.y):
			for z in range(low.z, high.z): cells[Vector3i(x, y, z)] = tint
	if collision:
		var part := PhysicsShapePart.new(); part.size = size; part.position = center; parts.append(part)

func _cylinder(center: Vector3, radius: float, height: float, tint: Color, axis: int = 1, collision: bool = true) -> void:
	var size := Vector3.ONE * radius * 2; size[axis] = height
	var low := Vector3i(((center - size * 0.5 - grid_origin) / CELL).floor())
	var high := Vector3i(((center + size * 0.5 - grid_origin) / CELL).ceil())
	for x in range(low.x, high.x):
		for y in range(low.y, high.y):
			for z in range(low.z, high.z):
				var p := (Vector3(x, y, z) + Vector3.ONE * 0.5) * CELL + grid_origin - center
				p[axis] = 0
				if p.length_squared() <= radius * radius: cells[Vector3i(x, y, z)] = tint
	if collision:
		var part := PhysicsShapePart.new(); part.shape_type = PhysicsShapePart.ShapeType.CYLINDER
		part.radius = radius; part.height = height; part.position = center
		part.rotation_degrees = Vector3(90, 0, 0) if axis == 2 else (Vector3(0, 0, 90) if axis == 0 else Vector3.ZERO)
		parts.append(part)

func _model(key: String) -> void:
	var path := "res://props/vox/advanced/%s.vox" % key
	assert(manifest.has(path))
	assert(VoxFile.write_cells(path, Vector3i(64, 80, 64), cells) == OK)

func _make_tool(key: String, index: int) -> void:
	cells.clear(); parts.clear()
	color = [Color(0.77, 0.25, 0.10), Color(0.16, 0.39, 0.48), Color(0.73, 0.58, 0.12), Color(0.25, 0.45, 0.25)][index % 4]
	var operation: String = TOOLS[key][1]
	# Authored silhouettes: each operation adds its own functional head, supply and grip.
	match operation:
		"shovel":
			_box(Vector3(0, -0.02, -0.1), Vector3(0.06, 0.08, 0.95), WOOD)
			_box(Vector3(0, -0.06, -0.68), Vector3(0.36, 0.035, 0.4), SILVER)
			_box(Vector3(-0.17, 0.0, -0.68), Vector3(0.035, 0.12, 0.4), SILVER)
			_box(Vector3(0.17, 0.0, -0.68), Vector3(0.035, 0.12, 0.4), SILVER)
			_box(Vector3(0, 0, -0.48), Vector3(0.36, 0.12, 0.035), SILVER)
			_box(Vector3(0, 0, 0.4), Vector3(0.25, 0.04, 0.035), DARK)
		"rope", "chain", "cable":
			_cylinder(Vector3(0, 0.03, -0.1), 0.16, 0.19, Color(0.55, 0.39, 0.2) if operation == "rope" else SILVER, 0)
			for x in [-0.12, 0.12]: _cylinder(Vector3(x, 0.03, -0.1), 0.19, 0.035, color, 0)
			_box(Vector3(0, 0.27, -0.1), Vector3(0.25, 0.06, 0.055), DARK)
			_box(Vector3(0.13, 0.13, -0.1), Vector3(0.04, 0.25, 0.05), color)
			_box(Vector3(0, -0.03, -0.32), Vector3(0.045, 0.045, 0.18), SILVER)
		"spring", "elastic":
			for i in 9:
				_cylinder(Vector3(0, 0.04, -0.3 + i * 0.035), 0.085, 0.018, SILVER if operation == "spring" else color, 2, false)
			_box(Vector3(0, -0.03, -0.13), Vector3(0.18, 0.055, 0.36), color)
			_box(Vector3(0, -0.14, 0.01), Vector3(0.07, 0.2, 0.08), DARK)
		"hinge":
			for x in [-0.09, 0.09]: _box(Vector3(x, 0.04, -0.1), Vector3(0.14, 0.26, 0.035), color)
			_cylinder(Vector3(0, 0.04, -0.12), 0.035, 0.3, SILVER)
			_box(Vector3(0, -0.2, -0.1), Vector3(0.07, 0.18, 0.075), DARK)
		"extinguish", "vacuum":
			_cylinder(Vector3(0, -0.1, 0), 0.14 if operation == "extinguish" else 0.19, 0.45, Color(0.72, 0.08, 0.06) if operation == "extinguish" else color)
			_box(Vector3(0, 0.2, 0), Vector3(0.075, 0.08, 0.22), DARK)
			_cylinder(Vector3(0.16, 0.16, -0.25), 0.045, 0.55, DARK, 2)
			_cylinder(Vector3(0.16, 0.16, -0.54), 0.065, 0.10, SILVER, 2)
		"saw":
			_box(Vector3(0, 0.01, -0.05), Vector3(0.26, 0.22, 0.34), color)
			_box(Vector3(0, 0.03, -0.47), Vector3(0.06, 0.17, 0.58), SILVER)
			for i in 10:
				for y in [-0.07, 0.13]: _box(Vector3(0, y, -0.25 - i * 0.05), Vector3(0.075, 0.025, 0.025), DARK, false)
			_box(Vector3(0, 0.2, -0.13), Vector3(0.3, 0.055, 0.06), DARK)
			_box(Vector3(0.14, 0.11, -0.13), Vector3(0.05, 0.22, 0.06), DARK)
			_box(Vector3(0, 0.04, 0.22), Vector3(0.055, 0.06, 0.24), DARK)
		"grind":
			_cylinder(Vector3(0, 0.03, 0), 0.07, 0.33, color, 2)
			_cylinder(Vector3(0, 0.03, -0.22), 0.14, 0.035, SILVER)
			_cylinder(Vector3(0.16, 0.04, -0.1), 0.035, 0.23, DARK, 0)
		"blow":
			_cylinder(Vector3(0, -0.03, 0), 0.19, 0.19, color, 0)
			_cylinder(Vector3(0, 0.02, -0.4), 0.065, 0.65, DARK, 2)
			_box(Vector3(0, 0.22, 0), Vector3(0.07, 0.055, 0.27), DARK)
		"magnet", "grabber":
			_box(Vector3(0, 0, 0), Vector3(0.19, 0.2, 0.27), color)
			for x in [-0.13, 0.13]:
				_box(Vector3(x, 0.08, -0.3), Vector3(0.065, 0.08, 0.38), color)
				_box(Vector3(x, 0.08, -0.5), Vector3(0.065, 0.08, 0.06), SILVER)
			if operation == "grabber": _cylinder(Vector3(0, 0.08, -0.25), 0.06, 0.15, Color(0.2, 0.8, 0.9), 2)
			_box(Vector3(0, -0.16, 0.02), Vector3(0.075, 0.22, 0.1), DARK)
		_:
			_box(Vector3(0, 0.04, -0.1), Vector3(0.12, 0.14, 0.26), color)
			_box(Vector3(0, -0.11, 0), Vector3(0.07, 0.2, 0.09), DARK)
			var length: float = 0.55 if operation in ["wash", "weld", "plunger"] else 0.18
			_cylinder(Vector3(0, 0.06, -0.25 - length * 0.5), 0.065 if operation == "plunger" else 0.025, length, SILVER, 2)
			match operation:
				"heat": _cylinder(Vector3(0, -0.18, 0.07), 0.085, 0.24, Color(0.2, 0.35, 0.7))
				"weld": _box(Vector3(0, -0.1, 0.15), Vector3(0.03, 0.03, 0.22), DARK)
				"glue": _cylinder(Vector3(0, 0.07, 0.17), 0.025, 0.29, Color(0.85, 0.82, 0.69), 2)
				"nail": _box(Vector3(0, -0.13, -0.19), Vector3(0.065, 0.22, 0.35), SILVER)
				"screw": _box(Vector3(0, -0.25, 0.02), Vector3(0.15, 0.09, 0.16), color)
				"staple": _box(Vector3(0, -0.09, -0.12), Vector3(0.12, 0.08, 0.25), SILVER)
				"sealant": _cylinder(Vector3(0, 0.06, -0.2), 0.06, 0.42, Color(0.84, 0.82, 0.72), 2)
				"paint", "foam": _cylinder(Vector3(0, 0.22, -0.12), 0.10, 0.2, Color(0.85, 0.8, 0.6))
				"marker": _box(Vector3(0, 0.1, -0.05), Vector3(0.14, 0.1, 0.11), Color(0.9, 0.87, 0.72))
	_model(key)
	var definition := PhysicsObjectDefinition.new()
	definition.display_name = TOOLS[key][0]; definition.mass = TOOLS[key][2]
	definition.shape_type = PhysicsObjectDefinition.ShapeType.COMPOUND; definition.parts = parts.duplicate()
	definition.vox_model = "res://props/vox/advanced/%s.vox" % key; definition.vox_voxel_size = CELL; definition.vox_origin = grid_origin
	definition.tool_profile = profiles.steel; definition.impact_sound = ImpactFeedback.Sound.METAL
	var tool := PhysicsToolDefinition.new()
	tool.category = PhysicsToolDefinition.Category.UTILITY; tool.motion_strikes = false; tool.charge_time = 0
	tool.rest_position = Vector3(0.26, -0.28, -0.34); tool.rest_rotation_degrees = Vector3.ZERO
	tool.windup_position = tool.rest_position; tool.strike_position = Vector3(0.12, -0.19, -0.4)
	tool.windup_rotation_degrees = Vector3.ZERO; tool.strike_rotation_degrees = Vector3.ZERO
	var action := ToolActionDefinition.new(); action.operation = operation
	action.primary_hint = "Hold LMB: " + operation if operation in ["heat", "saw", "grind", "wash", "screw", "extinguish", "blow", "vacuum", "magnet", "grabber", "shovel", "paint", "foam"] else "LMB: " + operation
	action.secondary_hint = "RMB: clear / remove / cancel"
	if operation == "vacuum": action.secondary_hint = "RMB: empty"
	if operation == "screw": action.secondary_hint = "RMB: reverse / remove screw"
	if operation == "plunger": action.secondary_hint = "RMB: reload nearby plunger"
	if CONNECTIONS.has(operation): action.connection = connections[operation]
	if operation == "plunger": action.connection = connections.suction
	action.range_metres = 10 if operation == "grabber" else (6 if operation in ["blow", "magnet", "vacuum", "wash"] else 3)
	action.force = 1400 if operation == "grabber" else (240 if operation in ["magnet", "blow"] else 90)
	action.sound_frequency = 50 + index * 12; action.effect_color = color
	if operation in ["wash", "extinguish"]: action.effect_color = Color(0.7, 0.85, 0.95)
	if operation == "heat": action.effect_color = Color(1, 0.6, 0.06); action.region_size = Vector3(0.18, 0.18, 0.15)
	if operation == "saw": action.nozzle = Vector3(0, 0.03, -0.5); action.region_size = Vector3(0.12, 0.23, 0.6); action.rate = 28
	if operation == "grind": action.nozzle = Vector3(0, 0.03, -0.22); action.region_size = Vector3(0.28, 0.08, 0.28); action.rate = 25
	if operation in ["saw", "grind"]: tool.strike_position = Vector3(0.035, -0.03, -0.4)
	action.moving_part_position = action.nozzle
	if operation == "staple": action.probe_depth = 0.09
	if operation == "shovel":
		action.region_size = Vector3(0.35, 0.18, 0.4); action.rate = 30
		definition.equipped_collision_parts = PackedInt32Array([1, 2, 3, 4])
		var container := PhysicsContainerDefinition.new(); container.form = PhysicsContainerDefinition.Form.CUSTOM
		container.inner_center = Vector3(0, 0.03, -0.68); container.inner_size = Vector3(0.31, 0.12, 0.36)
		container.stabilise_when_equipped = true; definition.container = container
	tool.advanced_action = action; definition.tool = tool
	_save(definition, "res://props/tools/advanced/%s.tres" % key); definitions[key] = definition

func _make_component(key: String) -> void:
	cells.clear(); parts.clear()
	var definition := PhysicsObjectDefinition.new()
	definition.shape_type = PhysicsObjectDefinition.ShapeType.COMPOUND
	definition.tool_profile = profiles.steel
	match key:
		"pulley":
			_cylinder(Vector3(0, 0.12, 0), 0.15, 0.06, SILVER, 2)
			for z in [-0.06, 0.06]: _box(Vector3(0, 0.2, z), Vector3(0.055, 0.35, 0.035), DARK)
			_box(Vector3(0, 0.37, 0), Vector3(0.22, 0.04, 0.19), SILVER)
			definition.mass = 1.5; definition.contraption_component = "pulley"
		"plunger":
			_cylinder(Vector3(0, 0, 0), 0.075, 0.075, Color(0.65, 0.16, 0.1), 2)
			_cylinder(Vector3(0, 0, 0.16), 0.022, 0.28, WOOD, 2)
			definition.mass = 0.2; definition.contraption_component = "plunger"
		"nail_projectile":
			_box(Vector3.ZERO, Vector3(0.025, 0.025, 0.09), SILVER)
			definition.mass = 0.015
	_model(key)
	definition.parts = parts.duplicate(); definition.vox_model = "res://props/vox/advanced/%s.vox" % key
	definition.vox_voxel_size = CELL; definition.vox_origin = grid_origin; definition.continuous_cd = true
	definition.display_name = key.capitalize(); definition.spawn_category = "Props"
	_save(definition, "res://contraptions/assets/nail_projectile.tres" if key == "nail_projectile" else "res://props/advanced/%s.tres" % key)
	definitions[key] = definition

func _make_samples() -> void:
	for key in SAMPLE_NAMES:
		var definition := VoxelStructureDefinition.new()
		definition.display_name = key.capitalize(); definition.voxel_size = 0.1
		definition.anchor_mode = VoxelStructureDefinition.AnchorMode.NONE if key.ends_with("sample") else VoxelStructureDefinition.AnchorMode.BOTTOM_LAYER
		var box := VoxelFillBox.new()
		box.size = Vector3i(12, 7, 2) if key.ends_with("sample") else (Vector3i(15, 4, 12) if key == "diggable_pile" else Vector3i(3, 36, 3))
		box.material = load("res://props/voxel_materials/wood.tres")
		if key == "steel_sample": box.material = load("res://house/assets/materials/painted_metal.tres")
		if key == "diggable_pile": box.material = load("res://contraptions/materials/soil.tres")
		definition.boxes = [box]
		_save(definition, "res://contraptions/assets/%s.tres" % key)

func _add(root: Node, node: Node, name_text: String, position: Vector3 = Vector3.ZERO) -> Node:
	root.add_child(node); node.name = name_text; node.owner = root
	if node is Node3D: node.position = position
	return node

func _make_lab() -> void:
	var lab := Node3D.new(); lab.name = "ContraptionLab"; lab.set_script(load("res://contraptions/contraption_lab.gd"))
	var source := load("res://house/house.tscn") as PackedScene
	var state := source.get_state()
	for index in state.get_node_count():
		if state.get_node_type(index) != &"WorldEnvironment": continue
		var environment := WorldEnvironment.new()
		for property in state.get_node_property_count(index):
			if state.get_node_property_name(index, property) == &"environment": environment.environment = state.get_node_property_value(index, property)
		_add(lab, environment, "WorldEnvironment")
	var ground := StaticBody3D.new(); _add(lab, ground, "Ground", Vector3(0, -0.25, 0))
	var collision := CollisionShape3D.new(); var shape := BoxShape3D.new(); shape.size = Vector3(22, 0.5, 24); collision.shape = shape
	ground.add_child(collision); collision.owner = lab
	var visual := MeshInstance3D.new(); var mesh := BoxMesh.new(); mesh.size = shape.size; visual.mesh = mesh
	var material := StandardMaterial3D.new(); material.albedo_color = Color(0.28, 0.31, 0.27); visual.material_override = material
	ground.add_child(visual); visual.owner = lab
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-55, -25, 0); sun.shadow_enabled = true; _add(lab, sun, "Sun")
	var player := (load("res://player.tscn") as PackedScene).instantiate(); _add(lab, player, "Player", Vector3(0, 0.05, 7))
	var i := 0
	for key in TOOLS:
		var position := Vector3(-6.5 + (i % 9) * 1.6, 0.7, 4.0 - floori(i / 9.0) * 1.8)
		_add(lab, PhysicsProp.create(definitions[key]), key, position)
		var label := Label3D.new(); label.text = TOOLS[key][0]; label.font_size = 32; label.pixel_size = 0.005
		label.rotation_degrees.x = -65; _add(lab, label, key + "Label", position + Vector3(0, -0.6, 0.5)); i += 1
	for key in SAMPLE_NAMES:
		var voxel := VoxelBody.new(); voxel.structure = load("res://contraptions/assets/%s.tres" % key)
		var x := -7.0 + SAMPLE_NAMES.find(key) * 3.5
		_add(lab, voxel, key, Vector3(x, 0.1, -3))
	for example in [["FixedPulley", Vector3(-4, 3.0, -7)], ["MovingPulley", Vector3(2, 1.8, -7)]]:
		_add(lab, PhysicsProp.create(definitions.pulley), example[0], example[1])
	for example in [["Bucket", Vector3(-5, 1.5, -7)], ["Counterweight", Vector3(-3, 1.5, -7)], ["MovingLoad", Vector3(2, 0.8, -7)], ["HoistCounterweight", Vector3(4, 1.6, -7)], ["SpringLoad", Vector3(6, 2.1, -7)], ["ElasticLoad", Vector3(8, 2.1, -7)]]:
		var definition: PhysicsObjectDefinition = load("res://bucket.tres".replace("res://", "res://props/")) if example[0] == "Bucket" else load("res://wooden_block.tres".replace("res://", "res://props/"))
		_add(lab, PhysicsProp.create(definition), example[0], example[1])
	var fixed := StaticBody3D.new(); _add(lab, fixed, "Overhead", Vector3(1, 3.8, -7))
	var beamshape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(16, 0.25, 0.3); beamshape.shape = box
	fixed.add_child(beamshape); beamshape.owner = lab
	var beam := MeshInstance3D.new(); var beammesh := BoxMesh.new(); beammesh.size = box.size; beam.mesh = beammesh; fixed.add_child(beam); beam.owner = lab
	var sign := Label3D.new(); sign.text = "CONTRAPTION LAB\nF equip · LMB use · RMB secondary · Q mode · Wheel setting\nTab spawn · R reset\nSamples / dig pile ahead. Hoists, spring and elastic at rear."
	sign.font_size = 40; sign.pixel_size = 0.008; _add(lab, sign, "Instructions", Vector3(0, 2.8, -4))
	var packed := PackedScene.new(); assert(packed.pack(lab) == OK); _save(packed, "res://contraptions/contraption_lab.tscn")
	lab.free()
