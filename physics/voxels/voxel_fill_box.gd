@tool
class_name VoxelFillBox
extends Resource
## A solid box of voxels in a structure, in cell coordinates.

@export var min_cell: Vector3i = Vector3i.ZERO:
	set(value):
		min_cell = value
		emit_changed()
@export var size: Vector3i = Vector3i(4, 4, 4):
	set(value):
		size = value
		emit_changed()
@export var material: VoxelMaterialDefinition:
	set(value):
		if material != null and material.changed.is_connected(emit_changed):
			material.changed.disconnect(emit_changed)
		material = value
		if material != null:
			material.changed.connect(emit_changed)
		emit_changed()
## Recolours these voxels while keeping the material's physical behaviour
## (e.g. colours from a MagicaVoxel model). Alpha 0 uses the material's colour.
@export var color_override: Color = Color(0, 0, 0, 0):
	set(value):
		color_override = value
		emit_changed()


## The material these voxels actually use, including any colour override.
func get_effective_material() -> VoxelMaterialDefinition:
	if material == null or color_override.a <= 0.0:
		return material
	return material.get_color_variant(color_override)
