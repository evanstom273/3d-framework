@tool
class_name KitMaterials
extends RefCounted
## Shared, cached materials for the house kit. Pieces ask for a finish (and an
## optional colour); identical requests share one material, so a whole house uses
## a handful of shaders and draws efficiently.

enum Brick { RED, YELLOW_STOCK, BROWN, ENGINEERING_BLUE, WHITE_PAINTED }
enum Facade { BRICK, RENDER, TIMBER_CLADDING, STONE }
enum FloorFinish { FLOORBOARDS, OAK_PARQUET, TILES, CHECKER_TILES, CARPET, CONCRETE, NONE }
enum RoofTile { CLAY_PLAIN, SLATE, CONCRETE_INTERLOCKING, STONE_SLATE }

const BRICK_SHADER := preload("res://house/kit/shaders/brick.gdshader")
const PAINT_SHADER := preload("res://house/kit/shaders/paint.gdshader")
const WOOD_SHADER := preload("res://house/kit/shaders/wood.gdshader")
const TILE_SHADER := preload("res://house/kit/shaders/tile.gdshader")
const ROOF_SHADER := preload("res://house/kit/shaders/roof_tile.gdshader")
const STONE_SHADER := preload("res://house/kit/shaders/stone.gdshader")

const BRICK_COLORS := {
	Brick.RED: Color(0.58, 0.27, 0.19), Brick.YELLOW_STOCK: Color(0.78, 0.64, 0.42),
	Brick.BROWN: Color(0.42, 0.26, 0.18), Brick.ENGINEERING_BLUE: Color(0.22, 0.22, 0.27),
	Brick.WHITE_PAINTED: Color(0.9, 0.9, 0.86),
}

static var _cache: Dictionary = {}


static func _shader(key: String, shader: Shader, parameters: Dictionary) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var material := ShaderMaterial.new()
	material.shader = shader
	for name in parameters:
		material.set_shader_parameter(name, parameters[name])
	_cache[key] = material
	return material


static func brick(kind: Brick, soldier := false) -> ShaderMaterial:
	var parameters := {"brick_color": BRICK_COLORS[kind]}
	if kind == Brick.WHITE_PAINTED:
		parameters["mortar_color"] = Color(0.86, 0.86, 0.82)
		parameters["variation"] = 0.04
	if soldier:
		parameters["brick_size"] = Vector2(0.075, 0.225)
		parameters["bond_offset"] = 0.0
	return _shader("brick:%d:%s" % [kind, soldier], BRICK_SHADER, parameters)


## Matt emulsion on plaster.
static func paint(color: Color) -> ShaderMaterial:
	return _shader("paint:" + color.to_html(), PAINT_SHADER, {"color": color})


## Satin/gloss paint for joinery: skirting, architraves, frames, fascias.
static func gloss(color: Color) -> ShaderMaterial:
	return _shader("gloss:" + color.to_html(), PAINT_SHADER, {"color": color, "roughness": 0.32, "mottling": 0.01, "bump": 0.05})


## External render: coarser texture than plaster.
static func render(color: Color) -> ShaderMaterial:
	return _shader("render:" + color.to_html(), PAINT_SHADER, {"color": color, "roughness": 0.95, "mottling": 0.08, "bump": 1.2, "texture_scale": 1.6})


static func timber(color := Color(0.55, 0.37, 0.22)) -> ShaderMaterial:
	return _shader("timber:" + color.to_html(), WOOD_SHADER, {"color": color, "gap": 0.0, "plank_length": 4.0, "roughness": 0.55})


static func floorboards(color := Color(0.6, 0.42, 0.26), along_z := false) -> ShaderMaterial:
	return _shader("boards:%s:%s" % [color.to_html(), along_z], WOOD_SHADER, {"color": color, "along_z": along_z})


static func parquet(along_z := false) -> ShaderMaterial:
	return _shader("parquet:%s" % along_z, WOOD_SHADER, {"color": Color(0.62, 0.44, 0.26), "plank_width": 0.07, "plank_length": 0.42, "gap": 0.0015, "along_z": along_z, "roughness": 0.35})


static func tiles(color: Color, size := Vector2(0.15, 0.15), checker_color := Color(0, 0, 0, 0)) -> ShaderMaterial:
	var parameters := {"color": color, "tile_size": size}
	if checker_color.a > 0.0:
		parameters["checker"] = true
		parameters["alt_color"] = checker_color
		parameters["roughness"] = 0.4
	return _shader("tiles:%s:%s:%s" % [color.to_html(), size, checker_color.to_html()], TILE_SHADER, parameters)


static func roof(kind: RoofTile, course: float) -> ShaderMaterial:
	var parameters := {"course": course}
	match kind:
		RoofTile.CLAY_PLAIN:
			parameters.merge({"color": Color(0.55, 0.26, 0.17), "tile_width": 0.165})
		RoofTile.SLATE:
			parameters.merge({"color": Color(0.22, 0.24, 0.28), "tile_width": 0.25, "camber": 0.1, "moss": 0.05, "roughness": 0.55, "variation": 0.15})
		RoofTile.CONCRETE_INTERLOCKING:
			parameters.merge({"color": Color(0.36, 0.33, 0.31), "tile_width": 0.3, "camber": 1.6, "variation": 0.1})
		RoofTile.STONE_SLATE:
			parameters.merge({"color": Color(0.56, 0.52, 0.44), "tile_width": 0.3, "camber": 0.2, "moss": 0.35, "variation": 0.35})
	return _shader("roof:%d:%.3f" % [kind, course], ROOF_SHADER, parameters)


static func stone(color := Color(0.8, 0.76, 0.67), blocks := 0.0) -> ShaderMaterial:
	return _shader("stone:%s:%.2f" % [color.to_html(), blocks], STONE_SHADER, {"color": color, "blocks": blocks})


static func concrete() -> ShaderMaterial:
	return _shader("concrete", STONE_SHADER, {"color": Color(0.6, 0.6, 0.58), "mottling": 0.1, "grain_scale": 25.0, "relief": 0.6})


static func terracotta() -> ShaderMaterial:
	return _shader("terracotta", STONE_SHADER, {"color": Color(0.7, 0.36, 0.22), "mottling": 0.12, "relief": 0.4, "roughness": 0.75})


static func carpet(color: Color) -> ShaderMaterial:
	return _shader("carpet:" + color.to_html(), STONE_SHADER, {"color": color, "mottling": 0.06, "grain_scale": 260.0, "relief": 0.8, "roughness": 1.0})


static func metal(color := Color(0.08, 0.08, 0.09), metallic := 0.4) -> StandardMaterial3D:
	var key := "metal:%s:%.2f" % [color.to_html(), metallic]
	if _cache.has(key):
		return _cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.38
	_cache[key] = material
	return material


static func lead() -> StandardMaterial3D:
	var key := "lead"
	if not _cache.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.42, 0.44, 0.45)
		material.metallic = 0.5
		material.roughness = 0.65
		_cache[key] = material
	return _cache[key]


static func floor_finish(kind: FloorFinish, color: Color, along_z := false) -> Material:
	match kind:
		FloorFinish.FLOORBOARDS:
			return floorboards(color, along_z)
		FloorFinish.OAK_PARQUET:
			return parquet(along_z)
		FloorFinish.TILES:
			return tiles(color, Vector2(0.3, 0.3))
		FloorFinish.CHECKER_TILES:
			return tiles(Color(0.9, 0.89, 0.85), Vector2(0.25, 0.25), Color(0.12, 0.13, 0.15))
		FloorFinish.CARPET:
			return carpet(color)
		_:
			return concrete()


## The face of an external wall for a facade choice.
static func facade(kind: Facade, brick_kind: Brick, color: Color) -> Material:
	match kind:
		Facade.RENDER:
			return render(color)
		Facade.TIMBER_CLADDING:
			return gloss(color)
		Facade.STONE:
			return stone(Color(0.74, 0.7, 0.6), 0.45)
		_:
			return brick(brick_kind)
