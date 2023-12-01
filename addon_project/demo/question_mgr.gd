extends Node


var _questions = [
	Question.new("Sally sold what by the seashore?", 
	["real estate", "lemonade", "seashells", "snake oil"], 2),
	Question.new("What did Humpty Dumpty sit on?", 
	["whoopy cushion", 
	"pin", 
	"his hands", 
	"a wall"], 3),
	Question.new("Why did the chicken cross the road?", 
	["it felt like it", 
	"to get to the other side", 
	"to get away from the farmer",
	"none of your beeswax"], 1),
	Question.new("How much wood would a wood chuck chuck?", 
	["none", 
	"all", 
	"slightly more than 50%", 
	"depends on the day"], 1),
	Question.new("What did Little Miss Muffet eat as she sat on a tuffet?",
	["curds and whey", 
	"Wheaties", 
	"Bon-bons", 
	"figgy pudding"], 0),
	Question.new("Jack and Jill went up the hill to ______", 
	["play a game of chess", 
	"watch TV", 
	"get a better view of the countryside", 
	"fetch a pail of water"], 3),
	Question.new("What did Little Jack Horner eat while sitting in the corner?",
	["ice cream", 
	"pumpkin pie", 
	"his Christmas pie", 
	"birthday cake"], 2)
]


var _current_question_index := -1


func _ready() -> void:
	var rand_ordered_questions := []
	while !_questions.is_empty():
		var rnd_question = _questions.pick_random()
		_questions.erase(rnd_question)
		rand_ordered_questions.append(rnd_question)
	_questions = rand_ordered_questions


func get_next_question() -> Question:
	_current_question_index += 1
	return _questions[_current_question_index]


func is_last_question(question: Question) -> bool:
	var index = _questions.find(question)
	return index == _questions.size() - 1


func get_question_count() -> int:
	return _questions.size()


func get_correct_answer_count() -> int:
	var correct_answers := 0
	for question in _questions:
		if question.answer_was_correct():
			correct_answers += 1
	
	return correct_answers


func reset() -> void:
	_current_question_index = -1
	for question in _questions:
		question.reset()


