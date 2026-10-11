extends SceneTree
var _f := 0
var _items: Array = []
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var floor := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(400, 1, 40)
		floor.add_child(shape)
		floor.position = Vector3(150, -0.5, 0)
		root.add_child(floor)
		var x := 0.0
		for folder in DirAccess.get_directories_at("res://furniture/"):
			for file in DirAccess.get_files_at("res://furniture/" + folder):
				if not file.ends_with(".tres") or folder == "materials":
					continue
				var def := load("res://furniture/%s/%s" % [folder, file]) as VoxelStructureDefinition
				if def == null or def.moving_parts.is_empty():
					continue
				var b := VoxelBody.new()
				b.structure = def
				b.name = file.get_basename()
				root.add_child(b)
				b.global_position = Vector3(x, 0.01, 0)
				x += 3.5
				_items.append({"body": b, "cells": 0, "pos": Vector3.ZERO, "leaves": {}})
	if _f == 60:
		for it in _items:
			var b: VoxelBody = it["body"]
			it["cells"] = b.cells.size()
			it["pos"] = b.global_position
			for m in _mechs(b):
				it["leaves"][m] = (m.get_node("Pivot/Leaf") as Node3D).global_transform
				for a in m.get_interaction_actions():
					if String(a["id"]).begins_with("open"):
						m.perform_interaction_action(a["id"], null)
	if _f == 180:
		var bad := 0
		for it in _items:
			var b: VoxelBody = it["body"]
			var notes := []
			if b.cells.size() != it["cells"]: notes.append("body lost %d" % (it["cells"] - b.cells.size()))
			if b.global_position.distance_to(it["pos"]) > 0.02: notes.append("body moved %.2f" % b.global_position.distance_to(it["pos"]))
			for m in it["leaves"]:
				var leaf := m.get_node_or_null("Pivot/Leaf") as Node3D
				if leaf == null:
					notes.append("%s fell off" % m.interaction_name)
					continue
				var t: Transform3D = it["leaves"][m]
				var d := leaf.global_transform.origin.distance_to(t.origin) + leaf.global_basis.get_rotation_quaternion().angle_to(t.basis.get_rotation_quaternion())
				if d < 0.05: notes.append("%s didn't move" % m.interaction_name)
			if not notes.is_empty():
				bad += 1
			print("%-24s %d parts %s" % [b.name, it["leaves"].size(), "OK" if notes.is_empty() else str(notes)])
		print("PIECES %d, problems %d" % [_items.size(), bad])
		return true
	return false

func _mechs(n: Node) -> Array[KitMechanism]:
	var out: Array[KitMechanism] = []
	for c in n.get_children(true):
		if c is KitMechanism:
			out.append(c)
		out.append_array(_mechs(c))
	return out
