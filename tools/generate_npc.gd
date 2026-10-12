extends SceneTree
## Generates the test NPC, "The Assistant": one .vox per body part (on a shared
## grid), a held clipboard, NPC materials, and res://npc/definitions/assistant.tres.
##
##   godot --headless --path . -s res://tools/generate_npc.gd

const AssistantModel := preload("res://tools/npc/assistant_model.gd")
const VOX := "res://npc/vox/"
const MATERIALS := "res://npc/materials/"
const DEFINITION := "res://npc/definitions/assistant.tres"
const FURNITURE_MATERIALS := "res://furniture/materials/"
## Real weight of the whole NPC; voxel densities are scaled to match.
const MASS := 75.0

## key: [name, colour, strength, density kg/m³, friction, bounce, blunt, sharp, pierce, sound, rubble]
const MATERIAL_TABLE := {
	"skin": ["Skin", Color(0.93, 0.76, 0.64), 4.0, 1000.0, 0.8, 0.05, 0.9, 1.6, 1.5, ImpactFeedback.Sound.CARDBOARD, 0.05],
	"hair": ["Hair", Color(0.36, 0.25, 0.16), 3.0, 300.0, 0.9, 0.02, 0.6, 2.0, 1.0, ImpactFeedback.Sound.CARDBOARD, 0.05],
	"suit": ["Suit", Color(0.14, 0.16, 0.22), 5.0, 900.0, 0.8, 0.03, 0.6, 1.8, 1.4, ImpactFeedback.Sound.CARDBOARD, 0.05],
	"shirt": ["Shirt", Color(0.95, 0.95, 0.93), 4.0, 900.0, 0.8, 0.03, 0.6, 1.9, 1.4, ImpactFeedback.Sound.CARDBOARD, 0.05],
	"tie": ["Silk", Color(0.55, 0.12, 0.16), 4.0, 900.0, 0.6, 0.03, 0.6, 1.9, 1.4, ImpactFeedback.Sound.CARDBOARD, 0.05],
	"leather": ["Leather", Color(0.08, 0.07, 0.07), 9.0, 950.0, 0.85, 0.05, 0.5, 1.6, 1.3, ImpactFeedback.Sound.CARDBOARD, 0.05],
	"flesh": ["Flesh", Color(0.86, 0.14, 0.16), 3.5, 1050.0, 0.85, 0.1, 0.9, 1.8, 1.6, ImpactFeedback.Sound.CARDBOARD, 0.12],
	"bone": ["Bone", Color(0.93, 0.9, 0.82), 14.0, 1900.0, 0.6, 0.15, 0.8, 0.6, 0.7, ImpactFeedback.Sound.WOOD, 0.2],
	"eye": ["Eye", Color(0.98, 0.98, 0.97), 2.0, 1000.0, 0.6, 0.2, 1.0, 1.5, 1.5, ImpactFeedback.Sound.RUBBER, 0.05],
	"pupil": ["Pupil", Color(0.12, 0.2, 0.3), 2.0, 1000.0, 0.6, 0.2, 1.0, 1.5, 1.5, ImpactFeedback.Sound.RUBBER, 0.05],
}

const BARKS := {
	"hit": ["Ow!", "Ouch!", "Hey!", "That's not in the brief!", "Mind the suit!", "Ow, my everything."],
	"limb": ["I needed that!", "That's coming out of your score.", "I'll need a form for that.", "Well, that's a first.", "Could someone hold this?"],
	"knocked": ["Whoa-oh-oh!", "Not again!", "Oof!"],
	"up": ["I'm fine! Fine.", "Totally meant to do that.", "Right. Where was I?", "Carrying on."],
	"carried": ["Put me down!", "This is highly irregular!", "Whoa, whoa, whoa!", "I can walk, you know!"],
	"thrown": ["Wheeeee- oof!", "Aaaaargh!", "Not the face!"],
	"burn": ["Hot! Hot! Hot!", "Ow, that's hot!", "Is something burning? Oh, it's me.", "Not the suit!"],
	"cut": ["Ow! That's sharp!", "That's attached to me!", "My good jacket!", "That's going to need a plaster."],
	"pushed": ["Whoa!", "Steady on!", "I'm being blown away!", "Pfft! Was that necessary?"],
	"door": ["After you!", "Allow me.", "I'll get that.", "Door's open!"],
	"locked": ["Locked. Of course it is.", "Hmm, locked.", "Has anyone got a key?"],
	"careful": ["Careful with that!", "Mind where you point that.", "Health and safety!", "Is that strictly necessary?"],
	"follow": ["Right behind you.", "Lead the way!", "Coming!"],
	"wait": ["I'll wait here.", "Righto.", "Take your time."],
	"death": ["Tell the boss I tried...", "Write that down...", "Bleurgh."],
	"look": ["Can I help?", "Hello!", "Is this part of the task?", "Don't mind me."],
	"talk": ["The task is in the envelope.", "You have one hour. Your time starts now.", "Please don't touch the props.", "I'm just here to keep score.", "Is that a hammer?"],
}

var materials: Dictionary = {}


func _initialize() -> void:
	for dir in [VOX, MATERIALS, DEFINITION.get_base_dir()]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_make_materials()
	var definition := NPCDefinition.new()
	definition.display_name = "The Assistant"
	definition.barks = BARKS
	# An obliging assistant: a calm walk, never a run, pottering close to home.
	definition.walk_speed = 1.5
	definition.run_speed = 2.25
	definition.wander_radius = 4.0
	if not _body(definition):
		quit(1)
		return
	_clipboard(definition)
	var error := ResourceSaver.save(definition, DEFINITION)
	print("Saved %s (error %d): %d parts" % [DEFINITION, error, definition.parts.size()])
	quit()


func _make_materials() -> void:
	for key in MATERIAL_TABLE:
		var path: String = MATERIALS + key + ".tres"
		var row: Array = MATERIAL_TABLE[key]
		var material := VoxelMaterialDefinition.new()
		material.display_name = row[0]
		material.color = row[1]
		material.color_jitter = 0.0
		material.strength = row[2]
		material.density = row[3]
		material.friction = row[4]
		material.bounce = row[5]
		material.blunt_multiplier = row[6]
		material.sharp_multiplier = row[7]
		material.pierce_multiplier = row[8]
		material.impact_sound = row[9]
		material.rubble_fraction = row[10]
		# Skin, flesh, hair and clothes burn and cut readily; bone is tougher.
		material.tool_profile = load("res://contraptions/materials/profiles/%s.tres" % ("wood" if key == "bone" else "soft"))
		ResourceSaver.save(material, path)
		materials[key] = load(path)
	# Props reuse the furniture library's materials.
	for key in ["plastic", "plywood", "paper", "steel"]:
		materials[key] = load(FURNITURE_MATERIALS + key + ".tres")


func _body(definition: NPCDefinition) -> bool:
	var model := FurnitureModel.new(AssistantModel.SIZE, AssistantModel.VOXEL)
	AssistantModel.new().build(model)
	# Each part must be one connected lump (they're joined per part, never across).
	for join in model.connect_parts():
		if join[1] < 0:
			print("  STILL LOOSE: %d voxels (%s)" % [join[0], join[2]])
	var grid := model.normalize()
	var baked := ModelExporter.palette(model, materials)
	if baked.is_empty():
		print("PALETTE FULL")
		return false
	var indexed: Dictionary = baked["indexed"]
	var groups := {"torso": 0}
	for group in range(1, model.moving.size()):
		groups[model.moving[group]["label"]] = group
	var density_scale := clampf(MASS / float(baked["mass"]), 0.02, 5.0)
	var parts: Array[NPCPart] = []
	var index_of := {}
	for joint: Array in AssistantModel.JOINTS:
		index_of[joint[0]] = parts.size()
		var group: int = groups[joint[0]]
		var vox_path: String = VOX + "assistant__%s.vox" % joint[0]
		VoxFile.write_indexed(vox_path, grid, indexed.get(group, {}), baked["colors"])
		var part := NPCPart.new()
		part.name = joint[0]
		part.structure = ModelExporter.definition("Assistant %s" % String(joint[0]).capitalize(), vox_path, model.voxel,
			baked["index_materials"], materials["suit"], density_scale)
		part.parent = index_of.get(joint[2], -1)
		part.pivot = ModelExporter.to_body(model, grid, joint[1])
		part.vital = joint[3]
		part.swing_limit = joint[4]
		part.twist_limit = joint[5]
		parts.append(part)
		print("  %-12s %6d voxels  pivot %s" % [joint[0], indexed.get(group, {}).size(), part.pivot])
	definition.parts = parts
	# The clipboard is held in front of the right hand.
	definition.held_by = "forearm_r"
	definition.held_transform = Transform3D(Basis.IDENTITY, ModelExporter.to_body(model, grid, Vector3(AssistantModel.CX + 0.235, 0.66, AssistantModel.CZ - 0.075)))
	print("  total %d voxels on a %s grid, %.0f kg" % [model.cells.size(), grid, MASS])
	return true


func _clipboard(definition: NPCDefinition) -> void:
	var model := FurnitureModel.new(Vector3(0.24, 0.34, 0.03), 0.01)
	AssistantModel.clipboard(model)
	model.connect_parts()
	var grid := model.normalize()
	var baked := ModelExporter.palette(model, materials)
	var vox_path := VOX + "assistant__clipboard.vox"
	VoxFile.write_indexed(vox_path, grid, baked["indexed"][0], baked["colors"])
	definition.held_prop = ModelExporter.definition("Clipboard", vox_path, model.voxel, baked["index_materials"],
		materials["plywood"], clampf(0.4 / float(baked["mass"]), 0.02, 5.0))
	print("  clipboard    %6d voxels" % model.cells.size())
