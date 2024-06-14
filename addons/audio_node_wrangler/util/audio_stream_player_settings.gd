class_name AudioStreamPlayerSettings
extends RefCounted

const AUDIO_PLAYER_DEF_PROP_VALUES = {
	"bus": "Master",
	"volume_db": 0.0,
}

var id := ""
var scene_path := ""
var node_path := ""
var audio_stream_path := ""
var node_type := ""
var settings := {}
var original_settings := {}
var _settings_as_loaded := {}
var _filter_match_string := ""


func read_from_scene_state(path:String, ss:SceneState, node_idx: int) -> void:
	scene_path = path
	node_path = str(ss.get_node_path(node_idx))
	id = "%s::%s" % [path, node_path]
	node_type = ss.get_node_type(node_idx)
	settings = {}
	for i in ss.get_node_property_count(node_idx):
		var prop_name = ss.get_node_property_name(node_idx, i)
		if prop_name == "stream":
			var stream_value:AudioStream = ss.get_node_property_value(node_idx, i)
			audio_stream_path = stream_value.resource_path
		if !AUDIO_PLAYER_DEF_PROP_VALUES.has(prop_name):
			continue
		settings[prop_name] = ss.get_node_property_value(node_idx, i)
	
	for def_prop in AUDIO_PLAYER_DEF_PROP_VALUES.keys():
		if settings.has(def_prop):
			continue
		settings[def_prop] = AUDIO_PLAYER_DEF_PROP_VALUES[def_prop]
	
	original_settings = settings.duplicate()


func read_from_dictionary(d:Dictionary) -> void:
	scene_path = d.scene_path
	node_path = d.node_path
	audio_stream_path = d.audio_stream_path
	node_type = d.node_type
	id = "%s::%s" % [scene_path, node_path]
	settings = d.settings
	if d.has("original_settings"):
		original_settings = d.original_settings
	_settings_as_loaded = settings.duplicate()


static func get_id_for_audio_node(node: Node) -> String:
	var temp := str(node.get_path())
	var local_path = temp.replace(str(node.owner.get_path()), ".")
	return "%s::%s" % [node.owner.scene_file_path, local_path]


func read_from_node(n:Node) -> void:
	id = AudioStreamPlayerSettings.get_id_for_audio_node(n)
	var stream:AudioStream = n.stream
	audio_stream_path = stream.resource_path
	node_type = n.get_class()
	settings = {}
	for prop_key in AUDIO_PLAYER_DEF_PROP_VALUES.keys():
		var value = n.get(prop_key)
		settings[prop_key] = value
	original_settings = settings.duplicate()


func write_to_dictionary() -> Dictionary:
	_settings_as_loaded = settings.duplicate()
	return {
		"scene_path": scene_path,
		"node_path": node_path,
		"audio_stream_path": audio_stream_path,
		"node_type": node_type,
		"settings": settings,
		"original_settings": original_settings,
	}


func should_update(other:AudioStreamPlayerSettings) -> bool:
	if scene_path != other.scene_path:
		return false
	if node_path != other.node_path:
		return false
	if audio_stream_path != other.audio_stream_path:
		return false
	if node_type != other.node_type:
		return false
	for setting in settings.keys():
		if !other.settings.has(setting):
			return false
		if settings[setting] != other.settings[setting]:
			#print("%s will be updated because setting %s is diff: %s, %s" % [id, setting, settings[setting], other.settings[setting]])
			return true
	return false


func create_or_update_player(audio_stream_player):
	if !audio_stream_player:
		if node_type == "AudioStreamPlayer":
			audio_stream_player = AudioStreamPlayer.new()
		if node_type == "AudioStreamPlayer2D":
			audio_stream_player = AudioStreamPlayer2D.new()
		if node_type == "AudioStreamPlayer3D":
			audio_stream_player = AudioStreamPlayer3D.new()
		audio_stream_player.stream = load(audio_stream_path)
	audio_stream_player.bus = settings.bus
	audio_stream_player.volume_db = settings.volume_db
	return audio_stream_player


func needs_update_applied() -> bool:
	for setting in settings.keys():
		if !original_settings.has(setting):
			return true
		if settings[setting] != original_settings[setting]:
			return true
	return false


func get_updater_property_dictionary() -> Dictionary:
	var updates := {}
	for setting in settings.keys():
		if !original_settings.has(setting) or settings[setting] != original_settings[setting]:
			updates[setting] = settings[setting]
	return updates


func matches_filter(filter_string:String) -> bool:
	if _filter_match_string.is_empty():
		_filter_match_string = "%s::%s" % [id.to_lower(), audio_stream_path.to_lower()]
	
	return filter_string.is_empty() or _filter_match_string.find(filter_string) > -1


func volume_db_changed() -> bool:
	var orig_vol = 0
	if original_settings.has("volume_db"):
		orig_vol = original_settings.volume_db
	var curr_vol = 0
	if settings.has("volume_db"):
		curr_vol = settings.volume_db
	
	return curr_vol != orig_vol


func bus_changed() -> bool:
	var orig_bus = "Master"
	if original_settings.has("bus"):
		orig_bus = original_settings.bus
	var curr_bus = "Master"
	if settings.has("bus"):
		curr_bus = settings.bus

	return curr_bus != orig_bus
