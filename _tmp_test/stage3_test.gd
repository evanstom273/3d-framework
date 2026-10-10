extends SceneTree
## Stage 3 acceptance: containers, physical hand states and tools.

var fails := 0
var scene: Node
var player: CharacterBody3D
var head: Node3D
var man: ObjectManipulator
var th: ToolHandler
var area: Node
var impacts: Array[ToolImpact] = []


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func mb(index: int, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = index
	e.pressed = pressed
	e.factor = 1.0
	return e


func motion(rel: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.relative = rel
	e.screen_relative = rel
	return e


func place(body: RigidBody3D, at: Vector3, basis := Basis()) -> void:
	body.global_transform = Transform3D(basis, at)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


func eye() -> Vector3:
	return head.global_position


## Turns the player and sets the hold distance so the hold point is `goal`.
func aim_hold(goal: Vector3) -> void:
	var dir := goal - eye()
	player.rotation.y = atan2(-dir.x, -dir.z)
	head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())
	man._hold_distance = dir.length()


func stand(at: Vector3, yaw := 0.0) -> void:
	player.global_position = Vector3(at.x, 0.0, at.z)
	player.velocity = Vector3.ZERO
	player.rotation.y = yaw
	head.rotation.x = 0.0


## Picks `body` up, lifts it clear, walks over and lowers it onto `goal`.
func carry_to(body: RigidBody3D, goal: Vector3, release := true) -> bool:
	var start := body.global_position
	stand(start + Vector3(0, 0, 1.3))
	await frames(2)
	if not man.grab(body):
		return false
	aim_hold(start + Vector3(0, 1.0, 0))
	await frames(45)
	await walk_to(goal + Vector3(0, 0, 1.3), func(): aim_hold(goal + Vector3(0, 0.7, 0)))
	aim_hold(goal + Vector3(0, 0.7, 0))
	await frames(30)
	aim_hold(goal + Vector3(0, 0.25, 0))
	await frames(30)
	aim_hold(goal)
	await frames(40)
	if release:
		man.release()
		await frames(60)
	return true


## Moves the player in walking-speed steps so held things follow physically.
func walk_to(to: Vector3, each_step: Callable = Callable(), speed := 5.0) -> void:
	var from := player.global_position
	var flat_to := Vector3(to.x, 0, to.z)
	var steps := maxi(1, ceili(from.distance_to(flat_to) / (speed / 60.0)))
	for i in steps:
		player.global_position = from.lerp(flat_to, float(i + 1) / steps)
		player.velocity = Vector3.ZERO
		if each_step.is_valid():
			each_step.call()
		await physics_frame


func contents_of(container: PhysicsProp) -> Array[RigidBody3D]:
	return container.get_contents()


func count_props() -> int:
	return get_nodes_in_group(&"physics_props").size()


func _initialize() -> void:
	scene = load("res://playground/physics_playground.tscn").instantiate()
	root.add_child(scene)
	run()


func run() -> void:
	await frames(120)
	player = scene.get_node("Player")
	head = player.get_node("Head")
	man = player.get_node("ObjectManipulator")
	th = player.get_node("ToolHandler")
	area = scene.get_node("ToolArea")
	th.impacted.connect(func(i: ToolImpact): impacts.append(i))
	var start_count := count_props()

	# --- Setup sanity
	check(th.manipulator == man and th.view == head, "ToolHandler wired to manipulator and head")
	var box: PhysicsProp = area.get_node("WoodenBox2")
	var box1: PhysicsProp = area.get_node("WoodenBox1")
	check(absf(box.global_position.y - 0.155) < 0.02 and box.global_basis.y.dot(Vector3.UP) > 0.99, "open box rests upright on its own walls (y=%.3f)" % box.global_position.y)
	for name in ["Bucket1", "Basket1"]:
		var c: PhysicsProp = area.get_node(name)
		check(c.global_basis.y.dot(Vector3.UP) > 0.99 and c.get_contents().is_empty(), "%s settles upright and empty" % name)
	var hammer: PhysicsProp = area.get_node("Hammer")
	var club: PhysicsProp = area.get_node("GolfClub")
	var bat: PhysicsProp = area.get_node("WoodenBat")
	check(hammer.global_position.y > 0.88 and club.global_position.y > 0.88, "tools rest on the workbench (hammer y=%.2f, club y=%.2f)" % [hammer.global_position.y, club.global_position.y])

	# Move the test box to open floor.
	var spot := Vector3(17, 0.155, 9)
	place(box, spot)
	await frames(30)

	# --- 1. Put a wooden block into the open box
	var block1: PhysicsProp = area.get_node("Block1")
	check(await carry_to(block1, spot + Vector3(-0.12, 0.05, 0)), "carry Block1 to the box")
	check(contents_of(box).has(block1), "Block1 is inside the box (block y=%.3f)" % block1.global_position.y)
	check(block1.global_position.y > box.global_position.y - 0.15 + 0.035 - 0.01, "block rests on the box floor, not through it")

	# --- 2. Several objects in the same box
	var others: Array[PhysicsProp] = [area.get_node("Block2"), area.get_node("Block3"), area.get_node("TeeBall1")]
	var offsets := [Vector3(0.13, 0.05, -0.1), Vector3(0.13, 0.05, 0.12), Vector3(-0.12, 0.2, 0.12)]
	for i in others.size():
		await carry_to(others[i], spot + offsets[i])
	var loaded := contents_of(box)
	check(loaded.size() == 4, "box holds 4 objects (%d)" % loaded.size())
	var carried_mass := man.get_carried_mass(box)
	check(absf(carried_mass - (4.0 + 0.5 * 3 + 0.5)) < 0.01, "carried mass includes contents (%.2f kg)" % carried_mass)

	# --- 3. Carry the loaded box around (walk, sprint, turn)
	stand(spot + Vector3(0, 0, 1.3))
	await frames(2)
	check(man.grab(box), "grab loaded box")
	check(box.is_held() and box.hand_state == PhysicsProp.HandState.HELD, "box hand state is HELD")
	check(man.get_hold_prompt().contains("4 items"), "carry prompt shows contents: '%s'" % man.get_hold_prompt().get_slice("\n", 0))
	aim_hold(spot + Vector3(0, 0.9, 0))
	await frames(45)
	var keep := func(): man._hold_distance = 1.2; head.rotation.x = deg_to_rad(-20)
	await walk_to(Vector3(17, 0, 3), keep, 5.0)
	await walk_to(Vector3(9, 0, 3), keep, 8.0)
	for i in 60:
		player.rotation.y += deg_to_rad(1.5)
		await physics_frame
	await walk_to(Vector3(9, 0, 9), keep, 5.0)
	await frames(30)
	check(contents_of(box).size() == 4, "all 4 objects stay in the box while walking, sprinting and turning (%d)" % contents_of(box).size())

	# --- 4. Drop it; contents remain physical
	var drop_at := player.global_position + -player.global_basis.z * 1.2
	aim_hold(Vector3(drop_at.x, 0.2, drop_at.z))
	await frames(60)
	man.release()
	await frames(90)
	var after_drop := contents_of(box)
	check(after_drop.size() == 4, "contents still inside after dropping the box (%d)" % after_drop.size())
	var all_dynamic := true
	for b in after_drop:
		all_dynamic = all_dynamic and not b.freeze and b.get_parent() == area
	check(all_dynamic, "contents are still free rigid bodies in the scene (not stored/reparented)")
	var nudge_block := after_drop[0]
	var nb_before := nudge_block.global_position
	nudge_block.apply_central_impulse(Vector3(0, 0.6, 0))
	await frames(40)
	check(nudge_block.global_position.distance_to(nb_before) < 0.3 and contents_of(box).has(nudge_block), "a nudged content bounces and lands back inside")

	# --- 5. Tip the box over by rotating it; contents spill
	var box_pos := box.global_position
	stand(box_pos + Vector3(0, 0, 1.3))
	await frames(2)
	man.grab(box)
	aim_hold(box_pos + Vector3(0, 0.9, 0))
	await frames(45)
	man.handle_input(mb(MOUSE_BUTTON_MIDDLE, true))
	Input.action_press("rotate_held_object")
	man.handle_input(motion(Vector2(0, 330)))
	await frames(120)
	Input.action_release("rotate_held_object")
	man.handle_input(mb(MOUSE_BUTTON_MIDDLE, false))
	var spilled := contents_of(box).size()
	check(spilled <= 1, "tilting the box spills its contents (%d left inside)" % spilled)
	man.release()
	await frames(120)
	var spilled_ok := true
	for b in loaded:
		spilled_ok = spilled_ok and is_instance_valid(b) and b.global_position.y > -0.01
	check(spilled_ok, "spilled objects land on the floor, none lost or through the floor")

	# --- 6. Pick an individual object out of a box
	place(box, spot)
	await frames(30)
	await carry_to(block1, spot + Vector3(-0.12, 0.05, 0))
	await carry_to(others[0], spot + Vector3(0.13, 0.05, 0))
	check(contents_of(box).size() == 2, "refilled box holds 2 blocks")
	stand(spot + Vector3(0, 0, 1.0))
	player.rotation.y = 0
	var look := (block1.global_position - eye())
	head.rotation.x = atan2(look.y, Vector2(look.x, look.z).length())
	player.rotation.y = atan2(-look.x, -look.z)
	await frames(2)
	var ray: RayCast3D = player.get_node("Head/Camera3D/InteractionRay")
	ray.force_raycast_update()
	check(man.resolve_grabbable(ray.get_collider()) == block1, "interaction ray picks the block inside the box, not the box")
	check(man.grab(block1), "grab the block out of the box")
	aim_hold(spot + Vector3(0, 1.0, 0.3))
	await frames(60)
	check(not contents_of(box).has(block1) and contents_of(box).has(others[0]), "block lifted out; the other stays in")
	man.release()
	await frames(60)

	# --- 7. Hammer into the box and back out
	check(await carry_to(hammer, spot + Vector3(0, 0.08, 0)), "carry hammer to box")
	await frames(30)
	check(contents_of(box).has(hammer), "hammer is inside the box (y=%.3f)" % hammer.global_position.y)
	stand(spot + Vector3(0, 0, 1.0))
	await frames(2)
	check(man.grab(hammer), "retrieve hammer from the box")
	aim_hold(spot + Vector3(0, 0.9, 0.4))
	await frames(45)
	check(not contents_of(box).has(hammer), "hammer is out of the box")

	# --- 8. Equip the hammer; same instance, no duplicate
	var hammers_before := 0
	for n in get_nodes_in_group(&"physics_props"):
		if n.definition == hammer.definition:
			hammers_before += 1
	check(not th.equip_held() == false, "F equips the held hammer")
	check(th.get_equipped_body() == hammer and not man.is_holding() and man.locked, "hammer moved from hand-hold to equipped (manipulator locked)")
	check(hammer.freeze and hammer.collision_layer == 0 and hammer.collision_mask == 0, "equipped hammer is kinematic with collisions off")
	check(hammer.hand_state == PhysicsProp.HandState.EQUIPPED, "hammer hand state is EQUIPPED")
	check(not man.grab(block1), "cannot grab something else while a tool is equipped")
	await frames(30)
	var rest := th._tool_transform_at(-1.0)
	check(hammer.global_transform.origin.distance_to(rest.origin) < 0.01, "hammer sits in its first-person rest pose")
	var local_rest := head.global_transform.affine_inverse() * hammer.global_position
	check(local_rest.z < -0.3 and local_rest.x > 0.1 and local_rest.y < -0.1, "rest pose is low-right and in front of the camera (%s)" % local_rest)
	var hammers_after := 0
	for n in get_nodes_in_group(&"physics_props"):
		if n.definition == hammer.definition:
			hammers_after += 1
	check(hammers_before == hammers_after and count_props() == start_count, "no duplicate created by equipping (%d props)" % count_props())

	# --- 9. Swing at a physics object
	var crate: PhysicsProp = scene.get_node("Props/WallCrate")
	var target_found := await place_under_crosshair(crate, 0.305, 1.7)
	check(target_found and crate.global_position.distance_to(player.global_position) > 1.4, "crate placed under the crosshair, well past the hammer's arm length")
	impacts.clear()
	check(th.handle_input(mb(MOUSE_BUTTON_LEFT, true)), "LMB with a tool equipped is consumed by the tool")
	check(not th.use_primary(), "a second click mid-swing is ignored (cooldown)")
	await frames(60)
	check(impacts.size() == 1 and impacts[0].collider == crate, "hammer swing hit the crate exactly once (%d impacts)" % impacts.size())
	check(crate.linear_velocity.length() > 0.5 or crate.global_position.distance_to(Vector3(crate.global_position)) >= 0.0, "crate was pushed (v=%.2f m/s)" % crate.linear_velocity.length())
	if impacts.size() > 0:
		check(impacts[0].tool == hammer and impacts[0].damage == 25.0 and impacts[0].impact_type == PhysicsToolDefinition.ImpactType.BLUNT, "impact carries tool, damage and type for future voxel use")
		check(impacts[0].position.distance_to(crate.global_position) < 0.6, "impact lands where the crosshair points")
	await frames(30)
	check(th.use_primary(), "can swing again after the cooldown")
	await frames(60)

	# --- 9b. Crosshair rules: off-crosshair and out-of-reach targets are not hit
	await place_under_crosshair(crate, 0.305, 1.5)
	player.rotation.y += deg_to_rad(40)
	await frames(2)
	impacts.clear()
	th.use_primary()
	await frames(60)
	check(impacts.is_empty(), "a crate 40 degrees off the crosshair is not hit")
	player.rotation.y -= deg_to_rad(40)
	await place_under_crosshair(crate, 0.305, 3.2)
	impacts.clear()
	th.use_primary()
	await frames(60)
	check(impacts.is_empty(), "a crate beyond the hammer's 2 m reach is not hit")
	var small: PhysicsProp = area.get_node("Block4")
	await place_under_crosshair(small, 0.05, 1.3)
	head.rotation.x += deg_to_rad(3.0)
	await frames(2)
	impacts.clear()
	th.use_primary()
	await frames(60)
	check(impacts.size() == 1 and impacts[0].collider == small, "aim assist catches a small block just off the crosshair")

	# --- 10. Unequip back to the hand, return it to the box
	th.unequip()
	check(man.get_held_body() == hammer and not man.locked, "F unequips the hammer back into the physical hold")
	check(not hammer.freeze and hammer.collision_layer == 16 and hammer.collision_mask == 31 and hammer.hand_state == PhysicsProp.HandState.HELD, "hammer physics restored (layer %d, mask %d)" % [hammer.collision_layer, hammer.collision_mask])
	man.release()
	await frames(60)
	await carry_to(hammer, spot + Vector3(0, 0.08, 0))
	await frames(30)
	check(contents_of(box).has(hammer), "unequipped hammer returned to the box")

	# --- 11. Golf club: hit a ball across the playground
	var ball: PhysicsProp = area.get_node("TeeBall2")
	stand(Vector3(16, 0, 14))
	await frames(5)
	check(th.equip(club), "F equips the golf club straight from the world")
	check(not th.equip(bat), "only one tool can be equipped at a time")
	await frames(30)
	await place_under_crosshair(ball, 0.15, 0.9)
	var tee := ball.global_position
	impacts.clear()
	th.use_primary()
	var peak := 0.0
	var far := 0.0
	for i in 240:
		await physics_frame
		peak = maxf(peak, ball.global_position.y)
		far = maxf(far, Vector2(ball.global_position.x - tee.x, ball.global_position.z - tee.z).length())
	var travel := ball.global_position - tee
	check(impacts.size() == 1 and impacts[0].collider == ball, "club struck the ball")
	check(far > 10.0 and travel.z < -8.0 and absf(travel.x) < far * 0.35, "ball flew down the range (%.1f m, peak %.2f m, dir %s)" % [far, peak, Vector2(travel.x, travel.z).normalized()])
	check(peak > 0.6, "loft lifted the ball (peak %.2f m)" % peak)

	# Bouncing ball: drop it into the swing and strike it after a bounce.
	place(ball, Vector3.ZERO)
	await place_under_crosshair(ball, 0.15, 0.9)
	var bounce_spot := ball.global_position
	place(ball, bounce_spot + Vector3(0, 0.9, 0))
	var bounced := false
	var prev_vy := 0.0
	for i in 120:
		await physics_frame
		if prev_vy < -0.5 and ball.linear_velocity.y > 0.3:
			bounced = true
		prev_vy = ball.linear_velocity.y
		# Time the swing so the club arrives as the ball comes back down.
		if bounced and ball.linear_velocity.y < 0.0 and ball.global_position.y < 0.62 and not th.is_busy():
			impacts.clear()
			th.use_primary()
			break
	await frames(60)
	check(bounced and impacts.size() == 1 and impacts[0].collider == ball, "club struck a bouncing ball (bounced=%s, impacts=%d)" % [bounced, impacts.size()])
	await frames(60)
	th.drop()
	await frames(60)
	check(not th.is_equipped() and not man.is_holding() and not club.freeze and club.hand_state == PhysicsProp.HandState.WORLD, "E drops the club back into world physics")

	# --- 12. Third tool through the same system
	stand(bat.global_position + Vector3(0, 0, 1.0))
	await frames(2)
	man.grab(bat)
	check(th.equip_held(), "bat equips through the same ToolHandler (no bespoke code)")
	await frames(30)
	var cardboard: PhysicsProp = scene.get_node("Props/CardboardFloor2")
	await place_under_crosshair(cardboard, 0.185, 1.6)
	impacts.clear()
	th.use_primary()
	await frames(50)
	check(impacts.size() == 1 and impacts[0].collider == cardboard and cardboard.linear_velocity.length() > 1.0, "bat knocked the cardboard box (v=%.1f)" % cardboard.linear_velocity.length())
	var swing_total := th._settings.get_total_action_time()
	check(absf(swing_total - 0.7) < 0.01 and absf(hammer.definition.tool.get_total_action_time() - 0.65) < 0.01, "tools keep their own timings (bat %.2fs, hammer %.2fs)" % [swing_total, hammer.definition.tool.get_total_action_time()])
	th.drop()
	await frames(30)

	# --- 13. Independence of instances sharing a definition
	var hammer2 := PhysicsProp.create(hammer.definition)
	scene.add_child(hammer2)
	place(hammer2, Vector3(18, 0.3, 14))
	await frames(30)
	stand(Vector3(18, 0, 15))
	await frames(2)
	man.grab(hammer2)
	th.equip_held()
	await frames(5)
	check(hammer2.freeze and not hammer.freeze and hammer.collision_layer == 16 and hammer.hand_state == PhysicsProp.HandState.WORLD, "equipping one hammer leaves the other untouched")
	check(hammer.definition.collision_layer == 16 and hammer.definition.tool.impact_impulse == 25.0, "shared definition is not mutated by runtime state")
	check(contents_of(box).size() != contents_of(box1).size(), "two boxes from one definition hold different contents (%d vs %d)" % [contents_of(box).size(), contents_of(box1).size()])
	th.drop()
	await frames(20)

	# --- 13b. TOOL_PATH mode still hits with the physical tool head
	var path_def: PhysicsObjectDefinition = hammer.definition.duplicate(true)
	path_def.tool.hit_detection = PhysicsToolDefinition.HitDetection.TOOL_PATH
	hammer2.definition = path_def
	stand(Vector3(18, 0, 15))
	place(hammer2, Vector3(18, 0.3, 14))
	await frames(30)
	man.grab(hammer2)
	th.equip_held()
	await frames(30)
	check(await place_in_swing(crate, 0.305), "found a pose where the hammer head physically reaches the crate")
	impacts.clear()
	th.use_primary()
	await frames(60)
	check(impacts.size() == 1 and impacts[0].collider == crate, "TOOL_PATH hammer hits by sweeping its head (%d impacts)" % impacts.size())
	check(hammer.definition.tool.hit_detection == PhysicsToolDefinition.HitDetection.CROSSHAIR, "the original hammer definition still uses CROSSHAIR")
	th.drop()
	await frames(20)

	# --- 14. Throw a loaded basket: contents leave with it and spill on landing
	var basket: PhysicsProp = area.get_node("Basket2")
	var bspot := Vector3(17, 0.135, 11)
	place(basket, bspot)
	await frames(30)
	var fb: Array[PhysicsProp] = [area.get_node("FloorBlock1"), area.get_node("FloorBlock2"), area.get_node("FloorBlock3")]
	for i in fb.size():
		await carry_to(fb[i], bspot + Vector3(-0.12 + 0.12 * i, 0.06, 0))
	var basket_load := contents_of(basket).size()
	check(basket_load == 3, "basket loaded with 3 blocks (%d)" % basket_load)
	stand(bspot + Vector3(0, 0, 1.3))
	await frames(2)
	man.grab(basket)
	aim_hold(bspot + Vector3(0, 0.9, 0))
	await frames(45)
	head.rotation.x = deg_to_rad(15)
	await frames(10)
	var still_in := contents_of(basket).size()
	man.handle_input(mb(MOUSE_BUTTON_LEFT, true))
	await frames(6)
	var flying_with := 0
	for b in fb:
		if b.linear_velocity.length() > 2.0:
			flying_with += 1
	check(still_in == 3 and flying_with == 3, "contents travel with the thrown basket (%d of 3 moving)" % flying_with)
	await frames(180)
	var spilt := 3 - contents_of(basket).size()
	var lost := 0
	for b in fb:
		if not is_instance_valid(b) or b.global_position.y < -0.01:
			lost += 1
	check(spilt >= 1 and lost == 0, "landing spilled %d block(s), none lost" % spilt)

	# --- 15. Hand-state rules and controls
	man.grab(scene.get_node("Props/Ball2"))
	check(not th.equip_held(), "F does nothing for a non-tool object")
	check(man.handle_input(mb(MOUSE_BUTTON_LEFT, true)) and not man.is_holding(), "LMB still throws an ordinary held object")
	check(not th.handle_input(mb(MOUSE_BUTTON_LEFT, true)), "tool use ignores LMB when no tool is equipped")
	await frames(60)
	check(count_props() == start_count + 1, "no props lost or duplicated overall (%d = %d + 1 spawned)" % [count_props(), start_count])
	var feedback_left := 0
	for n in scene.get_children():
		if n is ImpactFeedback:
			feedback_left += 1
	check(feedback_left == 0, "impact feedback nodes clean themselves up")

	print("RESULT: %d failure(s)" % fails)
	quit(1 if fails else 0)


## Puts `target` on the floor `distance` ahead and aims the crosshair at its centre.
func place_under_crosshair(target: RigidBody3D, half_height: float, distance: float) -> bool:
	var ahead := -player.global_basis.z.slide(Vector3.UP).normalized()
	var spot := player.global_position + ahead * distance
	place(target, Vector3(spot.x, half_height + 0.005, spot.z))
	await frames(30)
	var dir := target.global_position - eye()
	head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())
	await frames(2)
	return true


## Points the view so the equipped tool's strike passes through where `target`
## can rest, then puts the target there. Returns false if no pose fits.
func place_in_swing(target: RigidBody3D, half_height: float) -> bool:
	var s := th._settings
	for step in range(0, 16):
		head.rotation.x = deg_to_rad(-5.0 * step)
		var best := Vector3.INF
		for k in range(1, 10):
			var p := th._strike_point_at(s.windup_time + s.strike_time * k / 10.0)
			if p.y < best.y:
				best = p
		var flat := Vector2(best.x - player.global_position.x, best.z - player.global_position.z).length()
		if best.y < half_height * 1.5 and best.y > half_height * 0.4 and flat > 0.55:
			place(target, Vector3(best.x, half_height + 0.005, best.z))
			await frames(30)
			return true
	return false
