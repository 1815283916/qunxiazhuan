extends Control
@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	var result: Dictionary = game_state.battle_rewards
	var victory: bool = result.get("victory", false)
	$Title.text = "战斗胜利" if victory else "战斗失败"
	$Money.text = "获得银两：%d" % int(result.get("money", 0))
	$Experience.text = "结算经验：%d / 每人" % (int(result.heroes[0].exp) if not result.get("heroes", []).is_empty() else 0)
	var growth: Array[String] = []
	for hero in result.get("heroes", []):
		growth.append("%s：+%d经验  Lv.%d%s" % [hero.name, hero.exp, hero.before, " → %d" % hero.after if hero.after > hero.before else ""])
	$Growth.text = "\n".join(growth) if victory else "已恢复开战前的药品与成长，可重新整备后再战。"
	$Objective.text = game_state.get_objective()
	var counts := {}
	for item in result.get("items", []): counts[item] = int(counts.get(item, 0)) + 1
	var names: Array = counts.keys()
	$Rewards.visible = not names.is_empty()
	for i in $Rewards.get_child_count():
		var card := $Rewards.get_child(i)
		card.visible = i < names.size()
		if not card.visible: continue
		var item: String = names[i]
		var icon: String = game_state.item_library.get(item, {}).get("icon", "res://assets/Items/baoyu.jpg")
		card.texture = load(icon)
		card.get_node("Name").text = "%s × %d" % [item, counts[item]]
	$Retry.visible = not victory
	$Confirm/Label.text = "确 定" if victory else "放弃挑战"
	get_node("/root/AudioManager").play_effect("victory" if victory else "defeat")

func _on_confirm_pressed() -> void:
	game_state.goto(game_state.Narrative.followup_scene(game_state))

func _on_retry_pressed() -> void:
	if game_state.battle_outcome == "胜利": return
	game_state.new_battle()
	game_state.goto("res://scenes/battle.tscn")
