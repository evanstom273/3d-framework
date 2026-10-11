@tool
class_name ToolActionDefinition
extends Resource
## How an advanced tool behaves and feels. Shared by every copy of the tool; all
## changing state (selection, charge, contents) lives on the equipped tool's runtime.

enum Effect { NONE, FLAME, SPARKS, WATER, MIST, AIR, INTAKE, PAINT, FOAM, GLUE, SEALANT, BEAM, SAWDUST, DUST, SMOKE }
enum LoopSound { NONE, MOTOR, WHINE, HISS, SPRAY, ROAR, HUM, BUZZ }
enum ShotSound { NONE, CLICK, THUNK, POP, ZAP }

@export_enum("heat", "saw", "grind", "wash", "glue", "weld", "nail", "screw", "staple", "sealant", "rope", "chain", "cable", "spring", "elastic", "hinge", "extinguish", "blow", "vacuum", "magnet", "grabber", "shovel", "paint", "marker", "foam", "plunger", "pry") var operation: String = "heat"
## Short verb shown in the prompt, e.g. "Cut" or "Spray".
@export var verb: String = "Use"
@export var primary_hint: String = "Hold LMB: use"
@export var secondary_hint: String = "RMB: cancel"

@export_group("Reach and strength")
@export var range_metres: float = 3.0
@export var rate: float = 18.0
@export var force: float = 120.0
## Damage region for cutting tools, oriented like the tool (X width, Y height, Z depth).
@export var region_size: Vector3 = Vector3(0.12, 0.12, 0.16)
@export var cone_degrees: float = 20.0
@export var mass_limit: float = 80.0
@export var dwell_seconds: float = 0.7
@export var projectile_speed: float = 30.0
@export var probe_depth: float = 0.2
@export var rest_length: float = 2.0

@export_group("Tool geometry")
## Where effects and projectiles leave the tool, in the tool's local space.
@export var nozzle: Vector3 = Vector3(0, 0.1, -0.35)
## Spinning or running part (drill bit, grinder disc, chainsaw chain), local space.
@export var moving_part_position: Vector3 = Vector3(0, 0.1, -0.3)

@export_group("Feel")
## Particle effect streaming from the nozzle while in use.
@export var effect: Effect = Effect.NONE
## Particle effect where the tool meets a surface (sawdust, sparks...).
@export var contact_effect: Effect = Effect.NONE
@export var effect_color: Color = Color(1, 0.55, 0.1)
@export var loop_sound: LoopSound = LoopSound.NONE
## Pitch of the running sound (1 = the sound type's natural pitch).
@export_range(0.25, 4.0, 0.05) var sound_pitch: float = 1.0
@export var shot_sound: ShotSound = ShotSound.NONE
@export var sound_volume_db: float = -8.0
## Motors idle quietly while the tool is equipped and rev when used.
@export var idles: bool = false
## Hand vibration while in use (metres).
@export_range(0.0, 0.02, 0.0005) var use_shake: float = 0.0
## Recoil per shot (0 = none, 1 = strong).
@export_range(0.0, 2.0, 0.05) var shot_kick: float = 0.0
## Glow from the nozzle while in use (flame, welding arc). Alpha 0 = none.
@export var light_color: Color = Color(0, 0, 0, 0)

@export_group("Connections")
@export var connection: ConnectionDefinition

@export_group("Vacuum")
@export var cargo_items: int = 24
@export var cargo_mass: float = 5.0
@export var cargo_volume: float = 0.01

@export_group("Foam and markers")
@export var foam_hardening: float = 1.5
@export var foam_lifetime: float = 180.0
@export var colors: PackedColorArray = PackedColorArray([Color(0.8, 0.12, 0.1), Color(0.15, 0.4, 0.8), Color(0.9, 0.75, 0.12), Color(0.9, 0.9, 0.85)])
@export var label_text: String = "TEST"

## Legacy fields kept so older resources still load.
@export_group("Legacy")
@export var sound_frequency: float = 90.0
