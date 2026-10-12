extends SceneTree
var _f := 0
var _s: Node
var nav: NPCNavigation
var t0 := 0
func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		_s = (load("res://house/builder/taskmaster_house.tscn") as PackedScene).instantiate()
		root.add_child(_s)
		return false
	if _f == 30:
		var a := Time.get_ticks_usec()
		nav = NPCNavigation.new(); nav.name = "NPCNavigation"; _s.add_child(nav)
		var m := NavigationMesh.new(); m.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS; m.geometry_collision_mask = 1
		var src := NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(m, src, _s)
		var b := Time.get_ticks_usec()
		print("parse %.1f ms, verts %d" % [(b - a) / 1000.0, src.get_vertices().size() / 3])
		nav.start(Vector3(5, 0, 5))
		print("start (parse + obstacles) %.1f ms" % ((Time.get_ticks_usec() - b) / 1000.0))
		t0 = Time.get_ticks_msec()
	if _f > 30 and nav.is_ready:
		print("bake ready after %d ms" % (Time.get_ticks_msec() - t0))
		return true
	return _f > 3000
