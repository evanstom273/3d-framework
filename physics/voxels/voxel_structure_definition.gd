@tool
class_name VoxelStructureDefinition
extends Resource
## An authored voxel structure (wall, pillar, bridge) built from solid boxes.
## Assign it to a VoxelBody. Cell (0, 0, 0) spans the body's origin to one voxel
## along +X, +Y and +Z.

enum AnchorMode {
	## The lowest layer is fixed to the world; anything cut off from it falls.
	BOTTOM_LAYER,
	## Not fixed: the whole structure is a free physics object.
	NONE,
}

@export var display_name: String = "Wall"
## Spawn menu tab. Empty picks one automatically (Destructible if free-standing,
## Structures if anchored).
@export var spawn_category: String = ""
@export_range(0.02, 1.0, 0.01, "suffix:m") var voxel_size: float = 0.1:
	set(value):
		voxel_size = value
		emit_changed()
@export var anchor_mode: AnchorMode = AnchorMode.BOTTOM_LAYER:
	set(value):
		anchor_mode = value
		emit_changed()
## Multiplies the mass the voxels add up to. Thin parts (a board, a pane, sheet
## metal) are much thinner than a voxel, so generated furniture uses this to
## reach its real-world weight.
@export_range(0.01, 10.0, 0.01) var density_scale: float = 1.0:
	set(value):
		density_scale = value
		emit_changed()
@export var boxes: Array[VoxelFillBox] = []:
	set(value):
		for box in boxes:
			if box != null and box.changed.is_connected(emit_changed):
				box.changed.disconnect(emit_changed)
		boxes = value
		for box in boxes:
			if box != null and not box.changed.is_connected(emit_changed):
				box.changed.connect(emit_changed)
		emit_changed()

@export_group("MagicaVoxel")
## Build this structure from a MagicaVoxel model instead of `boxes`. Re-saving the
## model in MagicaVoxel updates it. For exported builds, add *.vox to the export
## filter's non-resource files.
@export_file("*.vox") var vox_file: String = "":
	set(value):
		vox_file = value
		_vox_boxes.clear()
		emit_changed()
## Physical material for every voxel in the model.
@export var vox_material: VoxelMaterialDefinition:
	set(value):
		vox_material = value
		_vox_boxes.clear()
		emit_changed()
## Other materials in the model: voxels whose colour matches one of these
## materials' colours use it (e.g. glass in a wooden frame). Others use vox_material.
@export var vox_extra_materials: Array[VoxelMaterialDefinition] = []:
	set(value):
		vox_extra_materials = value
		_vox_boxes.clear()
		emit_changed()
## Keep the model's colours (otherwise everything uses the material's colour).
@export var vox_keep_colors: bool = true:
	set(value):
		vox_keep_colors = value
		_vox_boxes.clear()
		emit_changed()
## Palette index -> VoxelMaterialDefinition. Generated models (furniture) record
## each voxel's material here, so shading never changes what a voxel is made of.
## Takes priority over vox_extra_materials' colour matching.
@export var vox_index_materials: Dictionary = {}:
	set(value):
		vox_index_materials = value
		_vox_boxes.clear()
		emit_changed()
## Doors, drawers and lids that open (furniture). Built onto the body at spawn.
@export var moving_parts: Array[FurniturePart] = []

var _vox_boxes: Array[VoxelFillBox] = []


## The boxes to build: from the .vox model when one is set, otherwise `boxes`.
func get_boxes() -> Array[VoxelFillBox]:
	if vox_file.is_empty():
		return boxes
	if _vox_boxes.is_empty():
		_vox_boxes = VoxFile.to_boxes(vox_file, vox_material, vox_keep_colors, vox_extra_materials, vox_index_materials)
	return _vox_boxes
