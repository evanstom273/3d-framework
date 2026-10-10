@tool
class_name PhysicsProp
extends RigidBody3D
## Rigid-body prop built from a PhysicsObjectDefinition, carryable by ObjectManipulator
## and, when the definition has a tool, equippable through ToolHandler.
## The definition is the source of truth: its shapes, meshes and details are built as
## internal children (previewed in the editor, never saved into scenes), and its
## mass, damping, material and layers replace this body's own values at runtime.
## Per-instance runtime state (hand state, contents, spawn point) lives here, so
## any number of props can share one definition independently.

enum HandState { WORLD, HELD, EQUIPPED }

@export var definition: PhysicsObjectDefinition:
	set(value):
		if definition == value:
			return
		if definition != null and definition.changed.is_connected(_apply_definition):
			definition.changed.disconnect(_apply_definition)
		definition = value
		if definition != null:
			definition.changed.connect(_apply_definition)
		if is_node_ready():
			_apply_definition()
		update_configuration_warnings()
## Props falling below this height return to where they started.
@export var respawn_below_y: float = -25.0

var hand_state: HandState = HandState.WORLD
var _built: Array[Node] = []
var _container: PhysicsContainer
var _spawn_transform: Transform3D
var _impact_memory: Dictionary = {}


## Creates a prop from code, e.g. for spawners: PhysicsProp.create(load("res://props/wooden_crate.tres")).
static func create(object_definition: PhysicsObjectDefinition) -> PhysicsProp:
	var prop := PhysicsProp.new()
	prop.definition = object_definition
	prop.name = object_definition.display_name.to_pascal_case()
	return prop


func _ready() -> void:
	_apply_definition()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	add_to_group(&"physics_props")
	_spawn_transform = global_transform


func can_be_grabbed() -> bool:
	return definition != null and definition.grabbable and not freeze


func get_grab_name() -> String:
	return definition.display_name if definition != null else str(name)


func is_held() -> bool:
	return hand_state == HandState.HELD


func get_impact_sound() -> int:
	return definition.impact_sound if definition != null else ImpactFeedback.Sound.GENERIC


func get_tool_definition() -> PhysicsToolDefinition:
	return definition.tool if definition != null else null


## Rigid bodies currently inside this prop, if it is a container.
func get_contents() -> Array[RigidBody3D]:
	if _container == null:
		var none: Array[RigidBody3D] = []
		return none
	return _container.get_contents()


## Own mass plus contents, used for carrying and throwing.
func get_carried_mass(depth: int = 0) -> float:
	if _container == null or not definition.container.contents_add_weight:
		return mass
	return mass + _container.get_contents_mass(depth)


## Extra line for the carry prompt.
func get_status_text() -> String:
	if _container == null:
		return ""
	var count := get_contents().size()
	if count == 0:
		return "empty"
	return "%d item%s, %.1f kg total" % [count, "" if count == 1 else "s", get_carried_mass()]


func on_grabbed(_holder: Node) -> void:
	hand_state = HandState.HELD


func on_released(_holder: Node, _thrown: bool) -> void:
	if hand_state == HandState.HELD:
		hand_state = HandState.WORLD


func on_equipped(_holder: Node) -> void:
	hand_state = HandState.EQUIPPED


func on_unequipped(_holder: Node) -> void:
	hand_state = HandState.WORLD


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false


func _physics_process(_delta: float) -> void:
	if global_position.y < respawn_below_y and hand_state == HandState.WORLD:
		reset_to_spawn()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if Engine.is_editor_hint() or definition == null:
		return
	ImpactBreaker.process(self, state, _impact_memory, definition.impact_damage_scale, hand_state != HandState.EQUIPPED)


func _apply_definition() -> void:
	for node in _built:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_built.clear()
	_container = null
	if definition == null:
		return
	for part in definition.get_collision_parts():
		var collision := CollisionShape3D.new()
		collision.shape = part["shape"]
		collision.transform = part["transform"]
		_add_built(collision)
	for part in definition.get_visual_parts():
		var mesh := MeshInstance3D.new()
		mesh.mesh = part["mesh"]
		mesh.transform = part["transform"]
		_add_built(mesh)
	if definition.detail_scene != null and not definition.uses_vox_model():
		_add_built(definition.detail_scene.instantiate())
	# Body values stay untouched in the editor so scenes are not saved with copies.
	if Engine.is_editor_hint():
		return
	mass = definition.mass
	physics_material_override = definition.get_physics_material()
	linear_damp = definition.linear_damp
	angular_damp = definition.angular_damp
	continuous_cd = definition.continuous_cd
	# Always on: even props that never break things still give impact feedback.
	contact_monitor = true
	max_contacts_reported = 4
	if hand_state != HandState.EQUIPPED:
		collision_layer = definition.collision_layer
		collision_mask = definition.collision_mask
	if definition.container != null:
		_container = PhysicsContainer.new()
		_container.name = "Container"
		_add_built(_container)
		_container.setup(self, definition.container)


func _add_built(node: Node) -> void:
	add_child(node, false, Node.INTERNAL_MODE_BACK)
	_built.append(node)


func _get_configuration_warnings() -> PackedStringArray:
	if definition == null:
		return ["Assign a PhysicsObjectDefinition to build this prop."]
	return []
