class_name KitMechanism
extends "res://interaction_target.gd"
## A reusable opening mechanism for doors, windows, gates and garage doors.
##
## A mechanism moves one or more *movers* (pivot nodes) through keyframed poses.
## Leaves, sashes and glass are voxel bodies fixed to movers by
## HouseFixtureAttachment, exactly like the house's hinged doors, so they still
## break, smash and fall out. What makes each opening type different is only the
## poses the builder gives it:
##   hinged      closed -> rotated about the hinge
##   sliding     closed -> translated along the track
##   folding     a chain of movers, each parented to the one before
##   tracks      many keyframes per mover (sectional garage panels, roller slats)
## Movers belong to *groups* that open independently (a stable door's halves).
## A group can have several *modes* (a tilt-and-turn window: "turn" or "tilt").
##
## Compatible with the existing systems: the crowbar calls force_open(), the
## window climber reads is_open(), and the interaction menu lists the actions.

class Group:
	var label: String = ""
	## Mode name -> button label. The first mode is the default.
	var modes: Dictionary = {}
	var mode: String = ""
	var progress: float = 0.0
	var target: float = 0.0


class Mover:
	var node: Node3D
	var group: int = 0
	## Mode name -> keyframes (local transforms of `node`), closed first.
	var poses: Dictionary = {}


var lockable: bool = true
## Seconds for a full open or close.
var duration: float = 0.6
## Powered openings (garage doors) run at a steady speed; manual ones ease.
var powered: bool = false
var groups: Array[Group] = []
var movers: Array[Mover] = []

## Kept as plain fields for compatibility with code that reads them directly.
var _is_open: bool = false
var _locked: bool = false
var _functional: bool = true


## Adds an independently operable group; returns its index.
func add_group(label: String, modes := {"open": "Open"}) -> int:
	var group := Group.new()
	group.label = label
	group.modes = modes
	group.mode = modes.keys()[0]
	groups.append(group)
	return groups.size() - 1


## Adds a mover node (already parented and placed at its closed pose) with
## keyframes per mode. Poses are local transforms of `node`.
func add_mover(node: Node3D, group: int, poses: Dictionary) -> Mover:
	var mover := Mover.new()
	mover.node = node
	mover.group = group
	mover.poses = poses
	movers.append(mover)
	return mover


func _ready() -> void:
	set_physics_process(false)
	for child in get_children():
		if child is HouseFixtureAttachment:
			child.released.connect(_on_leaf_released)


func is_open() -> bool:
	return _is_open


func is_locked() -> bool:
	return _locked


func get_interaction_prompt() -> String:
	return interaction_name + (" (locked)" if _locked else "")


func get_interaction_actions() -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	if not _functional:
		return actions
	if _locked:
		actions.append(_action(&"unlock", "Unlock"))
		return actions
	for index in groups.size():
		var group := groups[index]
		var suffix := "" if groups.size() == 1 else " " + group.label
		if group.target > 0.5:
			actions.append(_action(StringName("close:%d" % index), "Close" + suffix))
		else:
			for mode in group.modes:
				actions.append(_action(StringName("open:%d:%s" % [index, mode]), String(group.modes[mode]) + suffix))
	if lockable and not _is_open:
		actions.append(_action(&"lock", "Lock"))
	return actions


func perform_interaction_action(action_id: StringName, _actor: Node) -> void:
	if not _action_available(action_id):
		return
	var parts := String(action_id).split(":")
	match parts[0]:
		"lock":
			_locked = true
		"unlock":
			_locked = false
		"open":
			_move(int(parts[1]), parts[2], 1.0)
		"close":
			_move(int(parts[1]), groups[int(parts[1])].mode, 0.0)
	interaction_actions_changed.emit()


## Levered open with a crowbar: unlocks and opens every group, undamaged.
func force_open() -> bool:
	if not _functional or _is_open:
		return false
	_locked = false
	for index in groups.size():
		_move(index, groups[index].modes.keys()[0], 1.0)
	interaction_actions_changed.emit()
	return true


## Opens or closes everything (scripted use, e.g. a garage remote).
func set_open(open: bool) -> void:
	for index in groups.size():
		_move(index, groups[index].mode, 1.0 if open else 0.0)


func _move(index: int, mode: String, target: float) -> void:
	var group := groups[index]
	if group.progress <= 0.001 and group.mode != mode:
		group.mode = mode
	group.target = target
	_update_open_state()
	set_physics_process(true)


func _update_open_state() -> void:
	_is_open = false
	for group in groups:
		if group.target > 0.5 or group.progress > 0.02:
			_is_open = true


func _physics_process(delta: float) -> void:
	var moving := false
	var step := delta / maxf(duration, 0.05)
	for group in groups:
		if not is_equal_approx(group.progress, group.target):
			group.progress = move_toward(group.progress, group.target, step)
			moving = true
	for mover in movers:
		if is_instance_valid(mover.node):
			mover.node.transform = _pose(mover)
	for child in get_children():
		if child is HouseFixtureAttachment:
			child.sync_pose()
	_update_open_state()
	if not moving:
		set_physics_process(false)


func _pose(mover: Mover) -> Transform3D:
	var group := groups[mover.group]
	var frames: Array = mover.poses.get(group.mode, mover.poses.values()[0])
	if frames.size() == 1:
		return frames[0]
	var t := group.progress if powered else smoothstep(0.0, 1.0, group.progress)
	var at := t * (frames.size() - 1)
	var index := mini(floori(at), frames.size() - 2)
	var a: Transform3D = frames[index]
	var b: Transform3D = frames[index + 1]
	return a.interpolate_with(b, at - index)


## A leaf broke off its fixing. The rest keeps working; with none left the
## mechanism has nothing to move.
func _on_leaf_released() -> void:
	var attached := false
	for child in get_children():
		if child is HouseFixtureAttachment and child.attached:
			attached = true
	if not attached:
		_functional = false
	interaction_actions_changed.emit()


# --- Pose helpers for builders

## Rotation about a local axis through the mover's origin.
static func turned(axis: Vector3, degrees: float, at := Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis(axis.normalized(), deg_to_rad(degrees)), at)


## Keyframes along a door track: up the opening, round a curve of `radius`, then
## level inward (sectional garage doors), or wound round a drum (roller shutters).
## `start` is how far along the track this panel sits when closed; every panel
## travels `travel`. Returns poses for a mover whose frame is the track's at s=0.
static func track_poses(start: float, travel: float, top: float, radius: float, roll: bool, samples := 10) -> Array:
	var poses: Array = []
	for i in samples + 1:
		var s := start + travel * i / samples
		poses.append(_track_point(s, top, radius, roll))
	return poses


static func _track_point(s: float, top: float, radius: float, roll: bool) -> Transform3D:
	# Track coordinates: y up the opening from the sill, z inward (+Z, into the building).
	if s <= top:
		return Transform3D(Basis.IDENTITY, Vector3(0.0, s, 0.0))
	var beyond := s - top
	var angle := beyond / radius
	# A panel's own +Y (its leading edge) follows the track's direction of travel,
	# so it turns toward +Z (inward) round the curve and never sweeps outside.
	if not roll and angle >= PI * 0.5:
		# Level run inward under the ceiling.
		var along := beyond - radius * PI * 0.5
		return Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, top + radius, radius + along))
	if roll:
		# Spiral onto a drum in the shutter box, which sits outside (-Z) the head.
		var wraps := angle
		var r := radius * (1.0 - 0.04 * wraps / TAU)
		var centre := Vector3(0.0, top, -radius)
		return Transform3D(Basis(Vector3.RIGHT, -wraps), centre + Vector3(0.0, sin(wraps) * r, cos(wraps) * r))
	var c := Vector3(0.0, top, radius)
	return Transform3D(Basis(Vector3.RIGHT, angle), c + Vector3(0.0, sin(angle) * radius, -cos(angle) * radius))
