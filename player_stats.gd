extends Node
## Values are percentages. Stamina powers sprinting; Charge powers the jetpack.

signal changed

var _exhausted: bool = false
var _recovery_remaining: float = 0.0
var _charge_depleted: bool = false

@export_group("Vitals")
@export_range(0.0, 100.0, 1.0) var health: float = 100.0:
	set(value):
		health = clampf(value, 0.0, 100.0)
		changed.emit()
@export_range(0.0, 100.0, 1.0) var hazard_protection: float = 100.0:
	set(value):
		hazard_protection = clampf(value, 0.0, 100.0)
		changed.emit()
@export_range(0.0, 100.0, 1.0) var oxygen: float = 100.0:
	set(value):
		oxygen = clampf(value, 0.0, 100.0)
		changed.emit()
@export_range(0.0, 100.0, 1.0) var food: float = 100.0:
	set(value):
		food = clampf(value, 0.0, 100.0)
		changed.emit()
@export_range(0.0, 100.0, 1.0) var drink: float = 100.0:
	set(value):
		drink = clampf(value, 0.0, 100.0)
		changed.emit()

@export_group("Stamina")
## Percentage points per second of actual sprint movement.
@export_range(0.0, 100.0, 1.0) var sprint_drain: float = 20.0
@export_range(0.0, 100.0, 1.0) var recovery_rate: float = 15.0
@export_range(0.0, 5.0, 0.1) var recovery_delay: float = 1.0
## Prevent repeated sprint/walk switching when the bar has just emptied.
@export_range(1.0, 100.0, 1.0) var sprint_resume_threshold: float = 20.0
@export_range(0.0, 100.0, 1.0) var stamina: float = 100.0:
	set(value):
		stamina = clampf(value, 0.0, 100.0)
		if stamina <= 0.0:
			_exhausted = true
		elif stamina >= sprint_resume_threshold:
			_exhausted = false
		changed.emit()

@export_group("Charge")
## Percentage points per second while the jetpack is firing.
@export_range(0.0, 100.0, 1.0) var jetpack_drain: float = 25.0
@export_range(0.0, 100.0, 1.0) var charge_ground_recovery: float = 20.0
@export_range(0.0, 100.0, 0.5) var charge_air_recovery: float = 3.0
## Avoid rapidly pulsing the jetpack on tiny amounts of recovered charge.
@export_range(1.0, 100.0, 1.0) var jetpack_resume_threshold: float = 10.0
@export_range(0.0, 100.0, 1.0) var charge: float = 100.0:
	set(value):
		charge = clampf(value, 0.0, 100.0)
		if charge <= 0.0:
			_charge_depleted = true
		elif charge >= jetpack_resume_threshold:
			_charge_depleted = false
		changed.emit()


func can_sprint() -> bool:
	return stamina > 0.0 and not _exhausted


func update_stamina(delta: float, sprinting: bool) -> void:
	if sprinting:
		stamina -= sprint_drain * delta
		_recovery_remaining = recovery_delay
	else:
		# Only recover for the part of this frame after the delay has elapsed.
		var recovery_delta := maxf(0.0, delta - _recovery_remaining)
		_recovery_remaining = maxf(0.0, _recovery_remaining - delta)
		if stamina < 100.0 and recovery_delta > 0.0:
			stamina += recovery_rate * recovery_delta


func can_use_jetpack() -> bool:
	return charge > 0.0 and not _charge_depleted


## Returns the powered duration, so a nearly empty battery cannot grant free thrust.
func use_jetpack(delta: float) -> float:
	if not can_use_jetpack():
		return 0.0
	var powered_time := delta
	if jetpack_drain > 0.0:
		powered_time = minf(delta, charge / jetpack_drain)
	charge -= jetpack_drain * powered_time
	return powered_time


func recover_charge(delta: float, grounded: bool) -> void:
	if charge < 100.0:
		var rate := charge_ground_recovery if grounded else charge_air_recovery
		charge += rate * delta
