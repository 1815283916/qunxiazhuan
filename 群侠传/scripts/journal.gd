extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	$Entries.text = "\n\n".join(game_state.journal)

func _on_close_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
