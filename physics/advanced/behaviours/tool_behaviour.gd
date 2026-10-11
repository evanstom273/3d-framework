class_name ToolBehaviour
extends RefCounted
## What one category of advanced tool does with its input. The runtime handles
## binding, aiming, the prompt and feedback; behaviours only decide actions.
## Subclasses override what they need.

var runtime: AdvancedToolRuntime
var action: ToolActionDefinition
var mode: int = 0


static func create(operation: String) -> ToolBehaviour:
	match operation:
		"heat", "saw", "grind", "pry", "shovel":
			return CutterBehaviour.new()
		"blow", "wash", "extinguish", "vacuum", "magnet", "paint":
			return SprayBehaviour.new()
		"glue", "sealant", "staple", "screw":
			return FastenBehaviour.new()
		"weld", "rope", "chain", "cable", "spring", "elastic", "hinge":
			return LinkBehaviour.new()
		"nail", "plunger":
			return LauncherBehaviour.new()
		"grabber":
			return GrabberBehaviour.new()
		"marker", "foam":
			return BuilderBehaviour.new()
	return ToolBehaviour.new()


func setup(owner_runtime: AdvancedToolRuntime) -> void:
	runtime = owner_runtime
	action = owner_runtime.action


func press() -> void:
	pass


func release() -> void:
	pass


func secondary() -> void:
	pass


## Q pressed. Return true if the tool has modes.
func cycle_mode() -> bool:
	return false


## Mouse wheel while equipped. Return true if used.
func scroll(_direction: int) -> bool:
	return false


func tick(_delta: float) -> void:
	pass


## Extra input (grabber passes MMB/wheel to the hand). Return true if used.
func extra_input(_event: InputEvent) -> bool:
	return false


## Whether the tool is visibly working (use pose, running sound, effects).
func is_working() -> bool:
	return runtime.held


## Status after the tool name, e.g. "Rope · 2.0 m".
func detail() -> String:
	return action.verb


func hints() -> String:
	return "%s   %s" % [action.primary_hint, action.secondary_hint]


## Lines to draw for the preview (pairs of world points), or empty for none.
func preview_lines() -> PackedVector3Array:
	return PackedVector3Array()


## Where contact effects should appear this frame, or {} for none.
func contact() -> Dictionary:
	return {}


func unbind() -> void:
	pass
