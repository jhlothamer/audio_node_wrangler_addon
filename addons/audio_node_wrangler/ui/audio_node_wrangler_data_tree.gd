@tool
class_name AudioNodeWranglerDataTree
extends Tree


const ICON_PLAY = preload("res://addons/audio_node_wrangler/ui/Play.svg")
const ICON_STOP = preload("res://addons/audio_node_wrangler/ui/Stop.svg")
const ICON_UNDO = preload("res://addons/audio_node_wrangler/ui/UndoRedo.svg")


enum TreeButtons {
	PLAY,
	UNDO_BUS,
	UNDO_VOLUME_DB,
}

enum Lvl2Columns {
	ID,
	PLAY,
	BUS,
	BUS_ORIG,
	VOLUME_DB,
	VOLUME_DB_ORIG,
	ACTIVE_INSTANCES,
}

const LVL2_COL_TITLES = {
	Lvl2Columns.BUS: "Bus",
	Lvl2Columns.BUS_ORIG: "",
	Lvl2Columns.VOLUME_DB_ORIG: "",
}


@export var row_outline_color := Color.RED
@export var row_outline_width := 2
@export var row_outline_offset := Vector2(5,4)
@export var row_outline_size_offset := Vector2(-7,3)
@export var volume_column_label := "Volume Db"
@export var active_instances_column_label := "Instanced?"


func _ready() -> void:
	
	if Engine.is_editor_hint():
		if OK != AudioServer.bus_layout_changed.connect(_on_bus_layout_changed):
			printerr("AudioNodeWranglerUI: could not connect to AudioServer.bus_layout_changed")



func _get_data_by_resource() -> Dictionary:
	var d := {}
	for aud_setting in AudioNodeWranglerMgr._data.values():
		if !d.has(aud_setting.audio_stream_path):
			d[aud_setting.audio_stream_path] = []
		d[aud_setting.audio_stream_path].append(aud_setting)
	return d


func _get_data_by_scene() -> Dictionary:
	var d := {}
	for aud_setting in AudioNodeWranglerMgr._data.values():
		if !d.has(aud_setting.scene_path):
			d[aud_setting.scene_path] = []
		d[aud_setting.scene_path].append(aud_setting)
	return d


func _get_grouped_data(group_by_resource: bool) -> Dictionary:
	if group_by_resource:
		return _get_data_by_resource()
	return _get_data_by_scene()


func _free_temp_audio_players() -> void:
	for c in get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D or c is AudioStreamPlayer3D:
			c.queue_free()

func _get_bus_names() -> Array[String]:
	var busses:Array[String] = []
	
	for i in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(i)
		busses.append(bus)
	
	busses.sort()
	
	return busses

func refresh_list(group_by_resource: bool, filter_string:String, chk_instances: bool, bus_filter:String, called_from_ready:bool = false) -> void:
	if called_from_ready and get_root() != null:
		return
	_free_temp_audio_players()
	_prev_hover_item = null
	var bus_names := _get_bus_names()
	#TODO: _refresh_bus_filter(bus_names)
	var bus_names_str := ",".join(bus_names)
	
	var settings_by_res_path := _get_grouped_data(group_by_resource)
	clear()
	columns = Lvl2Columns.size() if !Engine.is_editor_hint() else Lvl2Columns.size() - 1
	set_column_custom_minimum_width(Lvl2Columns.BUS, 90)
	
	
	for col_id in LVL2_COL_TITLES.keys():
		if col_id == Lvl2Columns.ACTIVE_INSTANCES and Engine.is_editor_hint():
			continue
		set_column_title(col_id, LVL2_COL_TITLES[col_id])
	
	set_column_title(Lvl2Columns.VOLUME_DB, volume_column_label)
	set_column_title(Lvl2Columns.ACTIVE_INSTANCES, active_instances_column_label)
	
	var root = create_item()
	var keys:Array = settings_by_res_path.keys()
	keys.sort()
	for key in keys:
		var lvl1_node := create_item(root)
		lvl1_node.set_text(0, key)
		var settings:Array = settings_by_res_path[key]
		# sort here if needed
		for setting in settings:
			var lvl2_node := create_item(lvl1_node)

			if group_by_resource:
				lvl2_node.set_text(Lvl2Columns.ID, setting.id)
			else:
				lvl2_node.set_text(Lvl2Columns.ID, "%s (%s)" % [setting.node_path, setting.audio_stream_path])
			lvl2_node.set_metadata(Lvl2Columns.ID, setting)

			lvl2_node.add_button(Lvl2Columns.PLAY, ICON_PLAY, TreeButtons.PLAY)
			set_column_expand(Lvl2Columns.PLAY, false)
			lvl2_node.set_tooltip_text(Lvl2Columns.PLAY, "Play %s" % setting.audio_stream_path.get_file())

			lvl2_node.set_cell_mode(Lvl2Columns.BUS, TreeItem.CELL_MODE_RANGE)
			lvl2_node.set_editable(Lvl2Columns.BUS, true)
			lvl2_node.set_text(Lvl2Columns.BUS, bus_names_str)
			lvl2_node.set_range(Lvl2Columns.BUS, bus_names.find(setting.settings.bus))
			lvl2_node.set_tooltip_text(Lvl2Columns.BUS, "Bus")
			set_column_expand(Lvl2Columns.BUS, false)
			
			set_column_expand(Lvl2Columns.BUS_ORIG, false)
			_setup_bus_undo_button(lvl2_node, setting)
			
			#4
			lvl2_node.set_cell_mode(Lvl2Columns.VOLUME_DB, TreeItem.CELL_MODE_RANGE)
			lvl2_node.set_editable(Lvl2Columns.VOLUME_DB, true)
			lvl2_node.set_range_config(Lvl2Columns.VOLUME_DB, -60, 24, .1)
			lvl2_node.set_range(Lvl2Columns.VOLUME_DB, setting.settings.volume_db)
			lvl2_node.set_tooltip_text(Lvl2Columns.VOLUME_DB, "Volume dB")
			set_column_expand(Lvl2Columns.VOLUME_DB, false)
			
			set_column_expand(Lvl2Columns.VOLUME_DB_ORIG, false)
			_setup_volume_db_undo_button(lvl2_node, setting)
			
			if !Engine.is_editor_hint():
				lvl2_node.set_text_alignment(Lvl2Columns.ACTIVE_INSTANCES, HORIZONTAL_ALIGNMENT_CENTER)
				lvl2_node.set_cell_mode(Lvl2Columns.ACTIVE_INSTANCES, TreeItem.CELL_MODE_CHECK)
				lvl2_node.set_checked(Lvl2Columns.ACTIVE_INSTANCES, AudioNodeWranglerMgr.audio_node_has_instances(setting.id))
				set_column_expand(Lvl2Columns.ACTIVE_INSTANCES, false)
			
	filter_list(filter_string, chk_instances, bus_filter)


func _on_tree_button_clicked(item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	match id:
		TreeButtons.PLAY:
			_play_stop_audio(item)
		TreeButtons.UNDO_BUS:
			_undo_bus(item)
		TreeButtons.UNDO_VOLUME_DB:
			_undo_volume_db(item)


func _play_stop_audio(item:TreeItem) -> void:
	var audio_stream_player = item.get_metadata(Lvl2Columns.PLAY)
	if audio_stream_player and audio_stream_player.playing:
		audio_stream_player.stop()
		item.set_button(Lvl2Columns.PLAY, TreeButtons.PLAY, ICON_PLAY)
		return
	_play_audio(item)
	item.set_button(Lvl2Columns.PLAY, TreeButtons.PLAY, ICON_STOP)


func _play_audio(item:TreeItem) -> void:
	var setting:AudioStreamPlayerSettings = item.get_metadata(0)
	var audio_stream_player = item.get_metadata(Lvl2Columns.PLAY)
	var new_player = !audio_stream_player
	audio_stream_player = setting.create_or_update_player(audio_stream_player)
	item.set_metadata(Lvl2Columns.PLAY, audio_stream_player)
	if new_player:
		add_child(audio_stream_player)
		audio_stream_player.connect("finished", _on_audio_stream_finished.bind(item))
	audio_stream_player.play()


func _on_audio_stream_finished(item:TreeItem) -> void:
	var audio_stream_player = item.get_metadata(Lvl2Columns.PLAY)
	if audio_stream_player:
		audio_stream_player.stop()
		item.set_button(Lvl2Columns.PLAY, TreeButtons.PLAY, ICON_PLAY)


func stop_all_audio() -> void:
	var root = get_root()
	for lvl1_node in root.get_children():
		for lvl2_node in lvl1_node.get_children():
			var audio_stream_player = lvl2_node.get_metadata(Lvl2Columns.PLAY)
			if audio_stream_player:
				audio_stream_player.stop()
			lvl2_node.set_button(Lvl2Columns.PLAY, TreeButtons.PLAY, ICON_PLAY)


func _undo_bus(item:TreeItem) -> void:
	var setting:AudioStreamPlayerSettings = item.get_metadata(0)
	setting.settings.bus = setting.original_settings.bus
	var bus_index = _get_bus_names().find(setting.settings.bus)
	item.set_range(Lvl2Columns.BUS, bus_index)
	_setup_bus_undo_button(item, setting)
	AudioNodeWranglerMgr._apply_audio_setting_to_current_players(setting)


func _undo_volume_db(item:TreeItem) -> void:
	var setting:AudioStreamPlayerSettings = item.get_metadata(0)
	setting.settings.volume_db = setting.original_settings.volume_db
	item.set_range(Lvl2Columns.VOLUME_DB, setting.settings.volume_db)
	_setup_volume_db_undo_button(item, setting)
	AudioNodeWranglerMgr._apply_audio_setting_to_current_players(setting)


var _prev_hover_item:TreeItem
var _row_outline:ReferenceRect
func _on_tree_gui_input(event: InputEvent) -> void:
	if !event is InputEventMouseMotion:
		return
	var calc_pos = get_global_mouse_position() - global_position
	var hover_item := get_item_at_position(calc_pos)
	if !hover_item:
		if _row_outline:
			_row_outline.visible = false
		return
	if hover_item == _prev_hover_item:
		if _row_outline:
			_row_outline.visible = true
		return
	if !_row_outline:
		_row_outline = ReferenceRect.new()
		_row_outline.editor_only = false
		_row_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row_outline.border_color = row_outline_color
		_row_outline.border_width = row_outline_width
		add_child(_row_outline)
	var item_rect := get_item_area_rect(hover_item)
	_row_outline.position = item_rect.position + row_outline_offset - get_scroll()
	_row_outline.size = item_rect.size + row_outline_size_offset
	_row_outline.visible = true
	_prev_hover_item = hover_item


func _setup_bus_undo_button(item: TreeItem, setting:AudioStreamPlayerSettings) -> void:
	var button_index := item.get_button_by_id(Lvl2Columns.BUS_ORIG, TreeButtons.UNDO_BUS)
	if setting.bus_changed():
		if button_index < 0:
			item.add_button(Lvl2Columns.BUS_ORIG, ICON_UNDO, TreeButtons.UNDO_BUS)
		if setting.original_settings.has("bus"):
			item.set_tooltip_text(Lvl2Columns.BUS_ORIG, "Revert to '%s'" % setting.original_settings.bus)
		else:
			item.set_tooltip_text(Lvl2Columns.BUS_ORIG, "Revert to 'Master'")
	elif button_index > -1:
		item.erase_button(Lvl2Columns.BUS_ORIG, button_index)


func _setup_volume_db_undo_button(item: TreeItem, setting:AudioStreamPlayerSettings) -> void:
	var button_index := item.get_button_by_id(Lvl2Columns.VOLUME_DB_ORIG, TreeButtons.UNDO_VOLUME_DB)
	if setting.volume_db_changed():
		if button_index < 0:
			item.add_button(Lvl2Columns.VOLUME_DB_ORIG, ICON_UNDO, TreeButtons.UNDO_VOLUME_DB)
		if setting.original_settings.has("volume_db"):
			item.set_tooltip_text(Lvl2Columns.VOLUME_DB_ORIG, "Revert to %s" % setting.original_settings.volume_db)
		else:
			item.set_tooltip_text(Lvl2Columns.VOLUME_DB_ORIG, "Revert to 0")
	elif button_index > -1:
		item.erase_button(Lvl2Columns.VOLUME_DB_ORIG, button_index)


func _on_tree_item_edited() -> void:
	var item := get_selected()
	var setting:AudioStreamPlayerSettings = item.get_metadata(0)
	var col := get_selected_column()
	var val = item.get_range(col)
	match col:
		Lvl2Columns.VOLUME_DB:
			setting.settings.volume_db = val
			_setup_volume_db_undo_button(item, setting)
		Lvl2Columns.BUS:
			var bus_names := _get_bus_names()
			var bus_name = bus_names[val]
			setting.settings.bus = bus_name
			_setup_bus_undo_button(item, setting)
	var audio_stream_player = item.get_metadata(Lvl2Columns.PLAY)
	if audio_stream_player:
		setting.create_or_update_player(audio_stream_player)
	AudioNodeWranglerMgr._apply_audio_setting_to_current_players(setting)


func filter_list(filter_string:String, chk_instances: bool, bus_filter:String) -> void:
	#var filter_string := _filter_edit.text.to_lower()
	#var chk_instances = _active_instances_chk.visible && _active_instances_chk.button_pressed
	#var bus_filter = _bus_filter.get_item_text(_bus_filter.selected)
	var root := get_root()
	if !root:
		return
	for lvl1_node in root.get_children():
		var lvl2_node_visible := false
		for lvl2_node in lvl1_node.get_children():
			var setting:AudioStreamPlayerSettings = lvl2_node.get_metadata(0)
			if chk_instances and !lvl2_node.is_checked(Lvl2Columns.ACTIVE_INSTANCES):
				lvl2_node.visible = false
			elif !bus_filter.is_empty() and setting.settings.bus != bus_filter:
				lvl2_node.visible = false
			elif setting.matches_filter(filter_string):
				lvl2_node.visible = true
				lvl2_node_visible = true
			else:
				lvl2_node.visible = false
			lvl1_node.visible = lvl2_node_visible


func _on_bus_layout_changed() -> void:
	var bus_names := _get_bus_names()
	var bus_names_str := ",".join(bus_names)
	
	var root := get_root()
	for lvl1_node in root.get_children():
		for lvl2_node in lvl1_node.get_children():
			var setting:AudioStreamPlayerSettings = lvl2_node.get_metadata(Lvl2Columns.ID)
			lvl2_node.set_text(Lvl2Columns.BUS, bus_names_str)
			lvl2_node.set_range(Lvl2Columns.BUS, bus_names.find(setting.settings.bus))
