extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	$Scroll/Entries.text = "当前目标：%s\n\n%s" % [game_state.get_objective(), "\n\n".join(game_state.journal)]

func _on_close_pressed() -> void:
	game_state.goto(game_state.map_panel_return_scene)
