extends Control
@onready var game_state := get_node("/root/GameState")

func _on_start_pressed() -> void:
	game_state.reset_new_game()
	game_state.goto("res://scenes/world_map.tscn")

func _on_continue_pressed() -> void:
	var err: Error = game_state.load_latest()
	if err == OK:
		game_state.goto("res://scenes/world_map.tscn")
	else:
		$Notice/Text.text = "暂无可读取的存档，请先开始江湖旅程"
		$Notice.visible = true

func _on_settings_pressed() -> void:
	game_state.menu_return_scene = "res://scenes/main_menu.tscn"
	game_state.goto("res://scenes/system_menu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
