@tool
class_name PhysicsFeel
extends Resource
## How exaggerated the physics feels: a shared profile that impact, throw, hold
## and debris code consult. It only scales consequences of real physics events;
## mass, friction, bounce and strength stay in each object's own resources.
## Presets live next to this script (grounded, playful, chaotic). The active one is
## set by the scene (see physics_playground.gd) or falls back to DEFAULT_PATH.

const DEFAULT_PATH := "res://physics/feel/playful.tres"

static var _active: PhysicsFeel

@export var display_name: String = "Playful"
## Extra push given by strong impacts (tool hits, crashes). 1 = physically plain.
@export_range(1.0, 3.0, 0.05) var impact_impulse_multiplier: float = 1.25
## Spin added by strong impacts and throws, so things tumble and flip. 0 = none.
@export_range(0.0, 3.0, 0.05) var angular_impulse_multiplier: float = 1.0
## How eagerly held objects follow and turn. Light objects benefit; heavy ones
## stay limited by carry strength, so they still feel heavy.
@export_range(0.5, 2.5, 0.05) var held_responsiveness: float = 1.3
## Extra throw speed at full charge (a tap throw is unchanged).
@export_range(1.0, 2.0, 0.05) var throw_multiplier: float = 1.15
## How energetically rubble and broken-off chunks fly from an impact.
@export_range(0.0, 3.0, 0.05) var debris_launch_multiplier: float = 1.4
## Camera shake from big impacts near the player. 0 turns it off.
@export_range(0.0, 3.0, 0.05) var camera_shake_strength: float = 1.0
## Impacts weaker than this (N·s) get no exaggeration, spin or extra feedback, so
## resting, stacking, sliding and gentle bumps behave plainly.
@export_range(0.0, 50.0, 0.5, "suffix:N·s") var min_exaggeration_impulse: float = 6.0

## Spin added per m/s of impact speed change, and its ceiling (rad/s).
const TUMBLE_PER_SPEED := 1.5
const MAX_TUMBLE := 12.0


static func get_active() -> PhysicsFeel:
	if _active == null:
		_active = load(DEFAULT_PATH) if ResourceLoader.exists(DEFAULT_PATH) else PhysicsFeel.new()
	return _active


static func set_active(profile: PhysicsFeel) -> void:
	_active = profile


## Multiplier for an impulse of this size (plain below the threshold).
func impulse_scale(impulse: float) -> float:
	return impact_impulse_multiplier if impulse >= min_exaggeration_impulse else 1.0


## Adds a tumble to `body` for an impact pushing along `impulse`: it spins as if
## struck above its centre, more for light bodies (via speed change), capped.
## Deterministic: the axis comes from the push direction.
func tumble(body: RigidBody3D, impulse: Vector3) -> void:
	if body == null or body.freeze or angular_impulse_multiplier <= 0.0:
		return
	var strength := impulse.length()
	if strength < min_exaggeration_impulse:
		return
	var direction := impulse / strength
	var axis := Vector3.UP.cross(direction)
	if axis.length_squared() < 0.01:
		# A vertical hit: flip about a horizontal axis instead.
		axis = direction.cross(Vector3.RIGHT)
	var spin := minf(strength / body.mass * TUMBLE_PER_SPEED, MAX_TUMBLE) * angular_impulse_multiplier
	body.angular_velocity += axis.normalized() * minf(spin, MAX_TUMBLE * angular_impulse_multiplier)
