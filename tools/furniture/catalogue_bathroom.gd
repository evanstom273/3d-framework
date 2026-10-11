extends RefCounted
## Bathroom (15).

const CATEGORY := "Bathroom"
const F := FurnitureModel.Finish
const P := preload("res://tools/furniture/furniture_parts.gd")

const PORCELAIN := Color(0.96, 0.96, 0.95)
const CHROME := Color(0.84, 0.85, 0.87)

const MASSES := {
	"toilet": 28.0, "pedestal_sink": 22.0, "vanity_unit": 35.0, "bathtub": 45.0, "bathtub_freestanding": 70.0,
	"shower_enclosure": 60.0, "shower_tray": 25.0, "bathroom_cabinet": 12.0, "mirrored_cabinet": 14.0,
	"towel_rail": 4.0, "towel_rail_heated": 8.0, "toilet_roll_holder": 0.8, "bathroom_shelf": 6.0,
	"laundry_hamper": 3.0, "bathroom_stool": 3.0,
}


func models() -> Array:
	return [
		_m("toilet", "Toilet", Vector3(0.4, 0.8, 0.68), _toilet),
		_m("pedestal_sink", "Pedestal Sink", Vector3(0.56, 0.88, 0.45), _pedestal_sink),
		_m("vanity_unit", "Vanity Sink Cabinet", Vector3(0.8, 0.95, 0.46), _vanity),
		_m("bathtub", "Bathtub", Vector3(1.7, 0.58, 0.72), _bathtub),
		_m("bathtub_freestanding", "Freestanding Bathtub", Vector3(1.7, 0.75, 0.78), _freestanding_bath),
		_m("shower_enclosure", "Shower Enclosure", Vector3(0.9, 2.0, 0.9), _shower_enclosure),
		_m("shower_tray", "Shower Tray", Vector3(0.9, 0.05, 0.9), _shower_tray, {"voxel": 0.02}),
		_m("bathroom_cabinet", "Bathroom Cabinet", Vector3(0.4, 0.6, 0.2), _bathroom_cabinet),
		_m("mirrored_cabinet", "Mirrored Cabinet", Vector3(0.6, 0.65, 0.16), _mirrored_cabinet),
		_m("towel_rail", "Towel Rail", Vector3(0.62, 0.86, 0.26), _towel_rail, {"voxel": 0.018}),
		_m("towel_rail_heated", "Heated Towel Rail", Vector3(0.5, 1.2, 0.12), _heated_rail, {"voxel": 0.015}),
		_m("toilet_roll_holder", "Toilet Roll Holder", Vector3(0.18, 0.62, 0.18), _roll_holder),
		_m("bathroom_shelf", "Bathroom Storage Shelf", Vector3(0.6, 1.5, 0.3), _bathroom_shelf, {"voxel": 0.022}),
		_m("laundry_hamper", "Laundry Hamper", Vector3(0.4, 0.6, 0.4), _hamper),
		_m("bathroom_stool", "Bathroom Stool", Vector3(0.35, 0.45, 0.35), _stool),
	]


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


func _toilet(m: FurnitureModel) -> void:
	var china := m.paint("ceramic", PORCELAIN)
	var seat := m.paint("plastic", Color(0.98, 0.98, 0.97))
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	var water := m.paint("glass", Color(0.6, 0.8, 0.88))
	# Foot running back under the cistern, pedestal, bowl (hollowed), seat and lid up,
	# cistern with a push button.
	m.rounded(Vector3(0.09, 0.0, 0.16), Vector3(0.31, 0.06, 0.66), 0.02, china)
	m.box(Vector3(0.12, 0.06, 0.4), Vector3(0.28, 0.4, 0.62), china)
	m.ellipsoid(Vector3(0.2, 0.2, 0.32), Vector3(0.11, 0.2, 0.14), china)
	m.ellipsoid(Vector3(0.2, 0.36, 0.3), Vector3(0.18, 0.06, 0.24), china)
	m.cut_ellipsoid(Vector3(0.2, 0.39, 0.29), Vector3(0.13, 0.06, 0.19))
	m.box(Vector3(0.12, 0.34, 0.24), Vector3(0.28, 0.35, 0.36), water)
	m.ellipsoid(Vector3(0.2, 0.42, 0.29), Vector3(0.18, 0.012, 0.22), seat)
	m.cut_ellipsoid(Vector3(0.2, 0.42, 0.29), Vector3(0.12, 0.02, 0.15))
	m.rounded(Vector3(0.02, 0.4, 0.52), Vector3(0.38, 0.8, 0.68), 0.03, china)
	m.begin_part("hinge", "Lid", Vector3(0.2, 0.44, 0.5), Vector3.RIGHT, 100.0)
	m.ellipsoid(Vector3(0.2, 0.443, 0.29), Vector3(0.18, 0.012, 0.22), seat)
	m.box(Vector3(0.12, 0.432, 0.46), Vector3(0.28, 0.452, 0.51), seat)
	m.end_part()
	m.cylinder(Vector3(0.2, 0.8, 0.6), "y", 0.012, 0.025, chrome)


func _pedestal_sink(m: FurnitureModel) -> void:
	var china := m.paint("ceramic", PORCELAIN)
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	m.cylinder(Vector3(0.28, 0.0, 0.3), "y", 0.72, 0.1, china, 0.075)
	m.rounded(Vector3(0.0, 0.7, 0.0), Vector3(0.56, 0.86, 0.45), 0.06, china)
	m.cut_ellipsoid(Vector3(0.28, 0.86, 0.2), Vector3(0.21, 0.12, 0.15))
	for x in [0.17, 0.39]:
		m.cylinder(Vector3(x, 0.86, 0.38), "y", 0.06, 0.018, chrome)
		m.box(Vector3(x - 0.03, 0.91, 0.37), Vector3(x + 0.03, 0.925, 0.39), chrome)
	m.cylinder(Vector3(0.28, 0.86, 0.39), "y", 0.1, 0.012, chrome)
	m.cylinder(Vector3(0.28, 0.95, 0.39), "z", -0.08, 0.01, chrome)


func _vanity(m: FurnitureModel) -> void:
	var body := m.paint("painted_wood", Color(0.24, 0.32, 0.38))
	var top := m.paint("marble", Color(0.93, 0.92, 0.9), F.SPECKLE)
	var china := m.paint("ceramic", PORCELAIN)
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.12, 0.02), Vector3(0.8, 0.82, 0.46), 0.02, body)
	m.legs(0.0, 0.02, 0.8, 0.46, 0.12, 0.04, 0.02, body, false)
	m.door_front(Vector3(0.01, 0.13, 0.0), Vector3(0.395, 0.81, 0.022), body, brass, false)
	m.door_front(Vector3(0.405, 0.13, 0.0), Vector3(0.79, 0.81, 0.022), body, brass, true)
	m.box(Vector3(-0.01, 0.82, -0.01), Vector3(0.81, 0.85, 0.47), top)
	# Countertop basin with a tall mixer.
	m.ellipsoid(Vector3(0.4, 0.88, 0.22), Vector3(0.2, 0.05, 0.15), china)
	m.cut_ellipsoid(Vector3(0.4, 0.91, 0.22), Vector3(0.17, 0.05, 0.12))
	m.cylinder(Vector3(0.4, 0.85, 0.41), "y", 0.12, 0.014, chrome)
	m.cylinder(Vector3(0.4, 0.96, 0.41), "z", -0.12, 0.01, chrome)


func _bathtub(m: FurnitureModel) -> void:
	var acrylic := m.paint("plastic", PORCELAIN)
	var panel := m.paint("painted_wood", Color(0.95, 0.95, 0.93))
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	m.rounded(Vector3(0.0, 0.0, 0.0), Vector3(1.7, 0.56, 0.72), 0.03, acrylic, "top")
	m.cut(Vector3(0.08, 0.12, 0.08), Vector3(1.62, 0.57, 0.64))
	m.cut_ellipsoid(Vector3(0.85, 0.12, 0.36), Vector3(0.75, 0.08, 0.26))
	m.box(Vector3(0.0, 0.0, -0.02), Vector3(1.7, 0.52, 0.0), panel)
	# Mixer tap and overflow at one end.
	m.box(Vector3(1.5, 0.56, 0.28), Vector3(1.66, 0.58, 0.44), chrome)
	m.cylinder(Vector3(1.58, 0.58, 0.36), "y", 0.08, 0.014, chrome)
	m.cylinder(Vector3(1.58, 0.65, 0.36), "x", -0.1, 0.012, chrome)
	m.cylinder(Vector3(1.62, 0.4, 0.36), "x", 0.012, 0.03, chrome)


func _freestanding_bath(m: FurnitureModel) -> void:
	var enamel := m.paint("ceramic", PORCELAIN)
	var outside := m.paint("cast_iron", Color(0.2, 0.28, 0.3))
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	# A roll-top tub: an ellipsoid body cut open at the top, on claw feet.
	m.ellipsoid(Vector3(0.85, 0.5, 0.39), Vector3(0.84, 0.4, 0.38), outside)
	m.cut(Vector3(0.0, 0.7, 0.0), Vector3(1.7, 1.0, 0.8))
	m.cut_ellipsoid(Vector3(0.85, 0.55, 0.39), Vector3(0.78, 0.36, 0.32))
	m.cut(Vector3(0.0, 0.0, 0.0), Vector3(1.7, 0.14, 0.8))
	m.repaint(Vector3(0.0, 0.64, 0.0), Vector3(1.7, 0.7, 0.8), enamel)
	for corner in [Vector2(0.3, 0.16), Vector2(1.4, 0.16), Vector2(0.3, 0.62), Vector2(1.4, 0.62)]:
		m.cylinder(Vector3(corner.x, 0.0, corner.y), "y", 0.16, 0.035, brass, 0.025)
		m.ellipsoid(Vector3(corner.x, 0.025, corner.y), Vector3(0.045, 0.025, 0.045), brass)
	m.cylinder(Vector3(0.85, 0.0, 0.85), "y", 0.95, 0.014, brass)
	m.cylinder(Vector3(0.85, 0.95, 0.85), "z", -0.25, 0.012, brass)


func _shower_enclosure(m: FurnitureModel) -> void:
	var glass := m.paint("glass", Color(0.75, 0.88, 0.92))
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	var tray := m.paint("ceramic", PORCELAIN)
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.9, 0.05, 0.9), tray)
	# Two glass sides on chrome channels, the door on the front, a riser rail and head.
	m.box(Vector3(0.0, 0.05, 0.0), Vector3(0.02, 1.95, 0.9), chrome)
	m.box(Vector3(0.006, 0.05, 0.02), Vector3(0.014, 1.95, 0.88), glass)
	m.box(Vector3(0.0, 1.95, 0.0), Vector3(0.9, 2.0, 0.02), chrome)
	m.box(Vector3(0.0, 1.95, 0.0), Vector3(0.02, 2.0, 0.9), chrome)
	m.box(Vector3(0.02, 0.05, 0.004), Vector3(0.88, 1.95, 0.012), glass)
	m.box(Vector3(0.88, 0.05, 0.0), Vector3(0.9, 1.95, 0.02), chrome)
	m.box(Vector3(0.5, 0.95, -0.03), Vector3(0.52, 1.25, -0.0), chrome)
	m.box(Vector3(0.85, 0.05, 0.86), Vector3(0.87, 1.9, 0.88), chrome)
	m.cylinder(Vector3(0.86, 1.85, 0.87), "z", -0.12, 0.012, chrome)
	m.cylinder(Vector3(0.86, 1.83, 0.75), "y", 0.03, 0.06, chrome)


func _shower_tray(m: FurnitureModel) -> void:
	var tray := m.paint("ceramic", PORCELAIN)
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	m.rounded(Vector3(0.0, 0.0, 0.0), Vector3(0.9, 0.05, 0.9), 0.02, tray, "y")
	m.cylinder(Vector3(0.45, 0.04, 0.45), "y", 0.012, 0.045, chrome)
	m.cut_cylinder(Vector3(0.45, 0.045, 0.45), "y", 0.01, 0.03)


func _bathroom_cabinet(m: FurnitureModel) -> void:
	var white := m.paint("painted_wood", Color(0.96, 0.96, 0.94))
	var knob := m.paint("chrome", CHROME, F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(0.4, 0.6, 0.2), 0.016, white)
	m.box(Vector3(0.016, 0.3, 0.02), Vector3(0.384, 0.312, 0.19), white)
	m.door_front(Vector3(0.0, 0.0, -0.018), Vector3(0.4, 0.6, 0.0), white, knob, false)
	for i in 3:
		m.cylinder(Vector3(0.08 + i * 0.1, 0.312, 0.1), "y", 0.1 - i * 0.02, 0.025, m.paint("plastic", [Color(0.3, 0.6, 0.8), Color(0.9, 0.9, 0.9), Color(0.8, 0.4, 0.4)][i]))


func _mirrored_cabinet(m: FurnitureModel) -> void:
	var steel := m.paint("steel", Color(0.75, 0.76, 0.78), F.BRUSHED)
	var mirror := m.paint("mirror", Color(0.85, 0.88, 0.9))
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(0.6, 0.65, 0.16), 0.014, steel)
	m.box(Vector3(0.014, 0.32, 0.02), Vector3(0.586, 0.33, 0.15), steel)
	for x in [0.0, 0.302]:
		m.box(Vector3(x, 0.0, -0.016), Vector3(x + 0.298, 0.65, 0.0), steel)
		m.box(Vector3(x + 0.01, 0.01, -0.02), Vector3(x + 0.288, 0.64, -0.016), mirror)
	m.box(Vector3(0.05, 0.66, -0.03), Vector3(0.55, 0.69, 0.04), m.paint("plastic", Color(0.98, 0.97, 0.9)))


func _towel_rail(m: FurnitureModel) -> void:
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	var towel := m.paint("fabric", Color(0.6, 0.75, 0.78), F.FABRIC)
	for x in [0.02, 0.58]:
		m.box(Vector3(x, 0.0, 0.02), Vector3(x + 0.02, 0.02, 0.24), chrome)
		m.cylinder(Vector3(x + 0.01, 0.0, 0.13), "y", 0.84, 0.012, chrome)
	for y in [0.55, 0.84]:
		m.cylinder(Vector3(0.02, y, 0.13), "x", 0.58, 0.012, chrome)
	m.box(Vector3(0.1, 0.42, 0.11), Vector3(0.5, 0.86, 0.15), towel)


func _heated_rail(m: FurnitureModel) -> void:
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	for x in [0.02, 0.46]:
		m.cylinder(Vector3(x, 0.0, 0.06), "y", 1.2, 0.018, chrome)
		m.cylinder(Vector3(x, 0.1, 0.06), "z", 0.06, 0.012, chrome)
		m.cylinder(Vector3(x, 1.1, 0.06), "z", 0.06, 0.012, chrome)
	for i in 14:
		var y := 0.1 + i * 0.075 + (0.05 if i > 6 else 0.0)
		m.cylinder(Vector3(0.02, y, 0.06), "x", 0.44, 0.01, chrome)
	m.cylinder(Vector3(0.48, 0.02, 0.06), "x", 0.03, 0.02, m.paint("plastic", Color(0.95, 0.95, 0.95)))


func _roll_holder(m: FurnitureModel) -> void:
	var chrome := m.paint("chrome", CHROME, F.BRUSHED)
	var paper := m.paint("paper", Color(0.98, 0.98, 0.97))
	m.cylinder(Vector3(0.09, 0.0, 0.09), "y", 0.02, 0.08, chrome)
	m.cylinder(Vector3(0.09, 0.02, 0.09), "y", 0.58, 0.012, chrome)
	m.cylinder(Vector3(0.09, 0.45, 0.09), "x", 0.07, 0.008, chrome)
	m.cylinder(Vector3(0.11, 0.45, 0.09), "x", 0.06, 0.055, paper)
	m.cut_cylinder(Vector3(0.11, 0.45, 0.09), "x", 0.06, 0.02)
	for i in 2:
		m.cylinder(Vector3(0.09, 0.1 + i * 0.11, 0.09), "y", 0.1, 0.055, paper)


func _bathroom_shelf(m: FurnitureModel) -> void:
	var bamboo := m.paint("pine", Color(0.85, 0.72, 0.5), F.GRAIN)
	var towel := m.paint("fabric", Color(0.94, 0.94, 0.92), F.FABRIC)
	var basket := m.paint("wicker", Color(0.6, 0.47, 0.3), F.FABRIC)
	for x in [0.0, 0.57]:
		m.box(Vector3(x, 0.0, 0.0), Vector3(x + 0.03, 1.5, 0.03), bamboo)
		m.box(Vector3(x, 0.0, 0.27), Vector3(x + 0.03, 1.5, 0.3), bamboo)
	for i in 4:
		var y := 0.15 + i * 0.4
		for j in 5:
			m.box(Vector3(0.0, y, 0.01 + j * 0.06), Vector3(0.6, y + 0.02, 0.05 + j * 0.06), bamboo)
	for i in 3:
		m.rounded(Vector3(0.08, 0.57 + i * 0.05, 0.05), Vector3(0.5, 0.62 + i * 0.05, 0.27), 0.015, towel)
	m.rounded(Vector3(0.1, 0.17, 0.04), Vector3(0.5, 0.42, 0.27), 0.02, basket)
	m.cut(Vector3(0.12, 0.19, 0.06), Vector3(0.48, 0.43, 0.25))


func _hamper(m: FurnitureModel) -> void:
	var weave := m.paint("wicker", Color(0.82, 0.8, 0.74), F.FABRIC)
	var trim := m.paint("wicker", Color(0.55, 0.53, 0.48), F.FABRIC)
	m.cylinder(Vector3(0.2, 0.0, 0.2), "y", 0.56, 0.19, weave, 0.2)
	m.cut_cylinder(Vector3(0.2, 0.03, 0.2), "y", 0.56, 0.165)
	m.cylinder(Vector3(0.2, 0.56, 0.2), "y", 0.04, 0.205, trim)
	m.cylinder(Vector3(0.2, 0.6, 0.2), "y", 0.02, 0.04, trim)


func _stool(m: FurnitureModel) -> void:
	var teak := m.paint("oak", Color(0.55, 0.36, 0.2), F.GRAIN)
	for i in 6:
		m.box(Vector3(0.0, 0.42, 0.01 + i * 0.056), Vector3(0.35, 0.45, 0.05 + i * 0.056), teak)
	for corner in [Vector2(0.03, 0.03), Vector2(0.28, 0.03), Vector2(0.03, 0.28), Vector2(0.28, 0.28)]:
		m.box(Vector3(corner.x, 0.0, corner.y), Vector3(corner.x + 0.04, 0.42, corner.y + 0.04), teak)
	m.box(Vector3(0.03, 0.12, 0.05), Vector3(0.07, 0.15, 0.3), teak)
	m.box(Vector3(0.28, 0.12, 0.05), Vector3(0.32, 0.15, 0.3), teak)
	m.box(Vector3(0.05, 0.2, 0.15), Vector3(0.3, 0.23, 0.2), teak)
