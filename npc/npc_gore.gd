class_name NPCGore
extends RefCounted
## Light, comedic gore for NPCs: bright ketchup-red cartoon blood. Chunky
## bursts when flesh is hit, splats on whatever they land on (pooled and
## faded), spurting stumps when a limb comes off, and squelch / pop sounds.
## No organs; bone just shows as the odd off-white chunk.

const BLOOD := Color(0.92, 0.1, 0.12)
const MAX_SPLATS := 40
const SPLAT_LIFE := 60.0
const MAX_BURSTS := 12
## Materials that bleed when knocked out (by VoxelMaterialDefinition name).
const BLEEDS := ["Flesh", "Skin"]

static var _splats: Array[Decal] = []
static var _splat_textures: Array[Texture2D] = []
static var _blood_material: StandardMaterial3D
static var _bursts := 0
static var _sounds := {}


## Called when an NPC part loses voxels: blood for flesh, a dull thud otherwise.
static func on_cells_removed(body: VoxelBody, removed: Dictionary, direction: Vector3, strength: float) -> void:
	if not body.is_inside_tree():
		return
	var bleeding := 0
	var centre := Vector3.ZERO
	for cell: Vector3i in removed:
		var material: VoxelMaterialDefinition = body.palette[removed[cell]]
		if BLEEDS.has(material.display_name):
			bleeding += 1
			centre += body.cell_to_world(cell)
	if bleeding == 0:
		return
	centre /= bleeding
	var amount := clampf(bleeding / 4.0, 0.25, 1.0) * clampf(strength / 30.0, 0.4, 1.3)
	burst(_parent(body), centre, -direction if not direction.is_zero_approx() else Vector3.UP, amount)
	play(body, centre, "squelch", -4.0 + amount * 6.0)
	# Splats where it lands: under the hit, and a little way along the blow.
	splat(body, centre, Vector3.DOWN, 0.25 + amount * 0.35)
	if not direction.is_zero_approx():
		splat(body, centre, direction.normalized(), 0.2 + amount * 0.25)


## A one-shot spray of chunky red droplets.
static func burst(parent: Node, at: Vector3, normal: Vector3, amount: float) -> void:
	if parent == null or _bursts >= MAX_BURSTS:
		return
	_bursts += 1
	var particles := _droplets(roundi(10 + amount * 30), 0.9)
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.direction = normal
	particles.spread = 55.0
	particles.initial_velocity_min = 1.5 + amount * 1.5
	particles.initial_velocity_max = 3.0 + amount * 2.5
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	# Counted down however it goes (finished, or freed with its scene).
	particles.tree_exiting.connect(_burst_gone)
	particles.finished.connect(particles.queue_free)


## A stump spurting in comic arcs for a couple of seconds. `along` is the
## stump's outward direction in `body`'s local space.
static func spurt(body: Node3D, local_at: Vector3, along: Vector3, seconds := 2.5) -> void:
	if not body.is_inside_tree():
		return
	var particles := NPCSpurt.new()
	_setup_droplets(particles, 36, 0.8)
	particles.seconds = seconds
	particles.direction = along.normalized()
	particles.spread = 14.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 3.4
	particles.local_coords = false
	body.add_child(particles)
	particles.position = local_at


## A blood splat decal on the first surface along `direction` from `from`.
static func splat(context: Node3D, from: Vector3, direction: Vector3, size: float) -> void:
	var world := context.get_world_3d()
	if world == null:
		return
	var query := PhysicsRayQueryParameters3D.create(from, from + direction.normalized() * 2.5, 1)
	var hit := world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var decal: Decal
	# Splats go with their scene (a reload frees them): forget the dead ones.
	var live: Array[Decal] = []
	for old: Variant in _splats:
		if is_instance_valid(old):
			live.append(old)
	_splats = live
	if _splats.size() < MAX_SPLATS:
		decal = Decal.new()
		decal.cull_mask = 1
		decal.upper_fade = 0.2
		decal.lower_fade = 0.2
		_parent(context).add_child(decal)
	else:
		# Reuse the oldest.
		decal = _splats.pop_front()
	_splats.append(decal)
	if _splat_textures.is_empty():
		_make_splat_textures()
	decal.texture_albedo = _splat_textures[randi() % _splat_textures.size()]
	decal.modulate = BLOOD
	decal.size = Vector3(size, 0.3, size)
	var normal: Vector3 = hit["normal"]
	var side := normal.cross(Vector3.FORWARD if absf(normal.z) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side, normal, side.cross(normal)).rotated(normal, randf() * TAU)
	decal.global_transform = Transform3D(basis, hit["position"] + normal * 0.01)
	decal.albedo_mix = 1.0
	decal.set_meta(&"born", Time.get_ticks_msec())
	# Fade out over the last few seconds of its life (a reused splat restarts).
	if decal.has_meta(&"fade"):
		var old: Tween = decal.get_meta(&"fade")
		if old != null and old.is_valid():
			old.kill()
	var tween := decal.create_tween()
	decal.set_meta(&"fade", tween)
	tween.tween_interval(SPLAT_LIFE - 5.0)
	tween.tween_property(decal, "albedo_mix", 0.0, 5.0)


static func play(at_node: Node3D, at: Vector3, kind: String, volume_db := 0.0) -> void:
	if not at_node.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = _sound(kind)
	player.bus = &"Impacts"
	player.volume_db = volume_db
	player.pitch_scale = randf_range(0.85, 1.2)
	player.unit_size = 4.0
	_parent(at_node).add_child(player)
	player.global_position = at
	player.play()
	player.finished.connect(player.queue_free)


# --- Building blocks

static func _burst_gone() -> void:
	_bursts = maxi(_bursts - 1, 0)


static func _droplets(amount: int, lifetime: float) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	_setup_droplets(particles, amount, lifetime)
	return particles


static func _setup_droplets(particles: CPUParticles3D, amount: int, lifetime: float) -> void:
	particles.amount = amount
	particles.lifetime = lifetime
	particles.gravity = Vector3(0, -12.0, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.022
	if _blood_material == null:
		_blood_material = StandardMaterial3D.new()
		_blood_material.albedo_color = BLOOD
		_blood_material.roughness = 0.25
		_blood_material.metallic_specular = 0.8
	cube.material = _blood_material
	particles.mesh = cube


## A few round, blobby splat shapes with droplets round them (white; tinted by the decal).
static func _make_splat_textures() -> void:
	for variant in 4:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color(1, 1, 1, 0))
		var rng := RandomNumberGenerator.new()
		rng.seed = 17 + variant * 31
		var blobs := [[Vector2(32, 32), 15.0 + variant * 2.0]]
		for i in 7:
			var angle := rng.randf() * TAU
			var dist := rng.randf_range(12.0, 26.0)
			blobs.append([Vector2(32, 32) + Vector2.from_angle(angle) * dist, rng.randf_range(2.0, 6.5)])
		for y in 64:
			for x in 64:
				var p := Vector2(x, y)
				var a := 0.0
				for blob in blobs:
					a = maxf(a, clampf((blob[1] - p.distance_to(blob[0])) * 0.6, 0.0, 1.0))
				if a > 0.0:
					image.set_pixel(x, y, Color(1, 1, 1, a))
		_splat_textures.append(ImageTexture.create_from_image(image))


## Squelch (wet, low noise with a falling pitch) and pop (a quick bright plop).
static func _sound(kind: String) -> AudioStreamWAV:
	if _sounds.has(kind):
		return _sounds[kind]
	var rate := 22050
	var seconds := 0.32 if kind == "squelch" else 0.22
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var low := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / rate
		var env := exp(-t * (11.0 if kind == "squelch" else 18.0))
		var sample := 0.0
		if kind == "squelch":
			# Filtered noise through a wobbling, falling resonance.
			low += (rng.randf_range(-1.0, 1.0) - low) * 0.12
			phase += TAU * (420.0 - t * 900.0 + sin(t * 70.0) * 60.0) / rate
			sample = (low * 0.7 + sin(phase) * 0.35) * env
		else:
			phase += TAU * (900.0 - t * 2600.0) / rate
			sample = sin(phase) * env * 0.8
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	_sounds[kind] = stream
	return stream


## Where effects go: the running scene (or the root, when there isn't one).
static func _parent(node: Node) -> Node:
	var tree := node.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root
