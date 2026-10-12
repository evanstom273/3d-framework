class_name ModelExporter
extends RefCounted
## Turns a finished FurnitureModel into game data: a palette with each colour's
## real material, one .vox per part (all on the model's shared grid, so parts
## line up with the body), and VoxelStructureDefinitions. Shared by the
## furniture and NPC generators (tools/generate_furniture.gd, tools/generate_npc.gd).

## Finish shades: multipliers for shade 0, 1, 2.
const SHADES := {
	FurnitureModel.Finish.PLAIN: [1.0, 1.0, 1.0],
	FurnitureModel.Finish.GRAIN: [1.0, 0.9, 1.08],
	FurnitureModel.Finish.FABRIC: [1.0, 0.92, 1.0],
	FurnitureModel.Finish.BRUSHED: [1.0, 1.09, 1.0],
	FurnitureModel.Finish.SPECKLE: [1.0, 0.94, 1.05],
}


## Palette entries for every (paint, shade) used, the material behind each
## index, the cells of each part keyed by group (0 = body), and the raw mass.
## Returns {} if the palette overflows (more than 255 colours).
static func palette(model: FurnitureModel, materials: Dictionary) -> Dictionary:
	var colors := PackedColorArray([Color.BLACK])
	var index_of := {}
	var index_materials := {}
	var indexed := {}
	var mass := 0.0
	var cell_volume := pow(model.voxel, 3.0)
	for cell: Vector3i in model.cells:
		var entry: Array = model.cells[cell]
		var key := Vector2i(entry[0], entry[1])
		if not index_of.has(key):
			if colors.size() >= 256:
				return {}
			var part: Array = model.parts[entry[0]]
			var shade: float = SHADES[part[2]][entry[1]]
			var color: Color = part[1]
			colors.append(Color(clampf(color.r * shade, 0, 1), clampf(color.g * shade, 0, 1), clampf(color.b * shade, 0, 1)))
			index_of[key] = colors.size() - 1
			index_materials[colors.size() - 1] = materials[part[0]]
		var group: int = entry[2] if entry.size() > 2 else 0
		if not indexed.has(group):
			indexed[group] = {}
		indexed[group][cell] = index_of[key]
		mass += materials[model.parts[entry[0]][0]].density * cell_volume
	return {"colors": colors, "index_materials": index_materials, "indexed": indexed, "mass": mass}


## A model-space point (metres, as given to the DSL) in the loaded body's space:
## VoxFile centres x and z on the grid and keeps y from 0.
static func to_body(model: FurnitureModel, grid: Vector3i, point: Vector3) -> Vector3:
	var p := point / model.voxel - Vector3(model.shift)
	return (p - Vector3(grid.x / 2, 0, grid.z / 2)) * model.voxel


## A definition for one part's .vox, sharing the palette's material map.
static func definition(display_name: String, vox_path: String, voxel: float, index_materials: Dictionary,
		main_material: VoxelMaterialDefinition, density_scale := 1.0) -> VoxelStructureDefinition:
	var result := VoxelStructureDefinition.new()
	result.display_name = display_name
	result.voxel_size = voxel
	result.anchor_mode = VoxelStructureDefinition.AnchorMode.NONE
	result.vox_file = vox_path
	result.vox_material = main_material
	result.vox_keep_colors = true
	result.vox_index_materials = index_materials
	result.density_scale = density_scale
	return result
