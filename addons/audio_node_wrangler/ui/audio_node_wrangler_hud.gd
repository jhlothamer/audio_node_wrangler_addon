extends CanvasLayer

const MIN_FULL_UI_SIZE = Vector2(880,400)

enum UISizeSelection {
	Auto,
	Full,
	Mini,
}

## Set UI size - Full for HD or Mini for Pixel Art or Auto to let Audio Node Wrangler decide
@export var ui_size_selection := UISizeSelection.Auto


@onready var _ui:Control = $AudioNodeWranglerUI
@onready var _mini_ui:Control = $AudionNodeWranglerMiniUI


# if tree already paused when ui shown, keep paused after ui dismissed
var _prev_tree_paused := false
var _current_ui:Control

func _ready() -> void:
	_ui.visible = false
	_mini_ui.visible = false
	if ui_size_selection == UISizeSelection.Full:
		_current_ui = _ui
		return
	elif ui_size_selection == UISizeSelection.Mini:
		_current_ui = _mini_ui
		return
	var current_screen_size := _ui.get_viewport_rect().size
	if current_screen_size.x < MIN_FULL_UI_SIZE.x or current_screen_size.y < MIN_FULL_UI_SIZE.y:
		_current_ui = _mini_ui
	else:
		_current_ui = _ui


func _input(event: InputEvent) -> void:
	if event.is_action(AudioNodeWranglerConsts.AUDIO_NODE_WRANGLER_TOGGLE_HUD_ACTION_NAME) and event.is_pressed():
		
		if !_current_ui.visible:
			_current_ui._refresh_list()
			_current_ui.visible = true
			_prev_tree_paused = get_tree().paused
			get_tree().paused = true
		else:
			_current_ui._about_to_hide()
			_current_ui.visible = false
			get_tree().paused = _prev_tree_paused


func _on_audio_node_wrangler_ui_closed_pressed() -> void:
	_ui.visible = false
	get_tree().paused = _prev_tree_paused


func _on_audion_node_wrangler_mini_ui_closed_pressed() -> void:
	_mini_ui.visible = false
	get_tree().paused = _prev_tree_paused
