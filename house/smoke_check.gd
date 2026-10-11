extends SceneTree
## Focused headless checks; does not save or modify project assets.

var failures := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("HOUSE CHECK: " + message)


func frames(count := 3) -> void:
	for index in count:
		await physics_frame
	await process_frame


func all_nodes(node: Node) -> Array[Node]:
	var found: Array[Node] = [node]
	for child in node.get_children():
		found.append_array(all_nodes(child))
	return found


func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://house/assets/authoring_manifest.json"))
	var model_count := 0
	for path in manifest:
		if String(path).ends_with(".vox"):
			var data := VoxFile.read(path)
			expect(not data.is_empty() and not data.voxels.is_empty(), "Readable MagicaVoxel asset " + path)
			model_count += 1
		elif String(path).ends_with(".tres"):
			expect(load(path) != null, "Load resource " + path)
	var packed := load("res://house/house.tscn") as PackedScene
	expect(packed != null, "House scene loads")
	if packed == null:
		quit(1)
		return
	var house := packed.instantiate()
	root.add_child(house)
	current_scene = house
	house.get_node("Player").set_gameplay_enabled(false)
	await frames(4)
	var initial_free := 0
	var attachment_count := 0
	for node in all_nodes(house):
		if node is RigidBody3D and not node.freeze:
			initial_free += 1
		if node is HouseFixtureAttachment:
			attachment_count += 1
			expect(node.attached, "Initially mounted " + str(node.get_path()))
			if node.attached:
				expect(not node.body.anchors.is_empty(), "Mount has anchor cells " + str(node.get_path()))
	expect(initial_free < 140, "Initial free body budget: %d" % initial_free)
	for index in 6:
		var body := house.get_node("Architecture/Section%d" % index) as VoxelBody
		expect(body.structure.vox_file.ends_with(".vox"), "Architecture section has editable VOX")
		expect(VoxelConnectivity.components(body.cells).size() == 1, "Connected structural section %d" % index)
		for cell in body.anchors:
			expect(cell.y == 0, "Only foundation layer anchored")
	var menu: SpawnMenu
	for child in house.get_children():
		if child is SpawnMenu:
			menu = child
	expect(menu != null, "Existing spawn menu installed")
	if menu != null:
		menu.open()
		expect(menu.is_open(), "Spawn menu opens")
		menu.close()
	for node_path in ["Fixtures/FrontDoor", "Fixtures/LivingFront", "Rooms/Kitchen/CupboardWest/Door", "Rooms/Kitchen/Drawers/Drawer1"]:
		var target: Node3D = house.get_node(node_path)
		var attachment := target.get_node("Attachment") as HouseFixtureAttachment
		var closed := attachment.body.global_transform
		target.perform_interaction_action(&"open", null)
		# Wait for physics-time animation, not a wall-clock timer during startup.
		await target._motion.finished
		await frames(1)
		expect(not attachment.body.global_transform.is_equal_approx(closed), "Opens: " + node_path)
		target.perform_interaction_action(&"close", null)
		await target._motion.finished
		await frames(1)
		expect(attachment.body.global_transform.is_equal_approx(closed), "Closes: " + node_path)
	# A hit during animation releases a damaged leaf, without an active follow tween.
	var door: Node3D = house.get_node("Fixtures/FrontDoor")
	door.perform_interaction_action(&"open", null)
	await frames(6)
	var leaf := door.get_node("Leaf") as VoxelBody
	leaf.damage_sphere(Vector3(0, 20, 0), 17.0, 1000.0)
	await frames(4)
	expect(not door.get_node("Attachment").attached and not leaf.freeze, "Damaged moving leaf released")
	expect(door.get_interaction_actions().is_empty(), "Broken door stops exposing actions")
	# Remove a jamb's actual supporting cells rather than invoking the release method.
	var supported: Node3D = house.get_node("Fixtures/StudyDoor")
	var mount := supported.get_node("Attachment") as HouseFixtureAttachment
	var support := mount.get_node(mount.support_path) as VoxelBody
	for cell in support.cells.keys():
		if mount.support_region.has_point((Vector3(cell) + Vector3.ONE * 0.5) * support.voxel_size):
			support.take_voxel(cell)
	await frames(4)
	expect(not mount.attached, "Destroyed jamb releases door")
	var pane := house.get_node("Fixtures/StudyFront/Glass") as VoxelBody
	var glass_cell := Vector3i(5, 10, 0)
	var spot := pane.cell_to_world(glass_cell)
	var normal := pane.global_basis.z
	var query := PhysicsRayQueryParameters3D.create(spot - normal * 0.15, spot + normal * 0.15, 16)
	var space := pane.get_world_3d().direct_space_state
	expect(not space.intersect_ray(query).is_empty(), "Intact pane has collision")
	var pane_count := pane.cells.size()
	pane.damage_sphere(Vector3(glass_cell) + Vector3.ONE * 0.5, 1.1, 100.0)
	await frames(4)
	expect(pane.cells.size() < pane_count, "Glass cells removed")
	expect(space.intersect_ray(query).is_empty(), "Glass hole has no stale collision")
	expect(pane.mesh_material_override != null, "Glass uses transparent material override")
	# Exercise existing tool damage and collision rebuilding on an isolated wall.
	var wall := VoxelBody.new()
	wall.structure = load("res://props/voxel_structures/brick_wall.tres")
	wall.position = Vector3(50, 0, 0)
	house.add_child(wall)
	await frames()
	var hammer: PhysicsObjectDefinition = load("res://props/hammer.tres")
	var impact := ToolImpact.new()
	impact.tool_definition = hammer.tool
	impact.power = 1.0
	impact.damage = hammer.tool.damage
	impact.position = Vector3(50, 0.9, -0.1)
	impact.normal = Vector3(0, 0, -1)
	impact.direction = Vector3(0, 0, 1)
	impact.impact_type = hammer.tool.impact_type
	var count_before := wall.cells.size()
	wall.receive_tool_impact(impact)
	wall.receive_tool_impact(impact)
	await frames(4)
	expect(wall.cells.size() < count_before, "Existing charged hammer removes wall cells")
	var wall_ray := PhysicsRayQueryParameters3D.create(Vector3(50, 0.9, -0.4), Vector3(50, 0.9, 0.4), 16)
	# Debris is expected inside a fresh breach; only the original wall collider
	# must disappear where cells have been removed.
	var excluded: Array[RID] = []
	for node in all_nodes(house):
		if node is CollisionObject3D and node != wall:
			excluded.append(node.get_rid())
	wall_ray.exclude = excluded
	expect(space.intersect_ray(wall_ray).is_empty(), "Wall breach updates collision")
	# Existing contact-damage consequences can damage both a moving chair and fixed wall.
	var chair := house.get_node("Rooms/Kitchen/ChairWest") as VoxelBody
	var chair_count := chair.cells.size()
	var chair_cell: Vector3i = chair.cells.keys()[0]
	var wall_cell: Vector3i = wall.cells.keys()[0]
	ImpactBreaker._apply(chair, wall, chair.cell_to_world(chair_cell), wall.cell_to_world(wall_cell), Vector3.UP, 150.0, 0.2, Vector3.FORWARD, 150.0)
	await frames(4)
	expect(chair.cells.size() < chair_count, "Furniture participates in collision damage")
	# Existing construction APIs preserve material/cells, and cement a compatible piece.
	var material: VoxelMaterialDefinition = load("res://props/voxel_materials/brick.tres")
	var added := Vector3i(12, 0, 0)
	wall.add_voxel(added, material, true)
	await frames()
	expect(wall.cells.has(added), "Voxel construction remains available")
	var piece_cells: Dictionary[Vector3i, int] = {Vector3i.ZERO: 0}
	var palette: Array[VoxelMaterialDefinition] = [material]
	var piece := VoxelBody.create_piece(piece_cells, {}, palette, wall.voxel_size)
	house.add_child(piece)
	piece.global_position = wall.to_global(Vector3(13, 0, 0) * wall.voxel_size)
	await frames(1)
	expect(VoxelConstruction.cement(piece, wall) == 1, "Compatible fragment cements into structure")
	var section := house.get_node("Architecture/Section0") as VoxelBody
	for cell in section.anchors.keys():
		section.take_voxel(cell)
	await frames(4)
	expect(not section.freeze or section.cells.is_empty(), "Removing a section's foundation releases it")
	var old_id := house.get_instance_id()
	expect(reload_current_scene() == OK, "House reset reloads scene")
	await frames(4)
	expect(current_scene.get_instance_id() != old_id, "Reset replaces damaged scene")
	expect(current_scene.get_node("Fixtures/FrontDoor/Attachment").attached, "Reset restores attached door")
	print("HOUSE CHECKS: ", checks, ", failures: ", failures, ", VOX models: ", model_count, ", initial free bodies: ", initial_free, ", attachments: ", attachment_count)
	quit(1 if failures else 0)
