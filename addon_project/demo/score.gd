extends Control


const SCENE_PATH_TITLE = "res://demo/demo_title.tscn"
const SCORE_TEXT_TEMPLATE = "[center]You scored %d/%d.\n\nYou get %s %s\n\n%s[/center]"
const SCORE_GRADES = [
	[.9, "an", "A", "Which indicates extreme intelligence or luck."],
	[.8, "a", "B", "Which indicates you usually come in second."],
	[.7, "a", "C", "Which means you are cool!"],
	[.6, "a", "D", "It either means you're dandy or a dunce.  Why not both!"],
	[.5, "an", "F", "F stands for FANTASTIC!"],
]


@onready var _score_lbl:RichTextLabel = $MarginContainer/VBoxContainer/ScoreRichTextLabel


func _ready() -> void:
	var correct_count = QuestionMgr.get_correct_answer_count()
	var question_count = QuestionMgr.get_question_count()
	
	var score_grades := _get_score_grades(float(correct_count) / float(question_count))

	_score_lbl.text = SCORE_TEXT_TEMPLATE % [correct_count, question_count, 
		score_grades[0], score_grades[1], score_grades[2]]
	QuestionMgr.reset()


func _get_score_grades(percentage: float) -> Array:
	var score_grades := []
	
	for i in SCORE_GRADES.size():
		var score_grade_array:Array = SCORE_GRADES[i]
		if i == SCORE_GRADES.size() - 1 or \
		SCORE_GRADES[i][0] <= percentage:
			score_grades = [score_grade_array[1], 
				score_grade_array[2], 
				score_grade_array[3]]
			break
	
	assert(score_grades.size() == 3)
	
	return score_grades


func _on_continue_btn_pressed() -> void:
	get_tree().change_scene_to_file(SCENE_PATH_TITLE)
