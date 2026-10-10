class_name ToolImpact
extends RefCounted
## One tool strike. Anything struck can implement receive_tool_impact(impact) on its
## collider or an ancestor to react (e.g. voxel destruction using position, damage
## and impact_type). Set `handled` there to suppress the default rigid-body impulse.

var tool: RigidBody3D
var tool_definition: PhysicsToolDefinition
var user: Node
var collider: Object
var position: Vector3
var normal: Vector3
## Unit direction the struck object is pushed.
var direction: Vector3
## Impulse applied to a struck rigid body (zero for static geometry).
var impulse: Vector3
## Speed of the tool's strike point at the moment of contact (m/s).
var strike_speed: float = 0.0
## Charge power the strike was made with (already applied to impulse and damage).
var power: float = 1.0
var damage: float = 0.0
var impact_type: PhysicsToolDefinition.ImpactType = PhysicsToolDefinition.ImpactType.BLUNT
var handled: bool = false
## Receivers may set this to tint the impact particles (e.g. the struck material).
var feedback_color: Color = Color(0, 0, 0, 0)
## Receivers may set an ImpactFeedback.Sound for the struck material (-1 = unset).
var feedback_sound: int = -1
