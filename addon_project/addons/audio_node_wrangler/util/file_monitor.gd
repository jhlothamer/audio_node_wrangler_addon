class_name FileMonitor
extends Node

signal file_modified()

@export var file_path := ""
@export var frequency := 1.0

var _file_last_modified_time := -1

func _ready() -> void:
	if file_path.is_empty():
		return
	if FileAccess.file_exists(file_path):
		_file_last_modified_time = FileAccess.get_modified_time(file_path)
	var timer = Timer.new()
	timer.wait_time = frequency
	timer.one_shot = false
	add_child(timer)
	timer.start()
	if OK != timer.timeout.connect(_on_timeout):
		printerr("FileMonitor: couldn't connect to timer timeout signal")


func _on_timeout() -> void:
	pass
	if !FileAccess.file_exists(file_path):
		return
	var prev_modified_time = _file_last_modified_time
	_file_last_modified_time = FileAccess.get_modified_time(file_path)
	if prev_modified_time != _file_last_modified_time:
		file_modified.emit()
