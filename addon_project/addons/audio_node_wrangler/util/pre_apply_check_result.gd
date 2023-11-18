class_name PreApplyCheckResult
extends RefCounted


enum ResultMessageButtons {
	OK,
	OK_CANCEL,
	OK_CANCEL_NO_NAG
}


var issues_found := false
var message := ""
var message_buttons := ResultMessageButtons.OK
var no_nag_project_setting_key := ""


func _init(msg: String = "", msg_btns:ResultMessageButtons = ResultMessageButtons.OK, no_nag_key: String = "") -> void:
	issues_found = !msg.is_empty()
	message = msg
	message_buttons = msg_btns
	no_nag_project_setting_key = no_nag_key

