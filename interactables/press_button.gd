extends "res://interaction_target.gd"

signal pressed

@onready var plunger: AnimatableBody3D = $Plunger

var _rest_height: float


func _ready() -> void:
	_rest_height = plunger.position.y


func get_interaction_actions() -> Array[Dictionary]:
	return [_action(&"press", "Press")]


func perform_interaction_action(action_id: StringName, _actor: Node) -> void:
	if not _action_available(action_id):
		return
	var motion := _begin_animation()
	motion.tween_property(plunger, "position:y", _rest_height - 0.06, animation_duration * 0.4)
	motion.tween_property(plunger, "position:y", _rest_height, animation_duration * 0.6)
	pressed.emit()
