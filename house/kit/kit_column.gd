@tool
class_name KitColumn
extends KitPiece
## A free-standing post, column or pier from the origin up to `height`: for
## verandas, carports, pergolas and open-plan rooms.

@export var style: KitPorch.Supports = KitPorch.Supports.COLUMNS:
	set(value):
		style = value
		queue_rebuild()
@export_range(0.5, 10.0, 0.05, "suffix:m") var height: float = 2.4:
	set(value):
		height = value
		queue_rebuild()
@export var color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		color = value
		queue_rebuild()
@export var brick: KitMaterials.Brick = KitMaterials.Brick.RED:
	set(value):
		brick = value
		queue_rebuild()


func _build(b: KitBuilder) -> void:
	KitPorch.support(b, style, Vector3.ZERO, height, KitMaterials.gloss(color), brick)
	# Turned columns have no collision of their own: a simple square collider.
	var r := 0.1
	b.collision_quad(Vector3(-r, 0, -r), Vector3(r, 0, -r), Vector3(r, height, -r), Vector3(-r, height, -r))
	b.collision_quad(Vector3(r, 0, -r), Vector3(r, 0, r), Vector3(r, height, r), Vector3(r, height, -r))
	b.collision_quad(Vector3(r, 0, r), Vector3(-r, 0, r), Vector3(-r, height, r), Vector3(r, height, r))
	b.collision_quad(Vector3(-r, 0, r), Vector3(-r, 0, -r), Vector3(-r, height, -r), Vector3(-r, height, r))
