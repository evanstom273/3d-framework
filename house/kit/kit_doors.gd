@tool
class_name KitDoors
extends RefCounted
## Builds the newer door, garage and gate styles on KitMechanism. Each style is a
## frame (static geometry into the wall's KitBuilder) plus leaves: fine voxel
## bodies fixed to movers, so they open, lock, get prised open and break.
## The original door styles stay on KitJoinery's breakable hinge.
##
## Coordinates are wall-local: the opening spans x0..x1, its bottom is at y0 and
## its head at `top`; the frame sits between z0 (outside) and z1 (inside).

const CELL := KitJoinery.CELL
const F := KitJoinery.FRAME
const STEEL_PATH := "res://furniture/materials/painted_steel.tres"

static var _steel: VoxelMaterialDefinition


## Builds the door and returns the nodes to add to the wall.
static func build(b: KitBuilder, o: KitOpening, x0: float, x1: float, y0: float, top: float, z0: float, z1: float, half: float, exterior: bool) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	var frame := KitMaterials.gloss(o.frame_color)
	var title := o.display_name if not o.display_name.is_empty() else _default_title(o)
	match o.door_style:
		KitOpening.DoorStyle.GLAZED_INTERIOR, KitOpening.DoorStyle.SOLID_TIMBER, KitOpening.DoorStyle.INDUSTRIAL_STEEL, KitOpening.DoorStyle.LABORATORY:
			KitJoinery.door_frame(b, o, x0, x1, top, z0, z1, frame)
			nodes.append(_hinged(o, title, x0 + F, x1 - F, y0, top - F, z0, z1, o.hinge_left, exterior))
		KitOpening.DoorStyle.STABLE:
			KitJoinery.door_frame(b, o, x0, x1, top, z0, z1, frame)
			nodes.append(_stable(o, title, x0 + F, x1 - F, y0, top - F, z0, z1, exterior))
		KitOpening.DoorStyle.DOUBLE, KitOpening.DoorStyle.FRENCH, KitOpening.DoorStyle.SHED_DOUBLE:
			_frame(b, x0, x1, top, z0, z1, frame, y0)
			nodes.append(_pair(o, title, x0 + F, x1 - F, y0, top - F, z0, z1, exterior))
		KitOpening.DoorStyle.SLIDING_PATIO:
			_frame(b, x0, x1, top, z0, z1, KitMaterials.gloss(o.frame_color), y0)
			nodes.append(_patio(o, title, x0 + F, x1 - F, y0 + 0.03, top - F, z0, z1))
		KitOpening.DoorStyle.POCKET:
			_lining(b, x0, x1, top, -half, half, frame, y0)
			nodes.append(_pocket(o, title, x0 + 0.02, x1 - 0.02, y0, top - 0.02))
		KitOpening.DoorStyle.BIFOLD:
			_frame(b, x0, x1, top, z0, z1, frame, y0)
			nodes.append(_bifold(o, title, x0 + F, x1 - F, y0, top - F, z0, z1))
		KitOpening.DoorStyle.BARN:
			_lining(b, x0, x1, top, -half, half, frame, y0)
			nodes.append(_barn(b, o, title, x0, x1, y0, top, half))
		KitOpening.DoorStyle.GARAGE_UP_AND_OVER:
			_frame(b, x0, x1, top, z0, z1, frame, y0)
			nodes.append(_up_and_over(o, title, x0 + F, x1 - F, y0, top - F, z0))
		KitOpening.DoorStyle.GARAGE_SECTIONAL:
			_frame(b, x0, x1, top, z0, z1, frame, y0)
			nodes.append(_sectional(b, o, title, x0 + F, x1 - F, y0, top - F, half + 0.005, false))
		KitOpening.DoorStyle.ROLLER_SHUTTER:
			_frame(b, x0, x1, top, z0 - 0.02, z0 + 0.05, KitMaterials.metal(Color(0.6, 0.62, 0.64), 0.6), y0)
			nodes.append(_sectional(b, o, title, x0 + F, x1 - F, y0, top - F, z0 + 0.01, true))
		KitOpening.DoorStyle.GATE_SLIDING:
			_posts(b, x0, x1, y0, top)
			nodes.append(_sliding_gate(b, o, title, x0, x1, y0, top, half))
		_:
			# Hinged gates, single or double.
			_posts(b, x0, x1, y0, top)
			if o.door_style == KitOpening.DoorStyle.GATE_DOUBLE_DRIVEWAY:
				nodes.append(_pair(o, title, x0 + 0.02, x1 - 0.02, y0 + 0.04, top, -0.03, 0.03, true))
			else:
				nodes.append(_hinged(o, title, x0 + 0.02, x1 - 0.02, y0 + 0.04, top, -0.03, 0.03, o.hinge_left, true))
	return nodes


static func _default_title(o: KitOpening) -> String:
	if o.is_gate():
		return "Gate"
	match o.door_style:
		KitOpening.DoorStyle.GARAGE_UP_AND_OVER, KitOpening.DoorStyle.GARAGE_SECTIONAL:
			return "Garage door"
		KitOpening.DoorStyle.ROLLER_SHUTTER:
			return "Roller shutter"
		KitOpening.DoorStyle.SHED_DOUBLE:
			return "Shed doors"
		KitOpening.DoorStyle.SLIDING_PATIO:
			return "Patio door"
	return "Door"


# --- Frames

## Jambs and head (no stops): for pairs, sliders, folding and garage doors.
static func _frame(b: KitBuilder, x0: float, x1: float, top: float, z0: float, z1: float, material: Material, y0 := 0.0) -> void:
	b.box(Vector3(x0, y0, z0), Vector3(x0 + F, top, z1), material)
	b.box(Vector3(x1 - F, y0, z0), Vector3(x1, top, z1), material)
	b.box(Vector3(x0 + F, top - F, z0), Vector3(x1 - F, top, z1), material)


## Lining boards across the full wall thickness, for doors that slide past the wall.
static func _lining(b: KitBuilder, x0: float, x1: float, top: float, z0: float, z1: float, material: Material, y0 := 0.0) -> void:
	b.box(Vector3(x0, y0, z0), Vector3(x0 + 0.02, top, z1), material)
	b.box(Vector3(x1 - 0.02, y0, z0), Vector3(x1, top, z1), material)
	b.box(Vector3(x0 + 0.02, top - 0.02, z0), Vector3(x1 - 0.02, top, z1), material)


## Gate posts either side of the opening, with ball caps.
static func _posts(b: KitBuilder, x0: float, x1: float, y0: float, top: float) -> void:
	var timber := KitMaterials.timber(Color(0.45, 0.34, 0.22))
	# Just outside the opening, so the leaf swings clear of them.
	for x in [x0 - 0.1, x1]:
		b.bevel_box(Vector3(x, y0 - 0.05, -0.05), Vector3(x + 0.1, top + 0.1, 0.05), 0.01, timber)
		b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.045, 0.03), Vector2(0.03, 0.06), Vector2(0.0, 0.07)]), Vector3(x + 0.05, top + 0.1, 0.0), 10, timber)


# --- Leaves

## A leaf's cells for a style: boxes (material, colour) and glazed areas (cell rects).
static func _leaf(o: KitOpening, nx: int, ny: int, boxes: Array[VoxelFillBox], glass: Array[Rect2i], deep: int) -> void:
	var color := o.door_color
	match o.door_style:
		KitOpening.DoorStyle.GLAZED_INTERIOR:
			# Three glazed panels stacked in a timber frame.
			_box(boxes, Vector3i(0, 0, 0), Vector3i(5, ny, deep), color)
			_box(boxes, Vector3i(nx - 5, 0, 0), Vector3i(5, ny, deep), color)
			_box(boxes, Vector3i(5, 0, 0), Vector3i(nx - 10, 8, deep), color)
			_box(boxes, Vector3i(5, ny - 5, 0), Vector3i(nx - 10, 5, deep), color)
			var span := (ny - 13 - 8) / 3
			for i in 3:
				var y := 8 + i * (span + 4)
				if i > 0:
					_box(boxes, Vector3i(5, y - 4, 0), Vector3i(nx - 10, 4, deep), color)
				glass.append(Rect2i(5, y, nx - 10, span))
		KitOpening.DoorStyle.SOLID_TIMBER, KitOpening.DoorStyle.GATE_SOLID:
			# Heavy oak boards with a rail-and-stile frame, studded.
			for x in range(0, nx, 5):
				_box(boxes, Vector3i(x, 0, 0), Vector3i(mini(4, nx - x), ny, deep), color.darkened(0.03 * ((x / 5) % 3)))
				if x + 4 < nx:
					_box(boxes, Vector3i(x + 4, 0, 1), Vector3i(1, ny, deep - 1), color.darkened(0.2))
			for y in [ny / 5, ny * 4 / 5]:
				for x in range(2, nx - 2, 5):
					_box(boxes, Vector3i(x, y, 0), Vector3i(1, 1, 1), Color(0.1, 0.1, 0.1))
		KitOpening.DoorStyle.INDUSTRIAL_STEEL:
			_steel_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, ny, deep), color)
			# Vision panel high up, kick plate low down.
			glass.append(Rect2i(nx / 2 - 4, ny - 30, 8, 18))
			_cut(boxes, Rect2i(nx / 2 - 4, ny - 30, 8, 18))
			_steel_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, 10, 1), Color(0.6, 0.62, 0.64))
		KitOpening.DoorStyle.LABORATORY:
			_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, ny, deep), color)
			glass.append(Rect2i(6, ny - 40, nx - 12, 26))
			_cut(boxes, Rect2i(6, ny - 40, nx - 12, 26))
			_steel_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, 9, 1), Color(0.72, 0.73, 0.75))
			_box(boxes, Vector3i(nx / 2 - 5, ny - 50, 0), Vector3i(10, 6, 1), Color(0.95, 0.75, 0.1))
		KitOpening.DoorStyle.FRENCH:
			_box(boxes, Vector3i(0, 0, 0), Vector3i(4, ny, deep), color)
			_box(boxes, Vector3i(nx - 4, 0, 0), Vector3i(4, ny, deep), color)
			_box(boxes, Vector3i(4, 0, 0), Vector3i(nx - 8, 9, deep), color)
			_box(boxes, Vector3i(4, ny - 4, 0), Vector3i(nx - 8, 4, deep), color)
			var area := Rect2i(4, 9, nx - 8, ny - 13)
			glass.append(area)
			KitJoinery._glazing_bars(boxes, area, 2, 5, color, deep)
		KitOpening.DoorStyle.SHED_DOUBLE, KitOpening.DoorStyle.GATE_TIMBER, KitOpening.DoorStyle.STABLE:
			# Ledged and braced boards.
			_box(boxes, Vector3i(0, 0, 1), Vector3i(nx, ny, 1), color)
			for x in range(0, nx, 5):
				_box(boxes, Vector3i(x, 0, 0), Vector3i(mini(4, nx - x), ny, 1), color)
			var ledges := [3, ny / 2 - 2, ny - 8]
			for y in ledges:
				_box(boxes, Vector3i(1, y, 2), Vector3i(nx - 2, 5, 1), color.darkened(0.06))
			for k in 2:
				var a: int = ledges[k] + 5
				var c: int = ledges[k + 1]
				for y in range(a, c):
					var t := float(y - a) / maxf(1.0, c - a - 1)
					_box(boxes, Vector3i(roundi(lerpf(2, nx - 6, t)), y, 2), Vector3i(4, 1, 1), color.darkened(0.06))
		KitOpening.DoorStyle.GATE_PICKET:
			# Pointed pickets with gaps, on two rails.
			for y in [6, ny - 12]:
				_box(boxes, Vector3i(0, y, 1), Vector3i(nx, 4, 1), color)
			for x in range(0, nx - 2, 5):
				_box(boxes, Vector3i(x, 0, 0), Vector3i(3, ny - 3, 1), color)
				_box(boxes, Vector3i(x + 1, ny - 3, 0), Vector3i(1, 3, 1), color)
		KitOpening.DoorStyle.GATE_METAL, KitOpening.DoorStyle.GATE_DOUBLE_DRIVEWAY:
			var iron := Color(0.08, 0.08, 0.09) if o.door_style == KitOpening.DoorStyle.GATE_METAL else color
			var metal := o.door_style == KitOpening.DoorStyle.GATE_METAL
			for y in [2, ny - 6]:
				_mat_box(boxes, Vector3i(0, y, 0), Vector3i(nx, 3, 2), iron, metal)
			_mat_box(boxes, Vector3i(0, 0, 0), Vector3i(2, ny, 2), iron, metal)
			_mat_box(boxes, Vector3i(nx - 2, 0, 0), Vector3i(2, ny, 2), iron, metal)
			for x in range(5, nx - 3, 5):
				_mat_box(boxes, Vector3i(x, 2, 0), Vector3i(1 if metal else 3, ny - 3, 1 if metal else 2), iron, metal)
				if metal:
					_mat_box(boxes, Vector3i(x - 1, ny - 2, 0), Vector3i(3, 2, 2), iron, true)
		KitOpening.DoorStyle.GATE_CHAIN_LINK:
			var galv := Color(0.62, 0.64, 0.66)
			_steel_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, 2, 2), galv)
			_steel_box(boxes, Vector3i(0, ny - 2, 0), Vector3i(nx, 2, 2), galv)
			_steel_box(boxes, Vector3i(0, 0, 0), Vector3i(2, ny, 2), galv)
			_steel_box(boxes, Vector3i(nx - 2, 0, 0), Vector3i(2, ny, 2), galv)
			# Diamond mesh: diagonal lines both ways.
			for y in range(2, ny - 2):
				for x in range(2, nx - 2):
					if (x + y) % 4 == 0 or (x - y + 400) % 4 == 0:
						_steel_box(boxes, Vector3i(x, y, 1), Vector3i(1, 1, 1), galv)
		_:
			_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, ny, deep), color)


static func _box(boxes: Array[VoxelFillBox], at: Vector3i, size: Vector3i, color: Color) -> void:
	KitJoinery._vbox(boxes, at, size, color)


static func _steel_box(boxes: Array[VoxelFillBox], at: Vector3i, size: Vector3i, color: Color) -> void:
	_mat_box(boxes, at, size, color, true)


static func _mat_box(boxes: Array[VoxelFillBox], at: Vector3i, size: Vector3i, color: Color, steel: bool) -> void:
	if size.x <= 0 or size.y <= 0 or size.z <= 0:
		return
	if not steel:
		KitJoinery._vbox(boxes, at, size, color)
		return
	var box := VoxelFillBox.new()
	box.min_cell = at
	box.size = size
	box.material = steel_material()
	box.color_override = color
	boxes.append(box)


## Removes cells in a rectangle (all depths) from boxes already added, by
## splitting them: used for vision panels.
static func _cut(boxes: Array[VoxelFillBox], hole: Rect2i) -> void:
	var kept: Array[VoxelFillBox] = []
	for box in boxes:
		var r := Rect2i(box.min_cell.x, box.min_cell.y, box.size.x, box.size.y)
		if not r.intersects(hole):
			kept.append(box)
			continue
		# Up to four pieces round the hole.
		var pieces := [Rect2i(r.position.x, r.position.y, r.size.x, hole.position.y - r.position.y),
			Rect2i(r.position.x, hole.end.y, r.size.x, r.end.y - hole.end.y),
			Rect2i(r.position.x, maxi(r.position.y, hole.position.y), hole.position.x - r.position.x, mini(r.end.y, hole.end.y) - maxi(r.position.y, hole.position.y)),
			Rect2i(hole.end.x, maxi(r.position.y, hole.position.y), r.end.x - hole.end.x, mini(r.end.y, hole.end.y) - maxi(r.position.y, hole.position.y))]
		for p: Rect2i in pieces:
			var clipped: Rect2i = p.intersection(r)
			if clipped.size.x <= 0 or clipped.size.y <= 0:
				continue
			var copy := VoxelFillBox.new()
			copy.min_cell = Vector3i(clipped.position.x, clipped.position.y, box.min_cell.z)
			copy.size = Vector3i(clipped.size.x, clipped.size.y, box.size.z)
			copy.material = box.material
			copy.color_override = box.color_override
			kept.append(copy)
	boxes.assign(kept)


static func steel_material() -> VoxelMaterialDefinition:
	if _steel == null:
		_steel = load(STEEL_PATH) if ResourceLoader.exists(STEEL_PATH) else KitJoinery._painted_wood()
	return _steel


## A leaf of the opening's style as a voxel body under `root`, its cell (0,0,0)
## at `origin`, fixed to `mover` along `strip` (leaf-local), with any glazing.
static func _make_leaf(root: Node3D, o: KitOpening, leaf_name: String, nx: int, ny: int, deep: int, origin: Vector3, mover_path: String, strip: AABB) -> VoxelBody:
	var boxes: Array[VoxelFillBox] = []
	var glass: Array[Rect2i] = []
	_leaf(o, nx, ny, boxes, glass, deep)
	var leaf := KitJoinery._voxel_leaf(root, leaf_name, boxes, origin, Vector3.INF)
	_attach(root, leaf_name + "Attachment", "../" + leaf_name, strip, "", AABB(), mover_path)
	for i in glass.size():
		var g := glass[i]
		var cells: Array[Vector2i] = []
		for y in g.size.y:
			for x in g.size.x:
				cells.append(Vector2i(x, y))
		var pane := KitWindows._glass_body(root, cells, origin + Vector3(g.position.x * CELL, g.position.y * CELL, CELL * (deep - 1) * 0.5), KitWindows.glass_material(o))
		if pane != null:
			pane.name = "%sGlass%d" % [leaf_name, i]
			var support := AABB(Vector3((g.position.x - 1) * CELL, (g.position.y - 1) * CELL, 0), Vector3((g.size.x + 2) * CELL, (g.size.y + 2) * CELL, deep * CELL))
			_attach(root, "%sPane%d" % [leaf_name, i], "../" + pane.name, AABB(), "../" + leaf_name, support, mover_path)
	return leaf


static func _attach(root: Node3D, attachment_name: String, body: String, mount: AABB, support: String, support_region: AABB, mover_path: String) -> void:
	var attachment := HouseFixtureAttachment.new()
	attachment.name = attachment_name
	attachment.body_path = NodePath(body)
	attachment.mount_region = mount
	attachment.support_region = support_region
	if not support.is_empty():
		attachment.support_path = NodePath(support)
	if not mover_path.is_empty():
		attachment.pivot_path = NodePath("../" + mover_path)
	root.add_child(attachment)


static func _mechanism(o: KitOpening, title: String, duration := 0.6) -> KitMechanism:
	var m := KitMechanism.new()
	m.name = "Door"
	# Doors, gates and garage doors: NPCs may open these (not windows).
	m.set_meta(&"door", true)
	m.interaction_name = title
	m.lockable = o.lockable
	m.duration = duration if not o.powered else duration * 2.5
	m.powered = o.powered
	return m


static func _mover_node(parent: Node3D, mover_name: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = mover_name
	node.position = at
	parent.add_child(node)
	return node


## Swing angle with sign: leaves open into the building unless set otherwise.
static func _swing(o: KitOpening, hinge_left: bool) -> float:
	var angle := o.max_open_angle if o.max_open_angle > 0.0 else 95.0
	return (-1.0 if hinge_left else 1.0) * (1.0 if o.opens_inward else -1.0) * angle


# --- Styles

static func _hinged(o: KitOpening, title: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, hinge_left: bool, exterior: bool) -> KitMechanism:
	var m := _mechanism(o, title)
	var deep := 3
	var thickness := deep * CELL
	var nx := floori((x1 - x0 - 0.006) / CELL)
	var ny := floori((y1 - y0 - 0.012) / CELL)
	var lx := x0 + ((x1 - x0) - nx * CELL) * 0.5
	var lz := z1 - thickness if o.opens_inward else z0
	var pivot := Vector3(lx if hinge_left else lx + nx * CELL, y0, lz + thickness if o.opens_inward else lz)
	var mover := _mover_node(m, "Mover", pivot)
	m.add_mover(mover, m.add_group(""), {"open": [Transform3D(Basis.IDENTITY, pivot), KitMechanism.turned(Vector3.UP, _swing(o, hinge_left), pivot)]})
	var strip := AABB(Vector3(0.0 if hinge_left else (nx - 4) * CELL, 0, 0), Vector3(4 * CELL, ny * CELL, thickness))
	var leaf := _make_leaf(m, o, "Leaf", nx, ny, deep, Vector3(lx, y0 + 0.006, lz), "Mover", strip)
	_hardware(o, leaf, nx * CELL, ny * CELL, thickness, hinge_left, exterior)
	return m


static func _stable(o: KitOpening, title: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, exterior: bool) -> KitMechanism:
	var m := _mechanism(o, title)
	var deep := 3
	var thickness := deep * CELL
	var nx := floori((x1 - x0 - 0.006) / CELL)
	var split := y0 + 1.05
	var lx := x0 + ((x1 - x0) - nx * CELL) * 0.5
	var lz := z1 - thickness if o.opens_inward else z0
	var hinge_left := o.hinge_left
	for half in 2:
		var bottom := y0 + 0.006 if half == 0 else split + 0.004
		var height := (split - 0.004 - bottom) if half == 0 else (y1 - 0.006 - bottom)
		var ny := floori(height / CELL)
		var pivot := Vector3(lx if hinge_left else lx + nx * CELL, bottom, lz + thickness if o.opens_inward else lz)
		var mover := _mover_node(m, "Mover%d" % half, pivot)
		var group := m.add_group("lower half" if half == 0 else "upper half")
		m.add_mover(mover, group, {"open": [Transform3D(Basis.IDENTITY, pivot), KitMechanism.turned(Vector3.UP, _swing(o, hinge_left), pivot)]})
		var strip := AABB(Vector3(0.0 if hinge_left else (nx - 4) * CELL, 0, 0), Vector3(4 * CELL, ny * CELL, thickness))
		var leaf := _make_leaf(m, o, "Leaf%d" % half, nx, ny, deep, Vector3(lx, bottom, lz), "Mover%d" % half, strip)
		if half == 0:
			_hardware(o, leaf, nx * CELL, ny * CELL, thickness, hinge_left, exterior)
	return m


## Two leaves meeting in the middle, opening together.
static func _pair(o: KitOpening, title: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, exterior: bool) -> KitMechanism:
	var m := _mechanism(o, title)
	var group := m.add_group("")
	var gate := o.is_gate()
	var deep := 2 if gate else 3
	var thickness := deep * CELL
	var leaf_w := (x1 - x0 - 0.01) * 0.5
	var nx := floori(leaf_w / CELL)
	var ny := floori((y1 - y0 - 0.012) / CELL)
	var lz := z1 - thickness if o.opens_inward else z0
	for side in 2:
		var left := side == 0
		var lx := x0 + 0.002 if left else x1 - 0.002 - nx * CELL
		var pivot := Vector3(lx if left else lx + nx * CELL, y0, lz + thickness if o.opens_inward else lz)
		var mover := _mover_node(m, "Mover%d" % side, pivot)
		m.add_mover(mover, group, {"open": [Transform3D(Basis.IDENTITY, pivot), KitMechanism.turned(Vector3.UP, _swing(o, left), pivot)]})
		var strip := AABB(Vector3(0.0 if left else (nx - 4) * CELL, 0, 0), Vector3(4 * CELL, ny * CELL, thickness))
		var leaf := _make_leaf(m, o, "Leaf%d" % side, nx, ny, deep, Vector3(lx, y0 + 0.006, lz), "Mover%d" % side, strip)
		if not left:
			_hardware(o, leaf, nx * CELL, ny * CELL, thickness, false, exterior)
	return m


## Sliding patio door: a fixed glazed panel and a sliding one behind it.
static func _patio(o: KitOpening, title: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> KitMechanism:
	var m := _mechanism(o, title, 0.9)
	var glazed := o.duplicate() as KitOpening
	glazed.door_style = KitOpening.DoorStyle.FRENCH
	glazed.door_color = o.frame_color
	var deep := 2
	var thickness := deep * CELL
	var panel_w := (x1 - x0) * 0.5 + 0.03
	var nx := floori(panel_w / CELL)
	var ny := floori((y1 - y0 - 0.01) / CELL)
	var fixed_left := not o.hinge_left
	# Fixed panel in the outer track, sliding panel in the inner track.
	var fixed_x := x0 if fixed_left else x1 - nx * CELL
	var slide_x := x1 - nx * CELL if fixed_left else x0
	var fixed := _mover_node(m, "Fixed", Vector3.ZERO)
	_make_leaf(m, _clear_glazed(glazed), "FixedLeaf", nx, ny, deep, Vector3(fixed_x, y0, z0 + 0.01), "Fixed", AABB(Vector3.ZERO, Vector3(nx * CELL, ny * CELL, thickness)))
	var mover := _mover_node(m, "Mover", Vector3.ZERO)
	var travel := (fixed_x - slide_x) * 0.96
	m.add_mover(mover, m.add_group(""), {"open": [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(travel, 0.0, 0.0))]})
	m.add_mover(fixed, 0, {"open": [Transform3D.IDENTITY]})
	var leaf := _make_leaf(m, _clear_glazed(glazed), "Leaf", nx, ny, deep, Vector3(slide_x, y0, z0 + 0.01 + thickness + 0.01), "Mover", AABB(Vector3.ZERO, Vector3(nx * CELL, 3 * CELL, thickness)))
	_hardware(o, leaf, nx * CELL, ny * CELL, thickness, not fixed_left, true, true)
	return m


## A full-height glazed panel: the patio door's leaves.
static func _clear_glazed(o: KitOpening) -> KitOpening:
	var copy := o.duplicate() as KitOpening
	copy.door_style = KitOpening.DoorStyle.FRENCH
	return copy


## Pocket door: slides sideways into the wall.
static func _pocket(o: KitOpening, title: String, x0: float, x1: float, y0: float, y1: float) -> KitMechanism:
	var m := _mechanism(o, title, 0.8)
	var deep := 2
	var thickness := deep * CELL
	var nx := floori((x1 - x0) / CELL)
	var ny := floori((y1 - y0 - 0.01) / CELL)
	var mover := _mover_node(m, "Mover", Vector3.ZERO)
	var into := -(nx * CELL - 0.08) if o.hinge_left else (nx * CELL - 0.08)
	m.add_mover(mover, m.add_group(""), {"open": [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(into, 0.0, 0.0))]})
	var leaf := _make_leaf(m, o, "Leaf", nx, ny, deep, Vector3(x0, y0 + 0.005, -thickness * 0.5), "Mover", AABB(Vector3.ZERO, Vector3(nx * CELL, 3 * CELL, thickness)))
	# A flush finger pull on the leading edge.
	var b := KitBuilder.new()
	var edge := nx * CELL - 0.04 if o.hinge_left else 0.04
	for face in [-0.002, thickness]:
		b.box(Vector3(edge - 0.015, ny * CELL * 0.48, face), Vector3(edge + 0.015, ny * CELL * 0.48 + 0.08, face + 0.002), KitMaterials.metal(Color(0.75, 0.76, 0.78), 0.9), false)
	KitHardware.mount(leaf, b, "Pull", Vector3(edge, ny * CELL * 0.5, 0.0), CELL, deep)
	return m


## Bi-fold: a chain of leaves folding against each other toward one side.
static func _bifold(o: KitOpening, title: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> KitMechanism:
	var m := _mechanism(o, title, 0.9)
	var group := m.add_group("")
	var count := clampi(roundi((x1 - x0) / 0.5), 2, 6)
	var deep := 2
	var thickness := deep * CELL
	var leaf_w := (x1 - x0 - 0.006) / count
	var nx := floori(leaf_w / CELL)
	var ny := floori((y1 - y0 - 0.012) / CELL)
	var lz := z1 - thickness if o.opens_inward else z0
	var angle := (o.max_open_angle if o.max_open_angle > 0.0 else 84.0) * (1.0 if o.opens_inward else -1.0)
	var parent: Node3D = m
	var path := ""
	for i in count:
		# Each mover sits at the hinge between leaf i-1 and leaf i.
		var at := Vector3(x0 + 0.003, y0, lz + (thickness if o.opens_inward else 0.0)) if i == 0 else Vector3(nx * CELL, 0.0, 0.0)
		var mover := _mover_node(parent, "Fold%d" % i, at)
		path = "Fold%d" % i if i == 0 else path + "/Fold%d" % i
		var turn := -angle if i == 0 else (2.0 * angle if i % 2 == 1 else -2.0 * angle)
		m.add_mover(mover, group, {"open": [Transform3D(Basis.IDENTITY, at), KitMechanism.turned(Vector3.UP, turn, at)]})
		var origin := Vector3(x0 + 0.003 + i * nx * CELL, y0 + 0.006, lz)
		var strip := AABB(Vector3.ZERO, Vector3(3 * CELL, ny * CELL, thickness))
		var glazed := o.duplicate() as KitOpening
		glazed.door_style = KitOpening.DoorStyle.FRENCH
		_make_leaf(m, glazed, "Leaf%d" % i, nx, ny, deep, origin, path, strip)
		parent = mover
	return m


## Barn door: hangs from a track on the inside face and slides along the wall.
static func _barn(b: KitBuilder, o: KitOpening, title: String, x0: float, x1: float, y0: float, top: float, half: float) -> KitMechanism:
	var m := _mechanism(o, title, 1.0)
	var iron := KitMaterials.metal(Color(0.08, 0.08, 0.09), 0.5)
	var w := x1 - x0 + 0.1
	var dir := -1.0 if o.hinge_left else 1.0
	var face := half + 0.012
	# Track rail across the opening and past it on the side the door slides to.
	var rail_x0 := minf(x0 - 0.05, x0 - 0.05 + dir * w)
	var rail_x1 := maxf(x1 + 0.05, x1 + 0.05 + dir * w)
	b.box(Vector3(rail_x0, top + 0.12, half), Vector3(rail_x1, top + 0.17, half + 0.012), iron)
	b.box(Vector3(rail_x0, top + 0.14, half + 0.012), Vector3(rail_x1, top + 0.15, face + 0.06), iron)
	var deep := 2
	var thickness := deep * CELL
	var nx := floori(w / CELL)
	var ny := floori((top + 0.08 - y0) / CELL)
	var mover := _mover_node(m, "Mover", Vector3.ZERO)
	m.add_mover(mover, m.add_group(""), {"open": [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(dir * (w - 0.1), 0.0, 0.0))]})
	var plank := o.duplicate() as KitOpening
	plank.door_style = KitOpening.DoorStyle.SHED_DOUBLE
	var leaf := _make_leaf(m, plank, "Leaf", nx, ny, deep, Vector3(x0 - 0.05, y0 + 0.01, face), "Mover", AABB(Vector3(0, (ny - 3) * CELL, 0), Vector3(nx * CELL, 3 * CELL, thickness)))
	# Strap hangers with wheels on the rail, and a pull.
	var hw := KitBuilder.new()
	for x in [0.12, nx * CELL - 0.12]:
		hw.box(Vector3(x - 0.02, ny * CELL - 0.3, thickness), Vector3(x + 0.02, ny * CELL + 0.06, thickness + 0.008), iron, false)
		hw.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.04, 0.02), Vector2(0.0, 0.02)]), Vector3(x, ny * CELL + 0.06, thickness + 0.02), 12, iron)
	KitHardware.mount(leaf, hw, "Hangers", Vector3(nx * CELL * 0.5, ny * CELL - 0.1, 0.0), CELL, deep, 0.4)
	var pull := KitBuilder.new()
	var px := 0.1 if o.hinge_left else nx * CELL - 0.1
	pull.extrude(KitJoinery._round_profile(0.01, 8), Vector3(px, 0.85, thickness + 0.05), Vector3(px, 1.15, thickness + 0.05), Vector3.BACK, iron, false, true)
	KitHardware.mount(leaf, pull, "Pull", Vector3(px, 1.0, 0.0), CELL, deep)
	return m


## Up-and-over garage door: swings out at the bottom and up under the ceiling.
static func _up_and_over(o: KitOpening, title: String, x0: float, x1: float, y0: float, y1: float, z0: float) -> KitMechanism:
	var m := _mechanism(o, title, 1.4)
	m.lockable = o.lockable
	var deep := 2
	var thickness := deep * CELL
	var nx := floori((x1 - x0 - 0.01) / CELL)
	var ny := floori((y1 - y0 - 0.01) / CELL)
	var h := ny * CELL
	var pivot := Vector3(x0 + 0.005, y1 - 0.005, z0 + 0.02)
	var mover := _mover_node(m, "Mover", pivot)
	# Keyframes: closed (hanging), swung out and up, and level inside.
	m.add_mover(mover, m.add_group(""), {"open": [
		Transform3D(Basis.IDENTITY, pivot),
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-40.0)), pivot + Vector3(0.0, -h * 0.2, 0.12)),
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), pivot + Vector3(0.0, 0.05, 0.15)),
	]})
	var boxes: Array[VoxelFillBox] = []
	# Vertical pressed ribs across a steel panel.
	_steel_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, ny, 1), o.door_color)
	for x in range(3, nx - 2, 6):
		_steel_box(boxes, Vector3i(x, 2, 1), Vector3i(2, ny - 4, 1), o.door_color.darkened(0.08))
	var leaf := KitJoinery._voxel_leaf(m, "Leaf", boxes, Vector3(x0 + 0.005, y0 + 0.005, z0 + 0.02 - thickness), Vector3.INF)
	_attach(m, "LeafAttachment", "../Leaf", AABB(Vector3(0, (ny - 4) * CELL, 0), Vector3(nx * CELL, 4 * CELL, thickness)), "", AABB(), "Mover")
	var handle := KitBuilder.new()
	handle.box(Vector3(nx * CELL * 0.5 - 0.08, 0.15, -0.02), Vector3(nx * CELL * 0.5 + 0.08, 0.19, 0.0), KitMaterials.metal(Color(0.75, 0.76, 0.78), 0.9), false)
	KitHardware.mount(leaf, handle, "Handle", Vector3(nx * CELL * 0.5, 0.17, 0.0), CELL, deep)
	return m


## Sectional garage door (panels run up a curved track and level inside) or a
## roller shutter (slats wind round a drum in the head).
static func _sectional(b: KitBuilder, o: KitOpening, title: String, x0: float, x1: float, y0: float, y1: float, z: float, roll: bool) -> KitMechanism:
	var m := _mechanism(o, title, 2.4 if roll else 2.0)
	m.powered = true
	var group := m.add_group("", {"open": "Raise"})
	var height := y1 - y0
	var count := clampi(roundi(height / (0.15 if roll else 0.52)), 3, 20)
	var section := height / count
	var nx := floori((x1 - x0 - 0.01) / CELL)
	var ny := maxi(1, floori((section - 0.004) / CELL))
	var radius := 0.16 if roll else 0.32
	var track := _mover_node(m, "Track", Vector3(x0 + 0.005, y0, z))
	var metal := KitMaterials.metal(Color(0.55, 0.57, 0.6), 0.6)
	if not roll:
		# Track rails: up the jambs, round the curve and on into the garage.
		for x in [x0 - 0.03, x1 - 0.01]:
			b.box(Vector3(x, y0, z), Vector3(x + 0.04, y1, z + 0.04), metal)
			b.box(Vector3(x, y1 + radius - 0.02, z + radius), Vector3(x + 0.04, y1 + radius + 0.02, z + radius + height + 0.2), metal)
	else:
		# Shutter box on the outside face: the slats run up inside the wall above
		# the head, then wind onto a drum in here.
		b.box(Vector3(x0 - 0.06, y1 - 0.02, z - radius * 2.0 - 0.1), Vector3(x1 + 0.06, y1 + radius * 2.0 + 0.1, z + 0.04), metal)
	for i in count:
		var start := i * section
		var track_top := height + radius if roll else height
		var poses := KitMechanism.track_poses(start, track_top + (0.4 if roll else 0.0), track_top, radius, roll, 18 if roll else 10)
		var mover := _mover_node(track, "Section%d" % i, Vector3(0.0, start, 0.0))
		m.add_mover(mover, group, {"open": poses})
		var boxes: Array[VoxelFillBox] = []
		if roll:
			_steel_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, ny, 1), o.door_color)
			_steel_box(boxes, Vector3i(0, ny - 1, 0), Vector3i(nx, 1, 1), o.door_color.darkened(0.15))
		else:
			_steel_box(boxes, Vector3i(0, 0, 0), Vector3i(nx, ny, 1), o.door_color)
			# Two horizontal ribs per panel.
			for y in [ny / 3, ny * 2 / 3]:
				_steel_box(boxes, Vector3i(1, y, 1), Vector3i(nx - 2, 1, 1), o.door_color.darkened(0.1))
		var leaf_name := "Leaf%d" % i
		KitJoinery._voxel_leaf(m, leaf_name, boxes, Vector3(x0 + 0.005, y0 + start, z), Vector3.INF)
		_attach(m, leaf_name + "Attachment", "../" + leaf_name, AABB(Vector3.ZERO, Vector3(nx * CELL, ny * CELL, CELL)), "", AABB(), "Track/Section%d" % i)
	return m


## Sliding driveway gate: runs along the wall on wheels.
static func _sliding_gate(b: KitBuilder, o: KitOpening, title: String, x0: float, x1: float, y0: float, top: float, half: float) -> KitMechanism:
	var m := _mechanism(o, title, 1.6)
	var dir := -1.0 if o.hinge_left else 1.0
	var w := x1 - x0
	var nx := floori(w / CELL)
	var ny := floori((top - y0 - 0.06) / CELL)
	# A ground rail the gate runs along.
	b.box(Vector3(minf(x0, x0 + dir * w), y0 - 0.01, -half - 0.08), Vector3(maxf(x1, x1 + dir * w), y0 + 0.01, -half - 0.04), KitMaterials.metal(Color(0.4, 0.4, 0.42), 0.6))
	var mover := _mover_node(m, "Mover", Vector3.ZERO)
	m.add_mover(mover, m.add_group(""), {"open": [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, Vector3(dir * w, 0.0, 0.0))]})
	var metal := o.duplicate() as KitOpening
	metal.door_style = KitOpening.DoorStyle.GATE_METAL
	_make_leaf(m, metal, "Leaf", nx, ny, 2, Vector3(x0, y0 + 0.05, -half - 0.08), "Mover", AABB(Vector3.ZERO, Vector3(nx * CELL, 4 * CELL, 2 * CELL)))
	return m


# --- Hardware

static func _hardware(o: KitOpening, leaf: VoxelBody, width: float, height: float, thickness: float, hinge_left: bool, exterior: bool, pull_bar := false) -> void:
	if o.handle == KitOpening.Handle.NONE:
		return
	var metal := KitMaterials.metal(Color(0.76, 0.6, 0.3), 0.85) if exterior else KitMaterials.metal(Color(0.75, 0.76, 0.78), 0.9)
	var lock_x := width - 0.07 if hinge_left else 0.07
	var y := clampf(1.0, 0.3, height - 0.2)
	var b := KitBuilder.new()
	if pull_bar or o.handle == KitOpening.Handle.PULL_BAR or o.door_style in [KitOpening.DoorStyle.INDUSTRIAL_STEEL, KitOpening.DoorStyle.LABORATORY]:
		for face in [-0.05, thickness + 0.05]:
			b.extrude(KitJoinery._round_profile(0.012, 10), Vector3(lock_x, y - 0.3, face), Vector3(lock_x, y + 0.3, face), Vector3.BACK, metal, false, true)
			for end in [y - 0.28, y + 0.28]:
				b.box(Vector3(lock_x - 0.008, end - 0.01, minf(face, 0.0 if face < 0.0 else thickness)), Vector3(lock_x + 0.008, end + 0.01, maxf(face, 0.0 if face < 0.0 else thickness)), metal, false)
	else:
		for side in [-1.0, 1.0]:
			var face := 0.0 if side < 0.0 else thickness
			b.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5 * side), Vector3(lock_x, y, face))
			if o.handle == KitOpening.Handle.KNOB:
				b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.03, 0.006), Vector2(0.008, 0.012), Vector2(0.008, 0.04), Vector2(0.026, 0.05), Vector2(0.03, 0.065), Vector2(0.02, 0.078), Vector2(0.0, 0.08)]), Vector3.ZERO, 14, metal)
			else:
				b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.026, 0.0), Vector2(0.026, 0.006), Vector2(0.008, 0.01), Vector2(0.008, 0.055), Vector2(0.0, 0.058)]), Vector3.ZERO, 12, metal)
				b.transform = Transform3D.IDENTITY
				var from := Vector3(lock_x, y, face + side * 0.05)
				b.extrude(KitJoinery._round_profile(0.008, 8), from, from + Vector3((-1.0 if hinge_left else 1.0) * 0.12, 0, 0), Vector3.UP, metal, false, true)
			b.transform = Transform3D.IDENTITY
	KitHardware.mount(leaf, b, "Handles", Vector3(lock_x, y, 0.0), CELL, roundi(thickness / CELL), 0.06)
