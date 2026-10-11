@tool
class_name KitWindowOpening
extends Node3D
## The hole of a window in a KitWall, so the player can climb through it while a
## casement is open (or has been smashed off). The origin is the bottom centre of
## the opening on the wall's centre line, and local -Z points outside.

var width: float = 1.0
var height: float = 1.0
## Wall thickness.
var depth: float = 0.3
## Height of the opening's bottom above the floor on the inside.
var sill_height: float = 0.9
## The window's casements and fixed lights (KitJoinery.window_sashes).
var casements: Array[Node3D] = []
## Each casement's clear opening, matching `casements` by index: x across the
## window from its centre, y up from its bottom.
var lights: Array[Rect2] = []


func _enter_tree() -> void:
	add_to_group(&"climbable_openings")


## Points out of the building.
func outward() -> Vector3:
	return global_basis.z.normalized() * -1.0


func along() -> Vector3:
	return global_basis.x.normalized()


func is_open() -> bool:
	return not open_lights().is_empty()


## The clear openings of casements that are open (or broken off their hinges).
func open_lights() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for index in casements.size():
		var casement := casements[index]
		var open := not is_instance_valid(casement)
		if not open and casement is KitMechanism:
			open = (casement as KitMechanism).is_open() or not bool(casement.get(&"_functional"))
		elif not open and casement.get_script() == KitJoinery.BREAKABLE_HINGE:
			open = bool(casement.get(&"_is_open")) or not bool(casement.get(&"_functional"))
		if open:
			result.append(lights[index] if index < lights.size() else Rect2(-width * 0.5, 0.0, width, height))
	return result


## World position of the bottom centre of a light.
func light_base(light: Rect2) -> Vector3:
	return global_transform * Vector3(light.get_center().x, light.position.y, 0.0)
