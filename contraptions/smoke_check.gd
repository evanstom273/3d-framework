extends SceneTree
## Focused, headless integration checks for the expansion; not a gameplay suite.
var failures: Array[String] = []
var scene: Node3D
var service: ContraptionWorld

func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label); push_error(label)
	else: print("PASS ", label)

func _initialize() -> void:
	create_timer(25).timeout.connect(func(): push_error("Smoke check timed out"); quit(2))
	_run.call_deferred()

func _run() -> void:
	scene = Node3D.new(); root.add_child(scene); current_scene = scene
	service = ContraptionWorld.find(scene, true)
	var player := (load("res://player.tscn") as PackedScene).instantiate()
	scene.add_child(player); player.position = Vector3(0, 20, 0); player.set_physics_process(false)
	await physics_frame
	var handler: ToolHandler = player.get_node("ToolHandler")
	var count := 0
	for file in DirAccess.get_files_at("res://props/tools/advanced"):
		if not file.ends_with(".tres"): continue
		var definition := load("res://props/tools/advanced/" + file) as PhysicsObjectDefinition
		check(definition != null and definition.tool.advanced_action != null, file + " action loads")
		check(not VoxFile.read_cells(definition.vox_model).is_empty(), file + " VOX loads")
		var body := PhysicsProp.create(definition); scene.add_child(body); body.position = Vector3(0, 20, -2)
		var identity := body.get_instance_id()
		check(handler.equip(body), file + " equips")
		handler._equip_progress = 1
		handler.physics_update(1.0 / 60.0)
		check(handler.get_equipped_body().get_instance_id() == identity, file + " retains body identity")
		handler.drop(); body.queue_free(); count += 1
	check(count == 26, "26 new tools")
	var menu := SpawnMenu.new(); scene.add_child(menu)
	check(menu._entries.has("Tools"), "spawn menu discovers Tools")
	var wood: VoxelMaterialDefinition = load("res://props/voxel_materials/wood.tres")
	var profile: ToolMaterialProfile = wood.tool_profile
	check(profile != null and profile.saw_response > 0, "explicit material profiles")
	var a := voxel(Vector3(0, 3, 0), [Vector3i.ZERO, Vector3i(1, 0, 0)], wood)
	await process_frame
	var mass_before := a.mass
	var collider_ids: Array[int] = []
	for child in a.get_children(true):
		if child is CollisionShape3D: collider_ids.append(child.get_instance_id())
	VoxelToolSurface.apply(a, a.cell_to_world(Vector3i.ZERO) + Vector3.UP * 0.05, Vector3.UP, 0.02, "paint", 1, Color.RED)
	a._flush_dirty()
	check(a.mass == mass_before and a.health.is_empty(), "paint preserves health and mass")
	var preserved := true
	for id in collider_ids: preserved = preserved and is_instance_id_valid(id)
	check(preserved, "surface update retains collision shapes")
	var dose_results: Array[float] = []
	for frequency in [30, 60, 120]:
		var sample := voxel(Vector3(3, 3, 0), [Vector3i.ZERO], wood)
		for tick in frequency:
			VoxelToolSurface.damage(sample, Transform3D(Basis(), sample.cell_to_world(Vector3i.ZERO)), Vector3.ONE * 0.11, &"saw", 1.0 / frequency, 1.0)
		dose_results.append(sample.health.get(Vector3i.ZERO, wood.strength)); sample.queue_free()
	check(absf(dose_results[0] - dose_results[2]) < 0.0001, "30 / 60 / 120 Hz exposure agrees")
	var moving := prop(Vector3(0.19, 3, 0))
	var mount := AttachmentPoint.at(a, a.cell_to_world(Vector3i(1, 0, 0)), Vector3.ZERO)
	var joint: ConnectionDefinition = load("res://contraptions/config/glue.tres")
	var record := service.create(mount, AttachmentPoint.at(moving, mount.position()), joint)
	check(record != null, "adjacent compatible surfaces fasten")
	var repeated := service.create(AttachmentPoint.at(a, mount.position(), Vector3.ZERO), AttachmentPoint.at(moving, mount.position()), joint)
	check(repeated != null and service._pairs.size() == 1, "fasteners consolidate into one rigid joint")
	service.remove(repeated)
	check(a.get_collision_exceptions().has(moving), "removing one fastener retains collision exclusion")
	var mapping: Dictionary = {}
	a.cells_transferred.connect(func(_piece: VoxelBody, plan: Dictionary): mapping.merge(plan))
	a._detach([Vector3i(1, 0, 0)])
	check(record != null and record.a.body() != a and record.a.valid(), "connection follows detached mounting cell")
	check(service.assembly_mass(moving) > moving.mass, "assembly mass includes detached body")
	var detached: VoxelBody = record.a.body()
	detached._remove_cell(record.a.cell); detached._flush_dirty()
	check(not service.connections.has(record), "destroyed mounting cell removes connection")
	check(not moving.get_collision_exceptions().has(detached), "final connection restores collision behaviour")
	var recipient := voxel(Vector3(5, 3, 0), [Vector3i.ZERO], wood)
	recipient.freeze = true; recipient.anchors[Vector3i.ZERO] = true
	var source := voxel(Vector3(5.1, 3, 0), [Vector3i.ZERO], wood)
	VoxelToolSurface.apply(source, source.cell_to_world(Vector3i.ZERO) + Vector3.UP * 0.05, Vector3.UP, 0.02, "paint", 1, Color.BLUE)
	var fastened := prop(Vector3(5.2, 3, 0))
	var transfer := service.create(AttachmentPoint.at(source, source.cell_to_world(Vector3i.ZERO), Vector3.ZERO), AttachmentPoint.at(fastened, source.cell_to_world(Vector3i.ZERO)), joint)
	check(VoxelConstruction.cement(source, recipient) == 1, "existing cement path transfers cell")
	check(recipient.surface_state.has(Vector3i(1, 0, 0)) and transfer.a.body() == recipient, "cement transfers paint and connection endpoint")
	check(service.anchored(fastened), "world-anchored assembly cannot be carried")
	service.remove(transfer)
	var vacuum := PhysicsProp.create(load("res://props/tools/advanced/vacuum_cleaner.tres")); scene.add_child(vacuum); vacuum.position = Vector3(10, 3, 0)
	var debris := voxel(Vector3(10, 3, -0.2), [Vector3i.ZERO], wood)
	var original_id := debris.get_instance_id()
	check(ToolMatter.collect(service, vacuum, debris, vacuum.definition.tool.advanced_action), "vacuum collects eligible debris")
	check(service.assembly_mass(vacuum) > vacuum.mass and debris.get_meta(&"vacuum_stored", false), "stored cargo keeps mass and suspends cleanup")
	service.release_cargo(vacuum)
	check(debris.get_instance_id() == original_id and not debris.freeze and debris.visible, "vacuum releases original body")
	var plunger := PhysicsProp.create(load("res://props/advanced/plunger.tres")); scene.add_child(plunger); plunger.position = Vector3(12, 3, 0)
	var target := prop(Vector3(12.1, 3, 0))
	var suction := service.create(AttachmentPoint.at(plunger, target.position), AttachmentPoint.at(target, target.position), load("res://contraptions/config/suction.tres"))
	check(suction != null, "plunger suction attaches")
	service.detach_suction(plunger)
	check(not service.connections.has(suction), "grabbing/reloading can release suction")
	# A rope under gravity, followed by the authored fixed/moving pulley examples.
	var anchor := StaticBody3D.new(); scene.add_child(anchor); anchor.position = Vector3(-5, 4, 0)
	var load_body := prop(Vector3(-5, 2, 0)); load_body.mass = 1
	var rope := service.create(AttachmentPoint.at(anchor, anchor.position), AttachmentPoint.at(load_body, load_body.position), load("res://contraptions/config/rope.tres"), Vector3.UP, 2.0)
	check(rope != null, "rope created")
	for frame in 120: await physics_frame
	check(service.connections.has(rope) and load_body.position.distance_to(anchor.position) < 2.35, "rope holds ordinary hanging load for 120 physics ticks")
	print("MEASURE hanging distance=", load_body.position.distance_to(anchor.position), " tension_N=", rope.strand.tension if is_instance_valid(rope.strand) else -1)
	service.reset(); await process_frame
	check(service.connections.is_empty() and service.patches.is_empty() and service.projectiles.is_empty(), "reset clears runtime contraptions")
	# Existing bounds cache remains constant-time for a representative 64k body.
	var cells: Dictionary[Vector3i, int] = {}
	for x in 40:
		for y in 40:
			for z in 40: cells[Vector3i(x, y, z)] = 0
	var large := VoxelBody.create_piece(cells, {}, [wood], 0.05)
	var begin := Time.get_ticks_usec()
	for iteration in 1000: large.get_cell_bounds()
	print("MEASURE cached bounds, 64000 cells, 1000 reads_us=", Time.get_ticks_usec() - begin)
	check(large.get_cell_bounds().size == Vector3.ONE * 40, "large-body bounds cache retained")
	large.free()
	scene.queue_free(); await process_frame
	var lab := (load("res://contraptions/contraption_lab.tscn") as PackedScene).instantiate()
	root.add_child(lab); current_scene = lab
	await physics_frame; await physics_frame
	var lab_world := ContraptionWorld.find(lab)
	check(lab_world.connections.size() == 5, "lab creates fixed/moving pulley, spring and elastic examples")
	for frame in 180: await physics_frame
	var strand_count := 0
	for example in lab_world.connections:
		if example.strand != null:
			strand_count += 1
			print("MEASURE lab ", example.definition.display_name, " guides=", example.strand.guides.size(), " force_N=", example.strand.tension)
	check(strand_count == 4, "lab strands survive ordinary initial loads for 180 ticks")
	lab.queue_free(); await process_frame; await process_frame
	print("ADVANCED CHECKS: ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)

func voxel(position: Vector3, locations: Array, material: VoxelMaterialDefinition) -> VoxelBody:
	var cells: Dictionary[Vector3i, int] = {}
	for cell in locations: cells[cell] = 0
	var body := VoxelBody.create_piece(cells, {}, [material], 0.1)
	scene.add_child(body); body.position = position
	return body

func prop(position: Vector3) -> PhysicsProp:
	var definition := PhysicsObjectDefinition.new(); definition.size = Vector3.ONE * 0.08; definition.mass = 0.1
	definition.tool_profile = load("res://contraptions/materials/profiles/wood.tres")
	var body := PhysicsProp.create(definition); scene.add_child(body); body.position = position
	return body
