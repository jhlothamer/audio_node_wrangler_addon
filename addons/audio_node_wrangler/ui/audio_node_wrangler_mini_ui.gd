extends Control


signal closed_pressed()


enum FileMenuIds {
	SCAN,
	RESET,
	SHOW_DATA
}

enum GroupByMenuIds {
	AUDIO_RESOURCE,
	SCENE,
}


@onready var _data_tree:AudioNodeWranglerDataTree = %AudioDataTree
@onready var _filter_edit:LineEdit = %FilterLineEdit
@onready var _active_instances_chk:CheckBox = %ActiveInstancesChk
@onready var _bus_filter_menu_btn:MenuButton = %BusFilterMenuBtn
@onready var _group_by_filter:PopupMenu = %"Group By"


var _group_by_resource := true


func _ready() -> void:
	if OK != AudioNodeWranglerMgr.data_changed.connect(_on_data_changed):
		printerr("AudioNodeWranglerMinuUI: could not connect to AudioNodeWranglerMgr.data_changed")
	_populate_bus_filter()
	var popup := _bus_filter_menu_btn.get_popup()
	popup.index_pressed.connect(_on_bus_filter_popup_index_pressed)
	_refresh_list.call_deferred(true)


func _refresh_list(called_from_ready:bool = false) -> void:
	var bus_filter := _get_bus_filter()
	_data_tree.refresh_list(_group_by_resource, _filter_edit.text.to_lower(), _active_instances_chk.button_pressed, bus_filter, AudioNodeWranglerDataTree.ChangesFilter.Both, called_from_ready)


func _populate_bus_filter() -> void:
	var bus_names := AudioWranglerUtil.get_bus_names()
	var popup := _bus_filter_menu_btn.get_popup()
	for bus_name in bus_names:
		popup.add_radio_check_item(bus_name)


func _get_bus_filter() -> String:
	var popup := _bus_filter_menu_btn.get_popup()
	for i in popup.item_count:
		if popup.is_item_checked(i):
			return popup.get_item_text(i)
	
	return ""


func _on_bus_filter_popup_index_pressed(index:int) -> void:
	var popup := _bus_filter_menu_btn.get_popup()
	for i in popup.item_count:
		if i != index:
			popup.set_item_checked(i, false)
	popup.toggle_item_checked(index)
	_refresh_list()


func _filter_list() -> void:
	_data_tree.filter_list(_filter_edit.text.to_lower(), _active_instances_chk.button_pressed, _get_bus_filter(), AudioNodeWranglerDataTree.ChangesFilter.Both)


func _about_to_hide() -> void:
	AudioNodeWranglerMgr.save_data()


func _on_data_changed() -> void:
	_refresh_list()


func _on_file_id_pressed(id: int) -> void:
	match id:
		FileMenuIds.SCAN:
			AudioNodeWranglerMgr.scan_project()
			_refresh_list()
		FileMenuIds.RESET:
			AudioNodeWranglerMgr.scan_project(true)
			_refresh_list()
		FileMenuIds.SHOW_DATA:
			AudioNodeWranglerMgr.show_data_file()


func _on_group_by_id_pressed(id: int) -> void:
	var index := _group_by_filter.get_item_index(id)
	for i in _group_by_filter.item_count:
		if i != index:
			_group_by_filter.set_item_checked(i, false)
	_group_by_filter.set_item_checked(index, true)
	
	_group_by_resource = id == GroupByMenuIds.AUDIO_RESOURCE
	_refresh_list()


func _on_filter_line_edit_text_changed(_new_text: String) -> void:
	_filter_list()


func _on_active_instances_chk_pressed() -> void:
	_filter_list()


func _on_close_btn_pressed() -> void:
	_data_tree.stop_all_audio()
	AudioNodeWranglerMgr.save_data()
	closed_pressed.emit()
