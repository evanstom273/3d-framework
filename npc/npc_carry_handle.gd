class_name NPCCarryHandle
extends RigidBody3D
## The body you actually hold when you pick an NPC up. Grabbing any part of the
## NPC grabs this instead (ObjectManipulator asks NPCCharacter.get_grab_proxy),
## and the NPC's whole posed body rides on it, so it's one stable thing in your
## hands rather than a flailing chain of limbs.
##
## While not held it's inert (no collision, no gravity) and just follows the NPC.

## Carried weight: light enough to lift (the grab limit is 80 kg).
const CARRY_MASS := 45.0

var npc: NPCCharacter
var _shape: CollisionShape3D
var _held := false


func _init(owner: NPCCharacter) -> void:
	npc = owner
	name = "CarryHandle"
	top_level = true
	mass = CARRY_MASS
	gravity_scale = 0.0
	collision_layer = 0
	collision_mask = 0
	can_sleep = false
	continuous_cd = true
	_shape = CollisionShape3D.new()
	_shape.shape = CapsuleShape3D.new()
	_shape.disabled = true
	add_child(_shape)


## Sets the collider: a standing capsule, or a ball round a limp body, centred
## at `centre` (local): the handle itself sits wherever he was grabbed.
func shape_for(standing: bool, centre: Vector3) -> void:
	if standing:
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.24
		capsule.height = 1.8
		_shape.shape = capsule
	else:
		var ball := SphereShape3D.new()
		ball.radius = 0.4
		_shape.shape = ball
	_shape.position = centre


func set_active(active: bool) -> void:
	_held = active
	_shape.disabled = not active
	collision_layer = 16 if active else 0
	collision_mask = 31 if active else 0
	gravity_scale = 1.0 if active else 0.0
	if not active:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


## Inert: just follow the NPC (so the grab system has something to aim at).
func follow(where: Transform3D) -> void:
	if not _held:
		global_transform = where
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


# --- The grab contract (ObjectManipulator)

func can_be_grabbed() -> bool:
	return is_instance_valid(npc) and npc.can_be_carried()


func get_grab_name() -> String:
	return npc.definition.display_name if is_instance_valid(npc) else "Someone"


func get_carried_mass(_depth: int = 0) -> float:
	return CARRY_MASS


func is_held() -> bool:
	return _held


func on_grabbed(_holder: Node) -> void:
	npc.start_carry(self)


func on_released(_holder: Node, thrown: bool) -> void:
	npc.end_carry(self, thrown)
