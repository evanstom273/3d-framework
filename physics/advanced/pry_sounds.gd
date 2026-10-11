class_name PrySounds
extends RefCounted
## Synthesised sounds for levering things open with a crowbar: a strained
## wood-and-metal creak while working, and a sharp crack when the lock gives.

const RATE := 22050

static var _creak: AudioStreamWAV
static var _crack: AudioStreamWAV


static func play_creak(at: Node3D, position: Vector3) -> void:
	if _creak == null:
		_creak = _make_creak()
	_play(at, position, _creak, -2.0, randf_range(0.8, 1.2))


static func play_crack(at: Node3D, position: Vector3) -> void:
	if _crack == null:
		_crack = _make_crack()
	_play(at, position, _crack, 2.0, randf_range(0.92, 1.08))


static func _play(at: Node3D, position: Vector3, stream: AudioStream, volume: float, pitch: float) -> void:
	var player := AudioStreamPlayer3D.new()
	player.bus = &"Tools"
	player.stream = stream
	player.volume_db = volume
	player.pitch_scale = pitch
	player.unit_size = 4.0
	player.max_distance = 40.0
	var scene := at.get_tree().current_scene
	if scene != null:
		scene.add_child(player)
	else:
		at.add_child(player)
	player.global_position = position
	player.play()
	player.finished.connect(player.queue_free)


## A slow groan: a buzzy tone that bends in pitch, with stick-slip judder.
static func _make_creak() -> AudioStreamWAV:
	var length := 0.55
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var envelope := sin(PI * t / length) * (0.75 + 0.25 * sin(t * 37.0))
		var pitch := 140.0 + 70.0 * sin(t * 5.3) + 40.0 * t
		phase += pitch / RATE
		# Stick-slip: the tone stutters on and off like fibres catching.
		var judder := 0.55 + 0.45 * signf(sin(t * TAU * 23.0))
		var tone := (fmod(phase, 1.0) * 2.0 - 1.0) * 0.6 + sin(phase * TAU * 2.0) * 0.25
		var grit := (randf() * 2.0 - 1.0) * 0.18
		data.encode_s16(i * 2, int(clampf((tone * judder + grit) * envelope * 0.7, -1.0, 1.0) * 30000.0))
	return _wav(data)


## Splintering crack: a hard noise transient, a thump, and a short metallic ring.
static func _make_crack() -> AudioStreamWAV:
	var length := 0.5
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var snap := (randf() * 2.0 - 1.0) * exp(-t * 38.0)
		var thump := sin(t * TAU * 85.0) * exp(-t * 14.0) * 0.8
		var ring := sin(t * TAU * 1350.0) * exp(-t * 9.0) * 0.22
		data.encode_s16(i * 2, int(clampf(snap + thump + ring, -1.0, 1.0) * 30000.0))
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
