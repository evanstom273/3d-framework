@tool
class_name FurniturePart
extends Resource
## A moving part of a furniture piece (a door, drawer, lid or flap): its own
## voxel model on the same grid as the piece's body, and how it moves. Built
## onto the body at spawn by FurnitureAssembly.

enum Kind { HINGE, SLIDE }

@export var label: String = "Door"
@export var kind: Kind = Kind.HINGE
## The part's voxels. Its .vox shares the body's grid size, so the part sits at
## the body's origin and lines up exactly.
@export var structure: VoxelStructureDefinition
## Hinge line point, or slide start, in the body's local space (metres).
@export var pivot: Vector3 = Vector3.ZERO
## Hinge axis, or slide direction (unit vector, body space).
@export var axis: Vector3 = Vector3.UP
## Degrees for a hinge (sign gives the direction), metres for a slide.
@export var amount: float = 100.0
