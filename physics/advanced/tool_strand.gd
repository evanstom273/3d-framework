class_name ToolStrand
extends Node3D
## A rope, chain, cable, spring or elastic band: a bounded chain of XPBD particles
## (no rigid body per link) pinned to its endpoints and any pulley guides, coupled
## back to the bodies through impulses. Particles wrap around scenery and props;
## there's no self-collision, rope-to-rope collision or knotting. Sleeps when idle.

var record: ConnectionRecord
var guides: Array[AttachmentPoint] = []
var points: PackedVector3Array = PackedVector3Array()
var previous: PackedVector3Array = PackedVector3Array()
var rest_length: float = 2.0
var tension: float = 0.0
var broken: bool = false
var settings: ContraptionLimits
## Rope distance from end A where a climber hangs, or negative when nobody does.
var rider_distance: float = -1.0
var rider_point: Vector3
## The climber's pull, so their weight can overload the strand.
var rider_tension: float = 0.0

var _lambdas: PackedFloat32Array = PackedFloat32Array()
var _rest_segments: PackedFloat32Array = PackedFloat32Array()
var _collided_at: PackedVector3Array = PackedVector3Array()
var _guide_indices: Array[int] = []
var _rider_index: int = -1
var _allocation_locked: bool = false
var _contacts: Array[WeakRef] = []
var _last_route: Array[Vector3] = []
var _idle: float = 0.0
var _sleeping: bool = false
var _visual := MeshInstance3D.new()
var _material := StandardMaterial3D.new()
var _query := PhysicsShapeQueryParameters3D.new()
var _sphere := SphereShape3D.new()
var _ray := PhysicsRayQueryParameters3D.new()


func setup(connection: ConnectionRecord, route_guides: Array[AttachmentPoint], length: float, count: int, limits: ContraptionLimits) -> void:
	record = connection
	guides = route_guides.duplicate()
	rest_length = length
	settings = limits
	var route := _route()
	var distances := PackedFloat32Array([0.0])
	for i in range(1, route.size()):
		distances.append(distances[-1] + route[i - 1].distance_to(route[i]))
	# Lay the particles out evenly along the initial route.
	for i in count:
		var distance := distances[-1] * i / (count - 1.0)
		var leg := 1
		while leg < distances.size() - 1 and distance > distances[leg]:
			leg += 1
		var span := maxf(distances[leg] - distances[leg - 1], 0.001)
		points.append(route[leg - 1].lerp(route[leg], (distance - distances[leg - 1]) / span))
	previous = points.duplicate()
	_collided_at = points.duplicate()
	_lambdas.resize(count - 1)
	_rest_segments.resize(count - 1)
	_rest_segments.fill(length / (count - 1))
	_sphere.radius = record.definition.radius
	_query.shape = _sphere
	_query.collision_mask = 1 | 2 | 16
	_material.albedo_color = record.definition.color
	_material.roughness = 0.75
	_material.metallic = 0.6 if record.definition.kind in [ConnectionDefinition.Kind.CHAIN, ConnectionDefinition.Kind.CABLE, ConnectionDefinition.Kind.SPRING] else 0.0
	_visual.material_override = _material
	add_child(_visual)
	_last_route = route


func _ready() -> void:
	_draw()


func wake() -> void:
	_sleeping = false
	_idle = 0.0


# --- Riders (climbing)

## Whether a player can hang on this strand.
func climbable() -> bool:
	return record.definition.kind in [ConnectionDefinition.Kind.ROPE, ConnectionDefinition.Kind.CHAIN,
		ConnectionDefinition.Kind.CABLE, ConnectionDefinition.Kind.ELASTIC]


## Pins the strand at `point`, `distance` metres of rope from end A.
func set_rider(distance: float, point: Vector3) -> void:
	rider_distance = clampf(distance, 0.0, rest_length)
	rider_point = point
	wake()
	_allocation_locked = false
	_allocate_guides(_route())
	_allocation_locked = true


func clear_rider() -> void:
	rider_distance = -1.0
	_rider_index = -1
	_allocation_locked = false
	wake()


## The rope on either side of the rider: for each, the pinned point it hangs
## from, how much rope there is to it, and the AttachmentPoint behind that pin.
func rider_supports() -> Array[Dictionary]:
	var supports: Array[Dictionary] = []
	if rider_distance < 0.0:
		return supports
	var pins := _pin_indices()
	var cumulative := _cumulative_rest()
	for j in range(pins.size() - 1):
		if rider_distance > cumulative[pins[j + 1]] and j < pins.size() - 2:
			continue
		for pin in [pins[j], pins[j + 1]]:
			supports.append({"position": points[pin], "length": absf(rider_distance - cumulative[pin]), "point": _participant(pin)})
		break
	return supports


## Rope distance from end A of the point on the strand nearest `point`, and how far away it is.
func nearest_distance(point: Vector3) -> Vector2:
	var cumulative := _cumulative_rest()
	var best := Vector2(0.0, INF)
	for i in range(points.size() - 1):
		var segment := points[i + 1] - points[i]
		var t := clampf((point - points[i]).dot(segment) / maxf(segment.length_squared(), 0.000001), 0.0, 1.0)
		var gap := point.distance_to(points[i] + segment * t)
		if gap < best.y:
			best = Vector2(lerpf(cumulative[i], cumulative[i + 1], t), gap)
	return best


func _pin_indices() -> Array[int]:
	var pins: Array[int] = [0]
	pins.append_array(_guide_indices)
	pins.append(points.size() - 1)
	return pins


func _cumulative_rest() -> PackedFloat32Array:
	var cumulative := PackedFloat32Array([0.0])
	for length in _rest_segments:
		cumulative.append(cumulative[-1] + length)
	return cumulative


func _participant(pin: int) -> AttachmentPoint:
	if pin == 0:
		return record.a
	if pin == points.size() - 1:
		return record.b
	return guides[_guide_indices.find(pin)]


## Shares the rope in the rider's leg so a particle sits exactly at the rider.
func _place_rider() -> void:
	_rider_index = -1
	var pins := _pin_indices()
	var cumulative := _cumulative_rest()
	for j in range(pins.size() - 1):
		var start := pins[j]
		var end := pins[j + 1]
		if rider_distance > cumulative[end] and j < pins.size() - 2:
			continue
		if end - start < 2:
			return
		var before := clampf(rider_distance - cumulative[start], 0.01, cumulative[end] - cumulative[start] - 0.01)
		var after := cumulative[end] - cumulative[start] - before
		var k := clampi(start + roundi(before / (before + after) * (end - start)), start + 1, end - 1)
		for i in range(start, k):
			_rest_segments[i] = before / (k - start)
		for i in range(k, end):
			_rest_segments[i] = after / (end - k)
		_rider_index = k
		return


func _route() -> Array[Vector3]:
	var route: Array[Vector3] = [record.a.position()]
	for guide in guides:
		route.append(guide.position())
	route.append(record.b.position())
	return route


func _physics_process(delta: float) -> void:
	if not record.valid():
		return
	for guide in guides:
		if not guide.valid():
			broken = true
			return
	var route := _route()
	for i in route.size():
		if route[i].distance_squared_to(_last_route[i]) > 0.000004:
			wake()
			break
	for reference in _contacts:
		var body := reference.get_ref() as RigidBody3D
		if is_instance_valid(body) and (body.linear_velocity.length_squared() > 0.0004 or body.angular_velocity.length_squared() > 0.0004):
			wake()
			break
	_last_route = route
	if rider_distance >= 0.0:
		wake()
	if _sleeping:
		return
	var exclude: Array[RID] = [record.a.body().get_rid(), record.b.body().get_rid()]
	for guide in guides:
		exclude.append(guide.body().get_rid())
	_query.exclude = exclude
	_ray.exclude = exclude
	_contacts.clear()
	var step := delta / settings.substeps
	var motion := 0.0
	for substep in settings.substeps:
		_allocate_guides(route)
		motion = maxf(motion, _integrate(step))
		_solve(route, step)
		_pin(route)
		_collide_moved(step)
		if substep == settings.substeps - 1:
			_collide_segments()
		_couple(route, step)
	_idle = _idle + delta if motion < 0.000002 else 0.0
	_sleeping = _idle > 1.5
	_draw()


## Verlet step with damping and gravity; returns the largest squared move.
func _integrate(step: float) -> float:
	var motion := 0.0
	var damping := 1.0 - record.definition.damping * step
	var fall := Vector3.DOWN * 9.8 * step * step
	for i in range(1, points.size() - 1):
		var before := points[i]
		points[i] += (points[i] - previous[i]) * damping + fall
		previous[i] = before
		motion = maxf(motion, before.distance_squared_to(points[i]))
	return motion


## Distance constraints (XPBD) plus an overall length limit, so loads can't
## stretch the strand much past its rest length. Springs also resist compression.
func _solve(route: Array[Vector3], step: float) -> void:
	_lambdas.fill(0.0)
	var inverse_mass := 1.0 / maxf(record.definition.strand_mass_per_metre * rest_length / points.size(), 0.005)
	var alpha := record.definition.compliance / (step * step)
	var spring := record.definition.kind == ConnectionDefinition.Kind.SPRING
	for iteration in settings.iterations:
		_pin(route)
		for i in range(points.size() - 1):
			var difference := points[i + 1] - points[i]
			var length := difference.length()
			if length < 0.00001:
				continue
			var constraint := length - _rest_segments[i]
			if constraint <= 0.0 and not spring:
				continue
			var wa := 0.0 if _pinned(i) else inverse_mass
			var wb := 0.0 if _pinned(i + 1) else inverse_mass
			var change := (-constraint - alpha * _lambdas[i]) / maxf(wa + wb + alpha, 0.00001)
			_lambdas[i] += change
			var correction := difference / length * change
			points[i] -= correction * wa
			points[i + 1] += correction * wb
		_taut(inverse_mass, alpha)


func _allocate_guides(route: Array[Vector3]) -> void:
	# While ridden the rope stops sliding over its guides; only the rider moves.
	if _allocation_locked:
		_place_rider()
		return
	_guide_indices.clear()
	if guides.is_empty():
		_rest_segments.fill(rest_length / (points.size() - 1))
		if rider_distance >= 0.0:
			_place_rider()
		return
	var lengths: Array[float] = []
	var total := 0.0
	for i in range(1, route.size()):
		var length := route[i].distance_to(route[i - 1])
		lengths.append(length)
		total += length
	var cumulative := 0.0
	var start := 0
	# Rope slides over the guides: each side gets material in proportion to its length.
	for leg in lengths.size():
		cumulative += lengths[leg]
		var last := leg == lengths.size() - 1
		var end := points.size() - 1 if last else clampi(roundi(cumulative / maxf(total, 0.01) * (points.size() - 1)), start + 1, points.size() - (lengths.size() - leg))
		if not last:
			_guide_indices.append(end)
		for i in range(start, end):
			_rest_segments[i] = rest_length * lengths[leg] / maxf(total, 0.01) / (end - start)
		start = end
	if rider_distance >= 0.0:
		_place_rider()


func _pinned(index: int) -> bool:
	return index == 0 or index == points.size() - 1 or index == _rider_index or _guide_indices.has(index)


func _pin(route: Array[Vector3]) -> void:
	points[0] = route[0]
	points[points.size() - 1] = route[route.size() - 1]
	for i in _guide_indices.size():
		points[_guide_indices[i]] = route[i + 1]
	if _rider_index > 0:
		points[_rider_index] = rider_point


func _taut(inverse_mass: float, alpha: float) -> void:
	var total := 0.0
	var gradients := PackedVector3Array()
	gradients.resize(points.size())
	for i in range(points.size() - 1):
		var difference := points[i + 1] - points[i]
		total += difference.length()
		var unit := difference.normalized()
		gradients[i] -= unit
		gradients[i + 1] += unit
	if total <= rest_length:
		return
	var denominator := alpha
	for i in points.size():
		if not _pinned(i):
			denominator += inverse_mass * gradients[i].length_squared()
	if denominator <= 0.0:
		return
	var change := -(total - rest_length) / denominator
	for i in points.size():
		if not _pinned(i):
			points[i] += gradients[i] * change * inverse_mass


## Sweeps only particles that moved noticeably since their last check.
func _collide_moved(step: float) -> void:
	var space := get_world_3d().direct_space_state
	for i in range(1, points.size() - 1):
		if _pinned(i):
			continue
		var from := _collided_at[i]
		var motion := points[i] - from
		if motion.length_squared() < 0.000004:
			continue
		_query.transform = Transform3D(Basis(), from)
		_query.motion = motion
		var fraction := space.cast_motion(_query)
		if fraction[0] >= 1.0:
			_collided_at[i] = points[i]
			continue
		_query.transform.origin = from + motion * minf(1.0, fraction[1] + 0.001)
		_query.motion = Vector3.ZERO
		var hit := space.get_rest_info(_query)
		points[i] = from + motion * fraction[0]
		if not hit.is_empty():
			points[i] += hit["normal"] * 0.002
			var body := instance_from_id(hit["collider_id"]) as CollisionObject3D
			var mass := record.definition.strand_mass_per_metre * rest_length / points.size()
			_reaction(body, points[i], motion * mass / maxf(step, 0.001))
		previous[i] = points[i].lerp(previous[i], 0.4)
		_collided_at[i] = points[i]


## Thin obstacles can slip between particles; a ray per segment catches them.
func _collide_segments() -> void:
	var space := get_world_3d().direct_space_state
	_ray.collision_mask = 1 | 2 | 16
	for i in range(points.size() - 1):
		_ray.from = points[i]
		_ray.to = points[i + 1]
		var hit := space.intersect_ray(_ray)
		if hit.is_empty():
			continue
		var target := i + 1 if not _pinned(i + 1) else i
		if _pinned(target):
			continue
		points[target] = hit["position"] + hit["normal"] * record.definition.radius * 1.1
		_collided_at[target] = points[target]
		_reaction(hit["collider"], hit["position"], -hit["normal"] * 0.05)


## Pulls the attached bodies (and pulleys) toward each other when the strand is
## taut, and reports the tension so overloads can break it.
func _couple(route: Array[Vector3], step: float) -> void:
	var path_length := 0.0
	# A climber pins the strand off its line, so measure the route while ridden.
	if not guides.is_empty() or rider_distance >= 0.0:
		for i in range(1, route.size()):
			path_length += route[i].distance_to(route[i - 1])
	else:
		for i in range(1, points.size()):
			path_length += points[i].distance_to(points[i - 1])
	var constraint := path_length - rest_length
	var spring := record.definition.kind == ConnectionDefinition.Kind.SPRING
	if constraint < 0.0 and not spring:
		tension = 0.0
		return
	if path_length > rest_length * record.definition.maximum_stretch:
		broken = true
		return
	var participants: Array[AttachmentPoint] = [record.a]
	participants.append_array(guides)
	participants.append(record.b)
	var gradients: Array[Vector3] = []
	var inverse_mass := 0.0
	var speed := 0.0
	for i in participants.size():
		var gradient := Vector3.ZERO
		if not guides.is_empty():
			if i > 0:
				gradient += (route[i] - route[i - 1]).normalized()
			if i < route.size() - 1:
				gradient += (route[i] - route[i + 1]).normalized()
		elif i == 0:
			gradient = (points[0] - points[1]).normalized()
		else:
			gradient = (points[points.size() - 1] - points[points.size() - 2]).normalized()
		gradients.append(gradient)
		var body := participants[i].body() as RigidBody3D
		if body != null and not body.freeze:
			inverse_mass += gradient.length_squared() / body.mass
			speed += body.linear_velocity.dot(gradient)
	var compliance := record.definition.compliance
	var impulse := -(constraint + speed * step * record.definition.damping) / maxf(inverse_mass * step + compliance / step, 0.0001)
	tension = absf(impulse / step)
	var cap := record.definition.strength * step * 2.0
	impulse = clampf(impulse, -cap, cap)
	for i in participants.size():
		_reaction(participants[i].body(), participants[i].position(), gradients[i] * impulse)


func _reaction(object: Object, point: Vector3, impulse: Vector3) -> void:
	var body := object as RigidBody3D
	if body == null:
		return
	var service := get_parent() as ContraptionWorld
	if service != null:
		service.watch(AttachmentPoint.at(body, point))
	_contacts.append(weakref(body))
	if not body.freeze:
		body.apply_impulse(impulse.limit_length(record.definition.strength / 60.0), point - body.global_position)


# --- Visuals

func _draw() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := record.definition.radius
	if record.definition.kind == ConnectionDefinition.Kind.CHAIN:
		_draw_chain(surface, radius)
	else:
		_draw_tube(surface, radius)
	surface.generate_normals()
	_visual.mesh = surface.commit()


## A round six-sided tube through every particle.
func _draw_tube(surface: SurfaceTool, radius: float) -> void:
	var sides := 6
	var rings: Array[PackedVector3Array] = []
	for i in points.size():
		var along := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := along.cross(side)
		var ring := PackedVector3Array()
		for s in sides:
			var angle := TAU * s / sides
			ring.append(to_local(points[i] + (side * cos(angle) + up * sin(angle)) * radius))
		rings.append(ring)
	for i in range(points.size() - 1):
		for s in sides:
			var t := (s + 1) % sides
			var a := rings[i][s]
			var b := rings[i][t]
			var c := rings[i + 1][t]
			var d := rings[i + 1][s]
			for vertex: Vector3 in [a, c, b, a, d, c]:
				surface.add_vertex(vertex)


## Alternating flat oval links, each turned 90 degrees from the last.
func _draw_chain(surface: SurfaceTool, radius: float) -> void:
	var segments := 8
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var along := b - a
		var length := along.length()
		if length < 0.0001:
			continue
		var direction := along / length
		var side := direction.cross(Vector3.UP if absf(direction.y) < 0.9 else Vector3.RIGHT).normalized()
		var up := direction.cross(side)
		var width := side if i % 2 == 0 else up
		var thickness := up if i % 2 == 0 else side
		var centre := (a + b) * 0.5
		var loop := PackedVector3Array()
		for s in segments:
			var angle := TAU * s / segments
			loop.append(centre + direction * cos(angle) * length * 0.62 + width * sin(angle) * radius * 1.8)
		var offset := thickness * radius * 0.45
		for s in segments:
			var p := loop[s]
			var q := loop[(s + 1) % segments]
			for vertex: Vector3 in [p - offset, q + offset, q - offset, p - offset, p + offset, q + offset]:
				surface.add_vertex(to_local(vertex))
