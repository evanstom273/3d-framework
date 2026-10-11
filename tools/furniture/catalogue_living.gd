extends RefCounted
## Living room furniture (25). See FurnitureModel for the modelling conventions.

const CATEGORY := "Living Room"
const F := FurnitureModel.Finish

const SAGE := Color(0.5, 0.58, 0.52)
const CHARCOAL := Color(0.25, 0.26, 0.28)
const MUSTARD := Color(0.78, 0.6, 0.2)
const TEAL := Color(0.18, 0.4, 0.42)
const OATMEAL := Color(0.78, 0.72, 0.62)
const OXBLOOD := Color(0.42, 0.13, 0.12)
const TAN_LEATHER := Color(0.55, 0.33, 0.18)


func models() -> Array:
	return [
		_m("sofa_three_seater", "Three-Seater Sofa", Vector3(2.1, 0.88, 0.92), func(m): _sofa(m, 3, SAGE)),
		_m("sofa_two_seater", "Two-Seater Sofa", Vector3(1.55, 0.86, 0.9), func(m): _sofa(m, 2, CHARCOAL)),
		_m("armchair", "Armchair", Vector3(0.95, 0.86, 0.9), func(m): _sofa(m, 1, MUSTARD)),
		_m("wingback_chair", "Wingback Chair", Vector3(0.82, 1.15, 0.86), _wingback),
		_m("recliner", "Recliner", Vector3(0.95, 1.02, 0.98), _recliner),
		_m("ottoman", "Ottoman", Vector3(0.95, 0.44, 0.62), _ottoman),
		_m("footstool", "Footstool", Vector3(0.46, 0.4, 0.46), _footstool, {"voxel": 0.018}),
		_m("coffee_table", "Coffee Table", Vector3(1.1, 0.45, 0.6), _coffee_table),
		_m("side_table", "Side Table", Vector3(0.5, 0.56, 0.5), _side_table),
		_m("nesting_tables", "Nesting Tables", Vector3(0.6, 0.52, 0.42), _nesting_tables),
		_m("tv_cabinet", "TV Cabinet", Vector3(1.6, 0.5, 0.42), _tv_cabinet, {"voxel": 0.025}),
		_m("television", "Television", Vector3(1.24, 0.78, 0.26), _television),
		_m("bookcase_tall", "Tall Bookcase", Vector3(0.9, 2.0, 0.32), func(m): _bookcase(m, 5, "tall"), {"voxel": 0.03}),
		_m("bookcase_short", "Short Bookcase", Vector3(0.9, 1.0, 0.32), func(m): _bookcase(m, 2, "short")),
		_m("display_cabinet", "Display Cabinet", Vector3(0.9, 1.8, 0.42), _display_cabinet, {"voxel": 0.03}),
		_m("sideboard", "Sideboard", Vector3(1.6, 0.82, 0.46), _sideboard),
		_m("console_table", "Console Table", Vector3(1.2, 0.78, 0.35), _console_table),
		_m("floor_lamp", "Floor Lamp", Vector3(0.46, 1.62, 0.46), _floor_lamp, {"voxel": 0.02}),
		_m("table_lamp", "Table Lamp", Vector3(0.34, 0.55, 0.34), _table_lamp),
		_m("fireplace_surround", "Fireplace Surround", Vector3(1.5, 1.2, 0.5), _fireplace),
		_m("mantel_clock", "Mantel Clock", Vector3(0.32, 0.26, 0.12), _mantel_clock),
		_m("coat_stand", "Coat Stand", Vector3(0.52, 1.85, 0.52), _coat_stand, {"voxel": 0.02}),
		_m("magazine_rack", "Magazine Rack", Vector3(0.42, 0.44, 0.3), _magazine_rack, {"voxel": 0.018}),
		_m("shelving_wood", "Wooden Shelving Unit", Vector3(1.0, 1.8, 0.36), _wood_shelving, {"voxel": 0.025}),
		_m("room_divider", "Room Divider", Vector3(1.5, 1.75, 0.42), _room_divider, {"voxel": 0.025}),
	]


## Real-world weights (kg).
const MASSES := {
	"sofa_three_seater": 70.0, "sofa_two_seater": 55.0, "armchair": 35.0, "wingback_chair": 30.0, "recliner": 45.0,
	"ottoman": 18.0, "footstool": 6.0, "coffee_table": 22.0, "side_table": 9.0, "nesting_tables": 14.0,
	"tv_cabinet": 40.0, "television": 14.0, "bookcase_tall": 45.0, "bookcase_short": 22.0, "display_cabinet": 60.0,
	"sideboard": 55.0, "console_table": 16.0, "floor_lamp": 7.0, "table_lamp": 3.0, "fireplace_surround": 70.0,
	"mantel_clock": 2.5, "coat_stand": 7.0, "magazine_rack": 4.0, "shelving_wood": 25.0, "room_divider": 12.0,
}


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


# --- Upholstered seating

## Sofa or armchair: plinth, arms with piped fronts, back, and separate seat and
## back cushions with seams between them, on turned feet.
func _sofa(m: FurnitureModel, seats: int, color: Color) -> void:
	var fabric := m.paint("fabric", color, F.FABRIC)
	var piping := m.paint("fabric", color.darkened(0.25), F.FABRIC)
	var cushion := m.paint("fabric", color.lightened(0.06), F.FABRIC)
	var feet := m.paint("walnut", Color(0.33, 0.22, 0.14), F.GRAIN)
	var w := m.size.x
	var d := m.size.z
	var h := m.size.y
	var arm := 0.18 if seats > 1 else 0.16
	m.legs(0.0, 0.0, w, d, 0.11, 0.05, 0.04, feet, true, 0.7)
	m.rounded(Vector3(0.02, 0.1, 0.06), Vector3(w - 0.02, 0.4, d), 0.03, fabric)
	for x in [0.0, w - arm]:
		m.rounded(Vector3(x, 0.1, 0.04), Vector3(x + arm, 0.64, d), 0.06, fabric)
		m.repaint(Vector3(x, 0.58, 0.04), Vector3(x + arm, 0.64, 0.08), piping)
	m.rounded(Vector3(arm, 0.4, d - 0.2), Vector3(w - arm, h, d), 0.06, fabric)
	var inner := w - arm * 2.0
	var each := inner / seats
	for i in seats:
		var x0 := arm + each * i
		m.rounded(Vector3(x0 + 0.005, 0.4, 0.06), Vector3(x0 + each - 0.005, 0.54, d - 0.18), 0.04, cushion)
		m.rounded(Vector3(x0 + 0.005, 0.54, d - 0.36), Vector3(x0 + each - 0.005, h - 0.06, d - 0.18), 0.05, cushion)
		# Seams between cushions.
		if i > 0:
			m.cut(Vector3(x0 - 0.004, 0.4, 0.06), Vector3(x0 + 0.004, h - 0.06, d - 0.18))
	m.repaint(Vector3(0.02, 0.1, 0.05), Vector3(w - 0.02, 0.13, 0.08), piping)


func _wingback(m: FurnitureModel) -> void:
	var fabric := m.paint("fabric", TEAL, F.FABRIC)
	var button := m.paint("fabric", TEAL.darkened(0.35))
	var wood := m.paint("walnut", Color(0.34, 0.22, 0.13), F.GRAIN)
	# Cabriole-ish legs: tapered, splayed slightly.
	for corner in [Vector2(0.08, 0.08), Vector2(0.74, 0.08), Vector2(0.08, 0.78), Vector2(0.74, 0.78)]:
		m.cylinder(Vector3(corner.x, 0.0, corner.y), "y", 0.24, 0.018, wood, 0.03)
	m.rounded(Vector3(0.04, 0.22, 0.04), Vector3(0.78, 0.46, 0.82), 0.03, fabric)
	m.rounded(Vector3(0.08, 0.46, 0.08), Vector3(0.74, 0.54, 0.66), 0.03, fabric)
	# Tall back with a curved top and wings to either side.
	var back := PackedVector2Array([Vector2(0.06, 0.4), Vector2(0.76, 0.4), Vector2(0.76, 1.02), Vector2(0.62, 1.12), Vector2(0.2, 1.12), Vector2(0.06, 1.02)])
	m.prism_xy(back, 0.66, 0.84, fabric)
	for x in [0.0, 0.66]:
		var wing := PackedVector2Array([Vector2(0.84, 0.4), Vector2(0.84, 1.05), Vector2(0.62, 1.0), Vector2(0.42, 0.78), Vector2(0.12, 0.72), Vector2(0.06, 0.62), Vector2(0.06, 0.4)])
		m.prism_zy(wing, x, x + 0.16, fabric)
	# Buttoned back.
	for row in 3:
		for col in 4:
			var bx := 0.18 + col * 0.15
			var by := 0.64 + row * 0.13
			m.repaint(Vector3(bx, by, 0.65), Vector3(bx + 0.02, by + 0.02, 0.67), button)


func _recliner(m: FurnitureModel) -> void:
	var leather := m.paint("leather", TAN_LEATHER, F.FABRIC)
	var seam := m.paint("leather", TAN_LEATHER.darkened(0.3))
	var lever := m.paint("chrome", Color(0.8, 0.8, 0.82), F.BRUSHED)
	m.rounded(Vector3(0.0, 0.04, 0.06), Vector3(0.95, 0.42, 0.98), 0.04, leather)
	for x in [0.0, 0.76]:
		m.rounded(Vector3(x, 0.04, 0.05), Vector3(x + 0.19, 0.66, 0.98), 0.08, leather)
	m.rounded(Vector3(0.19, 0.42, 0.06), Vector3(0.76, 0.56, 0.78), 0.05, leather)
	m.rounded(Vector3(0.19, 0.42, 0.72), Vector3(0.76, 1.02, 0.98), 0.08, leather)
	# Stitched panels on the back, a footrest seam on the front, side lever.
	for y in [0.62, 0.8]:
		m.repaint(Vector3(0.2, y, 0.71), Vector3(0.75, y + 0.015, 0.74), seam)
	m.repaint(Vector3(0.19, 0.2, 0.05), Vector3(0.76, 0.22, 0.08), seam)
	m.box(Vector3(0.95 - 0.01, 0.3, 0.3), Vector3(0.95, 0.46, 0.33), lever)


func _ottoman(m: FurnitureModel) -> void:
	var fabric := m.paint("fabric", OXBLOOD, F.FABRIC)
	var tuft := m.paint("fabric", OXBLOOD.darkened(0.4))
	var feet := m.paint("walnut", Color(0.3, 0.2, 0.12), F.GRAIN)
	m.legs(0.0, 0.0, 0.95, 0.62, 0.08, 0.05, 0.04, feet, true, 0.75)
	m.rounded(Vector3(0.0, 0.08, 0.0), Vector3(0.95, 0.44, 0.62), 0.05, fabric)
	for row in 2:
		for col in 4:
			var x := 0.16 + col * 0.21
			var z := 0.2 + row * 0.22
			m.cut(Vector3(x, 0.42, z), Vector3(x + 0.025, 0.44, z + 0.025))
			m.repaint(Vector3(x, 0.4, z), Vector3(x + 0.025, 0.42, z + 0.025), tuft)


func _footstool(m: FurnitureModel) -> void:
	var fabric := m.paint("fabric", OATMEAL, F.FABRIC)
	var wood := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	for corner in [Vector2(0.08, 0.08), Vector2(0.38, 0.08), Vector2(0.08, 0.38), Vector2(0.38, 0.38)]:
		m.cylinder(Vector3(corner.x, 0.0, corner.y), "y", 0.22, 0.014, wood, 0.022)
	m.cylinder(Vector3(0.23, 0.2, 0.23), "y", 0.07, 0.22, wood)
	m.cylinder(Vector3(0.23, 0.26, 0.23), "y", 0.14, 0.23, fabric)
	m.cylinder(Vector3(0.23, 0.38, 0.23), "y", 0.02, 0.2, fabric)


# --- Tables

func _coffee_table(m: FurnitureModel) -> void:
	var oak := m.paint("oak", Color(0.64, 0.46, 0.28), F.GRAIN)
	var dark := m.paint("oak", Color(0.52, 0.37, 0.22), F.GRAIN)
	m.rounded(Vector3(0.0, 0.41, 0.0), Vector3(1.1, 0.45, 0.6), 0.015, oak, "y")
	m.legs(0.0, 0.0, 1.1, 0.6, 0.41, 0.05, 0.04, dark, false)
	# Aprons under the top and a slatted lower shelf.
	m.box(Vector3(0.09, 0.34, 0.04), Vector3(1.01, 0.41, 0.06), dark)
	m.box(Vector3(0.09, 0.34, 0.54), Vector3(1.01, 0.41, 0.56), dark)
	for i in 6:
		var x := 0.1 + i * 0.152
		m.box(Vector3(x, 0.09, 0.08), Vector3(x + 0.12, 0.11, 0.52), oak)
	m.box(Vector3(0.04, 0.07, 0.04), Vector3(1.06, 0.09, 0.08), dark)
	m.box(Vector3(0.04, 0.07, 0.52), Vector3(1.06, 0.09, 0.56), dark)


func _side_table(m: FurnitureModel) -> void:
	var paint := m.paint("painted_wood", Color(0.86, 0.85, 0.8), F.PLAIN)
	var top := m.paint("oak", Color(0.62, 0.45, 0.28), F.GRAIN)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	m.rounded(Vector3(0.0, 0.53, 0.0), Vector3(0.5, 0.56, 0.5), 0.01, top, "y")
	m.legs(0.0, 0.0, 0.5, 0.5, 0.53, 0.04, 0.03, paint, false, 1.0)
	m.box(Vector3(0.07, 0.4, 0.04), Vector3(0.43, 0.53, 0.46), paint)
	m.drawer(Vector3(0.08, 0.41, 0.03), Vector3(0.42, 0.52, 0.05), paint, brass, "knob")
	m.box(Vector3(0.06, 0.12, 0.06), Vector3(0.44, 0.14, 0.44), paint)


func _nesting_tables(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.4, 0.26, 0.16), F.GRAIN)
	# Three tables, each slightly smaller and lower, tucked under the last.
	var sizes := [[0.6, 0.52, 0.42], [0.52, 0.46, 0.38], [0.44, 0.4, 0.34]]
	for i in 3:
		var s: Array = sizes[i]
		var x0 := (0.6 - float(s[0])) * 0.5
		var z0 := (0.42 - float(s[2])) * 0.5 - i * 0.01
		var w: float = s[0]
		var h: float = s[1]
		var d: float = s[2]
		m.box(Vector3(x0, h - 0.025, z0), Vector3(x0 + w, h, z0 + d), walnut)
		for x in [x0, x0 + w - 0.025]:
			m.box(Vector3(x, 0.0, z0), Vector3(x + 0.025, h - 0.025, z0 + 0.025), walnut)
			m.box(Vector3(x, 0.0, z0 + d - 0.025), Vector3(x + 0.025, h - 0.025, z0 + d), walnut)
			m.box(Vector3(x, 0.02, z0 + 0.025), Vector3(x + 0.025, 0.04, z0 + d - 0.025), walnut)


# --- Storage and media

func _tv_cabinet(m: FurnitureModel) -> void:
	var oak := m.paint("oak", Color(0.66, 0.48, 0.3), F.GRAIN)
	var front := m.paint("painted_wood", Color(0.2, 0.25, 0.28))
	var black := m.paint("steel", Color(0.1, 0.1, 0.11), F.BRUSHED)
	m.box(Vector3(0.0, 0.08, 0.0), Vector3(1.6, 0.5, 0.42), oak)
	m.cut(Vector3(0.03, 0.11, 0.0), Vector3(1.57, 0.47, 0.39))
	# Two doors and an open middle shelf for the set-top box.
	m.door_front(Vector3(0.03, 0.11, 0.0), Vector3(0.53, 0.47, 0.02), front, black, false, false)
	m.door_front(Vector3(1.07, 0.11, 0.0), Vector3(1.57, 0.47, 0.02), front, black, true, false)
	m.box(Vector3(0.53, 0.28, 0.02), Vector3(1.07, 0.3, 0.39), oak)
	m.box(Vector3(0.52, 0.11, 0.02), Vector3(0.54, 0.47, 0.39), oak)
	m.box(Vector3(1.06, 0.11, 0.02), Vector3(1.08, 0.47, 0.39), oak)
	for x in [0.06, 1.5]:
		m.box(Vector3(x, 0.0, 0.06), Vector3(x + 0.04, 0.08, 0.36), black)


func _television(m: FurnitureModel) -> void:
	var bezel := m.paint("electronics", Color(0.08, 0.08, 0.09))
	var screen := m.paint("screen", Color(0.05, 0.06, 0.08))
	var stand := m.paint("aluminium", Color(0.55, 0.56, 0.58), F.BRUSHED)
	m.box(Vector3(0.0, 0.08, 0.08), Vector3(1.24, 0.78, 0.13), bezel)
	m.box(Vector3(0.02, 0.1, 0.075), Vector3(1.22, 0.76, 0.08), screen)
	# Thicker electronics bulge behind, and a pedestal stand.
	m.rounded(Vector3(0.3, 0.2, 0.13), Vector3(0.94, 0.6, 0.18), 0.03, bezel)
	m.box(Vector3(0.58, 0.02, 0.1), Vector3(0.66, 0.2, 0.14), stand)
	m.rounded(Vector3(0.42, 0.0, 0.02), Vector3(0.82, 0.02, 0.24), 0.02, stand, "y")
	m.box(Vector3(1.1, 0.085, 0.07), Vector3(1.14, 0.095, 0.08), m.paint("plastic", Color(0.2, 0.8, 0.3)))


func _bookcase(m: FurnitureModel, shelves: int, kind: String) -> void:
	var paint := m.paint("painted_wood", Color(0.92, 0.91, 0.87) if kind == "tall" else Color(0.32, 0.4, 0.46))
	var back := m.paint("plywood", Color(0.8, 0.78, 0.72))
	var w := m.size.x
	var h := m.size.y
	var d := m.size.z
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.025, h, d), paint)
	m.box(Vector3(w - 0.025, 0.0, 0.0), Vector3(w, h, d), paint)
	m.box(Vector3(0.0, h - 0.025, 0.0), Vector3(w, h, d), paint)
	m.box(Vector3(0.025, 0.0, 0.02), Vector3(w - 0.025, 0.08, 0.04), paint)
	m.box(Vector3(0.025, 0.0, d - 0.012), Vector3(w - 0.025, h, d), back)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var gap := (h - 0.1) / (shelves + 1)
	for i in shelves + 1:
		var y := 0.08 + i * gap
		m.box(Vector3(0.025, y, 0.0), Vector3(w - 0.025, y + 0.022, d - 0.012), paint)
		if i < shelves + 1 and y + gap < h - 0.03:
			_books(m, 0.04, w - 0.04, y + 0.022, minf(gap - 0.04, 0.3), 0.02, d - 0.03, rng)


## A row of books of varied height, thickness and colour, with the odd gap or lean.
func _books(m: FurnitureModel, x0: float, x1: float, y: float, max_h: float, z0: float, z1: float, rng: RandomNumberGenerator) -> void:
	var colors := [Color(0.55, 0.12, 0.1), Color(0.12, 0.25, 0.45), Color(0.15, 0.35, 0.2), Color(0.85, 0.78, 0.6), Color(0.2, 0.2, 0.22), Color(0.7, 0.45, 0.15), Color(0.4, 0.15, 0.35)]
	var x := x0
	while x < x1 - 0.03:
		var t := rng.randf_range(0.022, 0.05)
		if x + t > x1:
			break
		if rng.randf() < 0.08:
			x += rng.randf_range(0.04, 0.1)
			continue
		var bh := clampf(rng.randf_range(0.16, 0.3), 0.08, max_h)
		var depth := rng.randf_range(0.14, z1 - z0)
		var book := m.paint("paper", colors[rng.randi() % colors.size()].lightened(rng.randf_range(-0.1, 0.1)))
		m.box(Vector3(x, y, z1 - depth), Vector3(x + t, y + bh, z1), book)
		x += t + 0.002


func _display_cabinet(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.38, 0.25, 0.16), F.GRAIN)
	var glass := m.paint("glass", Color(0.69, 0.86, 0.92))
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	var china := m.paint("ceramic", Color(0.95, 0.95, 0.93))
	var w := 0.9
	var d := 0.42
	m.box(Vector3(0.0, 0.0, 0.02), Vector3(w, 0.12, d), walnut)
	m.box(Vector3(-0.0, 1.72, 0.0), Vector3(w, 1.8, d), walnut)
	m.box(Vector3(0.0, 0.12, 0.02), Vector3(0.04, 1.72, d), walnut)
	m.box(Vector3(w - 0.04, 0.12, 0.02), Vector3(w, 1.72, d), walnut)
	m.box(Vector3(0.04, 0.12, d - 0.02), Vector3(w - 0.04, 1.72, d), walnut)
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, 0.03), walnut)
	# Two glazed doors (frames + glass) and glass shelves with a few plates.
	for x in [0.04, w * 0.5]:
		m.box(Vector3(x, 0.12, 0.0), Vector3(x + w * 0.5 - 0.04, 1.72, 0.03), walnut)
		m.cut(Vector3(x + 0.05, 0.17, 0.0), Vector3(x + w * 0.5 - 0.09, 1.67, 0.03))
		m.box(Vector3(x + 0.05, 0.17, 0.012), Vector3(x + w * 0.5 - 0.09, 1.67, 0.022), glass)
		m.box(Vector3(x + (w * 0.5 - 0.11 if x < 0.1 else 0.03), 0.9, -0.012), Vector3(x + (w * 0.5 - 0.09 if x < 0.1 else 0.05), 1.0, 0.0), brass)
	for y in [0.55, 0.95, 1.35]:
		m.box(Vector3(0.04, y, 0.04), Vector3(w - 0.04, y + 0.012, d - 0.02), glass)
		for i in 3:
			m.cylinder(Vector3(0.2 + i * 0.25, y + 0.012, d - 0.06), "z", -0.012, 0.09, china)


func _sideboard(m: FurnitureModel) -> void:
	var body := m.paint("painted_wood", Color(0.42, 0.5, 0.44))
	var top := m.paint("oak", Color(0.64, 0.46, 0.28), F.GRAIN)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	m.box(Vector3(0.0, 0.12, 0.0), Vector3(1.6, 0.79, 0.46), body)
	m.rounded(Vector3(-0.0, 0.79, -0.0), Vector3(1.6, 0.82, 0.46), 0.01, top, "y")
	m.legs(0.0, 0.0, 1.6, 0.46, 0.12, 0.045, 0.03, top, true, 0.7)
	# Doors either side, three drawers in the middle.
	m.door_front(Vector3(0.02, 0.14, -0.02), Vector3(0.52, 0.77, 0.0), body, brass, false)
	m.door_front(Vector3(1.08, 0.14, -0.02), Vector3(1.58, 0.77, 0.0), body, brass, true)
	for i in 3:
		var y := 0.14 + i * 0.21
		m.drawer(Vector3(0.54, y, -0.02), Vector3(1.06, y + 0.2, 0.0), body, brass, "cup")


func _console_table(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.4, 0.26, 0.16), F.GRAIN)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	m.rounded(Vector3(0.0, 0.75, 0.0), Vector3(1.2, 0.78, 0.35), 0.01, walnut, "y")
	for x in [0.04, 1.13]:
		for z in [0.04, 0.28]:
			m.cylinder(Vector3(x + 0.015, 0.0, z + 0.015), "y", 0.75, 0.01, walnut, 0.016)
	m.box(Vector3(0.06, 0.64, 0.03), Vector3(1.14, 0.75, 0.32), walnut)
	m.drawer(Vector3(0.1, 0.65, 0.02), Vector3(0.58, 0.74, 0.04), walnut, brass, "knob")
	m.drawer(Vector3(0.62, 0.65, 0.02), Vector3(1.1, 0.74, 0.04), walnut, brass, "knob")
	m.box(Vector3(0.05, 0.12, 0.05), Vector3(1.15, 0.14, 0.3), walnut)


# --- Lighting and fittings

func _floor_lamp(m: FurnitureModel) -> void:
	var iron := m.paint("cast_iron", Color(0.15, 0.15, 0.16))
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	var shade := m.paint("fabric", Color(0.93, 0.89, 0.8), F.FABRIC)
	m.cylinder(Vector3(0.23, 0.0, 0.23), "y", 0.035, 0.16, iron, 0.14)
	m.cylinder(Vector3(0.23, 0.035, 0.23), "y", 1.18, 0.012, brass)
	m.cylinder(Vector3(0.23, 1.2, 0.23), "y", 0.06, 0.03, brass)
	# Open drum shade: a ring, not a solid lump.
	m.cylinder(Vector3(0.23, 1.22, 0.23), "y", 0.4, 0.23, shade, 0.17)
	m.cut_cylinder(Vector3(0.23, 1.22, 0.23), "y", 0.4, 0.2)
	m.cylinder(Vector3(0.23, 1.24, 0.23), "y", 0.06, 0.03, m.paint("glass", Color(0.95, 0.92, 0.8)))


func _table_lamp(m: FurnitureModel) -> void:
	var ceramic := m.paint("ceramic", Color(0.3, 0.42, 0.55))
	var shade := m.paint("fabric", Color(0.95, 0.93, 0.86), F.FABRIC)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	m.cylinder(Vector3(0.17, 0.0, 0.17), "y", 0.02, 0.08, brass)
	m.ellipsoid(Vector3(0.17, 0.13, 0.17), Vector3(0.09, 0.11, 0.09), ceramic)
	m.cylinder(Vector3(0.17, 0.22, 0.17), "y", 0.08, 0.012, brass)
	m.cylinder(Vector3(0.17, 0.3, 0.17), "y", 0.24, 0.17, shade, 0.11)
	m.cut_cylinder(Vector3(0.17, 0.3, 0.17), "y", 0.24, 0.145)


func _fireplace(m: FurnitureModel) -> void:
	var paint := m.paint("painted_wood", Color(0.93, 0.92, 0.88))
	var marble := m.paint("marble", Color(0.88, 0.87, 0.84), F.SPECKLE)
	var iron := m.paint("cast_iron", Color(0.12, 0.12, 0.13))
	# Hearth, slips, cast iron insert, pilasters, frieze and mantel shelf.
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(1.5, 0.05, 0.5), marble)
	m.box(Vector3(0.18, 0.05, 0.28), Vector3(1.32, 0.95, 0.32), marble)
	m.box(Vector3(0.38, 0.05, 0.3), Vector3(1.12, 0.78, 0.5), iron)
	m.cut(Vector3(0.48, 0.05, 0.3), Vector3(1.02, 0.62, 0.46))
	for i in 5:
		m.box(Vector3(0.52 + i * 0.11, 0.12, 0.34), Vector3(0.54 + i * 0.11, 0.3, 0.36), iron)
	for x in [0.0, 1.32]:
		m.box(Vector3(x, 0.05, 0.22), Vector3(x + 0.18, 1.05, 0.5), paint)
		m.box(Vector3(x + 0.03, 0.05, 0.2), Vector3(x + 0.15, 1.0, 0.22), paint)
	m.box(Vector3(0.18, 0.95, 0.24), Vector3(1.32, 1.12, 0.5), paint)
	m.rounded(Vector3(-0.0, 1.12, 0.12), Vector3(1.5, 1.2, 0.5), 0.02, paint, "y")


func _mantel_clock(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.36, 0.23, 0.14), F.GRAIN)
	var face := m.paint("ceramic", Color(0.96, 0.95, 0.9))
	var brass := m.paint("brass", Color(0.8, 0.64, 0.32), F.BRUSHED)
	var hands := m.paint("cast_iron", Color(0.05, 0.05, 0.05))
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.32, 0.03, 0.12), walnut)
	var outline := PackedVector2Array([Vector2(0.02, 0.03), Vector2(0.3, 0.03), Vector2(0.3, 0.14), Vector2(0.24, 0.22), Vector2(0.16, 0.25), Vector2(0.08, 0.22), Vector2(0.02, 0.14)])
	m.prism_xy(outline, 0.01, 0.11, walnut)
	m.cylinder(Vector3(0.16, 0.13, 0.0), "z", 0.012, 0.075, brass)
	m.cylinder(Vector3(0.16, 0.13, -0.002), "z", 0.012, 0.065, face)
	m.box(Vector3(0.155, 0.13, -0.004), Vector3(0.165, 0.18, 0.0), hands)
	m.box(Vector3(0.16, 0.125, -0.004), Vector3(0.2, 0.135, 0.0), hands)


func _coat_stand(m: FurnitureModel) -> void:
	var wood := m.paint("walnut", Color(0.38, 0.25, 0.15), F.GRAIN)
	# Three splayed feet, a turned pole, and pegs near the top.
	for angle in [0.0, TAU / 3.0, TAU * 2.0 / 3.0]:
		var dir := Vector2(cos(angle), sin(angle))
		for i in 8:
			var t := i / 7.0
			var p := Vector2(0.26, 0.26) + dir * (0.03 + t * 0.21)
			m.box(Vector3(p.x - 0.018, 0.0 + (1.0 - t) * 0.06, p.y - 0.018), Vector3(p.x + 0.018, 0.04 + (1.0 - t) * 0.06, p.y + 0.018), wood)
	m.cylinder(Vector3(0.26, 0.05, 0.26), "y", 1.7, 0.022, wood, 0.018)
	m.ellipsoid(Vector3(0.26, 1.78, 0.26), Vector3(0.035, 0.04, 0.035), wood)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var dir := Vector2(cos(angle), sin(angle))
		for i in 4:
			var p := Vector2(0.26, 0.26) + dir * (0.02 + i * 0.03)
			m.box(Vector3(p.x - 0.01, 1.58 + i * 0.025, p.y - 0.01), Vector3(p.x + 0.01, 1.6 + i * 0.025, p.y + 0.01), wood)


func _magazine_rack(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.4, 0.27, 0.17), F.GRAIN)
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.42, 0.04, 0.3), walnut)
	for z in [0.03, 0.14, 0.25]:
		m.box(Vector3(0.0, 0.04, z), Vector3(0.42, 0.3, z + 0.015), walnut)
	m.box(Vector3(0.0, 0.04, 0.0), Vector3(0.02, 0.44, 0.3), walnut)
	m.box(Vector3(0.4, 0.04, 0.0), Vector3(0.42, 0.44, 0.3), walnut)
	m.cylinder(Vector3(0.0, 0.42, 0.15), "x", 0.42, 0.012, walnut)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for slot in 2:
		for i in 4:
			var z := 0.06 + slot * 0.11 + i * 0.018
			var tone := Color(rng.randf_range(0.3, 0.95), rng.randf_range(0.3, 0.9), rng.randf_range(0.3, 0.9))
			m.box(Vector3(0.05, 0.04, z), Vector3(0.37, rng.randf_range(0.28, 0.36), z + 0.008), m.paint("paper", tone))


func _wood_shelving(m: FurnitureModel) -> void:
	var pine := m.paint("pine", Color(0.8, 0.64, 0.42), F.GRAIN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for x in [0.0, 0.96]:
		for z in [0.0, 0.32]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.04, 1.8, z + 0.04), pine)
	for i in 5:
		var y := 0.06 + i * 0.42
		for j in 3:
			m.box(Vector3(0.0, y, 0.01 + j * 0.115), Vector3(1.0, y + 0.024, 0.11 + j * 0.115), pine)
		if i < 4:
			_books(m, 0.06, 0.6, y + 0.024, 0.32, 0.04, 0.33, rng)
	# Cross braces at the back.
	for i in 12:
		var t := i / 11.0
		var x := lerpf(0.04, 0.92, t)
		var y := lerpf(0.1, 1.7, t)
		m.box(Vector3(x, y, 0.33), Vector3(x + 0.08, y + 0.04, 0.35), pine)


func _room_divider(m: FurnitureModel) -> void:
	var frame := m.paint("walnut", Color(0.36, 0.24, 0.15), F.GRAIN)
	var weave := m.paint("wicker", Color(0.74, 0.58, 0.36), F.FABRIC)
	# Three hinged panels folded in a zigzag.
	var panels := [[0.0, 0.0, 0.5, 0.36], [0.5, 0.36, 1.0, 0.02], [1.0, 0.02, 1.5, 0.38]]
	for p in panels:
		var a := Vector2(p[0], p[1])
		var b := Vector2(p[2], p[3])
		var steps := 24
		for i in steps:
			var t := float(i) / steps
			var c := a.lerp(b, t)
			var edge := i == 0 or i == steps - 1
			for y in [0.0]:
				m.box(Vector3(c.x - 0.012, 0.0, c.y - 0.012), Vector3(c.x + 0.012, 1.75, c.y + 0.012), weave if not edge else frame)
			m.box(Vector3(c.x - 0.014, 0.0, c.y - 0.014), Vector3(c.x + 0.014, 0.08, c.y + 0.014), frame)
			m.box(Vector3(c.x - 0.014, 1.68, c.y - 0.014), Vector3(c.x + 0.014, 1.75, c.y + 0.014), frame)
			m.box(Vector3(c.x - 0.014, 0.86, c.y - 0.014), Vector3(c.x + 0.014, 0.9, c.y + 0.014), frame)
