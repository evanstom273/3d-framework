@tool
class_name ToolMaterialProfile
extends Resource
## Advanced responses are independent of the established impact multipliers.
@export var heat_response: float = 0.0
@export var saw_response: float = 0.0
@export var grind_response: float = 0.0
@export var dig_response: float = 0.0
@export var magnetic: bool = false
@export var fastening: bool = true
@export var weldable: bool = false
@export var stapleable: bool = false
@export var cooling_rate: float = 0.2

func response(operation: StringName) -> float:
	match operation:
		&"heat": return heat_response
		&"saw": return saw_response
		&"grind": return grind_response
		&"dig": return dig_response
	return 0.0
