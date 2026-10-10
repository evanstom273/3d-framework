class_name VoxFile
extends RefCounted
## Reads MagicaVoxel .vox files (the first model in the file) and converts them
## to voxel structure boxes. MagicaVoxel is Z-up; voxels are turned to Godot's
## Y-up, centred on X/Z with the bottom at Y = 0.


## Returns {size: Vector3i (vox axes), voxels: Array of [Vector3i, colour index],
## palette: PackedColorArray where palette[i] is colour index i}, or {} on failure.
static func read(path: String) -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 20 or bytes.slice(0, 4).get_string_from_ascii() != "VOX ":
		push_error("VoxFile: %s is not a MagicaVoxel file." % path)
		return {}
	var result := {"size": Vector3i.ZERO, "voxels": [], "palette": _default_palette()}
	var offset := 8
	var have_model := false
	while offset + 12 <= bytes.size():
		var id := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var content_size := bytes.decode_u32(offset + 4)
		var content := offset + 12
		match id:
			"MAIN":
				# Its children follow directly; step inside.
				offset = content + content_size
				continue
			"SIZE":
				if not have_model:
					result["size"] = Vector3i(bytes.decode_u32(content), bytes.decode_u32(content + 4), bytes.decode_u32(content + 8))
			"XYZI":
				if not have_model:
					var count := bytes.decode_u32(content)
					for i in count:
						var at := content + 4 + i * 4
						result["voxels"].append([Vector3i(bytes[at], bytes[at + 1], bytes[at + 2]), bytes[at + 3]])
					have_model = true
			"RGBA":
				var palette := PackedColorArray()
				palette.resize(256)
				for i in 255:
					var at := content + i * 4
					palette[i + 1] = Color8(bytes[at], bytes[at + 1], bytes[at + 2], bytes[at + 3])
				result["palette"] = palette
		offset = content + content_size + bytes.decode_u32(offset + 8)
	return result if have_model else {}


## Builds fill boxes (one per merged run of same-coloured voxels). Colours close to
## one of `extra_materials`' colours use that material instead of `material`.
static func to_boxes(path: String, material: VoxelMaterialDefinition, keep_colors: bool,
		extra_materials: Array[VoxelMaterialDefinition] = []) -> Array[VoxelFillBox]:
	var boxes: Array[VoxelFillBox] = []
	var data := read(path)
	if data.is_empty() or material == null:
		return boxes
	var size: Vector3i = data["size"]
	var by_color := {}
	for entry in data["voxels"]:
		var v: Vector3i = entry[0]
		var cell := Vector3i(v.x - size.x / 2, v.z, (size.y - 1 - v.y) - size.y / 2)
		# Keep colour indices apart when they map to different materials.
		var key: int = entry[1] if keep_colors or not extra_materials.is_empty() else 0
		if not by_color.has(key):
			by_color[key] = {}
		by_color[key][cell] = true
	var palette: PackedColorArray = data["palette"]
	for key in by_color:
		var color: Color = palette[key]
		var box_material := material
		for extra in extra_materials:
			if extra != null and _color_distance(extra.color, color) < 0.06:
				box_material = extra
				break
		for run in VoxelCollider.merge(by_color[key]):
			var box := VoxelFillBox.new()
			box.min_cell = run[0]
			box.size = run[1] - run[0] + Vector3i.ONE
			box.material = box_material
			if keep_colors:
				box.color_override = color
			boxes.append(box)
	return boxes


static func _color_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


## Reads a model as Godot-space cells: {size: Vector3i, cells: {Vector3i: Color}}.
## X stays X, MagicaVoxel's Z (up) becomes Y, and its Y runs toward -Z.
## Cells start at 0 (no centring).
static func read_cells(path: String) -> Dictionary:
	var data := read(path)
	if data.is_empty():
		return {}
	var vox_size: Vector3i = data["size"]
	var palette: PackedColorArray = data["palette"]
	var cells := {}
	for entry in data["voxels"]:
		var v: Vector3i = entry[0]
		cells[Vector3i(v.x, v.z, vox_size.y - 1 - v.y)] = palette[entry[1]]
	return {"size": Vector3i(vox_size.x, vox_size.z, vox_size.y), "cells": cells}


## Writes Godot-space cells ({Vector3i: Color}, all within `size`) as a .vox file.
## Up to 255 distinct colours.
static func write_cells(path: String, size: Vector3i, cells: Dictionary) -> Error:
	var colors: Array[Color] = []
	var index_of := {}
	var voxels := PackedByteArray()
	for cell: Vector3i in cells:
		var color: Color = cells[cell]
		var key := color.to_rgba32()
		if not index_of.has(key):
			if colors.size() >= 255:
				return ERR_OUT_OF_MEMORY
			colors.append(color)
			index_of[key] = colors.size()
		voxels.append_array(PackedByteArray([cell.x, size.z - 1 - cell.z, cell.y, index_of[key]]))
	var children := PackedByteArray()
	children.append_array(_chunk("SIZE", _ints([size.x, size.z, size.y])))
	var xyzi := _ints([cells.size()])
	xyzi.append_array(voxels)
	children.append_array(_chunk("XYZI", xyzi))
	var rgba := PackedByteArray()
	for i in 256:
		var c := colors[i] if i < colors.size() else Color(0.5, 0.5, 0.5)
		rgba.append_array(PackedByteArray([c.r8, c.g8, c.b8, 255]))
	children.append_array(_chunk("RGBA", rgba))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer("VOX ".to_ascii_buffer())
	file.store_32(150)
	file.store_buffer("MAIN".to_ascii_buffer())
	file.store_32(0)
	file.store_32(children.size())
	file.store_buffer(children)
	return OK


static var _mesh_cache: Dictionary = {}


## A static, face-culled, vertex-coloured mesh of a model, its first cell's corner
## at `origin`. Cached per file/size/origin/material.
static func build_mesh(path: String, voxel_size: float, origin: Vector3, material: Material) -> ArrayMesh:
	var key := "%s|%s|%s|%d" % [path, voxel_size, origin, material.get_instance_id() if material else 0]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var data := read_cells(path)
	if data.is_empty():
		return null
	var cells: Dictionary = data["cells"]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cell: Vector3i in cells:
		var color: Color = cells[cell]
		for face in VoxelMesher.FACES:
			if cells.has(cell + face[0]):
				continue
			var corners: Array = face[1]
			for index in VoxelMesher.FACE_ORDER:
				tool.set_color(color)
				tool.set_normal(Vector3(face[0]))
				tool.add_vertex(origin + (Vector3(cell) + corners[index]) * voxel_size)
	tool.set_material(material if material != null else VoxelMesher.get_material())
	var mesh := tool.commit()
	_mesh_cache[key] = mesh
	return mesh


static func _ints(values: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(values.size() * 4)
	for i in values.size():
		bytes.encode_s32(i * 4, values[i])
	return bytes


static func _chunk(id: String, content: PackedByteArray) -> PackedByteArray:
	var bytes := id.to_ascii_buffer()
	bytes.append_array(_ints([content.size(), 0]))
	bytes.append_array(content)
	return bytes


## MagicaVoxel's palette when a file doesn't include one (greys as a fallback).
static func _default_palette() -> PackedColorArray:
	var palette := PackedColorArray()
	palette.resize(256)
	for i in 256:
		palette[i] = Color(0.6, 0.6, 0.6)
	return palette
