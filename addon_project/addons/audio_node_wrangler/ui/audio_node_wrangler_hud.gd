extends CanvasLayer


@onready var _ui:Control = $SoundMgrUi


# if tree already paused when ui shown, keep paused after ui dismissed
var _prev_tree_paused := false


func _ready() -> void:
	_ui.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action(AudioNodeWranglerConsts.AUDIO_NODE_WRANGLER_TOGGLE_HUD_ACTION_NAME) and event.is_pressed():
		if !_ui.visible:
			_ui._refresh_list()
			_ui.visible = true
			_prev_tree_paused = get_tree().paused
			get_tree().paused = true
		else:
			_ui._about_to_hide()
			_ui.visible = false
			get_tree().paused = _prev_tree_paused


func _on_sound_mgr_ui_closed_pressed() -> void:
	_ui.visible = false
	get_tree().paused = _prev_tree_paused
