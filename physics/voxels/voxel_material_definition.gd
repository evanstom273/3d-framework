@tool
class_name VoxelMaterialDefinition
extends Resource
## What a voxel is made of: how it looks, how much damage it takes to knock out,
## and how heavy the pieces that break off are.

@export var display_name: String = "Brick"
@export var color: Color = Color(0.66, 0.3, 0.22):
	set(value):
		color = value
		emit_changed()
## Optional rendering for these voxels, e.g. transparent glass in a wooden frame.
## Physical properties and destruction still come from this resource.
@export var mesh_material_override: StandardMaterial3D:
	set(value):
		mesh_material_override = value
		emit_changed()
## Random per-voxel brightness variation, so surfaces don't look flat.
@export_range(0.0, 0.5, 0.01) var color_jitter: float = 0.08:
	set(value):
		color_jitter = value
		emit_changed()
## Damage needed to knock a voxel out. Partly damaged voxels darken.
@export_range(1.0, 500.0, 0.5) var strength: float = 10.0
## Mass of one cubic metre, used for broken-off pieces (brick is about 1900).
@export_range(10.0, 10000.0, 10.0, "suffix:kg/m³") var density: float = 1900.0
@export_range(0.0, 1.0, 0.01) var friction: float = 0.8
@export_range(0.0, 1.0, 0.01) var bounce: float = 0.05
## How much of a strike's damage this material takes, per impact type: blunt
## (hammers, crashes), sharp (axes) and pierce (pickaxes). 1 = as dealt.
@export_range(0.0, 5.0, 0.05) var blunt_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var sharp_multiplier: float = 1.0
@export_range(0.0, 5.0, 0.05) var pierce_multiplier: float = 1.0
## What hits on this material sound like.
@export var impact_sound: ImpactFeedback.Sound = ImpactFeedback.Sound.STONE
## Chance that a knocked-out voxel becomes a grabbable rubble piece instead of dust.
@export_range(0.0, 1.0, 0.01) var rubble_fraction: float = 0.2

var _physics_material: PhysicsMaterial
var _variants: Dictionary = {}


## The same material in another colour (cached, so equal colours share one variant).
func get_color_variant(variant_color: Color) -> VoxelMaterialDefinition:
	var key := variant_color.to_rgba32()
	if not _variants.has(key):
		var variant: VoxelMaterialDefinition = duplicate()
		variant.color = Color(variant_color, 1.0)
		_variants[key] = variant
	return _variants[key]


func damage_multiplier(impact_type: PhysicsToolDefinition.ImpactType) -> float:
	match impact_type:
		PhysicsToolDefinition.ImpactType.SHARP:
			return sharp_multiplier
		PhysicsToolDefinition.ImpactType.PIERCE:
			return pierce_multiplier
	return blunt_multiplier


func get_physics_material() -> PhysicsMaterial:
	if _physics_material == null:
		_physics_material = PhysicsMaterial.new()
		_physics_material.friction = friction
		_physics_material.bounce = bounce
	return _physics_material
