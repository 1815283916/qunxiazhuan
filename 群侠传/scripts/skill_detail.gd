extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	_refresh()
	_append_progress_details()

func _refresh() -> void:
	var skill_name: String = game_state.selected_skill_name
	var skill: Dictionary = game_state.skill_library.get(skill_name, game_state.skill_library["独孤九剑"])
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	var level: int = int(loadout.levels.get(skill_name, 1))
	$Paper/SkillIcon.texture = load(skill.icon)
	$Paper/SkillName.text = skill_name
	$Paper/SkillType.text = "【%s】%s" % [skill.school, skill.kind]
	var martial_details := "倍率 %.1f\n范围 %s\n消耗内力 %d" % [1.0 + float(maxi(0, level - 1) * int(skill.get("damage_growth", 1))) * 0.1, skill.get("pattern", "单体"), skill.get("cost", 0)]
	$Paper/Description.text = "%s\n等级 %d/10\n威力 %d\n%s" % [skill.description, level, skill.get("damage", 0), martial_details if skill.kind == "武学" else "装备心法后生效"]
	$Paper/Forget.visible = skill.kind == "武学"
	$Paper/Switch/Label.text = "切换至心法" if skill.kind == "武学" else "切换至武学"

func _on_switch_pressed() -> void:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	if game_state.skill_library[game_state.selected_skill_name].kind == "武学":
		game_state.selected_skill_name = loadout.internal
	else:
		if loadout.martial.is_empty(): return
		game_state.selected_skill_name = loadout.martial[0]
	game_state.selected_skill_kind = game_state.skill_library[game_state.selected_skill_name].kind
	_refresh()
	_append_progress_details()

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
	_append_progress_details()
	$Paper/Description.text += "\n\n已遗忘该武学。"

func _on_close_pressed() -> void:
	game_state.goto(game_state.detail_return_scene)

func _append_progress_details() -> void:
	var skill_name: String = game_state.selected_skill_name
	var skill: Dictionary = game_state.skill_library[skill_name]
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	var level := int(loadout.levels.get(skill_name, 1))
	var experience := int(loadout.get("exp", {}).get(skill_name, 0))
	var progress := "经验 已满级" if level >= game_state.SKILL_LEVEL_CAP else "经验 %d/%d（升级还需 %d）" % [experience, game_state.get_skill_experience_needed(level), maxi(0, game_state.get_skill_experience_needed(level) - experience)]
	var details := "\n%s\n%s" % [progress, "心法经验随装备心法累计" if skill.kind == "心法" else "武学经验单独累计"]
	if skill.kind == "心法":
		var bonus: Dictionary = game_state.get_internal_skill_bonus(game_state.selected_hero)
		details += "\n攻击 +%d\n防御 +%d" % [bonus.attack, bonus.defense]
	$Paper/Description.text += details
