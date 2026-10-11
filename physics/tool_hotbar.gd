class_name ToolHotbar
extends Node
## A player's tool hotbar: numbered slots that store equippable tool instances.
##
## Tap a number with a tool in hand (equipped or just held) to store it in that
## slot; tap an occupied slot with empty hands to equip its tool; tap the slot of
## the tool you're using to put it away; tap another occupied slot to swap. Hold a
## number to drop that slot's tool back into the world.
##
## Stored tools are the same nodes, never copies. While stored they stay in the
## scene but are suspended (the vacuum's approach): hidden, frozen, out of physics
## and not processing, so all their state survives. Equipping and putting away go
## through ToolHandler, exactly like F does.
##
## Needs a ToolHandler and ObjectManipulator; draws its slots on the given HUD.

signal changed

@export_range(1, 9) var slot_count: int = 4
## How long a number must be held to drop that slot's tool.
@export_range(0.15, 2.0, 0.05, "suffix:s") var drop_hold_time: float = 0.45

var tool_handler: ToolHandler
var manipulator: ObjectManipulator
var hud: CanvasLayer
## Optional: the player, for gameplay_enabled and rope climbing checks.
var player: Node

var _slots: Array[RigidBody3D] = []
## Per stored body: the state to restore when it comes out.
var _suspended: Dictionary = {}
var _press_time: Array[float] = []
var _drop_fired: Array[bool] = []
var _ui: Control
var _boxes: Array[PanelContainer] = []
var _names: Array[Label] = []
var _message: Label
var _message_time: float = 0.0


func setup(handler: ToolHandler, hands: ObjectManipulator, overlay: CanvasLayer, owner_player: Node = null) -> void:
	tool_handler = handler
	manipulator = hands
	hud = overlay
	player = owner_player


func _ready() -> void:
	_slots.resize(slot_count)
	_press_time.resize(slot_count)
	_press_time.fill(-1.0)
	_drop_fired.resize(slot_count)
	_drop_fired.fill(false)
	_ensure_actions()
	if hud != null:
		_build_ui()
	_refresh()


## The tool in a slot (stored or in hand), or null.
func get_slot(index: int) -> RigidBody3D:
	return _slots[index] if index >= 0 and index < _slots.size() and is_instance_valid(_slots[index]) else null


## The slot holding `body`, or -1.
func slot_of(body: RigidBody3D) -> int:
	for index in _slots.size():
		if body != null and _slots[index] == body:
			return index
	return -1


## The slot whose tool is in the player's hand right now, or -1.
func selected_slot() -> int:
	return slot_of(_in_hand())


func is_stored(body: RigidBody3D) -> bool:
	return body != null and _suspended.has(body)


## Only things the tool handler could equip go in the hotbar.
func can_store(body: RigidBody3D) -> bool:
	if body == null or tool_handler == null or tool_handler.get_tool_definition(body) == null:
		return false
	var world := ContraptionWorld.find(body)
	return world == null or not world.attached(body)


# --- Actions

## A tap on slot `index` (0-based).
func press(index: int) -> void:
	var in_hand := _in_hand()
	var slot_tool := get_slot(index)
	if in_hand == null:
		if slot_tool == null:
			_say("Slot %d is empty" % (index + 1))
		elif _climbing():
			_say("Hands are full climbing")
		else:
			_retrieve(index)
		return
	var current := slot_of(in_hand)
	if current == index:
		_store(in_hand, index)
		return
	if not can_store(in_hand):
		_say("Only tools fit in the hotbar")
		return
	if current >= 0:
		# Switching from one hotbar tool to another (or moving it to an empty slot).
		if slot_tool != null:
			_store(in_hand, current)
			_retrieve(index)
		else:
			_slots[current] = null
			_store(in_hand, index)
		return
	if slot_tool != null:
		_say("Slot %d holds the %s. Hold %d to drop it, or pick an empty slot" % [index + 1, _name_of(slot_tool), index + 1])
		return
	_store(in_hand, index)


## Holding slot `index`: its tool goes back into the world.
func drop(index: int) -> void:
	var body := get_slot(index)
	if body == null:
		return
	if is_stored(body):
		_resume(body)
		body.global_transform = _hand_transform(Vector3(0.0, -0.25, -0.7))
		body.linear_velocity = _holder_velocity() + _view_forward() * 1.5
	elif body == tool_handler.get_equipped_body():
		tool_handler.drop()
	elif body == manipulator.get_held_body():
		manipulator.release()
	_slots[index] = null
	_say("Dropped the %s" % _name_of(body))
	_refresh()


func _store(body: RigidBody3D, index: int) -> void:
	if body == tool_handler.get_equipped_body():
		body = tool_handler.stow()
	elif body == manipulator.get_held_body():
		body = manipulator.take_held_body()
	if body == null:
		return
	_suspend(body)
	_slots[index] = body
	_refresh()


func _retrieve(index: int) -> void:
	var body := get_slot(index)
	if body == null:
		return
	_resume(body)
	# Draw it up from the hip: the equip animation starts from here.
	body.global_transform = _hand_transform(Vector3(0.25, -0.65, -0.2))
	if not tool_handler.equip(body):
		# Couldn't equip (shouldn't happen with empty hands): keep it safe in its slot.
		_suspend(body)
		_say("Can't equip the %s right now" % _name_of(body))
	_refresh()


func _suspend(body: RigidBody3D) -> void:
	if _suspended.has(body):
		return
	_suspended[body] = {
		"process_mode": body.process_mode, "visible": body.visible, "freeze": body.freeze,
		"freeze_mode": body.freeze_mode, "layer": body.collision_layer, "mask": body.collision_mask,
		"groups": body.get_groups().filter(func(group): return group == &"physics_props"),
	}
	body.set_meta(&"hotbar_stored", true)
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	body.freeze = true
	body.collision_layer = 0
	body.collision_mask = 0
	body.hide()
	# Level resets mustn't teleport it while it's away.
	for group in _suspended[body]["groups"]:
		body.remove_from_group(group)
	# Disabled bodies leave the physics space and stop processing (children too).
	body.process_mode = Node.PROCESS_MODE_DISABLED
	if not body.tree_exiting.is_connected(_on_stored_body_exiting):
		body.tree_exiting.connect(_on_stored_body_exiting.bind(body))


func _resume(body: RigidBody3D) -> void:
	var saved: Dictionary = _suspended.get(body, {})
	if saved.is_empty():
		return
	_suspended.erase(body)
	if body.tree_exiting.is_connected(_on_stored_body_exiting):
		body.tree_exiting.disconnect(_on_stored_body_exiting)
	body.process_mode = saved["process_mode"]
	for group in saved["groups"]:
		body.add_to_group(group)
	body.collision_layer = saved["layer"]
	body.collision_mask = saved["mask"]
	body.freeze_mode = saved["freeze_mode"]
	body.freeze = saved["freeze"]
	body.visible = saved["visible"]
	body.remove_meta(&"hotbar_stored")
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.sleeping = false


## A stored tool deleted by something else (e.g. clearing spawned objects).
func _on_stored_body_exiting(body: RigidBody3D) -> void:
	_suspended.erase(body)
	var index := slot_of(body)
	if index >= 0:
		_slots[index] = null
	_refresh.call_deferred()


# --- Input and upkeep

func _process(delta: float) -> void:
	_message_time = maxf(0.0, _message_time - delta)
	if _message != null:
		_message.modulate.a = clampf(_message_time / 0.4, 0.0, 1.0)
	_forget_lost_tools()
	var active := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and (player == null or bool(player.get(&"gameplay_enabled")))
	for index in slot_count:
		var action := _action(index)
		var down := active and Input.is_action_pressed(action)
		if down:
			if _press_time[index] < 0.0:
				_press_time[index] = 0.0
				_drop_fired[index] = false
			else:
				_press_time[index] += delta
			if not _drop_fired[index] and _press_time[index] >= drop_hold_time and get_slot(index) != null:
				_drop_fired[index] = true
				drop(index)
		elif _press_time[index] >= 0.0:
			# Released: a short press is a tap.
			if active and not _drop_fired[index]:
				press(index)
			_press_time[index] = -1.0
	_refresh_selection()


## Tools taken out of the hotbar that left the hand (dropped, thrown, deleted)
## are no longer the slot's: they behave like any other object in the world.
func _forget_lost_tools() -> void:
	var in_hand := _in_hand()
	var dirty := false
	for index in _slots.size():
		var body := _slots[index]
		if body == null:
			continue
		if not is_instance_valid(body) or (not _suspended.has(body) and body != in_hand):
			_slots[index] = null
			dirty = true
	if dirty:
		_refresh()


func _ensure_actions() -> void:
	for index in slot_count:
		var action := _action(index)
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_1 + index
		InputMap.action_add_event(action, key)


static func _action(index: int) -> StringName:
	return StringName("hotbar_%d" % (index + 1))


# --- Helpers

func _in_hand() -> RigidBody3D:
	if tool_handler != null and tool_handler.is_equipped():
		return tool_handler.get_equipped_body()
	if manipulator != null and manipulator.is_holding():
		return manipulator.get_held_body()
	return null


func _climbing() -> bool:
	var climber: Variant = player.get(&"climber") if player != null else null
	return climber is RopeClimber and climber.is_climbing()


func _view() -> Node3D:
	return tool_handler.view if tool_handler != null else null


func _hand_transform(offset: Vector3) -> Transform3D:
	var view := _view()
	if view == null:
		return Transform3D.IDENTITY
	var basis := view.global_basis.orthonormalized()
	return Transform3D(basis, view.global_position + basis * offset)


func _view_forward() -> Vector3:
	var view := _view()
	return -view.global_basis.z.normalized() if view != null else Vector3.FORWARD


func _holder_velocity() -> Vector3:
	var body := player as CharacterBody3D
	return body.get_real_velocity() if body != null else Vector3.ZERO


static func _name_of(body: RigidBody3D) -> String:
	if body == null:
		return ""
	if body.has_method("get_grab_name"):
		return str(body.call("get_grab_name"))
	return str(body.name)


func _say(text: String) -> void:
	if _message != null:
		_message.text = text
		_message_time = 2.2


# --- HUD

const UiStyle := preload("res://ui/ui_style.gd")
const SLOT_SIZE := Vector2(128, 46)


func _build_ui() -> void:
	_ui = Control.new()
	_ui.name = "Hotbar"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(_ui)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 4)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_bottom = -14.0
	_ui.add_child(column)
	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_message.add_theme_constant_override("outline_size", 4)
	_message.add_theme_font_size_override("font_size", 14)
	_message.modulate.a = 0.0
	column.add_child(_message)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	for index in slot_count:
		var box := PanelContainer.new()
		box.custom_minimum_size = SLOT_SIZE
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)
		var inside := VBoxContainer.new()
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.add_theme_constant_override("separation", 0)
		box.add_child(inside)
		var number := Label.new()
		number.text = str(index + 1)
		number.add_theme_font_size_override("font_size", 11)
		number.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
		inside.add_child(number)
		var title := Label.new()
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_theme_font_size_override("font_size", 14)
		inside.add_child(title)
		_boxes.append(box)
		_names.append(title)
	var hint := Label.new()
	hint.text = "1–4 store / equip   ·   hold to drop"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	hint.add_theme_constant_override("outline_size", 3)
	column.add_child(hint)


func _refresh() -> void:
	if _ui == null:
		changed.emit()
		return
	for index in _boxes.size():
		var body := get_slot(index)
		_names[index].text = _name_of(body) if body != null else "Empty"
	_refresh_selection(true)
	changed.emit()


var _shown_selection := -2


func _refresh_selection(force := false) -> void:
	if _ui == null:
		return
	var selected := selected_slot()
	if selected == _shown_selection and not force:
		return
	_shown_selection = selected
	for index in _boxes.size():
		var occupied := get_slot(index) != null
		var style: StyleBoxFlat
		if index == selected:
			style = UiStyle.flat(Color(0.2, 0.3, 0.46, 0.92), 6)
			style.border_color = Color(0.45, 0.65, 1.0)
		elif occupied:
			style = UiStyle.flat(Color(0.14, 0.15, 0.19, 0.82), 6)
			style.border_color = Color(1, 1, 1, 0.22)
		else:
			style = UiStyle.flat(Color(0.06, 0.07, 0.09, 0.68), 6)
			style.border_color = Color(1, 1, 1, 0.08)
		style.set_border_width_all(2 if index == selected else 1)
		style.content_margin_top = 3
		style.content_margin_bottom = 4
		style.content_margin_left = 7
		style.content_margin_right = 7
		_boxes[index].add_theme_stylebox_override("panel", style)
		_names[index].add_theme_color_override("font_color", Color.WHITE if occupied else Color(1, 1, 1, 0.35))
