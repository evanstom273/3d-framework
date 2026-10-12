@tool
class_name NPCDefinition
extends Resource
## Everything that makes one kind of NPC: its voxel body parts, how it moves,
## how tough it is, what it carries and what it says. Spawned as an
## NPCCharacter (also from the spawn menu's NPCs tab).

@export var display_name: String = "NPC"
## Body parts, the torso (root) first. Part names drive the animation:
## head, torso, upper_arm_r/l, forearm_r/l, thigh_r/l, shin_r/l.
@export var parts: Array[NPCPart] = []

@export_group("Movement")
@export_range(0.2, 4.0, 0.05, "suffix:m/s") var walk_speed: float = 1.1
@export_range(0.5, 8.0, 0.05, "suffix:m/s") var run_speed: float = 3.4
## How far from its spawn point it wanders.
@export_range(1.0, 40.0, 0.5, "suffix:m") var wander_radius: float = 6.0

@export_group("Toughness")
## A vital part losing this share of its voxels kills the NPC.
@export_range(0.05, 1.0, 0.01) var vital_loss_limit: float = 0.45
## A hit stronger than this (impulse, N·s) knocks it over.
@export_range(1.0, 400.0, 1.0) var knockdown_impulse: float = 45.0
## Seconds lying still before getting back up.
@export_range(0.2, 10.0, 0.1, "suffix:s") var get_up_delay: float = 1.6

@export_group("Held prop")
@export var held_prop: VoxelStructureDefinition
## The part holding it, and the prop's transform in the NPC's shared space.
@export var held_by: String = "forearm_r"
@export var held_transform: Transform3D = Transform3D.IDENTITY

@export_group("Barks")
## Lines per occasion: hit, limb, knocked, up, flee, death, look, talk.
@export var barks: Dictionary = {}
