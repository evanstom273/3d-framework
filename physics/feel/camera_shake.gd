class_name CameraShake
extends Node
## Restrained impact shake for its parent Camera3D. Big impacts add "trauma"
## (falling off with distance); the shake is trauma squared, so small bumps are
## invisible and only real crashes register. Uses the camera's h/v offsets, so
## it never fights the camera's own motion. Strength comes from PhysicsFeel.

const RANGE := 10.0
const MAX_OFFSET := 0.035
const DECAY := 2.2

var _camera: Camera3D
var _trauma: float = 0.0
var _time: float = 0.0


## Lets any impact ask nearby cameras to shake.
static func shake_at(tree: SceneTree, position: Vector3, impulse: float) -> void:
	if tree != null:
		tree.call_group(&"camera_shakers", &"add_impact", position, impulse)


func _ready() -> void:
	_camera = get_parent() as Camera3D
	add_to_group(&"camera_shakers")
	set_process(false)


func add_impact(position: Vector3, impulse: float) -> void:
	var feel := PhysicsFeel.get_active()
	if _camera == null or feel.camera_shake_strength <= 0.0 or impulse < feel.min_exaggeration_impulse * 2.0:
		return
	var falloff := clampf(1.0 - _camera.global_position.distance_to(position) / RANGE, 0.0, 1.0)
	if falloff <= 0.0:
		return
	_trauma = minf(1.0, _trauma + clampf(impulse / 120.0, 0.0, 0.6) * falloff * feel.camera_shake_strength)
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_trauma = maxf(0.0, _trauma - DECAY * delta)
	var amount := _trauma * _trauma * MAX_OFFSET
	_camera.h_offset = sin(_time * 47.0) * amount
	_camera.v_offset = sin(_time * 53.0 + 1.3) * amount
	if _trauma <= 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		set_process(false)
