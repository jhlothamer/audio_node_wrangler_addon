extends Control

signal dialog_dismissed()

const SCENE_PATH_QUESTION = "res://demo/quiz_question.tscn"
const SCENE_PATH_SCORE = "res://demo/score.tscn"

const CORRECT_ANSWER_TITLES := [
	"Good job!",
	"You're a natural!",
	"No foolin you!",
	"You wrote the book!"
]
const CORRECT_ANSWER_RESPONSES := [
	"Correct!",
	"Keep up the good work!",
	"Maybe that was too easy. :)",
	]
const INCORRECT_ANSWER_TITLES := [
	"R U Kidding?",
	"Oatmeal-for-brains",
	"Maybe you should study more",
	"Are you feelin' OK?",
	"Wrong-o!"
]
const INCORRECT_ANSWER_RESPONSES := [
	"Wrong!",
	"Better luck next time!",
	"You know, this isn't rocket science.",
	"Hahahahahahahaha.  You're joking.  Right?",
	"The depth of your ignorance is astounding."
]




@onready var _question_lbl:Label = $MarginContainer/VBoxContainer/QuestionLabel
@onready var _answer_parent:VBoxContainer = $MarginContainer/VBoxContainer/AnswersVBoxContainer
@onready var _answer_chk:CheckBox = $MarginContainer/VBoxContainer/AnswersVBoxContainer/AnswerCheckBox
@onready var _accept_dlg:AcceptDialog = $AcceptDialog
@onready var _cheers_sound:AudioStreamPlayer = $CheersSound
@onready var _awwww_sound:AudioStreamPlayer = $AwwwSound
@onready var _no_answer_sound:AudioStreamPlayer = $NoAnswerSound
@onready var _button_pressed_sound:AudioStreamPlayer = $ButtonPressedSound


var _question: Question
var _answered := false


func _ready() -> void:
	_question = QuestionMgr.get_next_question()
	_question_lbl.text = _question.question
	for answer in _question.answers:
		var answer_chk = _answer_chk.duplicate()
		answer_chk.visible = true
		answer_chk.text = answer
		_answer_parent.add_child(answer_chk)


func _get_checked_answer() -> CheckBox:
	for chk in _answer_parent.get_children():
		if chk.button_pressed:
			return chk
		
	return null


func _on_continue_btn_pressed() -> void:
	if _answered:
		return
	
	var checked_answer := _get_checked_answer()
	if !checked_answer:
		_accept_dlg.dialog_text = "Please select an answer."
		_accept_dlg.title = "Whoa there!"
		_accept_dlg.popup()
		_no_answer_sound.play()
		return
	
	_answered = true
	var answer_index = _question.answers.find(checked_answer.text)
	if _question.answer_question(answer_index):
		_accept_dlg.title = CORRECT_ANSWER_TITLES.pick_random()
		_accept_dlg.dialog_text = CORRECT_ANSWER_RESPONSES.pick_random()
		_cheers_sound.play()
	else:
		_accept_dlg.title = INCORRECT_ANSWER_TITLES.pick_random()
		_accept_dlg.dialog_text = INCORRECT_ANSWER_RESPONSES.pick_random()
		_awwww_sound.play()
	_accept_dlg.popup()
	await dialog_dismissed
	if _cheers_sound.playing:
		await _cheers_sound.finished
	if _awwww_sound.playing:
		await _awwww_sound.finished
	_button_pressed_sound.play()
	await _button_pressed_sound.finished
	if !QuestionMgr.is_last_question(_question):
		get_tree().change_scene_to_file(SCENE_PATH_QUESTION)
	else:
		get_tree().change_scene_to_file(SCENE_PATH_SCORE)


func _on_accept_dialog_canceled() -> void:
	dialog_dismissed.emit()


func _on_accept_dialog_confirmed() -> void:
	dialog_dismissed.emit()

