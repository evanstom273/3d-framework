@tool
class_name FurnitureAssembly
extends Node3D
## The moving parts of one furniture piece: doors, drawers and lids built from
## its structure's moving_parts, each a voxel body on a hinge or slide that the
## player opens through a KitMechanism (E menu; the crowbar pries them too).
##
## Layout under the piece's VoxelBody:
##   Body (VoxelBody, the carcass)
##     Assembly (this)
##       Part0 (KitMechanism)  -> Pivot (mover) -> Leaf (frozen VoxelBody)
##
## Leaves are frozen (static) children, so they ride along when the piece is carried
## or thrown, and never push their own carcass. A leaf whose mounting is smashed
## (its hinge edge, or the carcass around it) falls off as a free piece.

## A leaf comes off when it loses this share of its voxels.
const LOSS_LIMIT := 0.5
## Voxels either side of the hinge line that count as its mounting.
const MOUNT_CELLS := 2

var body: VoxelBody
var _links: Array[Dictionary] = []
var _queued: bool = false


## Adds the moving parts to a freshly built body (replacing any earlier ones).
static func build(target: VoxelBody) -> void:
	var old := target.get_node_or_null(^"Assembly")
	if old != null:
		if old is FurnitureAssembly:
			old.free_parts()
		target.remove_child(old)
		old.queue_free()
	if target.structure == null or target.structure.moving_parts.is_empty():
		return
	var assembly := FurnitureAssembly.new()
	assembly.name = "Assembly"
	assembly.body = target
	target.add_child(assembly, false, Node.INTERNAL_MODE_BACK)
	for index in target.structure.moving_parts.size():
		var part: FurniturePart = target.structure.moving_parts[index]
		if part != null and part.structure != null:
			assembly._add_part(part, index)
	target.geometry_changed.connect(assembly._queue_check)
	# Baked parts are used once; a reset rebuilds them normally.
	target.baked_parts = []


func _add_part(part: FurniturePart, index: int) -> void:
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.position = part.pivot
	if Engine.is_editor_hint():
		# KitMechanism doesn't run in the editor: just show the part, closed.
		pivot.name = "Part%d" % index
		add_child(pivot)
		var shown := VoxelBody.new()
		shown.structure = part.structure
		shown.position = -part.pivot
		pivot.add_child(shown)
		return
	var mechanism := KitMechanism.new()
	mechanism.name = "Part%d" % index
	mechanism.interaction_name = part.label
	mechanism.lockable = false
	mechanism.duration = 0.45 if part.kind == FurniturePart.Kind.HINGE else 0.35
	add_child(mechanism)
	mechanism.add_child(pivot)
	var leaf := VoxelBody.new()
	leaf.name = "Leaf"
	leaf.distance_culled = true
	leaf.hold_when_split = true
	# Built off the main thread with the body when it was baked (see VoxelBody.bake).
	var baked: Dictionary = body.baked_parts[index] if index < body.baked_parts.size() else {}
	if not baked.is_empty() and baked["structure"] == part.structure:
		leaf.apply_baked(baked)
	else:
		leaf.structure = part.structure
	# The part's grid is the body's grid, so its origin is the body's origin.
	leaf.position = -part.pivot
	leaf.set(&"_spawned", true)
	pivot.add_child(leaf)
	# Static, not kinematic: a moved kinematic body sweeps at the speed of the
	# jump (a piece placed after spawning would smash whatever it passed).
	leaf.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	leaf.freeze = true
	leaf.add_collision_exception_with(body)
	body.add_collision_exception_with(leaf)
	var open := Transform3D(Basis.IDENTITY, part.pivot + part.axis * part.amount)
	if part.kind == FurniturePart.Kind.HINGE:
		open = Transform3D(Basis(part.axis.normalized(), deg_to_rad(part.amount)), part.pivot)
	mechanism.add_mover(pivot, mechanism.add_group(""), {"open": [Transform3D(Basis.IDENTITY, part.pivot), open]})
	var link := {"part": part, "mechanism": mechanism, "leaf": leaf, "cells": leaf.cells.size(), "attached": true}
	_links.append(link)
	leaf.geometry_changed.connect(_queue_check)


func _queue_check() -> void:
	if not _queued and not Engine.is_editor_hint():
		_queued = true
		_check.call_deferred()


## Drops any leaf whose hinge edge, or the carcass where it's fixed, is gone.
func _check() -> void:
	_queued = false
	for link in _links:
		if not link["attached"]:
			continue
		var leaf: VoxelBody = link["leaf"]
		if not is_instance_valid(leaf) or leaf.cells.is_empty():
			_release(link)
			continue
		var part: FurniturePart = link["part"]
		if leaf.cells.size() <= int(link["cells"]) * (1.0 - LOSS_LIMIT):
			_release(link)
			continue
		var region := _mount_region(part, leaf)
		if not leaf.has_cells_in(region) or not body.has_cells_in(region.grow(body.voxel_size * MOUNT_CELLS)):
			_release(link)


## Body-space box around where the part is fixed: the hinge line for a hinge,
## the whole closed part for a slide.
func _mount_region(part: FurniturePart, leaf: VoxelBody) -> AABB:
	var bounds := leaf.get_cell_bounds()
	var box := AABB(bounds.position * leaf.voxel_size, bounds.size * leaf.voxel_size)
	if part.kind == FurniturePart.Kind.SLIDE:
		return box
	var reach := leaf.voxel_size * MOUNT_CELLS
	var low := box.position
	var high := box.end
	# Clamp the box to a thin slab along the hinge line.
	for a in 3:
		if absf(part.axis[a]) < 0.5:
			low[a] = maxf(low[a], part.pivot[a] - reach)
			high[a] = minf(high[a], part.pivot[a] + reach)
	return AABB(low, (high - low).max(Vector3.ZERO))


func _release(link: Dictionary) -> void:
	link["attached"] = false
	var mechanism: KitMechanism = link["mechanism"]
	if is_instance_valid(mechanism):
		mechanism._functional = false
		mechanism.interaction_actions_changed.emit()
	var leaf: VoxelBody = link["leaf"]
	if not is_instance_valid(leaf) or leaf.cells.is_empty():
		return
	# Out into the world as an ordinary broken piece.
	var world := body.get_parent()
	leaf.reparent(world, true)
	leaf.remove_collision_exception_with(body)
	body.remove_collision_exception_with(leaf)
	leaf.freeze = false
	leaf.sleeping = false
	leaf.linear_velocity = body.linear_velocity


## Frees leaves still attached (a rebuild or reset makes new ones).
func free_parts() -> void:
	for link in _links:
		if link["attached"] and is_instance_valid(link["leaf"]):
			link["leaf"].queue_free()
	_links.clear()
