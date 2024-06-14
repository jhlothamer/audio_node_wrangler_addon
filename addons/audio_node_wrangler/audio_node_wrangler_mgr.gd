@tool
extends Node

signal data_changed()

const _SOUND_MGR_HUD_SCENE = preload("res://addons/audio_node_wrangler/ui/audio_node_wrangler_hud.tscn")
const DATA_FILE_PATH = "user://audio_node_wrangler_data/audio_node_wrangler_data.json"

#map's audio settting id to setting object
var _data := {}
#used to quickly tell if data should be re-loaded
var _data_file_mod_time := -1
#map audio node id (scene_path::node_path) to instances of that audio node
var _audio_node_instances := {}
#audio nodes added before data is loaded add to this list - to be added to _audio_node_instances after data loaded
var _audio_nodes_added_early := []
var _editor:EditorInterface
var _cached_bus_names := []


func _enter_tree() -> void:
	var running_in_editor := Engine.is_editor_hint()
	if !running_in_editor and OS.has_feature("debug"):
		get_tree().node_added.connect(_on_node_added)

	if !running_in_editor:
		return

	# bus_renamed available in Godot 4.2
	if AudioServer.has_signal("bus_renamed"):
		if OK != AudioServer.connect("bus_renamed", _on_bus_layout_changed):
			printerr("AudioNodeWranglerMgr: could not connect to AudioServer.bus_renamed")
	if OK != AudioServer.bus_layout_changed.connect(_on_bus_layout_changed):
		printerr("AudioNodeWranglerMgr: could not connect to AudioServer.bus_layout_changed")
	_cached_bus_names = _get_bus_names()


func _ready() -> void:
	load_data()
	_process_audio_nodes_added_early()
	# add in-game hud for sound mgr (and only in for debug builds)
	if !Engine.is_editor_hint() and OS.has_feature("debug"):
		var hud = _SOUND_MGR_HUD_SCENE.instantiate()
		get_parent().call_deferred("add_child", hud)
	var file_monitor := FileMonitor.new()
	file_monitor.file_path = DATA_FILE_PATH
	add_child(file_monitor)
	if OK != file_monitor.file_modified.connect(_on_data_file_modified):
		printerr("AudioNodeWranglerMgr: could not connect to file monitor signal")


func _get_bus_names() -> Array[String]:
	var busses:Array[String] = []
	
	for i in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(i)
		busses.append(bus)
	
	busses.sort()
	
	return busses



func scan_project(reset: bool = false) -> void:
	if reset:
		_data.clear()
	# recollect info from scene files
	var refreshed_data = _collect_aud_settings()
	# keep existing data
	for id in refreshed_data.keys():
		if _data.has(id):
			# keep any settings the user has changed
			refreshed_data[id].settings = _data[id].settings
	_data = refreshed_data
	save_data()
	data_changed.emit()


func save_data() -> void:
	_ensure_data_folder()

	var data := {}
	for id in _data.keys():
		var aud_setting = _data[id]
		data[id] = aud_setting.write_to_dictionary()
	
	var json_string = JSON.stringify(data, "\t")
	var f = FileAccess.open(DATA_FILE_PATH, FileAccess.WRITE)
	if !f:
		printerr("AudioNodeWranglerMgr: could not open sound data file %s" % DATA_FILE_PATH)
		return
	f.store_string(json_string)
	f.close()
	_data_file_mod_time = FileAccess.get_modified_time(DATA_FILE_PATH)

func load_data() -> void:
	_ensure_data_folder()
	if !FileAccess.file_exists(DATA_FILE_PATH):
		return
	var curr_mod_time := FileAccess.get_modified_time(DATA_FILE_PATH)
	if curr_mod_time == _data_file_mod_time:
		return
	var f = FileAccess.open(DATA_FILE_PATH, FileAccess.READ_WRITE)
	if !f:
		printerr("AudioNodeWranglerMgr: could not open sound data file %s" % DATA_FILE_PATH)
		return
	var json_string = f.get_as_text()
	var json = JSON.new()
	if OK != json.parse(json_string):
		printerr("AudioNodeWranglerMgr: error loading sound data: %s (line %s)" % [json.get_error_message(), json.get_error_line()])
		return
	
	var saved_data:Dictionary = json.data
	_data.clear()
	for id in saved_data.keys():
		var aud_setting_data:Dictionary = saved_data[id]
		var aud_setting := AudioStreamPlayerSettings.new()
		aud_setting.read_from_dictionary(aud_setting_data)
		_data[aud_setting.id] = aud_setting
	data_changed.emit()
	_data_file_mod_time = curr_mod_time


func pre_apply_checks() -> PreApplyCheckResult:
	var scenes_needing_update := _get_scenes_needing_update()
	if scenes_needing_update.is_empty():
		return PreApplyCheckResult.new("No changes need to be applied.")
	
	#get scenes already open in editor
	var open_scenes := []
	if Engine.is_editor_hint() and _editor:
		open_scenes = _editor.get_open_scenes()
	
	#get scenes open and needing update
	var scenes_that_should_be_closed = open_scenes.filter(func(scene_path:String): 
		return scenes_needing_update.has(scene_path)
		)
	
	#editor gets confused if we update scene files it has open - to avoid issues just tell user to close them
	if !scenes_that_should_be_closed.is_empty():
		var msg = "The following scenes will be updated and are open.\n\n%s\n\nPlease close these scenes in the editor to continue." % "\n".join(scenes_that_should_be_closed)
		return PreApplyCheckResult.new(msg)
	
	#get list of files with changes that have not been committed (note: may have issues with this if git isn't installed)
	#note: user can turn this warning off via project setting
	var modified_files = [] if !AudioNodeWranglerProjectSettingsHelper.get_git_commit_warn() else _get_modified_files()

	#get list of modified files that will be updated by this process
	var modified_scenes_that_need_commit = scenes_needing_update.filter(func(scene_path:String):
		return modified_files.has(scene_path)
		)
	
	#warn user that they should commit changes to files to be updated
	#this makes it easier to rollback changes should there be an issue with the update process
	if !modified_scenes_that_need_commit.is_empty():
		var msg = "The following files have changes that should be commited before proceeding:\n\n%s\n\nProceed anyway?" % "\n".join(modified_scenes_that_need_commit)
		return PreApplyCheckResult.new(msg, PreApplyCheckResult.ResultMessageButtons.OK_CANCEL_NO_NAG, 
			AudioNodeWranglerProjectSettingsHelper.PROJECT_SETTING_GIT_COMMIT_WARN)
	
	#no issues found
	return PreApplyCheckResult.new()


func apply_settings() -> String:
	var scenes_needing_update := _get_scenes_needing_update()
	if scenes_needing_update.is_empty():
		return "No changes need to be applied."
	save_data()
	
	var updater := SceneFileUpdater.new()
	for path in scenes_needing_update:
		
		var settings_with_diffs:Array[AudioStreamPlayerSettings] = _get_settings_with_differences(path)
		if settings_with_diffs.is_empty():
			continue
		
		if !updater.update_scene_file(path, _get_updater_dictionary(settings_with_diffs)):
			return "Error updating scene '%s': %s" % [path, updater.error_message]
		_refresh_scene_file_aud_settings(path)
	
	scan_project()

	return "Changes have been applied"


func audio_node_has_instances(id: String) -> bool:
	return _audio_node_instances.has(id)


func show_data_file() -> void:
	save_data()
	var global_path = ProjectSettings.globalize_path(DATA_FILE_PATH)
	OS.shell_show_in_file_manager(global_path, false)


func _ensure_data_folder() -> void:
	var data_folder := DATA_FILE_PATH.get_base_dir()
	if !DirAccess.dir_exists_absolute(data_folder):
		DirAccess.make_dir_recursive_absolute(data_folder)


func _process_audio_nodes_added_early() -> void:
	for node in _audio_nodes_added_early:
		_process_added_audio_node(node)
	_audio_nodes_added_early.clear()


func _on_node_added(node: Node) -> void:
	#don't process dynamically created/added nodes
	if !node.owner:
		return
	
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if _data_file_mod_time < 0:
			_audio_nodes_added_early.append(node)
		else:
			_process_added_audio_node(node)


func _process_added_audio_node(node:Node) -> void:
	var id := AudioStreamPlayerSettings.get_id_for_audio_node(node)
	var setting:AudioStreamPlayerSettings
	if !_data.has(id):
		setting = AudioStreamPlayerSettings.new()
		setting.read_from_node(node)
		_data[setting.id] = setting
		print("AudioNodeWranglerMgr: audio node not listed in settings has been added: id = '%s'" % id)
	else:
		setting = _data[id]
	
	setting.create_or_update_player(node)
	if !_audio_node_instances.has(id):
		_audio_node_instances[id] = []
	_audio_node_instances[id].append(node)
	node.tree_exiting.connect(_on_audio_node_tree_exiting.bind(node))


func _on_audio_node_tree_exiting(node: Node) -> void:
	var id := AudioStreamPlayerSettings.get_id_for_audio_node(node)
	if _audio_node_instances.has(id):
		_audio_node_instances[id].erase(node)


func _collect_aud_settings() -> Dictionary:
	var data := {}
	var dirs := ["res://"]
	while !dirs.is_empty():
		var path = dirs.pop_front()
		var dir = DirAccess.open(path)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while !file_name.is_empty():
			var full_file_path := ""
			if path == "res://":
				full_file_path = "%s%s" % [path, file_name]
			else:
				full_file_path = "%s/%s" % [path, file_name]
			if dir.current_is_dir():
				dirs.append(full_file_path)
			else:
				var ext := file_name.get_extension().to_lower()
				if ext == "tscn" or ext == "scn":
					_collect_aud_settings_scene(full_file_path, data)
					#var audio_stream_player_settings = _process_scene_file(full_file_path)
					#for aud_setting in audio_stream_player_settings:
						#data[aud_setting.id] = aud_setting
			file_name = dir.get_next()
	return data


func _collect_aud_settings_scene(full_file_path: String, data: Dictionary) -> void:
	var audio_stream_player_settings = _process_scene_file(full_file_path)
	for aud_setting in audio_stream_player_settings:
		data[aud_setting.id] = aud_setting


func _refresh_scene_file_aud_settings(scene_path: String) -> void:
	var scene_settings:Array[AudioStreamPlayerSettings] = []
	for setting in _data.values():
		if setting.scene_path == scene_path:
			scene_settings.append(setting)
		
	for setting in scene_settings:
		_data.erase(setting.id)
	
	_collect_aud_settings_scene(scene_path, _data)


func _process_scene_file(path: String) -> Array[AudioStreamPlayerSettings]:
	var audio_stream_player_settings:Array[AudioStreamPlayerSettings] = []
	var ps:PackedScene = load(path)
	var ss := ps.get_state()
	for i in ss.get_node_count():
		var node_type := ss.get_node_type(i)
		if node_type.begins_with("AudioStreamPlayer"):
			var a := AudioStreamPlayerSettings.new()
			a.read_from_scene_state(path, ss, i)
			audio_stream_player_settings.append(a)
	return audio_stream_player_settings


func _get_scenes_needing_update() -> Array:
	var scenes_needing_update:Array[String] = []
	for settings in _data.values():
		if settings.needs_update_applied():
			if !scenes_needing_update.has(settings.scene_path):
				scenes_needing_update.append(settings.scene_path)
			break
	return scenes_needing_update


func _group_data_by_scene() -> Dictionary:
	var d := {}
	for id in _data.keys():
		pass
		var aud_setting:AudioStreamPlayerSettings = _data[id]
		if !d.has(aud_setting.scene_path):
			var a:Array[AudioStreamPlayerSettings] = []
			d[aud_setting.scene_path] = a
		d[aud_setting.scene_path].append(aud_setting)
	return d


func _get_settings_with_differences(path: String) -> Array[AudioStreamPlayerSettings]:
	var existing_settings = _process_scene_file(path)
	var settings_with_diffs:Array[AudioStreamPlayerSettings] = []
	for existing_setting in existing_settings:
		if !_data.has(existing_setting.id):
			continue
		var aud_setting:AudioStreamPlayerSettings = _data[existing_setting.id]
		if !aud_setting.should_update(existing_setting):
			continue
		settings_with_diffs.append(aud_setting)
	return settings_with_diffs


func _get_updater_dictionary(settings: Array[AudioStreamPlayerSettings]) -> Dictionary:
	var updater_dictionary := {}
	for setting in settings:
		var setting_update := setting.get_updater_property_dictionary()
		if setting_update.is_empty():
			continue
		updater_dictionary[setting.node_path] = setting_update
	return updater_dictionary


func _apply_audio_setting_to_current_players(setting:AudioStreamPlayerSettings) -> void:
	if !_audio_node_instances.has(setting.id) or _audio_node_instances[setting.id].is_empty():
		return
	for audio_stream_player in _audio_node_instances[setting.id]:
		setting.create_or_update_player(audio_stream_player)


func _on_data_file_modified() -> void:
	load_data()


func _get_modified_files() -> Array:
	var output := []
	var _result = OS.execute("git", ["status", "-s"], output, true)
	
	if output.size() > 0 and output[0].begins_with("fatal"):
		return []

	output = output[0].split("\n")
	
	var mod_files = []
	for line in output:
		var parts = line.split(" ",false)
		if parts.size() < 2:
			continue
		mod_files.append( "res://%s" % parts[1].strip_edges())
	
	return mod_files


func _array_missing(a:Array, b:Array) -> String:
	for a_element in a:
		if !b.has(a_element):
			return a_element
	return ""


func _on_bus_layout_changed() -> void:
	print("AudioNodeWranglerMgr: bus layout changed")
	var current_bus_names := _get_bus_names()

	var old_name := _array_missing(_cached_bus_names, current_bus_names)
	var new_name := _array_missing(current_bus_names, _cached_bus_names)
	
	_cached_bus_names = current_bus_names

	if old_name.is_empty() and new_name.is_empty():
		# no changes for bus names
		return
	
	if old_name.is_empty() and !new_name.is_empty():
		# bus added - nothing to do - shouldn't be in data yet
		return

	if !old_name.is_empty() and new_name.is_empty():
		# bus was removed
		_on_bus_renamed(-1, old_name, &"")
		return

	if !old_name.is_empty() and !new_name.is_empty():
		# bus was renamed
		_on_bus_renamed(-1, old_name, new_name)
		return


func _on_bus_renamed(_bus_index: int, old_name: StringName, new_name:StringName) -> void:
	var updated := false
	for key in _data.keys():
		var settings:AudioStreamPlayerSettings = _data[key]
		if settings.original_settings.bus == old_name:
			settings.original_settings.bus = new_name if !new_name.is_empty() else &"Master"
			updated = true
		if settings.settings.bus == old_name:
			settings.settings.bus = new_name if !new_name.is_empty() else settings.original_settings.bus
			updated = true
	if updated:
		save_data()
		data_changed.emit()
