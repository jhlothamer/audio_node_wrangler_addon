@tool
extends EditorPlugin


const UI_SCENE = preload("res://addons/audio_node_wrangler/ui/audio_node_wrangler_ui.tscn")
const UI_ICON = preload("res://addons/audio_node_wrangler/ui/audio_node_wrangler_icon.svg")
const AUTOLOAD_CLASS_PATH = "res://addons/audio_node_wrangler/audio_node_wrangler_mgr.gd"
const AUTOLOAD_NAME = "AudioNodeWranglerMgr"


var _consts = preload("res://addons/audio_node_wrangler/audio_node_wrangler_consts.gd").new()
var _ui:Control


func _enter_tree() -> void:
	call_deferred("_add_ui")


func _ready() -> void:
	call_deferred("_update_mgr")


func _add_ui() -> void:
	_ui = UI_SCENE.instantiate()
	_ui.editor_interface = get_editor_interface()
	get_editor_interface().get_editor_main_screen().add_child(_ui)
	_make_visible(false)


func _exit_tree() -> void:
	if _ui:
		_ui.queue_free()
		_ui = null


func _enable_plugin() -> void:
	var _discard = AudioNodeWranglerProjectSettingsHelper.get_git_commit_warn()
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_CLASS_PATH)
	
	_add_input_actions([
		{
			"name": _consts.AUDIO_NODE_WRANGLER_TOGGLE_HUD_ACTION_NAME,
			"events": [
				{
					"keycode": KEY_F1
				}
			]
		}
	])


func _add_input_actions(actions:Array[Dictionary]) -> void:
	var added_actions:Array[String] = []
	for action in actions:
		var setting_name = "input/%s" % action["name"]
		if ProjectSettings.has_setting(setting_name):
			continue
		var events = []
		for event in action["events"]:
			if event.has("keycode"):
				var key_event := InputEventKey.new()
				key_event.keycode = event["keycode"]
				events.append(key_event)
		if events.is_empty():
			continue
		ProjectSettings.set_setting(setting_name, {
			"deadzone": .5,
			"events": events
		})
		added_actions.append(action["name"])
	if !added_actions.is_empty():
		print("AudioNodeWrangler: The following input actions have been added.  To see them in project settings, please reload the project.\n%s" 
		% ", ".join(added_actions))


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)
	if _ui:
		_ui.queue_free()
		_ui = null


func _apply_changes() -> void:
	var autoload:Node = get_node_or_null("/root/%s" % AUTOLOAD_NAME)
	if autoload:
		autoload.save_data()
	else:
		printerr("AudioNodeWrangler: cannot ref %s autoload to save data" % AUTOLOAD_NAME)


func _has_main_screen():
	return true


func _make_visible(visible):
	if _ui:
		_ui.visible = visible


func _get_plugin_name():
	return "AudioNodeWrangler"


func _get_plugin_icon():
	return UI_ICON

func _update_mgr() -> void:
	var mgr = get_node_or_null("/root/%s" % AUTOLOAD_NAME)
	if !mgr:
		print("AudioNodeWranglerPlugin: could not get ref to autoload %s" % AUTOLOAD_NAME)
		return
	mgr._editor = get_editor_interface()
