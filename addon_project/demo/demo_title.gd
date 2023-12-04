extends Control


func _on_new_game_btn_pressed() -> void:
	get_tree().change_scene_to_file(GameConsts.SCENE_PATH_QUESTION)


func _on_credits_btn_pressed() -> void:
	get_tree().change_scene_to_file(GameConsts.SCENE_PATH_CREDITS)


func _on_exit_btn_pressed() -> void:
	get_tree().quit()

