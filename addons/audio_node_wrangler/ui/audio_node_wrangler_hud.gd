extends CanvasLayer


const MIN_FULL_UI_SIZE = Vector2(880,400)


@onready var _ui:Control = $AudioNodeWranglerUI


# if tree already paused when ui shown, keep paused after ui dismissed
var _prev_tree_paused := false


func _ready() -> void:
	_ui.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action(AudioNodeWranglerConsts.AUDIO_NODE_WRANGLER_TOGGLE_HUD_ACTION_NAME) and event.is_pressed():
		var current_screen_size := _ui.get_viewport_rect().size
		if current_screen_size.x < MIN_FULL_UI_SIZE.x or current_screen_size.y < MIN_FULL_UI_SIZE.y:
			print("too small to show full size ui")
			return
		
		if !_ui.visible:
			_ui._refresh_list()
			_ui.visible = true
			_prev_tree_paused = get_tree().paused
			get_tree().paused = true
		else:
			_ui._about_to_hide()
			_ui.visible = false
			get_tree().paused = _prev_tree_paused


func _on_audio_node_wrangler_ui_closed_pressed() -> void:
	_ui.visible = false
	get_tree().paused = _prev_tree_paused
