@tool
class_name KitPorch
extends KitPiece
## An open porch over a door. The origin is on the wall's grid line at the middle
## of the porch, at floor level; the porch projects toward -Z (outside). It has a
## tiled platform, posts or columns (or wall brackets), beams, and a tiled
## lean-to or gabled roof with its own gutter.

enum RoofStyle { LEAN_TO, GABLE }
enum Supports { TIMBER_POSTS, COLUMNS, BRICK_PIERS, WALL_BRACKETS }

@export_range(1.0, 6.0, 0.05, "suffix:m") var width: float = 2.2:
	set(value):
		width = snap(value, 1.0)
		queue_rebuild()
@export_range(0.6, 4.0, 0.05, "suffix:m") var depth: float = 1.4:
	set(value):
		depth = snap(value, 0.6)
		queue_rebuild()
## Height of the beams (eaves) above the floor.
@export_range(1.8, 4.0, 0.05, "suffix:m") var post_height: float = 2.45:
	set(value):
		post_height = value
		queue_rebuild()
@export var roof_style: RoofStyle = RoofStyle.LEAN_TO:
	set(value):
		roof_style = value
		queue_rebuild()
@export_range(10.0, 55.0, 0.5, "suffix:°") var pitch: float = 30.0:
	set(value):
		pitch = value
		queue_rebuild()
@export var supports: Supports = Supports.TIMBER_POSTS:
	set(value):
		supports = value
		queue_rebuild()
@export var tiles: KitMaterials.RoofTile = KitMaterials.RoofTile.CLAY_PLAIN:
	set(value):
		tiles = value
		queue_rebuild()
## A tiled platform under the porch, down to the ground.
@export var platform: bool = true:
	set(value):
		platform = value
		queue_rebuild()
@export_range(0.0, 2.0, 0.05, "suffix:m") var platform_drop: float = 0.3:
	set(value):
		platform_drop = value
		queue_rebuild()
@export var timber_color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		timber_color = value
		queue_rebuild()
@export var brick: KitMaterials.Brick = KitMaterials.Brick.RED:
	set(value):
		brick = value
		queue_rebuild()
## Thickness of the wall the porch stands against.
@export_range(0.05, 0.6, 0.005, "suffix:m") var wall_thickness: float = 0.3:
	set(value):
		wall_thickness = value
		queue_rebuild()

const POST_INSET := 0.12


func _build(b: KitBuilder) -> void:
	var face_z := -wall_thickness * 0.5
	var front := face_z - depth
	var hw := width * 0.5
	var timber := KitMaterials.gloss(timber_color)
	if platform:
		var edge := KitMaterials.stone(Color(0.72, 0.7, 0.66))
		var quarry := KitMaterials.tiles(Color(0.62, 0.22, 0.16), Vector2(0.15, 0.15), Color(0.12, 0.12, 0.13))
		b.box(Vector3(-hw, -platform_drop, front), Vector3(hw, -0.03, face_z), edge)
		b.box(Vector3(-hw + 0.04, -0.03, front + 0.04), Vector3(hw - 0.04, 0.0, face_z), quarry)
		# Stone edging round the tiles (front piece full width, sides between).
		b.box(Vector3(-hw, -0.03, front), Vector3(hw, 0.0, front + 0.04), edge)
		b.box(Vector3(-hw, -0.03, front + 0.04), Vector3(-hw + 0.04, 0.0, face_z), edge)
		b.box(Vector3(hw - 0.04, -0.03, front + 0.04), Vector3(hw, 0.0, face_z), edge)
	var beam_y := post_height - 0.15
	var post_z := front + POST_INSET
	if supports == Supports.WALL_BRACKETS:
		for x in [-hw + POST_INSET, hw - POST_INSET]:
			_bracket(b, Vector3(x, beam_y, face_z), post_z, timber)
	else:
		for x in [-hw + POST_INSET, hw - POST_INSET]:
			KitPorch.support(b, supports, Vector3(x, 0, post_z), beam_y, timber, brick)
	# Beams: across the front, and back to the wall each side.
	b.box(Vector3(-hw + 0.02, beam_y, post_z - 0.05), Vector3(hw - 0.02, post_height, post_z + 0.05), timber)
	for x in [-hw + POST_INSET, hw - POST_INSET]:
		b.box(Vector3(x - 0.045, beam_y, post_z + 0.05), Vector3(x + 0.045, post_height, face_z), timber)
	var roof := KitRoof.new()
	roof.tiles = tiles
	roof.pitch = pitch
	roof.gable_walls = false
	roof.fascia_color = timber_color
	roof.wall_thickness = 0.1
	roof.eaves_overhang = 0.18
	roof.verge_overhang = 0.12
	var saved := b.transform
	if roof_style == RoofStyle.LEAN_TO:
		# The roof's +X (up the slope) points at the wall, its +Z runs along the porch.
		roof.lean_to = true
		roof.span = maxf(0.3, depth - POST_INSET - 0.05)
		roof.length = width - POST_INSET * 2.0
		roof.start_end = KitRoof.End.GABLE
		roof.finish_end = KitRoof.End.GABLE
		b.transform = saved * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(hw - POST_INSET, post_height, post_z))
	else:
		# Ridge runs out from the wall; the open gable faces the garden.
		roof.span = width - POST_INSET * 2.0
		roof.length = depth - POST_INSET
		roof.start_end = KitRoof.End.OPEN
		roof.finish_end = KitRoof.End.GABLE
		b.transform = saved * Transform3D(Basis(Vector3.UP, PI), Vector3(hw - POST_INSET, post_height, face_z))
	roof._build(b)
	b.transform = saved
	roof.free()


## A post, column or pier standing at `base`, carrying a beam at height `top`.
static func support(b: KitBuilder, kind: Supports, base: Vector3, top: float, timber: Material, brick: KitMaterials.Brick) -> void:
	match kind:
		Supports.COLUMNS:
			# Turned Tuscan column: base mouldings, tapered shaft, capital.
			var h := top
			var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.11, 0.0), Vector2(0.11, 0.05), Vector2(0.095, 0.07), Vector2(0.1, 0.09), Vector2(0.08, 0.11),
				Vector2(0.075, 0.14), Vector2(0.062, h - 0.16), Vector2(0.07, h - 0.13), Vector2(0.066, h - 0.11), Vector2(0.09, h - 0.06), Vector2(0.105, h - 0.06), Vector2(0.105, h), Vector2(0.0, h)])
			b.lathe(profile, base, 20, timber, true)
		Supports.BRICK_PIERS:
			b.box(base + Vector3(-0.165, 0, -0.165), base + Vector3(0.165, top - 0.08, 0.165), KitMaterials.brick(brick))
			b.box(base + Vector3(-0.19, top - 0.08, -0.19), base + Vector3(0.19, top, 0.19), KitMaterials.stone())
		_:
			# Chamfered timber post on a plinth block, with a cap.
			b.box(base + Vector3(-0.07, 0, -0.07), base + Vector3(0.07, 0.12, 0.07), timber)
			b.bevel_box(base + Vector3(-0.05, 0.12, -0.05), base + Vector3(0.05, top - 0.06, 0.05), 0.012, timber)
			b.box(base + Vector3(-0.065, top - 0.06, -0.065), base + Vector3(0.065, top, 0.065), timber)


## A timber bracket on the wall: wall post, arm out to `out_z`, and a diagonal brace.
func _bracket(b: KitBuilder, at: Vector3, out_z: float, timber: Material) -> void:
	b.box(Vector3(at.x - 0.035, at.y - 0.7, at.z - 0.06), Vector3(at.x + 0.035, at.y + 0.15, at.z), timber)
	b.box(Vector3(at.x - 0.035, at.y, out_z - 0.05), Vector3(at.x + 0.035, at.y + 0.15, at.z - 0.06), timber)
	var brace := rect_profile(Vector2(-0.035, -0.035), Vector2(0.035, 0.035))
	b.extrude(brace, Vector3(at.x, at.y - 0.62, at.z - 0.06), Vector3(at.x, at.y + 0.02, lerpf(at.z, out_z, 0.7)), Vector3.RIGHT, timber, false)
