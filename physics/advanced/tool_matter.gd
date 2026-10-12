class_name ToolMatter
extends RefCounted
## The physical side effects of advanced tools: paint/scorch/heat on surfaces,
## glue patches bonding on contact, nail and plunger projectiles, markers, vacuum
## cargo and spray foam. All bounded by ContraptionLimits; queries are pooled.

const SCORCH := Color(0.12, 0.085, 0.05)
const SURFACE_MASK := 1 | 2 | 16

static var _sphere := SphereShape3D.new()
static var _shape_query := PhysicsShapeQueryParameters3D.new()
static var _ray := PhysicsRayQueryParameters3D.new()


static func patch_mesh(color: Color, radius: float) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.004
	mesh.radial_segments = 14
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual


static func orient(visual: Node3D, point: AttachmentPoint) -> void:
	var up := point.normal()
	visual.global_position = point.position() + up * 0.003
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.UP).normalized()
	visual.global_basis = Basis(side, up, side.cross(up))


# --- Surfaces

## Paint, scorch, heat, cool or wash a surface. Voxel bodies store it per face;
## ordinary props get a few small patches stuck to them.
static func surface(world: ContraptionWorld, hit: Dictionary, operation: String, amount: float, color: Color, radius: float = 0.15) -> void:
	var body := hit["collider"] as CollisionObject3D
	if body == null:
		return
	if body is VoxelBody:
		VoxelToolSurface.apply(body as VoxelBody, hit["position"], hit["normal"], radius, operation, amount, color)
		if operation == "heat":
			track_heat(world, body as VoxelBody)
		return
	var entries: Array = world.get_meta(&"surfaces", [])
	var own: Array = []
	for entry: Dictionary in entries.duplicate():
		if not entry["point"].valid():
			entry["visual"].queue_free()
			entries.erase(entry)
			continue
		if entry["point"].body() != body:
			continue
		own.append(entry)
		if entry["point"].position().distance_to(hit["position"]) < radius * 1.5:
			if operation == "wash":
				entry["visual"].queue_free()
				entries.erase(entry)
			elif operation == "heat" or operation == "paint":
				entry["visual"].material_override.albedo_color = color if operation == "paint" else SCORCH
			world.set_meta(&"surfaces", entries)
			return
	if operation != "heat" and operation != "paint":
		world.set_meta(&"surfaces", entries)
		return
	if own.size() >= 8:
		own[0]["visual"].queue_free()
		entries.erase(own[0])
	if entries.size() >= 256:
		return
	var point := AttachmentPoint.at(body, hit["position"], hit["normal"])
	var visual := patch_mesh(color if operation == "paint" else SCORCH, radius)
	body.add_child(visual)
	orient(visual, point)
	entries.append({"point": point, "visual": visual})
	world.set_meta(&"surfaces", entries)


static func clear_surfaces(world: ContraptionWorld) -> void:
	for entry in world.get_meta(&"surfaces", []):
		if is_instance_valid(entry["visual"]):
			entry["visual"].queue_free()
	world.set_meta(&"surfaces", [])
	world.set_meta(&"heated", {})


## Remembers a voxel body with hot faces so it cools over time.
static func track_heat(world: ContraptionWorld, body: VoxelBody) -> void:
	var heated: Dictionary = world.get_meta(&"heated", {})
	heated[body.get_instance_id()] = weakref(body)
	world.set_meta(&"heated", heated)


# --- Ticked at 20 Hz by the world

static func update(world: ContraptionWorld, delta: float) -> void:
	var space := world.get_world_3d().direct_space_state
	_update_patches(world, space)
	_update_markers(world)
	_update_projectiles(world, space, delta)
	_update_foam(world, delta)
	_update_heat(world, delta)


## A glue patch bonds to the first thing pressed onto it.
static func _update_patches(world: ContraptionWorld, space: PhysicsDirectSpaceState3D) -> void:
	_sphere.radius = 0.045
	for patch: Dictionary in world.patches.duplicate():
		var point: AttachmentPoint = patch["point"]
		if not point.valid():
			world.erase_patch(patch)
			continue
		orient(patch["visual"], point)
		_shape_query.shape = _sphere
		_shape_query.collision_mask = SURFACE_MASK
		_shape_query.exclude = [point.body().get_rid()]
		_shape_query.motion = Vector3.ZERO
		_shape_query.transform = Transform3D(Basis(), point.position() + point.normal() * 0.015)
		for overlap in space.intersect_shape(_shape_query, 8):
			var other := overlap["collider"] as CollisionObject3D
			if other == null:
				continue
			var second := AttachmentPoint.at(other, _shape_query.transform.origin, -point.normal())
			if world.create(point, second, patch["definition"]) != null:
				world.erase_patch(patch)
				break


static func _update_markers(world: ContraptionWorld) -> void:
	for entry: Dictionary in world.markers.duplicate():
		var point: AttachmentPoint = entry["point"]
		if not point.valid():
			world.erase_marker(entry)
			continue
		var label: Label3D = entry["visual"]
		var normal := point.normal()
		label.global_position = point.position() + normal * 0.01
		label.global_basis = Basis.looking_at(-normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD)
		label.rotate_object_local(Vector3.BACK, entry["angle"])


## Swept checks catch fast projectiles; nails fasten on impact, plungers stick.
static func _update_projectiles(world: ContraptionWorld, space: PhysicsDirectSpaceState3D, delta: float) -> void:
	for entry: Dictionary in world.projectiles.duplicate():
		var body := entry["body"] as RigidBody3D
		if not is_instance_valid(body):
			world.projectiles.erase(entry)
			continue
		entry["age"] += delta
		if entry["done"]:
			continue
		_ray.from = entry["previous"]
		_ray.to = body.global_position + body.linear_velocity * delta
		_ray.collision_mask = SURFACE_MASK
		_ray.exclude = [body.get_rid()]
		var hit := space.intersect_ray(_ray)
		entry["previous"] = body.global_position
		if not hit.is_empty():
			entry["done"] = true
			if entry["plunger"]:
				body.global_position = hit["position"] + hit["normal"] * 0.07
				body.linear_velocity = Vector3.ZERO
				world.create(AttachmentPoint.at(body, hit["position"], -hit["normal"]), AttachmentPoint.at(hit["collider"], hit["position"], hit["normal"]), entry["definition"])
				ImpactFeedback.spawn(world, hit["position"], hit["normal"], PhysicsToolDefinition.ImpactType.BLUNT, 0.4, Color(0.8, 0.2, 0.15), ImpactFeedback.Sound.RUBBER)
			else:
				fasten(world, hit, entry["definition"], entry["depth"])
				ImpactFeedback.spawn(world, hit["position"], hit["normal"], PhysicsToolDefinition.ImpactType.SHARP, 0.4, Color(0.7, 0.7, 0.72), ImpactFeedback.Sound.METAL)
				body.queue_free()
				world.projectiles.erase(entry)
		elif entry["age"] > 8.0 and not entry["plunger"]:
			body.queue_free()
			world.projectiles.erase(entry)


static func _update_foam(world: ContraptionWorld, delta: float) -> void:
	for entry: Dictionary in world.foam.duplicate():
		var body := entry["body"] as VoxelBody
		if not is_instance_valid(body):
			world.foam.erase(entry)
			continue
		for cell in entry["owned_cells"].duplicate():
			if not body.cells.has(cell):
				entry["owned_cells"].erase(cell)
		if entry["owned_cells"].is_empty():
			world.foam.erase(entry)
			continue
		entry["age"] += delta
		if not entry["hardened"] and entry["age"] >= entry["hardening"]:
			entry["hardened"] = true
			var material: VoxelMaterialDefinition = load("res://contraptions/materials/foam.tres")
			var index := body.palette.find(material)
			if index < 0:
				index = body.palette.size()
				body.palette.append(material)
			for cell in entry["owned_cells"]:
				body._set_cell(cell, index)
		if entry["age"] > entry["lifetime"]:
			for cell in entry["owned_cells"]:
				body._remove_cell(cell)
			world.foam.erase(entry)


static func _update_heat(world: ContraptionWorld, delta: float) -> void:
	var heated: Dictionary = world.get_meta(&"heated", {})
	for id in heated.keys():
		var body := heated[id].get_ref() as VoxelBody
		if not is_instance_valid(body):
			heated.erase(id)
			continue
		var hot := false
		for cell in body.surface_state:
			if not body.cells.has(cell):
				continue
			var profile: ToolMaterialProfile = body.palette[body.cells[cell]].tool_profile
			var cooling := profile.cooling_rate if profile != null else 0.2
			for state: Dictionary in body.surface_state[cell].values():
				if state.get("heat", 0.0) > 0.0:
					state["heat"] = maxf(0.0, state["heat"] - delta * cooling)
					hot = true
		if not hot:
			heated.erase(id)
	world.set_meta(&"heated", heated)


# --- Fastening and projectiles

## Fastens the hit object to whatever lies directly behind it within `depth`.
static func fasten(world: ContraptionWorld, hit: Dictionary, definition: ConnectionDefinition, depth: float) -> bool:
	var body := hit["collider"] as CollisionObject3D
	if body == null:
		return false
	var normal: Vector3 = hit["normal"]
	var position: Vector3 = hit["position"]
	_ray.from = position - normal * 0.005
	_ray.to = position - normal * depth
	_ray.collision_mask = SURFACE_MASK
	_ray.exclude = [body.get_rid()]
	var back := world.get_world_3d().direct_space_state.intersect_ray(_ray)
	if back.is_empty():
		world.reason = "Nothing behind it to fasten into"
		return false
	return world.create(AttachmentPoint.at(body, position, normal), AttachmentPoint.at(back["collider"], back["position"], back["normal"]), definition) != null


## Fires a nail or plunger from `pose` (its -Z is the direction of travel).
static func launch(world: ContraptionWorld, tool: RigidBody3D, pose: Transform3D, action: ToolActionDefinition, reused: RigidBody3D = null) -> bool:
	if world.projectiles.size() >= world.limits.projectiles and reused == null:
		world.reason = "Too many projectiles; pick some up"
		return false
	var plunger := action.operation == "plunger"
	var body := reused
	if body == null:
		var path := "res://props/advanced/plunger.tres" if plunger else "res://contraptions/assets/nail_projectile.tres"
		body = PhysicsProp.create(load(path))
		world.add_child(body)
	body.show()
	body.freeze = false
	body.collision_layer = 16
	body.collision_mask = 19
	body.continuous_cd = true
	body.global_transform = pose
	body.linear_velocity = -pose.basis.z * action.projectile_speed
	body.angular_velocity = Vector3.ZERO
	body.add_collision_exception_with(tool)
	world.forget_projectile(body)
	world.projectiles.append({"body": body, "previous": pose.origin, "age": 0.0, "definition": action.connection,
		"depth": action.probe_depth, "done": false, "plunger": plunger})
	return true


# --- Vacuum cargo

static func volume(body: RigidBody3D) -> float:
	if body is VoxelBody:
		var voxel := body as VoxelBody
		return voxel.cells.size() * pow(voxel.voxel_size, 3.0)
	if body is PhysicsProp and (body as PhysicsProp).definition != null:
		var bounds := AABB()
		var first := true
		for part in (body as PhysicsProp).definition.get_collision_parts():
			var box: AABB = part["transform"] * (part["shape"] as Shape3D).get_debug_mesh().get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		return bounds.get_volume()
	return 1.0


## Stores a loose body inside the vacuum: same body, hidden and parked, so it
## comes back out with its identity, mass and state intact.
static func collect(world: ContraptionWorld, vacuum: RigidBody3D, body: RigidBody3D, action: ToolActionDefinition) -> bool:
	if body.freeze or body == vacuum or body.get_meta(&"vacuum_stored", false) or body.get_meta(&"despawning", false) or world.attached(body):
		return false
	var entries: Array = world.cargo.get(vacuum.get_instance_id(), [])
	var mass := body.mass
	var litres := volume(body)
	for entry in entries:
		if is_instance_valid(entry["body"]):
			mass += entry["body"].mass
			litres += entry["volume"]
	if entries.size() >= action.cargo_items or mass > action.cargo_mass or litres > action.cargo_volume:
		world.reason = "Vacuum full"
		return false
	entries.append({"body": body, "volume": volume(body), "layer": body.collision_layer, "mask": body.collision_mask, "process": body.is_physics_processing()})
	body.set_meta(&"vacuum_stored", true)
	body.freeze = true
	body.hide()
	body.collision_layer = 0
	body.collision_mask = 0
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.set_physics_process(false)
	if body is VoxelBody:
		VoxelBody._rubble.erase(body)
	world.cargo[vacuum.get_instance_id()] = entries
	world.watch(AttachmentPoint.at(vacuum, vacuum.global_position))
	return true


static func release_cargo(world: ContraptionWorld, vacuum: CollisionObject3D, deleting: bool) -> void:
	var entries: Array = world.cargo.get(vacuum.get_instance_id(), [])
	var space := world.get_world_3d().direct_space_state
	for entry: Dictionary in entries.duplicate():
		var body := entry["body"] as RigidBody3D
		if not is_instance_valid(body):
			entries.erase(entry)
			continue
		var clear := false
		var position := vacuum.global_position
		_sphere.radius = maxf(0.08, pow(entry["volume"], 1.0 / 3.0) * 0.8)
		_shape_query.shape = _sphere
		_shape_query.collision_mask = SURFACE_MASK
		_shape_query.motion = Vector3.ZERO
		_shape_query.exclude = [vacuum.get_rid(), body.get_rid()]
		for i in 24:
			var direction := Vector3(cos(i * 2.4), 0.3 + i * 0.03, sin(i * 2.4)).normalized()
			position = vacuum.global_position + direction * (0.7 + i * 0.08)
			_shape_query.transform = Transform3D(Basis(), position)
			if space.intersect_shape(_shape_query, 1).is_empty():
				clear = true
				break
		if not clear and not deleting:
			world.reason = "No room to empty the vacuum here"
			continue
		body.global_position = position
		body.collision_layer = entry["layer"]
		body.collision_mask = entry["mask"]
		body.freeze = false
		body.show()
		body.sleeping = false
		body.remove_meta(&"vacuum_stored")
		body.set_physics_process(entry["process"])
		if body is VoxelBody and (body as VoxelBody).is_rubble:
			VoxelBody._register_rubble(body as VoxelBody)
		entries.erase(entry)
	if entries.is_empty():
		world.cargo.erase(vacuum.get_instance_id())
	else:
		world.cargo[vacuum.get_instance_id()] = entries


# --- Markers and foam

static func marker(world: ContraptionWorld, point: AttachmentPoint, text: String, angle: float, color: Color) -> bool:
	if world.markers.size() >= world.limits.markers:
		world.reason = "Marker limit reached"
		return false
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.pixel_size = 0.003
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	world.add_child(label)
	world.markers.append({"point": point, "visual": label, "angle": angle})
	world.watch(point)
	return true


## Adds one foam cell where the crosshair points. Foam on foam joins up; foam on
## anything else starts its own small cluster, weakly glued on, so it never
## changes the host's material or gives it foam's lifetime.
static func grow_foam(world: ContraptionWorld, aim: Transform3D, action: ToolActionDefinition, exclude: Array[RID]) -> bool:
	var count := 0
	var volume_total := 0.0
	for entry in world.foam:
		if is_instance_valid(entry["body"]):
			count += entry["owned_cells"].size()
			volume_total += entry["owned_cells"].size() * pow(entry["body"].voxel_size, 3.0)
	var size := 0.08
	if count >= world.limits.foam_cells or volume_total + pow(size, 3.0) > world.limits.foam_volume:
		world.reason = "Foam limit reached"
		return false
	var space := world.get_world_3d().direct_space_state
	var target := VoxelConstruction.find_place_target(world.get_world_3d(), aim.origin, -aim.basis.z, action.range_metres, exclude, size)
	if target.is_empty() or not target["valid"]:
		world.reason = "Aim at a clear surface"
		return false
	var material: VoxelMaterialDefinition = load("res://contraptions/materials/foam_soft.tres")
	var support: VoxelBody = target.get("body")
	var on_foam := false
	for entry in world.foam:
		if entry["body"] == support:
			on_foam = true
			break
	_ray.from = aim.origin
	_ray.to = aim.origin - aim.basis.z * action.range_metres
	_ray.collision_mask = SURFACE_MASK
	_ray.exclude = exclude
	var surface_hit := space.intersect_ray(_ray)
	if support != null and not on_foam:
		if surface_hit.is_empty():
			return false
		var centre: Vector3 = surface_hit["position"] + surface_hit["normal"] * size * 0.6
		var world_cell := Vector3i((centre / size).floor())
		target = {"body": null, "world_cell": world_cell, "size": size, "anchored": false, "valid": true,
			"transform": Transform3D(Basis(), (Vector3(world_cell) + Vector3.ONE * 0.5) * size)}
		if VoxelConstruction._blocked(space, target["transform"], size, support):
			world.reason = "Something is in the way"
			return false
	var body: VoxelBody = VoxelConstruction.place(target, material, world)
	if body == null:
		return false
	var added_cell: Vector3i = target.get("cell", Vector3i.ZERO)
	var tracked := false
	for entry in world.foam:
		if entry["body"] == body and not entry["hardened"]:
			tracked = true
			if not entry["owned_cells"].has(added_cell):
				entry["owned_cells"].append(added_cell)
	if not tracked:
		world.foam.append({"body": body, "owned_cells": [added_cell], "age": 0.0, "hardening": action.foam_hardening,
			"hardened": false, "lifetime": action.foam_lifetime})
		var anchor := AttachmentPoint.at(body, body.cell_to_world(body.cells.keys()[0]), Vector3.ZERO)
		world.watch(anchor)
		if support != null and support != body and not surface_hit.is_empty():
			world.create(anchor, AttachmentPoint.at(support, surface_hit["position"], surface_hit["normal"]), load("res://contraptions/config/glue.tres"))
	return true


## Pushes a body: a real impulse if it's loose; if it's frozen but carried by
## something that can react (a VoxelBody: an NPC's limb), it's told instead.
static func push(target: RigidBody3D, impulse: Vector3, point: Vector3) -> void:
	if target == null:
		return
	if not target.freeze:
		target.apply_impulse(impulse, point - target.global_position)
	elif target is VoxelBody:
		(target as VoxelBody).pushed.emit(impulse, point)
