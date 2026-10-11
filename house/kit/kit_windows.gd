@tool
class_name KitWindows
extends RefCounted
## Builds windows from a KitOpening: the static frame (outer frame, mullions,
## transoms, sill board) into a KitBuilder, and one KitMechanism per panel
## (sashes and glass as breakable voxel bodies) as nodes.
##
## Coordinates passed in are "frame space" mapped to wall space by `place`:
## x across the opening from its left edge, y up from its bottom, and z through
## the frame from its outside face (z = 0) inward (+z). Bay windows reuse the
## same builder once per facet, each with its own `place`.

const CELL := KitJoinery.CELL
const DEPTH := 0.07
const SASH_DEEP := 2

static var _glass_cache: Dictionary = {}


## What a panel does, from a layout token.
class PanelSpec:
	var token: String = "F"
	var rect: Rect2
	## For shaped lights: the clear outline in frame space (empty for rectangles).
	var outline: PackedVector2Array = PackedVector2Array()


## A built window: the panels, the clear opening of each (frame space, for
## climbing) and the mechanism nodes (null for fixed lights), index for index.
class Result:
	var lights: Array[Rect2] = []
	var mechanisms: Array[Node3D] = []
	var nodes: Array[Node3D] = []


## Default panel tokens for a style when the opening gives no layout.
static func default_layout(o: KitOpening, width: float) -> PackedStringArray:
	if not o.panel_layout.strip_edges().is_empty():
		return _tokens(o.panel_layout)
	match o.window_style:
		KitOpening.WindowStyle.PICTURE, KitOpening.WindowStyle.FIXED:
			return PackedStringArray(["F"])
		KitOpening.WindowStyle.TOP_HUNG_AWNING:
			return _repeat("T", maxi(1, o.panes))
		KitOpening.WindowStyle.BOTTOM_HUNG_HOPPER:
			return _repeat("B", maxi(1, o.panes))
		KitOpening.WindowStyle.SLIDING_SASH:
			return _repeat("U", maxi(1, o.panes))
		KitOpening.WindowStyle.HORIZONTAL_SLIDER:
			return PackedStringArray(["S", "F"])
		KitOpening.WindowStyle.TILT_AND_TURN:
			return PackedStringArray(["TT"]) if o.panes <= 1 else PackedStringArray(["TT", "TTR"])
		KitOpening.WindowStyle.FULL_HEIGHT:
			return PackedStringArray(["L", "R"]) if width > 1.4 else PackedStringArray(["L"])
		KitOpening.WindowStyle.GLAZED_WALL:
			var count := maxi(2, roundi(width / 1.1))
			var tokens := PackedStringArray()
			for i in count:
				tokens.append("L" if i == count - 1 else "F")
			return tokens
	# CASEMENT and friends: outer panels open, middle ones fixed.
	var count := clampi(o.panes, 1, 4)
	if count == 1:
		return PackedStringArray(["L" if o.hinge_left else "R"])
	var tokens := PackedStringArray()
	for i in count:
		tokens.append("L" if i == 0 else ("R" if i == count - 1 else "F"))
	return tokens


static func _tokens(text: String) -> PackedStringArray:
	var tokens := PackedStringArray()
	for token in text.split(",", false):
		tokens.append(token.strip_edges().to_upper())
	return tokens


static func _repeat(token: String, count: int) -> PackedStringArray:
	var tokens := PackedStringArray()
	for i in count:
		tokens.append(token)
	return tokens


## Builds a window of `width` x `height` (frame space) whose outline comes from
## the opening's shape. `place` maps frame space to the wall/builder space.
static func build(b: KitBuilder, o: KitOpening, width: float, height: float, place: Transform3D, title: String) -> Result:
	var result := Result.new()
	var saved := b.transform
	b.transform = saved * place
	var f := o.frame_width
	var frame := KitMaterials.gloss(o.frame_color)
	var shape := KitShapes.outline(o, width, height)
	# Shift the outline from centred to the frame's left edge.
	for i in shape.size():
		shape[i] += Vector2(width * 0.5, 0.0)
	var inner := KitShapes.inset(shape, f)
	# Outer frame ring.
	for piece in KitShapes.ring(shape, inner):
		b.slab(piece, Vector3(0, 0, DEPTH), Vector3.RIGHT, Vector3.UP, DEPTH, frame, frame)
	var panels: Array[PanelSpec] = []
	if KitShapes.supports_panels(o):
		panels = _rect_panels(b, o, width, height, f, frame)
		# The curved or pointed top above the spring line is a fixed top light.
		var spring := KitShapes.spring_height(o, width, height)
		if spring < height - 0.01:
			b.box(Vector3(f, spring - f * 0.5, 0.0), Vector3(width - f, spring + f * 0.5, DEPTH), frame)
			var top := PanelSpec.new()
			top.token = _tokens(o.top_light_layout)[0] if not o.top_light_layout.is_empty() else "F"
			if not top.token in ["F", "T"]:
				top.token = "F"
			var clip := Geometry2D.intersect_polygons(inner, KitShapes.rect(0.0, spring + f * 0.5, width, height + 1.0))
			if not clip.is_empty():
				top.outline = clip[0]
				top.rect = KitShapes.bounds(top.outline)
				panels.append(top)
	else:
		# Round, oval, triangular, trapezoid and polygon windows are one light.
		var light := PanelSpec.new()
		var tokens := default_layout(o, width)
		light.token = tokens[0] if tokens[0] in ["F", "L", "R", "T", "B"] else "F"
		light.outline = inner
		light.rect = KitShapes.bounds(inner)
		panels.append(light)
	for i in panels.size():
		var panel := panels[i]
		var node := _panel(o, panel, title, i)
		result.lights.append(panel.rect)
		result.mechanisms.append(node if node is KitMechanism else null)
		if node != null:
			node.transform = place
			result.nodes.append(node)
	b.transform = saved
	return result


## Mullions, transom and the panel rectangles of a rectangular window body.
static func _rect_panels(b: KitBuilder, o: KitOpening, width: float, height: float, f: float, frame: Material) -> Array[PanelSpec]:
	var spring := KitShapes.spring_height(o, width, height)
	var body_top := spring - (f * 0.5 if spring < height - 0.01 else f)
	var bottom := f + 0.01
	var panels: Array[PanelSpec] = []
	# Transom: a row of top lights across the rectangular part.
	var transom := -1.0
	if o.transom_height > 0.0 and body_top - bottom > o.transom_height + 0.3:
		transom = body_top - o.transom_height
		b.box(Vector3(f, transom, 0.0), Vector3(width - f, transom + f, DEPTH), frame)
	var main_top := transom if transom > 0.0 else body_top
	var tokens := default_layout(o, width)
	var rects := _divide(width, f, tokens.size(), o.panel_widths)
	for i in tokens.size():
		var r: Vector2 = rects[i]
		if i > 0:
			b.box(Vector3(r.x - f, bottom, 0.0), Vector3(r.x, main_top, DEPTH), frame)
		var panel := PanelSpec.new()
		panel.token = tokens[i]
		panel.rect = Rect2(r.x, bottom, r.y - r.x, main_top - bottom)
		panels.append(panel)
	if transom > 0.0:
		var top_tokens := _tokens(o.top_light_layout)
		if top_tokens.is_empty():
			top_tokens = PackedStringArray(["F"])
		var top_rects := _divide(width, f, top_tokens.size(), PackedFloat32Array())
		for i in top_tokens.size():
			var r: Vector2 = top_rects[i]
			if i > 0:
				b.box(Vector3(r.x - f, transom + f, 0.0), Vector3(r.x, body_top, DEPTH), frame)
			var top := PanelSpec.new()
			top.token = top_tokens[i] if top_tokens[i] in ["F", "T", "B"] else "F"
			top.rect = Rect2(r.x, transom + f, r.y - r.x, body_top - transom - f)
			panels.append(top)
	# Weathered bottom rail with a drip.
	b.box(Vector3(f, 0.0, 0.0), Vector3(width - f, bottom, DEPTH), frame)
	b.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.025, 0), Vector2(0, 0.012)]), Vector3(f, bottom, 0.0), Vector3(width - f, bottom, 0.0), Vector3.UP, frame, false)
	return panels


## Splits the width between the frame's jambs into panels separated by mullions.
## Returns [x0, x1] per panel (frame space).
static func _divide(width: float, f: float, count: int, weights: PackedFloat32Array) -> Array:
	var inner := width - f * 2.0 - f * (count - 1)
	var total := 0.0
	var w: Array[float] = []
	for i in count:
		var weight := weights[i] if i < weights.size() and weights[i] > 0.0 else 1.0
		w.append(weight)
		total += weight
	var spans := []
	var x := f
	for i in count:
		var span := inner * w[i] / total
		spans.append(Vector2(x, x + span))
		x += span + f
	return spans


# --- Panels

## Builds one panel's moving or fixed parts. Returns the mechanism (or a plain
## node for fixed glass); positioned in frame space.
static func _panel(o: KitOpening, panel: PanelSpec, title: String, index: int) -> Node3D:
	var r := panel.rect
	var nx := maxi(2, floori((r.size.x - 0.004) / CELL))
	var ny := maxi(2, floori((r.size.y - 0.004) / CELL))
	var origin := Vector3(r.position.x + (r.size.x - nx * CELL) * 0.5, r.position.y + (r.size.y - ny * CELL) * 0.5, 0.005)
	var token := panel.token
	var fixed := token == "F"
	var name := "%s %d" % [title, index + 1]
	var root: Node3D
	if fixed:
		root = Node3D.new()
	else:
		var mechanism := KitMechanism.new()
		mechanism.interaction_name = name
		mechanism.lockable = o.lockable
		mechanism.duration = 0.5
		root = mechanism
	root.name = "Light%d" % index
	# Sash: a frame of voxels round the glass (or just glass for fixed lights).
	var rail := 0 if fixed else 2
	var sash_boxes: Array[VoxelFillBox] = []
	var glass_cells: Array[Vector2i] = []
	if panel.outline.is_empty():
		if rail > 0:
			KitJoinery._vbox(sash_boxes, Vector3i(0, 0, 0), Vector3i(rail, ny, SASH_DEEP), o.frame_color)
			KitJoinery._vbox(sash_boxes, Vector3i(nx - rail, 0, 0), Vector3i(rail, ny, SASH_DEEP), o.frame_color)
			KitJoinery._vbox(sash_boxes, Vector3i(rail, 0, 0), Vector3i(nx - rail * 2, rail + 1, SASH_DEEP), o.frame_color)
			KitJoinery._vbox(sash_boxes, Vector3i(rail, ny - rail, 0), Vector3i(nx - rail * 2, rail, SASH_DEEP), o.frame_color)
		for y in range(rail + (1 if rail > 0 else 0), ny - rail):
			for x in range(rail, nx - rail):
				glass_cells.append(Vector2i(x, y))
	else:
		# Shaped light: sash band and glass from the outline, relative to the cell grid.
		var local := PackedVector2Array()
		for p in panel.outline:
			local.append(p - Vector2(origin.x, origin.y))
		var glass_outline := KitShapes.inset(local, rail * CELL) if rail > 0 else local
		for c in KitShapes.cells_inside(local, Vector2.ZERO, CELL, nx + 2, ny + 2):
			if rail > 0 and not Geometry2D.is_point_in_polygon((Vector2(c) + Vector2.ONE * 0.5) * CELL, glass_outline):
				KitJoinery._vbox(sash_boxes, Vector3i(c.x, c.y, 0), Vector3i(1, 1, SASH_DEEP), o.frame_color)
			else:
				glass_cells.append(c)
	# Georgian glazing bars across the glass.
	var bars := o.glazing_bars
	if o.window_style == KitOpening.WindowStyle.GEORGIAN_BARS and bars == Vector2i.ZERO:
		bars = Vector2i(maxi(1, roundi(r.size.x / 0.24)), maxi(1, roundi(r.size.y / 0.3)))
	if bars.x > 1 or bars.y > 1:
		var area := Rect2i(rail, rail, nx - rail * 2, ny - rail * 2)
		KitJoinery._glazing_bars(sash_boxes, area, maxi(1, bars.x), maxi(1, bars.y), o.frame_color, SASH_DEEP)
	var leaf: VoxelBody = null
	if not sash_boxes.is_empty():
		leaf = KitJoinery._voxel_leaf(root, "Leaf", sash_boxes, origin, Vector3.INF)
	var glass := _glass_body(root, glass_cells, origin + Vector3(0, 0, CELL * 0.5), glass_material(o))
	# Mechanism: movers and poses for the panel's opening type.
	if root is KitMechanism:
		var mover := _mover(root as KitMechanism, o, token, r, nx * CELL, ny * CELL, origin)
		var hinge_strip := AABB(Vector3.ZERO, Vector3(rail * CELL, ny * CELL, SASH_DEEP * CELL))
		match token:
			"R", "TTR":
				hinge_strip.position.x = (nx - rail) * CELL
			"T":
				hinge_strip = AABB(Vector3(0, (ny - rail) * CELL, 0), Vector3(nx * CELL, rail * CELL, SASH_DEEP * CELL))
			"B", "U", "S":
				hinge_strip = AABB(Vector3.ZERO, Vector3(nx * CELL, rail * CELL + CELL, SASH_DEEP * CELL))
		if leaf != null:
			_attach(root, "Attachment", "../Leaf", hinge_strip, "", AABB(), mover)
		if glass != null:
			var support := AABB(Vector3(-CELL, -CELL, 0), Vector3((nx + 2) * CELL, (ny + 2) * CELL, SASH_DEEP * CELL))
			_attach(root, "PaneAttachment", "../" + glass.name, AABB(), "../Leaf" if leaf != null else "", support, mover)
		if leaf != null:
			_handle(leaf, token, nx, ny)
	else:
		# Fixed light: glazing bars (if any) and glass are held all round.
		if leaf != null:
			_attach(root, "Attachment", "../Leaf", AABB(Vector3.ZERO, Vector3(nx * CELL, ny * CELL, SASH_DEEP * CELL)), "", AABB(), null)
		if glass != null:
			_attach(root, "PaneAttachment" if leaf != null else "Attachment", "../" + glass.name, AABB(Vector3.ZERO, Vector3(nx * CELL, ny * CELL, CELL)), "", AABB(), null)
	return root


## The mover node and its poses for one panel type.
static func _mover(m: KitMechanism, o: KitOpening, token: String, r: Rect2, w: float, h: float, origin: Vector3) -> Node3D:
	var mover := Node3D.new()
	mover.name = "Mover"
	var angle := o.max_open_angle
	var poses: Dictionary = {}
	var group := m.add_group("", {"open": "Open"})
	match token:
		"L", "R":
			# Side-hung, opening out.
			var pivot := Vector3(origin.x if token == "L" else origin.x + w, 0.0, origin.z)
			mover.position = pivot
			poses["open"] = [Transform3D(Basis.IDENTITY, pivot), KitMechanism.turned(Vector3.UP, (1.0 if token == "L" else -1.0) * (angle if angle > 0.0 else 80.0), pivot)]
		"T":
			# Top-hung awning: the bottom swings out.
			var pivot := Vector3(0.0, origin.y + h, origin.z)
			mover.position = pivot
			poses["open"] = [Transform3D(Basis.IDENTITY, pivot), KitMechanism.turned(Vector3.RIGHT, angle if angle > 0.0 else 32.0, pivot)]
		"B":
			# Bottom-hung hopper: the top tips in.
			var pivot := Vector3(0.0, origin.y, origin.z + SASH_DEEP * CELL)
			mover.position = pivot
			poses["open"] = [Transform3D(Basis.IDENTITY, pivot), KitMechanism.turned(Vector3.RIGHT, angle if angle > 0.0 else 18.0, pivot)]
		"S":
			# Slides sideways behind its neighbour.
			var step := Vector3(0.0, 0.0, SASH_DEEP * CELL + 0.012)
			var along := Vector3(w * 0.92 * (1.0 if r.position.x < 0.3 else -1.0), 0.0, 0.0)
			poses["open"] = [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, step), Transform3D(Basis.IDENTITY, step + along)]
		"U":
			# Sliding sash: the lower half rises behind the upper.
			var step := Vector3(0.0, 0.0, SASH_DEEP * CELL + 0.012)
			poses["open"] = [Transform3D.IDENTITY, Transform3D(Basis.IDENTITY, step), Transform3D(Basis.IDENTITY, step + Vector3(0.0, h * 0.48, 0.0))]
		"TT", "TTR":
			# Tilt-and-turn: turns inward on its side hinges, or tilts in at the top.
			var left := token == "TT"
			var pivot := Vector3(origin.x if left else origin.x + w, origin.y, origin.z + SASH_DEEP * CELL)
			mover.position = pivot
			m.groups[group].modes = {"turn": "Open", "tilt": "Tilt"}
			m.groups[group].mode = "turn"
			poses["turn"] = [Transform3D(Basis.IDENTITY, pivot), KitMechanism.turned(Vector3.UP, (-1.0 if left else 1.0) * (angle if angle > 0.0 else 85.0), pivot)]
			poses["tilt"] = [Transform3D(Basis.IDENTITY, pivot), KitMechanism.turned(Vector3.RIGHT, 12.0, pivot)]
	if poses.is_empty():
		poses["open"] = [Transform3D.IDENTITY]
	m.add_child(mover)
	m.add_mover(mover, group, poses)
	return mover


static func _attach(root: Node3D, attachment_name: String, body: String, mount: AABB, support: String, support_region: AABB, mover: Node3D) -> void:
	var attachment := HouseFixtureAttachment.new()
	attachment.name = attachment_name
	attachment.body_path = NodePath(body)
	attachment.mount_region = mount
	attachment.support_region = support_region
	if not support.is_empty():
		attachment.support_path = NodePath(support)
	if mover != null:
		attachment.pivot_path = NodePath("../" + mover.name)
	root.add_child(attachment)


static func _glass_body(root: Node3D, cells: Array[Vector2i], origin: Vector3, material: VoxelMaterialDefinition) -> VoxelBody:
	if cells.is_empty():
		return null
	# One box per run of cells along each row.
	var rows: Dictionary = {}
	for c in cells:
		if not rows.has(c.y):
			rows[c.y] = []
		rows[c.y].append(c.x)
	var boxes: Array[VoxelFillBox] = []
	for y in rows:
		var xs: Array = rows[y]
		xs.sort()
		var start: int = xs[0]
		var last: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and xs[i] == last + 1:
				last = xs[i]
				continue
			var box := VoxelFillBox.new()
			box.min_cell = Vector3i(start, y, 0)
			box.size = Vector3i(last - start + 1, 1, 1)
			box.material = material
			boxes.append(box)
			if i < xs.size():
				start = xs[i]
				last = xs[i]
	return KitJoinery._voxel_leaf(root, "Glass", boxes, origin, Vector3.INF)


## Glass for a window: clear (tinted) or obscured, shared per look.
static func glass_material(o: KitOpening) -> VoxelMaterialDefinition:
	var key := "%s|%s" % [o.glass_tint.to_html(), o.obscured]
	if _glass_cache.has(key):
		return _glass_cache[key]
	var definition: VoxelMaterialDefinition = KitJoinery._kit_glass().duplicate()
	var look := StandardMaterial3D.new()
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = Color(o.glass_tint, 0.7 if o.obscured else o.glass_tint.a)
	look.roughness = 0.85 if o.obscured else 0.2
	definition.mesh_material_override = look
	_glass_cache[key] = definition
	return definition


static func _handle(leaf: VoxelBody, token: String, nx: int, ny: int) -> void:
	var b := KitBuilder.new()
	var metal := KitMaterials.metal(Color(0.75, 0.76, 0.78), 0.9)
	var face := SASH_DEEP * CELL
	var hx := (nx - 1.5) * CELL
	var hy := ny * CELL * 0.5
	match token:
		"R", "TTR":
			hx = 1.5 * CELL
		"T":
			hx = nx * CELL * 0.5
			hy = 1.5 * CELL
		"B", "U":
			hx = nx * CELL * 0.5
			hy = (ny - 1.5) * CELL
	b.box(Vector3(hx - 0.008, hy - 0.03, face), Vector3(hx + 0.008, hy + 0.03, face + 0.006), metal, false)
	b.extrude(KitJoinery._round_profile(0.006, 8), Vector3(hx, hy, face + 0.03), Vector3(hx, hy - 0.08, face + 0.03), Vector3.BACK, metal, false, true)
	KitHardware.mount(leaf, b, "Handle", Vector3(hx, hy, 0.0), CELL, SASH_DEEP)
