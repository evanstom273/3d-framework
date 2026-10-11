@tool
class_name KitSlab
extends KitPiece
## A level slab: foundations, terraces, paths, patios and decks. Size runs along
## +X and +Z from the origin; the top is at the origin.

enum Surface { CONCRETE, PAVING_FLAGS, BRICK_PAVIORS, GRAVEL, TIMBER_DECK, QUARRY_TILES }

@export var size: Vector2 = Vector2(3.0, 2.0):
	set(value):
		size = Vector2(snap(value.x, 0.1), snap(value.y, 0.1))
		queue_rebuild()
@export_range(0.02, 2.0, 0.01, "suffix:m") var thickness: float = 0.15:
	set(value):
		thickness = value
		queue_rebuild()
@export var surface: Surface = Surface.PAVING_FLAGS:
	set(value):
		surface = value
		queue_rebuild()
## A raised edging kerb round the slab.
@export var edging: bool = false:
	set(value):
		edging = value
		queue_rebuild()
@export var brick: KitMaterials.Brick = KitMaterials.Brick.RED:
	set(value):
		brick = value
		queue_rebuild()


func _build(b: KitBuilder) -> void:
	var top: Material
	var body: Material = KitMaterials.concrete()
	match surface:
		Surface.PAVING_FLAGS:
			top = KitMaterials.stone(Color(0.72, 0.7, 0.65), 0.6)
		Surface.BRICK_PAVIORS:
			top = KitMaterials.brick(brick)
		Surface.GRAVEL:
			top = KitMaterials.stone(Color(0.62, 0.6, 0.55))
		Surface.TIMBER_DECK:
			top = KitMaterials.floorboards(Color(0.5, 0.38, 0.26))
			body = KitMaterials.timber(Color(0.42, 0.32, 0.22))
		Surface.QUARRY_TILES:
			top = KitMaterials.tiles(Color(0.62, 0.22, 0.16), Vector2(0.15, 0.15))
		_:
			top = body
	var skin := minf(0.03, thickness * 0.5)
	b.box(Vector3(0, -thickness, 0), Vector3(size.x, -skin, size.y), body)
	b.box(Vector3(0, -skin, 0), Vector3(size.x, 0.0, size.y), top)
	if edging:
		var kerb := KitMaterials.stone(Color(0.68, 0.67, 0.64))
		var w := 0.06
		b.box(Vector3(-w, -thickness, -w), Vector3(size.x + w, 0.03, 0.0), kerb)
		b.box(Vector3(-w, -thickness, size.y), Vector3(size.x + w, 0.03, size.y + w), kerb)
		b.box(Vector3(-w, -thickness, 0.0), Vector3(0.0, 0.03, size.y), kerb)
		b.box(Vector3(size.x, -thickness, 0.0), Vector3(size.x + w, 0.03, size.y), kerb)
