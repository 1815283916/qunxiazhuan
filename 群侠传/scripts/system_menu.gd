extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	var keys: Array = game_state.settings.keys()
	for i in $Options.get_child_count():
		var check := $Options.get_child(i) as CheckButton
		check.button_pressed = bool(game_state.settings[keys[i]])
		check.toggled.connect(_toggle.bind(keys[i]))

func _toggle(value: bool, key: String) -> void:
	game_state.settings[key] = value
	if key == "fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_save_pressed() -> void:
	game_state.goto("res://scenes/save_load.tscn")

func _on_main_menu_pressed() -> void:
	game_state.goto("res://scenes/main_menu.tscn")

func _on_back_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
