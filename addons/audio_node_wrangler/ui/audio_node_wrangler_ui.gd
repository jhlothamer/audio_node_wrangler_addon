@tool
extends Control

signal closed_pressed()
signal _confirm_dismissed(result)


const ICON_PLAY = preload("res://addons/audio_node_wrangler/ui/Play.svg")
const ICON_STOP = preload("res://addons/audio_node_wrangler/ui/Stop.svg")
const ICON_UNDO = preload("res://addons/audio_node_wrangler/ui/UndoRedo.svg")
const NO_NAG_ACTION = "no_nag"
const SOUND_MGR_UI_DATA_PATH = "user://sound_manager_ui.json"
const UI_PANEL_STYLEBOX = preload("res://addons/audio_node_wrangler/ui/ui_panel_stylebox.tres")


enum ConfirmationDlgResult {
	CANCEL,
	OK,
	OK_NONAG
}

enum TreeButtons {
	PLAY,
	STOP,
	UNDO_BUS,
	UNDO_VOLUME_DB,
}

enum Lvl2Columns {
	ID,
	PLAY,
	STOP,
	BUS,
	BUS_ORIG,
	VOLUME_DB,
	VOLUME_DB_ORIG,
	ACTIVE_INSTANCES,
}

const LVL2_COL_TITLES = {
	Lvl2Columns.BUS: "Bus",
	Lvl2Columns.BUS_ORIG: "",
	Lvl2Columns.VOLUME_DB: "Volume Db",
	Lvl2Columns.VOLUME_DB_ORIG: "",
	Lvl2Columns.ACTIVE_INSTANCES: "Instances?",
}

@export var mouse_over_color := Color.DARK_GRAY
@export var debug_apply := false
@export var row_outline_color := Color.RED
@export var row_outline_width := 2
@export var row_outline_offset := Vector2(5,4)
@export var row_outline_size_offset := Vector2(-7,3)


@onready var _tree:Tree = %Tree
@onready var _apply_settings_btn:Button = %ApplySettingsBtn
@onready var _accept_dlg:AcceptDialog = $AcceptDialog
@onready var _confirm_dlg:ConfirmationDialog = %ConfirmationDialog
@onready var _close_btn:Button = %CloseBtn
@onready var _group_by_res_rdo:CheckBox = %GroupByAudioResRdo
@onready var _filter_edit:LineEdit = %FilterLineEdit
@onready var _active_instances_chk:CheckBox = %ActiveInstancesChk
@onready var _bus_filter:OptionButton = %BusFilterOptionBtn
@onready var _title:Label = %AudioNodeWranglerLabel
@onready var _panel:PanelContainer = $Panel


var editor_interface:EditorInterface


#flag indicating if the ui scene is being edited or not
var _is_active := false
var _confirm_ok_no_nag_btn:Button


func _enter_tree() -> void:
	var parent:Node = get_parent()
	_is_active = parent.name == "MainScreen" or !Engine.is_editor_hint()


func _ready() -> void:
	if !_is_active:
		return
	
	var running_in_editor := Engine.is_editor_hint()
	_apply_settings_btn.visible = running_in_editor or debug_apply
	_close_btn.visible = !running_in_editor
	_active_instances_chk.visible = !running_in_editor
	_title.visible = !running_in_editor
	
	if !running_in_editor:
		_panel.set("theme_override_styles/panel", UI_PANEL_STYLEBOX)
	
	if OK != AudioNodeWranglerMgr.data_changed.connect(_on_data_changed):
		printerr("AudioNodeWranglerUI: could not connect to AudioNodeWranglerMgr.data_changed")
	call_deferred("_refresh_list", true)
	_confirm_ok_no_nag_btn = _confirm_dlg.add_button("OK (don't show again)", true, NO_NAG_ACTION)
	
	if running_in_editor:
		if OK != AudioServer.bus_layout_changed.connect(_on_bus_layout_changed):
			printerr("AudioNodeWranglerUI: could not connect to AudioServer.bus_layout_changed")
		# bus_renamed available in Godot 4.2
		if AudioServer.has_signal("bus_renamed"):
			if OK != AudioServer.connect("bus_renamed", _on_bus_layout_changed):
				printerr("AudioNodeWranglerUI: could not connect to AudioServer.bus_renamed")


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


func _get_grouped_data() -> Dictionary:
	if _group_by_res_rdo.button_pressed:
		return _get_data_by_resource()
	return _get_data_by_scene()


func _get_bus_names() -> Array[String]:
	var busses:Array[String] = []
	
	for i in AudioServer.bus_count:
		var bus := AudioServer.get_bus_name(i)
		busses.append(bus)
	
	busses.sort()
	
	return busses

func _free_temp_audio_players() -> void:
	for c in get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D or c is AudioStreamPlayer3D:
			c.queue_free()

func _refresh_list(called_from_ready:bool = false) -> void:
	if called_from_ready and _tree.get_root() != null:
		return
	_free_temp_audio_players()
	_prev_hover_item = null
	var bus_names := _get_bus_names()
	_refresh_bus_filter(bus_names)
	var bus_names_str := ",".join(bus_names)
	
	var settings_by_res_path := _get_grouped_data()
	_tree.clear()
	_tree.columns = Lvl2Columns.size() if !Engine.is_editor_hint() else Lvl2Columns.size() - 1
	_tree.set_column_custom_minimum_width(Lvl2Columns.BUS, 90)
	
	var group_by_res := _group_by_res_rdo.button_pressed
	
	for col_id in LVL2_COL_TITLES.keys():
		if col_id == Lvl2Columns.ACTIVE_INSTANCES and Engine.is_editor_hint():
			continue
		_tree.set_column_title(col_id, LVL2_COL_TITLES[col_id])
	
	var root = _tree.create_item()
	var keys:Array = settings_by_res_path.keys()
	keys.sort()
	for key in keys:
		var lvl1_node := _tree.create_item(root)
		lvl1_node.set_text(0, key)
		var settings:Array = settings_by_res_path[key]
		# sort here if needed
		for setting in settings:
			var lvl2_node := _tree.create_item(lvl1_node)

			if group_by_res:
				lvl2_node.set_text(Lvl2Columns.ID, setting.id)
			else:
				lvl2_node.set_text(Lvl2Columns.ID, "%s (%s)" % [setting.node_path, setting.audio_stream_path])
			lvl2_node.set_metadata(Lvl2Columns.ID, setting)

			lvl2_node.add_button(Lvl2Columns.PLAY, ICON_PLAY, TreeButtons.PLAY)
			_tree.set_column_expand(Lvl2Columns.PLAY, false)
			lvl2_node.set_tooltip_text(Lvl2Columns.PLAY, "Play %s" % setting.audio_stream_path.get_file())

			lvl2_node.add_button(Lvl2Columns.STOP, ICON_STOP, TreeButtons.STOP)
			_tree.set_column_expand(Lvl2Columns.STOP, false)
			_tree.set_column_expand(Lvl2Columns.STOP, false)

			lvl2_node.set_cell_mode(Lvl2Columns.BUS, TreeItem.CELL_MODE_RANGE)
			lvl2_node.set_editable(Lvl2Columns.BUS, true)
			lvl2_node.set_text(Lvl2Columns.BUS, bus_names_str)
			lvl2_node.set_range(Lvl2Columns.BUS, bus_names.find(setting.settings.bus))
			lvl2_node.set_tooltip_text(Lvl2Columns.BUS, "Bus")
			_tree.set_column_expand(Lvl2Columns.BUS, false)
			
			_tree.set_column_expand(Lvl2Columns.BUS_ORIG, false)
			_setup_bus_undo_button(lvl2_node, setting)
			
			#4
			lvl2_node.set_cell_mode(Lvl2Columns.VOLUME_DB, TreeItem.CELL_MODE_RANGE)
			lvl2_node.set_editable(Lvl2Columns.VOLUME_DB, true)
			lvl2_node.set_range_config(Lvl2Columns.VOLUME_DB, -60, 24, .1)
			lvl2_node.set_range(Lvl2Columns.VOLUME_DB, setting.settings.volume_db)
			lvl2_node.set_tooltip_text(Lvl2Columns.VOLUME_DB, "Volume dB")
			_tree.set_column_expand(Lvl2Columns.VOLUME_DB, false)
			
			_tree.set_column_expand(Lvl2Columns.VOLUME_DB_ORIG, false)
			_setup_volume_db_undo_button(lvl2_node, setting)
			
			if !Engine.is_editor_hint():
				lvl2_node.set_text_alignment(Lvl2Columns.ACTIVE_INSTANCES, HORIZONTAL_ALIGNMENT_CENTER)
				lvl2_node.set_cell_mode(Lvl2Columns.ACTIVE_INSTANCES, TreeItem.CELL_MODE_CHECK)
				lvl2_node.set_checked(Lvl2Columns.ACTIVE_INSTANCES, AudioNodeWranglerMgr.audio_node_has_instances(setting.id))
				_tree.set_column_expand(Lvl2Columns.ACTIVE_INSTANCES, false)
			
	_filter_list()


func _on_tree_button_clicked(item: TreeItem, _column: int, id: int, _mouse_button_index: int) -> void:
	match id:
		TreeButtons.PLAY:
			_play_audio(item)
		TreeButtons.STOP:
			_stop_audio(item)
		TreeButtons.UNDO_BUS:
			_undo_bus(item)
		TreeButtons.UNDO_VOLUME_DB:
			_undo_volume_db(item)


func _play_audio(item:TreeItem) -> void:
	var setting:AudioStreamPlayerSettings = item.get_metadata(0)
	var audio_stream_player = item.get_metadata(Lvl2Columns.PLAY)
	var new_player = !audio_stream_player
	audio_stream_player = setting.create_or_update_player(audio_stream_player)
	item.set_metadata(Lvl2Columns.PLAY, audio_stream_player)
	if new_player:
		add_child(audio_stream_player)
	audio_stream_player.play()
	


func _stop_audio(item:TreeItem) -> void:
	var audio_stream_player = item.get_metadata(Lvl2Columns.PLAY)
	if !audio_stream_player:
		return
	audio_stream_player.stop()


func _stop_all_audio() -> void:
	var root = _tree.get_root()
	for lvl1_node in root.get_children():
		for lvl2_node in lvl1_node.get_children():
			var audio_stream_player = lvl2_node.get_metadata(Lvl2Columns.PLAY)
			if audio_stream_player:
				audio_stream_player.stop()


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
	var calc_pos = get_global_mouse_position() - _tree.global_position
	var hover_item := _tree.get_item_at_position(calc_pos)
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
		_row_outline.mouse_filter = Control.MOUSE_FILTER_PASS
		_row_outline.border_color = row_outline_color
		_row_outline.border_width = row_outline_width
		_tree.add_child(_row_outline)
	var item_rect := _tree.get_item_area_rect(hover_item)
	_row_outline.position = item_rect.position + row_outline_offset
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
	var item := _tree.get_selected()
	var setting:AudioStreamPlayerSettings = item.get_metadata(0)
	var col := _tree.get_selected_column()
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



func _on_scan_project_btn_pressed() -> void:
	AudioNodeWranglerMgr.scan_project()
	_refresh_list()


func _on_reset_settings_btn_pressed() -> void:
	AudioNodeWranglerMgr.scan_project(true)
	_refresh_list()


func _on_apply_settings_btn_pressed() -> void:
	var pre_check_results := AudioNodeWranglerMgr.pre_apply_checks()
	if pre_check_results.issues_found:
		match pre_check_results.message_buttons:
			PreApplyCheckResult.ResultMessageButtons.OK:
				_accept_dlg.dialog_text = pre_check_results.message
				_accept_dlg.popup()
				await _confirm_dismissed
				return
			PreApplyCheckResult.ResultMessageButtons.OK_CANCEL_NO_NAG, PreApplyCheckResult.ResultMessageButtons.OK_CANCEL:
				_confirm_ok_no_nag_btn.visible = pre_check_results.message_buttons == PreApplyCheckResult.ResultMessageButtons.OK_CANCEL_NO_NAG
				_confirm_dlg.dialog_text = pre_check_results.message
				_confirm_dlg.popup()
				var result:int = await _confirm_dismissed
				if result == ConfirmationDlgResult.CANCEL:
					return
				if result == ConfirmationDlgResult.OK_NONAG:
					AudioNodeWranglerProjectSettingsHelper.update_flag_setting(pre_check_results.no_nag_project_setting_key, false)
	
	var msg := AudioNodeWranglerMgr.apply_settings()
	if !msg.is_empty():
		_accept_dlg.dialog_text = msg
		_accept_dlg.popup()
	_refresh_list()

func _on_data_changed() -> void:
	if !_is_active:
		return
	_refresh_list()


func _on_close_btn_pressed() -> void:
	_stop_all_audio()
	AudioNodeWranglerMgr.save_data()
	closed_pressed.emit()


func _on_group_by_rdo_pressed() -> void:
	_refresh_list()


func _on_filter_line_edit_text_changed(_new_text: String) -> void:
	_filter_list()


func _filter_list() -> void:
	var filter_string := _filter_edit.text.to_lower()
	var chk_instances = _active_instances_chk.visible && _active_instances_chk.button_pressed
	var bus_filter = _bus_filter.get_item_text(_bus_filter.selected)
	var root := _tree.get_root()
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



func _on_active_instances_chk_pressed() -> void:
	_filter_list()


func _on_bus_filter_option_btn_item_selected(_index: int) -> void:
	_filter_list()


func _refresh_bus_filter(bus_names:Array) -> void:
	var selected_index := _bus_filter.selected
	var selected_bus_name := ""
	if selected_index > -1:
		selected_bus_name = _bus_filter.get_item_text(selected_index)
	_bus_filter.clear()
	_bus_filter.add_item("")
	for bus_name in bus_names:
		_bus_filter.add_item(bus_name)
	if selected_index > -1 and !selected_bus_name.is_empty():
		selected_index = bus_names.find(selected_bus_name) + 1
		_bus_filter.select(selected_index)


func _on_confirmation_dialog_custom_action(_action: StringName) -> void:
	_confirm_dlg.visible = false
	_confirm_dismissed.emit(ConfirmationDlgResult.OK_NONAG)


func _on_confirmation_dialog_confirmed() -> void:
	_confirm_dismissed.emit(ConfirmationDlgResult.OK)


func _on_confirmation_dialog_canceled() -> void:
	_confirm_dismissed.emit(ConfirmationDlgResult.CANCEL)


func _on_show_data_file_btn_pressed() -> void:
	AudioNodeWranglerMgr.show_data_file()


func _on_accept_dialog_canceled() -> void:
	_confirm_dismissed.emit(ConfirmationDlgResult.OK)


func _on_accept_dialog_confirmed() -> void:
	_confirm_dismissed.emit(ConfirmationDlgResult.OK)


func _on_accept_dialog_custom_action(_action: StringName) -> void:
	_confirm_dismissed.emit(ConfirmationDlgResult.OK)


func _about_to_hide() -> void:
	AudioNodeWranglerMgr.save_data()


func _on_bus_layout_changed() -> void:
	var bus_names := _get_bus_names()
	_refresh_bus_filter(bus_names)
	var bus_names_str := ",".join(bus_names)
	
	var root := _tree.get_root()
	for lvl1_node in root.get_children():
		for lvl2_node in lvl1_node.get_children():
			var setting:AudioStreamPlayerSettings = lvl2_node.get_metadata(Lvl2Columns.ID)
			lvl2_node.set_text(Lvl2Columns.BUS, bus_names_str)
			lvl2_node.set_range(Lvl2Columns.BUS, bus_names.find(setting.settings.bus))


func _on_bus_renamed(_bus_index: int, old_name: StringName, new_name:StringName) -> void:
	for i in _bus_filter.item_count:
		var bus_name := _bus_filter.get_item_text(i)
		if bus_name == old_name:
			_bus_filter.set_item_text(i, new_name)
		


