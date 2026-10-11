extends RefCounted
## Laboratory (15). Epoxy worktops, steel frames, safety colours.

const CATEGORY := "Laboratory"
const F := FurnitureModel.Finish
const P := preload("res://tools/furniture/furniture_parts.gd")

const EPOXY := Color(0.15, 0.16, 0.17)
const LAB_GREY := Color(0.78, 0.8, 0.81)
const SAFETY_YELLOW := Color(0.92, 0.75, 0.1)
const LAB_BLUE := Color(0.2, 0.38, 0.6)

const MASSES := {
	"lab_workbench": 140.0, "lab_stool": 6.0, "chemical_cabinet": 70.0, "fume_cupboard": 250.0,
	"microscope": 9.0, "centrifuge": 30.0, "oscilloscope": 8.0, "lab_terminal": 25.0,
	"instrument_rack": 60.0, "glassware_rack": 3.0, "test_tube_stand": 1.0, "lab_sink": 60.0,
	"specimen_cabinet": 55.0, "equipment_trolley": 20.0, "lab_shelving": 30.0,
}


func models() -> Array:
	return [
		_m("lab_workbench", "Laboratory Workbench", Vector3(1.8, 1.55, 0.8), _workbench, {"voxel": 0.03}),
		_m("lab_stool", "Laboratory Stool", Vector3(0.4, 0.75, 0.4), _stool),
		_m("chemical_cabinet", "Chemical Storage Cabinet", Vector3(0.9, 1.8, 0.5), _chemical_cabinet, {"voxel": 0.03}),
		_m("fume_cupboard", "Fume Cupboard", Vector3(1.5, 2.3, 0.85), _fume_cupboard, {"voxel": 0.035}),
		_m("microscope", "Microscope", Vector3(0.22, 0.4, 0.32), _microscope),
		_m("centrifuge", "Centrifuge", Vector3(0.5, 0.36, 0.55), _centrifuge),
		_m("oscilloscope", "Oscilloscope", Vector3(0.4, 0.22, 0.32), _oscilloscope),
		_m("lab_terminal", "Laboratory Computer Terminal", Vector3(0.7, 1.4, 0.6), _terminal, {"voxel": 0.022}),
		_m("instrument_rack", "Scientific Instrument Rack", Vector3(0.6, 1.6, 0.7), _instrument_rack, {"voxel": 0.025}),
		_m("glassware_rack", "Glassware Rack", Vector3(0.5, 0.5, 0.2), _glassware_rack),
		_m("test_tube_stand", "Test Tube Stand", Vector3(0.3, 0.16, 0.1), _test_tube_stand),
		_m("lab_sink", "Laboratory Sink", Vector3(1.2, 1.15, 0.7), _lab_sink, {"voxel": 0.025}),
		_m("specimen_cabinet", "Specimen Cabinet", Vector3(0.8, 1.9, 0.45), _specimen_cabinet, {"voxel": 0.03}),
		_m("equipment_trolley", "Equipment Trolley", Vector3(0.8, 0.95, 0.5), _trolley, {"voxel": 0.022}),
		_m("lab_shelving", "Laboratory Shelving Unit", Vector3(1.2, 1.9, 0.45), _shelving, {"voxel": 0.03}),
	]


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


func _workbench(m: FurnitureModel) -> void:
	var frame := m.paint("painted_steel", LAB_GREY)
	var top := m.paint("stone", EPOXY, F.SPECKLE)
	var front := m.paint("painted_steel", LAB_BLUE)
	var steel := m.paint("chrome", Color(0.75, 0.76, 0.78), F.BRUSHED)
	var glass := m.paint("glass", Color(0.75, 0.88, 0.92))
	# Steel C-frame bench, under-bench drawer unit, epoxy top, reagent shelf with service spine.
	for x in [0.04, 1.71]:
		m.box(Vector3(x, 0.0, 0.05), Vector3(x + 0.05, 0.9, 0.1), frame)
		m.box(Vector3(x, 0.0, 0.65), Vector3(x + 0.05, 0.9, 0.7), frame)
		m.box(Vector3(x, 0.0, 0.05), Vector3(x + 0.05, 0.05, 0.7), frame)
	m.box(Vector3(0.04, 0.85, 0.05), Vector3(1.76, 0.9, 0.1), frame)
	P.carcass(m, Vector3(1.2, 0.05, 0.08), Vector3(1.7, 0.85, 0.7), 0.02, frame)
	for i in 3:
		var y := 0.06 + i * 0.26
		m.drawer(Vector3(1.21, y, 0.06), Vector3(1.69, y + 0.25, 0.08), front, steel, "bar")
	m.box(Vector3(0.0, 0.9, 0.0), Vector3(1.8, 0.94, 0.8), top)
	m.box(Vector3(0.1, 0.94, 0.7), Vector3(1.7, 1.55, 0.78), frame)
	m.box(Vector3(0.1, 1.24, 0.5), Vector3(1.7, 1.26, 0.78), frame)
	for i in 7:
		var x := 0.2 + i * 0.2
		m.cylinder(Vector3(x, 1.26, 0.64), "y", 0.15 + (i % 3) * 0.03, 0.035, m.paint("glass", [Color(0.75, 0.88, 0.92), Color(0.6, 0.4, 0.2), Color(0.8, 0.9, 0.7)][i % 3]))
	# Gas taps and sockets on the spine.
	for i in 4:
		m.box(Vector3(0.3 + i * 0.35, 1.0, 0.68), Vector3(0.38 + i * 0.35, 1.08, 0.7), m.paint("plastic", Color(0.95, 0.95, 0.93)))
		m.cylinder(Vector3(0.45 + i * 0.35, 1.04, 0.7), "z", -0.05, 0.01, steel)
	m.box(Vector3(0.3, 0.94, 0.3), Vector3(0.36, 1.08, 0.36), glass)


func _stool(m: FurnitureModel) -> void:
	var frame := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	var seat := m.paint("plastic", Color(0.12, 0.13, 0.14))
	for i in 5:
		var angle := TAU * i / 5.0
		var dir := Vector2(cos(angle), sin(angle))
		for s in 6:
			var p := Vector2(0.2, 0.2) + dir * (0.02 + s * 0.03)
			m.box(Vector3(p.x - 0.014, 0.04, p.y - 0.014), Vector3(p.x + 0.014, 0.07, p.y + 0.014), frame)
		var tip := Vector2(0.2, 0.2) + dir * 0.19
		m.ellipsoid(Vector3(tip.x, 0.025, tip.y), Vector3(0.025, 0.025, 0.025), seat)
	m.cylinder(Vector3(0.2, 0.07, 0.2), "y", 0.58, 0.022, frame)
	m.cylinder(Vector3(0.2, 0.3, 0.2), "y", 0.015, 0.16, frame)
	m.cut_cylinder(Vector3(0.2, 0.3, 0.2), "y", 0.015, 0.14)
	m.cylinder(Vector3(0.2, 0.65, 0.2), "y", 0.08, 0.19, seat)


func _chemical_cabinet(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", SAFETY_YELLOW)
	var label := m.paint("plastic", Color(0.85, 0.1, 0.1))
	var steel := m.paint("chrome", Color(0.75, 0.76, 0.78), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.05, 0.0), Vector3(0.9, 1.8, 0.5), 0.02, body)
	for x in [0.0, 0.452]:
		m.door_front(Vector3(x, 0.06, -0.02), Vector3(x + 0.448, 1.78, 0.0), body, steel, x > 0.1, false)
	# Warning labels and vents.
	for x in [0.15, 0.6]:
		var diamond := PackedVector2Array([Vector2(x, 1.35), Vector2(x + 0.08, 1.43), Vector2(x, 1.51), Vector2(x - 0.08, 1.43)])
		m.prism_xy(diamond, -0.025, -0.02, label)
	for y in [0.15, 1.65]:
		for i in 6:
			m.box(Vector3(0.3 + i * 0.05, y, -0.024), Vector3(0.33 + i * 0.05, y + 0.06, -0.02), steel)
	m.box(Vector3(0.0, 0.0, 0.02), Vector3(0.9, 0.05, 0.48), m.paint("painted_steel", Color(0.2, 0.2, 0.2)))


func _fume_cupboard(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.92, 0.92, 0.9))
	var top := m.paint("stone", EPOXY, F.SPECKLE)
	var glass := m.paint("glass", Color(0.75, 0.88, 0.92))
	var steel := m.paint("chrome", Color(0.75, 0.76, 0.78), F.BRUSHED)
	var panel := m.paint("electronics", Color(0.15, 0.16, 0.18))
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(1.5, 0.9, 0.85), 0.025, body)
	for x in [0.0, 0.75]:
		m.door_front(Vector3(x + 0.01, 0.02, -0.02), Vector3(x + 0.74, 0.88, 0.0), body, steel, x > 0.1, false)
	m.box(Vector3(0.0, 0.9, 0.0), Vector3(1.5, 0.95, 0.85), top)
	# Side walls, back baffle, top hood with extract duct, and a sliding glass sash.
	m.box(Vector3(0.0, 0.95, 0.0), Vector3(0.1, 2.0, 0.85), body)
	m.box(Vector3(1.4, 0.95, 0.0), Vector3(1.5, 2.0, 0.85), body)
	m.box(Vector3(0.1, 0.95, 0.8), Vector3(1.4, 2.0, 0.85), body)
	m.box(Vector3(0.0, 1.85, 0.0), Vector3(1.5, 2.0, 0.85), body)
	m.cylinder(Vector3(0.75, 2.0, 0.45), "y", 0.3, 0.14, steel)
	m.box(Vector3(0.12, 1.25, 0.03), Vector3(1.38, 1.83, 0.05), body)
	m.box(Vector3(0.14, 1.27, 0.035), Vector3(1.36, 1.81, 0.045), glass)
	m.box(Vector3(0.12, 1.24, 0.01), Vector3(1.38, 1.27, 0.03), steel)
	m.box(Vector3(1.42, 1.3, -0.01), Vector3(1.49, 1.6, 0.0), panel)
	m.box(Vector3(1.43, 1.52, -0.015), Vector3(1.48, 1.57, -0.01), m.paint("plastic", Color(0.2, 0.9, 0.3)))
	m.cylinder(Vector3(0.4, 0.95, 0.5), "y", 0.2, 0.05, m.paint("glass", Color(0.6, 0.85, 0.6)))


func _microscope(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.93, 0.93, 0.92))
	var black := m.paint("cast_iron", Color(0.1, 0.1, 0.11))
	var chrome := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	m.rounded(Vector3(0.01, 0.0, 0.0), Vector3(0.21, 0.04, 0.3), 0.015, body)
	# Arm rising at the back, stage, revolving nosepiece, binocular head.
	m.box(Vector3(0.07, 0.04, 0.22), Vector3(0.15, 0.32, 0.29), body)
	m.box(Vector3(0.05, 0.14, 0.06), Vector3(0.17, 0.155, 0.22), black)
	m.cylinder(Vector3(0.11, 0.24, 0.13), "y", 0.04, 0.035, chrome)
	for i in 3:
		var angle := TAU * i / 3.0
		m.cylinder(Vector3(0.11 + cos(angle) * 0.02, 0.2, 0.13 + sin(angle) * 0.02), "y", 0.04, 0.008, chrome)
	m.rounded(Vector3(0.07, 0.28, 0.08), Vector3(0.15, 0.34, 0.24), 0.015, body)
	for x in [0.09, 0.13]:
		m.cylinder(Vector3(x, 0.33, 0.1), "y", 0.07, 0.012, black)
	m.cylinder(Vector3(0.05, 0.09, 0.25), "x", -0.03, 0.022, black)
	m.cylinder(Vector3(0.17, 0.09, 0.25), "x", 0.03, 0.022, black)


func _centrifuge(m: FurnitureModel) -> void:
	var body := m.paint("plastic", Color(0.9, 0.9, 0.88))
	var lid := m.paint("plastic", Color(0.3, 0.45, 0.65))
	var panel := m.paint("electronics", Color(0.15, 0.16, 0.18))
	P.appliance(m, Vector3(0.0, 0.02, 0.0), Vector3(0.5, 0.28, 0.55), body, 0.04)
	# Domed lid over the rotor.
	m.ellipsoid(Vector3(0.25, 0.28, 0.3), Vector3(0.2, 0.07, 0.2), lid)
	m.box(Vector3(0.05, 0.08, -0.008), Vector3(0.45, 0.22, 0.0), panel)
	m.box(Vector3(0.08, 0.15, -0.012), Vector3(0.24, 0.2, -0.008), m.paint("screen", Color(0.1, 0.4, 0.3)))
	for i in 4:
		m.cylinder(Vector3(0.28 + i * 0.04, 0.12, -0.008), "z", -0.008, 0.012, m.paint("plastic", Color(0.8, 0.8, 0.82)))
	for x in [0.05, 0.4]:
		m.box(Vector3(x, 0.0, 0.08), Vector3(x + 0.05, 0.02, 0.5), panel)


func _oscilloscope(m: FurnitureModel) -> void:
	var case := m.paint("painted_steel", Color(0.55, 0.58, 0.6))
	var front := m.paint("electronics", Color(0.15, 0.16, 0.18))
	var screen := m.paint("screen", Color(0.05, 0.15, 0.1))
	var trace := m.paint("plastic", Color(0.3, 1.0, 0.4))
	P.appliance(m, Vector3(0.0, 0.0, 0.02), Vector3(0.4, 0.22, 0.32), case, 0.01)
	m.box(Vector3(0.01, 0.01, 0.0), Vector3(0.39, 0.21, 0.02), front)
	m.box(Vector3(0.02, 0.04, -0.004), Vector3(0.22, 0.19, 0.0), screen)
	for i in 10:
		var y := 0.115 + sin(i * 0.9) * 0.03
		m.box(Vector3(0.03 + i * 0.018, y, -0.006), Vector3(0.045 + i * 0.018, y + 0.006, -0.004), trace)
	for row in 3:
		for col in 3:
			P.knob(m, 0.26 + col * 0.045, 0.06 + row * 0.05, 0.0, 0.012, m.paint("plastic", Color(0.8, 0.8, 0.82)))
	m.box(Vector3(0.02, 0.2, 0.06), Vector3(0.38, 0.23, 0.08), front)


func _terminal(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.85, 0.86, 0.86))
	var screen := m.paint("screen", Color(0.03, 0.08, 0.1))
	var key := m.paint("plastic", Color(0.2, 0.2, 0.22))
	var text := m.paint("plastic", Color(0.3, 0.9, 0.7))
	# A floor-standing console: pedestal cabinet, angled keyboard deck, monitor housing.
	P.carcass(m, Vector3(0.05, 0.0, 0.1), Vector3(0.65, 0.8, 0.6), 0.02, body)
	m.box(Vector3(0.06, 0.02, 0.08), Vector3(0.64, 0.78, 0.1), body)
	for i in 6:
		m.box(Vector3(0.12, 0.1 + i * 0.03, 0.075), Vector3(0.58, 0.11 + i * 0.03, 0.08), key)
	m.prism_zy(PackedVector2Array([Vector2(0.0, 0.8), Vector2(0.3, 0.8), Vector2(0.3, 0.86), Vector2(0.0, 0.84)]), 0.0, 0.7, body)
	for row in 4:
		for col in 12:
			m.box(Vector3(0.06 + col * 0.05, 0.85, 0.03 + row * 0.055), Vector3(0.1 + col * 0.05, 0.862, 0.07 + row * 0.055), key)
	m.rounded(Vector3(0.05, 0.86, 0.3), Vector3(0.65, 1.4, 0.6), 0.03, body)
	m.box(Vector3(0.1, 0.93, 0.29), Vector3(0.6, 1.33, 0.3), screen)
	for i in 6:
		m.box(Vector3(0.13, 1.28 - i * 0.05, 0.285), Vector3(0.2 + (i * 37 % 5) * 0.06, 1.29 - i * 0.05, 0.29), text)


func _instrument_rack(m: FurnitureModel) -> void:
	var frame := m.paint("painted_steel", Color(0.12, 0.12, 0.13))
	var panel := m.paint("aluminium", Color(0.7, 0.71, 0.72), F.BRUSHED)
	var black := m.paint("electronics", Color(0.1, 0.1, 0.11))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	P.carcass(m, Vector3(0.0, 0.08, 0.0), Vector3(0.6, 1.6, 0.7), 0.025, frame)
	for x in [0.03, 0.52]:
		m.cylinder(Vector3(x + 0.025, 0.0, 0.05), "y", 0.08, 0.03, black)
		m.cylinder(Vector3(x + 0.025, 0.0, 0.65), "y", 0.08, 0.03, black)
	# Rack-mounted instruments with displays, knobs and LEDs.
	var y := 0.12
	while y < 1.5:
		var units: float = [0.09, 0.13, 0.18][rng.randi() % 3]
		m.box(Vector3(0.03, y, -0.01), Vector3(0.57, y + units - 0.005, 0.02), panel)
		m.box(Vector3(0.06, y + 0.02, -0.014), Vector3(0.22, y + units - 0.025, -0.01), m.paint("screen", Color(0.05, 0.12, 0.08)))
		for k in rng.randi_range(2, 5):
			P.knob(m, 0.27 + k * 0.06, y + units * 0.5, -0.01, 0.012, black)
		m.box(Vector3(0.53, y + 0.02, -0.014), Vector3(0.545, y + 0.035, -0.01), m.paint("plastic", [Color(1, 0.2, 0.1), Color(0.2, 1, 0.3)][rng.randi() % 2]))
		y += units


func _glassware_rack(m: FurnitureModel) -> void:
	var rack := m.paint("plastic", Color(0.9, 0.9, 0.88))
	var glass := m.paint("glass", Color(0.8, 0.9, 0.93))
	m.box(Vector3(0.0, 0.0, 0.1), Vector3(0.5, 0.5, 0.13), rack)
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.5, 0.03, 0.2), rack)
	# Pegs with flasks and beakers drying upside down.
	for row in 3:
		for col in 5:
			var x := 0.05 + col * 0.1
			var y := 0.1 + row * 0.15
			m.cylinder(Vector3(x, y, 0.1), "z", -0.07, 0.006, rack)
			m.cylinder(Vector3(x, y - 0.06, 0.04), "y", 0.1, 0.025 if (row + col) % 2 == 0 else 0.035, glass, 0.012)


func _test_tube_stand(m: FurnitureModel) -> void:
	var wood := m.paint("pine", Color(0.82, 0.66, 0.44), F.GRAIN)
	var glass := m.paint("glass", Color(0.8, 0.9, 0.93))
	var colors := [Color(0.9, 0.2, 0.15), Color(0.2, 0.7, 0.3), Color(0.2, 0.4, 0.9), Color(0.9, 0.8, 0.2)]
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.3, 0.015, 0.1), wood)
	m.box(Vector3(0.0, 0.08, 0.0), Vector3(0.3, 0.095, 0.1), wood)
	for x in [0.0, 0.285]:
		m.box(Vector3(x, 0.015, 0.0), Vector3(x + 0.015, 0.08, 0.1), wood)
	for i in 6:
		var x := 0.04 + i * 0.045
		m.cut_cylinder(Vector3(x, 0.08, 0.05), "y", 0.015, 0.009)
		m.cylinder(Vector3(x, 0.015, 0.05), "y", 0.15, 0.008, glass)
		m.cylinder(Vector3(x, 0.015, 0.05), "y", 0.05 + (i % 3) * 0.02, 0.006, m.paint("plastic", colors[i % colors.size()]))


func _lab_sink(m: FurnitureModel) -> void:
	var frame := m.paint("painted_steel", LAB_GREY)
	var top := m.paint("stone", EPOXY, F.SPECKLE)
	var basin := m.paint("steel", Color(0.7, 0.71, 0.73), F.BRUSHED)
	var chrome := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.05, 0.05), Vector3(1.2, 0.88, 0.7), 0.02, frame)
	for x in [0.0, 0.6]:
		m.door_front(Vector3(x + 0.01, 0.06, 0.03), Vector3(x + 0.59, 0.87, 0.05), frame, chrome, x > 0.1, false)
	m.box(Vector3(0.0, 0.88, 0.0), Vector3(1.2, 0.92, 0.7), top)
	m.box(Vector3(0.3, 0.7, 0.1), Vector3(0.9, 0.92, 0.55), basin)
	m.cut(Vector3(0.33, 0.73, 0.13), Vector3(0.87, 0.93, 0.52))
	# Swan-neck tap with elbow levers, and an eye-wash station.
	m.cylinder(Vector3(0.6, 0.92, 0.62), "y", 0.25, 0.015, chrome)
	m.cylinder(Vector3(0.6, 1.15, 0.62), "z", -0.2, 0.012, chrome)
	for x in [0.5, 0.7]:
		m.box(Vector3(x - 0.004, 0.95, 0.6), Vector3(x + 0.004, 0.97, 0.66), chrome)
		m.box(Vector3(x - 0.004, 0.95, 0.66), Vector3(x + 0.004, 1.06, 0.68), chrome)
	m.cylinder(Vector3(1.05, 0.92, 0.55), "y", 0.12, 0.012, m.paint("plastic", Color(0.1, 0.7, 0.3)))
	m.cylinder(Vector3(1.05, 1.02, 0.55), "y", 0.03, 0.035, m.paint("plastic", Color(0.1, 0.7, 0.3)))


func _specimen_cabinet(m: FurnitureModel) -> void:
	var oak := m.paint("oak", Color(0.55, 0.38, 0.22), F.GRAIN)
	var glass := m.paint("glass", Color(0.75, 0.88, 0.92))
	var jar := m.paint("glass", Color(0.7, 0.75, 0.55))
	var specimen := m.paint("plastic", Color(0.8, 0.7, 0.55))
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(0.8, 1.9, 0.45), 0.03, oak)
	for y in [0.5, 0.95, 1.4]:
		m.box(Vector3(0.03, y, 0.03), Vector3(0.77, y + 0.02, 0.42), oak)
		for i in 4:
			var x := 0.12 + i * 0.17
			m.cylinder(Vector3(x, y + 0.02, 0.25), "y", 0.22, 0.06, jar)
			m.ellipsoid(Vector3(x, y + 0.12, 0.25), Vector3(0.035, 0.05, 0.035), specimen)
	for x in [0.0, 0.4]:
		m.box(Vector3(x, 0.05, -0.02), Vector3(x + 0.4, 1.85, 0.0), oak)
		m.cut(Vector3(x + 0.05, 0.1, -0.02), Vector3(x + 0.35, 1.8, 0.0))
		m.box(Vector3(x + 0.05, 0.1, -0.012), Vector3(x + 0.35, 1.8, -0.006), glass)
	m.box(Vector3(0.36, 0.9, -0.035), Vector3(0.38, 1.0, -0.02), brass)
	m.box(Vector3(0.42, 0.9, -0.035), Vector3(0.44, 1.0, -0.02), brass)
	m.box(Vector3(0.0, 0.0, -0.02), Vector3(0.8, 0.05, 0.0), oak)


func _trolley(m: FurnitureModel) -> void:
	var steel := m.paint("steel", Color(0.75, 0.76, 0.78), F.BRUSHED)
	var black := m.paint("rubber", Color(0.1, 0.1, 0.1))
	for y in [0.15, 0.55, 0.88]:
		m.box(Vector3(0.0, y, 0.0), Vector3(0.8, y + 0.02, 0.5), steel)
		m.box(Vector3(0.0, y + 0.02, 0.0), Vector3(0.8, y + 0.05, 0.015), steel)
		m.box(Vector3(0.0, y + 0.02, 0.485), Vector3(0.8, y + 0.05, 0.5), steel)
	for x in [0.01, 0.76]:
		for z in [0.01, 0.46]:
			m.cylinder(Vector3(x + 0.015, 0.08, z + 0.015), "y", 0.85, 0.014, steel)
			m.cylinder(Vector3(x + 0.015, 0.04, z + 0.015), "x", -0.02, 0.04, black)
	m.cylinder(Vector3(0.8, 0.95, 0.05), "z", 0.4, 0.014, steel)
	for i in 3:
		m.box(Vector3(0.1 + i * 0.22, 0.57, 0.15), Vector3(0.25 + i * 0.22, 0.65, 0.35), m.paint("plastic", [Color(0.2, 0.4, 0.8), Color(0.9, 0.9, 0.88), Color(0.85, 0.3, 0.2)][i]))


func _shelving(m: FurnitureModel) -> void:
	var frame := m.paint("painted_steel", LAB_GREY)
	var shelf := m.paint("steel", Color(0.72, 0.73, 0.75), F.BRUSHED)
	var bottle := m.paint("glass", Color(0.55, 0.35, 0.18))
	var clear := m.paint("glass", Color(0.8, 0.9, 0.93))
	var box := m.paint("cardboard", Color(0.8, 0.78, 0.7))
	for x in [0.0, 1.17]:
		for z in [0.0, 0.42]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.03, 1.9, z + 0.03), frame)
	for i in 5:
		var y := 0.08 + i * 0.44
		m.box(Vector3(0.0, y, 0.0), Vector3(1.2, y + 0.025, 0.45), shelf)
		m.box(Vector3(0.0, y + 0.025, 0.0), Vector3(1.2, y + 0.06, 0.012), shelf)
		if i < 4:
			for j in 6:
				var x := 0.1 + j * 0.18
				match (i + j) % 3:
					0:
						m.cylinder(Vector3(x, y + 0.025, 0.2), "y", 0.22, 0.045, bottle)
					1:
						m.cylinder(Vector3(x, y + 0.025, 0.2), "y", 0.15, 0.06, clear, 0.03)
					_:
						m.box(Vector3(x - 0.07, y + 0.025, 0.08), Vector3(x + 0.07, y + 0.17, 0.38), box)
