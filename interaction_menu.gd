extends Control
## Any target exposing get_interaction_actions() and perform_interaction_action()
## can use this menu. Action IDs remain owned by the target, not the UI.

@onready var target_name: Label = $Panel/Margin/Content/TargetName
@onready var action_list: VBoxContainer = $Panel/Margin/Content/Actions

var _target: Node
var _actor: Node
var _action_buttons: Array[Button] = []
var _action_ids: Array[StringName] = []
var _selected_id: StringName = &""


func _ready() -> void:
	hide()
	set_process(false)


func is_open() -> bool:
	return visible


func open_for(target: Node, actor: Node) -> void:
	if is_open() and _target == target:
		return
	if not target.has_method("get_interaction_actions") or not target.has_method("perform_interaction_action"):
		return
	close_menu()
	_target = target
	_actor = actor
	_selected_id = &""
	if _target.has_signal("interaction_actions_changed"):
		_target.connect("interaction_actions_changed", _refresh_actions)
	target_name.text = str(_target.call("get_interaction_prompt")) if _target.has_method("get_interaction_prompt") else str(_target.name)
	show()
	_refresh_actions()
	set_process(true)


func close_menu() -> void:
	if not is_open():
		return
	if is_instance_valid(_target) and _target.has_signal("interaction_actions_changed"):
		_target.disconnect("interaction_actions_changed", _refresh_actions)
	_target = null
	_actor = null
	hide()
	set_process(false)


func _refresh_actions() -> void:
	if not is_instance_valid(_target):
		close_menu()
		return
	for child in action_list.get_children():
		action_list.remove_child(child)
		child.queue_free()
	_action_buttons.clear()
	_action_ids.clear()
	target_name.text = str(_target.call("get_interaction_prompt")) if _target.has_method("get_interaction_prompt") else str(_target.name)
	var actions: Array = _target.call("get_interaction_actions")
	var first_available: Button = null
	var selected_button: Button = null
	for action: Dictionary in actions:
		var button := Button.new()
		button.text = str(action["label"])
		button.disabled = not bool(action.get("enabled", true))
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var action_id := StringName(action["id"])
		action_list.add_child(button)
		_action_buttons.append(button)
		_action_ids.append(action_id)
		if first_available == null and not button.disabled:
			first_available = button
		if action_id == _selected_id and not button.disabled:
			selected_button = button
	if selected_button != null:
		_set_selection(_selected_id)
	elif first_available != null:
		_set_selection(_action_ids[_action_buttons.find(first_available)])
	else:
		_selected_id = &""


func _set_selection(action_id: StringName) -> void:
	_selected_id = action_id
	for index in range(_action_buttons.size()):
		_action_buttons[index].set_pressed_no_signal(_action_ids[index] == action_id)


func _scroll_selection(step: int) -> void:
	if _action_buttons.is_empty():
		return
	var index := _action_ids.find(_selected_id)
	for _attempt in range(_action_buttons.size()):
		index = wrapi(index + step, 0, _action_buttons.size())
		if not _action_buttons[index].disabled:
			_set_selection(_action_ids[index])
			return


func _input(event: InputEvent) -> void:
	if not is_open() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_selection(-1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_selection(1)
	else:
		return
	get_viewport().set_input_as_handled()


func perform_selected_action() -> void:
	if is_instance_valid(_target) and is_instance_valid(_actor) and _selected_id != &"":
		_target.call("perform_interaction_action", _selected_id, _actor)


func _process(_delta: float) -> void:
	if not is_instance_valid(_target) or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		close_menu()
