extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	var skill_name: String = game_state.selected_skill_name
	var skill: Dictionary = game_state.skill_library.get(skill_name, game_state.skill_library["独孤九剑"])
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	var level: int = int(loadout.levels.get(skill_name, 1))
	$Paper/SkillIcon.texture = load(skill.icon)
	$Paper/SkillName.text = skill_name
	$Paper/SkillType.text = "【%s】%s" % [skill.school, skill.kind]
	var martial_details := "倍率 %.1f\n范围 %s\n消耗内力 %d" % [1.0 + float(maxi(0, level - 1)) * 0.1, skill.get("pattern", "单体"), skill.get("cost", 0)]
	$Paper/Description.text = "%s\n等级 %d/10\n威力 %d\n%s" % [skill.description, level, skill.get("damage", 0), martial_details if skill.kind == "武学" else "装备心法后生效"]
	$Paper/Forget.visible = skill.kind == "武学"
	$Paper/Switch/Label.text = "切换至心法" if skill.kind == "武学" else "切换至武学"

func _on_switch_pressed() -> void:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	if game_state.skill_library[game_state.selected_skill_name].kind == "武学":
		game_state.selected_skill_name = loadout.internal
	else:
		game_state.selected_skill_name = loadout.martial[0]
	game_state.selected_skill_kind = game_state.skill_library[game_state.selected_skill_name].kind
	_refresh()

func _on_forget_pressed() -> void:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	if loadout.martial.size() <= 1:
		$Paper/Description.text += "\n\n至少保留一个武学，无法遗忘。"
		return
	loadout.martial.erase(game_state.selected_skill_name)
	loadout.levels.erase(game_state.selected_skill_name)
	loadout.exp.erase(game_state.selected_skill_name)
	game_state.selected_skill_name = loadout.martial[0]
	_refresh()
	$Paper/Description.text += "\n\n已遗忘该武学。"

func _on_close_pressed() -> void:
	game_state.goto(game_state.detail_return_scene)
