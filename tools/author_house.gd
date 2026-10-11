extends SceneTree
## Offline authoring only. Uses the project's VOX writer and saves ordinary scenes.
## Existing outputs may only be replaced when they still match our manifest.

const VOX := "res://props/vox/house/"
const DEFINITIONS := "res://props/house/"
const ASSETS := "res://house/assets/"
const SCENES := "res://house/scenes/"
const MANIFEST := ASSETS + "authoring_manifest.json"
const OAK := Color8(163, 113, 65)
const DARK_WOOD := Color8(87, 59, 40)
const GREEN := Color8(68, 102, 82)
const BURGUNDY := Color8(132, 62, 65)
const LINEN := Color8(197, 186, 147)
const CREAM := Color8(226, 220, 197)
const METAL := Color8(76, 83, 83)
const CERAMIC := Color8(222, 229, 217)
const ROOF := Color8(62, 64, 72)
const INK := Color8(29, 34, 39)
const GOLD := Color8(196, 153, 66)
# Fit moving leaves to the 0.2 m architectural openings, with millimetre joints.
const LEAF_CELL := 0.0495

var materials: Dictionary = {}
var assets: Dictionary = {}
var previous: Dictionary = {}
var written: Dictionary = {}
var failed := false
var architecture_only := false


class Model:
	var size: Vector3i
	var cells: Dictionary = {}
	func _init(dimensions: Vector3i) -> void:
		size = dimensions
	func box(at: Vector3i, extent: Vector3i, color: Color) -> void:
		for x in range(at.x, at.x + extent.x):
			for y in range(at.y, at.y + extent.y):
				for z in range(at.z, at.z + extent.z):
					assert(x >= 0 and y >= 0 and z >= 0 and x < size.x and y < size.y and z < size.z)
					cells[Vector3i(x, y, z)] = color
	func cut(at: Vector3i, extent: Vector3i) -> void:
		for x in range(at.x, at.x + extent.x):
			for y in range(at.y, at.y + extent.y):
				for z in range(at.z, at.z + extent.z):
					cells.erase(Vector3i(x, y, z))
	func ellipse(at: Vector3i, extent: Vector3i, color: Color, hollow := false) -> void:
		for x in range(at.x, at.x + extent.x):
			for y in range(at.y, at.y + extent.y):
				for z in range(at.z, at.z + extent.z):
					var d := (Vector3(x, y, z) + Vector3.ONE * 0.5 - Vector3(at) - Vector3(extent) * 0.5) / (Vector3(extent) * 0.5)
					if d.length_squared() <= 1.0 and (not hollow or d.length_squared() > 0.48):
						cells[Vector3i(x, y, z)] = color


class SceneText:
	var references: Dictionary = {}
	var subs: Array[String] = []
	var nodes: Array[String] = []
	func ext(path: String, kind := "Resource") -> String:
		if not references.has(path):
			references[path] = ["r%d" % (references.size() + 1), kind]
		return 'ExtResource("%s")' % references[path][0]
	func sub(kind: String, properties: Dictionary) -> String:
		var id := "s%d" % (subs.size() + 1)
		var text := '[sub_resource type="%s" id="%s"]\n' % [kind, id]
		for key in properties:
			text += "%s = %s\n" % [key, properties[key]]
		subs.append(text)
		return 'SubResource("%s")' % id
	func node(label: String, kind: String, parent: String, properties: Dictionary = {}, packed := "") -> void:
		var line := '[node name="%s"' % label
		if not kind.is_empty():
			line += ' type="%s"' % kind
		if not parent.is_empty():
			line += ' parent="%s"' % parent
		if not packed.is_empty():
			line += " instance=" + ext(packed, "PackedScene")
		line += "]\n"
		for key in properties:
			line += "%s = %s\n" % [key, properties[key]]
		nodes.append(line)
	func text() -> String:
		var result := "[gd_scene format=3]\n\n"
		for path in references:
			result += '[ext_resource type="%s" path="%s" id="%s"]\n' % [references[path][1], path, references[path][0]]
		return result + "\n" + "\n".join(subs) + "\n" + "\n".join(nodes)


func _initialize() -> void:
	build.call_deferred()


func build() -> void:
	architecture_only = OS.get_cmdline_user_args().has("--architecture-only")
	if FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			previous = parsed
	for path in previous:
		if architecture_only and not _is_structural_model(path):
			continue
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path) != previous[path]:
			push_error("Refusing to overwrite hand-edited house output: " + path)
			quit(1)
			return
	_make_materials()
	if architecture_only:
		_make_architecture()
	else:
		_make_furniture()
		_make_fixtures()
		_make_small_props()
		_make_architecture()
		_make_fixture_scenes()
		_make_rooms()
		_make_garden()
		_make_house()
	if failed:
		quit(1)
		return
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	previous.merge(written, true)
	file.store_string(JSON.stringify(previous, "\t") + "\n")
	print("House authoring complete: ", written.size(), " outputs; ", assets.size(), " model definitions.")
	quit()


func _is_structural_model(path: String) -> bool:
	for section in 6:
		if path == VOX + "structure_%02d.vox" % section:
			return true
	return false


func _prepare(path: String) -> bool:
	# A geometry-only correction must not rewrite furnished scenes or definitions.
	if architecture_only and not _is_structural_model(path):
		return false
	if not (path.begins_with(VOX) or path.begins_with(DEFINITIONS) or path.begins_with(ASSETS) or path.begins_with(SCENES) or path == "res://house/house.tscn"):
		push_error("Output outside house authoring scope: " + path)
		failed = true
		return false
	if FileAccess.file_exists(path) and not previous.has(path):
		push_error("Refusing to overwrite an unowned file: " + path)
		failed = true
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	return true


func _save(resource: Resource, path: String) -> void:
	if _prepare(path):
		if ResourceSaver.save(resource, path) != OK:
			failed = true
		_record(path)


func _record(path: String) -> void:
	written[path] = FileAccess.get_sha256(path)
	var current := previous.duplicate()
	current.merge(written, true)
	var manifest := FileAccess.open(MANIFEST, FileAccess.WRITE)
	manifest.store_string(JSON.stringify(current, "\t") + "\n")


func _write_scene(scene: SceneText, file: String) -> void:
	var path := "res://house/house.tscn" if file == "house" else SCENES + file + ".tscn"
	if _prepare(path):
		var output := FileAccess.open(path, FileAccess.WRITE)
		output.store_string(scene.text())
		output.close()
		_record(path)


func _make_materials() -> void:
	for key in ["wood", "brick", "concrete", "glass"]:
		materials[key] = load("res://props/voxel_materials/" + key + ".tres")
	var specs := [
		["upholstery", GREEN, 3.0, 80.0, 0.05, 4],
		["plaster", CREAM, 4.0, 300.0, 0.08, 3],
		["ceramic", CERAMIC, 8.0, 900.0, 0.18, 7],
		["painted_metal", METAL, 24.0, 700.0, 0.08, 2],
		["roof_tile", ROOF, 8.0, 600.0, 0.12, 3],
	]
	for spec in specs:
		var mat := VoxelMaterialDefinition.new()
		mat.display_name = String(spec[0]).capitalize()
		mat.color = spec[1]
		mat.strength = spec[2]
		mat.density = spec[3]
		mat.rubble_fraction = spec[4]
		mat.impact_sound = spec[5]
		mat.color_jitter = 0.04
		mat.friction = 0.65
		mat.bounce = 0.03
		mat.sharp_multiplier = 1.7 if spec[0] == "upholstery" else 0.8
		mat.pierce_multiplier = 1.3
		_save(mat, ASSETS + "materials/" + spec[0] + ".tres")
		materials[spec[0]] = mat
	materials["burgundy_cloth"] = materials.upholstery.get_color_variant(BURGUNDY)
	materials["linen"] = materials.upholstery.get_color_variant(LINEN)
	materials["oak"] = materials.wood.get_color_variant(OAK)
	materials["dark_wood"] = materials.wood.get_color_variant(DARK_WOOD)
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.66, 0.85, 0.91, 0.23)
	glass.roughness = 0.2
	_save(glass, ASSETS + "materials/transparent_glass.tres")


func _model(id: String, label: String, model: Model, step: float, main := "wood", fixed := false, assembly := false, mass := -1.0) -> void:
	var vox_path := VOX + id + ".vox"
	if not _prepare(vox_path):
		return
	if VoxFile.write_cells(vox_path, model.size, model.cells) != OK:
		failed = true
		return
	_record(vox_path)
	var path := (ASSETS + "definitions/" if assembly else DEFINITIONS) + id + ".tres"
	if mass >= 0.0:
		var definition := PhysicsObjectDefinition.new()
		definition.display_name = label
		definition.mass = mass
		definition.size = Vector3(model.size) * step
		definition.vox_model = vox_path
		definition.vox_voxel_size = step
		definition.vox_origin = -definition.size * 0.5
		definition.impact_sound = ImpactFeedback.Sound.METAL if main == "painted_metal" else ImpactFeedback.Sound.WOOD
		definition.bounce = 0.05
		definition.spawn_category = "Props"
		_save(definition, path)
	else:
		var definition := VoxelStructureDefinition.new()
		definition.display_name = label
		definition.voxel_size = step
		definition.vox_file = vox_path
		definition.vox_material = materials[main]
		definition.anchor_mode = VoxelStructureDefinition.AnchorMode.BOTTOM_LAYER if fixed else VoxelStructureDefinition.AnchorMode.NONE
		definition.spawn_category = "Structures" if fixed else "Destructible"
		for key in materials:
			if key in ["upholstery", "burgundy_cloth", "linen"] and id not in ["sofa", "armchair", "bed", "floor_lamp", "table_lamp", "plant_pot"]:
				continue
			if key != main:
				definition.vox_extra_materials.append(materials[key])
		_save(definition, path)
	assets[id] = {"path": path, "size": Vector3(model.size) * step, "prop": mass >= 0.0, "cells": model.cells.size()}


func _legs(model: Model, top: int, width := 2, color := OAK) -> void:
	for x in [1, model.size.x - width - 1]:
		for z in [1, model.size.z - width - 1]:
			model.box(Vector3i(x, 0, z), Vector3i(width, top, width), color)


func _table_model(size: Vector3i, thickness := 2) -> Model:
	var model := Model.new(size)
	_legs(model, size.y - thickness)
	model.box(Vector3i(0, size.y - thickness, 0), Vector3i(size.x, thickness, size.z), OAK)
	return model


func _carcass(size: Vector3i, paint := OAK, shelves: Array = []) -> Model:
	var model := Model.new(size)
	model.box(Vector3i.ZERO, Vector3i(size.x, 2, size.z), paint)
	model.box(Vector3i(0, size.y - 1, 0), Vector3i(size.x, 1, size.z), paint)
	model.box(Vector3i.ZERO, Vector3i(1, size.y, size.z), paint)
	model.box(Vector3i(size.x - 1, 0, 0), Vector3i(1, size.y, size.z), paint)
	model.box(Vector3i(0, 0, size.z - 1), Vector3i(size.x, size.y, 1), paint)
	for y in shelves:
		model.box(Vector3i(1, int(y), 1), Vector3i(size.x - 2, 1, size.z - 2), paint)
	return model


func _make_furniture() -> void:
	for spec in [["sofa", "Sofa", 40, GREEN], ["armchair", "Armchair", 22, BURGUNDY]]:
		var width: int = spec[2]
		var m := Model.new(Vector3i(width, 18, 18))
		_legs(m, 4, 3, DARK_WOOD)
		m.box(Vector3i(0, 4, 0), Vector3i(width, 3, 18), OAK)
		m.box(Vector3i(0, 7, 15), Vector3i(width, 11, 3), spec[3])
		m.box(Vector3i(0, 7, 0), Vector3i(3, 7, 15), spec[3])
		m.box(Vector3i(width - 3, 7, 0), Vector3i(3, 7, 15), spec[3])
		m.box(Vector3i(3, 7, 1), Vector3i(width - 6, 3, 14), spec[3])
		m.box(Vector3i(4, 10, 12), Vector3i(7, 5, 3), LINEN)
		if width > 25:
			m.box(Vector3i(width - 11, 10, 12), Vector3i(7, 5, 3), BURGUNDY)
		_model(spec[0], spec[1], m, 0.05)
	for spec in [["coffee_table", "Coffee Table", Vector3i(24, 9, 14)], ["side_table", "Side Table", Vector3i(10, 11, 10)], ["desk", "Writing Desk", Vector3i(28, 15, 13)], ["console", "Hall Console", Vector3i(24, 15, 8)], ["bedside", "Bedside Table", Vector3i(10, 10, 10)], ["workbench", "Workbench", Vector3i(32, 18, 14)]]:
		var m := _table_model(spec[2])
		if spec[0] == "workbench":
			m.box(Vector3i(2, 4, 2), Vector3i(28, 1, 10), DARK_WOOD)
		_model(spec[0], spec[1], m, 0.05)
	var stand := _carcass(Vector3i(28, 10, 10), DARK_WOOD, [5])
	_model("tv_stand", "Television Stand", stand, 0.05)
	var tv := Model.new(Vector3i(22, 16, 6))
	tv.box(Vector3i(5, 0, 0), Vector3i(12, 1, 6), INK)
	tv.box(Vector3i(10, 1, 2), Vector3i(2, 4, 2), METAL)
	tv.box(Vector3i(0, 4, 2), Vector3i(22, 12, 3), INK)
	tv.box(Vector3i(1, 5, 1), Vector3i(20, 10, 1), Color8(48, 74, 80))
	tv.box(Vector3i(17, 5, 1), Vector3i(3, 1, 1), GOLD)
	_model("television", "Television", tv, 0.05, "painted_metal")
	var bed := Model.new(Vector3i(32, 18, 40))
	_legs(bed, 4, 3, DARK_WOOD)
	bed.box(Vector3i(0, 4, 0), Vector3i(32, 2, 40), OAK)
	bed.box(Vector3i(0, 6, 37), Vector3i(32, 12, 3), DARK_WOOD)
	bed.box(Vector3i(1, 6, 1), Vector3i(30, 4, 36), LINEN)
	bed.box(Vector3i(1, 10, 1), Vector3i(30, 1, 24), GREEN)
	bed.box(Vector3i(3, 10, 29), Vector3i(11, 3, 6), LINEN)
	bed.box(Vector3i(18, 10, 29), Vector3i(11, 3, 6), LINEN)
	_model("bed", "Double Bed", bed, 0.05)
	_model("storage_shelf", "Storage Shelf", _carcass(Vector3i(24, 34, 9), OAK, [10, 20, 30]), 0.05)
	var bench := Model.new(Vector3i(32, 18, 12))
	_legs(bench, 8, 3)
	bench.box(Vector3i(0, 8, 0), Vector3i(32, 2, 12), OAK)
	for x in [1, 28]:
		bench.box(Vector3i(x, 9, 10), Vector3i(3, 9, 2), DARK_WOOD)
	for y in [12, 16]:
		bench.box(Vector3i(0, y, 10), Vector3i(32, 2, 2), GREEN)
	_model("garden_bench", "Garden Bench", bench, 0.05)
	var rack := Model.new(Vector3i(12, 36, 12))
	rack.box(Vector3i(0, 0, 5), Vector3i(12, 2, 2), DARK_WOOD)
	rack.box(Vector3i(5, 0, 0), Vector3i(2, 2, 12), DARK_WOOD)
	rack.box(Vector3i(5, 2, 5), Vector3i(2, 34, 2), OAK)
	rack.box(Vector3i(1, 29, 5), Vector3i(10, 2, 2), OAK)
	rack.box(Vector3i(5, 32, 1), Vector3i(2, 2, 10), OAK)
	_model("coat_rack", "Coat Rack", rack, 0.05)
	for spec in [["floor_lamp", "Floor Lamp", 28, 0.05], ["table_lamp", "Table Lamp", 16, 0.025]]:
		var h: int = spec[2]
		var m := Model.new(Vector3i(10, h, 10))
		m.box(Vector3i(1, 0, 1), Vector3i(8, 2, 8), METAL)
		m.box(Vector3i(4, 2, 4), Vector3i(2, h - 8, 2), GOLD)
		m.ellipse(Vector3i(0, h - 8, 0), Vector3i(10, 8, 10), LINEN)
		_model(spec[0], spec[1], m, spec[3])
	var pot := Model.new(Vector3i(10, 14, 10))
	pot.box(Vector3i(1, 0, 1), Vector3i(8, 6, 8), materials.brick.color)
	pot.cut(Vector3i(2, 2, 2), Vector3i(6, 4, 6))
	pot.box(Vector3i(4, 2, 4), Vector3i(2, 8, 2), DARK_WOOD)
	pot.ellipse(Vector3i(0, 7, 0), Vector3i(10, 7, 10), GREEN)
	_model("plant_pot", "Potted Shrub", pot, 0.05, "wood")


func _panel(id: String, label: String, dimensions: Vector3i, color: Color, step := 0.05, main := "wood") -> void:
	var m := Model.new(dimensions)
	m.box(Vector3i.ZERO, dimensions, color)
	if dimensions.x > 8 and dimensions.y > 8 and main == "wood":
		m.box(Vector3i(2, 2, 0), Vector3i(dimensions.x - 4, dimensions.y / 2 - 3, 1), color.lightened(0.1))
		m.box(Vector3i(2, dimensions.y / 2 + 1, 0), Vector3i(dimensions.x - 4, dimensions.y / 2 - 3, 1), color.lightened(0.1))
		m.box(Vector3i(dimensions.x - 3, dimensions.y / 2, 0), Vector3i(2, 1, 1), GOLD)
	_model(id, label, m, step, main, true, true)


func _make_fixtures() -> void:
	_panel("front_door_leaf", "Front Door", Vector3i(24, 44, 2), BURGUNDY, LEAF_CELL)
	_panel("internal_door_leaf", "Interior Door", Vector3i(24, 44, 2), Color8(202, 192, 161), LEAF_CELL)
	_panel("shed_door_leaf", "Shed Door", Vector3i(20, 40, 2), GREEN, LEAF_CELL)
	_panel("cupboard_leaf", "Cupboard Door", Vector3i(14, 14, 1), GREEN)
	_panel("wardrobe_leaf", "Wardrobe Door", Vector3i(14, 36, 1), DARK_WOOD)
	_panel("fridge_leaf", "Fridge Door", Vector3i(16, 33, 2), Color8(185, 201, 188), 0.05, "painted_metal")
	_panel("oven_leaf", "Oven Door", Vector3i(14, 10, 2), INK, 0.05, "painted_metal")
	var frame := Model.new(Vector3i(32, 28, 2))
	frame.box(Vector3i.ZERO, frame.size, Color8(185, 193, 166))
	frame.cut(Vector3i(2, 2, 0), Vector3i(28, 24, 2))
	frame.box(Vector3i(15, 2, 0), Vector3i(2, 24, 2), Color8(185, 193, 166))
	_model("window_frame", "Opening Window Frame", frame, LEAF_CELL, "wood", true, true)
	var panes := Model.new(Vector3i(28, 24, 1))
	panes.box(Vector3i.ZERO, panes.size, materials.glass.color)
	# Leave the centre mullion to the timber frame; glass never overlaps its collider.
	panes.cut(Vector3i(13, 0, 0), Vector3i(2, 24, 1))
	_model("window_glass", "Window Glass", panes, LEAF_CELL, "glass", true, true)
	var shower := Model.new(Vector3i(18, 36, 2))
	shower.box(Vector3i.ZERO, shower.size, METAL)
	shower.cut(Vector3i(1, 1, 0), Vector3i(16, 34, 2))
	_model("screen_frame", "Shower Screen Frame", shower, 0.05, "painted_metal", true, true)
	_panel("screen_glass", "Shower Screen Glass", Vector3i(16, 34, 1), materials.glass.color, 0.05, "glass")
	_model("cabinet", "Kitchen Cabinet", _carcass(Vector3i(16, 17, 12), GREEN, [8]), 0.05, "wood", true, true)
	_model("drawer_cabinet", "Drawer Cabinet", _carcass(Vector3i(16, 17, 12), GREEN), 0.05, "wood", true, true)
	_model("wardrobe", "Wardrobe", _carcass(Vector3i(32, 40, 12), DARK_WOOD, [7, 32]), 0.05, "wood", true, true)
	_model("display_cabinet", "Display Cabinet", _carcass(Vector3i(16, 30, 10), DARK_WOOD, [10, 20]), 0.05, "wood", true, true)
	var drawer := Model.new(Vector3i(14, 4, 10))
	drawer.box(Vector3i.ZERO, Vector3i(14, 1, 10), OAK)
	drawer.box(Vector3i.ZERO, Vector3i(14, 4, 1), GREEN)
	drawer.box(Vector3i(0, 1, 9), Vector3i(14, 3, 1), OAK)
	drawer.box(Vector3i(0, 1, 0), Vector3i(1, 3, 10), OAK)
	drawer.box(Vector3i(13, 1, 0), Vector3i(1, 3, 10), OAK)
	drawer.box(Vector3i(5, 2, 0), Vector3i(4, 1, 1), GOLD)
	_model("drawer_tray", "Drawer Tray", drawer, 0.05, "wood", true, true)
	var fridge := _carcass(Vector3i(18, 36, 16), Color8(185, 201, 188), [10, 20, 29])
	_model("fridge", "Refrigerator", fridge, 0.05, "painted_metal", true, true)
	var oven := _carcass(Vector3i(16, 17, 12), METAL, [5])
	for x in [3, 10]:
		for z in [2, 7]:
			oven.box(Vector3i(x, 16, z), Vector3i(3, 1, 3), INK)
	for x in [3, 6, 9, 12]:
		oven.box(Vector3i(x, 14, 0), Vector3i(1, 1, 1), GOLD)
	_model("oven", "Oven", oven, 0.05, "painted_metal", true, true)
	var sink := _carcass(Vector3i(16, 20, 12), GREEN, [8])
	sink.cut(Vector3i(0, 17, 0), Vector3i(16, 3, 12))
	sink.box(Vector3i(0, 16, 0), Vector3i(16, 1, 12), CERAMIC)
	sink.box(Vector3i(3, 13, 2), Vector3i(10, 4, 8), CERAMIC)
	sink.cut(Vector3i(4, 14, 3), Vector3i(8, 3, 6))
	sink.box(Vector3i(7, 16, 10), Vector3i(2, 4, 1), METAL)
	sink.box(Vector3i(7, 19, 7), Vector3i(2, 1, 3), METAL)
	_model("sink", "Kitchen Sink", sink, 0.05, "wood", true, true)
	var washer := _carcass(Vector3i(12, 17, 12), Color8(205, 212, 205))
	washer.box(Vector3i(0, 0, 0), Vector3i(12, 17, 1), Color8(205, 212, 205))
	washer.ellipse(Vector3i(2, 3, 0), Vector3i(8, 9, 2), INK)
	washer.ellipse(Vector3i(3, 4, 0), Vector3i(6, 7, 1), Color8(97, 131, 140))
	washer.box(Vector3i(8, 14, 0), Vector3i(2, 2, 1), GOLD)
	_model("washer", "Washing Machine", washer, 0.05, "painted_metal", true, true)
	var toilet := Model.new(Vector3i(10, 16, 16))
	toilet.box(Vector3i(3, 0, 3), Vector3i(4, 7, 9), CERAMIC)
	toilet.ellipse(Vector3i(0, 5, 0), Vector3i(10, 6, 13), CERAMIC)
	toilet.cut(Vector3i(3, 8, 3), Vector3i(4, 3, 6))
	toilet.box(Vector3i(0, 7, 12), Vector3i(10, 9, 4), CERAMIC)
	toilet.box(Vector3i(7, 14, 11), Vector3i(2, 1, 1), METAL)
	_model("toilet", "Toilet", toilet, 0.05, "ceramic", true, true)
	var basin := Model.new(Vector3i(12, 18, 10))
	basin.box(Vector3i(4, 0, 4), Vector3i(4, 14, 4), CERAMIC)
	basin.box(Vector3i(0, 13, 0), Vector3i(12, 4, 10), CERAMIC)
	basin.cut(Vector3i(2, 14, 2), Vector3i(8, 3, 6))
	basin.box(Vector3i(5, 15, 8), Vector3i(2, 3, 1), METAL)
	_model("basin", "Pedestal Basin", basin, 0.05, "ceramic", true, true)
	var tray := Model.new(Vector3i(18, 2, 18))
	tray.box(Vector3i.ZERO, tray.size, CERAMIC)
	tray.cut(Vector3i(1, 1, 1), Vector3i(16, 1, 16))
	_model("shower_tray", "Shower Tray", tray, 0.05, "ceramic", true, true)
	for variant in ["landscape", "portrait"]:
		var art := Model.new(Vector3i(12, 14 if variant == "portrait" else 10, 1))
		art.box(Vector3i.ZERO, art.size, DARK_WOOD)
		art.box(Vector3i(1, 1, 0), Vector3i(10, art.size.y - 2, 1), LINEN)
		if variant == "portrait":
			art.ellipse(Vector3i(3, 4, 0), Vector3i(6, 8, 1), GOLD)
			art.box(Vector3i(2, 1, 0), Vector3i(8, 4, 1), BURGUNDY)
			art.box(Vector3i(4, 8, 0), Vector3i(1, 1, 1), INK)
			art.box(Vector3i(7, 8, 0), Vector3i(1, 1, 1), INK)
		else:
			art.box(Vector3i(1, 1, 0), Vector3i(10, 3, 1), GREEN)
			art.box(Vector3i(3, 4, 0), Vector3i(4, 3, 1), materials.brick.color)
			art.box(Vector3i(2, 7, 0), Vector3i(6, 1, 1), ROOF)
		_model("framed_" + variant, "Framed " + variant.capitalize(), art, 0.05, "wood", true, true)


func _make_small_props() -> void:
	var book := Model.new(Vector3i(10, 14, 3))
	book.box(Vector3i.ZERO, book.size, BURGUNDY)
	book.box(Vector3i(1, 1, 1), Vector3i(9, 12, 1), LINEN)
	book.box(Vector3i(0, 3, 0), Vector3i(1, 1, 3), GOLD)
	book.box(Vector3i(0, 10, 0), Vector3i(1, 1, 3), GOLD)
	_model("book", "Loose Book", book, 0.025, "wood", false, false, 0.7)
	var plate := Model.new(Vector3i(18, 3, 18))
	plate.ellipse(Vector3i.ZERO, plate.size, CERAMIC)
	plate.cut(Vector3i(4, 2, 4), Vector3i(10, 1, 10))
	_model("plate", "Plate", plate, 0.0125, "wood", false, false, 0.4)
	var utensil := Model.new(Vector3i(4, 2, 20))
	utensil.box(Vector3i(1, 0, 0), Vector3i(2, 1, 15), METAL)
	utensil.ellipse(Vector3i(0, 0, 13), Vector3i(4, 2, 7), METAL)
	_model("spoon", "Large Spoon", utensil, 0.0125, "painted_metal", false, false, 0.15)
	var bottle := Model.new(Vector3i(6, 14, 6))
	bottle.box(Vector3i(1, 0, 1), Vector3i(4, 10, 4), Color8(91, 117, 140))
	bottle.box(Vector3i(2, 10, 2), Vector3i(2, 4, 2), GOLD)
	bottle.box(Vector3i(1, 4, 0), Vector3i(4, 3, 1), LINEN)
	_model("bottle", "Laboratory Bottle", bottle, 0.025, "wood", false, false, 0.8)
	var scope := Model.new(Vector3i(18, 12, 12))
	scope.box(Vector3i.ZERO, scope.size, METAL)
	scope.box(Vector3i(1, 2, 0), Vector3i(12, 9, 1), INK)
	for x in range(2, 12):
		scope.box(Vector3i(x, 5 + int(sin(x * 0.8) * 2), 0), Vector3i.ONE, GREEN.lightened(0.3))
	for y in [3, 7]:
		scope.box(Vector3i(15, y, 0), Vector3i(2, 2, 1), GOLD)
	_model("oscilloscope", "Oscilloscope", scope, 0.025, "painted_metal", false, false, 7.0)
	var umbrella := Model.new(Vector3i(8, 36, 8))
	umbrella.box(Vector3i(3, 0, 3), Vector3i(2, 33, 2), METAL)
	umbrella.ellipse(Vector3i(0, 0, 0), Vector3i(8, 28, 8), BURGUNDY)
	umbrella.box(Vector3i(3, 32, 3), Vector3i(5, 2, 2), DARK_WOOD)
	umbrella.box(Vector3i(6, 29, 3), Vector3i(2, 4, 2), DARK_WOOD)
	_model("umbrella", "Umbrella", umbrella, 0.025, "wood", false, false, 1.1)
	var clock_model := Model.new(Vector3i(10, 12, 5))
	clock_model.box(Vector3i.ZERO, clock_model.size, DARK_WOOD)
	clock_model.ellipse(Vector3i(1, 3, 0), Vector3i(8, 8, 1), LINEN)
	clock_model.box(Vector3i(5, 6, 0), Vector3i(1, 3, 1), INK)
	clock_model.box(Vector3i(3, 6, 0), Vector3i(3, 1, 1), INK)
	_model("mantel_clock", "Mantel Clock", clock_model, 0.025, "wood", false, false, 1.8)
	var towel := Model.new(Vector3i(12, 3, 8))
	towel.box(Vector3i.ZERO, towel.size, LINEN)
	towel.box(Vector3i(1, 2, 0), Vector3i(1, 1, 8), GREEN)
	_model("towel", "Folded Towel", towel, 0.025, "wood", false, false, 0.4)


func _world_box(m: Model, origin: Vector3, low: Vector3, extent: Vector3, color: Color, erase := false) -> void:
	var start := Vector3i(((low - origin) / 0.2).round())
	var end := Vector3i(((low + extent - origin) / 0.2).round())
	start = start.max(Vector3i.ZERO)
	end = end.min(m.size)
	if end.x <= start.x or end.y <= start.y or end.z <= start.z:
		return
	if erase:
		m.cut(start, end - start)
	else:
		m.box(start, end - start, color)


func _door_specs() -> Array:
	return [
		["FrontDoor", Vector3(0, 0.41, -5.9), 0.0, "front_door"],
		["RearDoor", Vector3(0, 0.41, 5.9), 180.0, "front_door"],
		["LivingDoor", Vector3(-0.9, 0.41, -3.8), -90.0, "internal_door"],
		["KitchenDoor", Vector3(-0.9, 0.41, 0.2), -90.0, "internal_door"],
		["WorkshopDoor", Vector3(-0.9, 0.41, 4.4), -90.0, "internal_door"],
		["StudyDoor", Vector3(0.9, 0.41, -3.8), 90.0, "internal_door"],
		["BedroomDoor", Vector3(0.9, 0.41, 0.2), 90.0, "internal_door"],
		["BathroomDoor", Vector3(2.2, 0.41, 3.7), 0.0, "internal_door"],
		["UtilityDoor", Vector3(5.0, 0.41, 3.7), 0.0, "internal_door"],
	]


func _window_specs() -> Array:
	return [
		["LivingFront", Vector3(-3.6, 1.207, -5.9), 0.0],
		["StudyFront", Vector3(3.6, 1.207, -5.9), 0.0],
		["LivingWest", Vector3(-6.3, 1.207, -4.6), 90.0],
		["KitchenWest", Vector3(-6.3, 1.207, 0.2), 90.0],
		["WorkshopWest", Vector3(-6.3, 1.207, 4.4), 90.0],
		["StudyEast", Vector3(6.3, 1.207, -4.6), -90.0],
		["BedroomEast", Vector3(6.3, 1.207, 0.8), -90.0],
		["WorkshopRear", Vector3(-3.6, 1.207, 5.9), 180.0],
		["BathroomRear", Vector3(2.4, 1.207, 5.9), 180.0],
		["UtilityRear", Vector3(5.0, 1.207, 5.9), 180.0],
	]


func _opening(m: Model, origin: Vector3, centre: Vector3, yaw: float, width: float, height: float, bottom: float) -> void:
	var across_x := absf(sin(deg_to_rad(yaw))) < 0.5
	var cut_size := Vector3(width, height, 1.0) if across_x else Vector3(1.0, height, width)
	var low := centre - Vector3(cut_size.x * 0.5, 0, cut_size.z * 0.5)
	low.y = bottom
	# Timber jambs and lintel belong to the structural VOX, not floating trim nodes.
	var frame_size := Vector3(width + 0.4, height + 0.4, 0.4) if across_x else Vector3(0.4, height + 0.4, width + 0.4)
	var frame_low := Vector3(centre.x - frame_size.x * 0.5, bottom - 0.2, centre.z - frame_size.z * 0.5)
	_world_box(m, origin, frame_low, frame_size, OAK)
	_world_box(m, origin, low, cut_size, Color(), true)


func _make_architecture() -> void:
	for section in 6:
		var start_z := -6.0 + section * 2.0
		var origin := Vector3(-6.4, -0.8, start_z)
		var m := Model.new(Vector3i(64, 34, 10))
		# Only these feet occupy the model's bottom layer, which becomes anchored.
		for x in [-6.0, -1.0, 0.8, 5.6]:
			for z in [start_z + 0.2, start_z + 1.4]:
				_world_box(m, origin, Vector3(x, -0.8, z), Vector3(0.4, 1.0, 0.4), materials.concrete.color)
		_world_box(m, origin, Vector3(-6.4, 0.2, start_z), Vector3(12.8, 0.2, 2.0), OAK)
		_world_box(m, origin, Vector3(-6.4, 3.0, start_z), Vector3(12.8, 0.2, 2.0), CREAM)
		# Close the raised floor's outside edge with the same destructible brickwork.
		# The hollow crawlspace and the lowest, foot-only anchor layer stay intact.
		for x in [-6.4, 6.2]:
			_world_box(m, origin, Vector3(x, -0.2, start_z), Vector3(0.2, 3.4, 2.0), materials.brick.color)
		for x in [-6.2, 6.0, -1.0, 0.8]:
			_world_box(m, origin, Vector3(x, 0.4, start_z), Vector3(0.2, 2.6, 2.0), CREAM)
		for z in [-6.0, 5.8]:
			_world_box(m, origin, Vector3(-6.4, -0.2, z), Vector3(12.8, 3.4, 0.2), materials.brick.color)
		for z in [-5.8, 5.6]:
			_world_box(m, origin, Vector3(-6.2, 0.4, z), Vector3(12.4, 2.6, 0.2), CREAM)
		for z in [-1.8, 2.2]:
			for x in [-6.2, 1.0]:
				_world_box(m, origin, Vector3(x, 0.4, z), Vector3(5.2, 2.6, 0.2), CREAM)
		_world_box(m, origin, Vector3(1.0, 0.4, 3.6), Vector3(5.2, 2.6, 0.2), CREAM)
		_world_box(m, origin, Vector3(3.6, 0.4, 3.8), Vector3(0.2, 2.6, 2.0), CREAM)
		# The rear vestibule is an open connection to the central hallway.
		_world_box(m, origin, Vector3(0.8, 0.4, 2.4), Vector3(0.2, 2.2, 1.2), Color(), true)
		for door in _door_specs():
			_opening(m, origin, door[1], door[2], 1.2, 2.2, 0.4)
		for window in _window_specs():
			_opening(m, origin, window[1], window[2], 1.6, 1.4, 1.2)
		# Two-cell roof thickness joins the steps by faces, never only diagonally.
		for x in 64:
			var roof_y := 20 + mini(x, 63 - x) / 4
			m.box(Vector3i(x, roof_y - 1, 0), Vector3i(1, 2, 10), ROOF)
			if section == 0:
				m.box(Vector3i(x, 20, 0), Vector3i(1, maxi(1, roof_y - 19), 1), materials.brick.color)
			if section == 5:
				m.box(Vector3i(x, 20, 9), Vector3i(1, maxi(1, roof_y - 19), 1), materials.brick.color)
		# Posts and tie beams give every section its own support paths into its walls.
		for x in [1, 27, 35, 62]:
			var roof_y := 20 + mini(x, 63 - x) / 4
			m.box(Vector3i(x, 19, 4), Vector3i(1, roof_y - 18, 2), OAK)
		m.box(Vector3i(0, 18, 4), Vector3i(64, 1, 2), OAK)
		# Solid masonry chimney connected to the living room's west wall and roof.
		_world_box(m, origin, Vector3(-6.0, 0.4, -2.8), Vector3(0.6, 5.0, 0.6), materials.brick.color)
		_world_box(m, origin, Vector3(-6.2, 5.4, -3.0), Vector3(1.0, 0.2, 1.0), materials.brick.color)
		_model("structure_%02d" % section, "House Structural Section %d" % (section + 1), m, 0.2, "brick", true, true)
	var shed := Model.new(Vector3i(30, 29, 24))
	# Shed is one small connected body; feet anchor it, not its roof.
	for x in [1, 26]:
		for z in [1, 20]:
			shed.box(Vector3i(x, 0, z), Vector3i(3, 3, 3), materials.concrete.color)
	shed.box(Vector3i(0, 3, 0), Vector3i(30, 1, 24), OAK)
	for x in [0, 29]:
		shed.box(Vector3i(x, 4, 0), Vector3i(1, 20, 24), GREEN)
	for z in [0, 23]:
		shed.box(Vector3i(0, 4, z), Vector3i(30, 20, 1), GREEN)
	shed.cut(Vector3i(10, 4, 0), Vector3i(10, 20, 1))
	for x in 30:
		var y := 24 + mini(x, 29 - x) / 4
		shed.box(Vector3i(x, y - 1, 0), Vector3i(1, 2, 24), ROOF)
		shed.box(Vector3i(x, 24, 0), Vector3i(1, maxi(1, y - 23), 1), GREEN)
		shed.box(Vector3i(x, 24, 23), Vector3i(1, maxi(1, y - 23), 1), GREEN)
	_model("shed_structure", "Garden Shed Structure", shed, 0.1, "wood", true, true)
	var fence := Model.new(Vector3i(28, 15, 2))
	for x in [0, 26]:
		fence.box(Vector3i(x, 0, 0), Vector3i(2, 15, 2), DARK_WOOD)
	for y in [4, 11]:
		fence.box(Vector3i(0, y, 0), Vector3i(28, 2, 1), OAK)
	for x in range(2, 26, 2):
		fence.box(Vector3i(x, 2, 1), Vector3i(1, 12, 1), GREEN)
	_model("fence_panel", "Garden Fence Panel", fence, 0.1, "wood", true, true)


func _v(value: Variant) -> String:
	return var_to_str(value)


func _path(value: String) -> String:
	return "NodePath(" + _v(value) + ")"


func _body(scene: SceneText, label: String, id: String, at: Vector3, yaw := 0.0, parent := ".", extra: Dictionary = {}) -> void:
	var asset: Dictionary = assets[id]
	var prop: bool = asset.prop
	var properties := {
		"position": _v(at + (Vector3.UP * asset.size.y * 0.5 if prop else Vector3.ZERO)),
		"rotation": _v(Vector3(0, deg_to_rad(yaw), 0)),
		"script": scene.ext("res://physics/physics_prop.gd" if prop else "res://physics/voxels/voxel_body.gd", "Script"),
		"can_sleep": "true",
		"definition" if prop else "structure": scene.ext(asset.path),
	}
	properties.merge(extra, true)
	scene.node(label, "RigidBody3D", parent, properties)


func _existing(scene: SceneText, label: String, path: String, at: Vector3, angles := Vector3.ZERO, parent := ".") -> void:
	var definition: Resource = load(path)
	var prop := definition is PhysicsObjectDefinition
	var origin := at
	if prop:
		var basis := Basis.from_euler(angles * PI / 180.0)
		var bottom := INF
		for part in definition.get_collision_parts():
			var shape: Shape3D = part.shape
			var bounds: AABB = Transform3D(basis, Vector3.ZERO) * part.transform * shape.get_debug_mesh().get_aabb()
			bottom = minf(bottom, bounds.position.y)
		if is_finite(bottom):
			origin.y -= bottom
	scene.node(label, "RigidBody3D", parent, {
		"position": _v(origin), "rotation": _v(angles * PI / 180.0), "can_sleep": "true",
		"script": scene.ext("res://physics/physics_prop.gd" if prop else "res://physics/voxels/voxel_body.gd", "Script"),
		"definition" if prop else "structure": scene.ext(path),
	})


func _attachment(scene: SceneText, label: String, body: String, pivot: String, support: String, region: AABB, mount := AABB(), parent := ".") -> void:
	var properties := {
		"script": scene.ext("res://house/fixture_attachment.gd", "Script"),
		"body_path": _path(body), "support_region": _v(region), "mount_region": _v(mount),
	}
	if not pivot.is_empty():
		properties.pivot_path = _path(pivot)
	if not support.is_empty():
		properties.support_path = _path(support)
	scene.node(label, "Node", parent, properties)


func _hinge_scene(file: String, leaf: String, title: String, allow_lock := true, angle := -90.0, glass := "") -> void:
	var scene := SceneText.new()
	var size: Vector3 = assets[leaf].size
	scene.node(title.to_pascal_case(), "Node3D", "", {
		"script": scene.ext("res://house/breakable_hinge.gd", "Script"),
		"interaction_name": _v(title), "animation_duration": "0.4", "open_angle_degrees": str(angle),
		"allow_lock": _v(allow_lock),
	})
	# The hinge is on the opening face, so the thick leaf clears the tight jamb.
	var hinge_depth := -signf(angle) * size.z * 0.5 if file in ["front_door", "internal_door", "shed_door", "window"] else 0.0
	scene.node("Hinge", "Node3D", ".", {"position": _v(Vector3(-size.x * 0.5, 0, hinge_depth))})
	_body(scene, "Leaf", leaf, Vector3.ZERO)
	_attachment(scene, "Attachment", "../Leaf", "../Hinge", "", AABB(), AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), Vector3(0.1, size.y, size.z)))
	if not glass.is_empty():
		var glass_size: Vector3 = assets[glass].size
		var inset_y := (size.y - glass_size.y) * 0.5
		# A one-cell-deep VOX imports at z=0..cell_size; centre it inside the frame.
		_body(scene, "Glass", glass, Vector3(0, inset_y, -glass_size.z * 0.5), 0, ".", {"mesh_material_override": scene.ext(ASSETS + "materials/transparent_glass.tres")})
		_attachment(scene, "PaneAttachment", "../Glass", "../Hinge", "../Leaf", AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), Vector3(size.x, inset_y, size.z)))
	_write_scene(scene, file)


func _mounted_scene(file: String, id: String, doors: Array = [], drawers: Array = []) -> void:
	var scene := SceneText.new()
	var size: Vector3 = assets[id].size
	scene.node(file.to_pascal_case(), "Node3D", "", {"script": scene.ext("res://house/mounted_fixture.gd", "Script")})
	_body(scene, "Body", id, Vector3.ZERO)
	_attachment(scene, "Attachment", "../Body", "", "", AABB())
	for door in doors:
		var width: float = door[3]
		var at: Vector3 = door[1]
		var support_region := AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), Vector3(0.1, size.y, size.z))
		if at.x > 0.1:
			support_region.position.x = size.x * 0.5 - 0.1
		scene.node(door[0], "", ".", {
			"position": _v(at), "support_path": _path("../Body"), "support_region": _v(support_region),
			"open_angle_degrees": str(100.0 if at.x <= 0.1 else -100.0),
		}, SCENES + door[2] + ".tscn")
	for index in drawers.size():
		var at: Vector3 = drawers[index]
		scene.node("Drawer%d" % (index + 1), "", ".", {
			"position": _v(at), "support_path": _path("../Body"),
			"support_region": _v(AABB(Vector3(-size.x * 0.5, at.y, -size.z * 0.5), Vector3(0.1, 0.2, size.z))),
		}, SCENES + "drawer.tscn")
	_write_scene(scene, file)


func _make_fixture_scenes() -> void:
	_hinge_scene("front_door", "front_door_leaf", "Entrance Door")
	_hinge_scene("internal_door", "internal_door_leaf", "Door")
	_hinge_scene("shed_door", "shed_door_leaf", "Shed Door")
	_hinge_scene("window", "window_frame", "Window", true, 90.0, "window_glass")
	_hinge_scene("shower_screen", "screen_frame", "Shower Screen", false, 90.0, "screen_glass")
	_hinge_scene("cupboard_door", "cupboard_leaf", "Cupboard", false, 100.0)
	_hinge_scene("wardrobe_door", "wardrobe_leaf", "Wardrobe", false, 100.0)
	_hinge_scene("fridge_door", "fridge_leaf", "Fridge", false, 100.0)
	_hinge_scene("oven_door", "oven_leaf", "Oven", false, 100.0)
	var drawer := SceneText.new()
	drawer.node("Drawer", "Node3D", "", {"script": drawer.ext("res://house/sliding_drawer.gd", "Script"), "interaction_name": _v("Drawer")})
	drawer.node("Slide", "Node3D", ".")
	_body(drawer, "Tray", "drawer_tray", Vector3.ZERO)
	_attachment(drawer, "Attachment", "../Tray", "../Slide", "", AABB(), AABB(Vector3(-0.35, 0, 0.15), Vector3(0.7, 0.2, 0.1)))
	_write_scene(drawer, "drawer")
	_mounted_scene("kitchen_cupboard", "cabinet", [["Door", Vector3(0, 0.1, -0.325), "cupboard_door", 0.7]])
	_mounted_scene("kitchen_drawers", "drawer_cabinet", [], [Vector3(0, 0.1, -0.05), Vector3(0, 0.35, -0.05), Vector3(0, 0.6, -0.05)])
	_mounted_scene("kitchen_sink", "sink", [["Door", Vector3(0, 0.1, -0.325), "cupboard_door", 0.7]])
	_mounted_scene("fridge", "fridge", [["Door", Vector3(0, 0.1, -0.45), "fridge_door", 0.8]])
	_mounted_scene("oven", "oven", [["Door", Vector3(0, 0.15, -0.35), "oven_door", 0.7]])
	_mounted_scene("wardrobe", "wardrobe", [["LeftDoor", Vector3(-0.4, 0.1, -0.325), "wardrobe_door", 0.7], ["RightDoor", Vector3(0.4, 0.1, -0.325), "wardrobe_door", 0.7]])
	_mounted_scene("display_cabinet", "display_cabinet", [["Door", Vector3(0, 0.1, -0.275), "cupboard_door", 0.7]])
	for id in ["washer", "toilet", "basin", "shower_tray", "framed_landscape", "framed_portrait"]:
		_mounted_scene(id, id)


func _structure_support(world_region: AABB, levels := 3) -> Dictionary:
	var section := clampi(int(floor((world_region.get_center().z + 6.0) / 2.0)), 0, 5)
	var origin := Vector3(0, -0.8, -5.0 + section * 2.0)
	return {
		"support_path": _path("../".repeat(levels) + "Architecture/Section%d" % section),
		"support_region": _v(AABB(world_region.position - origin, world_region.size)),
	}


func _fixture(scene: SceneText, label: String, file: String, at: Vector3, yaw := 0.0, region := AABB(), levels := 3) -> void:
	if not region.has_volume():
		region = AABB(Vector3(at.x - 0.2, 0.2, at.z - 0.2), Vector3(0.4, 0.2, 0.4))
	var properties := _structure_support(region, levels)
	properties.position = _v(at)
	properties.rotation = _v(Vector3(0, deg_to_rad(yaw), 0))
	scene.node(label, "", ".", properties, SCENES + file + ".tscn")


func _room(label: String) -> SceneText:
	var scene := SceneText.new()
	scene.node(label, "Node3D", "")
	return scene


func _books(scene: SceneText, prefix: String, at: Vector3, count: int, yaw := 0.0) -> void:
	for index in count:
		_body(scene, "%s%d" % [prefix, index + 1], "book", at + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(index * 0.085, 0, 0), yaw + 90.0)


func _make_rooms() -> void:
	var hall := _room("Hall")
	_body(hall, "CoatRack", "coat_rack", Vector3(-0.48, 0.4, -2.7))
	_body(hall, "Console", "console", Vector3(0.55, 0.4, -1.65), 90)
	_body(hall, "ConsoleLamp", "table_lamp", Vector3(0.55, 1.15, -1.95))
	_body(hall, "Clock", "mantel_clock", Vector3(0.5, 1.15, -1.3), 90)
	_body(hall, "Umbrella", "umbrella", Vector3(-0.6, 0.4, -2.1))
	_fixture(hall, "HallPortrait", "framed_portrait", Vector3(0.76, 1.65, -2.1), 90, AABB(Vector3(0.8, 1.6, -2.2), Vector3(0.2, 0.6, 0.2)))
	_write_scene(hall, "hall")
	var living := _room("LivingRoom")
	_body(living, "Sofa", "sofa", Vector3(-4.1, 0.4, -2.5))
	_body(living, "ArmchairWest", "armchair", Vector3(-5.4, 0.4, -4.3), -90)
	_body(living, "ArmchairEast", "armchair", Vector3(-3.2, 0.4, -4.9), 35)
	_body(living, "CoffeeTable", "coffee_table", Vector3(-4.1, 0.4, -3.75))
	_body(living, "SideTableWest", "side_table", Vector3(-5.55, 0.4, -2.35))
	_body(living, "SideTableEast", "side_table", Vector3(-2.55, 0.4, -2.35))
	_body(living, "SideLamp", "table_lamp", Vector3(-5.55, 0.95, -2.35))
	_body(living, "FloorLamp", "floor_lamp", Vector3(-1.45, 0.4, -5.2))
	_body(living, "TVStand", "tv_stand", Vector3(-4.7, 0.4, -5.25), 180)
	_body(living, "Television", "television", Vector3(-4.7, 0.9, -5.25), 180)
	_existing(living, "Bookshelf", "res://props/voxel_structures/bookshelf.tres", Vector3(-1.5, 0.4, -2.2))
	_existing(living, "Tea", "res://props/objects/teapot.tres", Vector3(-4.25, 0.85, -3.7))
	_existing(living, "Mug", "res://props/objects/coffee_mug.tres", Vector3(-3.8, 0.85, -3.8))
	_body(living, "ReadingBook", "book", Vector3(-4.45, 0.85, -3.6), 70)
	_body(living, "SideClock", "mantel_clock", Vector3(-2.55, 0.95, -2.35))
	_existing(living, "Basket", "res://props/plastic_basket.tres", Vector3(-1.45, 0.4, -2.85))
	_existing(living, "RubberDuck", "res://props/objects/rubber_duck.tres", Vector3(-5.15, 0.9, -5.2))
	_fixture(living, "Landscape", "framed_landscape", Vector3(-3.9, 1.8, -1.86), 0, AABB(Vector3(-4.0, 1.7, -1.8), Vector3(0.4, 0.5, 0.2)))
	_write_scene(living, "living_room")
	var kitchen := _room("Kitchen")
	_fixture(kitchen, "Drawers", "kitchen_drawers", Vector3(-5.65, 0.4, -1.05), -90)
	_fixture(kitchen, "Sink", "kitchen_sink", Vector3(-5.65, 0.4, -0.15), -90)
	_fixture(kitchen, "CupboardWest", "kitchen_cupboard", Vector3(-5.65, 0.4, 0.75), -90)
	_fixture(kitchen, "Oven", "oven", Vector3(-4.7, 0.4, 1.85))
	_fixture(kitchen, "CupboardRearA", "kitchen_cupboard", Vector3(-3.8, 0.4, 1.85))
	_fixture(kitchen, "CupboardRearB", "kitchen_cupboard", Vector3(-2.9, 0.4, 1.85))
	_fixture(kitchen, "Fridge", "fridge", Vector3(-2.0, 0.4, 1.55))
	_existing(kitchen, "KitchenTable", "res://props/voxel_structures/table.tres", Vector3(-3.25, 0.4, -0.65))
	for spec in [["ChairWest", Vector3(-4.15, 0.4, -0.65), -90], ["ChairEast", Vector3(-2.7, 0.4, -0.65), 90], ["ChairFront", Vector3(-3.25, 0.4, -1.3), 180]]:
		_existing(kitchen, spec[0], "res://props/voxel_structures/chair.tres", spec[1], Vector3(0, spec[2], 0))
	for index in 2:
		_body(kitchen, "Plate%d" % index, "plate", Vector3(-3.55 + index * 0.6, 1.2, -0.65))
		_body(kitchen, "Spoon%d" % index, "spoon", Vector3(-3.35 + index * 0.6, 1.2, -0.7))
	_existing(kitchen, "TableMug", "res://props/objects/coffee_mug.tres", Vector3(-3.15, 1.2, -0.4))
	_existing(kitchen, "PanOnHob", "res://props/tools/frying_pan.tres", Vector3(-4.7, 1.25, 1.8), Vector3(90, 25, 0))
	_existing(kitchen, "CounterTeapot", "res://props/objects/teapot.tres", Vector3(-3.8, 1.25, 1.85))
	_body(kitchen, "CounterPlate", "plate", Vector3(-2.9, 1.25, 1.8))
	_existing(kitchen, "CupboardMug", "res://props/objects/coffee_mug.tres", Vector3(-3.8, 0.85, 1.85))
	_body(kitchen, "DrawerUtensil", "spoon", Vector3(-5.55, 1.075, -1.05), 90)
	_body(kitchen, "FridgeBottle", "bottle", Vector3(-2.0, 1.45, 1.5))
	_write_scene(kitchen, "kitchen")
	var study := _room("StudyDining")
	_existing(study, "DiningTable", "res://props/voxel_structures/table.tres", Vector3(3.8, 0.4, -4.4))
	for spec in [[Vector3(2.9, 0.4, -4.4), -90], [Vector3(4.7, 0.4, -4.4), 90], [Vector3(3.8, 0.4, -5.08), 180], [Vector3(3.8, 0.4, -3.72), 0]]:
		_existing(study, "DiningChair%d" % study.nodes.size(), "res://props/voxel_structures/chair.tres", spec[0], Vector3(0, spec[1], 0))
	_body(study, "WritingDesk", "desk", Vector3(5.5, 0.4, -2.5), 90)
	_existing(study, "DeskChair", "res://props/voxel_structures/chair.tres", Vector3(4.55, 0.4, -2.5), Vector3(0, -90, 0))
	_existing(study, "Bookshelf", "res://props/voxel_structures/bookshelf.tres", Vector3(1.55, 0.4, -2.3))
	_fixture(study, "DisplayCabinet", "display_cabinet", Vector3(5.3, 0.4, -5.25), 180)
	_existing(study, "GoldenTrophy", "res://props/objects/trophy.tres", Vector3(5.3, 1.45, -5.25))
	_body(study, "DeskLamp", "table_lamp", Vector3(5.5, 1.15, -2.9))
	_books(study, "DeskBook", Vector3(5.45, 1.15, -2.25), 2, 90)
	_existing(study, "DeskMug", "res://props/objects/coffee_mug.tres", Vector3(5.3, 1.15, -2.55))
	_existing(study, "DiningTeapot", "res://props/objects/teapot.tres", Vector3(3.85, 1.2, -4.4))
	_body(study, "DiningPlate", "plate", Vector3(3.55, 1.2, -4.35))
	_fixture(study, "EccentricPortrait", "framed_portrait", Vector3(2.6, 1.7, -1.86), 0, AABB(Vector3(2.4, 1.6, -1.8), Vector3(0.4, 0.6, 0.2)))
	_write_scene(study, "study")
	var bedroom := _room("Bedroom")
	_body(bedroom, "Bed", "bed", Vector3(3.3, 0.4, 0.65))
	_body(bedroom, "BedsideWest", "bedside", Vector3(2.0, 0.4, 1.65))
	_body(bedroom, "BedsideEast", "bedside", Vector3(4.6, 0.4, 1.65))
	_body(bedroom, "BedsideLamp", "table_lamp", Vector3(2.0, 0.9, 1.65))
	_body(bedroom, "AlarmClock", "mantel_clock", Vector3(4.6, 0.9, 1.65))
	_fixture(bedroom, "Wardrobe", "wardrobe", Vector3(5.65, 0.4, -0.65), 90)
	_books(bedroom, "ReadingBook", Vector3(4.5, 0.9, 1.65), 1)
	_existing(bedroom, "LaundryBasket", "res://props/plastic_basket.tres", Vector3(2.0, 0.4, -1.05))
	_fixture(bedroom, "Landscape", "framed_landscape", Vector3(3.3, 1.7, 2.14), 0, AABB(Vector3(3.1, 1.6, 2.2), Vector3(0.4, 0.5, 0.2)))
	_write_scene(bedroom, "bedroom")
	var workshop := _room("LaboratoryWorkshop")
	_body(workshop, "WestWorkbench", "workbench", Vector3(-5.55, 0.4, 3.45), -90)
	_body(workshop, "RearWorkbench", "workbench", Vector3(-3.8, 0.4, 5.1))
	_body(workshop, "StorageShelf", "storage_shelf", Vector3(-3.0, 0.4, 2.7), 180)
	_body(workshop, "Oscilloscope", "oscilloscope", Vector3(-5.55, 1.3, 3.7), -90)
	_body(workshop, "ExperimentBottleA", "bottle", Vector3(-5.55, 1.3, 3.05))
	_body(workshop, "ExperimentBottleB", "bottle", Vector3(-5.4, 1.3, 3.25))
	_existing(workshop, "Sledgehammer", "res://props/hammer.tres", Vector3(-3.8, 1.3, 5.1), Vector3(0, 0, 90))
	_existing(workshop, "Axe", "res://props/tools/axe.tres", Vector3(-3.85, 1.3, 4.87), Vector3(0, 0, 90))
	_existing(workshop, "Trowel", "res://props/trowel.tres", Vector3(-4.25, 1.3, 5.3), Vector3(90, 0, 0))
	_existing(workshop, "Pickaxe", "res://props/tools/pickaxe.tres", Vector3(-5.4, 0.4, 4.65), Vector3(0, 0, 90))
	_existing(workshop, "WoodenBox", "res://props/open_wooden_box.tres", Vector3(-1.65, 0.4, 2.85))
	_existing(workshop, "Bucket", "res://props/bucket.tres", Vector3(-2.15, 0.4, 2.95))
	_existing(workshop, "Basket", "res://props/plastic_basket.tres", Vector3(-3.0, 0.95, 2.7))
	_existing(workshop, "Stool", "res://props/voxel_structures/stool.tres", Vector3(-4.5, 0.4, 3.45))
	_existing(workshop, "Anvil", "res://props/objects/anvil.tres", Vector3(-2.65, 0.4, 5.15))
	_existing(workshop, "TestBall", "res://props/objects/bowling_ball.tres", Vector3(-3.0, 1.45, 2.7))
	_existing(workshop, "FoamDie", "res://props/objects/foam_die.tres", Vector3(-3.3, 0.4, 3.6))
	_existing(workshop, "BreakableCrate", "res://props/voxel_structures/breakable_crate.tres", Vector3(-5.45, 0.4, 5.25))
	_write_scene(workshop, "workshop")
	var bath := _room("Bathroom")
	_fixture(bath, "Toilet", "toilet", Vector3(1.5, 0.4, 5.25), -90)
	_fixture(bath, "Basin", "basin", Vector3(3.3, 0.4, 4.15), 90)
	_fixture(bath, "ShowerTray", "shower_tray", Vector3(2.95, 0.4, 5.1))
	_fixture(bath, "ShowerScreen", "shower_screen", Vector3(2.95, 0.5, 4.65), 0, AABB(Vector3(2.45, 0.2, 4.5), Vector3(0.3, 0.2, 0.3)))
	_body(bath, "FoldedTowel", "towel", Vector3(3.3, 1.25, 4.2))
	_existing(bath, "BathDuck", "res://props/objects/rubber_duck.tres", Vector3(2.9, 0.45, 5.15))
	_write_scene(bath, "bathroom")
	var utility := _room("UtilityStorage")
	_fixture(utility, "WashingMachine", "washer", Vector3(5.65, 0.4, 5.15))
	_body(utility, "Shelving", "storage_shelf", Vector3(4.5, 0.4, 5.3))
	_existing(utility, "StoredCrate", "res://props/wooden_crate.tres", Vector3(4.4, 2.1, 5.2))
	_existing(utility, "CleaningBucket", "res://props/bucket.tres", Vector3(5.7, 1.25, 5.3))
	_existing(utility, "LaundryBasket", "res://props/plastic_basket.tres", Vector3(4.5, 0.95, 5.25))
	_body(utility, "Towels", "towel", Vector3(5.6, 1.25, 4.98))
	_write_scene(utility, "utility")


func _static_box(scene: SceneText, label: String, at: Vector3, size: Vector3, color: Color, angles := Vector3.ZERO) -> void:
	var mat := scene.sub("StandardMaterial3D", {"albedo_color": _v(color), "roughness": "0.95"})
	var mesh := scene.sub("BoxMesh", {"size": _v(size), "material": mat})
	var shape := scene.sub("BoxShape3D", {"size": _v(size)})
	scene.node(label, "StaticBody3D", ".", {"position": _v(at), "rotation": _v(angles * PI / 180.0)})
	scene.node("Mesh", "MeshInstance3D", label, {"mesh": mesh})
	scene.node("Collision", "CollisionShape3D", label, {"shape": shape})


func _make_garden() -> void:
	var garden := _room("Garden")
	var grass := Color8(94, 120, 66)
	_static_box(garden, "WestLawn", Vector3(-10.2, -0.2, 4), Vector3(7.6, 0.4, 32), grass)
	_static_box(garden, "EastLawn", Vector3(10.2, -0.2, 4), Vector3(7.6, 0.4, 32), grass)
	_static_box(garden, "FrontLawn", Vector3(0, -0.2, -9), Vector3(12.8, 0.4, 6), grass)
	_static_box(garden, "RearLawn", Vector3(0, -0.2, 13), Vector3(12.8, 0.4, 14), grass)
	_static_box(garden, "CrawlspaceEarth", Vector3(0, -1.2, 0), Vector3(12.8, 0.4, 12), Color8(84, 65, 49))
	_static_box(garden, "FrontPath", Vector3(0, 0.01, -10), Vector3(1.6, 0.04, 4), Color8(156, 149, 133))
	_static_box(garden, "EntranceRamp", Vector3(0, 0.15, -7), Vector3(1.6, 0.1, 2.04), Color8(156, 149, 133), Vector3(-11.31, 0, 0))
	_static_box(garden, "Patio", Vector3(0, 0.2, 7.5), Vector3(6, 0.4, 3), Color8(157, 150, 132))
	_static_box(garden, "PatioRamp", Vector3(0, 0.15, 10), Vector3(1.6, 0.1, 2.04), Color8(157, 150, 132), Vector3(11.31, 0, 0))
	for index in 10:
		var x := -12.6 + index * 2.8
		_body(garden, "RearFence%d" % index, "fence_panel", Vector3(x, -0.1, 19.8))
		if absf(x) > 2.0:
			_body(garden, "FrontFence%d" % index, "fence_panel", Vector3(x, -0.1, -11.8))
	for index in 11:
		var z := -10.4 + index * 2.8
		_body(garden, "WestFence%d" % index, "fence_panel", Vector3(-13.8, -0.1, z), 90)
		_body(garden, "EastFence%d" % index, "fence_panel", Vector3(13.8, -0.1, z), 90)
	_body(garden, "Shed", "shed_structure", Vector3(-9, -0.3, 13))
	garden.node("ShedDoor", "", ".", {
		"position": _v(Vector3(-9, 0.11, 11.85)), "support_path": _path("../Shed"),
		"support_region": _v(AABB(Vector3(-0.7, 0.4, -1.2), Vector3(0.2, 1.8, 0.2))),
	}, SCENES + "shed_door.tscn")
	_body(garden, "ShedShelf", "storage_shelf", Vector3(-9, 0.1, 13.85))
	_existing(garden, "ShedBucket", "res://props/bucket.tres", Vector3(-9, 0.65, 13.8))
	_existing(garden, "GardenBroom", "res://props/tools/broom.tres", Vector3(-10, 0.1, 13))
	_existing(garden, "ShedCrate", "res://props/voxel_structures/breakable_crate.tres", Vector3(-8, 0.1, 13.6))
	_body(garden, "PatioBench", "garden_bench", Vector3(-2, 0.4, 7.7), -90)
	_existing(garden, "PatioTable", "res://props/voxel_structures/table.tres", Vector3(1.65, 0.4, 7.4))
	_existing(garden, "PatioChairA", "res://props/voxel_structures/chair.tres", Vector3(1.65, 0.4, 6.6), Vector3(0, 180, 0))
	_existing(garden, "PatioChairB", "res://props/voxel_structures/chair.tres", Vector3(1.65, 0.4, 8.2))
	_existing(garden, "PatioMug", "res://props/objects/coffee_mug.tres", Vector3(1.65, 1.2, 7.4))
	for pos in [Vector3(-2.7, 0.4, 6.55), Vector3(2.7, 0.4, 8.55), Vector3(-1.6, 0, -7.9), Vector3(1.6, 0, -7.9)]:
		_body(garden, "Planter%d" % garden.nodes.size(), "plant_pot", pos)
	_existing(garden, "Gnome", "res://props/objects/garden_gnome.tres", Vector3(-2.2, 0, -8.1))
	_existing(garden, "Football", "res://props/objects/football.tres", Vector3(6.5, 0, 10.5))
	_existing(garden, "TennisBall", "res://props/objects/tennis_ball.tres", Vector3(6.8, 0, 10.8))
	_existing(garden, "WoodenBat", "res://props/wooden_bat.tres", Vector3(5.9, 0, 10.8), Vector3(0, 0, 90))
	_existing(garden, "GardenBox", "res://props/open_wooden_box.tres", Vector3(5.3, 0, 10.5))
	_existing(garden, "GardenPlank", "res://props/objects/plank.tres", Vector3(-7, 0, 11), Vector3(0, 30, 0))
	_existing(garden, "GardenCrate", "res://props/voxel_structures/breakable_crate.tres", Vector3(-7, 0, 11.8))
	_existing(garden, "Pumpkin", "res://props/voxel_structures/pumpkin.tres", Vector3(-10.9, 0, 12))
	_write_scene(garden, "garden")


func _make_house() -> void:
	var structure := _room("Architecture")
	for index in 6:
		_body(structure, "Section%d" % index, "structure_%02d" % index, Vector3(0, -0.8, -5.0 + index * 2.0))
	_write_scene(structure, "architecture")
	var fixtures := _room("Fixtures")
	for door in _door_specs():
		var transform := Transform3D(Basis(Vector3.UP, deg_to_rad(door[2])), door[1])
		var region: AABB = transform * AABB(Vector3(-0.8, 0.2, -0.15), Vector3(0.2, 1.7, 0.3))
		_fixture(fixtures, door[0], door[3], door[1], door[2], region, 2)
	for window in _window_specs():
		var transform := Transform3D(Basis(Vector3.UP, deg_to_rad(window[2])), window[1])
		var region: AABB = transform * AABB(Vector3(-1.0, 0.1, -0.15), Vector3(0.2, 1.0, 0.3))
		_fixture(fixtures, window[0], "window", window[1], window[2], region, 2)
	_write_scene(fixtures, "fixtures")
	var scene := SceneText.new()
	var sky_material := scene.sub("ProceduralSkyMaterial", {
		"sky_horizon_color": "Color(0.66224277, 0.6717428, 0.6867428, 1)",
		"ground_horizon_color": "Color(0.66224277, 0.6717428, 0.6867428, 1)",
	})
	var sky := scene.sub("Sky", {"sky_material": sky_material})
	var environment := scene.sub("Environment", {
		"background_mode": "2", "sky": sky, "ambient_light_source": "3", "tonemap_mode": "2",
		"ssr_enabled": "true", "ssao_enabled": "true", "ssil_enabled": "true", "sdfgi_enabled": "true", "glow_enabled": "true",
	})
	scene.node("House", "Node3D", "", {"script": scene.ext("res://house/house.gd", "Script")})
	scene.node("WorldEnvironment", "WorldEnvironment", ".", {"environment": environment})
	scene.node("Sun", "DirectionalLight3D", ".", {
		"transform": "Transform3D(-0.8660254, -0.43301278, 0.25, 0, 0.49999997, 0.86602545, -0.50000006, 0.75, -0.43301266, 0, 0, 0)",
		"shadow_enabled": "true",
	})
	scene.node("Architecture", "", ".", {}, SCENES + "architecture.tscn")
	scene.node("Fixtures", "", ".", {}, SCENES + "fixtures.tscn")
	scene.node("Rooms", "Node3D", ".")
	for room in [["Hall", "hall"], ["LivingRoom", "living_room"], ["Kitchen", "kitchen"], ["Study", "study"], ["Bedroom", "bedroom"], ["Workshop", "workshop"], ["Bathroom", "bathroom"], ["Utility", "utility"]]:
		scene.node(room[0], "", "Rooms", {}, SCENES + room[1] + ".tscn")
	scene.node("Garden", "", ".", {}, SCENES + "garden.tscn")
	scene.node("DaylightFill", "Node3D", ".")
	for at in [Vector3(-3.5, 2.65, -3.5), Vector3(3.5, 2.65, -3.5), Vector3(-3.5, 2.65, 0.4), Vector3(3.5, 2.65, 0.4), Vector3(-3.5, 2.65, 4), Vector3(3.5, 2.65, 4.4), Vector3(0, 2.65, 0)]:
		scene.node("Fill%d" % scene.nodes.size(), "OmniLight3D", "DaylightFill", {
			"position": _v(at), "light_color": "Color(1, 0.94, 0.83, 1)", "light_energy": "0.45",
			"omni_range": "4.2", "shadow_enabled": "false",
		})
	scene.node("Player", "", ".", {"position": "Vector3(0, 0.05, -9.5)", "rotation": "Vector3(0, 3.14159265, 0)", "interaction_distance": "4.0"}, "res://player.tscn")
	_write_scene(scene, "house")
