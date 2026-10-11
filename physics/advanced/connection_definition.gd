@tool
class_name ConnectionDefinition
extends Resource
enum Kind { RIGID, HINGE, SEALANT, ROPE, CHAIN, CABLE, SPRING, ELASTIC, SUCTION }
@export var display_name: String = "Connection"
@export var kind: Kind = Kind.RIGID
@export var strength: float = 800.0
@export var torque_resistance: float = 80.0
@export var overload_duration: float = 0.2
@export var removal_resistance: float = 20.0
@export var maximum_gap: float = 0.16
@export var maximum_length: float = 12.0
@export var hinge_limit_degrees: float = 90.0
@export var compliance: float = 0.00001
@export var damping: float = 0.15
@export var strand_mass_per_metre: float = 0.15
@export var radius: float = 0.018
@export var maximum_stretch: float = 3.0
@export var color: Color = Color(0.65, 0.48, 0.28)
@export var lifetime: float = 0.0
@export var metal_only: bool = false
@export var soft_only: bool = false

func is_strand() -> bool:
	return kind in [Kind.ROPE, Kind.CHAIN, Kind.CABLE, Kind.SPRING, Kind.ELASTIC]
