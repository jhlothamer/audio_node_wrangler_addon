extends Control


func _on_back_btn_pressed() -> void:
	get_tree().change_scene_to_file(GameConsts.SCENE_PATH_TITLE)
