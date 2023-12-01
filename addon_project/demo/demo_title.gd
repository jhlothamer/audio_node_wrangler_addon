extends Control

const SCENE_PATH_QUESTION = "res://demo/quiz_question.tscn"


func _on_new_game_btn_pressed() -> void:
	get_tree().change_scene_to_file(SCENE_PATH_QUESTION)


func _on_exit_btn_pressed() -> void:
	get_tree().quit()
