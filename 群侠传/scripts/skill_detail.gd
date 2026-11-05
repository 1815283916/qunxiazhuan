extends Control

const Rules = preload("res://scripts/combat_rules.gd")

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
	var lines: Array[String] = []
	var description := _description_without_effects(skill)
	if not description.is_empty(): lines.append(description)
	lines.append("等级：%d / %d" % [level, game_state.SKILL_LEVEL_CAP])
	var experience := int(loadout.get("exp", {}).get(skill_name, 0))
	lines.append("经验：已满级" if level >= game_state.SKILL_LEVEL_CAP else "经验：%d / %d（升级还需%d）" % [experience, game_state.get_skill_experience_needed(level), maxi(0, game_state.get_skill_experience_needed(level) - experience)])
	if skill.kind == "武学":
		lines.append("威力：%d" % skill.get("damage", 0))
		lines.append("倍率：%.1f" % (1.0 + float(maxi(0, level - 1) * int(skill.get("damage_growth", 1))) * 0.1))
		lines.append("施展：%s" % Rules.cast_text(skill))
		lines.append("命中：%s" % Rules.hit_text(skill))
		lines.append("内力消耗：%d" % skill.get("cost", 0))
		if skill.has("cooldown"): lines.append("冷却：%d回合" % skill.cooldown)
	else:
		lines.append("攻击：+%d" % (level * int(skill.get("attack_bonus", 0))))
		lines.append("防御：+%d" % (level * int(skill.get("defense_bonus", 0))))
	$Paper/Description.text = "\n".join(lines)
	var equipped: bool = loadout.martial.has(skill_name) or loadout.internal == skill_name
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
	if loadout.martial.has(name) or loadout.internal == name:
		game_state.unequip_skill(game_state.selected_hero, name)
	else:
		game_state.equip_skill(game_state.selected_hero, name)
	_refresh()
	_append_progress_details()

func _replace_skill(index: int) -> void:
	game_state.equip_skill(game_state.selected_hero, game_state.selected_skill_name, index)
	replacement_menu.hide()
	_refresh()
	_append_progress_details()

func _on_close_pressed() -> void:
	game_state.goto(game_state.detail_return_scene)

func _append_progress_details() -> void:
	var skill_name: String = game_state.selected_skill_name
	var skill: Dictionary = game_state.skill_library[skill_name]
	var details: Array[String] = []
	for effect in skill.get("effects", []):
		details.append(Rules.highlight_status(Rules.martial_effect_label(effect)))
	if not details.is_empty(): $Paper/Description.text += "\n" + "\n".join(details)

func _description_without_effects(skill: Dictionary) -> String:
	var description := str(skill.get("description", ""))
	for effect in skill.get("effects", []):
		var status := Rules.martial_effect_label(effect)
		for prefix in ["命中后获得", "获得"]:
			description = description.replace(prefix + status + "。", "")
			description = description.replace(prefix + status, "")
	return description.strip_edges()
