extends RefCounted
## Garden and outdoor (10).

const CATEGORY := "Garden"
const F := FurnitureModel.Finish
const P := preload("res://tools/furniture/furniture_parts.gd")

const TEAK := Color(0.62, 0.45, 0.28)
const WEATHERED := Color(0.6, 0.58, 0.54)
const SAGE_PAINT := Color(0.45, 0.55, 0.47)

const MASSES := {
	"garden_bench": 30.0, "picnic_table": 60.0, "outdoor_dining_table": 35.0, "outdoor_chair": 8.0,
	"sun_lounger": 18.0, "garden_planter": 40.0, "flower_pot_large": 25.0, "compost_bin": 12.0,
	"wheelbarrow": 15.0, "garden_storage_chest": 25.0,
}


func models() -> Array:
	return [
		_m("garden_bench", "Garden Bench", Vector3(1.5, 0.9, 0.62), _bench, {"voxel": 0.025}),
		_m("picnic_table", "Picnic Table", Vector3(1.8, 0.75, 1.5), _picnic, {"voxel": 0.035}),
		_m("outdoor_dining_table", "Outdoor Dining Table", Vector3(1.5, 0.74, 0.9), _outdoor_table, {"voxel": 0.025}),
		_m("outdoor_chair", "Outdoor Chair", Vector3(0.58, 0.92, 0.6), _outdoor_chair),
		_m("sun_lounger", "Sun Lounger", Vector3(0.68, 0.85, 1.95), _lounger, {"voxel": 0.03}),
		_m("garden_planter", "Garden Planter", Vector3(1.0, 0.75, 0.45), _planter, {"voxel": 0.025}),
		_m("flower_pot_large", "Large Flower Pot", Vector3(0.55, 0.9, 0.55), _flower_pot, {"voxel": 0.022}),
		_m("compost_bin", "Compost Bin", Vector3(0.72, 0.95, 0.72), _compost_bin, {"voxel": 0.025}),
		_m("wheelbarrow", "Wheelbarrow", Vector3(0.65, 0.65, 1.45), _wheelbarrow, {"voxel": 0.025}),
		_m("garden_storage_chest", "Outdoor Storage Chest", Vector3(1.3, 0.6, 0.6), _storage_chest, {"voxel": 0.025}),
	]


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


func _bench(m: FurnitureModel) -> void:
	var teak := m.paint("oak", TEAK, F.GRAIN)
	var iron := m.paint("cast_iron", Color(0.1, 0.1, 0.1))
	# Cast iron ends with scrolled arms, teak slats for the seat and back.
	for x in [0.0, 1.45]:
		var side := PackedVector2Array([Vector2(0.04, 0.0), Vector2(0.1, 0.0), Vector2(0.12, 0.4), Vector2(0.48, 0.4), Vector2(0.52, 0.0), Vector2(0.58, 0.0),
			Vector2(0.56, 0.44), Vector2(0.62, 0.9), Vector2(0.56, 0.9), Vector2(0.5, 0.46), Vector2(0.06, 0.66), Vector2(0.02, 0.64), Vector2(0.08, 0.44)])
		m.prism_zy(side, x, x + 0.05, iron)
	for i in 6:
		var z := 0.06 + i * 0.07
		m.box(Vector3(0.03, 0.4, z), Vector3(1.47, 0.43, z + 0.055), teak)
	for i in 5:
		var t := i / 4.0
		var y := lerpf(0.5, 0.86, t)
		var z := lerpf(0.5, 0.58, t)
		m.box(Vector3(0.03, y, z), Vector3(1.47, y + 0.06, z + 0.025), teak)


func _picnic(m: FurnitureModel) -> void:
	var pine := m.paint("pine", Color(0.66, 0.55, 0.4), F.GRAIN)
	var pale := m.paint("pine", WEATHERED, F.GRAIN)
	# Table top and two bench seats joined by splayed A-frames.
	for i in 5:
		var z := 0.4 + i * 0.14
		m.box(Vector3(0.0, 0.71, z), Vector3(1.8, 0.75, z + 0.12), pine if i % 2 == 0 else pale)
	for z in [0.0, 1.24]:
		for i in 2:
			m.box(Vector3(0.0, 0.42, z + i * 0.13), Vector3(1.8, 0.46, z + i * 0.13 + 0.12), pine)
	for x in [0.25, 1.47]:
		m.box(Vector3(x, 0.38, 0.0), Vector3(x + 0.08, 0.42, 1.5), pine)
		m.box(Vector3(x, 0.67, 0.36), Vector3(x + 0.08, 0.71, 1.14), pine)
		for i in 14:
			var t := i / 13.0
			var y := t * 0.71
			m.box(Vector3(x, y, lerpf(0.15, 0.62, t)), Vector3(x + 0.08, y + 0.06, lerpf(0.25, 0.7, t)), pine)
			m.box(Vector3(x, y, lerpf(1.35, 0.88, t)), Vector3(x + 0.08, y + 0.06, lerpf(1.25, 0.8, t)), pine)


func _outdoor_table(m: FurnitureModel) -> void:
	var alu := m.paint("aluminium", Color(0.2, 0.21, 0.22), F.BRUSHED)
	var glass := m.paint("glass", Color(0.65, 0.78, 0.82))
	m.box(Vector3(0.0, 0.7, 0.0), Vector3(1.5, 0.74, 0.9), alu)
	m.cut(Vector3(0.05, 0.7, 0.05), Vector3(1.45, 0.74, 0.85))
	m.box(Vector3(0.05, 0.725, 0.05), Vector3(1.45, 0.74, 0.85), glass)
	m.legs(0.0, 0.0, 1.5, 0.9, 0.7, 0.045, 0.02, alu, false)
	m.cylinder(Vector3(0.75, 0.0, 0.45), "y", 0.74, 0.02, alu)
	m.cut_cylinder(Vector3(0.75, 0.7, 0.45), "y", 0.05, 0.025)


func _outdoor_chair(m: FurnitureModel) -> void:
	var frame := m.paint("aluminium", Color(0.2, 0.21, 0.22), F.BRUSHED)
	var weave := m.paint("wicker", Color(0.35, 0.3, 0.26), F.FABRIC)
	var cushion := m.paint("fabric", Color(0.9, 0.88, 0.82), F.FABRIC)
	m.rounded(Vector3(0.0, 0.0, 0.0), Vector3(0.58, 0.42, 0.6), 0.04, weave)
	m.cut(Vector3(0.05, 0.05, 0.05), Vector3(0.53, 0.42, 0.55))
	m.box(Vector3(0.05, 0.3, 0.05), Vector3(0.53, 0.33, 0.55), weave)
	for x in [0.0, 0.48]:
		m.rounded(Vector3(x, 0.42, 0.06), Vector3(x + 0.1, 0.64, 0.6), 0.03, weave)
	m.rounded(Vector3(0.0, 0.42, 0.48), Vector3(0.58, 0.92, 0.6), 0.04, weave)
	m.rounded(Vector3(0.1, 0.42, 0.05), Vector3(0.48, 0.5, 0.48), 0.03, cushion)
	m.rounded(Vector3(0.1, 0.5, 0.4), Vector3(0.48, 0.85, 0.48), 0.03, cushion)
	for x in [0.02, 0.52]:
		m.box(Vector3(x, 0.0, 0.02), Vector3(x + 0.04, 0.02, 0.58), frame)


func _lounger(m: FurnitureModel) -> void:
	var teak := m.paint("oak", TEAK, F.GRAIN)
	var cushion := m.paint("fabric", Color(0.2, 0.4, 0.55), F.FABRIC)
	var wheel := m.paint("rubber", Color(0.1, 0.1, 0.1))
	for x in [0.0, 0.62]:
		m.box(Vector3(x, 0.2, 0.0), Vector3(x + 0.06, 0.28, 1.95), teak)
		m.box(Vector3(x, 0.0, 1.8), Vector3(x + 0.06, 0.2, 1.88), teak)
		m.cylinder(Vector3(x + 0.03, 0.1, 0.12), "x", 0.03 if x < 0.1 else -0.03, 0.1, wheel)
	for i in 14:
		var z := 0.62 + i * 0.095
		m.box(Vector3(0.06, 0.26, z), Vector3(0.62, 0.28, z + 0.08), teak)
	# Raised back rest at the head end (toward the player).
	for i in 8:
		var t := i / 7.0
		m.box(Vector3(0.06, lerpf(0.28, 0.82, t), lerpf(0.62, 0.12, t)), Vector3(0.62, lerpf(0.33, 0.85, t), lerpf(0.67, 0.18, t)), teak)
	m.rounded(Vector3(0.08, 0.28, 0.66), Vector3(0.6, 0.35, 1.9), 0.03, cushion)


func _planter(m: FurnitureModel) -> void:
	var timber := m.paint("pine", Color(0.52, 0.46, 0.36), F.GRAIN)
	var soil := m.paint("soil", Color(0.28, 0.2, 0.14), F.SPECKLE)
	var leaf := m.paint("plant", Color(0.25, 0.45, 0.2), F.SPECKLE)
	var flower := m.paint("plant", Color(0.85, 0.3, 0.45))
	var bloom := m.paint("plant", Color(0.95, 0.85, 0.3))
	P.carcass(m, Vector3(0.0, 0.08, 0.0), Vector3(1.0, 0.55, 0.45), 0.035, timber)
	m.box(Vector3(0.0, 0.08, -0.0), Vector3(1.0, 0.55, 0.035), timber)
	for i in 4:
		m.repaint(Vector3(0.0, 0.08 + i * 0.12, -0.01), Vector3(1.0, 0.09 + i * 0.12, 0.45), m.paint("pine", Color(0.42, 0.37, 0.29)))
	m.legs(0.0, 0.0, 1.0, 0.45, 0.08, 0.08, 0.0, timber, false)
	m.box(Vector3(0.035, 0.45, 0.035), Vector3(0.965, 0.5, 0.415), soil)
	var rng := RandomNumberGenerator.new()
	rng.seed = 121
	for i in 9:
		var x := 0.1 + i * 0.1
		var h := rng.randf_range(0.12, 0.25)
		m.ellipsoid(Vector3(x, 0.5 + h * 0.5, 0.22), Vector3(0.06, h * 0.5, 0.08), leaf)
		m.ellipsoid(Vector3(x + 0.02, 0.5 + h, 0.2), Vector3(0.025, 0.025, 0.025), flower if i % 2 == 0 else bloom)


func _flower_pot(m: FurnitureModel) -> void:
	var clay := m.paint("terracotta", Color(0.72, 0.38, 0.24))
	var rim := m.paint("terracotta", Color(0.66, 0.34, 0.21))
	var soil := m.paint("soil", Color(0.28, 0.2, 0.14), F.SPECKLE)
	var leaf := m.paint("plant", Color(0.22, 0.42, 0.18), F.SPECKLE)
	var trunk := m.paint("oak", Color(0.4, 0.3, 0.2), F.GRAIN)
	m.cylinder(Vector3(0.275, 0.0, 0.275), "y", 0.42, 0.18, clay, 0.24)
	m.cylinder(Vector3(0.275, 0.4, 0.275), "y", 0.06, 0.27, rim)
	m.cut_cylinder(Vector3(0.275, 0.4, 0.275), "y", 0.07, 0.22)
	m.cylinder(Vector3(0.275, 0.38, 0.275), "y", 0.02, 0.21, soil)
	# A small bay tree: trunk and a clipped ball of leaves.
	m.cylinder(Vector3(0.275, 0.4, 0.275), "y", 0.25, 0.02, trunk)
	m.ellipsoid(Vector3(0.275, 0.73, 0.275), Vector3(0.2, 0.17, 0.2), leaf)


func _compost_bin(m: FurnitureModel) -> void:
	var plastic := m.paint("plastic", Color(0.12, 0.2, 0.12))
	var lid := m.paint("plastic", Color(0.1, 0.16, 0.1))
	m.cylinder(Vector3(0.36, 0.0, 0.36), "y", 0.86, 0.35, plastic, 0.28)
	# Hollow in bands that follow the taper, keeping 3 cm walls all the way up.
	for i in 10:
		var y := 0.03 + i * 0.083
		m.cut_cylinder(Vector3(0.36, y, 0.36), "y", 0.084, lerpf(0.35, 0.28, (y + 0.042) / 0.86) - 0.03)
	for i in 6:
		m.repaint(Vector3(0.0, 0.1 + i * 0.13, 0.0), Vector3(0.72, 0.12 + i * 0.13, 0.72), lid)
	m.begin_part("hinge", "Lid", Vector3(0.36, 0.86, 0.66), Vector3.RIGHT, 100.0)
	m.cylinder(Vector3(0.36, 0.86, 0.36), "y", 0.05, 0.3, lid, 0.24)
	m.cylinder(Vector3(0.36, 0.91, 0.36), "y", 0.04, 0.05, lid)
	m.end_part()
	# Access hatch at the base.
	m.box(Vector3(0.24, 0.04, 0.0), Vector3(0.48, 0.22, 0.05), lid)


func _wheelbarrow(m: FurnitureModel) -> void:
	var tray := m.paint("painted_steel", Color(0.15, 0.4, 0.2))
	var frame := m.paint("painted_steel", Color(0.15, 0.15, 0.16))
	var tyre := m.paint("rubber", Color(0.08, 0.08, 0.08))
	var hub := m.paint("steel", Color(0.6, 0.62, 0.64), F.BRUSHED)
	var grip := m.paint("rubber", Color(0.12, 0.12, 0.12))
	# Wheel at the front (toward the player), tray, frame, legs and handles behind.
	m.cylinder(Vector3(0.3, 0.17, 0.17), "x", 0.07, 0.17, tyre)
	m.cylinder(Vector3(0.29, 0.17, 0.17), "x", 0.09, 0.06, hub)
	m.rounded(Vector3(0.05, 0.3, 0.2), Vector3(0.6, 0.62, 0.95), 0.06, tray)
	m.cut(Vector3(0.09, 0.36, 0.25), Vector3(0.56, 0.63, 0.9))
	for x in [0.1, 0.52]:
		for i in 26:
			var t := i / 25.0
			m.box(Vector3(x, lerpf(0.17, 0.5, t), lerpf(0.17, 1.45, t)), Vector3(x + 0.03, lerpf(0.2, 0.53, t), lerpf(0.2, 1.48, t)), frame)
		m.box(Vector3(x, 0.0, 0.95), Vector3(x + 0.03, 0.38, 0.98), frame)
		m.box(Vector3(x - 0.005, 0.47, 1.32), Vector3(x + 0.035, 0.55, 1.47), grip)


func _storage_chest(m: FurnitureModel) -> void:
	var body := m.paint("plastic", Color(0.36, 0.3, 0.24))
	var lid := m.paint("plastic", Color(0.3, 0.25, 0.2))
	m.rounded(Vector3(0.0, 0.0, 0.0), Vector3(1.3, 0.55, 0.6), 0.02, body)
	m.cut(Vector3(0.04, 0.04, 0.04), Vector3(1.26, 0.56, 0.56))
	m.begin_part("hinge", "Lid", Vector3(0.65, 0.58, 0.61), Vector3.RIGHT, 100.0)
	m.rounded(Vector3(-0.01, 0.55, -0.01), Vector3(1.31, 0.6, 0.61), 0.02, lid)
	m.box(Vector3(0.6, 0.55, -0.02), Vector3(0.7, 0.58, 0.0), lid)
	m.end_part()
	# Moulded wood-grain planks on the front and a lock tab.
	for i in 4:
		m.cut(Vector3(0.02, 0.1 + i * 0.12, 0.0), Vector3(1.28, 0.11 + i * 0.12, 0.012))
	m.box(Vector3(0.6, 0.48, -0.02), Vector3(0.7, 0.55, 0.0), lid)
