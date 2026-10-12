extends RefCounted
## "The Assistant": a tall, lanky game-show assistant in a dark suit, built for
## tools/generate_npc.gd with the FurnitureModel kit. A generic archetype, not a
## likeness of anyone.
##
## Model space: metres, character facing -Z (front at z = 0), feet at y = 0,
## centred on CX / CZ. Every body part is its own group (begin_part), so it is
## exported as a separate voxel body; its pivot is the joint it hangs from.
## Under the clothes and skin is cartoon-red flesh with off-white bone cores, so
## damage shows red (and the odd bone) rather than hollow.

const VOXEL := 0.02
const SIZE := Vector3(0.68, 1.9, 0.36)
const CX := 0.34
const CZ := 0.18

const SKIN := Color(0.93, 0.76, 0.64)
const HAIR := Color(0.36, 0.25, 0.16)
const SUIT := Color(0.14, 0.16, 0.22)
const SHIRT := Color(0.95, 0.95, 0.93)
const TIE := Color(0.55, 0.12, 0.16)
const SHOE := Color(0.08, 0.07, 0.07)
const FLESH := Color(0.86, 0.14, 0.16)
const BONE := Color(0.93, 0.9, 0.82)

## Joints: name -> [pivot (model space), parent name, vital, swing limit °, twist limit °].
## Index order is the NPC part order; the torso (group 0) is the root.
const JOINTS := [
	["torso", Vector3(CX, 0.94, CZ), "", true, 0.0, 0.0],
	["head", Vector3(CX, 1.52, CZ), "torso", true, 40.0, 60.0],
	["upper_arm_r", Vector3(CX + 0.215, 1.43, CZ), "torso", false, 95.0, 45.0],
	["forearm_r", Vector3(CX + 0.235, 1.13, CZ), "upper_arm_r", false, 85.0, 20.0],
	["upper_arm_l", Vector3(CX - 0.215, 1.43, CZ), "torso", false, 95.0, 45.0],
	["forearm_l", Vector3(CX - 0.235, 1.13, CZ), "upper_arm_l", false, 85.0, 20.0],
	["thigh_r", Vector3(CX + 0.09, 0.94, CZ), "torso", false, 75.0, 20.0],
	["shin_r", Vector3(CX + 0.09, 0.51, CZ), "thigh_r", false, 85.0, 10.0],
	["thigh_l", Vector3(CX - 0.09, 0.94, CZ), "torso", false, 75.0, 20.0],
	["shin_l", Vector3(CX - 0.09, 0.51, CZ), "thigh_l", false, 85.0, 10.0],
]

var m: FurnitureModel
var skin: int
var hair: int
var suit: int
var lapel: int
var shirt: int
var tie: int
var shoe: int
var sole: int
var flesh: int
var bone: int
var eye: int
var pupil: int
var lip: int
var lanyard: int
var badge: int


func build(model: FurnitureModel) -> void:
	m = model
	skin = m.paint("skin", SKIN, FurnitureModel.Finish.SPECKLE)
	hair = m.paint("hair", HAIR, FurnitureModel.Finish.GRAIN)
	suit = m.paint("suit", SUIT, FurnitureModel.Finish.FABRIC)
	lapel = m.paint("suit", SUIT.darkened(0.25), FurnitureModel.Finish.FABRIC)
	shirt = m.paint("shirt", SHIRT, FurnitureModel.Finish.FABRIC)
	tie = m.paint("tie", TIE, FurnitureModel.Finish.FABRIC)
	shoe = m.paint("leather", SHOE, FurnitureModel.Finish.BRUSHED)
	sole = m.paint("leather", SHOE.lightened(0.15))
	flesh = m.paint("flesh", FLESH, FurnitureModel.Finish.SPECKLE)
	bone = m.paint("bone", BONE)
	eye = m.paint("eye", Color(0.98, 0.98, 0.97))
	pupil = m.paint("pupil", Color(0.12, 0.2, 0.3))
	lip = m.paint("skin", Color(0.72, 0.38, 0.36))
	lanyard = m.paint("tie", Color(0.18, 0.34, 0.7))
	badge = m.paint("plastic", Color(0.97, 0.97, 0.95))
	_torso()
	_head()
	for side in [1.0, -1.0]:
		_arm(side)
		_leg(side)


func _begin(index: int) -> void:
	var joint: Array = JOINTS[index]
	m.begin_part("joint", joint[0], joint[1], Vector3.UP, 0.0)


## A limb segment: clothing tube with a flesh core and a bone shaft, from y0 to y1.
func _segment(x: float, y0: float, y1: float, half_x: float, half_z: float, cloth: int, bone_radius: float, z := CZ) -> void:
	m.rounded(Vector3(x - half_x, y0, z - half_z), Vector3(x + half_x, y1, z + half_z), minf(half_x, half_z) * 0.6, cloth, "y")
	m.box(Vector3(x - half_x + 0.04, y0 + 0.01, z - half_z + 0.04), Vector3(x + half_x - 0.04, y1 - 0.01, z + half_z - 0.04), flesh)
	m.cylinder(Vector3(x, y0 + 0.02, z), "y", y1 - y0 - 0.04, bone_radius, bone)


# --- Torso (root): jacket, shirt front and tie, lanyard, trousers' seat

func _torso() -> void:
	# Hips and seat of the trousers, then the jacket over the chest.
	m.rounded(Vector3(CX - 0.16, 0.9, CZ - 0.1), Vector3(CX + 0.16, 1.02, CZ + 0.1), 0.04, suit)
	m.rounded(Vector3(CX - 0.185, 0.98, CZ - 0.115), Vector3(CX + 0.185, 1.42, CZ + 0.115), 0.05, suit)
	# Shoulders, sloping in to the neck.
	m.rounded(Vector3(CX - 0.2, 1.36, CZ - 0.105), Vector3(CX + 0.2, 1.47, CZ + 0.105), 0.05, suit)
	# Flesh and spine inside, a few ribs (the "light" in light gore: no organs).
	m.box(Vector3(CX - 0.14, 0.94, CZ - 0.07), Vector3(CX + 0.14, 1.42, CZ + 0.07), flesh)
	m.box(Vector3(CX - 0.02, 0.96, CZ + 0.02), Vector3(CX + 0.02, 1.44, CZ + 0.06), bone)
	for y in [1.2, 1.27, 1.34]:
		m.box(Vector3(CX - 0.11, y, CZ - 0.05), Vector3(CX + 0.11, y + 0.02, CZ - 0.03), bone)
	# Open jacket front: a V of shirt, the tie down the middle, lapels either side.
	var front := CZ - 0.115
	var v := PackedVector2Array([Vector2(CX - 0.075, 1.44), Vector2(CX + 0.075, 1.44), Vector2(CX + 0.01, 1.14), Vector2(CX - 0.01, 1.14)])
	m.prism_xy(v, front, front + 0.02, shirt)
	m.box(Vector3(CX - 0.016, 1.12, front - 0.01), Vector3(CX + 0.016, 1.4, front + 0.01), tie)
	m.box(Vector3(CX - 0.022, 1.38, front - 0.012), Vector3(CX + 0.022, 1.43, front + 0.01), tie)
	for s in [-1.0, 1.0]:
		var lapel_shape := PackedVector2Array([Vector2(CX + s * 0.075, 1.44), Vector2(CX + s * 0.12, 1.4), Vector2(CX + s * 0.03, 1.15), Vector2(CX + s * 0.012, 1.15)])
		m.prism_xy(lapel_shape, front - 0.012, front + 0.005, lapel)
	# Shirt collar round the neck.
	m.box(Vector3(CX - 0.06, 1.44, CZ - 0.07), Vector3(CX + 0.06, 1.49, CZ + 0.06), shirt)
	# Two jacket buttons, a breast pocket with a white square.
	for y in [1.04, 1.1]:
		m.box(Vector3(CX - 0.006, y, front - 0.012), Vector3(CX + 0.014, y + 0.02, front), lapel)
	m.repaint(Vector3(CX - 0.15, 1.3, front - 0.01), Vector3(CX - 0.07, 1.32, front + 0.01), lapel)
	m.box(Vector3(CX - 0.14, 1.32, front - 0.01), Vector3(CX - 0.1, 1.35, front + 0.01), shirt)
	# Lanyard round the neck to a badge on the chest (a game-show staff pass).
	for s in [-1.0, 1.0]:
		for i in 9:
			var t := i / 8.0
			var x: float = CX + s * lerpf(0.055, 0.03, t)
			var y := lerpf(1.44, 1.25, t)
			m.box(Vector3(x - 0.008, y, front - 0.016), Vector3(x + 0.008, y + 0.025, front - 0.004), lanyard)
	m.box(Vector3(CX + 0.03, 1.15, front - 0.022), Vector3(CX + 0.1, 1.25, front - 0.008), badge)
	m.repaint(Vector3(CX + 0.03, 1.22, front - 0.025), Vector3(CX + 0.1, 1.25, front - 0.02), lanyard)
	# Belt peeking out under the jacket hem.
	m.repaint(Vector3(CX - 0.17, 0.97, CZ - 0.12), Vector3(CX + 0.17, 0.99, CZ + 0.12), shoe)


# --- Head: neck, face, ears, hair

func _head() -> void:
	_begin(1)
	# Neck (goes with the head, so a beheading takes it).
	m.cylinder(Vector3(CX, 1.48, CZ + 0.005), "y", 0.1, 0.045, skin)
	m.cylinder(Vector3(CX, 1.48, CZ + 0.005), "y", 0.1, 0.022, flesh)
	m.cylinder(Vector3(CX, 1.48, CZ + 0.02), "y", 0.1, 0.012, bone)
	# A long face: skull of skin over flesh, a bone skull inside.
	var face := CZ - 0.105
	m.rounded(Vector3(CX - 0.085, 1.56, face), Vector3(CX + 0.085, 1.82, CZ + 0.1), 0.045, skin)
	m.ellipsoid(Vector3(CX, 1.69, CZ), Vector3(0.06, 0.1, 0.075), flesh)
	m.ellipsoid(Vector3(CX, 1.71, CZ + 0.005), Vector3(0.05, 0.07, 0.06), bone)
	# Jaw: slightly narrower at the chin.
	m.cut(Vector3(CX - 0.09, 1.56, face - 0.01), Vector3(CX - 0.065, 1.6, face + 0.04))
	m.cut(Vector3(CX + 0.065, 1.56, face - 0.01), Vector3(CX + 0.09, 1.6, face + 0.04))
	# Eyes: 3x3 voxel whites with a pupil each (repainted as X's on death).
	for s in [-1.0, 1.0]:
		var ex: float = CX + s * 0.04
		m.repaint(Vector3(ex - 0.03, 1.68, face - 0.005), Vector3(ex + 0.03, 1.74, face + 0.015), eye)
		m.repaint(Vector3(ex - 0.01, 1.70, face - 0.005), Vector3(ex + 0.01, 1.72, face + 0.015), pupil)
		# Eyebrows, a touch raised (permanently mildly concerned).
		m.box(Vector3(ex - 0.03, 1.75, face - 0.012), Vector3(ex + 0.03, 1.77, face + 0.008), hair)
		# Ears.
		m.box(Vector3(CX + s * 0.085 - (0.02 if s > 0 else 0.0), 1.66, CZ - 0.01), Vector3(CX + s * 0.085 + (0.0 if s > 0 else 0.02), 1.73, CZ + 0.03), skin)
	# Nose and an apologetic smile.
	m.box(Vector3(CX - 0.012, 1.64, face - 0.025), Vector3(CX + 0.012, 1.69, face + 0.01), skin)
	m.repaint(Vector3(CX - 0.035, 1.6, face - 0.005), Vector3(CX + 0.035, 1.62, face + 0.015), lip)
	m.repaint(Vector3(CX - 0.045, 1.62, face - 0.005), Vector3(CX - 0.03, 1.64, face + 0.015), lip)
	m.repaint(Vector3(CX + 0.03, 1.62, face - 0.005), Vector3(CX + 0.045, 1.64, face + 0.015), lip)
	# Neat side-parted hair: a cap over the top and back, a sweep at the front.
	m.rounded(Vector3(CX - 0.093, 1.76, face + 0.005), Vector3(CX + 0.093, 1.88, CZ + 0.108), 0.05, hair)
	m.box(Vector3(CX - 0.093, 1.62, CZ + 0.04), Vector3(CX + 0.093, 1.8, CZ + 0.108), hair)
	m.box(Vector3(CX - 0.09, 1.79, face - 0.012), Vector3(CX + 0.07, 1.84, face + 0.03), hair)
	m.cut(Vector3(CX + 0.04, 1.83, face - 0.02), Vector3(CX + 0.06, 1.89, CZ + 0.12))
	m.end_part()


# --- Arms: jacket sleeves, shirt cuffs, hands. side 1 = right (+X).

func _arm(side: float) -> void:
	var upper := 2 if side > 0 else 4
	var lower := upper + 1
	var x := CX + side * 0.235
	_begin(upper)
	m.rounded(Vector3(CX + side * 0.18 - 0.05, 1.36, CZ - 0.06), Vector3(CX + side * 0.18 + 0.05, 1.46, CZ + 0.06), 0.04, suit)
	_segment(x, 1.13, 1.42, 0.05, 0.055, suit, 0.016)
	m.end_part()
	_begin(lower)
	_segment(x, 0.9, 1.13, 0.045, 0.05, suit, 0.014)
	m.box(Vector3(x - 0.04, 0.87, CZ - 0.045), Vector3(x + 0.04, 0.9, CZ + 0.045), shirt)
	# Hand: palm and fingers (a groove between), thumb toward the front.
	m.rounded(Vector3(x - 0.032, 0.76, CZ - 0.04), Vector3(x + 0.032, 0.88, CZ + 0.035), 0.015, skin)
	m.box(Vector3(x - 0.012, 0.78, CZ - 0.02), Vector3(x + 0.012, 0.86, CZ + 0.015), flesh)
	for z in [CZ - 0.012, CZ + 0.012]:
		m.cut(Vector3(x - 0.034, 0.76, z - 0.002), Vector3(x + 0.034, 0.8, z + 0.002))
	m.box(Vector3(x - side * 0.02 - 0.012, 0.8, CZ - 0.06), Vector3(x - side * 0.02 + 0.012, 0.85, CZ - 0.035), skin)
	m.end_part()


# --- Legs: trousers, socks, shoes

func _leg(side: float) -> void:
	var upper := 6 if side > 0 else 8
	var lower := upper + 1
	var x := CX + side * 0.09
	_begin(upper)
	_segment(x, 0.51, 0.94, 0.065, 0.07, suit, 0.02)
	m.end_part()
	_begin(lower)
	_segment(x, 0.1, 0.51, 0.058, 0.062, suit, 0.017)
	# A crease down the front of each trouser leg.
	m.repaint(Vector3(x - 0.005, 0.12, CZ - 0.065), Vector3(x + 0.005, 0.5, CZ - 0.055), lapel)
	# Shoe: polished upper, toe cap, lighter sole, a flash of sock.
	m.box(Vector3(x - 0.05, 0.08, CZ - 0.04), Vector3(x + 0.05, 0.11, CZ + 0.05), lapel)
	m.rounded(Vector3(x - 0.055, 0.01, CZ - 0.17), Vector3(x + 0.055, 0.09, CZ + 0.075), 0.03, shoe)
	m.box(Vector3(x - 0.056, 0.0, CZ - 0.172), Vector3(x + 0.056, 0.02, CZ + 0.077), sole)
	m.repaint(Vector3(x - 0.06, 0.06, CZ - 0.18), Vector3(x + 0.06, 0.08, CZ - 0.15), sole)
	m.end_part()


# --- The clipboard (a separate held prop)

static func clipboard(model: FurnitureModel) -> void:
	var board := model.paint("plywood", Color(0.62, 0.48, 0.3), FurnitureModel.Finish.GRAIN)
	var paper := model.paint("paper", Color(0.97, 0.97, 0.94))
	var ink := model.paint("paper", Color(0.2, 0.22, 0.3))
	var clip := model.paint("steel", Color(0.7, 0.72, 0.74), FurnitureModel.Finish.BRUSHED)
	model.box(Vector3(0.0, 0.0, 0.0), Vector3(0.24, 0.32, 0.016), board)
	model.box(Vector3(0.015, 0.015, -0.006), Vector3(0.225, 0.28, 0.0), paper)
	# Lines of very important notes.
	for i in 7:
		var y := 0.04 + i * 0.032
		model.repaint(Vector3(0.03, y, -0.008), Vector3(0.03 + (0.17 if i % 3 != 2 else 0.1), y + 0.008, -0.005), ink)
	model.box(Vector3(0.08, 0.28, -0.014), Vector3(0.16, 0.33, 0.004), clip)
