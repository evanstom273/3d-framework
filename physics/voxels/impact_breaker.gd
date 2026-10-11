class_name ImpactBreaker
extends RefCounted
## Lets hard collisions break voxels. Each moving body calls process() from
## _integrate_forces: when it touches something new and its velocity changes
## sharply, the change times its mass is the impact. It damages itself if it is a
## VoxelBody, and the thing it hit if that is a fixed VoxelBody (fixed bodies
## can't measure their own impacts). Two moving voxel bodies each damage only
## themselves, so nothing is counted twice.
## Held objects count too: carry steering changes speed by at most ~2 m/s per
## step (even with the Chaotic feel), under MIN_IMPACT_SPEED, so only real
## collisions (swinging a held object into something) register.
## Strong impacts also get the PhysicsFeel profile's knockback, tumble, feedback
## and camera shake; damage itself stays purely physical and material-driven.

## Velocity changes below this are ordinary contact (resting, sliding, stacking).
const MIN_IMPACT_SPEED := 3.5
## Damage per newton-second of impact above the threshold.
const DAMAGE_PER_IMPULSE := 0.15
## One impact per body per this many milliseconds, so a single crash counts once.
const COOLDOWN_MSEC := 150


## `memory` is a per-body Dictionary the caller keeps between calls.
static func process(body: RigidBody3D, state: PhysicsDirectBodyState3D, memory: Dictionary,
		damage_scale: float, active: bool) -> void:
	var velocity := state.linear_velocity
	var spin := state.angular_velocity
	var previous: Vector3 = memory.get("velocity", velocity)
	var previous_spin: Vector3 = memory.get("spin", spin)
	memory["velocity"] = velocity
	memory["spin"] = spin
	var known: Dictionary = memory.get("contacts", {})
	var contacts := {}
	var fresh := -1
	for index in state.get_contact_count():
		var id := state.get_contact_collider_id(index)
		contacts[id] = true
		if fresh < 0 and not known.has(id):
			fresh = index
	memory["contacts"] = contacts
	if not active or fresh < 0:
		return
	# Measure at the contact point, so the end of a swung or spinning object counts
	# even when its centre is barely moving.
	var contact := state.get_contact_local_position(fresh)
	var lever := contact - (state.transform.origin + state.center_of_mass)
	var before := previous + previous_spin.cross(lever)
	var after := velocity + spin.cross(lever)
	var change := (after - before).length()
	if change < MIN_IMPACT_SPEED:
		return
	var now := Time.get_ticks_msec()
	if now < int(memory.get("cooldown", 0)):
		return
	memory["cooldown"] = now + COOLDOWN_MSEC
	var impulse := body.mass * change
	var damage := maxf(impulse - body.mass * MIN_IMPACT_SPEED, 0.0) * DAMAGE_PER_IMPULSE * damage_scale
	var radius := clampf(0.05 + 0.015 * sqrt(impulse), 0.08, 0.45)
	# Bodies can't be reshaped or pushed mid-step, so the consequences land after it.
	_apply.call_deferred(body, state.get_contact_collider_object(fresh),
		contact, state.get_contact_collider_position(fresh),
		state.get_contact_local_normal(fresh), damage, radius, before.normalized(), impulse)


static func _apply(body: RigidBody3D, other: Object, own_point: Vector3, other_point: Vector3,
		normal: Vector3, damage: float, radius: float, direction: Vector3, impulse: float) -> void:
	if not is_instance_valid(body):
		return
	var contraptions := ContraptionWorld.find(body)
	if contraptions != null: contraptions.impact(body, impulse)
	var feel := PhysicsFeel.get_active()
	var tint := Color(0, 0, 0, 0)
	var sound := _sound_of(body)
	if damage > 0.0:
		if body is VoxelBody:
			tint = (body as VoxelBody).damage_at(own_point, radius, damage, -direction)
		if is_instance_valid(other) and other is VoxelBody and (other as VoxelBody).freeze:
			var hit_tint := (other as VoxelBody).damage_at(other_point, radius, damage, direction)
			if hit_tint.a > 0.0:
				tint = hit_tint
				sound = _sound_of(other)
	if impulse < feel.min_exaggeration_impulse:
		return
	# Exaggerated consequences, each applied once per impact (the caller's cooldown
	# stops sustained contact repeating them). The struck loose body gets a share
	# of extra knockback well under 1x, so two bodies can never feed each other.
	var other_body := other as RigidBody3D if is_instance_valid(other) else null
	if other_body != null and not other_body.freeze and not _is_held(other_body):
		var knock := direction * impulse * (feel.impact_impulse_multiplier - 1.0) * 0.5
		other_body.apply_impulse(knock, other_point - other_body.global_position)
		feel.tumble(other_body, direction * impulse * 0.5)
	if not _is_held(body):
		# Recoil spin: the crashing object tumbles away from what it hit.
		feel.tumble(body, normal * impulse * 0.35)
	ImpactFeedback.spawn(body.get_parent(), own_point, normal, PhysicsToolDefinition.ImpactType.BLUNT,
		clampf(impulse / 60.0, 0.15, 1.0), tint, sound)
	CameraShake.shake_at(body.get_tree(), own_point, impulse)


static func _sound_of(node: Object) -> int:
	if node is VoxelBody:
		return (node as VoxelBody).get_impact_sound()
	if node is Node and (node as Node).has_method("get_impact_sound"):
		return int((node as Node).call("get_impact_sound"))
	return ImpactFeedback.Sound.GENERIC


static func _is_held(body: RigidBody3D) -> bool:
	return body.has_method("is_held") and bool(body.call("is_held"))
