@tool
class_name KitOpening
extends Resource
## A door, window, gate or open doorway in a KitWall (or a gate in a KitFence).
## Positions are along the wall from its start (the piece origin) to the centre
## of the opening.
##
## Enum values are only ever appended, never reordered, so saved scenes keep
## their door and window types.

enum Kind { DOOR, WINDOW, OPEN_DOORWAY }
enum DoorStyle {
	FOUR_PANEL, SIX_PANEL, HALF_GLAZED, FULLY_GLAZED, LEDGED_PLANK, FLUSH,
	GLAZED_INTERIOR, SOLID_TIMBER, STABLE, DOUBLE, FRENCH, SLIDING_PATIO, POCKET, BIFOLD, BARN,
	GARAGE_UP_AND_OVER, GARAGE_SECTIONAL, ROLLER_SHUTTER, INDUSTRIAL_STEEL, LABORATORY,
	GATE_TIMBER, GATE_PICKET, GATE_SOLID, GATE_DOUBLE_DRIVEWAY, GATE_METAL, GATE_CHAIN_LINK,
	GATE_SLIDING, SHED_DOUBLE,
}
enum WindowStyle {
	CASEMENT, GEORGIAN_BARS, CASEMENT_WITH_TOP_LIGHT, FIXED,
	PICTURE, TOP_HUNG_AWNING, BOTTOM_HUNG_HOPPER, SLIDING_SASH, HORIZONTAL_SLIDER, TILT_AND_TURN,
	FULL_HEIGHT, GLAZED_WALL, BAY, BOW,
}
enum Head { SOLDIER_COURSE, STONE_LINTEL, STONE_KEYSTONE, NONE }
enum Shape { RECTANGLE, SQUARE, CIRCLE, OVAL, ARCHED, SEMICIRCLE, TRIANGLE, GABLE, TRAPEZOID, POLYGON }
enum Handle { LEVER, KNOB, PULL_BAR, NONE }
enum CornerGlazing { NONE, AT_START, AT_END }

const DOOR_ONLY := ["door_style", "hinge_left", "opens_inward", "door_color", "door_bottom_height", "handle", "powered"]
const WINDOW_ONLY := ["window_style", "panes", "sill_height", "shape", "panel_layout", "panel_widths", "transom_height",
	"top_light_layout", "glazing_bars", "glass_tint", "obscured", "projection", "corner"]

@export var kind: Kind = Kind.WINDOW:
	set(value):
		kind = value
		emit_changed()
		notify_property_list_changed()
## Distance along the wall from its start to the middle of the opening.
@export_range(0.0, 30.0, 0.05, "or_greater", "suffix:m") var position: float = 1.5:
	set(value):
		position = snappedf(value, 0.05)
		emit_changed()
## Structural opening width, including the frame.
@export_range(0.3, 9.0, 0.05, "suffix:m") var width: float = 1.2:
	set(value):
		width = snappedf(value, 0.05)
		emit_changed()
@export_range(0.3, 3.0, 0.05, "suffix:m") var height: float = 1.2:
	set(value):
		height = snappedf(value, 0.05)
		emit_changed()
## Windows only: height of the sill above the floor.
@export_range(0.0, 2.5, 0.05, "suffix:m") var sill_height: float = 0.9:
	set(value):
		sill_height = snappedf(value, 0.05)
		emit_changed()

## Doors only: height of the opening above the floor.
@export_range(0.0, 2.5, 0.05, "suffix:m") var door_bottom_height: float = 0.0:
	set(value):
		door_bottom_height = snappedf(value, 0.05)
		emit_changed()


@export_group("Door")
@export var door_style: DoorStyle = DoorStyle.FOUR_PANEL:
	set(value):
		door_style = value
		emit_changed()
		notify_property_list_changed()
@export var hinge_left: bool = true:
	set(value):
		hinge_left = value
		emit_changed()
## Doors open into the building (+Z side of the wall); windows open out.
@export var opens_inward: bool = true:
	set(value):
		opens_inward = value
		emit_changed()
@export var lockable: bool = true:
	set(value):
		lockable = value
		emit_changed()
@export var door_color: Color = Color(0.93, 0.92, 0.88):
	set(value):
		door_color = value
		emit_changed()
@export var handle: Handle = Handle.LEVER:
	set(value):
		handle = value
		emit_changed()
## Motor-driven (garage doors, shutters): a steady, slower movement.
@export var powered: bool = false:
	set(value):
		powered = value
		emit_changed()

@export_group("Window")
@export var window_style: WindowStyle = WindowStyle.CASEMENT:
	set(value):
		window_style = value
		emit_changed()
		notify_property_list_changed()
## Number of casements side by side (when no panel layout is given).
@export_range(1, 4) var panes: int = 2:
	set(value):
		panes = value
		emit_changed()
@export var shape: Shape = Shape.RECTANGLE:
	set(value):
		shape = value
		emit_changed()
		notify_property_list_changed()
## ARCHED and GABLE: height of the curved or pointed top (0 = a half circle / 45°).
@export_range(0.0, 3.0, 0.05, "suffix:m") var arch_rise: float = 0.0:
	set(value):
		arch_rise = value
		emit_changed()
## POLYGON: number of sides.
@export_range(3, 12) var polygon_sides: int = 8:
	set(value):
		polygon_sides = value
		emit_changed()
## TRAPEZOID: top width as a fraction of the bottom.
@export_range(0.1, 1.0, 0.05) var taper: float = 0.6:
	set(value):
		taper = value
		emit_changed()
## Panels left to right, comma separated. F fixed, L / R side-hung (hinge left /
## right), T top-hung, B bottom-hung, S sliding, TT / TTR tilt-and-turn.
## Empty uses the window style. Example: "L,F,R".
@export var panel_layout: String = "":
	set(value):
		panel_layout = value
		emit_changed()
## Relative panel widths, e.g. [1, 2, 1]. Empty = equal.
@export var panel_widths: PackedFloat32Array = PackedFloat32Array():
	set(value):
		panel_widths = value
		emit_changed()
## Height of a row of top lights above a transom (0 for none).
@export_range(0.0, 1.5, 0.05, "suffix:m") var transom_height: float = 0.0:
	set(value):
		transom_height = value
		emit_changed()
## Top lights above the transom, like panel_layout (usually "F" or "T,T").
@export var top_light_layout: String = "F":
	set(value):
		top_light_layout = value
		emit_changed()
## Glazing bars per panel: columns x rows (0, 0 for clear glass).
@export var glazing_bars: Vector2i = Vector2i.ZERO:
	set(value):
		glazing_bars = value
		emit_changed()
@export var glass_tint: Color = Color(0.69, 0.86, 0.92, 0.23):
	set(value):
		glass_tint = value
		emit_changed()
## Frosted glass (bathrooms).
@export var obscured: bool = false:
	set(value):
		obscured = value
		emit_changed()
## BAY and BOW: how far the window projects from the wall.
@export_range(0.2, 1.5, 0.05, "suffix:m") var projection: float = 0.6:
	set(value):
		projection = value
		emit_changed()
## Glass that turns the corner: the jamb at that end is replaced by a slim post.
## Pair it with a matching opening on the other wall.
@export var corner: CornerGlazing = CornerGlazing.NONE:
	set(value):
		corner = value
		emit_changed()

@export_group("Finish")
@export var head: Head = Head.SOLDIER_COURSE:
	set(value):
		head = value
		emit_changed()
@export var frame_color: Color = Color(0.94, 0.94, 0.91):
	set(value):
		frame_color = value
		emit_changed()
@export_range(0.03, 0.15, 0.005, "suffix:m") var frame_width: float = 0.06:
	set(value):
		frame_width = value
		emit_changed()
## How far leaves and casements swing open (0 uses the style's default).
@export_range(0.0, 180.0, 1.0, "suffix:°") var max_open_angle: float = 0.0:
	set(value):
		max_open_angle = value
		emit_changed()
@export var display_name: String = "":
	set(value):
		display_name = value
		emit_changed()


## Hides settings that don't apply to this kind of opening.
func _validate_property(property: Dictionary) -> void:
	var name := String(property["name"])
	var hide := false
	if kind != Kind.WINDOW and WINDOW_ONLY.has(name):
		hide = true
	if kind == Kind.WINDOW and DOOR_ONLY.has(name):
		hide = true
	if name == "arch_rise" and not (kind == Kind.WINDOW and shape in [Shape.ARCHED, Shape.GABLE]):
		hide = true
	if name == "polygon_sides" and not (kind == Kind.WINDOW and shape == Shape.POLYGON):
		hide = true
	if name == "taper" and not (kind == Kind.WINDOW and shape == Shape.TRAPEZOID):
		hide = true
	if name == "projection" and not (kind == Kind.WINDOW and window_style in [WindowStyle.BAY, WindowStyle.BOW]):
		hide = true
	if hide:
		property["usage"] = PROPERTY_USAGE_NO_EDITOR | PROPERTY_USAGE_STORAGE


static func door(at: float, width_m := 0.9, style := DoorStyle.FOUR_PANEL) -> KitOpening:
	var opening := KitOpening.new()
	opening.kind = Kind.DOOR
	opening.position = at
	opening.width = width_m
	opening.height = 2.1
	opening.door_style = style
	return opening


static func window(at: float, width_m := 1.2, height_m := 1.2, sill := 0.9) -> KitOpening:
	var opening := KitOpening.new()
	opening.kind = Kind.WINDOW
	opening.position = at
	opening.width = width_m
	opening.height = height_m
	opening.sill_height = sill
	return opening


func bottom() -> float:
	return sill_height if kind == Kind.WINDOW else door_bottom_height


## True for door styles built by KitDoors (the original styles use KitJoinery).
func uses_mechanism() -> bool:
	if kind == Kind.WINDOW:
		return panel_layout != "" or shape != Shape.RECTANGLE or window_style >= WindowStyle.PICTURE or transom_height > 0.0 or glazing_bars != Vector2i.ZERO or corner != CornerGlazing.NONE
	return kind == Kind.DOOR and door_style >= DoorStyle.GLAZED_INTERIOR


func is_gate() -> bool:
	return kind == Kind.DOOR and door_style >= DoorStyle.GATE_TIMBER and door_style != DoorStyle.SHED_DOUBLE
