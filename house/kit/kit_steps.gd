@tool
class_name KitSteps
extends KitPiece
## External steps up to a door. The origin is the middle of the top edge, at the
## top (door threshold) level; the steps run down toward -Z to the ground.
## Optional brick cheek walls and an iron handrail.

enum Finish { STONE, CONCRETE, BRICK_WITH_STONE_TREADS }

@export_range(0.5, 6.0, 0.05, "suffix:m") var width: float = 1.2:
	set(value):
		width = snap(value, 0.5)
		queue_rebuild()
## Height from the ground to the top.
@export_range(0.1, 3.0, 0.05, "suffix:m") var total_rise: float = 0.3:
	set(value):
		total_rise = snap(value, 0.1)
		queue_rebuild()
@export_range(0.25, 0.45, 0.01, "suffix:m") var going: float = 0.32:
	set(value):
		going = value
		queue_rebuild()
## Depth of the level platform at the top (0 for none).
@export_range(0.0, 2.0, 0.05, "suffix:m") var landing: float = 0.0:
	set(value):
		landing = value
		queue_rebuild()
@export var finish: Finish = Finish.STONE:
	set(value):
		finish = value
		queue_rebuild()
@export var cheek_walls: bool = false:
	set(value):
		cheek_walls = value
		queue_rebuild()
@export var handrail: bool = false:
	set(value):
		handrail = value
		queue_rebuild()
@export var brick: KitMaterials.Brick = KitMaterials.Brick.RED:
	set(value):
		brick = value
		queue_rebuild()


func _build(b: KitBuilder) -> void:
	var count := maxi(1, ceili(total_rise / 0.17))
	var riser := total_rise / count
	var hw := width * 0.5
	var stone := KitMaterials.stone(Color(0.78, 0.75, 0.68))
	var body: Material = stone
	match finish:
		Finish.CONCRETE:
			body = KitMaterials.concrete()
			stone = body
		Finish.BRICK_WITH_STONE_TREADS:
			body = KitMaterials.brick(brick)
	var back := 0.0
	var ground := -total_rise
	# Step k's top is k risers below the top; the landing is step 0.
	for k in count:
		var top := -k * riser
		var depth := landing if k == 0 else going
		if depth <= 0.0:
			continue
		var front := back - depth
		b.box(Vector3(-hw, ground, front), Vector3(hw, top - 0.04, back), body)
		# Tread slab with a small overhanging nose.
		b.box(Vector3(-hw - 0.01, top - 0.04, front - 0.02), Vector3(hw + 0.01, top, back), stone)
		back = front
	if cheek_walls:
		var brickwork := KitMaterials.brick(brick)
		var coping := KitMaterials.stone(Color(0.75, 0.72, 0.66))
		var run := -back
		for side: float in [-1.0, 1.0]:
			var x0 := side * hw if side > 0.0 else -hw - 0.225
			var x1 := x0 + 0.225
			# A sloped-top cheek wall following the steps, polygon in (z, y).
			var poly := PackedVector2Array([Vector2(0.0, ground), Vector2(-run - 0.05, ground), Vector2(-run - 0.05, ground + 0.3), Vector2(-landing, 0.25), Vector2(0.0, 0.25)])
			b.slab(poly, Vector3(x0, 0, 0), Vector3.BACK, Vector3.UP, 0.225, brickwork, brickwork)
			b.extrude(PackedVector2Array([Vector2(-0.14, 0.0), Vector2(0.14, 0.0), Vector2(0.14, 0.04), Vector2(-0.14, 0.04)]), Vector3((x0 + x1) * 0.5, 0.25, 0.0), Vector3((x0 + x1) * 0.5, 0.25, -landing), Vector3.UP, coping, false)
			b.extrude(PackedVector2Array([Vector2(-0.14, 0.0), Vector2(0.14, 0.0), Vector2(0.14, 0.04), Vector2(-0.14, 0.04)]), Vector3((x0 + x1) * 0.5, 0.25, -landing), Vector3((x0 + x1) * 0.5, ground + 0.3, -run - 0.05), Vector3.UP, coping, false)
	if handrail:
		var iron := KitMaterials.metal(Color(0.05, 0.05, 0.05), 0.5)
		var round := arc(Vector2.ZERO, 0.02, 0.0, TAU * 9.0 / 10.0, 9)
		var x := hw - 0.08
		var low := Vector3(x, ground + 0.9, back + 0.1)
		var high := Vector3(x, 0.9, -landing - 0.05)
		b.extrude(round, low, high, Vector3.UP, iron, false, true)
		b.extrude(round, high, Vector3(x, 0.9, -0.05), Vector3.UP, iron, false, true)
		for post in [Vector3(x, ground, back + 0.1), Vector3(x, 0.0, -landing - 0.05), Vector3(x, 0.0, -0.05)]:
			var top_y := low.y if post.y < -0.01 else 0.9
			b.box(post + Vector3(-0.012, 0, -0.012), Vector3(post.x + 0.012, top_y, post.z + 0.012), iron, false)
	# Walk up a ramp rather than the individual steps.
	b.collision_quad(Vector3(-hw, ground, back), Vector3(hw, ground, back), Vector3(hw, 0.0, -landing), Vector3(-hw, 0.0, -landing))
