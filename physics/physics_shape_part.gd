@tool
class_name PhysicsShapePart
extends Resource
## One primitive piece of a compound physics object: its collision shape and the
## matching mesh, placed in the object's local space.

enum ShapeType { BOX, SPHERE, CYLINDER, CAPSULE }

@export var shape_type: ShapeType = ShapeType.BOX:
	set(value):
		shape_type = value
		emit_changed()
		notify_property_list_changed()
@export var size: Vector3 = Vector3(0.1, 0.1, 0.1):
	set(value):
		size = value
		emit_changed()
@export_range(0.001, 5.0, 0.001, "or_greater", "suffix:m") var radius: float = 0.05:
	set(value):
		radius = value
		emit_changed()
@export_range(0.001, 10.0, 0.001, "or_greater", "suffix:m") var height: float = 0.2:
	set(value):
		height = value
		emit_changed()
@export var position: Vector3 = Vector3.ZERO:
	set(value):
		position = value
		emit_changed()
@export var rotation_degrees: Vector3 = Vector3.ZERO:
	set(value):
		rotation_degrees = value
		emit_changed()
## Leave empty to use the object's material.
@export var material: Material:
	set(value):
		material = value
		emit_changed()
## Visual-only parts add a mesh without a collision shape.
@export var collides: bool = true:
	set(value):
		collides = value
		emit_changed()


static func make(type: ShapeType, part_size: Vector3, part_radius: float, part_height: float,
		part_transform: Transform3D = Transform3D.IDENTITY, part_material: Material = null) -> PhysicsShapePart:
	var part := PhysicsShapePart.new()
	part.shape_type = type
	part.size = part_size
	part.radius = part_radius
	part.height = part_height
	part.position = part_transform.origin
	part.rotation_degrees = part_transform.basis.get_euler() * (180.0 / PI)
	part.material = part_material
	return part


func get_transform() -> Transform3D:
	return Transform3D(Basis.from_euler(rotation_degrees * (PI / 180.0)), position)


func build_shape() -> Shape3D:
	match shape_type:
		ShapeType.SPHERE:
			var sphere := SphereShape3D.new()
			sphere.radius = radius
			return sphere
		ShapeType.CYLINDER:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = radius
			cylinder.height = height
			return cylinder
		ShapeType.CAPSULE:
			var capsule := CapsuleShape3D.new()
			capsule.radius = radius
			capsule.height = maxf(height, radius * 2.0)
			return capsule
	var box := BoxShape3D.new()
	box.size = size
	return box


func build_mesh(fallback_material: Material) -> Mesh:
	var mesh: PrimitiveMesh
	match shape_type:
		ShapeType.SPHERE:
			var sphere := SphereMesh.new()
			sphere.radius = radius
			sphere.height = radius * 2.0
			mesh = sphere
		ShapeType.CYLINDER:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = radius
			cylinder.bottom_radius = radius
			cylinder.height = height
			mesh = cylinder
		ShapeType.CAPSULE:
			var capsule := CapsuleMesh.new()
			capsule.radius = radius
			capsule.height = maxf(height, radius * 2.0)
			mesh = capsule
		_:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
	mesh.material = material if material != null else fallback_material
	return mesh


func _validate_property(property: Dictionary) -> void:
	var used := {
		&"size": shape_type == ShapeType.BOX,
		&"radius": shape_type != ShapeType.BOX,
		&"height": shape_type == ShapeType.CYLINDER or shape_type == ShapeType.CAPSULE,
	}
	if used.has(property.name) and not used[property.name]:
		property.usage = PROPERTY_USAGE_NO_EDITOR
