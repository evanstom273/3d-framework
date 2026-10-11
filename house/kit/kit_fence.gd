@tool
class_name KitFence
extends KitPiece
## A garden fence running along +X from the origin, with posts at regular bays
## and optional gates. The outside (the side gates open away from) is -Z.
##
## Gates are KitOpenings of kind DOOR with a GATE_* (or SHED_DOUBLE) style; their
## `position` and `width` work as in a KitWall. Posts are added either side of
## each gate, and the fence stops short of them.

enum Style { CLOSE_BOARD, PICKET, LAP_PANEL, POST_AND_RAIL, CHAIN_LINK, RAILINGS }

@export var style: Style = Style.CLOSE_BOARD:
	set(value):
		style = value
		queue_rebuild()
@export_range(0.5, 30.0, 0.05, "or_greater", "suffix:m") var length: float = 6.0:
	set(value):
		length = value
		queue_rebuild()
@export_range(0.4, 2.5, 0.05, "suffix:m") var height: float = 1.8:
	set(value):
		height = value
		queue_rebuild()
## Spacing between posts.
@export_range(0.6, 3.0, 0.05, "suffix:m") var bay_width: float = 1.8:
	set(value):
		bay_width = value
		queue_rebuild()
@export var color: Color = Color(0.47, 0.35, 0.23):
	set(value):
		color = value
		queue_rebuild()
@export var gates: Array[KitOpening] = []:
	set(value):
		for gate in gates:
			if gate != null and gate.changed.is_connected(queue_rebuild):
				gate.changed.disconnect(queue_rebuild)
		gates = value
		for gate in gates:
			if gate != null and not gate.changed.is_connected(queue_rebuild):
				gate.changed.connect(queue_rebuild)
		queue_rebuild()

const POST := 0.1

var _fixtures: Array[Node3D] = []
var _gate_edges: Array[float] = []


func _build(b: KitBuilder) -> void:
	_fixtures.clear()
	_gate_edges.clear()
	var post_material := KitMaterials.timber(color.darkened(0.15))
	var spans: Array[Vector2] = [Vector2(0.0, length)]
	for gate in gates:
		if gate == null or gate.kind != KitOpening.Kind.DOOR:
			continue
		var x0 := clampf(gate.position - gate.width * 0.5, POST, length - POST)
		var x1 := clampf(gate.position + gate.width * 0.5, POST, length - POST)
		if x1 - x0 < 0.3:
			continue
		spans = _cut(spans, x0 - POST, x1 + POST)
		_gate_edges.append_array([x0 - POST, x1 + POST])
		var top := minf(gate.height, height)
		var title := gate.display_name if not gate.display_name.is_empty() else "Gate"
		var o := gate
		if not gate.is_gate() and gate.door_style != KitOpening.DoorStyle.SHED_DOUBLE:
			o = gate.duplicate() as KitOpening
			o.door_style = KitOpening.DoorStyle.GATE_TIMBER
			o.display_name = title
		_fixtures.append_array(KitDoors.build(b, o, x0, x1, 0.0, top, -0.03, 0.03, 0.05, true))
	for span in spans:
		if span.y - span.x < 0.05:
			continue
		_span(b, span.x, span.y, post_material)


## One run of fence between two gates (or the ends), posts included.
func _span(b: KitBuilder, x0: float, x1: float, post_material: Material) -> void:
	var count := maxi(1, ceili((x1 - x0) / bay_width))
	var step := (x1 - x0) / count
	var metal := style in [Style.CHAIN_LINK, Style.RAILINGS]
	var iron := KitMaterials.metal(Color(0.08, 0.08, 0.09), 0.5)
	var galvanised := KitMaterials.metal(Color(0.62, 0.64, 0.66), 0.7)
	var start_gate := _at_gate(x0)
	var end_gate := _at_gate(x1)
	for i in count + 1:
		# The gate's own post stands at an end beside a gate.
		if (i == 0 and start_gate) or (i == count and end_gate):
			continue
		var x := clampf(x0 + step * i, x0 + POST * 0.5, x1 - POST * 0.5)
		if metal:
			var r := 0.03 if style == Style.CHAIN_LINK else 0.025
			b.box(Vector3(x - r, -0.05, -r), Vector3(x + r, height + 0.05, r), galvanised if style == Style.CHAIN_LINK else iron)
		else:
			b.bevel_box(Vector3(x - POST * 0.5, -0.05, -POST * 0.5), Vector3(x + POST * 0.5, height + 0.08, POST * 0.5), 0.01, post_material)
			# A weathered cap on top.
			b.box(Vector3(x - POST * 0.6, height + 0.08, -POST * 0.6), Vector3(x + POST * 0.6, height + 0.11, POST * 0.6), post_material)
	var timber := KitMaterials.timber(color)
	var a := x0 if start_gate else x0 + (0.03 if metal else POST * 0.5)
	var c := x1 if end_gate else x1 - (0.03 if metal else POST * 0.5)
	match style:
		Style.CLOSE_BOARD:
			# Gravel board, two arris rails behind, overlapping vertical feather-edge boards in front.
			b.box(Vector3(a, 0.0, -0.05), Vector3(c, 0.15, -0.03), timber)
			for y in [0.35, height - 0.3]:
				b.box(Vector3(a, y, -0.01), Vector3(c, y + 0.08, 0.04), timber, false)
			var n := maxi(1, floori((c - a) / 0.09))
			var w := (c - a) / n
			for i in n:
				var bx := a + w * i
				var z := -0.03 - (0.008 if i % 2 == 0 else 0.0)
				b.box(Vector3(bx, 0.15, z - 0.018), Vector3(bx + w + 0.012, height, z), timber, false)
			b.collision_quad(Vector3(a, 0.0, -0.04), Vector3(c, 0.0, -0.04), Vector3(c, height, -0.04), Vector3(a, height, -0.04))
		Style.LAP_PANEL:
			# Horizontal overlapping boards in a framed panel.
			b.box(Vector3(a, 0.0, -0.035), Vector3(c, 0.06, 0.035), timber)
			b.box(Vector3(a, height - 0.06, -0.035), Vector3(c, height, 0.035), timber)
			var rows := maxi(1, floori((height - 0.12) / 0.15))
			var h := (height - 0.12) / rows
			for i in rows:
				var y := 0.06 + h * i
				b.box(Vector3(a, y, -0.012), Vector3(c, y + h + 0.015, 0.008), timber, false)
			b.collision_quad(Vector3(a, 0.0, 0.0), Vector3(c, 0.0, 0.0), Vector3(c, height, 0.0), Vector3(a, height, 0.0))
		Style.PICKET:
			var paint := KitMaterials.gloss(color)
			for y in [0.2, height - 0.25]:
				b.box(Vector3(a, y, 0.0), Vector3(c, y + 0.07, 0.025), paint)
			var n := maxi(1, floori((c - a) / 0.12))
			var w := (c - a) / n
			for i in n:
				var px := a + w * (i + 0.5)
				var picket := PackedVector2Array([Vector2(px - 0.035, 0.05), Vector2(px + 0.035, 0.05), Vector2(px + 0.035, height - 0.06), Vector2(px, height), Vector2(px - 0.035, height - 0.06)])
				b.slab(picket, Vector3(0, 0, 0.0), Vector3.RIGHT, Vector3.UP, 0.02, paint, paint)
		Style.POST_AND_RAIL:
			for y in [0.3, height * 0.6, height - 0.12]:
				b.box(Vector3(a, y, -0.06), Vector3(c, y + 0.1, -0.03), timber)
		Style.CHAIN_LINK:
			# Top and bottom tension wires and a mesh panel (see-through, but solid).
			b.box(Vector3(a, height - 0.03, -0.02), Vector3(c, height, 0.02), galvanised)
			b.box(Vector3(a, 0.05, -0.005), Vector3(c, 0.06, 0.005), galvanised, false)
			_chain_mesh(b, a, c, 0.06, height - 0.03, galvanised)
			b.collision_quad(Vector3(a, 0.0, 0.0), Vector3(c, 0.0, 0.0), Vector3(c, height, 0.0), Vector3(a, height, 0.0))
		Style.RAILINGS:
			for y in [0.1, height - 0.12]:
				b.box(Vector3(a, y, -0.012), Vector3(c, y + 0.025, 0.012), iron)
			var n := maxi(1, floori((c - a) / 0.12))
			var w := (c - a) / n
			for i in n:
				var px := a + w * (i + 0.5)
				b.box(Vector3(px - 0.008, 0.0, -0.008), Vector3(px + 0.008, height - 0.05, 0.008), iron, false)
				# A spear finial on each bar.
				b.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.018, 0.0), Vector2(0.012, 0.04), Vector2(0.0, 0.09)]), Vector3(px, height - 0.05, 0.0), 6, iron)
			b.collision_quad(Vector3(a, 0.0, 0.0), Vector3(c, 0.0, 0.0), Vector3(c, height, 0.0), Vector3(a, height, 0.0))


## Diagonal wires either way, without collision (the panel quad handles that).
static func _chain_mesh(b: KitBuilder, x0: float, x1: float, y0: float, y1: float, material: Material) -> void:
	var pitch := 0.12
	var t := 0.0035
	var h := y1 - y0
	var start := x0 - h
	var x := start
	while x < x1:
		for direction in [1.0, -1.0]:
			var p := Vector2(x, y0) if direction > 0.0 else Vector2(x + h, y0)
			var q := Vector2(x + h, y1) if direction > 0.0 else Vector2(x, y1)
			var clipped := _clip(p, q, x0, x1)
			if clipped.is_empty():
				continue
			var a: Vector2 = clipped[0]
			var c: Vector2 = clipped[1]
			var side := (c - a).normalized().orthogonal() * t
			b.quad(Vector3(a.x - side.x, a.y - side.y, 0), Vector3(c.x - side.x, c.y - side.y, 0), Vector3(c.x + side.x, c.y + side.y, 0), Vector3(a.x + side.x, a.y + side.y, 0), material, false)
			b.quad(Vector3(a.x + side.x, a.y + side.y, 0), Vector3(c.x + side.x, c.y + side.y, 0), Vector3(c.x - side.x, c.y - side.y, 0), Vector3(a.x - side.x, a.y - side.y, 0), material, false)
		x += pitch


## Clips a segment to x0..x1; empty if it lies outside.
static func _clip(p: Vector2, q: Vector2, x0: float, x1: float) -> Array:
	var lo := p if p.x < q.x else q
	var hi := q if p.x < q.x else p
	if hi.x <= x0 or lo.x >= x1:
		return []
	var d := hi - lo
	var a := lo + d * maxf(0.0, (x0 - lo.x) / d.x)
	var c := lo + d * minf(1.0, (x1 - lo.x) / d.x)
	return [a, c]


static func _cut(spans: Array[Vector2], from: float, to: float) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for span in spans:
		if to <= span.x or from >= span.y:
			result.append(span)
			continue
		if from > span.x:
			result.append(Vector2(span.x, from))
		if to < span.y:
			result.append(Vector2(to, span.y))
	return result


func _build_fixtures() -> void:
	for node in _fixtures:
		add_generated(node)


func _at_gate(x: float) -> bool:
	for edge in _gate_edges:
		if absf(edge - x) < 0.001:
			return true
	return false
