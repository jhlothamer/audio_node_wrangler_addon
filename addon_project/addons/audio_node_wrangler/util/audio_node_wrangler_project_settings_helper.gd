class_name AudioNodeWranglerProjectSettingsHelper
extends Object


const PROJECT_SETTING_GIT_COMMIT_WARN = "audio_node_wrangler/settings/warn_of_uncommitted_git_changes"


static func get_git_commit_warn() -> bool:
	if !ProjectSettings.has_setting(PROJECT_SETTING_GIT_COMMIT_WARN):
		ProjectSettings.set_setting(PROJECT_SETTING_GIT_COMMIT_WARN, true)
	return ProjectSettings.get_setting(PROJECT_SETTING_GIT_COMMIT_WARN)


static func set_git_commit_warn(flag: bool) -> void:
	ProjectSettings.set_setting(PROJECT_SETTING_GIT_COMMIT_WARN, flag)


static func update_flag_setting(project_setting_key: String, flag: bool) -> void:
	ProjectSettings.set_setting(project_setting_key, flag)
