extends Node
## Shader warm-up: when a map loads, every voxel material (the shared vertex-
## colour one, glass, and each furniture material's own look) is drawn once,
## lit and shadow-casting, just in front of the camera for a few frames. The GPU
## compiles their pipelines during loading instead of the first time a room of
## furniture comes into view mid-play.

const FRAMES := 3
const EXTRA_MATERIALS := ["res://house/assets/materials/transparent_glass.tres"]
const MATERIAL_FOLDERS := ["res://furniture/materials/", "res://props/voxel_materials/"]

var _holder: Node3D
var _frames_left := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().scene_changed.connect(_warm_up)
	_warm_up.call_deferred()


func _warm_up() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene is Node3D or _holder != null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	_holder = Node3D.new()
	_holder.name = "ShaderWarmup"
	scene.add_child(_holder)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var index := 0
	for material in _materials():
		var instance := MeshInstance3D.new()
		instance.mesh = quad
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		# Tiny, just past the near plane: drawn (so compiled) but unnoticeable.
		instance.transform = Transform3D(Basis.IDENTITY, Vector3((index % 8) * 0.03 - 0.1, (index / 8) * 0.03 - 0.05, -0.3))
		_holder.add_child(instance)
		index += 1
	_holder.top_level = true
	_holder.global_transform = camera.global_transform
	_frames_left = FRAMES


func _process(_delta: float) -> void:
	if _frames_left <= 0:
		return
	_frames_left -= 1
	if _frames_left == 0 and is_instance_valid(_holder):
		_holder.queue_free()
		_holder = null


func _materials() -> Array[Material]:
	var found: Array[Material] = [VoxelMesher.get_material()]
	for path in EXTRA_MATERIALS:
		if ResourceLoader.exists(path):
			found.append(load(path))
	for folder in MATERIAL_FOLDERS:
		for file in DirAccess.get_files_at(folder):
			file = file.trim_suffix(".remap")
			if not file.ends_with(".tres"):
				continue
			var definition := load(folder + file) as VoxelMaterialDefinition
			if definition != null and definition.mesh_material_override != null and not found.has(definition.mesh_material_override):
				found.append(definition.mesh_material_override)
	return found
