class_name CutterBehaviour
extends ToolBehaviour
## Continuous work where the crosshair meets a surface within reach: chainsaw
## (saw), angle grinder (grind), blowtorch (heat), shovel (dig, plus scooping) and
## the crowbar's pry mode. The damage region is oriented like the tool (a blade
## cuts a slot, a torch a patch) and centred on the contact, so cuts deepen as you
## hold on. Damage is batched at 20 Hz from exposure time, so frame rate doesn't
## change how fast things cut.

const STEP := 0.05
## Seconds of levering to force a locked or an unlocked door or window.
const LOCKED_PRY_SECONDS := 1.8
const UNLOCKED_PRY_SECONDS := 0.7

var _exposure: float = 0.0
var _pry_target: Node
var _pry_progress: float = 0.0
var _creak_timer: float = 0.0
var _target_id: int = 0
var _contact: Dictionary = {}


func _operation() -> String:
	if action.operation == "shovel":
		return "dig" if mode == 1 else ""
	return action.operation


func cycle_mode() -> bool:
	if action.operation != "shovel":
		return false
	mode = 1 - mode
	runtime.stop()
	runtime.say("Dig mode: breaks marked ground" if mode == 1 else "Scoop mode: carry loose things on the blade")
	return true


func is_working() -> bool:
	return runtime.held and not _operation().is_empty()


func detail() -> String:
	if action.operation == "shovel":
		return "Shovel · %s" % ("Dig" if mode == 1 else "Scoop")
	return action.verb


func hints() -> String:
	if action.operation == "shovel":
		return "[LMB] Toss load   [Q] Dig mode" if mode == 0 else "[Hold LMB] Dig   [Q] Scoop mode"
	return action.primary_hint


func press() -> void:
	if action.operation == "shovel" and mode == 0:
		_toss()


func release() -> void:
	_exposure = 0.0
	_pry_progress = 0.0
	_contact = {}


func tick(delta: float) -> void:
	_contact = {}
	var operation := _operation()
	if operation.is_empty() or not runtime.held:
		_exposure = 0.0
		return
	if runtime.aimed.is_empty():
		_exposure = 0.0
		return
	if not runtime.aimed_in_reach():
		runtime.say("Get closer", 0.5)
		_exposure = 0.0
		return
	var hit := runtime.aimed
	_contact = {"position": hit["position"], "normal": hit["normal"], "color": _surface_color(hit)}
	var id: int = hit["collider"].get_instance_id()
	if id != _target_id:
		# A new target starts fresh, so damage can't be banked on one and spent on another.
		_target_id = id
		_exposure = 0.0
	_exposure += delta
	if _exposure < STEP:
		return
	var exposure := _exposure
	_exposure = 0.0
	_apply(hit, operation, exposure)


func contact() -> Dictionary:
	return _contact


func _apply(hit: Dictionary, operation: String, exposure: float) -> void:
	var world := runtime.world
	world.reason = ""
	var collider: CollisionObject3D = hit["collider"]
	if operation == "pry":
		if _pry_open(hit, exposure):
			return
		if world.weaken(hit["position"], action.rate * exposure):
			# Leverage lifts the prised piece away from what it was fixed to.
			_nudge(collider, hit, hit["normal"], exposure)
		else:
			runtime.say("Nothing fastened here to pry", 0.6)
		return
	# Grinders also cut through nails, screws and welds at the contact.
	if operation == "grind":
		world.weaken(hit["position"], action.rate * exposure)
	var profile := ContraptionWorld.profile(collider, hit["position"], hit["normal"])
	var response := profile.response(operation) if profile != null else 0.0
	if response <= 0.0:
		runtime.say(_resist_message(operation), 0.8)
		return
	var voxel := collider as VoxelBody
	if voxel != null:
		var pose := Transform3D(_region_basis(operation), hit["position"] - hit["normal"] * voxel.voxel_size * 0.3)
		VoxelToolSurface.damage(voxel, pose, action.region_size, operation, exposure, action.rate)
	else:
		_nudge(collider, hit, -hit["normal"], exposure)
	if operation == "heat":
		ToolMatter.surface(world, hit, "heat", exposure * profile.heat_response, action.effect_color)


## Levering a door or window (anything with force_open()): it strains and creaks,
## then the lock gives with a crack and it swings open, undamaged. Returns false
## when the target isn't a door or window.
func _pry_open(hit: Dictionary, exposure: float) -> bool:
	var target := hit["collider"] as Node
	while target != null and not target.has_method("force_open"):
		target = target.get_parent()
	if target == null:
		return false
	if target != _pry_target:
		_pry_target = target
		_pry_progress = 0.0
		_creak_timer = 0.0
	if bool(target.get(&"_is_open")):
		runtime.say("Already open", 0.6)
		return true
	var locked: bool = target.call("is_locked")
	var needed := LOCKED_PRY_SECONDS if locked else UNLOCKED_PRY_SECONDS
	_pry_progress += exposure
	_creak_timer -= exposure
	if _creak_timer <= 0.0:
		_creak_timer = randf_range(0.35, 0.55)
		PrySounds.play_creak(runtime.body, hit["position"])
		ImpactFeedback.spawn(runtime.body.get_tree().current_scene, hit["position"], hit["normal"], PhysicsToolDefinition.ImpactType.BLUNT, 0.3, Color(0.62, 0.52, 0.4), ImpactFeedback.Sound.WOOD)
	runtime.say("%s… %d%%" % ["Forcing the lock" if locked else "Levering it open", roundi(minf(_pry_progress / needed, 1.0) * 100.0)], 0.3)
	if _pry_progress >= needed:
		if target.call("force_open"):
			PrySounds.play_crack(runtime.body, hit["position"])
			ImpactFeedback.spawn(runtime.body.get_tree().current_scene, hit["position"], hit["normal"], PhysicsToolDefinition.ImpactType.BLUNT, 1.0, Color(0.62, 0.52, 0.4), ImpactFeedback.Sound.WOOD)
			CameraShake.shake_at(runtime.body.get_tree(), hit["position"], 40.0)
			runtime.say("Forced open" if locked else "Prised open", 1.2)
			runtime.shot(1.0)
		_pry_progress = 0.0
	return true


## Blades and discs cut in the tool's own plane; torches and shovels face the surface.
func _region_basis(operation: String) -> Basis:
	if operation == "saw" or operation == "grind":
		return runtime.body.global_basis.orthonormalized()
	return runtime.aim_transform().basis.orthonormalized()


## Loose objects get pushed around by a running blade instead of being cut.
func _nudge(collider: CollisionObject3D, hit: Dictionary, direction: Vector3, exposure: float) -> void:
	var target := collider as RigidBody3D
	if target == null or target.freeze:
		return
	target.apply_impulse(direction * action.force * exposure, hit["position"] - target.global_position)


func _surface_color(hit: Dictionary) -> Color:
	var voxel := hit["collider"] as VoxelBody
	if voxel != null:
		var cell := voxel.world_to_cell(hit["position"] - hit["normal"] * voxel.voxel_size * 0.25)
		if voxel.cells.has(cell):
			return voxel.palette[voxel.cells[cell]].color
	return action.effect_color


func _resist_message(operation: String) -> String:
	match operation:
		"saw":
			return "Too hard for the chainsaw"
		"grind":
			return "The grinder can't cut this"
		"heat":
			return "This doesn't burn"
		"dig":
			return "Only marked ground can be dug"
	return "Nothing happens"


## Scoop mode: flick whatever is on the blade forwards and up.
func _toss() -> void:
	var tool := runtime.body as PhysicsProp
	if tool == null or not tool.has_method("get_contents"):
		return
	var load: Array = tool.get_contents()
	if load.is_empty():
		runtime.say("The blade is empty")
		return
	var aim := runtime.aim_transform()
	var throw := -aim.basis.z * 4.5 + Vector3.UP * 2.5
	for item: RigidBody3D in load:
		item.linear_velocity = throw
		item.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4))
	runtime.shot()
