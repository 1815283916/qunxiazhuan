extends Control
@onready var game_state := get_node("/root/GameState")

var lines := [
	["宇文逸", "是，弟子一定行侠仗义，不堕我武当威名。"],
	["神秘剑客", "华山论剑将启，若想扬名江湖，便来试试你的剑。"],
	["宇文逸", "承让。此番我定会赴约。"]
]
var index := 0

func _ready() -> void:
	$DialogueBox/Speaker.text = lines[0][0]
	$DialogueBox/Text.text = lines[0][1]

func _on_continue_pressed() -> void:
	index += 1
	if index >= lines.size():
		game_state.goto("res://scenes/world_map.tscn")
		return
	$DialogueBox/Speaker.text = lines[index][0]
	$DialogueBox/Text.text = lines[index][1]

func _on_battle_pressed() -> void:
	game_state.goto("res://scenes/battle_prep.tscn")

func _on_skip_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
