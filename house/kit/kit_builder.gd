@tool
class_name KitBuilder
extends RefCounted
## Accumulates static house geometry, one surface per material, plus the triangles
## that collide. commit() turns it into a MeshInstance3D and one trimesh collider.
## Front faces wind clockwise (Godot's convention); every helper takes care of it,
## so callers only describe shapes. Box and quad UVs are in metres.

const FACE_ALL := 63
const FACE_NEG_X := 1
const FACE_POS_X := 2
const FACE_NEG_Y := 4
const FACE_POS_Y := 8
const FACE_NEG_Z := 16
const FACE_POS_Z := 32

## Applied to everything added afterwards; set it to place sub-assemblies.
var transform := Transform3D.IDENTITY
var _surfaces: Dictionary = {}
var _collision := PackedVector3Array()


func _tool(material: Material) -> SurfaceTool:
	if not _surfaces.has(material):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(material)
		_surfaces[material] = surface
	return _surfaces[material]


## One triangle facing `normal` (world-ish direction in local space). Optional per-vertex normals.
func tri(a: Vector3, b: Vector3, c: Vector3, material: Material, collide := true,
		uv_a := Vector2.ZERO, uv_b := Vector2.ZERO, uv_c := Vector2.ZERO, normals := PackedVector3Array()) -> void:
	a = transform * a
	b = transform * b
	c = transform * c
	var face := (b - a).cross(c - a)
	if face.length_squared() < 1e-14:
		return
	var flat := face.normalized()
	var smooth := normals.size() == 3
	var na := (transform.basis * normals[0]).normalized() if smooth else flat
	var nb := (transform.basis * normals[1]).normalized() if smooth else flat
	var nc := (transform.basis * normals[2]).normalized() if smooth else flat
	var surface := _tool(material)
	# (b - a) x (c - a) points out of a counter-clockwise face; emit it clockwise.
	for vertex in [[a, na, uv_a], [c, nc, uv_c], [b, nb, uv_b]]:
		surface.set_normal(vertex[1])
		surface.set_uv(vertex[2])
		surface.add_vertex(vertex[0])
	if collide:
		_collision.append_array([a, c, b])


## Collision only (no mesh): a simple stand-in for detailed visual geometry.
func collision_tri(a: Vector3, b: Vector3, c: Vector3) -> void:
	for p in [a, b, c]:
		_collision.append(transform * p)


func collision_quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for p in [a, b, c, a, c, d]:
		_collision.append(transform * p)


## A planar quad a-b-c-d, counter-clockwise when seen from the side it faces.
## UVs default to metres along a->b (u) and a->d (v), starting at `uv_offset`.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, material: Material, collide := true,
		uv_offset := Vector2.ZERO, u_axis := Vector3.ZERO, v_axis := Vector3.ZERO) -> void:
	if u_axis == Vector3.ZERO:
		u_axis = (b - a).normalized()
		v_axis = ((d - a) - u_axis * (d - a).dot(u_axis)).normalized()
	var uvs: Array[Vector2] = []
	for p in [a, b, c, d]:
		uvs.append(Vector2((p - a).dot(u_axis), (p - a).dot(v_axis)) + uv_offset)
	tri(a, b, c, material, collide, uvs[0], uvs[1], uvs[2])
	tri(a, c, d, material, collide, uvs[0], uvs[2], uvs[3])


## Axis-aligned box from `low` to `high` (local to `transform`); `faces` masks hidden sides.
func box(low: Vector3, high: Vector3, material: Material, collide := true, faces := FACE_ALL) -> void:
	if high.x - low.x < 1e-5 or high.y - low.y < 1e-5 or high.z - low.z < 1e-5:
		return
	var l := low
	var h := high
	if faces & FACE_NEG_Z:
		quad(Vector3(h.x, l.y, l.z), Vector3(l.x, l.y, l.z), Vector3(l.x, h.y, l.z), Vector3(h.x, h.y, l.z), material, collide, Vector2(-h.x, l.y), Vector3(-1, 0, 0), Vector3.UP)
	if faces & FACE_POS_Z:
		quad(Vector3(l.x, l.y, h.z), Vector3(h.x, l.y, h.z), Vector3(h.x, h.y, h.z), Vector3(l.x, h.y, h.z), material, collide, Vector2(l.x, l.y), Vector3.RIGHT, Vector3.UP)
	if faces & FACE_NEG_X:
		quad(Vector3(l.x, l.y, l.z), Vector3(l.x, l.y, h.z), Vector3(l.x, h.y, h.z), Vector3(l.x, h.y, l.z), material, collide, Vector2(l.z, l.y), Vector3.BACK, Vector3.UP)
	if faces & FACE_POS_X:
		quad(Vector3(h.x, l.y, h.z), Vector3(h.x, l.y, l.z), Vector3(h.x, h.y, l.z), Vector3(h.x, h.y, h.z), material, collide, Vector2(-h.z, l.y), Vector3.FORWARD, Vector3.UP)
	if faces & FACE_POS_Y:
		quad(Vector3(l.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, l.z), Vector3(l.x, h.y, l.z), material, collide, Vector2(l.x, -h.z), Vector3.RIGHT, Vector3.FORWARD)
	if faces & FACE_NEG_Y:
		quad(Vector3(l.x, l.y, l.z), Vector3(h.x, l.y, l.z), Vector3(h.x, l.y, h.z), Vector3(l.x, l.y, h.z), material, collide, Vector2(l.x, l.z), Vector3.RIGHT, Vector3.BACK)


## A box with its vertical edges (or all edges) chamfered by `bevel`, for trims and posts.
func bevel_box(low: Vector3, high: Vector3, bevel: float, material: Material, collide := true) -> void:
	var size := high - low
	bevel = minf(bevel, minf(size.x, size.z) * 0.45)
	var profile := PackedVector2Array([
		Vector2(low.x + bevel, low.z), Vector2(high.x - bevel, low.z), Vector2(high.x, low.z + bevel),
		Vector2(high.x, high.z - bevel), Vector2(high.x - bevel, high.z), Vector2(low.x + bevel, high.z),
		Vector2(low.x, high.z - bevel), Vector2(low.x, low.z + bevel)])
	prism(profile, low.y, high.y, material, collide)


## Vertical prism: a convex or simple polygon in XZ (any winding) from y0 to y1, capped.
func prism(polygon: PackedVector2Array, y0: float, y1: float, material: Material, collide := true, caps := true) -> void:
	if _signed_area(polygon) < 0.0:
		polygon.reverse()
	var count := polygon.size()
	var perimeter := 0.0
	for i in count:
		var p := polygon[i]
		var q := polygon[(i + 1) % count]
		var length := p.distance_to(q)
		# Outward faces of a counter-clockwise XZ polygon (seen from above, +Y).
		quad(Vector3(q.x, y0, q.y), Vector3(p.x, y0, p.y), Vector3(p.x, y1, p.y), Vector3(q.x, y1, q.y), material, collide, Vector2(-perimeter - length, y0), (Vector3(p.x, 0, p.y) - Vector3(q.x, 0, q.y)).normalized(), Vector3.UP)
		perimeter += length
	if caps:
		var indices := Geometry2D.triangulate_polygon(polygon)
		for i in range(0, indices.size(), 3):
			var a := polygon[indices[i]]
			var b := polygon[indices[i + 1]]
			var c := polygon[indices[i + 2]]
			# From above, polygon order in (x, z) reads clockwise because +Z points down-screen.
			tri(Vector3(a.x, y1, a.y), Vector3(c.x, y1, c.y), Vector3(b.x, y1, b.y), material, collide, Vector2(a.x, -a.y), Vector2(c.x, -c.y), Vector2(b.x, -b.y))
			tri(Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(c.x, y0, c.y), material, collide, Vector2(a.x, a.y), Vector2(b.x, b.y), Vector2(c.x, c.y))


## Sweeps a 2D cross-section along a straight line. Profile points are (across, up)
## in a frame where `up` is up and "across" is up x direction; any winding works.
func extrude(profile: PackedVector2Array, from: Vector3, to: Vector3, up: Vector3, material: Material,
		collide := true, smooth := false, caps := true) -> void:
	var direction := (to - from).normalized()
	var length := from.distance_to(to)
	if length < 1e-5:
		return
	var y_axis := (up - direction * up.dot(direction)).normalized()
	var x_axis := y_axis.cross(direction).normalized()
	if _signed_area(profile) < 0.0:
		profile.reverse()
	var count := profile.size()
	var normals := PackedVector3Array()
	normals.resize(count)
	if smooth:
		for i in count:
			var before := profile[(i - 1 + count) % count]
			var after := profile[(i + 1) % count]
			var tangent := (after - before).normalized()
			# Outward of a counter-clockwise polygon is the tangent turned clockwise.
			var n2 := Vector2(tangent.y, -tangent.x)
			normals[i] = x_axis * n2.x + y_axis * n2.y
	var distance := 0.0
	for i in count:
		var p := profile[i]
		var q := profile[(i + 1) % count]
		var a := from + x_axis * p.x + y_axis * p.y
		var b := from + x_axis * q.x + y_axis * q.y
		var c := b + direction * length
		var d := a + direction * length
		var span := p.distance_to(q)
		var uv_a := Vector2(0, distance)
		var uv_b := Vector2(0, distance + span)
		var uv_c := Vector2(length, distance + span)
		var uv_d := Vector2(length, distance)
		# Counter-clockwise profile: a, b, c, d reads counter-clockwise from outside.
		if smooth:
			var na := normals[i]
			var nb := normals[(i + 1) % count]
			tri(a, b, c, material, collide, uv_a, uv_b, uv_c, PackedVector3Array([na, nb, nb]))
			tri(a, c, d, material, collide, uv_a, uv_c, uv_d, PackedVector3Array([na, nb, na]))
		else:
			tri(a, b, c, material, collide, uv_a, uv_b, uv_c)
			tri(a, c, d, material, collide, uv_a, uv_c, uv_d)
		distance += span
	if caps:
		var indices := Geometry2D.triangulate_polygon(profile)
		for i in range(0, indices.size(), 3):
			var points: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for k in 3:
				var p := profile[indices[i + k]]
				points.append(from + x_axis * p.x + y_axis * p.y)
				uvs.append(p)
			# Start cap faces -direction, end cap faces +direction.
			tri(points[0], points[2], points[1], material, collide, uvs[0], uvs[2], uvs[1])
			tri(points[0] + direction * length, points[1] + direction * length, points[2] + direction * length, material, collide, uvs[0], uvs[1], uvs[2])


## Lathe: revolves (radius, height) points around +Y at `centre`. Smooth shaded.
func lathe(profile: PackedVector2Array, centre: Vector3, segments: int, material: Material, collide := false) -> void:
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		for k in range(profile.size() - 1):
			var p := profile[k]
			var q := profile[k + 1]
			var slope := Vector2(q.x - p.x, q.y - p.y).normalized()
			# Outward normal of the profile edge (profile runs bottom to top).
			var n2 := Vector2(slope.y, -slope.x)
			var n0 := d0 * n2.x + Vector3.UP * n2.y
			var n1 := d1 * n2.x + Vector3.UP * n2.y
			var pa := centre + d0 * p.x + Vector3.UP * p.y
			var pb := centre + d1 * p.x + Vector3.UP * p.y
			var pc := centre + d1 * q.x + Vector3.UP * q.y
			var pd := centre + d0 * q.x + Vector3.UP * q.y
			var u0 := float(i) / segments
			var u1 := float(i + 1) / segments
			# d0 -> d1 turns from +X toward +Z, i.e. clockwise seen from above; pa, pd, pc is CCW from outside.
			tri(pa, pd, pc, material, collide, Vector2(u0, p.y), Vector2(u0, q.y), Vector2(u1, q.y), PackedVector3Array([n0, n0, n1]))
			tri(pa, pc, pb, material, collide, Vector2(u0, p.y), Vector2(u1, q.y), Vector2(u1, p.y), PackedVector3Array([n0, n1, n1]))


## A flat polygon slab in an arbitrary plane: `points` are 2D in the plane spanned by
## `u_axis` and `v_axis` from `origin`, thickened by `thickness` along -(u x v).
## UVs are the plane coordinates, so roof shaders can read slope distances.
func slab(points: PackedVector2Array, origin: Vector3, u_axis: Vector3, v_axis: Vector3, thickness: float,
		top: Material, sides: Material, collide := true, uv_offset := Vector2.ZERO) -> void:
	if points.size() < 3:
		return
	if _signed_area(points) < 0.0:
		points.reverse()
	var normal := u_axis.cross(v_axis).normalized()
	var down := -normal * thickness
	var indices := Geometry2D.triangulate_polygon(points)
	for i in range(0, indices.size(), 3):
		var p: Array[Vector3] = []
		var uv: Array[Vector2] = []
		for k in 3:
			var q := points[indices[i + k]]
			p.append(origin + u_axis * q.x + v_axis * q.y)
			uv.append(q + uv_offset)
		tri(p[0], p[1], p[2], top, collide, uv[0], uv[1], uv[2])
		tri(p[0] + down, p[2] + down, p[1] + down, sides, collide, uv[0], uv[2], uv[1])
	var count := points.size()
	for i in count:
		var a := origin + u_axis * points[i].x + v_axis * points[i].y
		var b := origin + u_axis * points[(i + 1) % count].x + v_axis * points[(i + 1) % count].y
		quad(b, a, a + down, b + down, sides, collide)


## Builds the MeshInstance3D and collider under `owner`, tagged so a rebuild can find them.
func commit(owner: Node3D, collider_owner: CollisionObject3D = null, name := "Mesh") -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for material in _surfaces:
		var surface: SurfaceTool = _surfaces[material]
		surface.commit(mesh)
	var instance := MeshInstance3D.new()
	instance.name = name
	instance.mesh = mesh
	instance.set_meta(&"kit_generated", true)
	owner.add_child(instance)
	if collider_owner != null and not _collision.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(_collision)
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.name = name + "Collision"
		collision.shape = shape
		collision.set_meta(&"kit_generated", true)
		collider_owner.add_child(collision)
	return instance


func is_empty() -> bool:
	return _surfaces.is_empty()


static func _signed_area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		area += p.x * q.y - q.x * p.y
	return area * 0.5
