class_name ImpactFeedback
extends Node3D
## Short-lived particle burst and procedural knock sound at an impact point.
## Sounds are synthesised once per sound family, so no audio assets are needed.
## At most MAX_LIVE effects exist at once, so chain reactions stay cheap.

## What the struck thing sounds like. Set on materials and object definitions.
enum Sound { GENERIC, WOOD, METAL, STONE, PLASTIC, RUBBER, CARDBOARD, GLASS }

const LIFETIME := 0.6
const SAMPLE_RATE := 22050
const MAX_LIVE := 16

## Tone (Hz), length (s), noise mix, ring (second partial strength) per family.
const SOUND_RECIPES := {
	Sound.GENERIC: [130.0, 0.16, 0.55, 0.0],
	Sound.WOOD: [210.0, 0.13, 0.35, 0.25],
	Sound.METAL: [820.0, 0.38, 0.12, 0.6],
	Sound.STONE: [110.0, 0.15, 0.7, 0.0],
	Sound.PLASTIC: [480.0, 0.09, 0.3, 0.15],
	Sound.RUBBER: [150.0, 0.11, 0.15, 0.0],
	Sound.CARDBOARD: [170.0, 0.08, 0.8, 0.0],
	Sound.GLASS: [2300.0, 0.3, 0.45, 0.5],
}
## Tool impact types map onto families when the target has no sound of its own.
const TYPE_SOUNDS := {
	PhysicsToolDefinition.ImpactType.BLUNT: Sound.GENERIC,
	PhysicsToolDefinition.ImpactType.SWEEP: Sound.PLASTIC,
	PhysicsToolDefinition.ImpactType.SHARP: Sound.METAL,
	PhysicsToolDefinition.ImpactType.PIERCE: Sound.STONE,
}

static var _sounds: Dictionary = {}
static var _live: int = 0


## `strength` 0..1 scales particles and volume. `sound` is a Sound, or -1 to
## derive it from the impact type.
static func spawn(parent: Node, at: Vector3, normal: Vector3,
		impact_type: PhysicsToolDefinition.ImpactType, strength: float, tint: Color = Color(0, 0, 0, 0),
		sound: int = -1) -> void:
	if parent == null or not parent.is_inside_tree() or _live >= MAX_LIVE:
		return
	_live += 1
	var feedback := ImpactFeedback.new()
	feedback.tree_exited.connect(func(): _live -= 1)
	parent.add_child(feedback)
	feedback.global_position = at
	var family: int = sound if sound >= 0 else TYPE_SOUNDS.get(impact_type, Sound.GENERIC)
	feedback._emit(normal, impact_type, clampf(strength, 0.0, 1.0), tint, family)


func _emit(normal: Vector3, impact_type: PhysicsToolDefinition.ImpactType, strength: float, tint: Color, sound: int) -> void:
	var particles := CPUParticles3D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	# Strong hits throw more, faster, chunkier bits.
	particles.amount = 6 + roundi(strength * 18.0)
	particles.lifetime = 0.35 + strength * 0.25
	particles.direction = normal if not normal.is_zero_approx() else Vector3.UP
	particles.spread = 55.0 + strength * 20.0
	particles.initial_velocity_min = 1.0
	particles.initial_velocity_max = 2.0 + strength * 4.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.gravity = Vector3(0, -9.8, 0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0 + strength * 0.8
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.025
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = {
		PhysicsToolDefinition.ImpactType.BLUNT: Color(0.85, 0.75, 0.6),
		PhysicsToolDefinition.ImpactType.SWEEP: Color(0.95, 0.95, 0.85),
		PhysicsToolDefinition.ImpactType.SHARP: Color(1.0, 0.8, 0.3),
		PhysicsToolDefinition.ImpactType.PIERCE: Color(0.8, 0.8, 0.8),
	}[impact_type]
	if tint.a > 0.0:
		material.albedo_color = tint
	mesh.material = material
	particles.mesh = mesh
	add_child(particles)
	particles.emitting = true

	var player := AudioStreamPlayer3D.new()
	player.stream = _get_sound(sound)
	player.volume_db = lerpf(-16.0, 2.0, strength)
	# Bigger hits sound a little deeper.
	player.pitch_scale = randf_range(0.94, 1.06) * lerpf(1.08, 0.88, strength)
	add_child(player)
	player.play()
	var lifetime := maxf(LIFETIME, particles.lifetime + 0.1)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


static func _get_sound(sound: int) -> AudioStreamWAV:
	if _sounds.has(sound):
		return _sounds[sound]
	var recipe: Array = SOUND_RECIPES.get(sound, SOUND_RECIPES[Sound.GENERIC])
	var frequency := float(recipe[0])
	var length := float(recipe[1])
	var count := int(SAMPLE_RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + sound
	for index in count:
		var t := float(index) / SAMPLE_RATE
		var envelope := exp(-t / (length * 0.25))
		# A slightly inharmonic second partial makes metal ring and wood knock.
		var tone := sin(TAU * frequency * t) + sin(TAU * frequency * 2.76 * t) * float(recipe[3])
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := lerpf(tone, noise, float(recipe[2])) * envelope * 0.7
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	_sounds[sound] = stream
	return stream
