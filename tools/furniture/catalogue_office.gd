extends RefCounted
## Office and study (15).

const CATEGORY := "Office"
const F := FurnitureModel.Finish
const P := preload("res://tools/furniture/furniture_parts.gd")

const GRAPHITE := Color(0.22, 0.23, 0.25)
const LIGHT_GREY := Color(0.82, 0.83, 0.84)
const BEECH := Color(0.84, 0.7, 0.5)

const MASSES := {
	"executive_desk": 90.0, "writing_desk": 25.0, "computer_desk": 35.0, "office_chair": 14.0,
	"visitor_chair": 7.0, "filing_cabinet": 25.0, "filing_cabinet_tall": 40.0, "office_bookshelf": 35.0,
	"storage_cupboard": 45.0, "computer_monitor": 5.0, "computer_tower": 8.0, "keyboard": 0.8,
	"printer": 9.0, "desk_lamp": 1.5, "whiteboard": 12.0,
}


func models() -> Array:
	return [
		_m("executive_desk", "Executive Desk", Vector3(1.8, 0.78, 0.9), _executive_desk),
		_m("writing_desk", "Writing Desk", Vector3(1.0, 0.95, 0.55), _writing_desk),
		_m("computer_desk", "Computer Desk", Vector3(1.4, 0.75, 0.75), _computer_desk),
		_m("office_chair", "Office Chair", Vector3(0.66, 1.1, 0.66), _office_chair, {"voxel": 0.02}),
		_m("visitor_chair", "Visitor Chair", Vector3(0.55, 0.85, 0.55), _visitor_chair),
		_m("filing_cabinet", "Filing Cabinet", Vector3(0.47, 0.72, 0.62), func(m): _filing(m, 2)),
		_m("filing_cabinet_tall", "Tall Filing Cabinet", Vector3(0.47, 1.32, 0.62), func(m): _filing(m, 4)),
		_m("office_bookshelf", "Office Bookshelf", Vector3(0.8, 1.8, 0.35), _bookshelf, {"voxel": 0.03}),
		_m("storage_cupboard", "Storage Cupboard", Vector3(0.9, 1.8, 0.45), _cupboard, {"voxel": 0.03}),
		_m("computer_monitor", "Computer Monitor", Vector3(0.62, 0.48, 0.22), _monitor),
		_m("computer_tower", "Desktop Computer Tower", Vector3(0.2, 0.44, 0.44), _tower),
		_m("keyboard", "Keyboard", Vector3(0.44, 0.035, 0.14), _keyboard, {"voxel": 0.008, "hollow": false}),
		_m("printer", "Printer", Vector3(0.45, 0.3, 0.42), _printer, {"voxel": 0.016}),
		_m("desk_lamp", "Desk Lamp", Vector3(0.36, 0.5, 0.18), _desk_lamp),
		_m("whiteboard", "Whiteboard", Vector3(1.2, 1.85, 0.6), _whiteboard, {"voxel": 0.025}),
	]


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


func _executive_desk(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.36, 0.23, 0.14), F.GRAIN)
	var leather := m.paint("leather", Color(0.15, 0.28, 0.2), F.FABRIC)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	# Twin pedestals of drawers, a modesty panel, an inlaid leather top.
	for x in [0.0, 1.32]:
		P.carcass(m, Vector3(x, 0.06, 0.02), Vector3(x + 0.48, 0.74, 0.9), 0.025, walnut)
		m.box(Vector3(x, 0.0, 0.02), Vector3(x + 0.48, 0.06, 0.88), walnut)
		for i in 3:
			var y := 0.08 + i * 0.22
			m.drawer(Vector3(x + 0.01, y, 0.0), Vector3(x + 0.47, y + 0.21, 0.025), walnut, brass, "bar")
	m.box(Vector3(0.48, 0.25, 0.8), Vector3(1.32, 0.74, 0.83), walnut)
	m.drawer(Vector3(0.5, 0.64, 0.02), Vector3(1.3, 0.73, 0.045), walnut, brass, "knob")
	m.rounded(Vector3(-0.02, 0.74, -0.02), Vector3(1.82, 0.78, 0.92), 0.012, walnut, "y")
	m.repaint(Vector3(0.1, 0.77, 0.08), Vector3(1.7, 0.78, 0.82), leather)


func _writing_desk(m: FurnitureModel) -> void:
	var mahogany := m.paint("walnut", Color(0.45, 0.2, 0.12), F.GRAIN)
	var leather := m.paint("leather", Color(0.45, 0.12, 0.1), F.FABRIC)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	m.rounded(Vector3(0.0, 0.72, 0.0), Vector3(1.0, 0.75, 0.55), 0.01, mahogany, "y")
	m.repaint(Vector3(0.08, 0.74, 0.06), Vector3(0.92, 0.75, 0.45), leather)
	for corner in [Vector2(0.03, 0.03), Vector2(0.93, 0.03), Vector2(0.03, 0.48), Vector2(0.93, 0.48)]:
		m.cylinder(Vector3(corner.x + 0.02, 0.0, corner.y + 0.02), "y", 0.72, 0.014, mahogany, 0.024)
	m.box(Vector3(0.05, 0.62, 0.04), Vector3(0.95, 0.72, 0.52), mahogany)
	m.drawer(Vector3(0.08, 0.63, 0.02), Vector3(0.92, 0.71, 0.04), mahogany, brass, "knob")
	# Gallery of pigeonholes along the back.
	m.box(Vector3(0.0, 0.75, 0.42), Vector3(1.0, 0.95, 0.55), mahogany)
	for i in 6:
		var x := 0.05 + i * 0.155
		m.cut(Vector3(x, 0.77, 0.42), Vector3(x + 0.13, 0.93, 0.53))
		m.box(Vector3(x + 0.01, 0.77, 0.44), Vector3(x + 0.12, 0.78 + (i % 3) * 0.03, 0.52), m.paint("paper", Color(0.92, 0.9, 0.84)))


func _computer_desk(m: FurnitureModel) -> void:
	var top := m.paint("chipboard", Color(0.92, 0.91, 0.88))
	var frame := m.paint("painted_steel", GRAPHITE)
	m.rounded(Vector3(0.0, 0.72, 0.0), Vector3(1.4, 0.75, 0.75), 0.012, top, "y")
	# Steel T-legs with a crossbar, a cable tray, and a small drawer pedestal.
	for x in [0.05, 1.3]:
		m.box(Vector3(x, 0.0, 0.05), Vector3(x + 0.05, 0.03, 0.7), frame)
		m.box(Vector3(x, 0.03, 0.35), Vector3(x + 0.05, 0.72, 0.4), frame)
		m.box(Vector3(x, 0.68, 0.08), Vector3(x + 0.05, 0.72, 0.68), frame)
	m.box(Vector3(0.1, 0.6, 0.55), Vector3(1.3, 0.64, 0.6), frame)
	m.box(Vector3(0.3, 0.55, 0.6), Vector3(1.1, 0.68, 0.7), frame)
	P.carcass(m, Vector3(0.75, 0.05, 0.05), Vector3(1.2, 0.7, 0.65), 0.02, top)
	for i in 3:
		var y := 0.06 + i * 0.21
		m.drawer(Vector3(0.76, y, 0.03), Vector3(1.19, y + 0.2, 0.05), top, frame, "bar")


func _office_chair(m: FurnitureModel) -> void:
	var black := m.paint("plastic", Color(0.08, 0.08, 0.09))
	var mesh_back := m.paint("fabric", Color(0.15, 0.16, 0.18), F.FABRIC)
	var seat := m.paint("fabric", Color(0.2, 0.22, 0.26), F.FABRIC)
	var chrome := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	# Five-star base on castors, gas lift, seat, arms and a mesh back.
	for i in 5:
		var angle := TAU * i / 5.0
		var dir := Vector2(cos(angle), sin(angle))
		for s in 9:
			var p := Vector2(0.33, 0.33) + dir * (0.03 + s * 0.032)
			m.box(Vector3(p.x - 0.018, 0.06, p.y - 0.018), Vector3(p.x + 0.018, 0.1, p.y + 0.018), black)
		var tip := Vector2(0.33, 0.33) + dir * 0.3
		m.ellipsoid(Vector3(tip.x, 0.03, tip.y), Vector3(0.03, 0.03, 0.03), black)
	m.cylinder(Vector3(0.33, 0.1, 0.33), "y", 0.32, 0.025, chrome)
	m.rounded(Vector3(0.08, 0.42, 0.1), Vector3(0.58, 0.5, 0.58), 0.04, seat)
	for x in [0.06, 0.56]:
		m.box(Vector3(x, 0.42, 0.3), Vector3(x + 0.04, 0.62, 0.34), black)
		m.rounded(Vector3(x - 0.01, 0.62, 0.16), Vector3(x + 0.05, 0.65, 0.42), 0.012, black)
	m.box(Vector3(0.31, 0.46, 0.55), Vector3(0.35, 0.62, 0.62), black)
	m.rounded(Vector3(0.12, 0.58, 0.56), Vector3(0.54, 1.1, 0.64), 0.06, black)
	m.repaint(Vector3(0.15, 0.61, 0.55), Vector3(0.51, 1.07, 0.65), mesh_back)


func _visitor_chair(m: FurnitureModel) -> void:
	var frame := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	var seat := m.paint("fabric", Color(0.2, 0.32, 0.48), F.FABRIC)
	# Cantilever frame: a continuous tube forming the base, front legs and arms.
	for x in [0.04, 0.49]:
		m.cylinder(Vector3(x, 0.01, 0.02), "z", 0.5, 0.012, frame)
		m.cylinder(Vector3(x, 0.01, 0.04), "y", 0.43, 0.012, frame)
		m.cylinder(Vector3(x, 0.44, 0.04), "z", 0.45, 0.012, frame)
		m.cylinder(Vector3(x, 0.44, 0.49), "y", 0.4, 0.012, frame)
	# Rear crossbar tying the two runners together.
	m.cylinder(Vector3(0.03, 0.01, 0.5), "x", 0.47, 0.012, frame)
	m.rounded(Vector3(0.05, 0.42, 0.04), Vector3(0.5, 0.48, 0.5), 0.025, seat)
	m.rounded(Vector3(0.05, 0.5, 0.46), Vector3(0.5, 0.84, 0.52), 0.025, seat)


func _filing(m: FurnitureModel, drawers: int) -> void:
	var body := m.paint("painted_steel", LIGHT_GREY)
	var steel := m.paint("chrome", Color(0.75, 0.76, 0.78), F.BRUSHED)
	var label := m.paint("paper", Color(0.96, 0.95, 0.9))
	var h := m.size.y
	P.carcass(m, Vector3(0.0, 0.02, 0.0), Vector3(0.47, h, 0.62), 0.015, body)
	var each := (h - 0.04) / drawers
	for i in drawers:
		var y := 0.03 + i * each
		var drawer := m.drawer(Vector3(0.008, y, -0.02), Vector3(0.462, y + each - 0.008, 0.0), body, steel, "cup")
		# The label slides out with its drawer.
		m.in_part(drawer)
		m.box(Vector3(0.18, y + each * 0.62, -0.024), Vector3(0.29, y + each * 0.7, -0.02), label)
		m.end_part()
	m.box(Vector3(0.0, 0.0, 0.02), Vector3(0.47, 0.02, 0.6), m.paint("rubber", Color(0.1, 0.1, 0.1)))
	m.cylinder(Vector3(0.38, h - 0.06, -0.02), "z", -0.008, 0.012, steel)


func _bookshelf(m: FurnitureModel) -> void:
	var oak := m.paint("oak", Color(0.68, 0.5, 0.32), F.GRAIN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(0.8, 1.8, 0.35), 0.025, oak)
	for i in 5:
		var y := 0.06 + i * 0.35
		m.box(Vector3(0.025, y, 0.0), Vector3(0.775, y + 0.025, 0.33), oak)
		if i < 4:
			if i == 2:
				# Box files on one shelf.
				for j in 6:
					m.box(Vector3(0.04 + j * 0.12, y + 0.025, 0.04), Vector3(0.13 + j * 0.12, y + 0.31, 0.32), m.paint("cardboard", [Color(0.2, 0.3, 0.55), Color(0.55, 0.15, 0.12)][j % 2]))
			else:
				P.books(m, 0.04, 0.76, y + 0.025, 0.3, 0.03, 0.32, rng)


func _cupboard(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", LIGHT_GREY)
	var door := m.paint("painted_steel", Color(0.78, 0.79, 0.8))
	var steel := m.paint("chrome", Color(0.75, 0.76, 0.78), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(0.9, 1.8, 0.45), 0.02, body)
	for y in [0.4, 0.8, 1.2]:
		m.box(Vector3(0.02, y, 0.02), Vector3(0.88, y + 0.02, 0.43), body)
	for x in [0.0, 0.452]:
		m.door_front(Vector3(x, 0.01, -0.02), Vector3(x + 0.448, 1.79, 0.0), door, steel, x > 0.1, false)
	m.box(Vector3(0.44, 0.88, -0.03), Vector3(0.46, 1.02, -0.02), steel)
	for x in [0.05, 0.5]:
		for i in 6:
			m.box(Vector3(x, 1.55 + i * 0.03, -0.022), Vector3(x + 0.35, 1.56 + i * 0.03, -0.02), m.paint("painted_steel", Color(0.6, 0.61, 0.62)))


func _monitor(m: FurnitureModel) -> void:
	var black := m.paint("electronics", Color(0.07, 0.07, 0.08))
	var screen := m.paint("screen", Color(0.05, 0.08, 0.12))
	var silver := m.paint("aluminium", Color(0.6, 0.61, 0.63), F.BRUSHED)
	m.box(Vector3(0.0, 0.12, 0.06), Vector3(0.62, 0.48, 0.09), black)
	m.box(Vector3(0.012, 0.135, 0.055), Vector3(0.608, 0.468, 0.06), screen)
	m.rounded(Vector3(0.16, 0.18, 0.09), Vector3(0.46, 0.42, 0.12), 0.02, black)
	m.box(Vector3(0.29, 0.02, 0.1), Vector3(0.33, 0.22, 0.13), silver)
	m.rounded(Vector3(0.19, 0.0, 0.02), Vector3(0.43, 0.02, 0.22), 0.015, silver, "y")
	m.box(Vector3(0.55, 0.125, 0.052), Vector3(0.56, 0.13, 0.056), m.paint("plastic", Color(0.3, 0.6, 1.0)))


func _tower(m: FurnitureModel) -> void:
	var case := m.paint("painted_steel", Color(0.1, 0.1, 0.11))
	var front := m.paint("plastic", Color(0.16, 0.16, 0.18))
	var glass := m.paint("glass", Color(0.3, 0.35, 0.4))
	P.appliance(m, Vector3(0.0, 0.02, 0.0), Vector3(0.2, 0.44, 0.44), case, 0.006)
	m.box(Vector3(0.0, 0.02, -0.01), Vector3(0.2, 0.44, 0.0), front)
	for i in 8:
		m.box(Vector3(0.03, 0.1 + i * 0.03, -0.014), Vector3(0.17, 0.11 + i * 0.03, -0.01), case)
	m.cylinder(Vector3(0.1, 0.4, -0.01), "z", -0.006, 0.012, m.paint("plastic", Color(0.3, 0.6, 1.0)))
	m.box(Vector3(0.2, 0.08, 0.06), Vector3(0.202, 0.4, 0.4), glass)
	for x in [0.02, 0.15]:
		m.box(Vector3(x, 0.0, 0.04), Vector3(x + 0.03, 0.02, 0.4), front)


func _keyboard(m: FurnitureModel) -> void:
	var body := m.paint("plastic", Color(0.12, 0.12, 0.13))
	var key := m.paint("plastic", Color(0.25, 0.25, 0.27))
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.44, 0.02, 0.14), body)
	for row in 5:
		var z := 0.015 + row * 0.022
		var x := 0.012 + (row % 2) * 0.006
		while x < 0.43:
			var wide := 0.11 if (row == 4 and x > 0.12 and x < 0.2) else 0.016
			m.box(Vector3(x, 0.02, z), Vector3(x + wide, 0.03, z + 0.016), key)
			x += wide + 0.004


func _printer(m: FurnitureModel) -> void:
	var body := m.paint("plastic", Color(0.9, 0.9, 0.88))
	var dark := m.paint("plastic", Color(0.25, 0.26, 0.28))
	var paper := m.paint("paper", Color(0.98, 0.98, 0.97))
	P.appliance(m, Vector3(0.0, 0.0, 0.04), Vector3(0.45, 0.24, 0.42), body, 0.02)
	m.box(Vector3(0.06, 0.04, -0.02), Vector3(0.39, 0.1, 0.06), dark)
	m.box(Vector3(0.09, 0.08, -0.04), Vector3(0.36, 0.09, 0.06), paper)
	# Paper feed tray standing up at the back with a stack of paper.
	m.box(Vector3(0.08, 0.24, 0.32), Vector3(0.37, 0.3, 0.42), dark)
	m.box(Vector3(0.1, 0.24, 0.34), Vector3(0.35, 0.29, 0.4), paper)
	m.box(Vector3(0.3, 0.24, 0.06), Vector3(0.42, 0.25, 0.14), dark)
	m.box(Vector3(0.32, 0.25, 0.08), Vector3(0.36, 0.255, 0.1), m.paint("plastic", Color(0.2, 0.8, 0.3)))


func _desk_lamp(m: FurnitureModel) -> void:
	var metal := m.paint("painted_steel", Color(0.15, 0.3, 0.32))
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	# A broad cast iron foot keeps the cantilevered arm from tipping it over.
	m.cylinder(Vector3(0.09, 0.0, 0.09), "y", 0.03, 0.09, m.paint("cast_iron", Color(0.12, 0.2, 0.22)))
	# Two arm sections and a conical shade, angled out over the desk.
	for i in 12:
		var t := i / 11.0
		m.box(Vector3(0.06, 0.025 + t * 0.3, 0.085), Vector3(0.08, 0.045 + t * 0.3, 0.095), metal)
	for i in 12:
		var t := i / 11.0
		m.box(Vector3(0.07 + t * 0.12, 0.32 + t * 0.06, 0.085), Vector3(0.09 + t * 0.12, 0.34 + t * 0.06, 0.095), metal)
	m.ellipsoid(Vector3(0.07, 0.33, 0.09), Vector3(0.018, 0.018, 0.018), brass)
	m.cylinder(Vector3(0.21, 0.4, 0.09), "y", -0.11, 0.03, metal, 0.07)
	m.cut_cylinder(Vector3(0.21, 0.29, 0.09), "y", 0.08, 0.055)


func _whiteboard(m: FurnitureModel) -> void:
	var frame := m.paint("aluminium", Color(0.78, 0.79, 0.8), F.BRUSHED)
	var board := m.paint("plastic", Color(0.98, 0.98, 0.97))
	var stand := m.paint("painted_steel", Color(0.3, 0.31, 0.33))
	var marker := m.paint("plastic", Color(0.1, 0.2, 0.7))
	# Mobile whiteboard on a wheeled A-frame, with a marker tray and a few scribbles.
	m.box(Vector3(0.0, 0.7, 0.28), Vector3(1.2, 1.85, 0.32), frame)
	m.box(Vector3(0.02, 0.72, 0.275), Vector3(1.18, 1.83, 0.28), board)
	for i in 3:
		m.repaint(Vector3(0.15, 1.6 - i * 0.12, 0.27), Vector3(0.15 + 0.3 + i * 0.12, 1.62 - i * 0.12, 0.28), marker)
	m.box(Vector3(0.1, 0.68, 0.22), Vector3(1.1, 0.7, 0.3), frame)
	for x in [0.02, 1.15]:
		m.box(Vector3(x, 0.08, 0.27), Vector3(x + 0.03, 1.4, 0.33), stand)
		m.box(Vector3(x, 0.05, 0.0), Vector3(x + 0.03, 0.08, 0.6), stand)
		for z in [0.02, 0.56]:
			m.cylinder(Vector3(x + 0.015, 0.025, z), "x", 0.03, 0.025, m.paint("rubber", Color(0.1, 0.1, 0.1)))
