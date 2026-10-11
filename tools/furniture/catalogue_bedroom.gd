extends RefCounted
## Bedroom (20).

const CATEGORY := "Bedroom"
const F := FurnitureModel.Finish
const P := preload("res://tools/furniture/furniture_parts.gd")

const LINEN := Color(0.93, 0.92, 0.88)
const DUVET_BLUE := Color(0.45, 0.55, 0.68)
const DUVET_GREEN := Color(0.55, 0.62, 0.5)
const PINK := Color(0.85, 0.66, 0.64)
const DOVE := Color(0.72, 0.72, 0.7)

const MASSES := {
	"bed_single": 45.0, "bed_double": 70.0, "bed_king": 90.0, "bunk_bed": 80.0, "bedside_cabinet": 14.0,
	"bedside_table": 7.0, "chest_of_drawers": 40.0, "chest_of_drawers_tall": 50.0, "wardrobe_double": 85.0,
	"wardrobe_single": 50.0, "dressing_table": 25.0, "dressing_stool": 5.0, "mirror_full_length": 9.0,
	"bedroom_desk": 22.0, "bedroom_desk_chair": 6.0, "blanket_chest": 20.0, "storage_bench": 16.0,
	"bedroom_bookshelf": 20.0, "clothes_rail": 8.0, "laundry_basket": 2.5,
}


func models() -> Array:
	return [
		_m("bed_single", "Single Bed", Vector3(0.98, 1.0, 2.05), func(m): _bed(m, 0.9, DUVET_BLUE, "pine")),
		_m("bed_double", "Double Bed", Vector3(1.43, 1.1, 2.1), func(m): _bed(m, 1.35, DUVET_GREEN, "oak")),
		_m("bed_king", "King-Size Bed", Vector3(1.6, 1.25, 2.15), func(m): _bed(m, 1.5, LINEN, "upholstered")),
		_m("bunk_bed", "Bunk Bed", Vector3(1.0, 1.65, 2.05), _bunk_bed),
		_m("bedside_cabinet", "Bedside Cabinet", Vector3(0.45, 0.58, 0.4), _bedside_cabinet),
		_m("bedside_table", "Bedside Table", Vector3(0.42, 0.55, 0.38), _bedside_table),
		_m("chest_of_drawers", "Chest of Drawers", Vector3(0.9, 0.85, 0.46), func(m): _chest(m, 0.85, [2, 1, 1, 1])),
		_m("chest_of_drawers_tall", "Tall Chest of Drawers", Vector3(0.6, 1.25, 0.46), func(m): _chest(m, 1.25, [1, 1, 1, 1, 1, 1])),
		_m("wardrobe_double", "Double Wardrobe", Vector3(1.0, 1.95, 0.6), func(m): _wardrobe(m, 2)),
		_m("wardrobe_single", "Single Wardrobe", Vector3(0.55, 1.85, 0.58), func(m): _wardrobe(m, 1)),
		_m("dressing_table", "Dressing Table", Vector3(1.1, 1.45, 0.45), _dressing_table),
		_m("dressing_stool", "Dressing Stool", Vector3(0.45, 0.46, 0.35), _dressing_stool),
		_m("mirror_full_length", "Full-Length Mirror", Vector3(0.5, 1.6, 0.42), _cheval_mirror, {"voxel": 0.02}),
		_m("bedroom_desk", "Bedroom Desk", Vector3(1.1, 0.76, 0.5), _desk),
		_m("bedroom_desk_chair", "Desk Chair", Vector3(0.44, 0.88, 0.48), _desk_chair),
		_m("blanket_chest", "Blanket Chest", Vector3(0.9, 0.5, 0.45), _blanket_chest),
		_m("storage_bench", "Storage Bench", Vector3(1.0, 0.48, 0.4), _storage_bench),
		_m("bedroom_bookshelf", "Bookshelf", Vector3(0.6, 1.4, 0.28), _bookshelf),
		_m("clothes_rail", "Clothes Rail", Vector3(1.2, 1.6, 0.5), _clothes_rail),
		_m("laundry_basket", "Laundry Basket", Vector3(0.42, 0.55, 0.32), _laundry_basket),
	]


func _m(id: String, title: String, size: Vector3, build: Callable, extra := {}) -> Dictionary:
	var spec := {"id": id, "name": title, "category": CATEGORY, "size": size, "build": build, "mass": MASSES.get(id, 0.0)}
	spec.merge(extra)
	return spec


# --- Beds

## A bed: frame (timber or upholstered), slats, mattress, duvet, pillows.
## The headboard is at the back (+Z); the foot faces the player.
func _bed(m: FurnitureModel, mattress_w: float, duvet_color: Color, frame_kind: String) -> void:
	var w := m.size.x
	var d := m.size.z
	var upholstered := frame_kind == "upholstered"
	var frame := m.paint("fabric", Color(0.6, 0.58, 0.55), F.FABRIC) if upholstered else m.paint(frame_kind, Color(0.8, 0.64, 0.42) if frame_kind == "pine" else Color(0.6, 0.43, 0.26), F.GRAIN)
	var mattress := m.paint("foam", Color(0.94, 0.94, 0.92), F.FABRIC)
	var duvet := m.paint("fabric", duvet_color, F.FABRIC)
	var sheet := m.paint("fabric", LINEN, F.FABRIC)
	var x0 := (w - mattress_w) * 0.5
	# Side rails, foot rail and legs.
	m.box(Vector3(0.0, 0.12, 0.0), Vector3(0.04, 0.32, d - 0.06), frame)
	m.box(Vector3(w - 0.04, 0.12, 0.0), Vector3(w, 0.32, d - 0.06), frame)
	m.box(Vector3(0.0, 0.12, 0.0), Vector3(w, 0.4 if not upholstered else 0.32, 0.05), frame)
	m.legs(0.0, 0.0, w, d - 0.06, 0.14, 0.06, 0.0, frame, false)
	for i in 12:
		var z := 0.08 + i * (d - 0.2) / 11.0
		m.box(Vector3(0.04, 0.26, z), Vector3(w - 0.04, 0.28, z + 0.07), m.paint("pine", Color(0.84, 0.7, 0.5), F.GRAIN))
	# Headboard.
	var head_h := m.size.y
	if upholstered:
		m.rounded(Vector3(0.0, 0.12, d - 0.1), Vector3(w, head_h, d), 0.05, frame)
		for col in 6:
			for row in 3:
				var bx := 0.2 + col * (w - 0.4) / 5.0
				var by := 0.7 + row * 0.15
				m.cut(Vector3(bx, by, d - 0.1), Vector3(bx + 0.02, by + 0.02, d - 0.09))
	else:
		m.box(Vector3(0.0, 0.0, d - 0.06), Vector3(0.06, head_h, d), frame)
		m.box(Vector3(w - 0.06, 0.0, d - 0.06), Vector3(w, head_h, d), frame)
		m.box(Vector3(0.06, head_h - 0.1, d - 0.05), Vector3(w - 0.06, head_h - 0.02, d - 0.01), frame)
		m.box(Vector3(0.06, 0.38, d - 0.05), Vector3(w - 0.06, 0.46, d - 0.01), frame)
		var bars := 5 if mattress_w > 1.0 else 3
		for i in bars:
			var x := 0.06 + (w - 0.12) * (i + 1) / (bars + 1) - 0.02
			m.box(Vector3(x, 0.46, d - 0.045), Vector3(x + 0.04, head_h - 0.1, d - 0.015), frame)
	# Mattress, a turned-back duvet, and pillows against the headboard.
	m.rounded(Vector3(x0, 0.28, 0.06), Vector3(x0 + mattress_w, 0.5, d - 0.08), 0.04, mattress)
	m.rounded(Vector3(x0 - 0.02, 0.48, 0.04), Vector3(x0 + mattress_w + 0.02, 0.56, d - 0.55), 0.04, duvet)
	m.rounded(Vector3(x0 - 0.01, 0.5, d - 0.6), Vector3(x0 + mattress_w + 0.01, 0.58, d - 0.48), 0.04, sheet)
	var pillows := 2 if mattress_w > 1.0 else 1
	for i in pillows:
		var px := x0 + 0.05 + i * (mattress_w * 0.5)
		m.rounded(Vector3(px, 0.5, d - 0.44), Vector3(px + mattress_w / pillows - 0.1, 0.62, d - 0.12), 0.05, sheet)


func _bunk_bed(m: FurnitureModel) -> void:
	var pine := m.paint("pine", Color(0.82, 0.66, 0.44), F.GRAIN)
	var mattress := m.paint("foam", Color(0.94, 0.94, 0.92), F.FABRIC)
	var red := m.paint("fabric", Color(0.7, 0.2, 0.18), F.FABRIC)
	var navy := m.paint("fabric", Color(0.18, 0.24, 0.4), F.FABRIC)
	var w := 1.0
	var d := 2.05
	for x in [0.0, w - 0.06]:
		for z in [0.0, d - 0.06]:
			m.box(Vector3(x, 0.0, z), Vector3(x + 0.06, 1.65, z + 0.06), pine)
	for y in [0.2, 1.1]:
		m.box(Vector3(0.0, y, 0.0), Vector3(w, y + 0.12, 0.06), pine)
		m.box(Vector3(0.0, y, d - 0.06), Vector3(w, y + 0.12, d), pine)
		m.box(Vector3(0.0, y, 0.06), Vector3(0.04, y + 0.12, d - 0.06), pine)
		m.box(Vector3(w - 0.04, y, 0.06), Vector3(w, y + 0.12, d - 0.06), pine)
		m.rounded(Vector3(0.05, y + 0.06, 0.07), Vector3(w - 0.05, y + 0.22, d - 0.07), 0.03, mattress)
		m.rounded(Vector3(0.04, y + 0.2, 0.06), Vector3(w - 0.04, y + 0.27, d - 0.5), 0.03, red if y < 0.5 else navy)
	# Safety rail on the top bunk and a ladder at the foot end.
	m.box(Vector3(w - 0.04, 1.32, 0.5), Vector3(w, 1.4, d - 0.06), pine)
	for i in 4:
		var y := 0.42 + i * 0.22
		m.box(Vector3(0.12, y, -0.04), Vector3(0.5, y + 0.03, 0.0), pine)
	for x in [0.1, 0.5]:
		m.box(Vector3(x, 0.0, -0.05), Vector3(x + 0.04, 1.4, 0.0), pine)


# --- Bedside and drawers

func _bedside_cabinet(m: FurnitureModel) -> void:
	var white := m.paint("painted_wood", Color(0.94, 0.93, 0.9))
	var oak := m.paint("oak", Color(0.62, 0.45, 0.28), F.GRAIN)
	var knob := m.paint("ceramic", Color(0.95, 0.95, 0.93))
	P.carcass(m, Vector3(0.0, 0.08, 0.0), Vector3(0.45, 0.55, 0.4), 0.02, white)
	m.rounded(Vector3(-0.0, 0.55, -0.0), Vector3(0.45, 0.58, 0.4), 0.008, oak, "y")
	m.drawer(Vector3(0.02, 0.4, -0.02), Vector3(0.43, 0.53, 0.0), white, knob, "knob")
	m.door_front(Vector3(0.02, 0.1, -0.02), Vector3(0.43, 0.39, 0.0), white, knob, false)
	m.legs(0.0, 0.0, 0.45, 0.4, 0.08, 0.035, 0.02, oak, true, 0.7)


func _bedside_table(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.4, 0.26, 0.16), F.GRAIN)
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	m.cylinder(Vector3(0.21, 0.52, 0.19), "y", 0.03, 0.2, walnut)
	m.cylinder(Vector3(0.21, 0.25, 0.19), "y", 0.02, 0.17, walnut)
	for angle in [0.4, 2.5, 4.6]:
		var p := Vector2(0.21, 0.19) + Vector2(cos(angle), sin(angle)) * 0.13
		m.cylinder(Vector3(p.x, 0.0, p.y), "y", 0.52, 0.012, walnut, 0.018)
	m.cylinder(Vector3(0.21, 0.55, 0.19), "y", 0.012, 0.19, brass)
	m.cut_cylinder(Vector3(0.21, 0.55, 0.19), "y", 0.02, 0.18)


## Chest of drawers: rows (each row's count of drawers side by side), bottom up from the plinth.
func _chest(m: FurnitureModel, h: float, rows: Array) -> void:
	var w := m.size.x
	var oak := m.paint("oak", Color(0.6, 0.43, 0.26), F.GRAIN)
	var front := m.paint("oak", Color(0.66, 0.48, 0.3), F.GRAIN)
	var knob := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.1, 0.0), Vector3(w, h - 0.03, 0.46), 0.02, oak)
	m.rounded(Vector3(-0.01, h - 0.03, -0.01), Vector3(w + 0.01, h, 0.47), 0.01, oak, "y")
	m.box(Vector3(0.0, 0.0, 0.0), Vector3(w, 0.1, 0.03), oak)
	m.legs(0.0, 0.0, w, 0.46, 0.1, 0.05, 0.0, oak, false)
	var space := h - 0.15
	var row_h := space / rows.size()
	for r in rows.size():
		var y := 0.11 + r * row_h
		var count: int = rows[rows.size() - 1 - r]
		var each := (w - 0.04) / count
		for c in count:
			var x := 0.02 + c * each
			m.drawer(Vector3(x + 0.004, y + 0.004, -0.02), Vector3(x + each - 0.004, y + row_h - 0.004, 0.0), front, knob, "knob" if count > 1 else "bar")


func _wardrobe(m: FurnitureModel, doors: int) -> void:
	var w := m.size.x
	var h := m.size.y
	var d := m.size.z
	var body := m.paint("painted_wood", Color(0.9, 0.89, 0.85))
	var door := m.paint("painted_wood", Color(0.86, 0.85, 0.8))
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	var rail := m.paint("chrome", Color(0.8, 0.81, 0.83), F.BRUSHED)
	P.carcass(m, Vector3(0.0, 0.08, 0.0), Vector3(w, h - 0.06, d), 0.022, body)
	# Cornice and plinth mouldings.
	m.rounded(Vector3(-0.02, h - 0.06, -0.02), Vector3(w + 0.02, h, d + 0.01), 0.015, body)
	m.box(Vector3(0.0, 0.0, -0.01), Vector3(w, 0.08, d), body)
	m.cylinder(Vector3(0.03, h - 0.3, d * 0.5), "x", w - 0.06, 0.014, rail)
	# A few garments on hangers inside.
	var colors := [Color(0.2, 0.3, 0.45), Color(0.7, 0.68, 0.62), Color(0.5, 0.15, 0.15), Color(0.2, 0.2, 0.22)]
	for i in (5 if doors > 1 else 3):
		var x := 0.1 + i * (w - 0.2) / (4 if doors > 1 else 2)
		m.box(Vector3(x - 0.02, h - 1.05, 0.12), Vector3(x + 0.02, h - 0.33, d - 0.12), m.paint("fabric", colors[i % colors.size()], F.FABRIC))
	# Doors over the front, a drawer below.
	var each := (w - 0.01) / doors
	for i in doors:
		var x := 0.005 + i * each
		m.door_front(Vector3(x, 0.32, -0.022), Vector3(x + each - 0.005, h - 0.08, 0.0), door, brass, doors > 1 and i == 1)
	m.drawer(Vector3(0.01, 0.09, -0.022), Vector3(w - 0.01, 0.31, 0.0), door, brass, "bar")


# --- Dressing

func _dressing_table(m: FurnitureModel) -> void:
	var white := m.paint("painted_wood", Color(0.95, 0.94, 0.9))
	var mirror := m.paint("mirror", Color(0.85, 0.88, 0.9))
	var knob := m.paint("ceramic", Color(0.9, 0.88, 0.8))
	m.rounded(Vector3(0.0, 0.72, 0.0), Vector3(1.1, 0.75, 0.45), 0.01, white, "y")
	for x in [0.0, 0.75]:
		P.carcass(m, Vector3(x, 0.05, 0.02), Vector3(x + 0.35, 0.72, 0.45), 0.018, white)
		for i in 3:
			var y := 0.06 + i * 0.22
			m.drawer(Vector3(x + 0.01, y, 0.0), Vector3(x + 0.34, y + 0.21, 0.02), white, knob, "knob")
	m.drawer(Vector3(0.36, 0.6, 0.02), Vector3(0.74, 0.71, 0.04), white, knob, "knob")
	# Arched mirror on a stand at the back.
	var frame := PackedVector2Array([Vector2(0.25, 0.75), Vector2(0.85, 0.75), Vector2(0.85, 1.25), Vector2(0.75, 1.38), Vector2(0.55, 1.45), Vector2(0.35, 1.38), Vector2(0.25, 1.25)])
	m.prism_xy(frame, 0.38, 0.42, white)
	var glass := PackedVector2Array([Vector2(0.29, 0.79), Vector2(0.81, 0.79), Vector2(0.81, 1.23), Vector2(0.72, 1.34), Vector2(0.55, 1.4), Vector2(0.38, 1.34), Vector2(0.29, 1.23)])
	m.prism_xy(glass, 0.37, 0.38, mirror)
	for i in 3:
		m.cylinder(Vector3(0.35 + i * 0.07, 0.75, 0.2), "y", 0.06 + i * 0.02, 0.018, m.paint("glass", [Color(0.8, 0.5, 0.6), Color(0.6, 0.75, 0.85), Color(0.9, 0.8, 0.5)][i]))


func _dressing_stool(m: FurnitureModel) -> void:
	var white := m.paint("painted_wood", Color(0.95, 0.94, 0.9))
	var seat := m.paint("fabric", PINK, F.FABRIC)
	for corner in [Vector2(0.04, 0.04), Vector2(0.37, 0.04), Vector2(0.04, 0.27), Vector2(0.37, 0.27)]:
		m.cylinder(Vector3(corner.x + 0.02, 0.0, corner.y + 0.02), "y", 0.36, 0.014, white, 0.02)
	m.box(Vector3(0.04, 0.3, 0.04), Vector3(0.41, 0.36, 0.31), white)
	m.rounded(Vector3(0.0, 0.36, 0.0), Vector3(0.45, 0.46, 0.35), 0.04, seat)


func _cheval_mirror(m: FurnitureModel) -> void:
	var walnut := m.paint("walnut", Color(0.38, 0.25, 0.15), F.GRAIN)
	var mirror := m.paint("mirror", Color(0.85, 0.88, 0.9))
	var brass := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	# Two uprights on splayed feet, the framed glass between, tilted back slightly.
	for x in [0.0, 0.46]:
		m.box(Vector3(x, 0.0, 0.02), Vector3(x + 0.04, 0.04, 0.4), walnut)
		m.box(Vector3(x, 0.04, 0.19), Vector3(x + 0.04, 1.5, 0.23), walnut)
		m.ellipsoid(Vector3(x + 0.02, 1.52, 0.21), Vector3(0.025, 0.03, 0.025), walnut)
		m.cylinder(Vector3(x, 0.9, 0.21), "x", 0.04, 0.012, brass)
	for i in 28:
		var t := i / 27.0
		var y := lerpf(0.12, 1.5, t)
		var z := 0.2 + (t - 0.5) * 0.08
		var edge := i == 0 or i == 27
		m.box(Vector3(0.05, y, z - 0.012), Vector3(0.45, y + 0.052, z + 0.012), walnut if edge else mirror)
		m.box(Vector3(0.04, y, z - 0.015), Vector3(0.06, y + 0.052, z + 0.015), walnut)
		m.box(Vector3(0.44, y, z - 0.015), Vector3(0.46, y + 0.052, z + 0.015), walnut)


# --- Desk and seating

func _desk(m: FurnitureModel) -> void:
	var white := m.paint("painted_wood", Color(0.94, 0.93, 0.9))
	var oak := m.paint("oak", Color(0.64, 0.46, 0.28), F.GRAIN)
	var knob := m.paint("brass", Color(0.78, 0.62, 0.3), F.BRUSHED)
	m.rounded(Vector3(0.0, 0.73, 0.0), Vector3(1.1, 0.76, 0.5), 0.01, oak, "y")
	m.legs(0.0, 0.0, 1.1, 0.5, 0.73, 0.045, 0.02, white, true, 0.75)
	m.box(Vector3(0.05, 0.6, 0.04), Vector3(1.05, 0.73, 0.48), white)
	m.drawer(Vector3(0.08, 0.61, 0.02), Vector3(0.52, 0.72, 0.04), white, knob, "knob")
	m.drawer(Vector3(0.58, 0.61, 0.02), Vector3(1.02, 0.72, 0.04), white, knob, "knob")


func _desk_chair(m: FurnitureModel) -> void:
	var frame := m.paint("painted_wood", Color(0.94, 0.93, 0.9))
	var seat := m.paint("fabric", DOVE, F.FABRIC)
	P.chair(m, 0.44, 0.48, 0.46, 0.88, frame, seat, 0, true)
	m.rounded(Vector3(0.06, 0.58, 0.44), Vector3(0.38, 0.8, 0.475), 0.02, seat)


func _blanket_chest(m: FurnitureModel) -> void:
	var pine := m.paint("pine", Color(0.76, 0.58, 0.36), F.GRAIN)
	var iron := m.paint("cast_iron", Color(0.12, 0.12, 0.13))
	P.carcass(m, Vector3(0.0, 0.06, 0.0), Vector3(0.9, 0.46, 0.45), 0.025, pine)
	m.box(Vector3(0.0, 0.06, -0.0), Vector3(0.9, 0.46, 0.025), pine)
	m.rounded(Vector3(-0.015, 0.46, -0.015), Vector3(0.915, 0.5, 0.465), 0.012, pine, "y")
	for x in [0.0, 0.84]:
		m.box(Vector3(x, 0.0, 0.0), Vector3(x + 0.06, 0.06, 0.45), pine)
	# Strap hinges at the back, hasp and handles.
	m.box(Vector3(0.42, 0.38, -0.008), Vector3(0.48, 0.48, 0.0), iron)
	for x in [-0.01, 0.9]:
		m.box(Vector3(x, 0.28, 0.18), Vector3(x + 0.01, 0.32, 0.27), iron)
	for x in [0.15, 0.65]:
		m.box(Vector3(x, 0.47, 0.42), Vector3(x + 0.1, 0.5, 0.47), iron)


func _storage_bench(m: FurnitureModel) -> void:
	var white := m.paint("painted_wood", Color(0.9, 0.89, 0.85))
	var cushion := m.paint("fabric", Color(0.42, 0.5, 0.6), F.FABRIC)
	var basket := m.paint("wicker", Color(0.74, 0.58, 0.36), F.FABRIC)
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.4, 0.4), 0.02, white)
	m.box(Vector3(0.48, 0.02, 0.0), Vector3(0.52, 0.38, 0.38), white)
	for x in [0.04, 0.54]:
		m.begin_part("slide", "Basket", Vector3(x + 0.21, 0.15, 0.02), Vector3.FORWARD, 0.28)
		m.rounded(Vector3(x, 0.03, 0.02), Vector3(x + 0.42, 0.33, 0.37), 0.02, basket)
		m.cut(Vector3(x + 0.03, 0.06, 0.05), Vector3(x + 0.39, 0.34, 0.34))
		m.end_part()
	m.rounded(Vector3(0.0, 0.4, 0.0), Vector3(1.0, 0.48, 0.4), 0.03, cushion)


func _bookshelf(m: FurnitureModel) -> void:
	var oak := m.paint("oak", Color(0.62, 0.45, 0.28), F.GRAIN)
	var rng := RandomNumberGenerator.new()
	rng.seed = 51
	P.carcass(m, Vector3(0.0, 0.0, 0.0), Vector3(0.6, 1.4, 0.28), 0.02, oak)
	for i in 4:
		var y := 0.02 + i * 0.34
		m.box(Vector3(0.02, y, 0.0), Vector3(0.58, y + 0.02, 0.27), oak)
		P.books(m, 0.03, 0.57, y + 0.02, 0.28, 0.02, 0.26, rng)


func _clothes_rail(m: FurnitureModel) -> void:
	var chrome := m.paint("chrome", Color(0.82, 0.83, 0.85), F.BRUSHED)
	var rubber := m.paint("rubber", Color(0.1, 0.1, 0.1))
	for x in [0.03, 1.17]:
		m.cylinder(Vector3(x, 0.05, 0.25), "y", 1.55, 0.014, chrome)
		m.cylinder(Vector3(x, 0.05, 0.03), "z", 0.44, 0.012, chrome)
		m.cylinder(Vector3(x, 0.025, 0.04), "y", 0.04, 0.025, rubber)
		m.cylinder(Vector3(x, 0.025, 0.46), "y", 0.04, 0.025, rubber)
	m.cylinder(Vector3(0.03, 1.58, 0.25), "x", 1.14, 0.014, chrome)
	m.cylinder(Vector3(0.03, 0.12, 0.25), "x", 1.14, 0.012, chrome)
	var colors := [Color(0.15, 0.2, 0.35), Color(0.8, 0.76, 0.68), Color(0.6, 0.2, 0.2), Color(0.25, 0.4, 0.3), Color(0.9, 0.9, 0.88), Color(0.3, 0.3, 0.32)]
	for i in 8:
		var x := 0.12 + i * 0.13
		m.box(Vector3(x - 0.03, 0.85, 0.07), Vector3(x + 0.03, 1.5, 0.43), m.paint("fabric", colors[i % colors.size()], F.FABRIC))
		m.box(Vector3(x - 0.004, 1.5, 0.12), Vector3(x + 0.004, 1.56, 0.38), chrome)


func _laundry_basket(m: FurnitureModel) -> void:
	var wicker := m.paint("wicker", Color(0.7, 0.55, 0.34), F.FABRIC)
	var lid := m.paint("wicker", Color(0.6, 0.46, 0.28), F.FABRIC)
	m.rounded(Vector3(0.0, 0.0, 0.0), Vector3(0.42, 0.5, 0.32), 0.05, wicker)
	m.cut(Vector3(0.03, 0.03, 0.03), Vector3(0.39, 0.5, 0.29))
	m.begin_part("hinge", "Lid", Vector3(0.21, 0.5, 0.33), Vector3.RIGHT, 100.0)
	m.rounded(Vector3(-0.01, 0.5, -0.01), Vector3(0.43, 0.55, 0.33), 0.04, lid)
	m.end_part()
	for y in [0.1, 0.22, 0.34]:
		m.repaint(Vector3(0.0, y, 0.0), Vector3(0.42, y + 0.02, 0.32), lid)
