extends Node3D
## Physics prototyping space. R returns every prop to where it started.

## How exaggerated physics feels here. Swap for grounded.tres or chaotic.tres
## (res://physics/feel/) or make your own PhysicsFeel resource.
@export var physics_feel: PhysicsFeel = preload("res://physics/feel/playful.tres")


func _ready() -> void:
	PhysicsFeel.set_active(physics_feel)
	# Q: spawn menu, G: random spawn. Added last so it sees input before the player.
	add_child(SpawnMenu.new())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_playground"):
		get_tree().call_group(&"tool_handlers", &"drop")
		get_tree().call_group(&"object_manipulators", &"release")
		get_tree().call_group(&"physics_props", &"reset_to_spawn")
		get_viewport().set_input_as_handled()
