extends SceneTree
## Generates the destructible furniture library: one MagicaVoxel model and one
## VoxelStructureDefinition per piece, under res://furniture/. Each voxel keeps
## its real material (wood, fabric, steel, glass...) through the definition's
## palette-index map, so pieces break according to what they're made of.
##
## Run:  godot --headless --path . -s res://tools/generate_furniture.gd
##       ... -- sofa_three_seater armchair      (only these)
##       ... -- category=Living                (one catalogue)
##
## Only files listed in furniture/manifest.json (i.e. made by this script) are
## ever overwritten; anything else at a target path is left alone and reported.
## Materials are created once and then left for you to tune.

const OUT := "res://furniture/"
const VOX := "res://furniture/vox/"
const MATERIALS := "res://furniture/materials/"
const MANIFEST := "res://furniture/manifest.json"
const GLASS_LOOK := "res://house/assets/materials/transparent_glass.tres"

const CATALOGUES := [
	"res://tools/furniture/catalogue_living.gd",
	"res://tools/furniture/catalogue_kitchen.gd",
	"res://tools/furniture/catalogue_bedroom.gd",
	"res://tools/furniture/catalogue_bathroom.gd",
	"res://tools/furniture/catalogue_office.gd",
	"res://tools/furniture/catalogue_laboratory.gd",
	"res://tools/furniture/catalogue_workshop.gd",
	"res://tools/furniture/catalogue_garden.gd",
	"res://tools/furniture/catalogue_utility.gd",
]

## key: [name, colour, strength, density kg/m³, friction, bounce, blunt, sharp, pierce, sound, rubble]
## Densities are per voxel of the model; thin sheet parts (steel, plastic) use
## an effective density, since a voxel is far thicker than the sheet it shows.
const MATERIAL_TABLE := {
	"oak": ["Oak", Color(0.62, 0.45, 0.28), 8.0, 700.0, 0.7, 0.08, 1.0, 1.2, 1.0, ImpactFeedback.Sound.WOOD, 0.25],
	"pine": ["Pine", Color(0.8, 0.64, 0.42), 6.0, 500.0, 0.7, 0.1, 1.0, 1.3, 1.1, ImpactFeedback.Sound.WOOD, 0.3],
	"walnut": ["Walnut", Color(0.38, 0.25, 0.16), 9.0, 650.0, 0.7, 0.08, 1.0, 1.1, 1.0, ImpactFeedback.Sound.WOOD, 0.25],
	"painted_wood": ["Painted timber", Color(0.92, 0.91, 0.87), 7.0, 650.0, 0.6, 0.08, 1.0, 1.2, 1.0, ImpactFeedback.Sound.WOOD, 0.25],
	"chipboard": ["Chipboard", Color(0.85, 0.83, 0.78), 4.5, 700.0, 0.6, 0.05, 1.3, 1.0, 1.2, ImpactFeedback.Sound.WOOD, 0.35],
	"plywood": ["Plywood", Color(0.78, 0.66, 0.48), 6.0, 600.0, 0.7, 0.08, 1.0, 1.1, 1.0, ImpactFeedback.Sound.WOOD, 0.3],
	"fabric": ["Upholstery", Color(0.45, 0.5, 0.55), 5.0, 160.0, 0.9, 0.02, 0.45, 2.2, 1.6, ImpactFeedback.Sound.CARDBOARD, 0.1],
	"leather": ["Leather", Color(0.36, 0.2, 0.12), 7.0, 220.0, 0.85, 0.03, 0.5, 1.8, 1.4, ImpactFeedback.Sound.CARDBOARD, 0.08],
	"foam": ["Mattress", Color(0.92, 0.92, 0.9), 4.0, 90.0, 0.95, 0.02, 0.35, 2.4, 1.8, ImpactFeedback.Sound.CARDBOARD, 0.05],
	"steel": ["Steel", Color(0.6, 0.62, 0.65), 32.0, 900.0, 0.5, 0.05, 0.6, 0.3, 0.5, ImpactFeedback.Sound.METAL, 0.05],
	"painted_steel": ["Painted steel", Color(0.3, 0.35, 0.42), 28.0, 850.0, 0.5, 0.05, 0.65, 0.35, 0.5, ImpactFeedback.Sound.METAL, 0.05],
	"chrome": ["Chrome", Color(0.82, 0.83, 0.85), 30.0, 1100.0, 0.4, 0.1, 0.6, 0.3, 0.4, ImpactFeedback.Sound.METAL, 0.05],
	"cast_iron": ["Cast iron", Color(0.16, 0.16, 0.17), 40.0, 3000.0, 0.6, 0.03, 0.5, 0.2, 0.3, ImpactFeedback.Sound.METAL, 0.1],
	"brass": ["Brass", Color(0.78, 0.62, 0.3), 25.0, 1500.0, 0.5, 0.06, 0.6, 0.35, 0.5, ImpactFeedback.Sound.METAL, 0.05],
	"aluminium": ["Aluminium", Color(0.78, 0.79, 0.8), 18.0, 500.0, 0.5, 0.06, 0.8, 0.5, 0.6, ImpactFeedback.Sound.METAL, 0.05],
	"glass": ["Glass", Color(0.69, 0.86, 0.92), 1.2, 1300.0, 0.4, 0.05, 1.6, 1.0, 1.5, ImpactFeedback.Sound.GLASS, 0.45],
	"mirror": ["Mirror", Color(0.85, 0.88, 0.9), 1.2, 1300.0, 0.4, 0.05, 1.6, 1.0, 1.5, ImpactFeedback.Sound.GLASS, 0.45],
	"screen": ["Screen", Color(0.06, 0.07, 0.09), 2.0, 900.0, 0.4, 0.05, 1.5, 1.0, 1.5, ImpactFeedback.Sound.GLASS, 0.3],
	"plastic": ["Plastic", Color(0.9, 0.9, 0.88), 4.0, 450.0, 0.6, 0.15, 0.9, 1.4, 1.2, ImpactFeedback.Sound.PLASTIC, 0.15],
	"rubber": ["Rubber", Color(0.1, 0.1, 0.1), 9.0, 900.0, 1.0, 0.4, 0.4, 1.2, 1.0, ImpactFeedback.Sound.RUBBER, 0.05],
	"ceramic": ["Ceramic", Color(0.95, 0.95, 0.93), 2.5, 1400.0, 0.5, 0.05, 1.7, 0.8, 1.2, ImpactFeedback.Sound.GLASS, 0.4],
	"marble": ["Marble", Color(0.88, 0.87, 0.84), 22.0, 2500.0, 0.55, 0.05, 1.0, 0.3, 0.6, ImpactFeedback.Sound.STONE, 0.2],
	"stone": ["Stone", Color(0.68, 0.66, 0.62), 20.0, 2300.0, 0.7, 0.05, 1.0, 0.3, 0.6, ImpactFeedback.Sound.STONE, 0.25],
	"concrete": ["Concrete", Color(0.62, 0.62, 0.6), 18.0, 2200.0, 0.75, 0.04, 1.0, 0.3, 0.6, ImpactFeedback.Sound.STONE, 0.25],
	"terracotta": ["Terracotta", Color(0.7, 0.36, 0.22), 3.0, 1300.0, 0.7, 0.05, 1.5, 0.8, 1.2, ImpactFeedback.Sound.STONE, 0.4],
	"paper": ["Paper", Color(0.9, 0.88, 0.82), 2.0, 450.0, 0.8, 0.05, 0.8, 2.0, 1.6, ImpactFeedback.Sound.CARDBOARD, 0.1],
	"cardboard": ["Cardboard", Color(0.66, 0.5, 0.32), 1.8, 180.0, 0.8, 0.05, 1.0, 1.8, 1.6, ImpactFeedback.Sound.CARDBOARD, 0.1],
	"wicker": ["Wicker", Color(0.72, 0.56, 0.34), 3.5, 250.0, 0.8, 0.1, 1.1, 1.4, 1.2, ImpactFeedback.Sound.WOOD, 0.3],
	"plant": ["Foliage", Color(0.25, 0.45, 0.2), 1.0, 300.0, 0.9, 0.02, 1.0, 2.5, 1.5, ImpactFeedback.Sound.CARDBOARD, 0.1],
	"soil": ["Soil", Color(0.3, 0.22, 0.15), 1.5, 1200.0, 0.95, 0.0, 1.2, 1.0, 1.0, ImpactFeedback.Sound.CARDBOARD, 0.3],
	"electronics": ["Electronics", Color(0.12, 0.12, 0.13), 6.0, 700.0, 0.6, 0.1, 1.0, 1.0, 1.0, ImpactFeedback.Sound.PLASTIC, 0.15],
}

## How each material responds to the advanced tools (blowtorch, saws, grinder,
## drill, shovel...), from res://contraptions/materials/profiles/.
const PROFILE_DIR := "res://contraptions/materials/profiles/"
const TOOL_PROFILES := {
	"wood": ["oak", "pine", "walnut", "painted_wood", "chipboard", "plywood", "wicker"],
	"steel": ["steel", "painted_steel", "cast_iron", "chrome"],
	"nonmagnetic_metal": ["brass", "aluminium"],
	"glass": ["glass", "mirror", "screen"],
	"masonry": ["marble", "stone", "concrete", "terracotta", "ceramic"],
	"plastic": ["plastic", "rubber", "electronics"],
	"soft": ["fabric", "leather", "foam", "paper", "cardboard", "plant"],
	"soil": ["soil"],
}

var materials: Dictionary = {}
var manifest: Dictionary = {}
var report: Array[String] = []


func _initialize() -> void:
	var only: Array[String] = []
	var category := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("category="):
			category = arg.trim_prefix("category=")
		else:
			only.append(arg)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VOX))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIALS))
	_load_manifest()
	_make_materials()
	var count := 0
	for path in CATALOGUES:
		if not ResourceLoader.exists(path):
			continue
		var catalogue: Object = load(path).new()
		for spec: Dictionary in catalogue.call("models"):
			if not category.is_empty() and spec["category"] != category:
				continue
			if not only.is_empty() and not only.has(spec["id"]):
				continue
			if _generate(spec):
				count += 1
	_save_manifest()
	for line in report:
		print(line)
	print("Furniture generated: %d" % count)
	quit()


func _generate(spec: Dictionary) -> bool:
	var size: Vector3 = spec["size"]
	var longest := maxf(size.x, maxf(size.y, size.z))
	# About 40 voxels along the longest side; at least 2 cm on anything bigger than
	# a small appliance, so big pieces stay cheap to build and break.
	var auto := clampf(longest / 40.0, 0.012, 0.045)
	if longest >= 0.55:
		auto = maxf(auto, 0.02)
	var voxel: float = spec.get("voxel", auto)
	var model := FurnitureModel.new(size, voxel)
	var build: Callable = spec["build"]
	build.call(model)
	if spec.get("hollow", true):
		var keep: Array[String] = ["glass", "mirror", "screen"]
		model.hollow(keep)
	# Every piece must be one connected lump, or loose bits drop off on load.
	var joins := model.connect_parts()
	if not joins.is_empty():
		var bridged := 0
		var longest_bridge := 0
		var loose := []
		for join in joins:
			if join[1] < 0:
				loose.append("%d (%s)" % [join[0], join[2]])
			else:
				bridged += 1
				longest_bridge = maxi(longest_bridge, join[1])
		report.append("  joined %d loose part(s) of %s, longest bridge %d voxels%s" % [bridged, spec["id"], longest_bridge,
			"" if loose.is_empty() else ", STILL LOOSE: %s" % [loose]])
	if model.cells.is_empty():
		report.append("EMPTY  %s" % spec["id"])
		return false
	var grid := model.normalize()
	if grid.x > 255 or grid.y > 255 or grid.z > 255:
		report.append("TOO BIG  %s %s" % [spec["id"], grid])
		return false
	# Palette: one entry per (paint, shade) used, each with its real material.
	var baked := ModelExporter.palette(model, materials)
	if baked.is_empty():
		report.append("PALETTE FULL  %s" % spec["id"])
		return false
	var palette: PackedColorArray = baked["colors"]
	var index_materials: Dictionary = baked["index_materials"]
	var indexed: Dictionary = baked["indexed"]
	var mass: float = baked["mass"]
	var folder: String = OUT + String(spec["category"]).to_snake_case() + "/"
	var vox_path: String = VOX + spec["id"] + ".vox"
	var def_path: String = folder + spec["id"] + ".tres"
	if not _may_write(vox_path) or not _may_write(def_path):
		report.append("SKIPPED (not ours)  %s" % spec["id"])
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	VoxFile.write_indexed(vox_path, grid, indexed.get(0, {}), palette)
	var definition := VoxelStructureDefinition.new()
	definition.display_name = spec["name"]
	definition.spawn_category = spec["category"]
	definition.voxel_size = voxel
	definition.anchor_mode = VoxelStructureDefinition.AnchorMode.NONE
	definition.vox_file = vox_path
	definition.vox_material = materials[model.parts[0][0]]
	definition.vox_keep_colors = true
	definition.vox_index_materials = index_materials
	# Real-world weight: voxels are thicker than the boards and panes they show.
	if float(spec.get("mass", 0.0)) > 0.0 and mass > 0.0:
		definition.density_scale = clampf(float(spec["mass"]) / mass, 0.02, 5.0)
		mass = float(spec["mass"])
	# Each moving part: its own .vox on the same grid (so it lines up with the
	# body), saved inside the definition.
	var moving_parts: Array[FurniturePart] = []
	for group in range(1, model.moving.size()):
		if not indexed.has(group):
			continue
		var spec_part: Dictionary = model.moving[group]
		var part_path: String = VOX + "%s__part%d.vox" % [spec["id"], group]
		if not _may_write(part_path):
			continue
		VoxFile.write_indexed(part_path, grid, indexed[group], palette)
		manifest[part_path] = true
		var part_definition := ModelExporter.definition("%s %s" % [spec["name"], spec_part["label"]], part_path, voxel,
			index_materials, definition.vox_material, definition.density_scale)
		var part := FurniturePart.new()
		part.label = spec_part["label"]
		part.kind = FurniturePart.Kind.HINGE if spec_part["kind"] == "hinge" else FurniturePart.Kind.SLIDE
		part.structure = part_definition
		part.axis = spec_part["axis"]
		part.amount = spec_part["amount"]
		part.pivot = ModelExporter.to_body(model, grid, spec_part["pivot"])
		moving_parts.append(part)
	definition.moving_parts = moving_parts
	_save(definition, def_path)
	manifest[vox_path] = true
	manifest[def_path] = true
	report.append("%-28s %6d voxels  %6.1f kg  %.3f m voxels  scale %.2f  %d moving parts" % [spec["id"], model.cells.size(), mass, voxel, definition.density_scale, definition.moving_parts.size()])
	return true


func _make_materials() -> void:
	for key in MATERIAL_TABLE:
		var path: String = MATERIALS + key + ".tres"
		if ResourceLoader.exists(path):
			materials[key] = load(path)
			_ensure_profile(key, materials[key], path)
			continue
		var row: Array = MATERIAL_TABLE[key]
		var material := VoxelMaterialDefinition.new()
		material.display_name = row[0]
		material.color = row[1]
		# No per-voxel colour noise: the palette shades give the texture, and flat
		# colour lets the mesher merge faces (far fewer triangles).
		material.color_jitter = 0.0
		material.strength = row[2]
		material.density = row[3]
		material.friction = row[4]
		material.bounce = row[5]
		material.blunt_multiplier = row[6]
		material.sharp_multiplier = row[7]
		material.pierce_multiplier = row[8]
		material.impact_sound = row[9]
		material.rubble_fraction = row[10]
		if key == "glass":
			material.mesh_material_override = load(GLASS_LOOK)
		elif key == "mirror":
			var shiny := StandardMaterial3D.new()
			shiny.albedo_color = Color(0.85, 0.88, 0.9)
			shiny.metallic = 1.0
			shiny.roughness = 0.04
			material.mesh_material_override = shiny
		material.tool_profile = _profile_for(key)
		ResourceSaver.save(material, path)
		materials[key] = load(path)


static func _profile_for(key: String) -> ToolMaterialProfile:
	for profile in TOOL_PROFILES:
		if TOOL_PROFILES[profile].has(key):
			return load(PROFILE_DIR + profile + ".tres")
	return null


## Existing materials are left for tuning, but get a tool profile if they lack one.
func _ensure_profile(key: String, material: VoxelMaterialDefinition, path: String) -> void:
	if material.tool_profile == null and _profile_for(key) != null:
		material.tool_profile = _profile_for(key)
		ResourceSaver.save(material, path)


func _may_write(path: String) -> bool:
	return not FileAccess.file_exists(path) or manifest.has(path)


func _load_manifest() -> void:
	if FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			manifest = parsed


func _save_manifest() -> void:
	var keys := manifest.keys()
	keys.sort()
	var ordered := {}
	for key in keys:
		ordered[key] = true
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(ordered, "\t"))


## Saves, keeping an existing file's uid so scenes that use it still resolve.
func _save(resource: Resource, path: String) -> void:
	var uid_line := ""
	if FileAccess.file_exists(path):
		var found := RegEx.create_from_string("uid=\"uid://[a-z0-9]+\"").search(FileAccess.get_file_as_string(path).get_slice("\n", 0))
		if found != null:
			uid_line = found.get_string()
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
