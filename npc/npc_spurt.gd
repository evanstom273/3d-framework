class_name NPCSpurt
extends CPUParticles3D
## A severed stump spurting in comic pulses for a few seconds, splatting the
## ground under it, then tidying itself away. Self-contained (no timers or
## captured callbacks), so it's fine if its limb is freed first.

const PULSE := 0.55
const ON := 0.3

var seconds := 2.5
var _age := 0.0
var _last_pulse := -1


func _ready() -> void:
	emitting = true


func _process(delta: float) -> void:
	_age += delta
	var pulse := int(_age / PULSE)
	if _age < seconds:
		var into := fmod(_age, PULSE)
		emitting = into < ON
		if pulse != _last_pulse:
			_last_pulse = pulse
			# Each pulse a little weaker, and a splat where it lands.
			initial_velocity_max = 3.4 * (1.0 - _age / seconds * 0.6)
			NPCGore.splat(self, global_position, Vector3.DOWN, 0.3)
	else:
		emitting = false
		if _age > seconds + lifetime + 0.1:
			queue_free()
