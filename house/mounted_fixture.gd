extends Node3D
## Supplies a built-in cabinet/appliance's explicit floor or wall mounting.

@export var support_path: NodePath
@export var support_region: AABB


func _ready() -> void:
	if not support_path.is_empty():
		$Attachment.support_path = NodePath("../" + String(support_path))
		$Attachment.support_region = support_region
