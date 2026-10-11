@tool
class_name KitChimney
extends KitPiece
## A chimney stack from the origin (centre of its footprint, at its base) up to
## `height`, with oversailing brick courses, a cap and pots. Below
## `breast_height` it is a plastered chimney breast facing +Z, with an optional
## fireplace, hearth and mantelpiece, for stacks built inside a room.

enum Fireplace { NONE, CAST_IRON, OPEN_BRICK }

@export var size: Vector2 = Vector2(0.9, 0.6):
	set(value):
		size = Vector2(snap(value.x, 0.3), snap(value.y, 0.3))
		queue_rebuild()
@export_range(0.5, 20.0, 0.05, "suffix:m") var height: float = 9.0:
	set(value):
		height = value
		queue_rebuild()
## Oversailing courses, cap and pots at the top. Turn off for a breast that
## stops at a ceiling (stack it with another piece above).
@export var stack_top: bool = true:
	set(value):
		stack_top = value
		queue_rebuild()
@export_range(0, 4) var pots: int = 2:
	set(value):
		pots = value
		queue_rebuild()
@export var brick: KitMaterials.Brick = KitMaterials.Brick.RED:
	set(value):
		brick = value
		queue_rebuild()
@export var facade: KitMaterials.Facade = KitMaterials.Facade.BRICK:
	set(value):
		facade = value
		queue_rebuild()
@export var facade_color: Color = Color(0.93, 0.91, 0.85):
	set(value):
		facade_color = value
		queue_rebuild()

@export_group("Inside")
## Height of the plastered breast (0 for an all-brick stack outside the house).
@export_range(0.0, 10.0, 0.05, "suffix:m") var breast_height: float = 0.0:
	set(value):
		breast_height = value
		queue_rebuild()
@export var fireplace: Fireplace = Fireplace.NONE:
	set(value):
		fireplace = value
		queue_rebuild()
@export var inside_color: Color = Color(0.93, 0.91, 0.86):
	set(value):
		inside_color = value
		queue_rebuild()
@export var mantel_color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		mantel_color = value
		queue_rebuild()


func _build(b: KitBuilder) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var face := KitMaterials.facade(facade, brick, facade_color)
	var top := height - 0.4 if stack_top else height
	var breast := minf(breast_height, top)
	if breast > 0.0:
		_breast(b, hx, hz, breast)
	b.box(Vector3(-hx, breast, -hz), Vector3(hx, top, hz), face)
	if not stack_top:
		return
	# Two oversailing courses, a plain course, then the cap.
	var y := top
	for spread in [0.03, 0.06, 0.0]:
		b.box(Vector3(-hx - spread, y, -hz - spread), Vector3(hx + spread, y + 0.075, hz + spread), face)
		y += 0.075
	var cap := KitMaterials.concrete()
	b.box(Vector3(-hx - 0.05, y, -hz - 0.05), Vector3(hx + 0.05, y + 0.05, hz + 0.05), cap)
	y += 0.05
	# Mortar flaunching sloping up round the pots.
	b.slab(PackedVector2Array([Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]), Vector3(0, y + 0.03, 0), Vector3.RIGHT, Vector3.FORWARD, 0.03, cap, cap, false)
	y += 0.03
	var terracotta := KitMaterials.terracotta()
	var soot := KitMaterials.paint(Color(0.05, 0.05, 0.05))
	for i in pots:
		var x := 0.0 if pots == 1 else lerpf(-hx + 0.2, hx - 0.2, float(i) / (pots - 1))
		var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.13, 0.04), Vector2(0.105, 0.09), Vector2(0.09, 0.42), Vector2(0.1, 0.46), Vector2(0.115, 0.5), Vector2(0.1, 0.52), Vector2(0.0, 0.52)])
		b.lathe(profile, Vector3(x, y, 0), 16, terracotta)
		b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.0, 0.001)]), Vector3(x, y + 0.5215, 0), 12, soot)


func _breast(b: KitBuilder, hx: float, hz: float, breast: float) -> void:
	var plaster := KitMaterials.paint(inside_color)
	if fireplace == Fireplace.NONE:
		b.box(Vector3(-hx, 0.0, -hz), Vector3(hx, breast, hz), plaster)
		return
	var fw := minf(0.8, size.x - 0.3) * 0.5
	var fh := minf(0.85, breast - 0.3)
	var depth := minf(0.35, size.y - 0.15)
	var back := hz - depth
	# Piers either side, a lintel over the opening and the stack behind the firebox.
	b.box(Vector3(-hx, 0.0, -hz), Vector3(-fw, breast, hz), plaster)
	b.box(Vector3(fw, 0.0, -hz), Vector3(hx, breast, hz), plaster)
	b.box(Vector3(-fw, fh, -hz), Vector3(fw, breast, hz), plaster)
	b.box(Vector3(-fw, 0.0, -hz), Vector3(fw, fh, back), plaster)
	var soot := KitMaterials.paint(Color(0.08, 0.07, 0.07))
	var black := KitMaterials.metal(Color(0.06, 0.06, 0.06), 0.6)
	var inset := 0.004
	b.box(Vector3(-fw + inset, 0.0, back), Vector3(fw - inset, fh - inset, back + 0.01), soot, false)
	b.box(Vector3(-fw, 0.0, back), Vector3(-fw + inset, fh, hz), soot, false)
	b.box(Vector3(fw - inset, 0.0, back), Vector3(fw, fh, hz), soot, false)
	b.box(Vector3(-fw, fh - inset, back), Vector3(fw, fh, hz), soot, false)
	if fireplace == Fireplace.CAST_IRON:
		# Cast iron surround with an arched-look head and a basket grate.
		var proud := 0.012
		b.box(Vector3(-fw - 0.07, 0.0, hz), Vector3(-fw, fh + 0.07, hz + proud), black)
		b.box(Vector3(fw, 0.0, hz), Vector3(fw + 0.07, fh + 0.07, hz + proud), black)
		b.box(Vector3(-fw, fh, hz), Vector3(fw, fh + 0.07, hz + proud), black)
		for i in 6:
			var x := lerpf(-fw + 0.08, fw - 0.08, i / 5.0)
			b.box(Vector3(x - 0.008, 0.08, back + 0.06), Vector3(x + 0.008, 0.26, back + 0.08), black, false)
		b.box(Vector3(-fw + 0.06, 0.06, back + 0.04), Vector3(fw - 0.06, 0.08, hz - 0.05), black, false)
	else:
		var brickwork := KitMaterials.brick(brick)
		b.box(Vector3(-fw + inset, 0.0, back + 0.011), Vector3(fw - inset, fh - inset, back + 0.012), brickwork, false)
	# Hearth slab, and a painted mantelpiece with pilasters.
	var hearth := KitMaterials.tiles(Color(0.55, 0.25, 0.18), Vector2(0.1, 0.1)) if fireplace == Fireplace.CAST_IRON else KitMaterials.stone()
	b.box(Vector3(-hx - 0.05, 0.0, back), Vector3(hx + 0.05, 0.03, hz + 0.45), hearth)
	var mantel := KitMaterials.gloss(mantel_color)
	var shelf_y := minf(fh + 0.32, breast - 0.06)
	b.box(Vector3(-hx - 0.08, shelf_y, hz), Vector3(hx + 0.08, shelf_y + 0.05, hz + 0.17), mantel)
	b.box(Vector3(-fw - 0.22, 0.03, hz), Vector3(-fw - 0.07, shelf_y, hz + 0.05), mantel)
	b.box(Vector3(fw + 0.07, 0.03, hz), Vector3(fw + 0.22, shelf_y, hz + 0.05), mantel)
	b.box(Vector3(-fw - 0.07, fh + 0.07, hz), Vector3(fw + 0.07, shelf_y, hz + 0.035), mantel)
