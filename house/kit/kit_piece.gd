@tool
class_name KitPiece
extends StaticBody3D
## Base for the parametric house pieces. Change a property in the Inspector and the
## piece rebuilds its mesh, collision and fixtures. Generated nodes are not saved
## into your scene (they have no owner); the piece regenerates them on load, so
## scene files only store the settings.
##
## Conventions: metres; place pieces on a 0.5 m grid with 90° turns. A storey is
## 3.0 m floor to floor; floors are 0.25 m thick with their top at the piece origin.

var _rebuild_queued := false


func _ready() -> void:
	rebuild()


## Rebuild at the end of the frame, so several property changes only rebuild once.
func queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.has_meta(&"kit_generated"):
			remove_child(child)
			child.queue_free()
	var builder := KitBuilder.new()
	_build(builder)
	builder.commit(self, self)
	_build_fixtures()


## Subclasses add their static geometry here.
func _build(_builder: KitBuilder) -> void:
	pass


## Subclasses add moving or breakable parts (doors, windows) here, via add_generated().
func _build_fixtures() -> void:
	pass


func add_generated(node: Node) -> void:
	node.set_meta(&"kit_generated", true)
	add_child(node)


## Snaps a length to 5 cm, never below `minimum`.
static func snap(value: float, minimum := 0.05) -> float:
	return maxf(minimum, snappedf(value, 0.05))


# --- Profiles for extrusions

## Rectangle (across, up) from `low` to `high`.
static func rect_profile(low: Vector2, high: Vector2) -> PackedVector2Array:
	return PackedVector2Array([low, Vector2(high.x, low.y), high, Vector2(low.x, high.y)])


## Arc of points around `centre` from `start` to `end` angles (radians), inclusive.
static func arc(centre: Vector2, radius: float, start: float, end: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments + 1:
		var angle := lerpf(start, end, float(i) / segments)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points
