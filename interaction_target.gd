extends Node3D
## Subclasses expose {id, label, enabled} actions and implement their execution.
## The existing raycast resolves these nodes; the player supplies the shared menu.

signal interaction_actions_changed

@export var interaction_name: String = "Interactable"
@export_range(0.05, 2.0, 0.01) var animation_duration: float = 0.35

var _busy: bool = false


func get_interaction_prompt() -> String:
	return interaction_name


func get_interaction_actions() -> Array[Dictionary]:
	return []


func perform_interaction_action(_action_id: StringName, _actor: Node) -> void:
	pass


func can_interact() -> bool:
	return not get_interaction_actions().is_empty()


func interact(actor: Node) -> void:
	actor.call("open_interaction_menu", self)


func _action(action_id: StringName, label: String) -> Dictionary:
	return {"id": action_id, "label": label, "enabled": not _busy}


func _action_available(action_id: StringName) -> bool:
	for action in get_interaction_actions():
		if action["id"] == action_id and action.get("enabled", true):
			return true
	return false


func _begin_animation() -> Tween:
	_busy = true
	interaction_actions_changed.emit()
	var motion := create_tween()
	motion.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.finished.connect(_finish_animation)
	return motion


func _finish_animation() -> void:
	_busy = false
	interaction_actions_changed.emit()
