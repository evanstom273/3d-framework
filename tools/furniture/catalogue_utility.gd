extends RefCounted
## Utility and miscellaneous (10).

const CATEGORY := "Utility"
const F := FurnitureModel.Finish
const P := preload("res://tools/furniture/furniture_parts.gd")

const MASSES := {
	"metal_locker": 45.0, "storage_trunk": 18.0, "plastic_storage_box": 2.0, "wooden_crate_large": 12.0,
	"bin": 5.0, "recycling_bin": 12.0, "coat_rack_wall": 9.0, "utility_shelf": 10.0, "folding_chair": 4.0,
	"folding_table": 12.0,
}


func models() -> Array:
	return [
		_m("metal_locker", "Metal Locker", Vector3(0.6, 1.8, 0.45), _locker, {"voxel": 0.025}),
		_m("storage_trunk", "Storage Trunk", Vector3(0.9, 0.5, 0.5), _trunk),
		_m("plastic_storage_box", "Plastic Storage Box", Vector3(0.6, 0.32, 0.4), _plastic_box),
		_m("wooden_crate_large", "Wooden Crate", Vector3(0.7, 0.5, 0.5), _crate),
		_m("bin", "Pedal Bin", Vector3(0.34, 0.66, 0.34), _pedal_bin),
		_m("recycling_bin", "Recycling Wheelie Bin", Vector3(0.6, 1.05, 0.72), _wheelie_bin, {"voxel": 0.025}),
		_m("coat_rack_wall", "Coat Rack", Vector3(0.9, 1.62, 0.45), _coat_rack, {"voxel": 0.022}),
		_m("utility_shelf", "Utility Shelf", Vector3(0.8, 1.2, 0.3), _utility_shelf, {"voxel": 0.025}),
		_m("folding_chair", "Folding Chair", Vector3(0.45, 0.82, 0.5), _folding_chair),
		_m("folding_table", "Folding Table", Vector3(1.5, 0.74, 0.75), _folding_table, {"voxel": 0.025}),
	]


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


func _locker(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.3, 0.42, 0.55))
	var steel := m.paint("chrome", Color(0.78, 0.79, 0.81), F.BRUSHED)
	var label := m.paint("paper", Color(0.95, 0.94, 0.9))
	P.carcass(m, Vector3(0.0, 0.08, 0.0), Vector3(0.6, 1.8, 0.45), 0.015, body)
	m.box(Vector3(0.0, 0.0, 0.02), Vector3(0.6, 0.08, 0.43), m.paint("painted_steel", Color(0.15, 0.15, 0.16)))
	m.box(Vector3(0.0, 0.09, -0.015), Vector3(0.6, 1.79, 0.0), body)
	# Vent louvres top and bottom, a name card holder, a padlock hasp.
	for y in [0.2, 1.55]:
		for i in 5:
			m.cut(Vector3(0.15, y + i * 0.035, -0.015), Vector3(0.45, y + i * 0.035 + 0.012, -0.005))
	m.box(Vector3(0.22, 1.3, -0.02), Vector3(0.38, 1.36, -0.015), label)
	m.box(Vector3(0.5, 0.9, -0.03), Vector3(0.54, 1.02, -0.015), steel)
	m.box(Vector3(0.505, 0.85, -0.04), Vector3(0.535, 0.9, -0.03), m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED))


func _trunk(m: FurnitureModel) -> void:
	var canvas := m.paint("leather", Color(0.24, 0.3, 0.42), F.FABRIC)
	var trim := m.paint("leather", Color(0.4, 0.24, 0.14), F.FABRIC)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	m.rounded(Vector3(0.0, 0.0, 0.0), Vector3(0.9, 0.5, 0.5), 0.02, canvas)
	m.cut(Vector3(0.03, 0.03, 0.03), Vector3(0.87, 0.36, 0.47))
	for x in [0.15, 0.73]:
		m.repaint(Vector3(x, 0.0, 0.0), Vector3(x + 0.05, 0.5, 0.5), trim)
	m.repaint(Vector3(0.0, 0.34, 0.0), Vector3(0.9, 0.38, 0.5), trim)
	for corner in [Vector3(0.0, 0.0, 0.0), Vector3(0.84, 0.0, 0.0), Vector3(0.0, 0.44, 0.0), Vector3(0.84, 0.44, 0.0)]:
		m.box(corner + Vector3(0.0, 0.0, -0.008), corner + Vector3(0.06, 0.06, 0.0), brass)
	m.box(Vector3(0.42, 0.3, -0.012), Vector3(0.48, 0.38, 0.0), brass)
	for x in [-0.01, 0.9]:
		m.box(Vector3(x, 0.26, 0.2), Vector3(x + 0.01, 0.3, 0.3), trim)


func _plastic_box(m: FurnitureModel) -> void:
	var clear := m.paint("plastic", Color(0.86, 0.9, 0.92))
	var lid := m.paint("plastic", Color(0.2, 0.45, 0.75))
	var stuff := [Color(0.8, 0.3, 0.2), Color(0.95, 0.85, 0.3), Color(0.3, 0.6, 0.35)]
	m.rounded(Vector3(0.02, 0.0, 0.02), Vector3(0.58, 0.28, 0.38), 0.02, clear)
	m.cut(Vector3(0.04, 0.02, 0.04), Vector3(0.56, 0.29, 0.36))
	for i in 3:
		m.box(Vector3(0.06 + i * 0.16, 0.02, 0.08), Vector3(0.18 + i * 0.16, 0.12 + i * 0.03, 0.32), m.paint("fabric", stuff[i], F.FABRIC))
	m.rounded(Vector3(0.0, 0.28, 0.0), Vector3(0.6, 0.32, 0.4), 0.02, lid)
	for x in [-0.01, 0.6]:
		m.box(Vector3(x, 0.22, 0.12), Vector3(x + 0.01, 0.3, 0.28), lid)


func _crate(m: FurnitureModel) -> void:
	var pine := m.paint("pine", Color(0.78, 0.62, 0.4), F.GRAIN)
	var dark := m.paint("pine", Color(0.62, 0.48, 0.3), F.GRAIN)
	var stencil := m.paint("pine", Color(0.25, 0.2, 0.15))
	# Planked sides with gaps, corner battens, a lid of boards and stencilled lettering.
	for i in 4:
		var y := 0.01 + i * 0.12
		m.box(Vector3(0.0, y, 0.0), Vector3(0.7, y + 0.1, 0.02), pine)
		m.box(Vector3(0.0, y, 0.48), Vector3(0.7, y + 0.1, 0.5), pine)
		m.box(Vector3(0.0, y, 0.02), Vector3(0.02, y + 0.1, 0.48), pine)
		m.box(Vector3(0.68, y, 0.02), Vector3(0.7, y + 0.1, 0.48), pine)
	for corner in [Vector2(0.0, 0.0), Vector2(0.64, 0.0), Vector2(0.0, 0.44), Vector2(0.64, 0.44)]:
		m.box(Vector3(corner.x - 0.005, 0.0, corner.y - 0.005), Vector3(corner.x + 0.065, 0.5, corner.y + 0.065), dark)
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.7, 0.02, 0.5), pine)
	for i in 5:
		m.box(Vector3(0.01 + i * 0.137, 0.48, 0.0), Vector3(0.137 + i * 0.137, 0.5, 0.5), pine)
	for i in 4:
		m.repaint(Vector3(0.18 + i * 0.09, 0.22, -0.002), Vector3(0.24 + i * 0.09, 0.3, 0.002), stencil)


func _pedal_bin(m: FurnitureModel) -> void:
	var steel := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	var black := m.paint("plastic", Color(0.1, 0.1, 0.11))
	m.cylinder(Vector3(0.17, 0.03, 0.17), "y", 0.58, 0.16, steel)
	m.cut_cylinder(Vector3(0.17, 0.05, 0.17), "y", 0.6, 0.145)
	m.cylinder(Vector3(0.17, 0.0, 0.17), "y", 0.03, 0.165, black)
	m.ellipsoid(Vector3(0.17, 0.61, 0.17), Vector3(0.165, 0.05, 0.165), steel)
	m.box(Vector3(0.12, 0.01, -0.03), Vector3(0.22, 0.03, 0.04), black)
	m.box(Vector3(0.14, 0.6, 0.31), Vector3(0.2, 0.64, 0.34), black)


func _wheelie_bin(m: FurnitureModel) -> void:
	var body := m.paint("plastic", Color(0.15, 0.35, 0.6))
	var lid := m.paint("plastic", Color(0.12, 0.3, 0.52))
	var wheel := m.paint("rubber", Color(0.08, 0.08, 0.08))
	var label := m.paint("plastic", Color(0.95, 0.95, 0.95))
	# Tapered body, overhanging lid hinged at the back, axle and wheels at the back.
	for i in 20:
		var t := i / 19.0
		var y := lerpf(0.05, 0.98, t)
		var inset := lerpf(0.05, 0.0, t)
		m.box(Vector3(inset, y, inset), Vector3(0.6 - inset, y + 0.05, 0.66 - inset * 0.5), body)
	# Hollow each layer inside its own taper, keeping the floor and 2.5 cm walls.
	for i in 20:
		var t := i / 19.0
		var y := maxf(lerpf(0.05, 0.98, t), 0.08)
		var inset := lerpf(0.05, 0.0, t) + 0.025
		m.cut(Vector3(inset, y, inset), Vector3(0.6 - inset, lerpf(0.05, 0.98, t) + 0.05, 0.66 - (inset - 0.025) * 0.5 - 0.025))
	m.begin_part("hinge", "Lid", Vector3(0.3, 1.0, 0.7), Vector3.RIGHT, 110.0)
	m.rounded(Vector3(-0.02, 0.98, -0.03), Vector3(0.62, 1.05, 0.7), 0.015, lid)
	m.end_part()
	m.box(Vector3(0.05, 0.92, 0.66), Vector3(0.55, 1.0, 0.72), lid)
	for x in [-0.02, 0.56]:
		m.cylinder(Vector3(x, 0.1, 0.62), "x", 0.06, 0.1, wheel)
	m.cylinder(Vector3(0.0, 0.1, 0.62), "x", 0.6, 0.012, m.paint("steel", Color(0.6, 0.62, 0.64)))
	# Moulded feet at the front, level with the bottom of the wheels.
	for x in [0.08, 0.42]:
		m.box(Vector3(x, 0.0, 0.06), Vector3(x + 0.1, 0.06, 0.16), body)
	m.box(Vector3(0.2, 0.6, -0.008), Vector3(0.4, 0.75, 0.0), label)
	var arrow := PackedVector2Array([Vector2(0.3, 0.62), Vector2(0.36, 0.7), Vector2(0.24, 0.7)])
	m.prism_xy(arrow, -0.012, -0.008, m.paint("plastic", Color(0.2, 0.6, 0.3)))


func _coat_rack(m: FurnitureModel) -> void:
	var oak := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	var iron := m.paint("cast_iron", Color(0.1, 0.1, 0.1))
	var coat := m.paint("fabric", Color(0.3, 0.25, 0.2), F.FABRIC)
	var scarf := m.paint("fabric", Color(0.75, 0.2, 0.18), F.FABRIC)
	# A freestanding hall rack: hook rail on two posts with feet, coats hanging.
	for x in [0.02, 0.83]:
		m.box(Vector3(x - 0.02, 0.0, 0.02), Vector3(x + 0.07, 0.04, 0.43), oak)
		m.box(Vector3(x, 0.04, 0.2), Vector3(x + 0.05, 1.62, 0.25), oak)
	m.box(Vector3(0.02, 0.3, 0.2), Vector3(0.88, 0.34, 0.25), oak)
	m.rounded(Vector3(0.0, 1.5, 0.18), Vector3(0.9, 1.62, 0.25), 0.01, oak, "y")
	for i in 5:
		var x := 0.1 + i * 0.175
		m.box(Vector3(x - 0.01, 1.54, 0.12), Vector3(x + 0.01, 1.58, 0.18), iron)
		m.box(Vector3(x - 0.01, 1.58, 0.11), Vector3(x + 0.01, 1.62, 0.13), iron)
	m.box(Vector3(0.05, 0.9, 0.12), Vector3(0.22, 1.56, 0.18), coat)
	m.box(Vector3(0.45, 1.15, 0.13), Vector3(0.5, 1.56, 0.17), scarf)


func _utility_shelf(m: FurnitureModel) -> void:
	var white := m.paint("painted_steel", Color(0.93, 0.93, 0.92))
	var bottle := [Color(0.2, 0.5, 0.9), Color(0.9, 0.85, 0.2), Color(0.9, 0.3, 0.2), Color(0.3, 0.7, 0.4)]
	for x in [0.0, 0.77]:
		m.box(Vector3(x, 0.0, 0.0), Vector3(x + 0.03, 1.2, 0.3), white)
	for i in 4:
		var y := 0.05 + i * 0.37
		if y > 1.15:
			break
		m.box(Vector3(0.0, y, 0.0), Vector3(0.8, y + 0.02, 0.3), white)
		m.box(Vector3(0.0, y + 0.02, 0.0), Vector3(0.8, y + 0.05, 0.01), white)
		for j in 5:
			m.cylinder(Vector3(0.1 + j * 0.15, y + 0.02, 0.15), "y", 0.18 + (j % 2) * 0.06, 0.04, m.paint("plastic", bottle[(i + j) % bottle.size()]))


func _folding_chair(m: FurnitureModel) -> void:
	var frame := m.paint("painted_steel", Color(0.16, 0.17, 0.18))
	var seat := m.paint("plywood", Color(0.75, 0.6, 0.4), F.GRAIN)
	# Crossed X legs seen from the side, slatted seat and back.
	for x in [0.02, 0.4]:
		for i in 18:
			var t := i / 17.0
			m.box(Vector3(x, t * 0.45, lerpf(0.02, 0.42, t)), Vector3(x + 0.03, t * 0.45 + 0.04, lerpf(0.05, 0.45, t)), frame)
			m.box(Vector3(x, t * 0.82, lerpf(0.48, 0.38, t)), Vector3(x + 0.03, t * 0.82 + 0.04, lerpf(0.5, 0.41, t)), frame)
	m.box(Vector3(0.02, 0.43, 0.05), Vector3(0.43, 0.46, 0.42), seat)
	m.box(Vector3(0.02, 0.6, 0.38), Vector3(0.43, 0.8, 0.41), seat)


func _folding_table(m: FurnitureModel) -> void:
	var top := m.paint("plastic", Color(0.92, 0.92, 0.9))
	var frame := m.paint("painted_steel", Color(0.2, 0.21, 0.22))
	m.rounded(Vector3(0.0, 0.7, 0.0), Vector3(1.5, 0.74, 0.75), 0.02, top, "y")
	m.box(Vector3(0.05, 0.66, 0.05), Vector3(1.45, 0.7, 0.08), frame)
	m.box(Vector3(0.05, 0.66, 0.67), Vector3(1.45, 0.7, 0.7), frame)
	for x in [0.15, 1.3]:
		for i in 16:
			var t := i / 15.0
			m.box(Vector3(x, t * 0.66, lerpf(0.05, 0.36, t)), Vector3(x + 0.03, t * 0.66 + 0.05, lerpf(0.08, 0.39, t)), frame)
			m.box(Vector3(x, t * 0.66, lerpf(0.7, 0.39, t)), Vector3(x + 0.03, t * 0.66 + 0.05, lerpf(0.67, 0.36, t)), frame)
		m.box(Vector3(x - 0.02, 0.0, 0.03), Vector3(x + 0.05, 0.02, 0.72), frame)
