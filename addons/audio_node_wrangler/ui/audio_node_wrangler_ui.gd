@tool
extends Control

signal closed_pressed()
signal _confirm_dismissed(result)


const NO_NAG_ACTION = "no_nag"
const SOUND_MGR_UI_DATA_PATH = "user://sound_manager_ui.json"
const UI_PANEL_STYLEBOX = preload("res://addons/audio_node_wrangler/ui/ui_panel_stylebox.tres")


enum ConfirmationDlgResult {
	CANCEL,
	OK,
	OK_NONAG
}


@export var debug_apply := false


@onready var _data_tree:AudioNodeWranglerDataTree = %AudioDataTree
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
@onready var _changes_filter:OptionButton = %ChangesFilterOptionBtn


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
	_refresh_list.call_deferred(true)
	_confirm_ok_no_nag_btn = _confirm_dlg.add_button("OK (don't show again)", true, NO_NAG_ACTION)
	
	if running_in_editor:
		if OK != AudioServer.bus_layout_changed.connect(_on_bus_layout_changed):
			printerr("AudioNodeWranglerUI: could not connect to AudioServer.bus_layout_changed")
		# bus_renamed available in Godot 4.2
		if AudioServer.has_signal("bus_renamed"):
			if OK != AudioServer.connect("bus_renamed", _on_bus_layout_changed):
				printerr("AudioNodeWranglerUI: could not connect to AudioServer.bus_renamed")


func _refresh_list(called_from_ready:bool = false) -> void:
	var bus_names := AudioWranglerUtil.get_bus_names()
	_refresh_bus_filter(bus_names)
	var bus_filter := ""
	if _bus_filter.selected > -1:
		bus_filter = _bus_filter.get_item_text(_bus_filter.selected)
	_data_tree.refresh_list(_group_by_res_rdo.button_pressed, _filter_edit.text.to_lower(), _active_instances_chk.button_pressed, bus_filter, _changes_filter.selected, called_from_ready)


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
	_data_tree.stop_all_audio()
	AudioNodeWranglerMgr.save_data()
	closed_pressed.emit()


func _on_group_by_rdo_pressed() -> void:
	_refresh_list()


func _on_filter_line_edit_text_changed(_new_text: String) -> void:
	_data_tree.filter_list(_filter_edit.text.to_lower(), _active_instances_chk.button_pressed, _bus_filter.get_item_text(_bus_filter.selected), _changes_filter.selected)


func _on_active_instances_chk_pressed() -> void:
	_data_tree.filter_list(_filter_edit.text.to_lower(), _active_instances_chk.button_pressed, _bus_filter.get_item_text(_bus_filter.selected), _changes_filter.selected)


func _on_bus_filter_option_btn_item_selected(_index: int) -> void:
	_data_tree.filter_list(_filter_edit.text.to_lower(), _active_instances_chk.button_pressed, _bus_filter.get_item_text(_bus_filter.selected), _changes_filter.selected)


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
	var bus_names := AudioWranglerUtil.get_bus_names()
	_refresh_bus_filter(bus_names)


func _on_bus_renamed(_bus_index: int, old_name: StringName, new_name:StringName) -> void:
	for i in _bus_filter.item_count:
		var bus_name := _bus_filter.get_item_text(i)
		if bus_name == old_name:
			_bus_filter.set_item_text(i, new_name)


func _on_changes_filter_option_btn_item_selected(_index: int) -> void:
	_data_tree.filter_list(_filter_edit.text.to_lower(), _active_instances_chk.button_pressed, _bus_filter.get_item_text(_bus_filter.selected), _changes_filter.selected)
