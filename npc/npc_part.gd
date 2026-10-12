@tool
class_name NPCPart
extends Resource
## One body part of an NPC: its voxels and the joint it hangs from. All of an
## NPC's parts share one model grid, so each part's body sits at the NPC's
## origin and `pivot` is given in that shared space (metres, feet at y = 0,
## facing -Z).

@export var name: String = ""
@export var structure: VoxelStructureDefinition
## Index of the part this one hangs from (-1 for the root, the torso).
@export var parent: int = -1
## The joint: where this part turns relative to its parent.
@export var pivot: Vector3 = Vector3.ZERO
## Wrecking or losing a vital part (head, torso) kills the NPC.
@export var vital: bool = false
## Ragdoll joint limits.
@export_range(0.0, 180.0, 1.0, "suffix:°") var swing_limit: float = 60.0
@export_range(0.0, 180.0, 1.0, "suffix:°") var twist_limit: float = 20.0
