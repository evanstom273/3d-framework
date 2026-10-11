@tool
class_name PhysicsObjectDefinition
extends Resource
@export var tool_profile: ToolMaterialProfile
@export_enum("none", "pulley", "plunger") var contraption_component: String = ""
## Optional prop-only scoop collision while equipped. All other tools remain noncolliding.
@export var equipped_collision_parts: PackedInt32Array = []
## Data for one kind of physics object. Save as a .tres and assign it to a
## PhysicsProp; the prop builds its collision, mesh and body settings from it.
## Edits update every prop using the definition, including in the editor.
## Optional sub-resources add behaviour: `container` makes it hold other objects,
## `tool` makes it equippable. Runtime state always lives on the prop, never here.

enum ShapeType { BOX, SPHERE, CYLINDER, CAPSULE, COMPOUND }

@export_group("Identity")
@export var display_name: String = "Object":
	set(value):
		display_name = value
		emit_changed()
@export var grabbable: bool = true:
	set(value):
		grabbable = value
		emit_changed()
## Spawn menu tab. Empty picks one automatically (Tools, Containers, Balls, Props).
@export var spawn_category: String = ""

@export_group("Shape")
## COMPOUND builds the object from `parts`. Containers generate their own walls.
@export var shape_type: ShapeType = ShapeType.BOX:
	set(value):
		shape_type = value
		_invalidate_geometry()
		notify_property_list_changed()
## Box dimensions in metres.
@export var size: Vector3 = Vector3(0.5, 0.5, 0.5):
	set(value):
		size = value
		_invalidate_geometry()
@export_range(0.01, 5.0, 0.005, "or_greater", "suffix:m") var radius: float = 0.25:
	set(value):
		radius = value
		_invalidate_geometry()
@export_range(0.01, 10.0, 0.005, "or_greater", "suffix:m") var height: float = 0.5:
	set(value):
		height = value
		_invalidate_geometry()
## Pieces of a COMPOUND object, e.g. a hammer's handle and head.
@export var parts: Array[PhysicsShapePart] = []:
	set(value):
		_watch_parts(false)
		parts = value
		_watch_parts(true)
		_invalidate_geometry()
## Replaces the generated collision shape, e.g. a convex hull for furniture.
@export var shape_override: Shape3D:
	set(value):
		shape_override = value
		_invalidate_geometry()

@export_group("Physics")
@export_range(0.01, 1000.0, 0.01, "or_greater", "suffix:kg") var mass: float = 1.0:
	set(value):
		mass = value
		emit_changed()
@export_range(0.0, 1.0, 0.01) var friction: float = 0.6:
	set(value):
		friction = value
		_invalidate_material()
@export_range(0.0, 1.0, 0.01) var bounce: float = 0.0:
	set(value):
		bounce = value
		_invalidate_material()
## Use this body's friction even when touching a slipperier surface.
@export var rough: bool = false:
	set(value):
		rough = value
		_invalidate_material()
## Subtract this body's bounce from the other surface's instead of adding it.
@export var absorbent: bool = false:
	set(value):
		absorbent = value
		_invalidate_material()
@export_range(0.0, 10.0, 0.01, "or_greater") var linear_damp: float = 0.05:
	set(value):
		linear_damp = value
		emit_changed()
@export_range(0.0, 10.0, 0.01, "or_greater") var angular_damp: float = 0.1:
	set(value):
		angular_damp = value
		emit_changed()
## What collisions with this object sound like.
@export var impact_sound: ImpactFeedback.Sound = ImpactFeedback.Sound.GENERIC
## How much damage this object does to voxel structures when it crashes into them
## (multiplies the impact). 0 never breaks anything; hard, heavy things go above 1.
@export_range(0.0, 5.0, 0.05) var impact_damage_scale: float = 1.0
## Swept collision for small or fast objects, so throws cannot tunnel through walls.
@export var continuous_cd: bool = true:
	set(value):
		continuous_cd = value
		emit_changed()

@export_group("Collision")
@export_flags_3d_physics var collision_layer: int = 16:
	set(value):
		collision_layer = value
		emit_changed()
@export_flags_3d_physics var collision_mask: int = 31:
	set(value):
		collision_mask = value
		emit_changed()

@export_group("Visuals")
## Applied to the generated mesh. Edit it inline to restyle every prop using this definition.
@export var material: Material:
	set(value):
		material = value
		_invalidate_geometry()
## Replaces the generated mesh, e.g. an imported model.
@export var mesh_override: Mesh:
	set(value):
		mesh_override = value
		_invalidate_geometry()
## Optional extra visuals (trim, labels, decals) added on top of the mesh. These are
## authored at a fixed size, so they do not follow changes to the shape.
@export var detail_scene: PackedScene:
	set(value):
		detail_scene = value
		emit_changed()
## Draw the object from a MagicaVoxel model instead of its shape meshes and details.
## Collision still comes from the shape, so the object behaves exactly the same.
@export_file("*.vox") var vox_model: String = "":
	set(value):
		vox_model = value
		_invalidate_geometry()
## Size of one model voxel in metres.
@export_range(0.002, 1.0, 0.001, "suffix:m") var vox_voxel_size: float = 0.025:
	set(value):
		vox_voxel_size = value
		_invalidate_geometry()
## Where the model's first voxel corner sits in the object's local space.
@export var vox_origin: Vector3 = Vector3.ZERO:
	set(value):
		vox_origin = value
		_invalidate_geometry()

@export_group("Behaviour")
## Set to make this object a container whose walls hold other physics objects.
@export var container: PhysicsContainerDefinition:
	set(value):
		if container != null and container.changed.is_connected(_invalidate_geometry):
			container.changed.disconnect(_invalidate_geometry)
		container = value
		if container != null:
			container.changed.connect(_invalidate_geometry)
		_invalidate_geometry()
## Set to make this object equippable as a tool.
@export var tool: PhysicsToolDefinition:
	set(value):
		tool = value
		emit_changed()

var _collision_parts: Array[Dictionary] = []
var _visual_parts: Array[Dictionary] = []
var _geometry_built: bool = false
var _physics_material: PhysicsMaterial


func is_container() -> bool:
	return container != null


func is_equippable() -> bool:
	return tool != null


## Collision pieces as [{shape, transform}], shared by every prop using this definition.
func get_collision_parts() -> Array[Dictionary]:
	_ensure_geometry()
	return _collision_parts


## Visual pieces as [{mesh, transform}].
func get_visual_parts() -> Array[Dictionary]:
	_ensure_geometry()
	return _visual_parts


func get_physics_material() -> PhysicsMaterial:
	if _physics_material == null:
		_physics_material = PhysicsMaterial.new()
		_physics_material.friction = friction
		_physics_material.bounce = bounce
		_physics_material.rough = rough
		_physics_material.absorbent = absorbent
	return _physics_material


func _ensure_geometry() -> void:
	if _geometry_built:
		return
	_geometry_built = true
	_collision_parts = []
	_visual_parts = []
	var source: Array[PhysicsShapePart] = []
	var draw_parts := true
	if container != null and container.form != PhysicsContainerDefinition.Form.CUSTOM:
		source = container.build_parts(material)
		draw_parts = container.draws_parts()
		_visual_parts.append_array(container.build_visuals(material))
	elif shape_type == ShapeType.COMPOUND:
		for part in parts:
			if part != null:
				source.append(part)
	else:
		source.append(PhysicsShapePart.make(shape_type as PhysicsShapePart.ShapeType, size, radius, height))
	for part in source:
		var part_transform := part.get_transform()
		if part.collides and shape_override == null:
			_collision_parts.append({"shape": part.build_shape(), "transform": part_transform})
		if draw_parts and mesh_override == null:
			_visual_parts.append({"mesh": part.build_mesh(material), "transform": part_transform})
	if shape_override != null:
		_collision_parts.append({"shape": shape_override, "transform": Transform3D.IDENTITY})
	if mesh_override != null:
		_visual_parts.append({"mesh": mesh_override, "transform": Transform3D.IDENTITY})
	if uses_vox_model():
		var vox_mesh := VoxFile.build_mesh(vox_model, vox_voxel_size, vox_origin, _get_vox_material())
		if vox_mesh != null:
			_visual_parts = [{"mesh": vox_mesh, "transform": Transform3D.IDENTITY}]


func uses_vox_model() -> bool:
	return not vox_model.is_empty()


## The object's material with vertex colours as albedo, so a model keeps its
## colours while metal stays metallic and plastic stays shiny.
func _get_vox_material() -> Material:
	var base := material as StandardMaterial3D
	if base == null:
		return null
	var vox_material: StandardMaterial3D = base.duplicate()
	vox_material.vertex_color_use_as_albedo = true
	vox_material.albedo_color = Color.WHITE
	vox_material.albedo_texture = null
	# Every voxel face points outward, so back faces can be culled (some source
	# materials, like the bucket's, were double-sided for their thin meshes).
	vox_material.cull_mode = BaseMaterial3D.CULL_BACK
	return vox_material


func _watch_parts(enabled: bool) -> void:
	for part in parts:
		if part == null:
			continue
		if enabled and not part.changed.is_connected(_invalidate_geometry):
			part.changed.connect(_invalidate_geometry)
		elif not enabled and part.changed.is_connected(_invalidate_geometry):
			part.changed.disconnect(_invalidate_geometry)


func _invalidate_geometry() -> void:
	_geometry_built = false
	emit_changed()


func _invalidate_material() -> void:
	_physics_material = null
	emit_changed()


## Only show the dimensions the chosen shape uses.
func _validate_property(property: Dictionary) -> void:
	var used := {
		&"size": shape_type == ShapeType.BOX,
		&"radius": shape_type == ShapeType.SPHERE or shape_type == ShapeType.CYLINDER or shape_type == ShapeType.CAPSULE,
		&"height": shape_type == ShapeType.CYLINDER or shape_type == ShapeType.CAPSULE,
		&"parts": shape_type == ShapeType.COMPOUND,
	}
	if used.has(property.name) and not used[property.name]:
		property.usage = PROPERTY_USAGE_NO_EDITOR
