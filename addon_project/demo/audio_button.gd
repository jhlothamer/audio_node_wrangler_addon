class_name AudioButton
extends Button


@export var hover_sound_node:AudioStreamPlayer
@export var pressed_sound_node:AudioStreamPlayer


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)


func _on_mouse_entered() -> void:
	if hover_sound_node:
		hover_sound_node.play()


func _gui_input(event: InputEvent) -> void:
	if not pressed_sound_node:
		return
	
	if not event is InputEventMouseButton:
		return
	
	var mb_event:InputEventMouseButton = event
	if not _matches_action_mode(mb_event) or not _matches_button_mask(mb_event):
		return
	
	#this prevents the base button code from emitting pressed before the sound is done playing
	get_viewport().set_input_as_handled()
	
	pressed_sound_node.play()
	await pressed_sound_node.finished
	pressed.emit()


func _matches_button_mask(mb_event:InputEventMouseButton) -> bool:
	if button_mask & MOUSE_BUTTON_MASK_LEFT and mb_event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if button_mask & MOUSE_BUTTON_MASK_RIGHT and mb_event.button_index == MOUSE_BUTTON_RIGHT:
		return true
	if button_mask & MOUSE_BUTTON_MASK_MIDDLE and mb_event.button_index == MOUSE_BUTTON_MIDDLE:
		return true
	return false


func _matches_action_mode(mb_event:InputEventMouseButton) -> bool:
	if action_mode == ACTION_MODE_BUTTON_PRESS and mb_event.pressed:
		return true
	if action_mode == ACTION_MODE_BUTTON_RELEASE and !mb_event.pressed:
		return true
	return false

