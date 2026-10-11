extends "res://interactables/lockable_hinge.gd"
## The original hinge actions/poses, with voxel leaves outside the moving pivot.

@export var support_path: NodePath
@export var support_region: AABB
@export var allow_lock: bool = true

var _functional: bool = true
var _motion: Tween


func _ready() -> void:
	super()
	set_physics_process(false)
	var attachment := $Attachment as HouseFixtureAttachment
	if not support_path.is_empty():
		attachment.support_path = NodePath("../" + String(support_path))
		attachment.support_region = support_region
	attachment.released.connect(_on_released)


func get_interaction_actions() -> Array[Dictionary]:
	if not _functional:
		return []
	if not allow_lock:
		return [_action(&"close", "Close")] if _is_open else [_action(&"open", "Open")]
	return super()


func _begin_animation() -> Tween:
	_motion = super()
	set_physics_process(true)
	return _motion


func _physics_process(_delta: float) -> void:
	_sync_leaves()


func _sync_leaves() -> void:
	for child in get_children():
		if child is HouseFixtureAttachment:
			child.sync_pose()


func _finish_animation() -> void:
	_sync_leaves()
	set_physics_process(false)
	super()


func _on_released() -> void:
	_functional = false
	_busy = false
	if _motion != null and _motion.is_valid():
		_motion.kill()
	set_physics_process(false)
	for child in get_children():
		if child is HouseFixtureAttachment:
			child.release()
	interaction_actions_changed.emit()
