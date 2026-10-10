@tool
class_name PhysicsToolDefinition
extends Resource
## Makes a physics object equippable. Poses are in view space (metres, degrees;
## -Z forward, +X right, +Y up) and describe where the hand is; the grip says where
## the hand holds the tool, in the tool's own local space.

enum Category { STRIKING, UTILITY }
enum PrimaryAction {
	## Wind up, strike, recover; hits land under the crosshair (or along the tool's path).
	SWING,
	## Places a voxel where the crosshair points (on a voxel face or a surface).
	## Holding the button keeps placing, one per action cycle.
	PLACE_VOXEL,
}
## How a strike hurts voxels: materials take more or less damage per type
## (an axe chops wood, a pickaxe chews stone). SWEEP counts as blunt.
enum ImpactType { BLUNT, SWEEP, SHARP, PIERCE }
enum HitDetection {
	## Hits whatever is under the crosshair within `reach`, at the impact moment of the swing.
	CROSSHAIR,
	## Hits only what the tool's strike point physically sweeps through.
	TOOL_PATH,
}
enum AimMode {
	## Impulses go where the player looks.
	VIEW_FORWARD,
	## Impulses go where the player faces, ignoring look pitch (good for ground shots).
	VIEW_FORWARD_FLAT,
}

@export var category: Category = Category.STRIKING
@export var primary_action: PrimaryAction = PrimaryAction.SWING
@export var action_name: String = "Swing"

@export_group("Grip")
## Where the hand holds the tool, in the tool's local space.
@export var grip_position: Vector3 = Vector3.ZERO
## Rotates the tool within the hand.
@export var grip_rotation_degrees: Vector3 = Vector3.ZERO
## How much the held tool follows looking up and down. Use 0 for tools aimed at the
## ground such as a golf club, so the head stays on the floor while you look at it.
@export_range(0.0, 1.0, 0.05) var pitch_follow: float = 1.0
@export_range(0.05, 1.0, 0.01, "suffix:s") var equip_time: float = 0.25

@export_group("Poses")
@export var rest_position: Vector3 = Vector3(0.28, -0.3, -0.45)
@export var rest_rotation_degrees: Vector3 = Vector3.ZERO
@export var windup_position: Vector3 = Vector3(0.28, -0.2, -0.35)
@export var windup_rotation_degrees: Vector3 = Vector3(40, 0, 0)
@export var strike_position: Vector3 = Vector3(0.22, -0.4, -0.6)
@export var strike_rotation_degrees: Vector3 = Vector3(-90, 0, 0)

@export_group("Timing")
@export_range(0.02, 2.0, 0.01, "suffix:s") var windup_time: float = 0.18
## Impacts are detected only during the strike.
@export_range(0.02, 1.0, 0.01, "suffix:s") var strike_time: float = 0.12
@export_range(0.02, 2.0, 0.01, "suffix:s") var recover_time: float = 0.25
## Extra pause after recovering before the next use.
@export_range(0.0, 2.0, 0.01, "suffix:s") var cooldown: float = 0.1

@export_group("Placing")
## PLACE_VOXEL: what new voxels are made of.
@export var place_material: VoxelMaterialDefinition
## PLACE_VOXEL: voxel size when starting a new structure (existing ones keep theirs).
@export_range(0.02, 1.0, 0.01, "suffix:m") var place_voxel_size: float = 0.1

@export_group("Charging")
## Seconds of holding the use button to reach full charge. The tool holds its windup
## pose while charging and strikes on release. Zero strikes instantly at max power.
@export_range(0.0, 3.0, 0.05, "suffix:s") var charge_time: float = 0.6
## Power of a quick tap.
@export_range(0.0, 3.0, 0.05) var min_charge_power: float = 0.3
## Power at full charge. Power scales the impulse, the launch speed cap and the damage.
@export_range(0.1, 3.0, 0.05) var max_charge_power: float = 1.0

@export_group("Motion Strikes")
## Swinging the equipped tool by moving the mouse (no button) hits whatever its
## strike point sweeps through, with power from how fast it moved.
@export var motion_strikes: bool = true
## Strike point speed (m/s, ignoring your own walking) below which nothing happens.
@export_range(0.5, 30.0, 0.5, "suffix:m/s") var motion_strike_min_speed: float = 5.0
## Strike point speed that gives max_charge_power.
@export_range(1.0, 60.0, 0.5, "suffix:m/s") var motion_strike_full_speed: float = 14.0
## Minimum time between motion strikes.
@export_range(0.0, 2.0, 0.01, "suffix:s") var motion_strike_cooldown: float = 0.25

@export_group("Impact")
@export var hit_detection: HitDetection = HitDetection.CROSSHAIR
## CROSSHAIR: how far from the camera a strike can land.
@export_range(0.5, 6.0, 0.05, "suffix:m") var reach: float = 2.0
## CROSSHAIR: if the exact crosshair ray misses, a sphere this wide is tried, so
## near-misses on small objects still connect.
@export_range(0.0, 0.5, 0.01, "suffix:m") var aim_assist_radius: float = 0.12
## CROSSHAIR: when in the strike the hit lands (0 = start of strike, 1 = end).
@export_range(0.0, 1.0, 0.05) var impact_moment: float = 0.5
@export var impact_type: ImpactType = ImpactType.BLUNT
## The part of the tool that hits, in the tool's local space (e.g. a hammer head).
## Used for TOOL_PATH hits and for the swing speed reported on impacts.
@export var strike_point: Vector3 = Vector3(0, 0.15, 0)
## TOOL_PATH: radius of the swept sphere around the strike point.
@export_range(0.01, 0.5, 0.005, "suffix:m") var strike_radius: float = 0.08
## Impulse given to struck rigid bodies.
@export_range(0.0, 200.0, 0.5, "suffix:N·s") var impact_impulse: float = 20.0
## Caps the speed given to light objects so they are not launched absurdly.
@export_range(0.5, 60.0, 0.5, "suffix:m/s") var max_launch_speed: float = 10.0
@export var aim_mode: AimMode = AimMode.VIEW_FORWARD
## 0 sends struck objects along the aim; 1 along the strike point's actual path.
@export_range(0.0, 1.0, 0.05) var swing_path_influence: float = 0.5
## Raises the impulse direction above the aim, e.g. a golf club's loft.
@export_range(-45.0, 80.0, 1.0, "suffix:°") var loft_degrees: float = 0.0
## Stored on each impact for systems such as voxel destruction to interpret.
@export_range(0.0, 1000.0, 1.0) var damage: float = 10.0
## Radius of voxel damage at full power (scales with the square root of power).
## Zero means this tool doesn't break voxels.
@export_range(0.0, 2.0, 0.01, "suffix:m") var voxel_damage_radius: float = 0.15
## Layers a strike can hit. The tool and its user are always excluded.
@export_flags_3d_physics var hit_mask: int = 1 | 2 | 4 | 16


func get_total_action_time() -> float:
	return windup_time + strike_time + recover_time + cooldown
