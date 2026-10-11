class_name FurnitureParts
extends RefCounted
## Shared building blocks for the furniture catalogues (metres, front at Z = 0).

const F := FurnitureModel.Finish

const BOOK_COLORS := [Color(0.55, 0.12, 0.1), Color(0.12, 0.25, 0.45), Color(0.15, 0.35, 0.2), Color(0.85, 0.78, 0.6),
	Color(0.2, 0.2, 0.22), Color(0.7, 0.45, 0.15), Color(0.4, 0.15, 0.35), Color(0.9, 0.9, 0.86)]


## A row of books of varied height, thickness and colour, with the odd gap.
static func books(m: FurnitureModel, x0: float, x1: float, y: float, max_h: float, z0: float, z1: float, rng: RandomNumberGenerator) -> void:
	var x := x0
	while x < x1 - 0.03:
		var t := rng.randf_range(0.022, 0.05)
		if x + t > x1:
			break
		if rng.randf() < 0.08:
			x += rng.randf_range(0.04, 0.1)
			continue
		var bh := minf(rng.randf_range(0.16, 0.3), maxf(max_h, 0.06))
		var depth := rng.randf_range(0.14, maxf(z1 - z0, 0.15))
		var book := m.paint("paper", BOOK_COLORS[rng.randi() % BOOK_COLORS.size()].lightened(rng.randf_range(-0.1, 0.1)))
		m.box(Vector3(x, y, z1 - depth), Vector3(x + t, y + bh, z1), book)
		x += t + 0.002


## An open-fronted box (sides, top, bottom, back) from `a` to `b`, panels `t`
## thick. Returns the inside as [low, high].
static func carcass(m: FurnitureModel, a: Vector3, b: Vector3, t: float, side: int, back: int = -1) -> Array:
	if back < 0:
		back = side
	m.box(a, Vector3(a.x + t, b.y, b.z), side)
	m.box(Vector3(b.x - t, a.y, a.z), b, side)
	m.box(Vector3(a.x + t, b.y - t, a.z), Vector3(b.x - t, b.y, b.z), side)
	m.box(Vector3(a.x + t, a.y, a.z), Vector3(b.x - t, a.y + t, b.z), side)
	m.box(Vector3(a.x + t, a.y + t, b.z - t * 0.6), Vector3(b.x - t, b.y - t, b.z), back)
	return [Vector3(a.x + t, a.y + t, a.z), Vector3(b.x - t, b.y - t, b.z - t * 0.6)]


## A recessed kick plinth under a cabinet.
static func plinth(m: FurnitureModel, x0: float, x1: float, depth: float, height: float, handle: int) -> void:
	m.box(Vector3(x0 + 0.01, 0.0, 0.06), Vector3(x1 - 0.01, height, depth - 0.02), handle)


## A worktop with a small overhang and a rounded front edge.
static func worktop(m: FurnitureModel, x0: float, x1: float, y: float, depth: float, thick: float, handle: int) -> void:
	m.rounded(Vector3(x0, y, -0.02), Vector3(x1, y + thick, depth), 0.012, handle, "y")


## A rounded appliance body, hollowed by the generator.
static func appliance(m: FurnitureModel, a: Vector3, b: Vector3, handle: int, radius := 0.02) -> void:
	m.rounded(a, b, radius, handle)


## A round control knob on a front face at height y.
static func knob(m: FurnitureModel, x: float, y: float, z: float, r: float, handle: int) -> void:
	m.cylinder(Vector3(x, y, z), "z", -0.025, r, handle)


## A long bar handle standing off a front face.
static func bar_handle(m: FurnitureModel, x0: float, x1: float, y: float, z: float, handle: int, vertical := false) -> void:
	if vertical:
		m.box(Vector3(x0 - 0.012, y, z - 0.035), Vector3(x0 + 0.012, x1, z - 0.02), handle)
		m.box(Vector3(x0 - 0.01, y, z - 0.02), Vector3(x0 + 0.01, y + 0.02, z), handle)
		m.box(Vector3(x0 - 0.01, x1 - 0.02, z - 0.02), Vector3(x0 + 0.01, x1, z), handle)
	else:
		m.box(Vector3(x0, y - 0.012, z - 0.035), Vector3(x1, y + 0.012, z - 0.02), handle)
		m.box(Vector3(x0, y - 0.01, z - 0.02), Vector3(x0 + 0.02, y + 0.01, z), handle)
		m.box(Vector3(x1 - 0.02, y - 0.01, z - 0.02), Vector3(x1, y + 0.01, z), handle)


## A seat shell: tapered legs, a seat, and a back of vertical slats or a solid panel.
static func chair(m: FurnitureModel, w: float, d: float, seat_h: float, back_h: float, frame: int, seat: int, slats := 0, round_legs := false) -> void:
	var leg := 0.035
	for corner in [Vector2(0.02, 0.02), Vector2(w - 0.02 - leg, 0.02), Vector2(0.02, d - 0.02 - leg), Vector2(w - 0.02 - leg, d - 0.02 - leg)]:
		var back_leg: bool = corner.y > d * 0.5
		var top := back_h if back_leg else seat_h
		if round_legs:
			m.cylinder(Vector3(corner.x + leg * 0.5, 0.0, corner.y + leg * 0.5), "y", top, leg * 0.42, frame, leg * 0.5)
		else:
			m.box(Vector3(corner.x, 0.0, corner.y), Vector3(corner.x + leg, top, corner.y + leg), frame)
	m.box(Vector3(0.02, seat_h - 0.09, 0.02), Vector3(w - 0.02, seat_h - 0.05, 0.04), frame)
	m.box(Vector3(0.02, seat_h - 0.09, d - 0.04), Vector3(w - 0.02, seat_h - 0.05, d - 0.02), frame)
	m.box(Vector3(0.02, 0.12, 0.04), Vector3(0.04, 0.15, d - 0.04), frame)
	m.box(Vector3(w - 0.04, 0.12, 0.04), Vector3(w - 0.02, 0.15, d - 0.04), frame)
	m.rounded(Vector3(0.0, seat_h - 0.05, 0.0), Vector3(w, seat_h, d), 0.012, seat, "y")
	# Back: top rail plus slats, or a solid shaped panel.
	m.box(Vector3(0.02, back_h - 0.08, d - 0.04), Vector3(w - 0.02, back_h, d - 0.015), frame)
	if slats > 0:
		var span := w - 0.1
		for i in slats:
			var x := 0.05 + span * (i + 0.5) / slats - 0.012
			m.box(Vector3(x, seat_h, d - 0.035), Vector3(x + 0.024, back_h - 0.08, d - 0.02), frame)
	else:
		m.box(Vector3(0.05, seat_h + 0.12, d - 0.035), Vector3(w - 0.05, back_h - 0.08, d - 0.02), frame)
