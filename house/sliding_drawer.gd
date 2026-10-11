extends "res://interaction_target.gd"

@export var travel: Vector3 = Vector3(0, 0, -0.4)
@export var support_path: NodePath
@export var support_region: AABB

var _is_open: bool = false
var _functional: bool = true
var _closed: Vector3
var _motion: Tween


func _ready() -> void:
	_closed = $Slide.position
	set_physics_process(false)
	var attachment := $Attachment as HouseFixtureAttachment
	if not support_path.is_empty():
		attachment.support_path = NodePath("../" + String(support_path))
		attachment.support_region = support_region
	attachment.released.connect(_on_released)


func get_interaction_actions() -> Array[Dictionary]:
	if not _functional:
		return []
	return [_action(&"close", "Close")] if _is_open else [_action(&"open", "Open")]


func perform_interaction_action(action_id: StringName, _actor: Node) -> void:
	if not _action_available(action_id):
		return
	_is_open = action_id == &"open"
	_motion = _begin_animation()
	_motion.tween_property($Slide, "position", _closed + (travel if _is_open else Vector3.ZERO), animation_duration)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	$Attachment.sync_pose()


func _finish_animation() -> void:
	$Attachment.sync_pose()
	set_physics_process(false)
	super()


func _on_released() -> void:
	_functional = false
	_busy = false
	if _motion != null and _motion.is_valid():
		_motion.kill()
	set_physics_process(false)
	interaction_actions_changed.emit()
