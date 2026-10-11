class_name ConnectionRecord
extends RefCounted
var a: AttachmentPoint
var b: AttachmentPoint
var definition: ConnectionDefinition
var axis: Vector3 = Vector3.UP
var damage: float = 0.0
var overload: float = 0.0
var age: float = 0.0
var strand: ToolStrand
var joint_key: String = ""
var rest_separation: Vector3
var rest_rotation: Quaternion

func valid() -> bool:
	return a.valid() and b.valid() and a.body() != b.body()

func remaining_strength() -> float:
	return definition.strength * clampf(1.0 - damage / maxf(definition.removal_resistance, 0.01), 0, 1)
