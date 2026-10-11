extends RefCounted
## Workshop and garden shed (15).

const CATEGORY := "Workshop"
const F := FurnitureModel.Finish
const P := preload("res://tools/furniture/furniture_parts.gd")

const TOOL_RED := Color(0.72, 0.12, 0.1)
const HAMMERITE := Color(0.18, 0.32, 0.26)
const GALV := Color(0.66, 0.68, 0.7)

const MASSES := {
	"workbench_wood": 70.0, "workbench_metal": 80.0, "tool_cabinet": 60.0, "tool_chest": 35.0,
	"pegboard": 15.0, "storage_rack": 40.0, "workshop_shelving_wood": 25.0, "shelving_metal": 30.0,
	"vice": 14.0, "sawhorse": 6.0, "workshop_stool": 5.0, "ladder": 8.0, "toolbox": 6.0,
	"pallet": 20.0, "garden_tool_rack": 12.0,
}


func models() -> Array:
	return [
		_m("workbench_wood", "Heavy Wooden Workbench", Vector3(1.8, 0.9, 0.75), _wood_bench, {"voxel": 0.03}),
		_m("workbench_metal", "Metal Workbench", Vector3(1.6, 1.6, 0.7), _metal_bench, {"voxel": 0.03}),
		_m("tool_cabinet", "Tool Cabinet", Vector3(0.7, 1.0, 0.46), _tool_cabinet, {"voxel": 0.022}),
		_m("tool_chest", "Tool Chest", Vector3(0.66, 0.45, 0.32), _tool_chest),
		_m("pegboard", "Pegboard", Vector3(1.2, 0.94, 0.5), _pegboard, {"voxel": 0.018}),
		_m("storage_rack", "Storage Rack", Vector3(1.2, 1.8, 0.5), _storage_rack, {"voxel": 0.03}),
		_m("workshop_shelving_wood", "Wooden Shed Shelving", Vector3(1.0, 1.7, 0.4), _wood_shelving, {"voxel": 0.028}),
		_m("shelving_metal", "Metal Shelving Unit", Vector3(0.9, 1.8, 0.4), _metal_shelving, {"voxel": 0.028}),
		_m("vice", "Bench Vice", Vector3(0.24, 0.2, 0.36), _vice),
		_m("sawhorse", "Sawhorse", Vector3(0.9, 0.7, 0.5), _sawhorse),
		_m("workshop_stool", "Workshop Stool", Vector3(0.38, 0.62, 0.38), _stool),
		_m("ladder", "Stepladder", Vector3(0.48, 1.55, 0.75), _ladder, {"voxel": 0.022}),
		_m("toolbox", "Toolbox", Vector3(0.5, 0.26, 0.22), _toolbox),
		_m("pallet", "Wooden Pallet", Vector3(1.2, 0.15, 0.8), _pallet, {"voxel": 0.025}),
		_m("garden_tool_rack", "Garden Equipment Rack", Vector3(0.9, 1.4, 0.35), _garden_rack, {"voxel": 0.022}),
	]


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


func _wood_bench(m: FurnitureModel) -> void:
	var beech := m.paint("oak", Color(0.72, 0.56, 0.36), F.GRAIN)
	var worn := m.paint("oak", Color(0.6, 0.45, 0.28), F.GRAIN)
	var iron := m.paint("cast_iron", Color(0.14, 0.14, 0.15))
	# Thick laminated top with a dog-hole row, trestle legs, stretchers and a tool well.
	m.box(Vector3(0.0, 0.8, 0.0), Vector3(1.8, 0.9, 0.62), beech)
	m.box(Vector3(0.0, 0.84, 0.62), Vector3(1.8, 0.86, 0.75), worn)
	m.box(Vector3(0.0, 0.86, 0.72), Vector3(1.8, 0.9, 0.75), beech)
	for i in 8:
		m.cut(Vector3(0.15 + i * 0.2, 0.86, 0.06), Vector3(0.17 + i * 0.2, 0.9, 0.08))
	for x in [0.1, 1.62]:
		for z in [0.06, 0.6]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.08, 0.8, z + 0.08), beech)
		m.box(Vector3(x, 0.15, 0.06), Vector3(x + 0.08, 0.22, 0.68), beech)
		m.box(Vector3(x - 0.02, 0.0, 0.0), Vector3(x + 0.1, 0.06, 0.74), beech)
	m.box(Vector3(0.1, 0.4, 0.62), Vector3(1.7, 0.48, 0.68), beech)
	# A front vice on the left end.
	m.box(Vector3(0.2, 0.62, -0.06), Vector3(0.5, 0.9, -0.02), worn)
	m.cylinder(Vector3(0.35, 0.78, -0.06), "z", -0.06, 0.02, iron)
	m.cylinder(Vector3(0.24, 0.78, -0.12), "x", 0.22, 0.01, iron)


func _metal_bench(m: FurnitureModel) -> void:
	var frame := m.paint("painted_steel", HAMMERITE)
	var top := m.paint("plywood", Color(0.78, 0.66, 0.48), F.GRAIN)
	var steel := m.paint("chrome", Color(0.75, 0.76, 0.78), F.BRUSHED)
	var board := m.paint("painted_steel", Color(0.5, 0.52, 0.5))
	for x in [0.0, 1.55]:
		for z in [0.0, 0.65]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.05, 0.86, z + 0.05), frame)
	m.box(Vector3(0.0, 0.82, 0.0), Vector3(1.6, 0.86, 0.7), frame)
	m.box(Vector3(0.0, 0.86, 0.0), Vector3(1.6, 0.9, 0.7), top)
	m.box(Vector3(0.05, 0.12, 0.05), Vector3(1.55, 0.15, 0.65), frame)
	P.carcass(m, Vector3(1.05, 0.15, 0.05), Vector3(1.55, 0.82, 0.68), 0.02, frame)
	for i in 3:
		var y := 0.16 + i * 0.22
		m.drawer(Vector3(1.06, y, 0.03), Vector3(1.54, y + 0.21, 0.05), frame, steel, "bar")
	# Perforated back board with an overhead light bar.
	m.box(Vector3(0.0, 0.9, 0.65), Vector3(1.6, 1.6, 0.7), board)
	for row in 10:
		for col in 22:
			m.cut(Vector3(0.05 + col * 0.07, 0.95 + row * 0.06, 0.645), Vector3(0.06 + col * 0.07, 0.96 + row * 0.06, 0.66))
	m.box(Vector3(0.0, 1.55, 0.5), Vector3(1.6, 1.6, 0.7), frame)
	m.box(Vector3(0.1, 1.53, 0.55), Vector3(1.5, 1.55, 0.62), m.paint("plastic", Color(0.98, 0.97, 0.9)))
	for i in 5:
		m.box(Vector3(0.15 + i * 0.12, 1.1, 0.6), Vector3(0.17 + i * 0.12, 1.3 - i * 0.02, 0.64), steel)


func _tool_cabinet(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", TOOL_RED)
	var steel := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	var black := m.paint("rubber", Color(0.08, 0.08, 0.08))
	P.carcass(m, Vector3(0.0, 0.1, 0.0), Vector3(0.7, 0.96, 0.46), 0.02, body)
	m.box(Vector3(-0.01, 0.96, -0.01), Vector3(0.71, 1.0, 0.47), black)
	var heights := [0.11, 0.2, 0.29, 0.38, 0.5, 0.65, 0.95]
	for i in heights.size() - 1:
		m.drawer(Vector3(0.008, heights[i], -0.02), Vector3(0.692, heights[i + 1] - 0.006, 0.0), body, steel, "bar")
	# Castors and a side push handle.
	for x in [0.04, 0.6]:
		for z in [0.05, 0.38]:
			m.box(Vector3(x, 0.07, z), Vector3(x + 0.06, 0.1, z + 0.06), steel)
			m.cylinder(Vector3(x + 0.015, 0.035, z + 0.03), "x", 0.03, 0.035, black)
	m.cylinder(Vector3(0.72, 0.8, 0.05), "z", 0.36, 0.014, steel)
	m.box(Vector3(0.7, 0.79, 0.05), Vector3(0.73, 0.82, 0.07), steel)
	m.box(Vector3(0.7, 0.79, 0.39), Vector3(0.73, 0.82, 0.41), steel)


func _tool_chest(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", TOOL_RED)
	var steel := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(0.66, 0.38, 0.32), 0.015, body)
	m.rounded(Vector3(-0.005, 0.38, -0.005), Vector3(0.665, 0.45, 0.325), 0.015, body)
	for i in 4:
		var y := 0.01 + i * 0.09
		m.drawer(Vector3(0.006, y, -0.015), Vector3(0.654, y + 0.085, 0.0), body, steel, "bar")
	P.bar_handle(m, 0.23, 0.43, 0.45, 0.16, steel)
	m.box(Vector3(0.3, 0.36, -0.02), Vector3(0.36, 0.42, -0.005), steel)


func _pegboard(m: FurnitureModel) -> void:
	var board := m.paint("plywood", Color(0.75, 0.62, 0.44))
	var hook := m.paint("steel", Color(0.6, 0.62, 0.65), F.BRUSHED)
	var red := m.paint("plastic", Color(0.8, 0.15, 0.1))
	var yellow := m.paint("plastic", Color(0.95, 0.75, 0.1))
	var wood := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	# Freestanding: the board stands in two splayed feet.
	for x in [0.05, 1.07]:
		m.box(Vector3(x, 0.0, -0.15), Vector3(x + 0.08, 0.04, 0.35), wood)
		m.box(Vector3(x + 0.02, 0.04, 0.08), Vector3(x + 0.06, 0.3, 0.14), wood)
	m.box(Vector3(0.0, 0.04, 0.1), Vector3(1.2, 0.94, 0.12), board)
	for row in 16:
		for col in 22:
			m.cut(Vector3(0.04 + col * 0.052, 0.04 + row * 0.052, 0.1), Vector3(0.048 + col * 0.052, 0.048 + row * 0.052, 0.12))
	# Hung tools: hammer, screwdrivers, spanners, pliers, saw outline.
	m.box(Vector3(0.1, 0.45, 0.08), Vector3(0.13, 0.75, 0.1), wood)
	m.box(Vector3(0.06, 0.72, 0.07), Vector3(0.17, 0.77, 0.1), hook)
	for i in 4:
		var x := 0.25 + i * 0.05
		m.box(Vector3(x, 0.55, 0.08), Vector3(x + 0.015, 0.7, 0.1), hook)
		m.box(Vector3(x - 0.005, 0.7, 0.075), Vector3(x + 0.02, 0.78, 0.1), red if i % 2 == 0 else yellow)
	for i in 5:
		var x := 0.55 + i * 0.06
		m.box(Vector3(x, 0.4 + i * 0.02, 0.085), Vector3(x + 0.02, 0.75, 0.1), hook)
	var saw := PackedVector2Array([Vector2(0.88, 0.25), Vector2(1.15, 0.3), Vector2(1.15, 0.42), Vector2(0.88, 0.38)])
	m.prism_xy(saw, 0.09, 0.1, hook)
	m.box(Vector3(0.82, 0.3, 0.08), Vector3(0.9, 0.42, 0.1), red)
	m.box(Vector3(0.1, 0.1, 0.06), Vector3(0.7, 0.13, 0.1), wood)
	for i in 5:
		m.cylinder(Vector3(0.15 + i * 0.12, 0.13, 0.08), "y", 0.08, 0.03, m.paint("plastic", [Color(0.3, 0.5, 0.8), Color(0.9, 0.9, 0.88)][i % 2]))


func _storage_rack(m: FurnitureModel) -> void:
	var frame := m.paint("painted_steel", Color(0.15, 0.3, 0.55))
	var beam := m.paint("painted_steel", Color(0.92, 0.5, 0.1))
	var deck := m.paint("chipboard", Color(0.78, 0.7, 0.56))
	var tote := m.paint("plastic", Color(0.2, 0.2, 0.22))
	var crate := m.paint("cardboard", Color(0.66, 0.5, 0.32))
	for x in [0.0, 1.15]:
		for z in [0.0, 0.45]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.05, 1.8, z + 0.05), frame)
		for i in 6:
			m.box(Vector3(x + 0.015, 0.1 + i * 0.3, 0.05), Vector3(x + 0.035, 0.12 + i * 0.3 + 0.28, 0.07), frame)
	for i in 4:
		var y := 0.1 + i * 0.55
		if y > 1.7:
			break
		m.box(Vector3(0.0, y, 0.0), Vector3(1.2, y + 0.06, 0.04), beam)
		m.box(Vector3(0.0, y, 0.46), Vector3(1.2, y + 0.06, 0.5), beam)
		m.box(Vector3(0.05, y + 0.04, 0.04), Vector3(1.15, y + 0.06, 0.46), deck)
		m.box(Vector3(0.1, y + 0.06, 0.06), Vector3(0.5, y + 0.3, 0.44), tote if i % 2 == 0 else crate)
		m.box(Vector3(0.6, y + 0.06, 0.06), Vector3(1.1, y + 0.26, 0.44), crate if i % 2 == 0 else tote)


func _wood_shelving(m: FurnitureModel) -> void:
	var pine := m.paint("pine", Color(0.75, 0.6, 0.4), F.GRAIN)
	var pot := m.paint("terracotta", Color(0.7, 0.36, 0.22))
	var tin := m.paint("steel", Color(0.6, 0.62, 0.64), F.BRUSHED)
	var jar := m.paint("glass", Color(0.65, 0.75, 0.6))
	for x in [0.0, 0.94]:
		m.box(Vector3(x, 0.0, 0.0), Vector3(x + 0.06, 1.7, 0.06), pine)
		m.box(Vector3(x, 0.0, 0.34), Vector3(x + 0.06, 1.7, 0.4), pine)
	for i in 4:
		var y := 0.15 + i * 0.5
		if y > 1.65:
			break
		for j in 3:
			m.box(Vector3(0.0, y, 0.01 + j * 0.13), Vector3(1.0, y + 0.025, 0.12 + j * 0.13), pine)
		for k in 4:
			var x := 0.12 + k * 0.22
			match (i + k) % 3:
				0:
					m.cylinder(Vector3(x, y + 0.025, 0.2), "y", 0.13, 0.06, pot, 0.075)
					m.cut_cylinder(Vector3(x, y + 0.045, 0.2), "y", 0.12, 0.06)
				1:
					m.cylinder(Vector3(x, y + 0.025, 0.2), "y", 0.18, 0.07, tin)
				_:
					m.cylinder(Vector3(x, y + 0.025, 0.2), "y", 0.15, 0.05, jar)


func _metal_shelving(m: FurnitureModel) -> void:
	var galv := m.paint("steel", GALV, F.BRUSHED)
	var box := m.paint("cardboard", Color(0.66, 0.5, 0.32))
	var paint := m.paint("steel", Color(0.85, 0.2, 0.15))
	for x in [0.0, 0.87]:
		for z in [0.0, 0.37]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.03, 1.8, z + 0.03), galv)
	for i in 5:
		var y := 0.06 + i * 0.42
		m.box(Vector3(0.0, y, 0.0), Vector3(0.9, y + 0.025, 0.4), galv)
		m.box(Vector3(0.0, y + 0.025, 0.0), Vector3(0.9, y + 0.05, 0.012), galv)
		if i < 4:
			m.box(Vector3(0.06, y + 0.025, 0.06), Vector3(0.42, y + 0.28, 0.36), box)
			m.cylinder(Vector3(0.6, y + 0.025, 0.2), "y", 0.2, 0.08, paint)
			m.cylinder(Vector3(0.78, y + 0.025, 0.2), "y", 0.16, 0.06, galv)
	for i in 4:
		var t := i / 3.0
		m.box(Vector3(0.03 + t * 0.8, 0.1 + t * 1.6, 0.39), Vector3(0.07 + t * 0.8, 0.14 + t * 1.6, 0.4), galv)


func _vice(m: FurnitureModel) -> void:
	var iron := m.paint("cast_iron", Color(0.15, 0.3, 0.55))
	var steel := m.paint("chrome", Color(0.75, 0.76, 0.78), F.BRUSHED)
	m.box(Vector3(0.02, 0.0, 0.08), Vector3(0.22, 0.03, 0.34), iron)
	m.box(Vector3(0.05, 0.03, 0.2), Vector3(0.19, 0.17, 0.3), iron)
	m.box(Vector3(0.05, 0.08, 0.04), Vector3(0.19, 0.17, 0.12), iron)
	m.box(Vector3(0.08, 0.06, 0.12), Vector3(0.16, 0.1, 0.2), iron)
	m.box(Vector3(0.04, 0.17, 0.11), Vector3(0.2, 0.2, 0.125), steel)
	m.box(Vector3(0.04, 0.17, 0.195), Vector3(0.2, 0.2, 0.21), steel)
	m.cylinder(Vector3(0.12, 0.12, 0.04), "z", -0.08, 0.012, steel)
	m.cylinder(Vector3(0.0, 0.12, -0.04), "x", 0.24, 0.007, steel)


func _sawhorse(m: FurnitureModel) -> void:
	var pine := m.paint("pine", Color(0.8, 0.64, 0.42), F.GRAIN)
	m.box(Vector3(0.0, 0.62, 0.2), Vector3(0.9, 0.7, 0.3), pine)
	# Splayed A-frame legs at each end, with a brace.
	for x in [0.08, 0.76]:
		for i in 10:
			var t := i / 9.0
			var y := lerpf(0.0, 0.62, t)
			m.box(Vector3(x, y, lerpf(0.0, 0.18, t)), Vector3(x + 0.06, y + 0.07, lerpf(0.06, 0.24, t)), pine)
			m.box(Vector3(x, y, lerpf(0.44, 0.26, t)), Vector3(x + 0.06, y + 0.07, lerpf(0.5, 0.32, t)), pine)
		m.box(Vector3(x, 0.22, 0.08), Vector3(x + 0.06, 0.27, 0.42), pine)


func _stool(m: FurnitureModel) -> void:
	var seat := m.paint("plywood", Color(0.75, 0.62, 0.44), F.GRAIN)
	var frame := m.paint("painted_steel", Color(0.12, 0.12, 0.13))
	m.cylinder(Vector3(0.19, 0.58, 0.19), "y", 0.04, 0.17, seat)
	for i in 4:
		var angle := TAU * i / 4.0 + PI * 0.25
		var dir := Vector2(cos(angle), sin(angle))
		for s in 10:
			var t := s / 9.0
			var p := Vector2(0.19, 0.19) + dir * lerpf(0.17, 0.11, t)
			m.box(Vector3(p.x - 0.014, t * 0.58, p.y - 0.014), Vector3(p.x + 0.014, t * 0.58 + 0.07, p.y + 0.014), frame)
	m.cylinder(Vector3(0.19, 0.2, 0.19), "y", 0.015, 0.16, frame)
	m.cut_cylinder(Vector3(0.19, 0.2, 0.19), "y", 0.015, 0.14)


func _ladder(m: FurnitureModel) -> void:
	var alu := m.paint("aluminium", Color(0.78, 0.79, 0.8), F.BRUSHED)
	var foot := m.paint("rubber", Color(0.1, 0.1, 0.1))
	var tray := m.paint("plastic", Color(0.9, 0.5, 0.1))
	# An A-frame stepladder, open, with treads on the front and a tool tray on top.
	for side in [0.0, 0.44]:
		for i in 30:
			var t := i / 29.0
			var y := t * 1.5
			m.box(Vector3(side, y, lerpf(0.0, 0.32, t)), Vector3(side + 0.04, y + 0.06, lerpf(0.04, 0.36, t)), alu)
			m.box(Vector3(side, y, lerpf(0.75, 0.4, t)), Vector3(side + 0.04, y + 0.06, lerpf(0.71, 0.36, t)), alu)
		m.box(Vector3(side - 0.005, 0.0, 0.0), Vector3(side + 0.045, 0.03, 0.06), foot)
		m.box(Vector3(side - 0.005, 0.0, 0.69), Vector3(side + 0.045, 0.03, 0.75), foot)
	for i in 4:
		var t := (i + 1) / 5.0
		m.box(Vector3(0.04, t * 1.5, lerpf(0.0, 0.32, t) - 0.04), Vector3(0.44, t * 1.5 + 0.03, lerpf(0.04, 0.32, t) + 0.06), alu)
	m.rounded(Vector3(0.0, 1.5, 0.3), Vector3(0.48, 1.55, 0.46), 0.015, tray)


func _toolbox(m: FurnitureModel) -> void:
	var body := m.paint("plastic", Color(0.15, 0.15, 0.16))
	var lid := m.paint("plastic", Color(0.95, 0.72, 0.1))
	var latch := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	m.rounded(Vector3(0.0, 0.0, 0.0), Vector3(0.5, 0.18, 0.22), 0.02, body)
	m.cut(Vector3(0.03, 0.03, 0.03), Vector3(0.47, 0.19, 0.19))
	for x in [0.06, 0.4]:
		m.box(Vector3(x, 0.14, -0.012), Vector3(x + 0.04, 0.21, 0.0), latch)
	m.begin_part("hinge", "Lid", Vector3(0.25, 0.2, 0.225), Vector3.RIGHT, 100.0)
	m.rounded(Vector3(-0.005, 0.18, -0.005), Vector3(0.505, 0.22, 0.225), 0.02, lid)
	m.box(Vector3(0.12, 0.22, 0.09), Vector3(0.38, 0.26, 0.13), body)
	m.cut(Vector3(0.16, 0.22, 0.09), Vector3(0.34, 0.245, 0.13))
	m.end_part()


func _pallet(m: FurnitureModel) -> void:
	var pine := m.paint("pine", Color(0.76, 0.62, 0.42), F.GRAIN)
	var weathered := m.paint("pine", Color(0.62, 0.55, 0.45), F.GRAIN)
	# Top deck boards, three stringer blocks rows, bottom boards.
	for i in 7:
		var x := i * 0.18
		m.box(Vector3(x, 0.125, 0.0), Vector3(x + 0.12, 0.15, 0.8), pine if i % 3 != 1 else weathered)
	for z in [0.0, 0.35, 0.7]:
		m.box(Vector3(0.0, 0.1, z), Vector3(1.2, 0.125, z + 0.1), pine)
		for x in [0.0, 0.55, 1.1]:
			m.box(Vector3(x, 0.025, z), Vector3(x + 0.1, 0.1, z + 0.1), weathered)
	for x in [0.0, 0.55, 1.1]:
		m.box(Vector3(x, 0.0, 0.0), Vector3(x + 0.1, 0.025, 0.8), pine)


func _garden_rack(m: FurnitureModel) -> void:
	var frame := m.paint("painted_steel", HAMMERITE)
	var wood := m.paint("oak", Color(0.62, 0.46, 0.28), F.GRAIN)
	var steel := m.paint("steel", Color(0.6, 0.62, 0.64), F.BRUSHED)
	var green := m.paint("plastic", Color(0.2, 0.5, 0.25))
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.9, 0.04, 0.35), frame)
	for x in [0.0, 0.86]:
		m.box(Vector3(x, 0.0, 0.3), Vector3(x + 0.04, 1.4, 0.35), frame)
	m.box(Vector3(0.0, 1.0, 0.25), Vector3(0.9, 1.04, 0.35), frame)
	for i in 5:
		m.cut(Vector3(0.1 + i * 0.16, 1.0, 0.27), Vector3(0.14 + i * 0.16, 1.04, 0.31))
	# Spade, fork, rake, hoe and broom standing in the slots.
	for i in 5:
		var x := 0.12 + i * 0.16
		m.box(Vector3(x - 0.012, 0.15, 0.27), Vector3(x + 0.012, 1.38, 0.31), wood)
		match i:
			0:
				m.box(Vector3(x - 0.09, 0.04, 0.27), Vector3(x + 0.09, 0.3, 0.29), steel)
			1:
				for t in 4:
					m.box(Vector3(x - 0.08 + t * 0.05, 0.04, 0.27), Vector3(x - 0.07 + t * 0.05, 0.3, 0.29), steel)
			2:
				m.box(Vector3(x - 0.15, 0.04, 0.27), Vector3(x + 0.15, 0.08, 0.3), steel)
			3:
				m.box(Vector3(x - 0.08, 0.04, 0.27), Vector3(x + 0.08, 0.14, 0.29), steel)
			_:
				m.box(Vector3(x - 0.1, 0.04, 0.25), Vector3(x + 0.1, 0.16, 0.33), green)
