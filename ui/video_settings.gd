class_name VideoSettings
extends RefCounted
## Graphics settings, saved with the rest in user://settings.cfg ([video]).
##
## Environment effects are switches on top of each map's own WorldEnvironment:
## an effect shows only if the map uses it *and* it's switched on here, so
## turning everything on never adds fog to a map that has none. Applied to
## every scene as it loads (watch() hooks the tree), and live from the menu.

const SECTION := "video"

## key -> [menu label, default]
const TOGGLES := {
	"ssao": ["Ambient occlusion (SSAO)", true],
	"ssil": ["Indirect lighting (SSIL)", true],
	"ssr": ["Reflections (SSR)", true],
	"sdfgi": ["Global illumination (SDFGI)", true],
	"glow": ["Glow / bloom", true],
	"fog": ["Fog", true],
}
const SHADOWS := ["Off", "Low", "Medium", "High"]
const ANTI_ALIASING := ["Off", "FXAA", "MSAA 2x", "MSAA 4x", "TAA"]
const FPS_LIMITS := [0, 30, 60, 120, 144, 240]

const PRESETS := {
	"Low": {"ssao": false, "ssil": false, "ssr": false, "sdfgi": false, "glow": true, "fog": false,
		"shadows": 1, "aa": 1, "render_scale": 0.75},
	"Medium": {"ssao": true, "ssil": false, "ssr": false, "sdfgi": false, "glow": true, "fog": true,
		"shadows": 2, "aa": 1, "render_scale": 1.0},
	"High": {"ssao": true, "ssil": true, "ssr": true, "sdfgi": true, "glow": true, "fog": true,
		"shadows": 3, "aa": 2, "render_scale": 1.0},
}
const DEFAULTS := {"vsync": true, "max_fps": 0}

static var values: Dictionary = {}
static var _loaded := false
static var _watching := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	values = PRESETS["High"].duplicate()
	values.merge(DEFAULTS)
	var config := ConfigFile.new()
	if config.load(GameSettings.PATH) == OK:
		for key in values:
			values[key] = config.get_value(SECTION, key, values[key])


static func save(config: ConfigFile) -> void:
	for key in values:
		config.set_value(SECTION, key, values[key])


static func get_value(key: String) -> Variant:
	load_settings()
	return values[key]


static func set_value(key: String, value: Variant) -> void:
	load_settings()
	values[key] = value
	apply()


static func apply_preset(preset: String) -> void:
	load_settings()
	values.merge(PRESETS[preset], true)
	apply()


## "Low", "Medium", "High", or "Custom" when the settings match none of them.
static func current_preset() -> String:
	load_settings()
	for preset in PRESETS:
		var matches := true
		for key in PRESETS[preset]:
			# Bools, ints and floats all compare as numbers.
			if not is_equal_approx(float(values[key]), float(PRESETS[preset][key])):
				matches = false
				break
		if matches:
			return preset
	return "Custom"


## Applies everything to the current window and scene.
static func apply() -> void:
	load_settings()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var viewport := tree.root
	# Anti-aliasing and resolution.
	var aa: int = values["aa"]
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_DISABLED][aa]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = aa == 4
	var scale := clampf(float(values["render_scale"]), 0.5, 1.0)
	viewport.scaling_3d_scale = scale
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.999 else Viewport.SCALING_3D_MODE_BILINEAR
	# Frame pacing.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(values["max_fps"])
	# Shadow resolution and softness.
	var shadows: int = values["shadows"]
	var size: int = [1024, 1024, 2048, 4096][shadows]
	RenderingServer.directional_shadow_atlas_set_size(size, true)
	viewport.positional_shadow_atlas_size = size
	var filter: int = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_HARD,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][shadows]
	RenderingServer.directional_soft_shadow_filter_set_quality(filter)
	RenderingServer.positional_soft_shadow_filter_set_quality(filter)
	_apply_to(tree.root)


## Re-applies to every scene as it loads (call once, from an autoload).
static func watch(tree: SceneTree) -> void:
	if _watching:
		return
	_watching = true
	tree.node_added.connect(_on_node_added)
	apply()


static func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment or node is Light3D:
		_apply_node(node)


static func _apply_to(node: Node) -> void:
	_apply_node(node)
	for child in node.get_children():
		_apply_to(child)


static func _apply_node(node: Node) -> void:
	if node is WorldEnvironment:
		var environment: Environment = (node as WorldEnvironment).environment
		if environment != null:
			_apply_environment(environment)
	elif node is Light3D:
		var light := node as Light3D
		# Remember what the scene asked for, so switching shadows back on restores it.
		if not light.has_meta(&"scene_shadow"):
			light.set_meta(&"scene_shadow", light.shadow_enabled)
		light.shadow_enabled = bool(light.get_meta(&"scene_shadow")) and int(values["shadows"]) > 0


static func _apply_environment(environment: Environment) -> void:
	if not environment.has_meta(&"scene_effects"):
		environment.set_meta(&"scene_effects", {
			"ssao": environment.ssao_enabled, "ssil": environment.ssil_enabled, "ssr": environment.ssr_enabled,
			"sdfgi": environment.sdfgi_enabled, "glow": environment.glow_enabled,
			"fog": environment.fog_enabled, "volumetric_fog": environment.volumetric_fog_enabled,
		})
	var scene: Dictionary = environment.get_meta(&"scene_effects")
	environment.ssao_enabled = scene["ssao"] and values["ssao"]
	environment.ssil_enabled = scene["ssil"] and values["ssil"]
	environment.ssr_enabled = scene["ssr"] and values["ssr"]
	environment.sdfgi_enabled = scene["sdfgi"] and values["sdfgi"]
	environment.glow_enabled = scene["glow"] and values["glow"]
	environment.fog_enabled = scene["fog"] and values["fog"]
	environment.volumetric_fog_enabled = scene["volumetric_fog"] and values["fog"]
