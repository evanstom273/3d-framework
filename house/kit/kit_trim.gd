@tool
class_name KitTrim
extends KitPiece
## A straight run of moulding fixed to a wall face: cornice, dentil cornice, brick
## band, stone string course or timber fascia. The origin is on the wall's
## outside face; the run goes along +X and projects toward -Z.

enum Profile { STONE_STRING_COURSE, CORNICE, DENTIL_CORNICE, SOLDIER_BAND, FASCIA_BOARD }

@export var profile: Profile = Profile.STONE_STRING_COURSE:
	set(value):
		profile = value
		queue_rebuild()
@export_range(0.1, 40.0, 0.05, "suffix:m") var length: float = 3.0:
	set(value):
		length = snap(value, 0.1)
		queue_rebuild()
@export var color: Color = Color(0.82, 0.79, 0.72):
	set(value):
		color = value
		queue_rebuild()
@export var brick: KitMaterials.Brick = KitMaterials.Brick.RED:
	set(value):
		brick = value
		queue_rebuild()


func _build(b: KitBuilder) -> void:
	var stone := KitMaterials.stone(color)
	# Extruding along +X puts "across" on -Z, out of the wall.
	var from := Vector3.ZERO
	var to := Vector3(length, 0, 0)
	match profile:
		Profile.STONE_STRING_COURSE:
			b.extrude(PackedVector2Array([Vector2(-0.02, 0.0), Vector2(0.04, 0.0), Vector2(0.05, 0.01), Vector2(0.05, 0.1), Vector2(0.03, 0.12), Vector2(-0.02, 0.12)]), from, to, Vector3.UP, stone)
		Profile.CORNICE, Profile.DENTIL_CORNICE:
			var cornice := PackedVector2Array([Vector2(-0.02, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.04), Vector2(0.07, 0.07), Vector2(0.12, 0.1), Vector2(0.15, 0.13), Vector2(0.15, 0.2), Vector2(-0.02, 0.2)])
			b.extrude(cornice, from, to, Vector3.UP, stone)
			if profile == Profile.DENTIL_CORNICE:
				var x := 0.03
				while x + 0.04 <= length:
					b.box(Vector3(x, 0.035, -0.07), Vector3(x + 0.04, 0.075, 0.0), stone, false)
					x += 0.07
		Profile.SOLDIER_BAND:
			b.box(Vector3(0, 0, -0.02), Vector3(length, 0.225, 0.02), KitMaterials.brick(brick, true))
		Profile.FASCIA_BOARD:
			b.box(Vector3(0, 0, -0.025), Vector3(length, 0.2, 0.0), KitMaterials.gloss(color))
