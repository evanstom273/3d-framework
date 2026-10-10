extends "res://interaction_target.gd"

@export var pulled_angle_degrees: float = -35.0

@onready var handle: AnimatableBody3D = $Handle

var _pulled: bool = false
var _reset_angle: float


func _ready() -> void:
	_reset_angle = handle.rotation.x


func get_interaction_actions() -> Array[Dictionary]:
	return [_action(&"reset", "Reset")] if _pulled else [_action(&"pull", "Pull")]


func perform_interaction_action(action_id: StringName, _actor: Node) -> void:
	if not _action_available(action_id):
		return
	_pulled = action_id == &"pull"
	var angle := deg_to_rad(pulled_angle_degrees) if _pulled else _reset_angle
	_begin_animation().tween_property(handle, "rotation:x", angle, animation_duration)
