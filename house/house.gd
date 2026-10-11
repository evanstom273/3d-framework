extends Node3D

@export var physics_feel: PhysicsFeel = preload("res://physics/feel/playful.tres")


func _ready() -> void:
	PhysicsFeel.set_active(physics_feel)
	add_child(SpawnMenu.new())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_playground"):
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene.call_deferred()
