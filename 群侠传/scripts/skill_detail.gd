extends Control

@onready var game_state := get_node("/root/GameState")
var replacement_menu: PopupMenu

func _ready() -> void:
	replacement_menu = PopupMenu.new()
	replacement_menu.add_theme_font_size_override("font_size", 23)
	replacement_menu.id_pressed.connect(_replace_skill)
	add_child(replacement_menu)
	_refresh()
	_append_progress_details()

func _refresh() -> void:
	var skill_name: String = game_state.selected_skill_name
	var skill: Dictionary = game_state.skill_library[skill_name]
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	var level: int = int(loadout.levels.get(skill_name, 1))
	$Paper/SkillIcon.texture = load(skill.icon)
	$Paper/SkillName.text = skill_name
	$Paper/SkillType.text = "【%s】%s" % [skill.school, skill.kind]
	var martial_details := "倍率 %.1f\n范围 %s\n消耗内力 %d" % [1.0 + float(maxi(0, level - 1) * int(skill.get("damage_growth", 1))) * 0.1, skill.get("pattern", "单体"), skill.get("cost", 0)]
	$Paper/Description.text = "%s\n等级 %d/%d\n%s" % [skill.description, level, game_state.SKILL_LEVEL_CAP, "威力 %d\n%s" % [skill.get("damage", 0), martial_details] if skill.kind == "武学" else "装备心法后生效"]
	var equipped: bool = loadout.martial.has(skill_name) or loadout.internal == skill_name
	$Paper/Description.text += "\n状态：%s" % ("已装备" if equipped else "已学会，未装备")
	$Paper/Equip.visible = true
	$Paper/Equip.disabled = skill.kind == "心法" and equipped
	$Paper/Equip/Label.text = "已装备" if skill.kind == "心法" and equipped else "卸 下" if equipped else "装 备"
	if skill.kind == "武学" and not equipped and loadout.martial.size() == 4: $Paper/Equip/Label.text = "替换武学"
	$Paper/Switch/Label.text = "下一个技能"

func _on_switch_pressed() -> void:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	if loadout.learned.is_empty(): return
	var index: int = loadout.learned.find(game_state.selected_skill_name)
	game_state.selected_skill_name = loadout.learned[(index + 1) % loadout.learned.size()]
	game_state.selected_skill_kind = game_state.skill_library[game_state.selected_skill_name].kind
	_refresh()
	_append_progress_details()

func _on_equip_pressed() -> void:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	var name: String = game_state.selected_skill_name
	if game_state.skill_library[name].kind == "武学" and not loadout.martial.has(name) and loadout.martial.size() == 4:
		replacement_menu.clear()
		for previous in loadout.martial: replacement_menu.add_item("替换%s" % previous)
		replacement_menu.popup_centered()
		return
	var message: String = game_state.unequip_skill(game_state.selected_hero, name) if loadout.martial.has(name) or loadout.internal == name else game_state.equip_skill(game_state.selected_hero, name)
	_refresh()
	_append_progress_details()
	$Paper/Description.text += "\n\n" + message

func _replace_skill(index: int) -> void:
	var message: String = game_state.equip_skill(game_state.selected_hero, game_state.selected_skill_name, index)
	replacement_menu.hide()
	_refresh()
	_append_progress_details()
	$Paper/Description.text += "\n\n" + message

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
		details += "\n攻击 +%d\n防御 +%d" % [level * int(skill.get("attack_bonus", 0)), level * int(skill.get("defense_bonus", 0))]
		if loadout.internal != skill_name:
			var old: Dictionary = game_state.get_internal_skill_bonus(game_state.selected_hero)
			var combat: Dictionary = game_state.get_hero_combat_stats(game_state.selected_hero)
			var attack_change: int = level * int(skill.get("attack_bonus", 0)) - int(old.attack)
			var defense_change: int = level * int(skill.get("defense_bonus", 0)) - int(old.defense)
			details += "\n切换后攻击：%d → %d（%+d）\n切换后防御：%d → %d（%+d）" % [combat.attack, combat.attack + attack_change, attack_change, combat.defense, combat.defense + defense_change, defense_change]
	$Paper/Description.text += details
