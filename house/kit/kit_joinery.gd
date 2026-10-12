@tool
class_name KitJoinery
extends RefCounted
## Doors and windows for KitWall. Frames, stops, hinges and architraves are static
## geometry in the wall. Leaves, sashes and glass are fine voxel bodies on the
## house's existing breakable hinges: they open, lock, smash and fall out when
## their hinge side is destroyed. All coordinates are wall-local.

const BREAKABLE_HINGE := preload("res://house/breakable_hinge.gd")
const WOOD := preload("res://props/voxel_materials/wood.tres")
## Painted joinery: the same timber, without the raw-wood colour speckle.
static var _painted: VoxelMaterialDefinition
static var _glass_material: VoxelMaterialDefinition
const GLASS := preload("res://props/voxel_materials/glass.tres")
## Leaves and sashes are voxelised at 2.5 cm: fine enough for panels and glazing
## bars, coarse enough that smashing them stays cheap.
const CELL := 0.025
const FRAME := 0.06
const LEAF_CELLS_DEEP := 3
const SASH_CELLS_DEEP := 2


# --- Doors

## Door frame (or lining) occupying z0..z1, with stops and hinge knuckles.
static func door_frame(b: KitBuilder, o: KitOpening, x0: float, x1: float, top: float, z0: float, z1: float, frame: Material) -> void:
	var metal := KitMaterials.metal(Color(0.72, 0.6, 0.32), 0.8)
	b.box(Vector3(x0, 0, z0), Vector3(x0 + FRAME, top, z1), frame)
	b.box(Vector3(x1 - FRAME, 0, z0), Vector3(x1, top, z1), frame)
	b.box(Vector3(x0 + FRAME, top - FRAME, z0), Vector3(x1 - FRAME, top, z1), frame)
	if o.kind == KitOpening.Kind.OPEN_DOORWAY:
		return
	var leaf := _door_leaf_z(o, z0, z1)
	# The stop bead the leaf closes against, on the far side of the leaf from its swing.
	var stop_z0 := leaf.x - 0.015 if o.opens_inward else leaf.y
	var stop_z1 := leaf.x if o.opens_inward else leaf.y + 0.015
	b.box(Vector3(x0 + FRAME, 0, stop_z0), Vector3(x0 + FRAME + 0.012, top - FRAME - 0.012, stop_z1), frame)
	b.box(Vector3(x1 - FRAME - 0.012, 0, stop_z0), Vector3(x1 - FRAME, top - FRAME - 0.012, stop_z1), frame)
	b.box(Vector3(x0 + FRAME, top - FRAME - 0.012, stop_z0), Vector3(x1 - FRAME, top - FRAME, stop_z1), frame)
	var hinge_x := x0 + FRAME if o.hinge_left else x1 - FRAME
	var hinge_z := leaf.y if o.opens_inward else leaf.x
	for y in [0.22, 1.05, top - FRAME - 0.3]:
		b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.009, 0.004), Vector2(0.009, 0.096), Vector2(0.0, 0.1)]), Vector3(hinge_x, y, hinge_z), 8, metal)


## Architrave (moulded trim) round an opening on the face at z, facing `side` (+1 or -1).
static func architrave(b: KitBuilder, x0: float, x1: float, top: float, z: float, side: float, material: Material, bottom := 0.0) -> void:
	var width := 0.07
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(width, 0), Vector2(width, 0.008), Vector2(width * 0.55, 0.016), Vector2(0.012, 0.02), Vector2(0, 0.02)])
	# Profile across the trim (0 at the opening edge) and out from the wall face.
	var out := Vector3(0, 0, side)
	# Extruding up with "up" = out of the face, "across" is -X on a +Z face and +X on a -Z face.
	var flipped := _flip(profile)
	b.extrude(profile if side > 0.0 else flipped, Vector3(x0, bottom, z), Vector3(x0, top + width, z), out, material, false)
	b.extrude(flipped if side > 0.0 else profile, Vector3(x1, bottom, z), Vector3(x1, top + width, z), out, material, false)
	# Along +X, "across" is +Y on a +Z face (up, away from the opening) and -Y on a -Z face.
	b.extrude(profile if side > 0.0 else flipped, Vector3(x0, top, z), Vector3(x1, top, z), out, material, false)


## Mirrors an architrave profile so the moulding faces the other way.
static func _flip(profile: PackedVector2Array) -> PackedVector2Array:
	var flipped := PackedVector2Array()
	for p in profile:
		flipped.append(Vector2(-p.x, p.y))
	return flipped


## Leaf z range (x: front, y: back) inside a frame from z0 to z1.
static func _door_leaf_z(o: KitOpening, z0: float, z1: float) -> Vector2:
	var thickness := CELL * LEAF_CELLS_DEEP
	return Vector2(z1 - thickness, z1) if o.opens_inward else Vector2(z0, z0 + thickness)


static func door_leaf(o: KitOpening, x0: float, x1: float, top: float, z0: float, z1: float, exterior: bool) -> Node3D:
	var inner_width := (x1 - x0) - FRAME * 2.0 - 0.006
	var nx := floori(inner_width / CELL)
	var ny := floori((top - FRAME - 0.012) / CELL)
	var leaf_x := x0 + FRAME + ((x1 - x0) - FRAME * 2.0 - nx * CELL) * 0.5
	var leaf_z := _door_leaf_z(o, z0, z1)
	var width := nx * CELL
	var height := ny * CELL
	var boxes: Array[VoxelFillBox] = []
	var glass_rects: Array[Rect2i] = []
	_door_cells(o, nx, ny, boxes, glass_rects)
	var root := _hinge_root(o.display_name if not o.display_name.is_empty() else ("Front door" if exterior else "Door"), o.lockable,
		(-1.0 if o.hinge_left else 1.0) * (1.0 if o.opens_inward else -1.0) * 95.0)
	root.set_meta(&"door", true)
	var pivot := Vector3(leaf_x if o.hinge_left else leaf_x + width, 0, leaf_z.y if o.opens_inward else leaf_z.x)
	var leaf := _voxel_leaf(root, "Leaf", boxes, Vector3(leaf_x, 0.006, leaf_z.x), pivot)
	var mount := AABB(Vector3(0 if o.hinge_left else width - 0.1, 0, 0), Vector3(0.1, height, CELL * LEAF_CELLS_DEEP))
	_attachment(root, "Attachment", "../Leaf", mount, "", AABB())
	for i in glass_rects.size():
		var rect := glass_rects[i]
		var pane := _glass(root, "Glass%d" % i, rect.size.x, rect.size.y, Vector3(leaf_x, 0.006, leaf_z.x) + Vector3(rect.position.x * CELL, rect.position.y * CELL, CELL))
		var support := AABB(Vector3(rect.position.x * CELL - CELL, rect.position.y * CELL - CELL, 0), Vector3(rect.size.x * CELL + CELL * 2, rect.size.y * CELL + CELL * 2, CELL * LEAF_CELLS_DEEP))
		_attachment(root, "PaneAttachment%d" % i, "../" + pane.name, AABB(), "../Leaf", support)
	_door_hardware(o, leaf, width, height, exterior)
	return root


## Voxel layout of a leaf: nx by ny cells, three deep (0 faces the outside, -Z).
static func _door_cells(o: KitOpening, nx: int, ny: int, boxes: Array[VoxelFillBox], glass: Array[Rect2i]) -> void:
	var color := o.door_color
	# Cell counts at 2.5 cm: 125 mm stiles, 200 mm bottom rail.
	var stile := 5
	var top_rail := 5
	var bottom_rail := 8
	var lock_rail := 7
	var lock_y := clampi(roundi(0.95 / CELL), bottom_rail + 8, ny - top_rail - 12)
	match o.door_style:
		KitOpening.DoorStyle.FLUSH:
			_vbox(boxes, Vector3i.ZERO, Vector3i(nx, ny, 3), color)
		KitOpening.DoorStyle.LEDGED_PLANK:
			# Vertical boards with V-grooves on the face, ledges and braces behind.
			_vbox(boxes, Vector3i(0, 0, 1), Vector3i(nx, ny, 1), color)
			var board := 5
			for x in range(0, nx, board):
				_vbox(boxes, Vector3i(x, 0, 0), Vector3i(mini(board - 1, nx - x), ny, 1), color)
			var ledge := 5
			var ledges := [4, ny / 2 - ledge / 2, ny - ledge - 4]
			for y in ledges:
				_vbox(boxes, Vector3i(2, y, 2), Vector3i(nx - 4, ledge, 1), color.darkened(0.05))
			for k in 2:
				var y_from: int = ledges[k] + ledge
				var y_to: int = ledges[k + 1]
				for y in range(y_from, y_to):
					var t := float(y - y_from) / maxf(1.0, y_to - y_from - 1)
					var x := roundi(lerpf(3, nx - 7, t if o.hinge_left else 1.0 - t))
					_vbox(boxes, Vector3i(x, y, 2), Vector3i(4, 1, 1), color.darkened(0.05))
		_:
			# Stiles and rails full depth; panels recessed both faces with a raised field.
			_vbox(boxes, Vector3i(0, 0, 0), Vector3i(stile, ny, 3), color)
			_vbox(boxes, Vector3i(nx - stile, 0, 0), Vector3i(stile, ny, 3), color)
			_vbox(boxes, Vector3i(stile, 0, 0), Vector3i(nx - stile * 2, bottom_rail, 3), color)
			_vbox(boxes, Vector3i(stile, ny - top_rail, 0), Vector3i(nx - stile * 2, top_rail, 3), color)
			_vbox(boxes, Vector3i(stile, lock_y, 0), Vector3i(nx - stile * 2, lock_rail, 3), color)
			var inner_x := nx - stile * 2
			var muntin := 4
			var lower := Rect2i(stile, bottom_rail, inner_x, lock_y - bottom_rail)
			var upper := Rect2i(stile, lock_y + lock_rail, inner_x, ny - top_rail - lock_y - lock_rail)
			match o.door_style:
				KitOpening.DoorStyle.HALF_GLAZED:
					_two_panels(boxes, lower, muntin, color)
					glass.append(upper)
					_glazing_bars(boxes, upper, 2, 2, color)
				KitOpening.DoorStyle.FULLY_GLAZED:
					# Glass both above and below the lock rail, in one pane each.
					glass.append(lower)
					glass.append(upper)
					_glazing_bars(boxes, upper, 2, 3, color)
					_glazing_bars(boxes, lower, 2, 2, color)
				KitOpening.DoorStyle.SIX_PANEL:
					_two_panels(boxes, lower, muntin, color)
					var frieze := 6
					var frieze_y := upper.position.y + upper.size.y - upper.size.y / 3
					_vbox(boxes, Vector3i(stile, frieze_y, 0), Vector3i(inner_x, frieze, 3), color)
					_two_panels(boxes, Rect2i(upper.position.x, upper.position.y, upper.size.x, frieze_y - upper.position.y), muntin, color)
					_two_panels(boxes, Rect2i(upper.position.x, frieze_y + frieze, upper.size.x, upper.end.y - frieze_y - frieze), muntin, color)
				_:
					_two_panels(boxes, lower, muntin, color)
					_two_panels(boxes, upper, muntin, color)


## Two panels side by side with a muntin between, filling `area`.
static func _two_panels(boxes: Array[VoxelFillBox], area: Rect2i, muntin: int, color: Color) -> void:
	var half := (area.size.x - muntin) / 2
	_vbox(boxes, Vector3i(area.position.x + half, area.position.y, 0), Vector3i(area.size.x - half * 2, area.size.y, 3), color)
	for x in [area.position.x, area.position.x + area.size.x - half]:
		_panel(boxes, Rect2i(x, area.position.y, half, area.size.y), color)


## A recessed panel with a raised and fielded centre.
static func _panel(boxes: Array[VoxelFillBox], area: Rect2i, color: Color) -> void:
	if area.size.x <= 0 or area.size.y <= 0:
		return
	_vbox(boxes, Vector3i(area.position.x, area.position.y, 1), Vector3i(area.size.x, area.size.y, 1), color)
	var border := 2
	if area.size.x > border * 2 + 2 and area.size.y > border * 2 + 2:
		_vbox(boxes, Vector3i(area.position.x + border, area.position.y + border, 0), Vector3i(area.size.x - border * 2, area.size.y - border * 2, 1), color)
		_vbox(boxes, Vector3i(area.position.x + border, area.position.y + border, 2), Vector3i(area.size.x - border * 2, area.size.y - border * 2, 1), color)


## Glazing bars dividing a glazed area into columns x rows (full depth, over the glass).
static func _glazing_bars(boxes: Array[VoxelFillBox], area: Rect2i, columns: int, rows: int, color: Color, depth := 3) -> void:
	for c in range(1, columns):
		var x := area.position.x + area.size.x * c / columns
		_vbox(boxes, Vector3i(x, area.position.y, 0), Vector3i(1, area.size.y, depth), color)
	for r in range(1, rows):
		var y := area.position.y + area.size.y * r / rows
		_vbox(boxes, Vector3i(area.position.x, y, 0), Vector3i(area.size.x, 1, depth), color)


static func _door_hardware(o: KitOpening, leaf: VoxelBody, width: float, height: float, exterior: bool) -> void:
	var thickness := CELL * LEAF_CELLS_DEEP
	var brass := KitMaterials.metal(Color(0.76, 0.6, 0.3), 0.85)
	var chrome := KitMaterials.metal(Color(0.75, 0.76, 0.78), 0.9)
	var black := KitMaterials.metal(Color(0.05, 0.05, 0.05), 0.5)
	var lock_x := width - 0.065 if o.hinge_left else 0.065
	var handle_y := clampf(1.0, 0.3, height - 0.3)
	var out := Basis(Vector3.RIGHT, -PI * 0.5)
	if o.door_style == KitOpening.DoorStyle.LEDGED_PLANK:
		# Black ironmongery: strap hinges across the face and a ring latch.
		for y in [0.18, height - 0.18]:
			var strap := KitBuilder.new()
			var x0 := 0.0 if o.hinge_left else width - 0.45
			strap.box(Vector3(x0, y - 0.02, -0.004), Vector3(x0 + 0.45, y + 0.02, 0.0), black, false)
			KitHardware.mount(leaf, strap, "StrapHinge", Vector3(x0 + 0.225, y, 0.0), CELL, LEAF_CELLS_DEEP, 0.1)
		var latch := KitBuilder.new()
		for face in [-0.004, thickness]:
			latch.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.004), Vector2(0.0, 0.004)]), Vector3(lock_x, handle_y, face), 10, black)
		latch.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(lock_x, handle_y - 0.03, -0.012))
		latch.lathe(PackedVector2Array([Vector2(0.032, -0.004), Vector2(0.038, 0.0), Vector2(0.032, 0.004), Vector2(0.026, 0.0), Vector2(0.032, -0.004)]), Vector3.ZERO, 14, black)
		KitHardware.mount(leaf, latch, "RingLatch", Vector3(lock_x, handle_y, 0.0), CELL, LEAF_CELLS_DEEP)
		return
	var metal := brass if exterior else chrome
	# One set of furniture through the lock: handle each side, and the escutcheons.
	var handles := KitBuilder.new()
	for side in [-1.0, 1.0]:
		var face := 0.0 if side < 0.0 else thickness
		handles.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5 * side), Vector3(lock_x, handle_y, face))
		if exterior and side < 0.0:
			# Brass knob outside.
			handles.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.006), Vector2(0.008, 0.012), Vector2(0.008, 0.04), Vector2(0.026, 0.05), Vector2(0.03, 0.065), Vector2(0.02, 0.078), Vector2(0.0, 0.08)]), Vector3.ZERO, 14, metal)
		else:
			# Lever on a round rose.
			handles.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.026, 0.0), Vector2(0.026, 0.006), Vector2(0.008, 0.01), Vector2(0.008, 0.055), Vector2(0.0, 0.058)]), Vector3.ZERO, 12, metal)
			handles.transform = Transform3D.IDENTITY
			var lever_from := Vector3(lock_x, handle_y, face + side * 0.05)
			handles.extrude(_round_profile(0.008, 8), lever_from, lever_from + Vector3((-1.0 if o.hinge_left else 1.0) * 0.12, 0, 0), Vector3.UP, metal, false, true)
		handles.transform = Transform3D.IDENTITY
		if o.lockable:
			handles.box(Vector3(lock_x - 0.012, handle_y - 0.1, face - (0.003 if side < 0.0 else 0.0)), Vector3(lock_x + 0.012, handle_y - 0.06, face + (0.003 if side > 0.0 else 0.0)), metal, false)
	KitHardware.mount(leaf, handles, "Handles", Vector3(lock_x, handle_y - 0.03, 0.0), CELL, LEAF_CELLS_DEEP, 0.06)
	if exterior:
		# Letter plate and a knocker on the outside face.
		var plate_y := clampf(0.95, 0.4, height - 0.4)
		var plate := KitBuilder.new()
		plate.box(Vector3(width * 0.5 - 0.15, plate_y - 0.035, -0.006), Vector3(width * 0.5 + 0.15, plate_y + 0.035, 0.0), metal, false)
		plate.box(Vector3(width * 0.5 - 0.13, plate_y - 0.012, -0.009), Vector3(width * 0.5 + 0.13, plate_y + 0.012, -0.006), black, false)
		KitHardware.mount(leaf, plate, "LetterPlate", Vector3(width * 0.5, plate_y, 0.0), CELL, LEAF_CELLS_DEEP, 0.1)
		var knocker := KitBuilder.new()
		knocker.transform = Transform3D(out, Vector3(width * 0.5, height - 0.45, 0.0))
		knocker.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.008), Vector2(0.012, 0.014), Vector2(0.0, 0.016)]), Vector3.ZERO, 12, metal)
		knocker.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(width * 0.5, height - 0.5, -0.02))
		knocker.lathe(PackedVector2Array([Vector2(0.045, -0.005), Vector2(0.052, 0.0), Vector2(0.045, 0.005), Vector2(0.038, 0.0), Vector2(0.045, -0.005)]), Vector3.ZERO, 16, metal)
		KitHardware.mount(leaf, knocker, "Knocker", Vector3(width * 0.5, height - 0.45, 0.0), CELL, LEAF_CELLS_DEEP)


static func _round_profile(radius: float, segments: int) -> PackedVector2Array:
	return KitPiece.arc(Vector2.ZERO, radius, 0.0, TAU * (segments - 1) / segments, segments - 1)


# --- Windows

## Window frame from y0 to y1 occupying z0..z1, with mullions and an optional transom.
static func window_frame(b: KitBuilder, o: KitOpening, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, frame: Material) -> void:
	b.box(Vector3(x0, y0, z0), Vector3(x0 + FRAME, y1, z1), frame)
	b.box(Vector3(x1 - FRAME, y0, z0), Vector3(x1, y1, z1), frame)
	b.box(Vector3(x0 + FRAME, y1 - FRAME, z0), Vector3(x1 - FRAME, y1, z1), frame)
	# The bottom rail is deeper and weathered so rain runs off outside.
	b.box(Vector3(x0 + FRAME, y0, z0), Vector3(x1 - FRAME, y0 + FRAME + 0.01, z1), frame)
	b.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.025, 0), Vector2(0, 0.012)]), Vector3(x0, y0 + FRAME + 0.01, z0), Vector3(x1, y0 + FRAME + 0.01, z0), Vector3.UP, frame, false)
	var layout := _window_layout(o, x0, x1, y0, y1)
	for mullion in layout["mullions"]:
		b.box(Vector3(mullion, y0 + FRAME + 0.01, z0), Vector3(mullion + FRAME, layout["casement_top"], z1), frame)
	if layout["transom"] > 0.0:
		b.box(Vector3(x0 + FRAME, layout["transom"], z0), Vector3(x1 - FRAME, layout["transom"] + FRAME, z1), frame)
	# Rebate lips the sashes close against (inside face of each light).
	var lip_z0 := z0 + CELL * SASH_CELLS_DEEP + 0.008
	for rect in layout["casements"] + layout["top_lights"]:
		var r: Rect2 = rect
		b.box(Vector3(r.position.x, r.position.y, lip_z0), Vector3(r.end.x, r.position.y + 0.012, lip_z0 + 0.012), frame)
		b.box(Vector3(r.position.x, r.end.y - 0.012, lip_z0), Vector3(r.end.x, r.end.y, lip_z0 + 0.012), frame)
		b.box(Vector3(r.position.x, r.position.y + 0.012, lip_z0), Vector3(r.position.x + 0.012, r.end.y - 0.012, lip_z0 + 0.012), frame)
		b.box(Vector3(r.end.x - 0.012, r.position.y + 0.012, lip_z0), Vector3(r.end.x, r.end.y - 0.012, lip_z0 + 0.012), frame)


## Clear openings (Rect2 in x, y) of every light; used by callers for layout.
static func window_lights(o: KitOpening, x0: float, x1: float, y0: float, y1: float) -> Array:
	var layout := _window_layout(o, x0, x1, y0, y1)
	return layout["casements"] + layout["top_lights"]


static func _window_layout(o: KitOpening, x0: float, x1: float, y0: float, y1: float) -> Dictionary:
	var count := clampi(o.panes, 1, 4)
	var inner_x0 := x0 + FRAME
	var inner_x1 := x1 - FRAME
	var bottom := y0 + FRAME + 0.01
	var top := y1 - FRAME
	var transom := -1.0
	if o.window_style == KitOpening.WindowStyle.CASEMENT_WITH_TOP_LIGHT and top - bottom > 0.9:
		transom = top - 0.32
	var casement_top := transom if transom > 0.0 else top
	var width := (inner_x1 - inner_x0 - (count - 1) * FRAME) / count
	var casements: Array = []
	var mullions: Array = []
	var top_lights: Array = []
	for i in count:
		var cx := inner_x0 + i * (width + FRAME)
		casements.append(Rect2(cx, bottom, width, casement_top - bottom))
		if i > 0:
			mullions.append(cx - FRAME)
		if transom > 0.0:
			top_lights.append(Rect2(cx, transom + FRAME, width, top - transom - FRAME))
	return {"casements": casements, "mullions": mullions, "transom": transom, "top_lights": top_lights, "casement_top": casement_top}


## Builds the casements (openable or fixed) and fixed top lights for a window.
static func window_sashes(o: KitOpening, x0: float, x1: float, y0: float, y1: float, z0: float) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	var layout := _window_layout(o, x0, x1, y0, y1)
	var casements: Array = layout["casements"]
	var count := casements.size()
	for i in count:
		var rect: Rect2 = casements[i]
		var opens := o.window_style != KitOpening.WindowStyle.FIXED and (count <= 2 or i == 0 or i == count - 1)
		var hinge_left := (i == 0) if count > 1 else o.hinge_left
		nodes.append(_casement(o, rect, z0, opens, hinge_left, "%s %d" % [o.display_name if not o.display_name.is_empty() else "Window", i + 1]))
	for rect in layout["top_lights"]:
		var r: Rect2 = rect
		var root := Node3D.new()
		root.name = "TopLight"
		var nx := floori((r.size.x - 0.004) / CELL)
		var ny := floori((r.size.y - 0.004) / CELL)
		var pane := _glass(root, "Glass", nx, ny, Vector3(r.position.x + (r.size.x - nx * CELL) * 0.5, r.position.y + (r.size.y - ny * CELL) * 0.5, z0 + CELL * 0.5))
		_attachment(root, "Attachment", "../" + pane.name, AABB(Vector3.ZERO, Vector3(nx * CELL, ny * CELL, CELL)), "", AABB())
		nodes.append(root)
	return nodes


static func _casement(o: KitOpening, rect: Rect2, z0: float, opens: bool, hinge_left: bool, title: String) -> Node3D:
	var nx := floori((rect.size.x - 0.004) / CELL)
	var ny := floori((rect.size.y - 0.004) / CELL)
	var origin := Vector3(rect.position.x + (rect.size.x - nx * CELL) * 0.5, rect.position.y + (rect.size.y - ny * CELL) * 0.5, z0)
	var color := o.frame_color
	var boxes: Array[VoxelFillBox] = []
	var rail := 2
	_vbox(boxes, Vector3i(0, 0, 0), Vector3i(rail, ny, SASH_CELLS_DEEP), color)
	_vbox(boxes, Vector3i(nx - rail, 0, 0), Vector3i(rail, ny, SASH_CELLS_DEEP), color)
	_vbox(boxes, Vector3i(rail, 0, 0), Vector3i(nx - rail * 2, rail + 1, SASH_CELLS_DEEP), color)
	_vbox(boxes, Vector3i(rail, ny - rail, 0), Vector3i(nx - rail * 2, rail, SASH_CELLS_DEEP), color)
	var glass_area := Rect2i(rail, rail + 1, nx - rail * 2, ny - rail * 2 - 1)
	if o.window_style == KitOpening.WindowStyle.GEORGIAN_BARS:
		_glazing_bars(boxes, glass_area, maxi(1, roundi(rect.size.x / 0.24)), maxi(1, roundi(rect.size.y / 0.3)), color, SASH_CELLS_DEEP)
	var root: Node3D
	if opens:
		# Casements open outward (towards -Z).
		root = _hinge_root(title, true, (1.0 if hinge_left else -1.0) * 80.0)
	else:
		root = Node3D.new()
	root.name = "Casement"
	var pivot := Vector3(origin.x if hinge_left else origin.x + nx * CELL, 0, origin.z)
	var sash := _voxel_leaf(root, "Leaf", boxes, origin, pivot if opens else Vector3.INF)
	var mount := AABB(Vector3(0 if hinge_left else (nx - rail) * CELL, 0, 0), Vector3(rail * CELL, ny * CELL, SASH_CELLS_DEEP * CELL))
	if not opens:
		mount = AABB(Vector3.ZERO, Vector3(nx * CELL, rail * CELL, SASH_CELLS_DEEP * CELL))
	_attachment(root, "Attachment", "../Leaf", mount, "", AABB(), opens)
	var pane := _glass(root, "Glass", glass_area.size.x, glass_area.size.y, origin + Vector3(glass_area.position.x * CELL, glass_area.position.y * CELL, CELL * 0.5))
	var support := AABB(Vector3((glass_area.position.x - 1) * CELL, (glass_area.position.y - 1) * CELL, 0), Vector3((glass_area.size.x + 2) * CELL, (glass_area.size.y + 2) * CELL, SASH_CELLS_DEEP * CELL))
	_attachment(root, "PaneAttachment", "../" + pane.name, AABB(), "../Leaf", support, opens)
	if opens:
		# A small lever handle on the inside face, on the opening side.
		var b := KitBuilder.new()
		var hx := (nx - 1.5) * CELL if hinge_left else 1.5 * CELL
		var face := SASH_CELLS_DEEP * CELL
		var metal := KitMaterials.metal(Color(0.75, 0.76, 0.78), 0.9)
		b.box(Vector3(hx - 0.008, ny * CELL * 0.5 - 0.03, face), Vector3(hx + 0.008, ny * CELL * 0.5 + 0.03, face + 0.006), metal, false)
		b.extrude(_round_profile(0.006, 8), Vector3(hx, ny * CELL * 0.5, face + 0.03), Vector3(hx, ny * CELL * 0.5 - 0.09, face + 0.03), Vector3.BACK, metal, false, true)
		KitHardware.mount(sash, b, "Handle", Vector3(hx, ny * CELL * 0.5, 0.0), CELL, SASH_CELLS_DEEP)
	return root


# --- Shared building blocks

static func _hinge_root(title: String, lockable: bool, open_angle: float) -> Node3D:
	var root := Node3D.new()
	root.set_script(BREAKABLE_HINGE)
	root.set(&"interaction_name", title)
	root.set(&"allow_lock", lockable)
	root.set(&"open_angle_degrees", open_angle)
	root.set(&"animation_duration", 0.5)
	return root


## Adds a voxel leaf (and the Hinge pivot node when `pivot` is finite) under `root`.
static func _voxel_leaf(root: Node3D, leaf_name: String, boxes: Array[VoxelFillBox], origin: Vector3, pivot: Vector3) -> VoxelBody:
	if pivot.is_finite():
		var hinge := Node3D.new()
		hinge.name = "Hinge"
		hinge.position = pivot
		root.add_child(hinge)
	var structure := VoxelStructureDefinition.new()
	structure.voxel_size = CELL
	structure.anchor_mode = VoxelStructureDefinition.AnchorMode.NONE
	structure.boxes = boxes
	var leaf := VoxelBody.new()
	leaf.name = leaf_name
	leaf.structure = structure
	leaf.position = origin
	root.add_child(leaf)
	return leaf


static func _glass(root: Node3D, glass_name: String, nx: int, ny: int, origin: Vector3) -> VoxelBody:
	var boxes: Array[VoxelFillBox] = []
	var box := VoxelFillBox.new()
	box.size = Vector3i(maxi(1, nx), maxi(1, ny), 1)
	box.material = _kit_glass()
	boxes.append(box)
	return _voxel_leaf(root, glass_name, boxes, origin, Vector3.INF)


static func _attachment(root: Node3D, attachment_name: String, body: String, mount: AABB, support: String, support_region: AABB, pivoted := true) -> void:
	var attachment := HouseFixtureAttachment.new()
	attachment.name = attachment_name
	attachment.body_path = NodePath(body)
	attachment.mount_region = mount
	attachment.support_region = support_region
	if not support.is_empty():
		attachment.support_path = NodePath(support)
	if pivoted and root.get_script() == BREAKABLE_HINGE:
		attachment.pivot_path = NodePath("../Hinge")
	root.add_child(attachment)


static func _kit_glass() -> VoxelMaterialDefinition:
	if _glass_material == null:
		_glass_material = GLASS.duplicate()
		_glass_material.rubble_fraction = 0.2
	return _glass_material


static func _painted_wood() -> VoxelMaterialDefinition:
	if _painted == null:
		_painted = WOOD.duplicate()
		_painted.display_name = "Painted timber"
		_painted.color_jitter = 0.012
		# Sturdier than raw timber: a blow knocks a hole rather than shattering the leaf.
		_painted.strength = 16.0
		_painted.rubble_fraction = 0.12
	return _painted


static func _vbox(boxes: Array[VoxelFillBox], min_cell: Vector3i, size: Vector3i, color: Color) -> void:
	if size.x <= 0 or size.y <= 0 or size.z <= 0:
		return
	var box := VoxelFillBox.new()
	box.min_cell = min_cell
	box.size = size
	box.material = _painted_wood()
	box.color_override = color
	boxes.append(box)
