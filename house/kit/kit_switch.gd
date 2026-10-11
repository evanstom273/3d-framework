@tool
class_name KitSwitch
extends KitPiece
## A wall light switch. Its origin is on the wall surface at the middle of the
## plate, facing +Z. Pressing it (E or click) toggles every KitLight whose
## `circuit` matches; the rocker shows which way it is.

enum Finish { WHITE, BRASS, BLACK_NICKEL, CHROME }

@export var circuit: String = "":
	set(value):
		circuit = value
		queue_rebuild()
@export var on: bool = true:
	set(value):
		on = value
		_pose_rocker()
@export var finish: Finish = Finish.WHITE:
	set(value):
		finish = value
		queue_rebuild()
@export var label: String = "Light switch"

const PLATE := 0.086

static var _click: AudioStreamWAV

var _rocker: MeshInstance3D


func get_interaction_prompt() -> String:
	return "%s (%s)" % [label, "on" if on else "off"]


func can_interact() -> bool:
	return true


func allows_click_interaction() -> bool:
	return true


func interact(_actor: Node) -> void:
	toggle()


## Flips the switch and sets every light on its circuit to match.
func toggle() -> void:
	on = not on
	if not circuit.is_empty():
		for light in get_tree().get_nodes_in_group(KitLight.circuit_group(circuit)):
			if light is KitLight:
				light.on = on
	_play_click()


func _ready() -> void:
	super()
	if Engine.is_editor_hint() or circuit.is_empty():
		return
	# Lights start as the switch says.
	for light in get_tree().get_nodes_in_group(KitLight.circuit_group(circuit)):
		if light is KitLight:
			light.on = on


func _build(b: KitBuilder) -> void:
	var plate := _plate_material()
	var half := PLATE * 0.5
	b.box(Vector3(-half, -half, 0.0), Vector3(half, half, 0.006), plate)
	# A raised, slightly smaller face gives the plate a bevelled edge.
	b.box(Vector3(-half + 0.004, -half + 0.004, 0.006), Vector3(half - 0.004, half - 0.004, 0.009), plate)
	var screw := KitMaterials.metal(Color(0.7, 0.7, 0.68), 0.8)
	for y in [-0.03, 0.03]:
		b.bevel_box(Vector3(-0.0032, y - 0.0015, 0.009 - 0.0032), Vector3(0.0032, y + 0.0015, 0.009 + 0.0032), 0.0012, screw, false)
	# The rocker's recess.
	b.box(Vector3(-0.015, -0.025, 0.0085), Vector3(0.015, 0.025, 0.0095), KitMaterials.paint(Color(0.12, 0.12, 0.12)), false)
	var rocker := KitBuilder.new()
	rocker.box(Vector3(-0.013, -0.023, -0.004), Vector3(0.013, 0.023, 0.004), plate, false)
	_rocker = rocker.commit(self, null, "Rocker")
	_rocker.position = Vector3(0, 0, 0.011)
	_pose_rocker()


func _pose_rocker() -> void:
	if is_instance_valid(_rocker):
		# Top pressed in is "on", as on UK switches.
		_rocker.rotation_degrees.x = -9.0 if on else 9.0


func _plate_material() -> Material:
	match finish:
		Finish.BRASS:
			return KitMaterials.metal(Color(0.76, 0.6, 0.3), 0.85)
		Finish.BLACK_NICKEL:
			return KitMaterials.metal(Color(0.12, 0.12, 0.13), 0.8)
		Finish.CHROME:
			return KitMaterials.metal(Color(0.8, 0.81, 0.83), 0.95)
	return KitMaterials.gloss(Color(0.96, 0.96, 0.95))


func _play_click() -> void:
	if _click == null:
		var rate := 22050
		var samples := PackedByteArray()
		var count := int(rate * 0.035)
		samples.resize(count * 2)
		for i in count:
			var t := float(i) / rate
			# A sharp tick: a short decaying noise burst with a body thunk.
			var value := (randf() * 2.0 - 1.0) * exp(-t * 260.0) * 0.8 + sin(t * TAU * 1800.0) * exp(-t * 120.0) * 0.35
			samples.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32000.0))
		_click = AudioStreamWAV.new()
		_click.format = AudioStreamWAV.FORMAT_16_BITS
		_click.mix_rate = rate
		_click.data = samples
	var player := AudioStreamPlayer3D.new()
	player.stream = _click
	player.volume_db = -6.0
	player.unit_size = 2.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
