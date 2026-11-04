extends "res://tests/test_narrative.gd"
## Full graphical walkthrough, with captures kept under the ignored artifact directory.
func _initialize() -> void:
	if OS.get_environment("QUNXIA_CAPTURE_DIR").is_empty():
		OS.set_environment("QUNXIA_CAPTURE_DIR", ProjectSettings.globalize_path("res://.review_artifacts"))
	DirAccess.make_dir_recursive_absolute(OS.get_environment("QUNXIA_CAPTURE_DIR"))
	super._initialize()
