@tool
class_name KitOpening
extends Resource
## A door, window or open doorway in a KitWall. Positions are along the wall from
## its start (the piece origin), to the centre of the opening.

enum Kind { DOOR, WINDOW, OPEN_DOORWAY }
enum DoorStyle { FOUR_PANEL, SIX_PANEL, HALF_GLAZED, FULLY_GLAZED, LEDGED_PLANK, FLUSH }
enum WindowStyle { CASEMENT, GEORGIAN_BARS, CASEMENT_WITH_TOP_LIGHT, FIXED }
enum Head { SOLDIER_COURSE, STONE_LINTEL, STONE_KEYSTONE, NONE }

@export var kind: Kind = Kind.WINDOW:
	set(value):
		kind = value
		emit_changed()
## Distance along the wall from its start to the middle of the opening.
@export_range(0.0, 30.0, 0.05, "or_greater", "suffix:m") var position: float = 1.5:
	set(value):
		position = snappedf(value, 0.05)
		emit_changed()
## Structural opening width, including the frame.
@export_range(0.3, 4.0, 0.05, "suffix:m") var width: float = 1.2:
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

@export_group("Door")
@export var door_style: DoorStyle = DoorStyle.FOUR_PANEL:
	set(value):
		door_style = value
		emit_changed()
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

@export_group("Window")
@export var window_style: WindowStyle = WindowStyle.CASEMENT:
	set(value):
		window_style = value
		emit_changed()
## Number of casements side by side.
@export_range(1, 4) var panes: int = 2:
	set(value):
		panes = value
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
@export var display_name: String = "":
	set(value):
		display_name = value
		emit_changed()


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
	return sill_height if kind == Kind.WINDOW else 0.0
