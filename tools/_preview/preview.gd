extends Node3D
## Temporary render check for the house kit.

@export var shot: int = 0

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	ground.position.y = -0.3
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.42, 0.22)
	ground.material_override = gm
	add_child(ground)
	# 6 x 5 m box of walls, front (z=0) with door and windows.
	var front := KitWall.new()
	front.length = 6.0
	front.start_join = KitWall.Join.CORNER
	front.end_join = KitWall.Join.CORNER
	front.quoins = true
	front.openings = [KitOpening.window(1.3), KitOpening.door(3.0, 1.0, KitOpening.DoorStyle.SIX_PANEL), KitOpening.window(4.7)]
	front.openings[1].head = KitOpening.Head.STONE_KEYSTONE
	add_child(front)
	var left := KitWall.new()
	left.length = 5.0
	left.start_join = KitWall.Join.BUTT_EXTERIOR
	left.end_join = KitWall.Join.BUTT_EXTERIOR
	left.rotation_degrees.y = -90
	left.openings = [KitOpening.window(2.5, 0.9, 1.2)]
	left.openings[0].window_style = KitOpening.WindowStyle.GEORGIAN_BARS
	left.openings[0].panes = 1
	add_child(left)
	var right := KitWall.new()
	right.length = 5.0
	right.start_join = KitWall.Join.BUTT_EXTERIOR
	right.end_join = KitWall.Join.BUTT_EXTERIOR
	right.position = Vector3(6, 0, 5)
	right.rotation_degrees.y = 90
	add_child(right)
	var back := KitWall.new()
	back.length = 6.0
	back.start_join = KitWall.Join.CORNER
	back.end_join = KitWall.Join.CORNER
	back.position = Vector3(6, 0, 5)
	back.rotation_degrees.y = 180
	add_child(back)
	var floor_piece := KitFloor.new()
	floor_piece.size = Vector2(6, 5)
	floor_piece.ceiling = false
	add_child(floor_piece)
	var roof := KitRoof.new()
	roof.span = 6.0
	roof.length = 5.0
	roof.position = Vector3(0, 3.0, 0)
	roof.downpipe_drop = 3.3
	roof.finish_end = KitRoof.End.HIP
	add_child(roof)
	var camera := Camera3D.new()
	add_child(camera)
	match shot:
		0:
			camera.position = Vector3(-4.5, 2.2, -7.5)
			camera.look_at(Vector3(3, 2.2, 1))
		1:
			camera.position = Vector3(1.2, 1.4, -1.6)
			camera.look_at(Vector3(3.0, 1.3, 0))
		2:
			camera.position = Vector3(4.8, 1.6, 3.8)
			camera.look_at(Vector3(2.0, 1.2, 0.2))
	camera.fov = 70
