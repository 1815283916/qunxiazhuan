extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	$Title.text = "战斗%s" % game_state.battle_outcome
	var victory: bool = game_state.battle_outcome == "胜利"
	$Money.text = "获得银两：%d" % (game_state.reward_money if victory else 0)
	$Experience.text = "获得经验：%d / 每人" % (game_state.reward_exp if victory else 0)
	$Rewards.visible = victory
	$Retry.visible = not victory
	$Confirm/Label.text = "确 定" if victory else "放弃挑战"
	$Detail/Text.text = "\n".join(game_state.battle_log) if not game_state.battle_log.is_empty() else "本场没有战斗记录"

func _on_confirm_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")

func _on_details_pressed() -> void:
	$Detail.visible = not $Detail.visible

func _on_retry_pressed() -> void:
	if game_state.battle_outcome == "胜利": return
	game_state.new_battle()
	game_state.goto("res://scenes/battle.tscn")
