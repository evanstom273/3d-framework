@tool
class_name KitBalustrade
extends KitPiece
## A level balustrade: landings, stairwell edges, galleries. Runs along +X from
## the origin on the floor; newels at either end are optional so runs can meet at
## a shared corner newel (turn one off) or die into a wall.

@export_range(0.2, 20.0, 0.05, "suffix:m") var length: float = 2.0:
	set(value):
		length = snap(value, 0.2)
		queue_rebuild()
@export_range(0.6, 1.4, 0.05, "suffix:m") var height: float = 0.9:
	set(value):
		height = value
		queue_rebuild()
@export var start_newel: bool = true:
	set(value):
		start_newel = value
		queue_rebuild()
@export var end_newel: bool = true:
	set(value):
		end_newel = value
		queue_rebuild()
@export var paint_color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		paint_color = value
		queue_rebuild()
@export var rail_color: Color = Color(0.55, 0.37, 0.22):
	set(value):
		rail_color = value
		queue_rebuild()


func _build(b: KitBuilder) -> void:
	var paint := KitMaterials.gloss(paint_color)
	var oak := KitMaterials.timber(rail_color)
	var x0 := 0.045 if start_newel else 0.0
	var x1 := length - (0.045 if end_newel else 0.0)
	if start_newel:
		KitStairs.newel(b, Vector3(0, 0, 0), height + 0.15, paint, oak)
	if end_newel:
		KitStairs.newel(b, Vector3(length, 0, 0), height + 0.15, paint, oak)
	# Base rail on the floor, handrail on top, balusters between.
	b.box(Vector3(x0, 0.0, -0.03), Vector3(x1, 0.06, 0.03), paint, false)
	b.extrude(KitStairs.handrail_profile(), Vector3(x0, height, 0), Vector3(x1, height, 0), Vector3.UP, oak, false)
	var count := maxi(1, floori((x1 - x0) / 0.11))
	var step := (x1 - x0) / count
	for i in count:
		var x := x0 + step * (i + 0.5)
		b.bevel_box(Vector3(x - 0.016, 0.06, -0.016), Vector3(x + 0.016, height - 0.03, 0.016), 0.005, paint, false)
	b.collision_quad(Vector3(0, 0, 0), Vector3(length, 0, 0), Vector3(length, height, 0), Vector3(0, height, 0))
