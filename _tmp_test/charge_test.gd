extends SceneTree
## Chargeable throws and strikes.

var fails := 0
var scene: Node
var player: CharacterBody3D
var head: Node3D
var man: ObjectManipulator
var th: ToolHandler
var impacts: Array[ToolImpact] = []


func check(ok: bool, label: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await physics_frame


func mb(pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e


func place(body: RigidBody3D, at: Vector3) -> void:
	body.global_transform = Transform3D(Basis(), at)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO


## Grabs `body` in front of the player at chest height, then throws after holding LMB.
func throw_after(body: RigidBody3D, hold_seconds: float) -> float:
	place(body, Vector3(16, 0.3, 8))
	player.global_position = Vector3(16, 0, 9.3)
	player.rotation.y = 0
	head.rotation.x = deg_to_rad(-20)
	await frames(20)
	man.grab(body)
	head.rotation.x = 0
	await frames(40)
	man.handle_input(mb(true))
	Input.action_press("throw_held_object")
	await frames(roundi(hold_seconds * 60.0))
	Input.action_release("throw_held_object")
	man.handle_input(mb(false))
	var speed := body.linear_velocity.length()
	await frames(60)
	return speed


## Aims at `target` resting `distance` ahead and strikes after holding LMB.
func strike_after(target: RigidBody3D, half_height: float, distance: float, hold_seconds: float) -> ToolImpact:
	player.global_position = Vector3(16, 0, 12)
	player.rotation.y = 0
	place(target, Vector3(16, half_height + 0.005, 12 - distance))
	await frames(40)
	var dir := target.global_position - head.global_position
	head.rotation.x = atan2(dir.y, Vector2(dir.x, dir.z).length())
	await frames(2)
	impacts.clear()
	th.handle_input(mb(true))
	Input.action_press("use_tool")
	await frames(roundi(hold_seconds * 60.0))
	Input.action_release("use_tool")
	th.handle_input(mb(false))
	await frames(45)
	return impacts[0] if impacts.size() == 1 else null


func _initialize() -> void:
	scene = load("res://playground/physics_playground.tscn").instantiate()
	root.add_child(scene)
	run()


func run() -> void:
	await frames(90)
	player = scene.get_node("Player")
	head = player.get_node("Head")
	man = player.get_node("ObjectManipulator")
	th = player.get_node("ToolHandler")
	th.impacted.connect(func(i: ToolImpact): impacts.append(i))
	var bar: ProgressBar = player.get_node("HUD/ChargeBar")
	var card: PhysicsProp = scene.get_node("Props/CardboardFloor1")

	# --- Throws
	var tap := await throw_after(card, 0.0)
	var half := await throw_after(card, 0.4)
	var full := await throw_after(card, 1.2)
	check(absf(tap - 16.0 * 0.3) < 0.6, "tap throw is weak (%.1f m/s, expect ~4.8)" % tap)
	check(absf(half - 16.0 * lerpf(0.3, 1.0, 0.5)) < 1.2, "half-charged throw is in between (%.1f m/s, expect ~10.4)" % half)
	check(absf(full - 16.0) < 0.6, "fully charged throw is the configured maximum (%.1f m/s)" % full)

	# Charging state, bar and pull-back.
	place(card, Vector3(16, 0.3, 8))
	player.global_position = Vector3(16, 0, 9.3)
	head.rotation.x = deg_to_rad(-20)
	await frames(20)
	man.grab(card)
	head.rotation.x = 0
	await frames(40)
	var rest_distance := head.global_position.distance_to(card.global_position)
	check(not bar.visible, "charge bar hidden when not charging")
	man.handle_input(mb(true))
	Input.action_press("throw_held_object")
	await frames(24)
	check(bar.visible and absf(bar.value - 0.5) < 0.06 and man.is_holding(), "charge bar shows ~50%% after 0.4 s and the object is still held (%.2f)" % bar.value)
	await frames(60)
	check(bar.value >= 1.0 and bar.modulate.g < 0.7, "bar caps at full and turns orange")
	var pulled := head.global_position.distance_to(card.global_position)
	check(rest_distance - pulled > 0.15, "held object draws back while charging (%.2f m)" % (rest_distance - pulled))
	Input.action_release("throw_held_object")
	await frames(2)
	check(not man.is_holding() and card.linear_velocity.length() > 14.0, "releasing the button (even without the release event) throws at full charge")
	await frames(30)
	check(not bar.visible, "bar hides after the throw")

	# Max power above 1.
	man.max_throw_power = 1.5
	var boosted := await throw_after(card, 1.2)
	check(absf(boosted - 24.0) < 0.8, "max_throw_power 1.5 gives a stronger full throw (%.1f m/s)" % boosted)
	man.max_throw_power = 1.0

	# --- Tool strikes
	var hammer: PhysicsProp = scene.get_node("ToolArea/Hammer")
	player.global_position = hammer.global_position + Vector3(0, -hammer.global_position.y, 1.0)
	await frames(2)
	th.equip(hammer)
	await frames(30)
	var crate: PhysicsProp = scene.get_node("Props/WallCrate")
	var weak := await strike_after(crate, 0.305, 1.5, 0.0)
	var weak_speed := crate.linear_velocity.length()
	var strong := await strike_after(crate, 0.305, 1.5, 0.8)
	check(weak != null and strong != null, "both tap and charged hammer swings hit")
	if weak != null and strong != null:
		check(absf(weak.power - 0.3) < 0.01 and absf(strong.power - 1.0) < 0.01, "impact power: tap %.2f, full %.2f" % [weak.power, strong.power])
		check(absf(strong.impulse.length() - 25.0) < 0.1 and absf(weak.impulse.length() - 7.5) < 0.1, "impulse scales with power (%.1f vs %.1f N·s)" % [weak.impulse.length(), strong.impulse.length()])
		check(absf(strong.damage - 25.0) < 0.01 and absf(weak.damage - 7.5) < 0.01, "damage scales with power for future voxel use")

	# Windup is held while charging, and nothing is hit until release.
	place(crate, Vector3(16, 0.31, 10.5))
	await frames(30)
	impacts.clear()
	th.handle_input(mb(true))
	Input.action_press("use_tool")
	await frames(60)
	var windup := th._tool_transform_at(th._settings.windup_time)
	check(hammer.global_position.distance_to(windup.origin) < 0.01 and impacts.is_empty(), "hammer holds its windup pose while charging, no hit yet")
	check(not th.begin_charge(), "pressing again mid-charge does nothing")
	Input.action_release("use_tool")
	th.handle_input(mb(false))
	await frames(45)
	check(impacts.size() == 1, "strike lands after release")
	th.drop()
	await frames(30)

	# Golf: tap vs full drive distance.
	var club: PhysicsProp = scene.get_node("ToolArea/GolfClub")
	var ball: PhysicsProp = scene.get_node("ToolArea/TeeBall3")
	player.global_position = club.global_position + Vector3(0, -club.global_position.y, 1.0)
	await frames(2)
	th.equip(club)
	await frames(30)
	var distances: Array[float] = []
	for hold in [0.0, 1.2]:
		await frames(60)
		var hit := await strike_after(ball, 0.15, 0.9, hold)
		print("  golf hold %.1fs: impact=%s power=%s impulse=%s ball v=%.1f" % [hold, hit != null, hit.power if hit else -1.0, hit.impulse.length() if hit else -1.0, ball.linear_velocity.length()])
		var tee := Vector3(16, 0, 11.1)
		var far := 0.0
		for i in 180:
			await physics_frame
			far = maxf(far, Vector2(ball.global_position.x - tee.x, ball.global_position.z - tee.z).length())
		distances.append(far)
	check(distances[1] > distances[0] * 2.0 and distances[1] > 10.0, "full-charge drive goes much further than a tap (%.1f m vs %.1f m)" % [distances[1], distances[0]])
	th.drop()

	print("RESULT: %d failure(s)" % fails)
	quit(1 if fails else 0)
