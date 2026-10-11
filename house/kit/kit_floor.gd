@tool
class_name KitFloor
extends KitPiece
## A floor and the ceiling under it. Size runs along +X and +Z from the origin; the
## finished top is at the origin and the ceiling below it at -thickness. Span it
## between wall grid lines: its edges tuck into the walls.
## Stairwells and hatches are rectangles cut through it, lined and nosed.

enum Structure { TIMBER_JOISTS, CONCRETE_SLAB }

@export var size: Vector2 = Vector2(4.0, 4.0):
	set(value):
		size = Vector2(snap(value.x, 0.3), snap(value.y, 0.3))
		queue_rebuild()
@export_range(0.1, 0.6, 0.01, "suffix:m") var thickness: float = 0.25:
	set(value):
		thickness = value
		queue_rebuild()
@export var finish: KitMaterials.FloorFinish = KitMaterials.FloorFinish.FLOORBOARDS:
	set(value):
		finish = value
		queue_rebuild()
## Board, tile or carpet colour.
@export var finish_color: Color = Color(0.6, 0.42, 0.26):
	set(value):
		finish_color = value
		queue_rebuild()
@export var boards_along_z: bool = false:
	set(value):
		boards_along_z = value
		queue_rebuild()
@export var structure: Structure = Structure.TIMBER_JOISTS:
	set(value):
		structure = value
		queue_rebuild()
## Plastered ceiling underneath (off for ground slabs and exposed joists).
@export var ceiling: bool = true:
	set(value):
		ceiling = value
		queue_rebuild()
@export var ceiling_color: Color = Color(0.97, 0.97, 0.95):
	set(value):
		ceiling_color = value
		queue_rebuild()
## Holes through the floor (x, z, width, depth), e.g. a stairwell.
@export var openings: Array[Rect2] = []:
	set(value):
		openings = value
		queue_rebuild()
@export var trim_color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		trim_color = value
		queue_rebuild()


func _build(b: KitBuilder) -> void:
	var holes: Array[Rect2] = []
	for hole in openings:
		holes.append(hole.intersection(Rect2(Vector2.ZERO, size)))
	var finish_depth := 0.0 if finish == KitMaterials.FloorFinish.NONE else 0.022
	var ceiling_depth := 0.015 if ceiling else 0.0
	var top_material := KitMaterials.floor_finish(finish, finish_color, boards_along_z)
	var core := KitMaterials.timber(Color(0.66, 0.5, 0.33)) if structure == Structure.TIMBER_JOISTS else KitMaterials.concrete()
	var under := KitMaterials.paint(ceiling_color)
	# Without a ceiling, joisted floors are a thin deck with the joists showing below.
	var exposed := structure == Structure.TIMBER_JOISTS and not ceiling
	var core_bottom := -finish_depth - 0.03 if exposed else -thickness + ceiling_depth
	for rect in KitWall._subtract(Rect2(Vector2.ZERO, size), holes):
		var x0 := rect.position.x
		var x1 := rect.end.x
		var z0 := rect.position.y
		var z1 := rect.end.y
		if finish_depth > 0.0:
			b.box(Vector3(x0, -finish_depth, z0), Vector3(x1, 0.0, z1), top_material)
		b.box(Vector3(x0, core_bottom, z0), Vector3(x1, -finish_depth, z1), core, true, KitBuilder.FACE_ALL if not ceiling else KitBuilder.FACE_ALL & ~KitBuilder.FACE_NEG_Y)
		if ceiling:
			b.box(Vector3(x0, -thickness, z0), Vector3(x1, -thickness + ceiling_depth, z1), under)
	if exposed:
		_joists(b, holes, core_bottom)
	var trim := KitMaterials.gloss(trim_color)
	var nosing := KitMaterials.timber(Color(0.5, 0.34, 0.2))
	for hole in holes:
		if not hole.has_area():
			continue
		# Lining boards round the hole's edges, and a rounded nosing at the top.
		var lining := 0.018
		var x0 := hole.position.x
		var x1 := hole.end.x
		var z0 := hole.position.y
		var z1 := hole.end.y
		b.box(Vector3(x0, -thickness, z0), Vector3(x0 + lining, 0.0, z1), trim)
		b.box(Vector3(x1 - lining, -thickness, z0), Vector3(x1, 0.0, z1), trim)
		b.box(Vector3(x0, -thickness, z0), Vector3(x1, 0.0, z0 + lining), trim)
		b.box(Vector3(x0, -thickness, z1 - lining), Vector3(x1, 0.0, z1), trim)
		var round_nose := PackedVector2Array([Vector2(-0.03, -0.028), Vector2(0.0, -0.028)])
		round_nose.append_array(arc(Vector2(0.0, -0.014), 0.014, -PI * 0.5, PI * 0.5, 6).slice(1))
		round_nose.append(Vector2(-0.03, 0.0))
		var top := 0.006
		for edge in [[Vector3(x0, top, z0), Vector3(x0, top, z1)], [Vector3(x1, top, z1), Vector3(x1, top, z0)],
				[Vector3(x1, top, z0), Vector3(x0, top, z0)], [Vector3(x0, top, z1), Vector3(x1, top, z1)]]:
			# Extruding along the edge puts "across" into the hole for these directions.
			b.extrude(round_nose, edge[0], edge[1], Vector3.UP, nosing, false)


## Exposed joists under a floor without a ceiling (lofts, cellars).
func _joists(b: KitBuilder, holes: Array[Rect2], deck_bottom: float) -> void:
	var timber := KitMaterials.timber(Color(0.68, 0.52, 0.34))
	var spacing := 0.4
	var along_x := size.x >= size.y
	var span := size.y if along_x else size.x
	var run := size.x if along_x else size.y
	var count := floori(span / spacing)
	for i in range(count + 1):
		var at := minf(i * spacing + 0.025, span - 0.025)
		var low := Vector3(0, -thickness, at - 0.025) if along_x else Vector3(at - 0.025, -thickness, 0)
		var high := Vector3(run, deck_bottom, at + 0.025) if along_x else Vector3(at + 0.025, deck_bottom, run)
		var blocked := false
		for hole in holes:
			if hole.has_area() and Rect2(Vector2(low.x, low.z), Vector2(high.x - low.x, high.z - low.z)).intersects(hole):
				blocked = true
		if not blocked:
			b.box(low, high, timber)
