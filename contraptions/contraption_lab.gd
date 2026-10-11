extends Node3D
## The furniture and tool layout is authored; only example constraints are runtime state.
func _ready() -> void:
	PhysicsFeel.set_active(load("res://physics/feel/playful.tres"))
	add_child(SpawnMenu.new())
	_setup.call_deferred()

func _setup() -> void:
	var world := ContraptionWorld.find(self, true)
	var rope: ConnectionDefinition = load("res://contraptions/config/rope.tres")
	var fixed: PhysicsProp = $FixedPulley
	fixed.freeze = true
	var guide := AttachmentPoint.at(fixed, fixed.to_global(Vector3(0, 0.12, 0)))
	world.create(AttachmentPoint.at($Bucket, $Bucket.global_position + Vector3.UP * 0.2), AttachmentPoint.at($Counterweight, $Counterweight.global_position + Vector3.UP * 0.2), rope, Vector3.UP, 3.5, [guide])
	var moving: PhysicsProp = $MovingPulley
	var joint: ConnectionDefinition = load("res://contraptions/config/glue.tres")
	# Place the load against the movable bracket before fastening its real surfaces.
	$MovingLoad.global_position = moving.global_position + Vector3(0, -0.22, 0)
	var point := moving.global_position + Vector3(0, -0.05, 0)
	world.create(AttachmentPoint.at(moving, point), AttachmentPoint.at($MovingLoad, point), joint)
	var start := AttachmentPoint.at($Overhead, Vector3(1, 3.65, -7), Vector3.DOWN)
	var end := AttachmentPoint.at($HoistCounterweight, $HoistCounterweight.global_position)
	world.create(start, end, rope, Vector3.UP, 5.2, [AttachmentPoint.at(moving, moving.to_global(Vector3(0, 0.12, 0)))])
	for name_text in ["SpringLoad", "ElasticLoad"]:
		var body: RigidBody3D = get_node(name_text)
		var profile: ConnectionDefinition = load("res://contraptions/config/spring.tres" if name_text == "SpringLoad" else "res://contraptions/config/elastic.tres")
		world.create(AttachmentPoint.at($Overhead, Vector3(body.position.x, 3.65, -7), Vector3.DOWN), AttachmentPoint.at(body, body.global_position), profile, Vector3.UP, 1.1)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_playground"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
