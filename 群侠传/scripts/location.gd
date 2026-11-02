extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	$TopBar/Location.text = game_state.current_scene
	$Description/Text.text = "你来到了%s。山门古朴，竹影幽深，来往侠客正在谈论近日江湖中的大事。" % game_state.current_scene

func _on_npc_pressed() -> void:
	game_state.goto("res://scenes/dialogue.tscn")

func _on_plaza_pressed() -> void:
	game_state.goto("res://scenes/battle_prep.tscn")

func _on_shop_pressed() -> void:
	game_state.goto("res://scenes/shop.tscn")

func _on_back_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
