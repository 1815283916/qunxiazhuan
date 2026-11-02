extends Control
@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	$TopBar/Money.text = str(game_state.money)
	$TopBar/Reputation.text = str(game_state.reputation)
	for marker in $Locations.get_children():
		if marker is Button:
			if marker.name == "Huashan": marker.pressed.connect(_on_battle_pressed)
			else: marker.pressed.connect(_on_location_pressed.bind(marker.text))

func _on_location_pressed(location: String) -> void:
	game_state.current_scene = location
	game_state.goto("res://scenes/location.tscn")

func _on_battle_pressed() -> void:
	game_state.goto("res://scenes/battle_prep.tscn")

func _on_character_pressed() -> void:
	game_state.goto("res://scenes/roster.tscn")

func _on_menu_pressed() -> void:
	game_state.goto("res://scenes/system_menu.tscn")

func _on_log_pressed() -> void:
	game_state.goto("res://scenes/journal.tscn")

func _on_inventory_pressed() -> void:
	game_state.goto("res://scenes/inventory.tscn")
