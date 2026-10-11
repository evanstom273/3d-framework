extends RefCounted
## Kitchen and dining (25). Units are 600 mm deep and 900 mm to the worktop.

const CATEGORY := "Kitchen"
const F := FurnitureModel.Finish
const P := preload("res://tools/furniture/furniture_parts.gd")

const SHAKER := Color(0.55, 0.62, 0.6)
const IVORY := Color(0.93, 0.91, 0.85)
const WHITE := Color(0.95, 0.95, 0.94)
const STEEL := Color(0.72, 0.73, 0.75)
const BLACK := Color(0.09, 0.09, 0.1)

const MASSES := {
	"dining_table": 45.0, "dining_table_extendable": 55.0, "dining_chair": 6.0, "bar_stool": 7.0,
	"kitchen_island": 120.0, "breakfast_bar": 60.0, "base_cabinet": 30.0, "wall_cabinet": 18.0,
	"pantry_cabinet": 65.0, "drawer_cabinet": 35.0, "corner_cabinet": 40.0, "sink_unit": 45.0,
	"fridge": 65.0, "freezer": 55.0, "cooker": 60.0, "oven": 35.0, "microwave": 13.0,
	"dishwasher": 45.0, "washing_machine": 70.0, "tumble_dryer": 40.0, "kettle": 1.2, "toaster": 2.0,
	"kitchen_trolley": 16.0, "dish_rack": 1.5, "kitchen_shelving": 14.0,
}


func models() -> Array:
	return [
		_m("dining_table", "Dining Table", Vector3(1.6, 0.76, 0.9), _dining_table),
		_m("dining_table_extendable", "Extendable Dining Table", Vector3(1.8, 0.76, 0.95), _extendable),
		_m("dining_chair", "Dining Chair", Vector3(0.45, 0.95, 0.5), _dining_chair),
		_m("bar_stool", "Bar Stool", Vector3(0.42, 0.78, 0.42), _bar_stool),
		_m("kitchen_island", "Kitchen Island", Vector3(1.8, 0.92, 0.95), _island),
		_m("breakfast_bar", "Breakfast Bar", Vector3(1.5, 1.05, 0.5), _breakfast_bar, {"voxel": 0.022}),
		_m("base_cabinet", "Base Cabinet", Vector3(0.6, 0.92, 0.62), _base_cabinet),
		_m("wall_cabinet", "Wall Cabinet", Vector3(0.6, 0.72, 0.33), _wall_cabinet),
		_m("pantry_cabinet", "Tall Pantry Cabinet", Vector3(0.6, 2.1, 0.6), _pantry),
		_m("drawer_cabinet", "Drawer Cabinet", Vector3(0.6, 0.92, 0.62), _drawer_cabinet),
		_m("corner_cabinet", "Corner Cabinet", Vector3(0.95, 0.92, 0.95), _corner_cabinet),
		_m("sink_unit", "Kitchen Sink Unit", Vector3(1.0, 1.05, 0.62), _sink_unit),
		_m("fridge", "Fridge", Vector3(0.6, 1.85, 0.66), _fridge),
		_m("freezer", "Chest Freezer", Vector3(1.0, 0.86, 0.6), _freezer),
		_m("cooker", "Cooker", Vector3(0.6, 0.94, 0.62), _cooker),
		_m("oven", "Built-in Oven", Vector3(0.6, 0.6, 0.56), _oven),
		_m("microwave", "Microwave", Vector3(0.5, 0.3, 0.38), _microwave),
		_m("dishwasher", "Dishwasher", Vector3(0.6, 0.85, 0.6), _dishwasher),
		_m("washing_machine", "Washing Machine", Vector3(0.6, 0.85, 0.6), _washing_machine),
		_m("tumble_dryer", "Tumble Dryer", Vector3(0.6, 0.85, 0.6), _tumble_dryer),
		_m("kettle", "Kettle", Vector3(0.24, 0.26, 0.16), _kettle),
		_m("toaster", "Toaster", Vector3(0.3, 0.2, 0.18), _toaster),
		_m("kitchen_trolley", "Kitchen Trolley", Vector3(0.7, 0.9, 0.42), _trolley),
		_m("dish_rack", "Dish Rack", Vector3(0.46, 0.18, 0.32), _dish_rack),
		_m("kitchen_shelving", "Freestanding Kitchen Shelving", Vector3(0.9, 1.6, 0.4), _shelving),
	]


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


# --- Tables and seating

func _dining_table(m: FurnitureModel) -> void:
	var oak := m.paint("oak", Color(0.62, 0.45, 0.28), F.GRAIN)
	var apron := m.paint("oak", Color(0.55, 0.39, 0.24), F.GRAIN)
	m.rounded(Vector3(0.0, 0.72, 0.0), Vector3(1.6, 0.76, 0.9), 0.015, oak, "y")
	m.legs(0.0, 0.0, 1.6, 0.9, 0.72, 0.07, 0.05, apron, true, 0.72)
	m.box(Vector3(0.12, 0.63, 0.06), Vector3(1.48, 0.72, 0.09), apron)
	m.box(Vector3(0.12, 0.63, 0.81), Vector3(1.48, 0.72, 0.84), apron)
	m.box(Vector3(0.06, 0.63, 0.12), Vector3(0.09, 0.72, 0.78), apron)
	m.box(Vector3(1.51, 0.63, 0.12), Vector3(1.54, 0.72, 0.78), apron)


func _extendable(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.38, 0.25, 0.16), F.GRAIN)
	var leaf := m.paint("walnut", Color(0.44, 0.3, 0.19), F.GRAIN)
	var runner := m.paint("steel", Color(0.4, 0.4, 0.42), F.BRUSHED)
	# Two halves pulled apart on runners with the extension leaf between.
	m.rounded(Vector3(0.0, 0.72, 0.0), Vector3(0.75, 0.76, 0.95), 0.015, walnut, "y")
	m.rounded(Vector3(1.05, 0.72, 0.0), Vector3(1.8, 0.76, 0.95), 0.015, walnut, "y")
	m.box(Vector3(0.75, 0.722, 0.0), Vector3(1.05, 0.758, 0.95), leaf)
	for z in [0.2, 0.72]:
		m.box(Vector3(0.2, 0.66, z), Vector3(1.6, 0.7, z + 0.03), runner)
	# Pedestal legs: a column on a cross foot at each end.
	for x in [0.3, 1.5]:
		m.cylinder(Vector3(x, 0.08, 0.475), "y", 0.62, 0.06, walnut, 0.045)
		m.rounded(Vector3(x - 0.04, 0.0, 0.12), Vector3(x + 0.04, 0.08, 0.83), 0.02, walnut)
		m.box(Vector3(x - 0.04, 0.66, 0.15), Vector3(x + 0.04, 0.72, 0.8), walnut)


func _dining_chair(m: FurnitureModel) -> void:
	var frame := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	var seat := m.paint("fabric", Color(0.55, 0.46, 0.35), F.FABRIC)
	P.chair(m, 0.45, 0.5, 0.46, 0.95, frame, seat, 4, true)


func _bar_stool(m: FurnitureModel) -> void:
	var chrome := m.paint("chrome", Color(0.82, 0.83, 0.85), F.BRUSHED)
	var seat := m.paint("leather", Color(0.15, 0.13, 0.12), F.FABRIC)
	m.cylinder(Vector3(0.21, 0.0, 0.21), "y", 0.02, 0.2, chrome, 0.18)
	m.cylinder(Vector3(0.21, 0.02, 0.21), "y", 0.62, 0.025, chrome)
	# Foot ring.
	m.cylinder(Vector3(0.21, 0.28, 0.21), "y", 0.02, 0.17, chrome)
	m.cut_cylinder(Vector3(0.21, 0.28, 0.21), "y", 0.02, 0.15)
	m.cylinder(Vector3(0.21, 0.64, 0.21), "y", 0.08, 0.2, seat, 0.19)
	m.rounded(Vector3(0.04, 0.7, 0.33), Vector3(0.38, 0.78, 0.4), 0.03, seat)


# --- Units

func _base_cabinet(m: FurnitureModel) -> void:
	var body := m.paint("chipboard", Color(0.9, 0.89, 0.86))
	var door := m.paint("painted_wood", SHAKER)
	var top := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	var brass := m.paint("brass", Color(0.75, 0.6, 0.32), F.BRUSHED)
	P.plinth(m, 0.0, 0.6, 0.6, 0.12, door)
	P.carcass(m, Vector3(0.0, 0.12, 0.02), Vector3(0.6, 0.88, 0.6), 0.02, body)
	m.box(Vector3(0.02, 0.45, 0.04), Vector3(0.58, 0.47, 0.58), body)
	m.door_front(Vector3(0.005, 0.13, 0.0), Vector3(0.595, 0.87, 0.022), door, brass, true)
	P.worktop(m, 0.0, 0.6, 0.88, 0.62, 0.04, top)


func _wall_cabinet(m: FurnitureModel) -> void:
	var body := m.paint("chipboard", Color(0.9, 0.89, 0.86))
	var door := m.paint("painted_wood", SHAKER)
	var brass := m.paint("brass", Color(0.75, 0.6, 0.32), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.0, 0.02), Vector3(0.6, 0.72, 0.33), 0.02, body)
	m.box(Vector3(0.02, 0.35, 0.04), Vector3(0.58, 0.37, 0.31), body)
	m.door_front(Vector3(0.005, 0.005, 0.0), Vector3(0.595, 0.715, 0.022), door, brass, true)
	m.box(Vector3(0.1, 0.62, 0.32), Vector3(0.5, 0.66, 0.33), m.paint("steel", Color(0.5, 0.5, 0.52)))


func _pantry(m: FurnitureModel) -> void:
	var body := m.paint("chipboard", Color(0.9, 0.89, 0.86))
	var door := m.paint("painted_wood", SHAKER)
	var brass := m.paint("brass", Color(0.75, 0.6, 0.32), F.BRUSHED)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	P.plinth(m, 0.0, 0.6, 0.58, 0.12, door)
	P.carcass(m, Vector3(0.0, 0.12, 0.02), Vector3(0.6, 2.1, 0.6), 0.02, body)
	for y in [0.55, 0.95, 1.35, 1.75]:
		m.box(Vector3(0.02, y, 0.04), Vector3(0.58, y + 0.02, 0.58), body)
		# Jars and tins on the shelves behind the doors.
		for i in 4:
			m.cylinder(Vector3(0.1 + i * 0.13, y + 0.02, 0.4), "y", rng.randf_range(0.1, 0.2), 0.04, m.paint("glass" if i % 2 == 0 else "steel", Color(0.7, 0.8, 0.8) if i % 2 == 0 else Color(0.7, 0.2, 0.15)))
	m.door_front(Vector3(0.005, 0.13, 0.0), Vector3(0.595, 1.2, 0.022), door, brass, true)
	m.door_front(Vector3(0.005, 1.21, 0.0), Vector3(0.595, 2.09, 0.022), door, brass, true)


func _drawer_cabinet(m: FurnitureModel) -> void:
	var body := m.paint("chipboard", Color(0.9, 0.89, 0.86))
	var front := m.paint("painted_wood", IVORY)
	var top := m.paint("marble", Color(0.2, 0.2, 0.21), F.SPECKLE)
	var steel := m.paint("steel", Color(0.55, 0.56, 0.58), F.BRUSHED)
	P.plinth(m, 0.0, 0.6, 0.6, 0.12, front)
	P.carcass(m, Vector3(0.0, 0.12, 0.02), Vector3(0.6, 0.88, 0.6), 0.02, body)
	var heights := [0.13, 0.32, 0.53, 0.72, 0.87]
	for i in 4:
		m.drawer(Vector3(0.005, heights[i], 0.0), Vector3(0.595, heights[i + 1] - 0.005, 0.022), front, steel, "cup")
	P.worktop(m, 0.0, 0.6, 0.88, 0.62, 0.04, top)


func _corner_cabinet(m: FurnitureModel) -> void:
	var body := m.paint("chipboard", Color(0.9, 0.89, 0.86))
	var door := m.paint("painted_wood", SHAKER)
	var top := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	var brass := m.paint("brass", Color(0.75, 0.6, 0.32), F.BRUSHED)
	# An L-shaped unit: two carcasses meeting in the corner, with a bi-fold door.
	P.carcass(m, Vector3(0.0, 0.12, 0.35), Vector3(0.95, 0.88, 0.95), 0.02, body)
	P.carcass(m, Vector3(0.35, 0.12, 0.0), Vector3(0.95, 0.88, 0.37), 0.02, body)
	# Plinths under both carcasses (set back from the fronts), so it stands level.
	m.box(Vector3(0.01, 0.0, 0.39), Vector3(0.93, 0.12, 0.93), door)
	m.box(Vector3(0.39, 0.0, 0.04), Vector3(0.93, 0.12, 0.4), door)
	m.door_front(Vector3(0.0, 0.13, 0.33), Vector3(0.35, 0.87, 0.355), door, brass, false)
	m.door_front(Vector3(0.36, 0.13, 0.0), Vector3(0.94, 0.87, 0.022), door, brass, true)
	# An L-shaped worktop following the two carcasses, overhanging their fronts.
	m.rounded(Vector3(0.0, 0.88, 0.31), Vector3(0.95, 0.92, 0.95), 0.012, top, "y")
	m.rounded(Vector3(0.33, 0.88, -0.02), Vector3(0.95, 0.92, 0.37), 0.012, top, "y")


func _sink_unit(m: FurnitureModel) -> void:
	var body := m.paint("chipboard", Color(0.9, 0.89, 0.86))
	var door := m.paint("painted_wood", IVORY)
	var top := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	var ceramic := m.paint("ceramic", WHITE)
	var chrome := m.paint("chrome", Color(0.82, 0.83, 0.85), F.BRUSHED)
	var brass := m.paint("brass", Color(0.75, 0.6, 0.32), F.BRUSHED)
	P.plinth(m, 0.0, 1.0, 0.6, 0.12, door)
	P.carcass(m, Vector3(0.0, 0.12, 0.02), Vector3(1.0, 0.88, 0.6), 0.02, body)
	m.door_front(Vector3(0.005, 0.13, 0.0), Vector3(0.495, 0.75, 0.022), door, brass, false)
	m.door_front(Vector3(0.505, 0.13, 0.0), Vector3(0.995, 0.75, 0.022), door, brass, true)
	P.worktop(m, 0.0, 1.0, 0.88, 0.62, 0.04, top)
	# A ceramic Belfast sink set into the front, with a bridge mixer tap.
	m.box(Vector3(0.2, 0.68, -0.03), Vector3(0.8, 0.92, 0.5), ceramic)
	m.cut(Vector3(0.24, 0.72, 0.01), Vector3(0.76, 0.93, 0.46))
	m.cylinder(Vector3(0.5, 0.92, 0.55), "y", 0.08, 0.018, chrome)
	m.cylinder(Vector3(0.5, 1.0, 0.55), "z", -0.16, 0.012, chrome)
	m.box(Vector3(0.38, 0.92, 0.52), Vector3(0.62, 0.95, 0.56), chrome)
	for x in [0.38, 0.62]:
		m.cylinder(Vector3(x, 0.95, 0.54), "y", 0.05, 0.016, chrome)


# --- Appliances

func _fridge(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.66, 0.78, 0.8))
	var seal := m.paint("rubber", Color(0.2, 0.2, 0.2))
	var chrome := m.paint("chrome", Color(0.82, 0.83, 0.85), F.BRUSHED)
	# A retro rounded fridge-freezer: two doors, chrome handles, a badge.
	P.appliance(m, Vector3(0.0, 0.06, 0.04), Vector3(0.6, 1.85, 0.66), body, 0.05)
	m.repaint(Vector3(0.0, 1.22, 0.04), Vector3(0.6, 1.24, 0.1), seal)
	# Fridge and freezer compartments behind two doors hinged on the left.
	m.cut(Vector3(0.05, 0.12, 0.05), Vector3(0.55, 1.17, 0.6))
	m.cut(Vector3(0.05, 1.29, 0.05), Vector3(0.55, 1.79, 0.6))
	m.begin_part("hinge", "Fridge door", Vector3(0.01, 0.6, 0.0), Vector3.UP, 110.0)
	m.rounded(Vector3(0.01, 0.07, 0.0), Vector3(0.59, 1.21, 0.05), 0.04, body)
	P.bar_handle(m, 0.52, 0.85, 1.05, 0.0, chrome, true)
	m.end_part()
	m.begin_part("hinge", "Freezer door", Vector3(0.01, 1.5, 0.0), Vector3.UP, 110.0)
	m.rounded(Vector3(0.01, 1.25, 0.0), Vector3(0.59, 1.83, 0.05), 0.04, body)
	P.bar_handle(m, 0.52, 1.3, 1.5, 0.0, chrome, true)
	m.end_part()
	m.box(Vector3(0.24, 1.7, -0.008), Vector3(0.36, 1.74, 0.0), chrome)
	for x in [0.06, 0.5]:
		m.box(Vector3(x, 0.0, 0.1), Vector3(x + 0.04, 0.06, 0.6), seal)


func _freezer(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", WHITE)
	var lid := m.paint("painted_steel", Color(0.97, 0.97, 0.96))
	var plastic := m.paint("plastic", Color(0.6, 0.62, 0.64))
	P.appliance(m, Vector3(0.0, 0.04, 0.0), Vector3(1.0, 0.82, 0.6), body, 0.02)
	m.cut(Vector3(0.05, 0.1, 0.05), Vector3(0.95, 0.83, 0.55))
	m.begin_part("hinge", "Lid", Vector3(0.5, 0.86, 0.605), Vector3.RIGHT, 80.0)
	m.rounded(Vector3(-0.005, 0.82, -0.005), Vector3(1.005, 0.86, 0.605), 0.015, lid)
	m.box(Vector3(0.4, 0.78, -0.03), Vector3(0.6, 0.82, 0.0), plastic)
	m.end_part()
	m.box(Vector3(0.06, 0.08, -0.006), Vector3(0.2, 0.18, 0.0), plastic)
	for x in [0.04, 0.9]:
		m.box(Vector3(x, 0.0, 0.05), Vector3(x + 0.06, 0.04, 0.55), plastic)


func _cooker(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.86, 0.85, 0.82))
	var black := m.paint("electronics", BLACK)
	var glass := m.paint("glass", Color(0.12, 0.12, 0.13))
	var iron := m.paint("cast_iron", Color(0.12, 0.12, 0.13))
	var chrome := m.paint("chrome", Color(0.82, 0.83, 0.85), F.BRUSHED)
	P.appliance(m, Vector3(0.0, 0.0, 0.0), Vector3(0.6, 0.9, 0.62), body, 0.01)
	# Hob with four burners and pan supports, control panel, oven door with window.
	m.box(Vector3(0.0, 0.9, 0.04), Vector3(0.6, 0.91, 0.62), black)
	for burner in [Vector2(0.16, 0.18), Vector2(0.44, 0.18), Vector2(0.16, 0.45), Vector2(0.44, 0.45)]:
		m.cylinder(Vector3(burner.x, 0.91, burner.y), "y", 0.012, 0.045, iron)
		m.box(Vector3(burner.x - 0.1, 0.92, burner.y - 0.006), Vector3(burner.x + 0.1, 0.935, burner.y + 0.006), iron)
		m.box(Vector3(burner.x - 0.006, 0.92, burner.y - 0.1), Vector3(burner.x + 0.006, 0.935, burner.y + 0.1), iron)
	m.box(Vector3(0.0, 0.8, -0.01), Vector3(0.6, 0.9, 0.0), black)
	for i in 5:
		P.knob(m, 0.08 + i * 0.11, 0.85, -0.01, 0.018, chrome)
	m.cut(Vector3(0.06, 0.15, 0.0), Vector3(0.54, 0.7, 0.5))
	m.begin_part("hinge", "Oven door", Vector3(0.3, 0.12, -0.02), Vector3.RIGHT, -85.0)
	m.box(Vector3(0.03, 0.12, -0.02), Vector3(0.57, 0.74, 0.0), body)
	m.box(Vector3(0.1, 0.25, -0.022), Vector3(0.5, 0.6, -0.018), glass)
	P.bar_handle(m, 0.08, 0.52, 0.68, -0.02, chrome)
	m.end_part()
	m.box(Vector3(0.03, 0.02, -0.01), Vector3(0.57, 0.1, 0.0), black)


func _oven(m: FurnitureModel) -> void:
	var body := m.paint("steel", Color(0.6, 0.61, 0.63), F.BRUSHED)
	var black := m.paint("electronics", BLACK)
	var glass := m.paint("glass", Color(0.1, 0.1, 0.11))
	var chrome := m.paint("chrome", Color(0.82, 0.83, 0.85), F.BRUSHED)
	P.appliance(m, Vector3(0.02, 0.0, 0.02), Vector3(0.58, 0.58, 0.56), black, 0.005)
	m.box(Vector3(0.0, 0.47, 0.0), Vector3(0.6, 0.6, 0.025), body)
	m.cut(Vector3(0.06, 0.06, 0.025), Vector3(0.54, 0.42, 0.5))
	m.begin_part("hinge", "Oven door", Vector3(0.3, 0.0, 0.0), Vector3.RIGHT, -85.0)
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.6, 0.46, 0.025), body)
	m.box(Vector3(0.08, 0.08, -0.004), Vector3(0.52, 0.36, 0.0), glass)
	P.bar_handle(m, 0.06, 0.54, 0.41, 0.0, chrome)
	m.end_part()
	m.box(Vector3(0.24, 0.5, -0.006), Vector3(0.36, 0.56, 0.0), m.paint("screen", Color(0.05, 0.1, 0.15)))
	P.knob(m, 0.1, 0.535, 0.0, 0.02, chrome)
	P.knob(m, 0.5, 0.535, 0.0, 0.02, chrome)


func _microwave(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.2, 0.2, 0.22))
	var glass := m.paint("glass", Color(0.08, 0.08, 0.1))
	var panel := m.paint("electronics", BLACK)
	var silver := m.paint("aluminium", Color(0.75, 0.76, 0.78), F.BRUSHED)
	P.appliance(m, Vector3(0.0, 0.02, 0.0), Vector3(0.5, 0.3, 0.38), body, 0.012)
	m.cut(Vector3(0.04, 0.06, 0.0), Vector3(0.32, 0.26, 0.34))
	m.begin_part("hinge", "Door", Vector3(0.02, 0.16, -0.006), Vector3.UP, 100.0)
	m.box(Vector3(0.02, 0.05, -0.006), Vector3(0.34, 0.27, 0.0), glass)
	m.end_part()
	m.box(Vector3(0.36, 0.05, -0.006), Vector3(0.48, 0.27, 0.0), panel)
	m.box(Vector3(0.38, 0.22, -0.01), Vector3(0.46, 0.25, -0.006), m.paint("screen", Color(0.1, 0.3, 0.2)))
	P.knob(m, 0.42, 0.14, -0.006, 0.025, silver)
	for x in [0.04, 0.42]:
		m.box(Vector3(x, 0.0, 0.05), Vector3(x + 0.04, 0.02, 0.33), panel)


func _dishwasher(m: FurnitureModel) -> void:
	var body := m.paint("steel", Color(0.68, 0.69, 0.71), F.BRUSHED)
	var black := m.paint("electronics", BLACK)
	P.appliance(m, Vector3(0.0, 0.08, 0.02), Vector3(0.6, 0.85, 0.6), body, 0.01)
	m.cut(Vector3(0.04, 0.1, 0.02), Vector3(0.56, 0.8, 0.56))
	m.begin_part("hinge", "Door", Vector3(0.3, 0.08, -0.01), Vector3.RIGHT, -85.0)
	m.box(Vector3(0.0, 0.08, -0.01), Vector3(0.6, 0.72, 0.02), body)
	m.box(Vector3(0.0, 0.72, -0.01), Vector3(0.6, 0.84, 0.02), black)
	for i in 6:
		m.box(Vector3(0.06 + i * 0.05, 0.775, -0.014), Vector3(0.085 + i * 0.05, 0.79, -0.01), m.paint("plastic", Color(0.8, 0.8, 0.82)))
	m.box(Vector3(0.38, 0.765, -0.014), Vector3(0.54, 0.795, -0.01), m.paint("screen", Color(0.1, 0.2, 0.3)))
	m.box(Vector3(0.22, 0.66, -0.02), Vector3(0.38, 0.7, -0.01), black)
	m.end_part()
	m.box(Vector3(0.0, 0.0, 0.05), Vector3(0.6, 0.08, 0.07), black)
	# Adjustable feet at the back, so it stands level on the kick plate and these.
	for x in [0.03, 0.52]:
		m.box(Vector3(x, 0.0, 0.5), Vector3(x + 0.05, 0.08, 0.57), black)


func _washing_machine(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", WHITE)
	var trim := m.paint("plastic", Color(0.85, 0.86, 0.88))
	var glass := m.paint("glass", Color(0.55, 0.65, 0.72))
	var drum := m.paint("steel", Color(0.6, 0.62, 0.65), F.BRUSHED)
	P.appliance(m, Vector3(0.0, 0.02, 0.0), Vector3(0.6, 0.85, 0.6), body, 0.015)
	m.box(Vector3(0.0, 0.72, -0.008), Vector3(0.6, 0.84, 0.0), trim)
	m.box(Vector3(0.02, 0.75, -0.015), Vector3(0.2, 0.81, -0.008), trim)
	P.knob(m, 0.46, 0.78, -0.008, 0.03, trim)
	m.box(Vector3(0.28, 0.76, -0.012), Vector3(0.38, 0.8, -0.008), m.paint("screen", Color(0.1, 0.15, 0.2)))
	# Porthole door: chrome-look ring, glass, drum behind.
	m.cut_cylinder(Vector3(0.3, 0.42, 0.0), "z", 0.04, 0.17)
	m.begin_part("hinge", "Door", Vector3(0.1, 0.42, -0.05), Vector3.UP, 100.0)
	m.cylinder(Vector3(0.3, 0.42, 0.0), "z", -0.05, 0.2, trim)
	m.cut_cylinder(Vector3(0.3, 0.42, -0.06), "z", 0.07, 0.15)
	m.cylinder(Vector3(0.3, 0.42, -0.03), "z", 0.012, 0.15, glass)
	m.end_part()
	m.cylinder(Vector3(0.3, 0.42, 0.04), "z", 0.02, 0.17, drum)


func _tumble_dryer(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.93, 0.93, 0.92))
	var trim := m.paint("plastic", Color(0.55, 0.57, 0.6))
	var glass := m.paint("glass", Color(0.4, 0.45, 0.5))
	P.appliance(m, Vector3(0.0, 0.02, 0.0), Vector3(0.6, 0.85, 0.6), body, 0.015)
	m.box(Vector3(0.0, 0.72, -0.008), Vector3(0.6, 0.84, 0.0), trim)
	P.knob(m, 0.12, 0.78, -0.008, 0.03, body)
	for i in 3:
		m.box(Vector3(0.3 + i * 0.08, 0.77, -0.012), Vector3(0.35 + i * 0.08, 0.79, -0.008), body)
	m.cut_cylinder(Vector3(0.3, 0.42, 0.0), "z", 0.3, 0.17)
	m.begin_part("hinge", "Door", Vector3(0.09, 0.42, -0.04), Vector3.UP, 100.0)
	m.cylinder(Vector3(0.3, 0.42, 0.0), "z", -0.04, 0.21, trim)
	m.cylinder(Vector3(0.3, 0.42, -0.04), "z", 0.012, 0.16, glass)
	m.end_part()
	m.box(Vector3(0.06, 0.06, -0.006), Vector3(0.54, 0.14, 0.0), trim)
	for i in 8:
		m.box(Vector3(0.08 + i * 0.055, 0.08, -0.008), Vector3(0.1 + i * 0.055, 0.12, -0.006), m.paint("plastic", Color(0.3, 0.3, 0.32)))


func _kettle(m: FurnitureModel) -> void:
	var steel := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	var black := m.paint("plastic", Color(0.08, 0.08, 0.09))
	m.cylinder(Vector3(0.1, 0.0, 0.08), "y", 0.02, 0.085, black)
	m.cylinder(Vector3(0.1, 0.02, 0.08), "y", 0.18, 0.08, steel, 0.065)
	m.cylinder(Vector3(0.1, 0.2, 0.08), "y", 0.02, 0.03, black)
	# Spout to the front, handle at the back.
	m.cylinder(Vector3(0.1, 0.13, 0.03), "z", -0.05, 0.015, steel, 0.01)
	m.box(Vector3(0.09, 0.05, 0.15), Vector3(0.11, 0.22, 0.17), black)
	m.box(Vector3(0.09, 0.2, 0.11), Vector3(0.11, 0.22, 0.17), black)
	m.box(Vector3(0.09, 0.05, 0.11), Vector3(0.11, 0.07, 0.17), black)


func _toaster(m: FurnitureModel) -> void:
	var body := m.paint("painted_steel", Color(0.75, 0.15, 0.12))
	var chrome := m.paint("chrome", Color(0.82, 0.83, 0.85), F.BRUSHED)
	var black := m.paint("plastic", Color(0.08, 0.08, 0.09))
	P.appliance(m, Vector3(0.0, 0.02, 0.0), Vector3(0.3, 0.2, 0.18), body, 0.03)
	for x in [0.07, 0.17]:
		m.cut(Vector3(x, 0.15, 0.04), Vector3(x + 0.035, 0.21, 0.14))
	m.box(Vector3(0.28, 0.12, 0.07), Vector3(0.31, 0.16, 0.11), black)
	m.box(Vector3(0.02, 0.06, -0.006), Vector3(0.1, 0.09, 0.0), chrome)
	for x in [0.02, 0.24]:
		m.box(Vector3(x, 0.0, 0.03), Vector3(x + 0.04, 0.02, 0.15), black)


# --- Islands, bars, trolleys and racks

func _island(m: FurnitureModel) -> void:
	var body := m.paint("painted_wood", Color(0.2, 0.27, 0.33))
	var top := m.paint("marble", Color(0.92, 0.91, 0.88), F.SPECKLE)
	var brass := m.paint("brass", Color(0.75, 0.6, 0.32), F.BRUSHED)
	P.plinth(m, 0.0, 1.8, 0.62, 0.12, body)
	P.carcass(m, Vector3(0.0, 0.12, 0.02), Vector3(1.8, 0.88, 0.62), 0.025, body)
	for i in 3:
		var x := 0.01 + i * 0.6
		m.drawer(Vector3(x, 0.66, 0.0), Vector3(x + 0.58, 0.87, 0.022), body, brass, "bar")
		m.door_front(Vector3(x, 0.13, 0.0), Vector3(x + 0.58, 0.65, 0.022), body, brass, i % 2 == 0)
	# Worktop overhangs the back as a breakfast ledge.
	m.rounded(Vector3(-0.03, 0.88, -0.03), Vector3(1.83, 0.92, 0.95), 0.015, top, "y")
	for x in [0.3, 1.5]:
		m.box(Vector3(x, 0.12, 0.62), Vector3(x + 0.05, 0.88, 0.67), body)


func _breakfast_bar(m: FurnitureModel) -> void:
	var oak := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	var steel := m.paint("painted_steel", BLACK)
	m.rounded(Vector3(0.0, 1.01, 0.0), Vector3(1.5, 1.05, 0.5), 0.015, oak, "y")
	# Black steel hairpin-style frame with a foot rail.
	for x in [0.08, 1.4]:
		for z in [0.06, 0.42]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.03, 1.01, z + 0.03), steel)
		m.box(Vector3(x, 0.95, 0.06), Vector3(x + 0.03, 1.01, 0.45), steel)
	m.cylinder(Vector3(0.08, 0.25, 0.08), "x", 1.35, 0.012, steel)
	m.box(Vector3(0.08, 0.96, 0.22), Vector3(1.43, 1.01, 0.25), steel)


func _trolley(m: FurnitureModel) -> void:
	var beech := m.paint("pine", Color(0.84, 0.7, 0.5), F.GRAIN)
	var chrome := m.paint("chrome", Color(0.82, 0.83, 0.85), F.BRUSHED)
	var rubber := m.paint("rubber", Color(0.1, 0.1, 0.1))
	for y in [0.12, 0.45, 0.86]:
		m.rounded(Vector3(0.0, y, 0.0), Vector3(0.7, y + 0.03, 0.42), 0.01, beech, "y")
	for x in [0.02, 0.65]:
		for z in [0.02, 0.37]:
			m.box(Vector3(x, 0.06, z), Vector3(x + 0.03, 0.89, z + 0.03), beech)
			m.cylinder(Vector3(x + 0.015, 0.03, z + 0.015), "x", 0.03, 0.03, rubber)
	P.bar_handle(m, 0.12, 0.58, 0.8, 0.0, chrome)
	# A row of towels on the rail and a cutting board on top.
	m.box(Vector3(0.15, 0.89, 0.1), Vector3(0.5, 0.91, 0.32), m.paint("oak", Color(0.7, 0.52, 0.32), F.GRAIN))


func _dish_rack(m: FurnitureModel) -> void:
	var wire := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	var tray := m.paint("plastic", Color(0.3, 0.32, 0.35))
	var plate := m.paint("ceramic", Color(0.95, 0.95, 0.93))
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(0.46, 0.015, 0.32), tray)
	for x in [0.0, 0.445]:
		m.box(Vector3(x, 0.015, 0.0), Vector3(x + 0.015, 0.12, 0.32), wire)
	for i in 10:
		var x := 0.05 + i * 0.035
		m.box(Vector3(x, 0.015, 0.04), Vector3(x + 0.006, 0.12, 0.05), wire)
		m.box(Vector3(x, 0.015, 0.27), Vector3(x + 0.006, 0.12, 0.28), wire)
	for i in 6:
		var x := 0.06 + i * 0.06
		m.cylinder(Vector3(x, 0.12, 0.16), "x", 0.012, 0.11, plate)


func _shelving(m: FurnitureModel) -> void:
	var steel := m.paint("painted_steel", BLACK)
	var shelf := m.paint("pine", Color(0.82, 0.68, 0.46), F.GRAIN)
	var jar := m.paint("glass", Color(0.75, 0.85, 0.85))
	var pot := m.paint("ceramic", Color(0.3, 0.45, 0.6))
	for x in [0.0, 0.87]:
		for z in [0.0, 0.37]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.03, 1.6, z + 0.03), steel)
	for i in 4:
		var y := 0.1 + i * 0.48
		m.box(Vector3(0.0, y, 0.0), Vector3(0.9, y + 0.025, 0.4), shelf)
		if i < 3:
			for j in 4:
				var x := 0.1 + j * 0.2
				if (i + j) % 2 == 0:
					m.cylinder(Vector3(x, y + 0.025, 0.2), "y", 0.16, 0.05, jar)
				else:
					m.cylinder(Vector3(x, y + 0.025, 0.2), "y", 0.1, 0.07, pot, 0.08)
					m.cut_cylinder(Vector3(x, y + 0.04, 0.2), "y", 0.1, 0.06)
