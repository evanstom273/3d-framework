@tool
class_name PhysicsContainerDefinition
extends Resource
@export var stabilise_when_equipped: bool = false
## Makes a physics object a container. Contents are ordinary rigid bodies held in
## by real walls; this resource generates those walls (or, for CUSTOM, uses the
## object's own shapes) and describes the inner volume used to track contents.
## Future vessels: wheelbarrows and trolleys can use CUSTOM with their own parts;
## trays are an OPEN_BOX with low walls; drawers and toolboxes nest one inside a body.

enum Form {
	## Rectangular box without a lid.
	OPEN_BOX,
	## Round, optionally tapered vessel such as a bucket.
	ROUND,
	## Walls come from the object's own shape parts; only the inner volume is defined here.
	CUSTOM,
}

@export var form: Form = Form.OPEN_BOX:
	set(value):
		form = value
		emit_changed()
		notify_property_list_changed()

@export_group("Box")
@export var outer_size: Vector3 = Vector3(0.6, 0.35, 0.6):
	set(value):
		outer_size = value
		emit_changed()

@export_group("Round")
@export_range(0.02, 2.0, 0.005, "or_greater", "suffix:m") var top_radius: float = 0.16:
	set(value):
		top_radius = value
		emit_changed()
@export_range(0.02, 2.0, 0.005, "or_greater", "suffix:m") var bottom_radius: float = 0.13:
	set(value):
		bottom_radius = value
		emit_changed()
@export_range(0.02, 2.0, 0.005, "or_greater", "suffix:m") var height: float = 0.32:
	set(value):
		height = value
		emit_changed()
## Collision segments around the wall; more is rounder but costs more.
@export_range(6, 32, 1) var wall_segments: int = 14:
	set(value):
		wall_segments = value
		emit_changed()

@export_group("Custom")
@export var inner_size: Vector3 = Vector3(0.5, 0.3, 0.5):
	set(value):
		inner_size = value
		emit_changed()
@export var inner_center: Vector3 = Vector3.ZERO:
	set(value):
		inner_center = value
		emit_changed()

@export_group("Walls")
## Thicker walls resist tunnelling better; keep at least ~0.03 m.
@export_range(0.01, 0.2, 0.005, "suffix:m") var wall_thickness: float = 0.03:
	set(value):
		wall_thickness = value
		emit_changed()
@export_range(0.01, 0.2, 0.005, "suffix:m") var floor_thickness: float = 0.03:
	set(value):
		floor_thickness = value
		emit_changed()

@export_group("Contents")
## Objects piled this far above the rim still count as contents.
@export_range(0.0, 1.0, 0.01, "suffix:m") var heap_height: float = 0.15
## While carried upright, contents are pulled toward the container's motion at this
## rate (1/s) so ordinary walking does not shake them out. Zero disables it.
@export_range(0.0, 30.0, 0.5) var carry_stabilisation: float = 12.0
## Beyond this tilt the stabilisation fades out, so tipping spills contents.
@export_range(0.0, 90.0, 1.0, "suffix:°") var stabilise_max_tilt: float = 35.0
## Add contents' mass to the container's carried weight.
@export var contents_add_weight: bool = true


## Wall and floor pieces in the container's local space (empty for CUSTOM).
func build_parts(material: Material) -> Array[PhysicsShapePart]:
	var parts: Array[PhysicsShapePart] = []
	var box := PhysicsShapePart.ShapeType.BOX
	match form:
		Form.OPEN_BOX:
			var o := outer_size
			var t := wall_thickness
			parts.append(PhysicsShapePart.make(box, Vector3(o.x, floor_thickness, o.z), 0, 0,
				Transform3D(Basis(), Vector3(0, (floor_thickness - o.y) * 0.5, 0)), material))
			for side in [-1.0, 1.0]:
				parts.append(PhysicsShapePart.make(box, Vector3(o.x, o.y, t), 0, 0,
					Transform3D(Basis(), Vector3(0, 0, side * (o.z - t) * 0.5)), material))
				parts.append(PhysicsShapePart.make(box, Vector3(t, o.y, o.z - t * 2.0), 0, 0,
					Transform3D(Basis(), Vector3(side * (o.x - t) * 0.5, 0, 0)), material))
		Form.ROUND:
			parts.append(PhysicsShapePart.make(PhysicsShapePart.ShapeType.CYLINDER, Vector3.ZERO,
				bottom_radius, floor_thickness, Transform3D(Basis(), Vector3(0, (floor_thickness - height) * 0.5, 0)), material))
			# Straight boxes around the rim, tilted outward to follow the taper.
			var tilt := atan2(top_radius - bottom_radius, height)
			var mid_radius := (top_radius + bottom_radius) * 0.5 - wall_thickness * 0.5
			var width := 2.0 * (mid_radius + wall_thickness) * tan(PI / wall_segments) * 1.08
			for index in wall_segments:
				var angle := TAU * index / wall_segments
				var basis := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, tilt)
				var origin := Vector3(sin(angle), 0, cos(angle)) * mid_radius
				parts.append(PhysicsShapePart.make(box, Vector3(width, height / cos(tilt), wall_thickness), 0, 0,
					Transform3D(basis, origin), material))
	return parts


## Whether parts from build_parts() should be drawn. Round walls use one smooth mesh instead.
func draws_parts() -> bool:
	return form == Form.OPEN_BOX


## Extra visual meshes as [{mesh, transform}], used where generated parts are hidden.
func build_visuals(material: Material) -> Array[Dictionary]:
	var visuals: Array[Dictionary] = []
	if form == Form.ROUND:
		var vessel := CylinderMesh.new()
		vessel.top_radius = top_radius
		vessel.bottom_radius = bottom_radius
		vessel.height = height
		vessel.cap_top = false
		vessel.radial_segments = 32
		vessel.material = material
		visuals.append({"mesh": vessel, "transform": Transform3D.IDENTITY})
	return visuals


## The space contents occupy, in the container's local space.
func get_inner_bounds() -> AABB:
	match form:
		Form.OPEN_BOX:
			var size := Vector3(outer_size.x - wall_thickness * 2.0, outer_size.y - floor_thickness, outer_size.z - wall_thickness * 2.0)
			return AABB(Vector3(-size.x * 0.5, floor_thickness - outer_size.y * 0.5, -size.z * 0.5), size)
		Form.ROUND:
			var r := maxf(top_radius, bottom_radius) - wall_thickness
			var h := height - floor_thickness
			return AABB(Vector3(-r, floor_thickness - height * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	return AABB(inner_center - inner_size * 0.5, inner_size)


## Box covering the inner volume plus the heap allowance, for overlap detection.
func build_volume_shape() -> Dictionary:
	var bounds := get_inner_bounds()
	bounds.size.y += heap_height
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	return {"shape": shape, "transform": Transform3D(Basis(), bounds.get_center())}


func contains_local_point(point: Vector3) -> bool:
	var bounds := get_inner_bounds()
	bounds.size.y += heap_height
	if not bounds.has_point(point):
		return false
	if form == Form.ROUND:
		var t := clampf((point.y - bounds.position.y) / maxf(height, 0.001), 0.0, 1.0)
		var r := lerpf(bottom_radius, top_radius, t) - wall_thickness
		return Vector2(point.x, point.z).length() <= r
	return true


func _validate_property(property: Dictionary) -> void:
	var groups := {
		&"outer_size": Form.OPEN_BOX,
		&"top_radius": Form.ROUND, &"bottom_radius": Form.ROUND, &"height": Form.ROUND, &"wall_segments": Form.ROUND,
		&"inner_size": Form.CUSTOM, &"inner_center": Form.CUSTOM,
	}
	if groups.has(property.name) and groups[property.name] != form:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if form == Form.CUSTOM and (property.name == &"wall_thickness" or property.name == &"floor_thickness"):
		property.usage = PROPERTY_USAGE_NO_EDITOR
