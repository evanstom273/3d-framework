@tool
class_name KitWall
extends KitPiece
## A straight wall with doors, windows and open doorways.
##
## The wall runs along +X from the origin for `length` metres, centred on its grid
## line. The outside is -Z, the inside +Z. The origin is at finished floor level.
##
## Corners: where two walls meet, set the end of one to CORNER (it runs on to cover
## the corner and wraps its facade round it) and the end of the other to
## BUTT_EXTERIOR (it stops at the first wall's inside face). Interior walls meeting
## an exterior wall use BUTT_EXTERIOR; meeting another interior wall, BUTT_INTERIOR.

enum WallType { EXTERIOR, INTERIOR, GARDEN }
enum Join { NONE, CORNER, BUTT_EXTERIOR, BUTT_INTERIOR }

const THICKNESS := {WallType.EXTERIOR: 0.3, WallType.INTERIOR: 0.12, WallType.GARDEN: 0.225}
## Brick outer leaf of a cavity wall.
const OUTER_LEAF := 0.105
## Frames sit back from the outside face, in the reveal.
const SETBACK := 0.1

@export var wall_type: WallType = WallType.EXTERIOR:
	set(value):
		wall_type = value
		queue_rebuild()
@export_range(0.3, 30.0, 0.05, "or_greater", "suffix:m") var length: float = 3.0:
	set(value):
		length = snap(value, 0.3)
		queue_rebuild()
## Floor to floor for storey walls (3.0), or the height of a garden wall.
@export_range(0.3, 10.0, 0.05, "suffix:m") var height: float = 3.0:
	set(value):
		height = snap(value, 0.3)
		queue_rebuild()
@export var start_join: Join = Join.NONE:
	set(value):
		start_join = value
		queue_rebuild()
@export var end_join: Join = Join.NONE:
	set(value):
		end_join = value
		queue_rebuild()
@export var openings: Array[KitOpening] = []:
	set(value):
		for opening in openings:
			if opening != null and opening.changed.is_connected(queue_rebuild):
				opening.changed.disconnect(queue_rebuild)
		openings = value
		for opening in openings:
			if opening != null and not opening.changed.is_connected(queue_rebuild):
				opening.changed.connect(queue_rebuild)
		queue_rebuild()

@export_group("Outside")
@export var facade: KitMaterials.Facade = KitMaterials.Facade.BRICK:
	set(value):
		facade = value
		queue_rebuild()
@export var brick: KitMaterials.Brick = KitMaterials.Brick.RED:
	set(value):
		brick = value
		queue_rebuild()
## Render or cladding colour.
@export var facade_color: Color = Color(0.93, 0.91, 0.85):
	set(value):
		facade_color = value
		queue_rebuild()
## How far the outside face continues below the floor, down to the ground.
@export_range(0.0, 2.0, 0.05, "suffix:m") var plinth_drop: float = 0.3:
	set(value):
		plinth_drop = value
		queue_rebuild()
## Stone quoins on CORNER ends.
@export var quoins: bool = false:
	set(value):
		quoins = value
		queue_rebuild()
## A projecting band course at this height (0 for none).
@export_range(0.0, 10.0, 0.05, "suffix:m") var band_course_height: float = 0.0:
	set(value):
		band_course_height = value
		queue_rebuild()

@export_group("Inside")
@export var inside_color: Color = Color(0.93, 0.91, 0.86):
	set(value):
		inside_color = value
		queue_rebuild()
## Interior walls: paint on the -Z side.
@export var other_side_color: Color = Color(0.93, 0.91, 0.86):
	set(value):
		other_side_color = value
		queue_rebuild()
## Where this storey's ceiling is (the underside of the floor above).
@export_range(1.0, 10.0, 0.05, "suffix:m") var ceiling_height: float = 2.75:
	set(value):
		ceiling_height = value
		queue_rebuild()
@export var skirting: bool = true:
	set(value):
		skirting = value
		queue_rebuild()
@export var coving: bool = true:
	set(value):
		coving = value
		queue_rebuild()
@export var dado_rail: bool = false:
	set(value):
		dado_rail = value
		queue_rebuild()
@export var picture_rail: bool = false:
	set(value):
		picture_rail = value
		queue_rebuild()
## Wall tiles on the inside face up to this height (0 for none).
@export_range(0.0, 3.0, 0.05, "suffix:m") var tile_height: float = 0.0:
	set(value):
		tile_height = value
		queue_rebuild()
@export var tile_color: Color = Color(0.94, 0.95, 0.93):
	set(value):
		tile_color = value
		queue_rebuild()
@export var joinery_color: Color = Color(0.95, 0.95, 0.92):
	set(value):
		joinery_color = value
		queue_rebuild()

var _holes: Array[Rect2] = []


func thickness() -> float:
	return THICKNESS[wall_type]


func _start_x() -> float:
	return _join_offset(start_join, -1.0)


func _end_x() -> float:
	return length + _join_offset(end_join, 1.0)


func _join_offset(join: Join, direction: float) -> float:
	match join:
		Join.CORNER:
			return direction * thickness() * 0.5
		Join.BUTT_EXTERIOR:
			return -direction * THICKNESS[WallType.EXTERIOR] * 0.5
		Join.BUTT_INTERIOR:
			return -direction * THICKNESS[WallType.INTERIOR] * 0.5
	return 0.0


func _bottom() -> float:
	match wall_type:
		WallType.EXTERIOR:
			return -plinth_drop
		WallType.GARDEN:
			return -0.1
	return 0.0


func _build(b: KitBuilder) -> void:
	var half := thickness() * 0.5
	var x0 := _start_x()
	var x1 := _end_x()
	var y0 := _bottom()
	_holes.clear()
	for opening in openings:
		if opening == null:
			continue
		var left := clampf(opening.position - opening.width * 0.5, x0 + 0.05, x1 - 0.05)
		var right := clampf(opening.position + opening.width * 0.5, x0 + 0.05, x1 - 0.05)
		var bottom := opening.bottom()
		var top := minf(bottom + opening.height, height - 0.1)
		_holes.append(Rect2(left, bottom, right - left, top - bottom) if right - left > 0.2 and top > bottom else Rect2())
	var solid := _subtract(Rect2(x0, y0, x1 - x0, height - y0), _holes)
	var paint_in := KitMaterials.paint(inside_color)
	match wall_type:
		WallType.EXTERIOR:
			_build_exterior(b, solid, half, x0, x1, paint_in)
		WallType.INTERIOR:
			var paint_out := KitMaterials.paint(other_side_color)
			for rect in solid:
				b.box(Vector3(rect.position.x, rect.position.y, -half), Vector3(rect.end.x, rect.end.y, half), paint_out, true, KitBuilder.FACE_ALL & ~KitBuilder.FACE_POS_Z)
				b.box(Vector3(rect.position.x, rect.position.y, -half), Vector3(rect.end.x, rect.end.y, half), paint_in, false, KitBuilder.FACE_POS_Z)
		WallType.GARDEN:
			var face := KitMaterials.facade(facade, brick, facade_color)
			for rect in solid:
				b.box(Vector3(rect.position.x, rect.position.y, -half), Vector3(rect.end.x, rect.end.y, half), face)
			_coping(b, half, x0, x1)
	for i in openings.size():
		if openings[i] != null and _holes[i].has_area():
			_opening_details(b, openings[i], _holes[i], half)
	_interior_finishes(b, half, x0, x1)
	if quoins and wall_type != WallType.INTERIOR:
		if start_join == Join.CORNER:
			_quoins(b, half, x0, -1.0)
		if end_join == Join.CORNER:
			_quoins(b, half, x1, 1.0)


func _build_exterior(b: KitBuilder, solid: Array[Rect2], half: float, x0: float, x1: float, paint_in: Material) -> void:
	var cladding := facade == KitMaterials.Facade.TIMBER_CLADDING
	var face := KitMaterials.paint(Color(0.2, 0.2, 0.2)) if cladding else KitMaterials.facade(facade, brick, facade_color)
	for rect in solid:
		# CORNER ends turn the facade round the end of the wall.
		var r0 := rect.position.x
		var r1 := rect.end.x
		if start_join == Join.CORNER and r0 < x0 + OUTER_LEAF - 0.001:
			var cut := minf(x0 + OUTER_LEAF, r1)
			b.box(Vector3(r0, rect.position.y, -half), Vector3(cut, rect.end.y, half), face)
			r0 = cut
		if end_join == Join.CORNER and r1 > x1 - OUTER_LEAF + 0.001:
			var cut := maxf(x1 - OUTER_LEAF, r0)
			b.box(Vector3(cut, rect.position.y, -half), Vector3(r1, rect.end.y, half), face)
			r1 = cut
		if r1 - r0 > 0.0005:
			b.box(Vector3(r0, rect.position.y, -half), Vector3(r1, rect.end.y, -half + OUTER_LEAF), face, true, KitBuilder.FACE_ALL & ~KitBuilder.FACE_POS_Z)
			b.box(Vector3(r0, rect.position.y, -half + OUTER_LEAF), Vector3(r1, rect.end.y, half), paint_in, true, KitBuilder.FACE_ALL & ~KitBuilder.FACE_NEG_Z)
		if cladding:
			_weatherboards(b, rect, half)
	if plinth_drop > 0.05:
		_plinth(b, half, x0, x1)
	if band_course_height > 0.0:
		var band := KitMaterials.brick(brick, true) if facade == KitMaterials.Facade.BRICK else KitMaterials.stone()
		var bx0 := x0 - (0.025 if start_join == Join.CORNER else 0.0)
		var bx1 := x1 + (0.025 if end_join == Join.CORNER else 0.0)
		b.box(Vector3(bx0, band_course_height, -half - 0.025), Vector3(bx1, band_course_height + 0.15, -half + 0.05), band)
		if end_join == Join.CORNER:
			b.box(Vector3(x1 - 0.05, band_course_height, -half + 0.05), Vector3(bx1, band_course_height + 0.15, half), band)
		if start_join == Join.CORNER:
			b.box(Vector3(bx0, band_course_height, -half + 0.05), Vector3(x0 + 0.05, band_course_height + 0.15, half), band)


## Overlapping horizontal boards on the outside face of one solid rectangle.
func _weatherboards(b: KitBuilder, rect: Rect2, half: float) -> void:
	var board := KitMaterials.gloss(facade_color)
	var pitch := 0.15
	var y := floorf(rect.position.y / pitch) * pitch
	while y < rect.end.y - 0.001:
		var bottom := maxf(y, rect.position.y)
		var top := minf(y + pitch, rect.end.y)
		if top - bottom > 0.004:
			var proud := lerpf(0.008, 0.022, 1.0 - (bottom - y) / pitch)
			var profile := PackedVector2Array([Vector2(0, bottom), Vector2(proud, bottom), Vector2(lerpf(0.022, 0.008, (top - y) / pitch), top), Vector2(0, top)])
			# Extruding along +X puts "across" on -Z, i.e. out of the wall.
			b.extrude(profile, Vector3(rect.position.x, 0, -half), Vector3(rect.end.x, 0, -half), Vector3.UP, board, false)
		y += pitch


func _plinth(b: KitBuilder, half: float, x0: float, x1: float) -> void:
	var material := KitMaterials.brick(KitMaterials.Brick.ENGINEERING_BLUE) if facade == KitMaterials.Facade.BRICK else KitMaterials.render(Color(0.45, 0.45, 0.44))
	var px0 := x0 - (0.015 if start_join == Join.CORNER else 0.0)
	var px1 := x1 + (0.015 if end_join == Join.CORNER else 0.0)
	b.box(Vector3(px0, -plinth_drop, -half - 0.015), Vector3(px1, -0.1, -half + 0.05), material)
	var bevel := PackedVector2Array([Vector2(-0.05, -0.1), Vector2(0.015, -0.1), Vector2(0.0, -0.075), Vector2(-0.05, -0.075)])
	b.extrude(bevel, Vector3(px0, 0, -half), Vector3(px1, 0, -half), Vector3.UP, material, false)
	for side in [[start_join, x0, -1.0], [end_join, x1, 1.0]]:
		if side[0] != Join.CORNER:
			continue
		var edge: float = side[1]
		var dir: float = side[2]
		var lo := minf(edge - dir * 0.05, edge + dir * 0.015)
		var hi := maxf(edge - dir * 0.05, edge + dir * 0.015)
		b.box(Vector3(lo, -plinth_drop, -half + 0.05), Vector3(hi, -0.1, half), material)
		# The bevel turns the corner too, running along the end face behind the front one.
		var along_from := Vector3(edge, 0, -half + 0.05) if dir > 0.0 else Vector3(edge, 0, half)
		var along_to := Vector3(edge, 0, half) if dir > 0.0 else Vector3(edge, 0, -half + 0.05)
		b.extrude(bevel, along_from, along_to, Vector3.UP, material, false)


func _coping(b: KitBuilder, half: float, x0: float, x1: float) -> void:
	var stone := KitMaterials.stone(Color(0.72, 0.7, 0.66))
	var w := half + 0.035
	# Saddleback coping with drip grooves either side.
	var profile := PackedVector2Array([Vector2(-w, 0.0), Vector2(-w, 0.05), Vector2(0.0, 0.09), Vector2(w, 0.05), Vector2(w, 0.0), Vector2(w - 0.02, 0.0), Vector2(w - 0.02, 0.008), Vector2(w - 0.03, 0.008), Vector2(w - 0.03, 0.0), Vector2(-w + 0.03, 0.0), Vector2(-w + 0.03, 0.008), Vector2(-w + 0.02, 0.008), Vector2(-w + 0.02, 0.0)])
	b.extrude(profile, Vector3(x1 + 0.0, height, 0), Vector3(x0, height, 0), Vector3.UP, stone)


func _opening_details(b: KitBuilder, o: KitOpening, hole: Rect2, half: float) -> void:
	var frame := KitMaterials.gloss(o.frame_color)
	var x0 := hole.position.x
	var x1 := hole.end.x
	var bottom := hole.position.y
	var top := hole.end.y
	var exterior := wall_type == WallType.EXTERIOR
	var stone := KitMaterials.stone()
	match o.kind:
		KitOpening.Kind.WINDOW:
			var z0 := -half + SETBACK if exterior else -0.035
			KitJoinery.window_frame(b, o, x0, x1, bottom, top, z0, z0 + 0.07, frame)
			if exterior:
				# Projecting stone sill with a drip, and a window board inside.
				var sill_material := frame if facade == KitMaterials.Facade.TIMBER_CLADDING else stone
				var out := SETBACK + 0.05
				var sill := PackedVector2Array([Vector2(-0.02, bottom + 0.02), Vector2(out, bottom - 0.006), Vector2(out, bottom - 0.065), Vector2(out - 0.02, bottom - 0.065), Vector2(out - 0.02, bottom - 0.055), Vector2(out - 0.03, bottom - 0.055), Vector2(out - 0.03, bottom - 0.065), Vector2(-0.02, bottom - 0.065)])
				b.extrude(sill, Vector3(x0 - 0.05, 0, z0), Vector3(x1 + 0.05, 0, z0), Vector3.UP, sill_material)
				var board := KitMaterials.gloss(joinery_color)
				b.box(Vector3(x0 - 0.03, bottom - 0.005, z0 + 0.07), Vector3(x1 + 0.03, bottom + 0.022, half + 0.028), board)
		_:
			var z0 := -half + SETBACK if exterior else -half
			var z1 := z0 + 0.1 if exterior else half
			KitJoinery.door_frame(b, o, x0, x1, top, z0, z1, frame)
			var trim := KitMaterials.gloss(joinery_color)
			KitJoinery.architrave(b, x0, x1, top, half, 1.0, trim)
			if exterior:
				# Stone threshold under the door, sloping out.
				var inside := half * 2.0 - SETBACK
				var threshold := PackedVector2Array([Vector2(-inside, 0.006), Vector2(-0.1, 0.012), Vector2(SETBACK + 0.06, -0.01), Vector2(SETBACK + 0.06, -0.06), Vector2(-inside, -0.06)])
				b.extrude(threshold, Vector3(x0, 0, z0 + 0.0), Vector3(x1, 0, z0 + 0.0), Vector3.UP, stone)
			elif wall_type == WallType.INTERIOR:
				KitJoinery.architrave(b, x0, x1, top, -half, -1.0, KitMaterials.gloss(joinery_color))
	if exterior or wall_type == WallType.GARDEN:
		_head(b, o, x0, x1, top, half)


## Lintel detail over an opening on the outside face.
func _head(b: KitBuilder, o: KitOpening, x0: float, x1: float, top: float, half: float) -> void:
	if facade == KitMaterials.Facade.TIMBER_CLADDING or top > height - 0.15:
		return
	var face_z := -half
	match o.head:
		KitOpening.Head.SOLDIER_COURSE:
			if facade == KitMaterials.Facade.BRICK:
				b.box(Vector3(x0, top - 0.002, face_z - 0.003), Vector3(x1, minf(top + 0.225, height), face_z + OUTER_LEAF), KitMaterials.brick(brick, true))
		KitOpening.Head.STONE_LINTEL, KitOpening.Head.STONE_KEYSTONE:
			var stone := KitMaterials.stone()
			b.box(Vector3(x0 - 0.1, top - 0.002, face_z - 0.012), Vector3(x1 + 0.1, minf(top + 0.15, height), face_z + OUTER_LEAF), stone)
			if o.head == KitOpening.Head.STONE_KEYSTONE:
				var mid := (x0 + x1) * 0.5
				var key := PackedVector2Array([Vector2(mid - 0.07, top - 0.03), Vector2(mid + 0.07, top - 0.03), Vector2(mid + 0.1, top + 0.19), Vector2(mid - 0.1, top + 0.19)])
				# A tapered keystone standing proud of the lintel.
				b.slab(key, Vector3(0, 0, face_z + 0.03), Vector3.RIGHT, Vector3.UP, 0.06, stone, stone)


## Skirting, tiles, rails and coving on the inside face(s).
func _interior_finishes(b: KitBuilder, half: float, x0: float, x1: float) -> void:
	var faces: Array = []
	if wall_type == WallType.EXTERIOR:
		faces.append([half, 1.0, inside_color])
	elif wall_type == WallType.INTERIOR:
		faces.append([half, 1.0, inside_color])
		faces.append([-half, -1.0, other_side_color])
	var trim := KitMaterials.gloss(joinery_color)
	for face in faces:
		var z: float = face[0]
		var side: float = face[1]
		# On the inside of a corner, the other wall covers this face's last `thickness`.
		var inner_x0 := x0 + (thickness() if start_join == Join.CORNER and side > 0.0 else 0.0)
		var inner_x1 := x1 - (thickness() if end_join == Join.CORNER and side > 0.0 else 0.0)
		var tiled := tile_height > 0.0 and side > 0.0
		if tiled:
			var tiles := KitMaterials.tiles(tile_color)
			var tile_top := minf(tile_height, ceiling_height)
			for rect in _subtract(Rect2(inner_x0, 0.0, inner_x1 - inner_x0, tile_top), _holes):
				b.box(Vector3(rect.position.x, rect.position.y, z), Vector3(rect.end.x, rect.end.y, z + 0.008), tiles, false)
			for span in _free_spans(inner_x0, inner_x1, tile_top - 0.01, tile_top + 0.01):
				_moulding(b, PackedVector2Array([Vector2(0, 0), Vector2(0.012, 0), Vector2(0.012, 0.006), Vector2(0.006, 0.014), Vector2(0, 0.014)]), span.x, span.y, tile_top, z, side, KitMaterials.tiles(tile_color))
		if skirting and not tiled:
			var profile := PackedVector2Array([Vector2(0, 0), Vector2(0.018, 0), Vector2(0.018, 0.11), Vector2(0.013, 0.125), Vector2(0.016, 0.135), Vector2(0.008, 0.15), Vector2(0, 0.15)])
			for span in _free_spans(inner_x0, inner_x1, 0.0, 0.15):
				_moulding(b, profile, span.x, span.y, 0.0, z, side, trim)
		if dado_rail:
			var dado := PackedVector2Array([Vector2(0, 0), Vector2(0.012, 0.004), Vector2(0.018, 0.02), Vector2(0.012, 0.036), Vector2(0, 0.045)])
			for span in _free_spans(inner_x0, inner_x1, 0.88, 0.94):
				_moulding(b, dado, span.x, span.y, 0.88, z, side, trim)
		if picture_rail and ceiling_height > 2.4:
			var rail := PackedVector2Array([Vector2(0, 0), Vector2(0.016, 0.006), Vector2(0.02, 0.02), Vector2(0.008, 0.032), Vector2(0, 0.035)])
			for span in _free_spans(inner_x0, inner_x1, ceiling_height - 0.5, ceiling_height - 0.46):
				_moulding(b, rail, span.x, span.y, ceiling_height - 0.5, z, side, trim)
		if coving and ceiling_height < height - 0.01:
			var cove := PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0)])
			cove.append_array(arc(Vector2(0.1, -0.1), 0.1, PI * 0.5, PI, 8).slice(1))
			var plaster := KitMaterials.paint(Color(0.97, 0.97, 0.95))
			for span in _free_spans(inner_x0, inner_x1, ceiling_height - 0.1, ceiling_height):
				_moulding(b, cove, span.x, span.y, ceiling_height, z, side, plaster)


## Extrudes a trim profile (out from the face, up) along the face at z, facing `side`.
func _moulding(b: KitBuilder, profile: PackedVector2Array, from_x: float, to_x: float, y: float, z: float, side: float, material: Material) -> void:
	var shifted := PackedVector2Array()
	for p in profile:
		shifted.append(Vector2(p.x, p.y + y))
	# Extruding along -X puts "across" on +Z; along +X it is -Z.
	if side > 0.0:
		b.extrude(shifted, Vector3(to_x, 0, z), Vector3(from_x, 0, z), Vector3.UP, material, false)
	else:
		b.extrude(shifted, Vector3(from_x, 0, z), Vector3(to_x, 0, z), Vector3.UP, material, false)


func _quoins(b: KitBuilder, half: float, edge: float, direction: float) -> void:
	var stone := KitMaterials.stone(Color(0.82, 0.79, 0.72))
	var course := 0.225
	var y := maxf(_bottom(), -0.1) if plinth_drop > 0.05 else 0.0
	var index := 0
	while y + course <= height + 0.001:
		var long := index % 2 == 0
		var front := 0.32 if long else 0.18
		var back := thickness() if not long else 0.16
		var proud := 0.012
		# Block on the main face, and its return on the end face.
		var fx0 := edge - direction * front
		var fx1 := edge + direction * proud
		b.box(Vector3(minf(fx0, fx1), y, -half - proud), Vector3(maxf(fx0, fx1), y + course - 0.012, -half + 0.04), stone)
		var rx0 := edge - direction * 0.04
		b.box(Vector3(minf(rx0, fx1), y, -half + 0.04), Vector3(maxf(rx0, fx1), y + course - 0.012, -half + back), stone)
		y += course
		index += 1


func _build_fixtures() -> void:
	var half := thickness() * 0.5
	var exterior := wall_type == WallType.EXTERIOR
	for i in openings.size():
		var o := openings[i]
		if o == null or i >= _holes.size() or not _holes[i].has_area():
			continue
		var hole := _holes[i]
		match o.kind:
			KitOpening.Kind.DOOR:
				var z0 := -half + SETBACK if exterior else -half
				var z1 := z0 + 0.1 if exterior else half
				add_generated(KitJoinery.door_leaf(o, hole.position.x, hole.end.x, hole.end.y, z0, z1, exterior))
			KitOpening.Kind.WINDOW:
				var z0 := -half + SETBACK if exterior else -0.035
				for node in KitJoinery.window_sashes(o, hole.position.x, hole.end.x, hole.position.y, hole.end.y, z0):
					add_generated(node)


# --- 2D helpers

## Rectangles covering `area` minus `holes`, as vertical strips merged where possible.
static func _subtract(area: Rect2, holes: Array[Rect2]) -> Array[Rect2]:
	var xs: Array[float] = [area.position.x, area.end.x]
	for hole in holes:
		if hole.has_area():
			xs.append(clampf(hole.position.x, area.position.x, area.end.x))
			xs.append(clampf(hole.end.x, area.position.x, area.end.x))
	xs.sort()
	var strips: Array[Rect2] = []
	for i in range(xs.size() - 1):
		var a := xs[i]
		var c := xs[i + 1]
		if c - a < 0.0005:
			continue
		var mid := (a + c) * 0.5
		var intervals: Array[Vector2] = [Vector2(area.position.y, area.end.y)]
		for hole in holes:
			if not hole.has_area() or mid <= hole.position.x or mid >= hole.end.x:
				continue
			var cut: Array[Vector2] = []
			for interval in intervals:
				if hole.position.y > interval.x + 0.0005:
					cut.append(Vector2(interval.x, minf(interval.y, hole.position.y)))
				if hole.end.y < interval.y - 0.0005:
					cut.append(Vector2(maxf(interval.x, hole.end.y), interval.y))
			intervals = cut
		for interval in intervals:
			if interval.y - interval.x > 0.0005:
				strips.append(Rect2(a, interval.x, c - a, interval.y - interval.x))
	# Merge neighbours with the same vertical extent, so solid runs are single boxes.
	var merged: Array[Rect2] = []
	for strip in strips:
		var joined := false
		for k in merged.size():
			var m := merged[k]
			if absf(m.end.x - strip.position.x) < 0.0005 and absf(m.position.y - strip.position.y) < 0.0005 and absf(m.end.y - strip.end.y) < 0.0005:
				merged[k] = Rect2(m.position, Vector2(strip.end.x - m.position.x, m.size.y))
				joined = true
				break
		if not joined:
			merged.append(strip)
	return merged


## X ranges between x0 and x1 where no opening crosses the band y0..y1.
func _free_spans(x0: float, x1: float, y0: float, y1: float) -> Array[Vector2]:
	var spans: Array[Vector2] = [Vector2(x0, x1)]
	for hole in _holes:
		if not hole.has_area() or hole.end.y <= y0 or hole.position.y >= y1:
			continue
		var next: Array[Vector2] = []
		for span in spans:
			if hole.position.x > span.x:
				next.append(Vector2(span.x, minf(span.y, hole.position.x - (0.07 if y0 < 0.2 else 0.0))))
			if hole.end.x < span.y:
				next.append(Vector2(maxf(span.x, hole.end.x + (0.07 if y0 < 0.2 else 0.0)), span.y))
		spans = next
	var result: Array[Vector2] = []
	for span in spans:
		if span.y - span.x > 0.01:
			result.append(span)
	return result
