extends "res://interaction_target.gd"
## Used by both the door and the independently targeted window glass.

@export var open_angle_degrees: float = -90.0

@onready var hinge: Node3D = $Hinge

var _is_open: bool = false
var _locked: bool = false
var _closed_angle: float


func _ready() -> void:
	_closed_angle = hinge.rotation.y


func get_interaction_prompt() -> String:
	return interaction_name + (" (locked)" if _locked else "")


func get_interaction_actions() -> Array[Dictionary]:
	if _is_open:
		return [_action(&"close", "Close")]
	if _locked:
		return [_action(&"unlock", "Unlock")]
	return [_action(&"open", "Open"), _action(&"lock", "Lock")]


func perform_interaction_action(action_id: StringName, _actor: Node) -> void:
	if not _action_available(action_id):
		return
	match action_id:
		&"lock":
			_locked = true
			interaction_actions_changed.emit()
			return
		&"unlock":
			_locked = false
			interaction_actions_changed.emit()
			return
		&"open":
			_is_open = true
		&"close":
			_is_open = false
	var angle := _closed_angle + (deg_to_rad(open_angle_degrees) if _is_open else 0.0)
	_begin_animation().tween_property(hinge, "rotation:y", angle, animation_duration)
