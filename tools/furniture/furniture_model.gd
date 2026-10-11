class_name FurnitureModel
extends RefCounted
## A small modelling kit for destructible furniture, used offline by
## tools/generate_furniture.gd. Shapes are given in metres with the model's
## minimum corner at the origin: +X across, +Y up, and the front at Z = 0 (the
## spawn menu turns -Z toward the player). They are rasterised into voxels of
## `voxel` metres; every voxel remembers its material and a shade, so wood grain,
## fabric and metal finishes survive as palette variations.

## Finish patterns: how a part's voxels are shaded.
enum Finish { PLAIN, GRAIN, FABRIC, BRUSHED, SPECKLE }

var voxel: float
var size: Vector3
## Vector3i -> [part handle, shade 0..2]
var cells: Dictionary = {}
## Part handles: [material key, colour, finish]
var parts: Array = []
var _handles: Dictionary = {}
## Moving parts: index 0 is the body; each later entry describes a door, drawer
## or lid: {kind: "hinge" | "slide", label, pivot, axis, amount} (metres, model space).
var moving: Array = [{}]
## Voxels drawn now belong to this part (0 = the body).
var _group: int = 0
## What normalize() subtracted from every cell.
var shift: Vector3i = Vector3i.ZERO


func _init(model_size: Vector3, voxel_size: float) -> void:
	size = model_size
	voxel = voxel_size


## A material + colour + finish to paint with. Same arguments give the same handle.
func paint(material: String, color: Color, finish: Finish = Finish.PLAIN) -> int:
	var key := "%s|%s|%d" % [material, color.to_html(false), finish]
	if not _handles.has(key):
		_handles[key] = parts.size()
		parts.append([material, color, finish])
	return _handles[key]


## Moves every voxel so the lowest corner is cell (0, 0, 0); returns the grid size.
func normalize() -> Vector3i:
	if cells.is_empty():
		return Vector3i.ONE
	var lo := Vector3i(1 << 20, 1 << 20, 1 << 20)
	var hi := -lo
	for c: Vector3i in cells:
		lo = lo.min(c)
		hi = hi.max(c)
	shift = lo
	if lo != Vector3i.ZERO:
		var moved := {}
		for c: Vector3i in cells:
			moved[c - lo] = cells[c]
		cells = moved
	return hi - lo + Vector3i.ONE


# --- Cell ranges

## Cells covering [a, b) along one axis; at least one cell even for parts thinner
## than a voxel.
func _range(a: float, b: float) -> Vector2i:
	var lo := roundi(minf(a, b) / voxel)
	var hi := roundi(maxf(a, b) / voxel)
	if hi <= lo:
		lo = floori((a + b) * 0.5 / voxel)
		hi = lo + 1
	return Vector2i(lo, hi)


func _put(cell: Vector3i, handle: int, shade: int) -> void:
	# Parts may stick out past the nominal size (handles, overhangs): the generator
	# shifts everything to the model's real bounds when it exports.
	cells[cell] = [handle, shade, _group]


func _shade(handle: int, cell: Vector3i, grain_axis: int) -> int:
	var finish: int = parts[handle][2]
	match finish:
		Finish.GRAIN:
			# Bands across the grain, broken up a little along it.
			var across := cell[(grain_axis + 1) % 3] * 3 + cell[(grain_axis + 2) % 3] * 5
			var along := cell[grain_axis]
			var wave := sin(across * 0.9 + sin(along * 0.23 + across) * 1.7)
			return 0 if wave > 0.45 else (2 if wave < -0.6 else 1)
		Finish.FABRIC:
			return 1 if ((cell.x * 7 + cell.y * 13 + cell.z * 17) % 5) == 0 else 0
		Finish.BRUSHED:
			return 1 if (cell[grain_axis] + cell[(grain_axis + 1) % 3] * 3) % 4 == 0 else 0
		Finish.SPECKLE:
			var h := (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791)
			return absi(h) % 3
	return 0


static func _longest(v: Vector3) -> int:
	if v.x >= v.y and v.x >= v.z:
		return 0
	return 1 if v.y >= v.z else 2


# --- Shapes (metres)

## Solid box from `a` to `b`.
func box(a: Vector3, b: Vector3, handle: int) -> void:
	var rx := _range(a.x, b.x)
	var ry := _range(a.y, b.y)
	var rz := _range(a.z, b.z)
	var axis := _longest((b - a).abs())
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			for z in range(rz.x, rz.y):
				var c := Vector3i(x, y, z)
				_put(c, handle, _shade(handle, c, axis))


## Box with its edges rounded off (radius in metres), for cushions, tops and bodies.
## `edges` picks which: "all", "y" (vertical edges only), "top".
func rounded(a: Vector3, b: Vector3, radius: float, handle: int, edges := "all") -> void:
	var lo := a.min(b)
	var hi := a.max(b)
	var rx := _range(lo.x, hi.x)
	var ry := _range(lo.y, hi.y)
	var rz := _range(lo.z, hi.z)
	var axis := _longest(hi - lo)
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			for z in range(rz.x, rz.y):
				var p := (Vector3(x, y, z) + Vector3.ONE * 0.5) * voxel
				var q := Vector3(maxf(lo.x + radius - p.x, p.x - (hi.x - radius)), maxf(lo.y + radius - p.y, p.y - (hi.y - radius)), maxf(lo.z + radius - p.z, p.z - (hi.z - radius)))
				match edges:
					"y":
						q.y = 0.0
					"top":
						if p.y < hi.y - radius:
							q = Vector3.ZERO
				if Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length() > radius + voxel * 0.25:
					continue
				var c := Vector3i(x, y, z)
				_put(c, handle, _shade(handle, c, axis))


## Cylinder along an axis ("x", "y" or "z") from `start` (centre of one end) for
## `length`, radius `r0` at the start tapering to `r1` (default the same).
func cylinder(start: Vector3, axis: String, length: float, r0: float, handle: int, r1: float = -1.0) -> void:
	if r1 < 0.0:
		r1 = r0
	var a: int = {"x": 0, "y": 1, "z": 2}[axis]
	var r := maxf(r0, r1)
	var lo := start - Vector3.ONE * r
	var hi := start + Vector3.ONE * r
	lo[a] = minf(start[a], start[a] + length)
	hi[a] = maxf(start[a], start[a] + length)
	var rx := _range(lo.x, hi.x)
	var ry := _range(lo.y, hi.y)
	var rz := _range(lo.z, hi.z)
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			for z in range(rz.x, rz.y):
				var p := (Vector3(x, y, z) + Vector3.ONE * 0.5) * voxel
				var t := clampf((p[a] - start[a]) / length, 0.0, 1.0) if absf(length) > 0.0001 else 0.0
				var radius := lerpf(r0, r1, t)
				var d := p - start
				d[a] = 0.0
				# Thin rods still get a line of voxels.
				if d.length() > maxf(radius, voxel * 0.55):
					continue
				var c := Vector3i(x, y, z)
				_put(c, handle, _shade(handle, c, a))
	# The cells the axis itself runs through, so a rod thinner than a voxel can
	# never miss every cell centre and vanish (it depended on grid alignment).
	var along := _range(lo[a], hi[a])
	var through := Vector3i((start / voxel).floor())
	for k in range(along.x, along.y):
		var c := through
		c[a] = k
		if not cells.has(c):
			_put(c, handle, _shade(handle, c, a))


## Ellipsoid centred at `c` with radii `r` (a sphere when all equal).
func ellipsoid(c: Vector3, r: Vector3, handle: int) -> void:
	var rx := _range(c.x - r.x, c.x + r.x)
	var ry := _range(c.y - r.y, c.y + r.y)
	var rz := _range(c.z - r.z, c.z + r.z)
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			for z in range(rz.x, rz.y):
				var p := (Vector3(x, y, z) + Vector3.ONE * 0.5) * voxel - c
				if (p / r).length() > 1.0:
					continue
				var cell := Vector3i(x, y, z)
				_put(cell, handle, _shade(handle, cell, 1))


## A prism: a 2D outline (in the XY plane, metres) extruded from z0 to z1.
## Good for shaped backs, arms, chair splats and gable shapes.
func prism_xy(outline: PackedVector2Array, z0: float, z1: float, handle: int) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in outline:
		lo = lo.min(p)
		hi = hi.max(p)
	var rx := _range(lo.x, hi.x)
	var ry := _range(lo.y, hi.y)
	var rz := _range(z0, z1)
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			var p := (Vector2(x, y) + Vector2.ONE * 0.5) * voxel
			if not Geometry2D.is_point_in_polygon(p, outline):
				continue
			for z in range(rz.x, rz.y):
				var c := Vector3i(x, y, z)
				_put(c, handle, _shade(handle, c, 1))


## The same, extruded along X (an outline in the ZY plane: Vector2(z, y)).
func prism_zy(outline: PackedVector2Array, x0: float, x1: float, handle: int) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in outline:
		lo = lo.min(p)
		hi = hi.max(p)
	var rz := _range(lo.x, hi.x)
	var ry := _range(lo.y, hi.y)
	var rx := _range(x0, x1)
	for z in range(rz.x, rz.y):
		for y in range(ry.x, ry.y):
			var p := (Vector2(z, y) + Vector2.ONE * 0.5) * voxel
			if not Geometry2D.is_point_in_polygon(p, outline):
				continue
			for x in range(rx.x, rx.y):
				var c := Vector3i(x, y, z)
				_put(c, handle, _shade(handle, c, 0))


## Removes voxels in a box (grooves, recesses, openings).
func cut(a: Vector3, b: Vector3) -> void:
	var rx := _range(a.x, b.x)
	var ry := _range(a.y, b.y)
	var rz := _range(a.z, b.z)
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			for z in range(rz.x, rz.y):
				cells.erase(Vector3i(x, y, z))


## Removes voxels in a cylinder (holes, bowls, drums).
func cut_cylinder(start: Vector3, axis: String, length: float, radius: float) -> void:
	var a: int = {"x": 0, "y": 1, "z": 2}[axis]
	var lo := start - Vector3.ONE * radius
	var hi := start + Vector3.ONE * radius
	lo[a] = minf(start[a], start[a] + length)
	hi[a] = maxf(start[a], start[a] + length)
	var rx := _range(lo.x, hi.x)
	var ry := _range(lo.y, hi.y)
	var rz := _range(lo.z, hi.z)
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			for z in range(rz.x, rz.y):
				var p := (Vector3(x, y, z) + Vector3.ONE * 0.5) * voxel
				var d := p - start
				d[a] = 0.0
				if d.length() <= radius:
					cells.erase(Vector3i(x, y, z))


## Removes an ellipsoid (basins, bowls, seat dips).
func cut_ellipsoid(c: Vector3, r: Vector3) -> void:
	var rx := _range(c.x - r.x, c.x + r.x)
	var ry := _range(c.y - r.y, c.y + r.y)
	var rz := _range(c.z - r.z, c.z + r.z)
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			for z in range(rz.x, rz.y):
				var p := (Vector3(x, y, z) + Vector3.ONE * 0.5) * voxel - c
				if (p / r).length() <= 1.0:
					cells.erase(Vector3i(x, y, z))


## Repaints existing voxels inside a box (seams, stripes, labels, worn spots).
func repaint(a: Vector3, b: Vector3, handle: int) -> void:
	var rx := _range(a.x, b.x)
	var ry := _range(a.y, b.y)
	var rz := _range(a.z, b.z)
	for x in range(rx.x, rx.y):
		for y in range(ry.x, ry.y):
			for z in range(rz.x, rz.y):
				var c := Vector3i(x, y, z)
				if cells.has(c):
					cells[c] = [handle, cells[c][1], group_of(c)]


# --- Common furniture parts

## Four legs inside a footprint (inset from its edges), square or round.
func legs(x0: float, z0: float, x1: float, z1: float, height: float, thick: float, inset: float, handle: int, round := false, taper := 1.0, y0 := 0.0) -> void:
	for corner in [Vector2(x0 + inset, z0 + inset), Vector2(x1 - inset - thick, z0 + inset), Vector2(x0 + inset, z1 - inset - thick), Vector2(x1 - inset - thick, z1 - inset - thick)]:
		if round or taper != 1.0:
			cylinder(Vector3(corner.x + thick * 0.5, y0, corner.y + thick * 0.5), "y", height, thick * 0.5 * taper, handle, thick * 0.5)
		else:
			box(Vector3(corner.x, y0, corner.y), Vector3(corner.x + thick, y0 + height, corner.y + thick), handle)


## Starts a moving part: everything drawn until end_part() is a separate body
## that opens. "hinge" turns `amount` degrees about `axis` through `pivot`;
## "slide" moves `amount` metres along `axis`. Positions are model metres.
func begin_part(kind: String, label: String, pivot: Vector3, axis: Vector3, amount: float) -> int:
	moving.append({"kind": kind, "label": label, "pivot": pivot, "axis": axis.normalized(), "amount": amount})
	_group = moving.size() - 1
	return _group


func end_part() -> void:
	_group = 0


## Draws into an existing part again (e.g. a label on a drawer front), until end_part().
func in_part(part: int) -> void:
	_group = part


## Which moving part a cell belongs to (0 = the body).
func group_of(cell: Vector3i) -> int:
	var entry: Array = cells.get(cell, [])
	return entry[2] if entry.size() > 2 else 0


## A drawer that pulls out: a front with a shadow gap and a knob or bar handle,
## on a tray running `depth` into the piece (a cavity is cut for it). The
## depth defaults to most of the way to the back.
func drawer(a: Vector3, b: Vector3, front: int, handle_part: int, style := "bar", depth := -1.0) -> int:
	if depth < 0.0:
		depth = clampf(size.z - b.z - 0.05, 0.1, 0.5)
	var x0 := a.x + 0.03
	var x1 := b.x - 0.03
	var y0 := a.y + 0.02
	var y1 := b.y - 0.03
	var tray := x1 - x0 > voxel * 3 and y1 - y0 > voxel * 2
	if tray:
		cut(Vector3(x0, y0, b.z), Vector3(x1, y1, b.z + depth))
	var mid := (a + b) * 0.5
	var part := begin_part("slide", "Drawer", Vector3(mid.x, mid.y, a.z), Vector3.FORWARD, depth * 0.75)
	box(a, b, front)
	# Gap around the front.
	var gap := voxel
	cut(Vector3(a.x, b.y - gap, a.z), Vector3(b.x, b.y, a.z + gap))
	if tray:
		var t := voxel
		box(Vector3(x0, y0, b.z), Vector3(x1, y0 + t, b.z + depth), front)
		box(Vector3(x0, y0, b.z), Vector3(x0 + t, y1, b.z + depth), front)
		box(Vector3(x1 - t, y0, b.z), Vector3(x1, y1, b.z + depth), front)
		box(Vector3(x0, y0, b.z + depth - t), Vector3(x1, y1, b.z + depth), front)
	match style:
		"knob":
			ellipsoid(Vector3(mid.x, mid.y, a.z - voxel), Vector3.ONE * maxf(0.018, voxel * 0.8), handle_part)
		"cup":
			box(Vector3(mid.x - 0.05, mid.y - 0.01, a.z - voxel), Vector3(mid.x + 0.05, mid.y + 0.02, a.z), handle_part)
		_:
			var w := minf(0.16, (b.x - a.x) * 0.45)
			box(Vector3(mid.x - w * 0.5, mid.y - 0.008, a.z - voxel * 1.6), Vector3(mid.x + w * 0.5, mid.y + 0.012, a.z - voxel * 0.6), handle_part)
			box(Vector3(mid.x - w * 0.5, mid.y - 0.008, a.z - voxel * 0.6), Vector3(mid.x - w * 0.5 + voxel, mid.y + 0.012, a.z), handle_part)
			box(Vector3(mid.x + w * 0.5 - voxel, mid.y - 0.008, a.z - voxel * 0.6), Vector3(mid.x + w * 0.5, mid.y + 0.012, a.z), handle_part)
	end_part()
	return part


## A cupboard door that swings open on hinges at the edge away from its handle:
## a framed panel (recessed centre) with the handle near the opposite edge.
func door_front(a: Vector3, b: Vector3, front: int, handle_part: int, handle_left := false, shaker := true, label := "Door") -> int:
	# Hinged on the outer front corner of the edge away from the handle, opening outward (-Z).
	var hinge_x := b.x if handle_left else a.x
	var part := begin_part("hinge", label, Vector3(hinge_x, (a.y + b.y) * 0.5, a.z), Vector3.UP, -100.0 if handle_left else 100.0)
	box(a, b, front)
	if shaker and (b.x - a.x) > voxel * 6 and (b.y - a.y) > voxel * 6:
		var rail := maxf(voxel * 2, 0.05)
		cut(Vector3(a.x + rail, a.y + rail, a.z), Vector3(b.x - rail, b.y - rail, a.z + voxel))
		box(Vector3(a.x + rail, a.y + rail, a.z + voxel), Vector3(b.x - rail, b.y - rail, a.z + voxel * 2), front)
	var hx := a.x + 0.05 if handle_left else b.x - 0.05
	var hy := b.y - minf(0.12, (b.y - a.y) * 0.25)
	box(Vector3(hx - 0.008, hy - 0.06, a.z - voxel * 1.5), Vector3(hx + 0.008, hy + 0.06, a.z), handle_part)
	end_part()
	return part


# --- Finishing

## Removes voxels buried at least two deep inside the model, keeping a solid
## two-voxel shell. Saves memory and build time on big upholstered pieces.
## Materials listed in `keep` (e.g. glass) are never hollowed.
const DEEP: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(-1, 0, 0), Vector3i(-2, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 2, 0),
	Vector3i(0, -1, 0), Vector3i(0, -2, 0), Vector3i(0, 0, 1), Vector3i(0, 0, 2), Vector3i(0, 0, -1), Vector3i(0, 0, -2)]


const FACE_NEIGHBOURS: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0),
	Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]


## Joins every loose part (anything not sharing a face with the main body: legs
## under a rounded corner, knobs touching only at an edge) to the body with the
## shortest run of voxels in its own material. A VoxelBody drops loose parts the
## moment it checks its support, so a piece must be one connected lump.
## Returns [part voxels, bridge voxels] per join, and [part voxels, -1] for any
## part further than `max_gap` voxels away (left loose, to be fixed by hand).
func connect_parts(max_gap := 8) -> Array:
	var joins := []
	# Passes repeat until nothing more joins: a part reached through another
	# loose part is only seen as connected once components are recounted.
	for pass_index in 8:
		var pass_joins := _connect_pass(max_gap)
		if pass_joins.is_empty():
			break
		var progress := false
		for join in pass_joins:
			if join[1] >= 0:
				progress = true
				joins.append(join)
		if not progress:
			for join in pass_joins:
				joins.append(join)
			break
	return joins


func _connect_pass(max_gap: int) -> Array:
	var joins := []
	var groups := _components()
	if groups.size() < 2:
		return joins
	groups.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.size() > b.size())
	# Each moving part (and the body) is joined up separately: the largest lump
	# of each is its main piece.
	var mains := {}
	for group in groups:
		var id := group_of(group.keys()[0])
		if not mains.has(id):
			mains[id] = group
	for group: Dictionary in groups:
		var main: Dictionary = mains[group_of(group.keys()[0])]
		if main == group or main.has(group.keys()[0]):
			continue
		# Breadth-first from the whole part through empty cells until the body.
		var came_from := {}
		var frontier: Array[Vector3i] = []
		for c: Vector3i in group:
			came_from[c] = c
			frontier.append(c)
		var reached := Vector3i.ZERO
		var found := false
		for step in max_gap + 1:
			var next: Array[Vector3i] = []
			for c in frontier:
				for offset in FACE_NEIGHBOURS:
					var q := c + offset
					if came_from.has(q):
						continue
					if main.has(q):
						reached = c
						found = true
						break
					# Other loose parts are passed through (joined on a later pass).
					came_from[q] = c
					next.append(q)
				if found:
					break
			if found or step == max_gap:
				break
			frontier = next
		if not found:
			var first: Vector3i = group.keys()[0]
			joins.append([group.size(), -1, "%s at %s" % [parts[cells[first][0]][0], Vector3(first) * voxel]])
			continue
		# Fill the path back to the part with the part's own paint.
		var bridge := 0
		var at := reached
		var path: Array[Vector3i] = []
		while not group.has(at):
			path.append(at)
			at = came_from[at]
		var entry: Array = cells[at]
		for c in path:
			main[c] = true
			if not cells.has(c):
				cells[c] = [entry[0], entry[1], group_of(at)]
				bridge += 1
		for c in group:
			main[c] = true
		joins.append([group.size(), bridge])
	return joins


func _components() -> Array[Dictionary]:
	var seen := {}
	var groups: Array[Dictionary] = []
	for start: Vector3i in cells:
		if seen.has(start):
			continue
		var group := {start: true}
		var id := group_of(start)
		seen[start] = true
		var stack: Array[Vector3i] = [start]
		while not stack.is_empty():
			var c: Vector3i = stack.pop_back()
			for offset in FACE_NEIGHBOURS:
				var q := c + offset
				if cells.has(q) and not seen.has(q) and group_of(q) == id:
					seen[q] = true
					group[q] = true
					stack.append(q)
		groups.append(group)
	return groups


func hollow(keep: Array[String] = []) -> void:
	var remove: Array[Vector3i] = []
	for c: Vector3i in cells:
		if keep.has(parts[cells[c][0]][0]):
			continue
		var buried := true
		var id := group_of(c)
		for step in DEEP:
			# A part's surface stays even where it touches another part.
			if not cells.has(c + step) or group_of(c + step) != id:
				buried = false
				break
		if buried:
			remove.append(c)
	for c in remove:
		cells.erase(c)
