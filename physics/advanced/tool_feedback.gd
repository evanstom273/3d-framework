class_name ToolFeedback
extends Node3D
## Sound and effects for one advanced tool: a running loop that idles quietly while
## equipped and revs when used, a particle stream from the nozzle toward the aim,
## contact particles where the tool meets a surface (sawdust, sparks, splash), a
## glow for flames and welding arcs, a beam for the grabber and magnet, spinning
## or running parts, and one-shot sounds. Sounds are synthesised once and cached.

const RATE := 22050

static var _loops: Dictionary = {}
static var _shots: Dictionary = {}

var action: ToolActionDefinition
var _loop := AudioStreamPlayer3D.new()
var _shot := AudioStreamPlayer3D.new()
var _stream := CPUParticles3D.new()
var _contact := CPUParticles3D.new()
var _light := OmniLight3D.new()
var _beam := MeshInstance3D.new()
var _beam_mesh := ImmediateMesh.new()
var _spinner: Node3D
var _teeth: Array[MeshInstance3D] = []
var _equipped: bool = false
var _phase: float = 0.0
var _volume: float = -80.0
var _built: bool = false


func setup(definition: ToolActionDefinition) -> void:
	action = definition
	if not _built:
		_built = true
		for node: Node in [_loop, _shot, _stream, _contact, _light, _beam]:
			add_child(node)
		# Effects are placed in world space each frame, not carried by the tool.
		for node: Node3D in [_stream, _contact, _light, _beam]:
			node.top_level = true
		_beam.mesh = _beam_mesh
		_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_loop.bus = &"Tools"
	_shot.bus = &"Tools"
	_loop.stream = _loop_stream(action.loop_sound)
	_loop.max_distance = 25.0
	_loop.unit_size = 4.0
	_shot.stream = _shot_stream(action.shot_sound)
	_shot.max_distance = 25.0
	_shot.unit_size = 4.0
	_shot.volume_db = action.sound_volume_db
	_configure(_stream, action.effect, action.effect_color)
	_configure(_contact, action.contact_effect, action.effect_color)
	_stream.emitting = false
	_contact.emitting = false
	_light.visible = false
	_light.light_color = Color(action.light_color, 1.0)
	_light.omni_range = 3.5
	_light.shadow_enabled = false
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.albedo_color = Color(action.effect_color, 0.8)
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam.material_override = beam_material
	_beam.visible = false
	_build_moving_parts()


func set_equipped(on: bool) -> void:
	_equipped = on
	if not on:
		_loop.stop()
		_volume = -80.0
		_stream.emitting = false
		_contact.emitting = false
		_light.visible = false
		_beam.visible = false


func play_shot() -> void:
	if _shot.stream != null:
		_shot.pitch_scale = randf_range(0.94, 1.06)
		_shot.play()


## A short shower of sparks, e.g. when a weld completes.
func burst(at: Vector3, normal: Vector3) -> void:
	ImpactFeedback.spawn(get_tree().current_scene, at, normal, PhysicsToolDefinition.ImpactType.SHARP, 1.0, Color(1.0, 0.85, 0.4), ImpactFeedback.Sound.METAL)


func update(delta: float, working: bool, runtime: AdvancedToolRuntime) -> void:
	_phase += delta
	_update_sound(delta, working)
	var nozzle := runtime.nozzle_position()
	var direction := runtime.nozzle_direction()
	# Stream from the nozzle toward the aim.
	if action.effect != ToolActionDefinition.Effect.NONE and action.effect != ToolActionDefinition.Effect.BEAM:
		_stream.global_transform = Transform3D(_facing(direction), nozzle)
		if action.operation == "paint" and runtime.behaviour.has_method("current_color"):
			_stream.color = runtime.behaviour.call("current_color")
		_stream.emitting = working
	# Contact particles where the tool meets the surface.
	var touch := runtime.behaviour.contact()
	var touching := working and not touch.is_empty() and action.contact_effect != ToolActionDefinition.Effect.NONE
	if touching:
		var normal: Vector3 = touch.get("normal", Vector3.UP)
		_contact.global_transform = Transform3D(_facing(-normal), touch["position"] + normal * 0.02)
		if touch.has("color") and action.contact_effect in [ToolActionDefinition.Effect.SAWDUST, ToolActionDefinition.Effect.DUST]:
			_contact.color = (touch["color"] as Color).lightened(0.15)
	_contact.emitting = touching
	# Glow: flames and arcs flicker.
	_light.visible = working and action.light_color.a > 0.0
	if _light.visible:
		_light.global_position = nozzle + direction * 0.08
		_light.light_energy = 1.6 + sin(_phase * 37.0) * 0.4 + sin(_phase * 91.0) * 0.3
	# Beam from the muzzle to the held or attracted thing.
	_update_beam(working and action.effect == ToolActionDefinition.Effect.BEAM, nozzle, touch, runtime)
	_animate_moving_parts(delta, working)


# --- Sound

func _update_sound(delta: float, working: bool) -> void:
	if _loop.stream == null or not _equipped:
		return
	var target := action.sound_volume_db if working else (action.sound_volume_db - 16.0 if action.idles else -80.0)
	_volume = move_toward(_volume, target, delta * (90.0 if working else 60.0))
	if _volume <= -60.0:
		if _loop.playing:
			_loop.stop()
		return
	if not _loop.playing:
		_loop.play()
	_loop.volume_db = _volume
	# Motors rev up under load and drop back to idle.
	var pitch := action.sound_pitch * (1.0 if working else 0.72)
	_loop.pitch_scale = move_toward(_loop.pitch_scale, pitch, delta * 2.5)


static func _loop_stream(kind: ToolActionDefinition.LoopSound) -> AudioStreamWAV:
	if kind == ToolActionDefinition.LoopSound.NONE:
		return null
	if _loops.has(kind):
		return _loops[kind]
	var count := RATE
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + kind
	var low := 0.0
	var band := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.08)
		band = lerpf(band, noise, 0.35)
		var sample := 0.0
		match kind:
			ToolActionDefinition.LoopSound.MOTOR:
				# Two-stroke: a buzzy sawtooth with a firing pulse and some grit.
				var saw := fposmod(t * 110.0, 1.0) * 2.0 - 1.0
				var pulse := 0.6 + 0.4 * sin(TAU * 30.0 * t)
				sample = (saw * 0.55 + sin(TAU * 220.0 * t) * 0.2) * pulse + band * 0.25
			ToolActionDefinition.LoopSound.WHINE:
				sample = sin(TAU * 880.0 * t) * 0.35 + sin(TAU * 1760.0 * t) * 0.15 + band * 0.3
			ToolActionDefinition.LoopSound.HISS:
				sample = (noise - band) * 0.9
			ToolActionDefinition.LoopSound.SPRAY:
				sample = band * 0.7 * (0.8 + 0.2 * sin(TAU * 25.0 * t)) + (noise - band) * 0.25
			ToolActionDefinition.LoopSound.ROAR:
				sample = low * 2.2 + sin(TAU * 45.0 * t) * 0.25 + band * 0.2
			ToolActionDefinition.LoopSound.HUM:
				sample = (sin(TAU * 120.0 * t) * 0.5 + sin(TAU * 240.0 * t) * 0.25) * (0.75 + 0.25 * sin(TAU * 4.0 * t))
			ToolActionDefinition.LoopSound.BUZZ:
				var square := 1.0 if sin(TAU * 100.0 * t) > 0.0 else -1.0
				var crackle := noise if rng.randf() < 0.08 else 0.0
				sample = square * 0.25 + crackle * 0.8 + band * 0.2
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	_loops[kind] = stream
	return stream


static func _shot_stream(kind: ToolActionDefinition.ShotSound) -> AudioStreamWAV:
	if kind == ToolActionDefinition.ShotSound.NONE:
		return null
	if _shots.has(kind):
		return _shots[kind]
	var length: float = {
		ToolActionDefinition.ShotSound.CLICK: 0.04,
		ToolActionDefinition.ShotSound.THUNK: 0.16,
		ToolActionDefinition.ShotSound.POP: 0.2,
		ToolActionDefinition.ShotSound.ZAP: 0.25,
	}[kind]
	var count := int(RATE * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31 + kind
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := 0.0
		match kind:
			ToolActionDefinition.ShotSound.CLICK:
				sample = (sin(TAU * 2400.0 * t) * 0.5 + noise * 0.5) * exp(-t / 0.008)
			ToolActionDefinition.ShotSound.THUNK:
				sample = (sin(TAU * 90.0 * t) * 0.8 + noise * 0.5 * exp(-t / 0.02)) * exp(-t / 0.05)
			ToolActionDefinition.ShotSound.POP:
				sample = sin(TAU * lerpf(420.0, 140.0, t / length) * t) * exp(-t / 0.06) + noise * 0.2 * exp(-t / 0.015)
			ToolActionDefinition.ShotSound.ZAP:
				sample = (noise * 0.7 + (1.0 if sin(TAU * 100.0 * t) > 0.0 else -1.0) * 0.3) * exp(-t / 0.08)
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 28000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	_shots[kind] = stream
	return stream


# --- Particles

## Points the emitter's -Z (its spray direction) along `direction`.
static func _facing(direction: Vector3) -> Basis:
	var up := Vector3.UP if absf(direction.normalized().y) < 0.95 else Vector3.BACK
	return Basis.looking_at(direction, up)


func _configure(particles: CPUParticles3D, effect: ToolActionDefinition.Effect, tint: Color) -> void:
	particles.one_shot = false
	particles.local_coords = false
	particles.direction = Vector3(0, 0, -1)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINT
	particles.radial_accel_min = 0.0
	particles.radial_accel_max = 0.0
	var size := 0.02
	var additive := false
	var color := tint
	var gravity := Vector3(0, -9.8, 0)
	match effect:
		ToolActionDefinition.Effect.FLAME:
			_tune(particles, 48, 0.22, 7.0, 2.5, 4.0)
			gravity = Vector3(0, 1.5, 0)
			size = 0.035
			additive = true
		ToolActionDefinition.Effect.SPARKS:
			_tune(particles, 36, 0.35, 45.0, 3.0, 7.0)
			size = 0.008
			additive = true
			color = Color(1.0, 0.8, 0.35)
		ToolActionDefinition.Effect.WATER:
			_tune(particles, 70, 0.4, 3.0, 10.0, 13.0)
			size = 0.018
			color = Color(0.7, 0.85, 1.0, 0.7)
		ToolActionDefinition.Effect.MIST:
			_tune(particles, 60, 0.6, 14.0, 5.0, 7.0)
			gravity = Vector3(0, -1.0, 0)
			size = 0.06
			color = Color(0.95, 0.97, 1.0, 0.45)
		ToolActionDefinition.Effect.AIR:
			_tune(particles, 20, 0.35, 12.0, 7.0, 10.0)
			gravity = Vector3.ZERO
			size = 0.01
			color = Color(0.85, 0.85, 0.8, 0.35)
		ToolActionDefinition.Effect.INTAKE:
			_tune(particles, 24, 0.4, 0.0, 0.0, 0.0)
			particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
			particles.emission_sphere_radius = 0.45
			particles.radial_accel_min = -16.0
			particles.radial_accel_max = -12.0
			gravity = Vector3.ZERO
			size = 0.01
			color = Color(0.7, 0.68, 0.62, 0.5)
		ToolActionDefinition.Effect.PAINT:
			_tune(particles, 55, 0.3, 9.0, 6.0, 8.0)
			gravity = Vector3(0, -3.0, 0)
			size = 0.012
		ToolActionDefinition.Effect.FOAM:
			_tune(particles, 20, 0.35, 8.0, 2.0, 3.0)
			gravity = Vector3(0, -6.0, 0)
			size = 0.03
			color = Color(0.95, 0.85, 0.45)
		ToolActionDefinition.Effect.SAWDUST:
			_tune(particles, 34, 0.5, 60.0, 1.5, 3.5)
			size = 0.012
		ToolActionDefinition.Effect.DUST:
			_tune(particles, 24, 0.6, 50.0, 1.0, 2.5)
			gravity = Vector3(0, -4.0, 0)
			size = 0.03
		ToolActionDefinition.Effect.SMOKE:
			_tune(particles, 16, 1.2, 25.0, 0.4, 0.9)
			gravity = Vector3(0, 1.2, 0)
			size = 0.07
			color = Color(0.25, 0.24, 0.23, 0.5)
		_:
			_tune(particles, 8, 0.3, 20.0, 1.0, 2.0)
	particles.gravity = gravity
	particles.color = color
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var mesh: PrimitiveMesh = QuadMesh.new() if effect in [ToolActionDefinition.Effect.FLAME, ToolActionDefinition.Effect.MIST, ToolActionDefinition.Effect.SMOKE] else BoxMesh.new()
	if mesh is QuadMesh:
		(mesh as QuadMesh).size = Vector2.ONE * size
	else:
		(mesh as BoxMesh).size = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if mesh is QuadMesh:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mesh.material = material
	particles.mesh = mesh
	# Flames and smoke fade out over their life.
	if effect in [ToolActionDefinition.Effect.FLAME, ToolActionDefinition.Effect.MIST, ToolActionDefinition.Effect.SMOKE, ToolActionDefinition.Effect.SPARKS]:
		var ramp := Gradient.new()
		var start := color.lightened(0.3) if effect == ToolActionDefinition.Effect.FLAME else color
		ramp.set_color(0, start)
		ramp.set_color(1, Color(color.lerp(Color(0.3, 0.3, 0.3), 0.5), 0.0))
		particles.color_ramp = ramp
	else:
		particles.color_ramp = null


static func _tune(particles: CPUParticles3D, amount: int, lifetime: float, spread: float, speed_min: float, speed_max: float) -> void:
	particles.amount = amount
	particles.lifetime = lifetime
	particles.spread = spread
	particles.initial_velocity_min = speed_min
	particles.initial_velocity_max = speed_max


# --- Beam

func _update_beam(active: bool, from: Vector3, touch: Dictionary, runtime: AdvancedToolRuntime) -> void:
	var to: Vector3 = touch.get("position", runtime.aim_point(action.range_metres)) if active else from
	_beam.visible = active
	if not active:
		return
	_beam_mesh.clear_surfaces()
	_beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	# A few wavering strands read as a field rather than a laser.
	for strand in 3:
		var previous := from
		for step in range(1, 9):
			var t := step / 8.0
			var wobble := Vector3(sin(_phase * 23.0 + strand * 2.1 + t * 9.0), cos(_phase * 19.0 + strand * 1.3 + t * 7.0), 0) * 0.03 * sin(t * PI)
			var point := from.lerp(to, t) + wobble
			_beam_mesh.surface_add_vertex(previous)
			_beam_mesh.surface_add_vertex(point)
			previous = point
	_beam_mesh.surface_end()


# --- Moving parts

func _build_moving_parts() -> void:
	if _spinner != null:
		_spinner.queue_free()
		_spinner = null
	_teeth.clear()
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.18, 0.18, 0.2)
	dark.metallic = 0.7
	dark.roughness = 0.4
	match action.operation:
		"screw", "grind":
			_spinner = Node3D.new()
			_spinner.position = action.moving_part_position
			add_child(_spinner)
			var blade := MeshInstance3D.new()
			var box := BoxMesh.new()
			# A drill bit's flats, or the slot across a grinding disc, show the spin.
			box.size = Vector3(0.012, 0.003, 0.05) if action.operation == "screw" else Vector3(0.12, 0.004, 0.012)
			box.material = dark
			blade.mesh = box
			_spinner.add_child(blade)
		"saw":
			_spinner = Node3D.new()
			_spinner.position = action.moving_part_position
			add_child(_spinner)
			for i in 14:
				var tooth := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.026, 0.012, 0.022)
				box.material = dark
				tooth.mesh = box
				_spinner.add_child(tooth)
				_teeth.append(tooth)


func _animate_moving_parts(delta: float, working: bool) -> void:
	if _spinner == null:
		return
	match action.operation:
		"screw":
			if working:
				_spinner.rotate_object_local(Vector3.FORWARD, delta * 40.0)
		"grind":
			if working:
				_spinner.rotate_object_local(Vector3.UP, delta * 55.0)
		"saw":
			# Teeth run round the bar: along the top edge, back along the bottom.
			var length := action.region_size.z
			var travel := fposmod(_phase * (3.0 if working else 0.0), 1.0)
			for i in _teeth.size():
				var u := fposmod(i / float(_teeth.size()) + travel, 1.0)
				var top := u < 0.5
				var along := (u * 2.0 if top else (u - 0.5) * 2.0) * length - length * 0.5
				_teeth[i].position = Vector3(0, 0.037 if top else -0.037, along if top else -along)
