extends Control
@onready var game_state := get_node("/root/GameState")

func _on_start_pressed() -> void:
	game_state.reset_new_game()
	game_state.goto("res://scenes/world_map.tscn")

func _on_continue_pressed() -> void:
	game_state.menu_return_scene = "res://scenes/main_menu.tscn"
	game_state.goto("res://scenes/save_load.tscn")

func _on_settings_pressed() -> void:
	game_state.menu_return_scene = "res://scenes/main_menu.tscn"
	game_state.goto("res://scenes/system_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
