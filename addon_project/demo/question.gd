class_name Question
extends RefCounted

var question := ""
var answers := []
var correct_answer_index := 0
var given_answer_index := -1


func _init(q: String, a:Array, cai: int = -1) -> void:
	question = q
	answers = a
	if cai < 0:
		answers.sort_custom(func (_a,_b):
			return 1 if randf() >= .5 else -1)
		correct_answer_index = randi_range(0, answers.size() - 1)
	else:
		correct_answer_index = cai


func answer_question(answer_index: int) -> bool:
	given_answer_index = answer_index
	return correct_answer_index == given_answer_index


func answer_was_correct() -> bool:
	return correct_answer_index == given_answer_index


func reset() -> void:
	given_answer_index = -1
