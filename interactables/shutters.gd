extends "res://interaction_target.gd"

@onready var left_hinge: AnimatableBody3D = $LeftHinge
@onready var right_hinge: AnimatableBody3D = $RightHinge

var _is_open: bool = false
var _left_closed_angle: float
var _right_closed_angle: float


func _ready() -> void:
	_left_closed_angle = left_hinge.rotation.y
	_right_closed_angle = right_hinge.rotation.y


func get_interaction_actions() -> Array[Dictionary]:
	return [_action(&"close", "Close")] if _is_open else [_action(&"open", "Open")]


func perform_interaction_action(action_id: StringName, _actor: Node) -> void:
	if not _action_available(action_id):
		return
	_is_open = action_id == &"open"
	var angle := deg_to_rad(100.0) if _is_open else 0.0
	var motion := _begin_animation().set_parallel(true)
	motion.tween_property(left_hinge, "rotation:y", _left_closed_angle - angle, animation_duration)
	motion.tween_property(right_hinge, "rotation:y", _right_closed_angle + angle, animation_duration)
