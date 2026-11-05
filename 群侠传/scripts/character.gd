extends Control

@onready var game_state := get_node("/root/GameState")
var current_tab := "属性"
var empty_slot_icons := {
	"weapon":"res://assets/UI/zbk_wuqi.png",
	"armor":"res://assets/UI/zbk_fangju.png",
	"accessory":"res://assets/UI/zbk_shipin.png"
}
var equipment_menu: PopupMenu
var pending_equipment_slot := ""
var initial_character_tab := ""
var skill_scroll: ScrollContainer
const EquippedBadge = preload("res://scripts/skill_equipped_badge.gd")

func _ready() -> void:
	initial_character_tab = game_state.character_tab
	for tab in $Paper/Tabs.get_children():
		if tab is TextureButton: tab.pressed.connect(_on_tab_pressed.bind(tab.tooltip_text))
	for i in $Party.get_child_count():
		var portrait := $Party.get_child(i)
		portrait.pressed.connect(_select_party_hero.bind(i))
	$Paper/EquipmentPanel/Weapon.pressed.connect(_open_equipped_item.bind("weapon"))
	$Paper/EquipmentPanel/Armor.pressed.connect(_open_equipped_item.bind("armor"))
	$Paper/EquipmentPanel/Accessory.pressed.connect(_open_equipped_item.bind("accessory"))
	equipment_menu = PopupMenu.new()
	equipment_menu.id_pressed.connect(_on_equipment_choice)
	add_child(equipment_menu)
	for i in $Paper/SkillsPanel/Grid.get_child_count():
		var skill_button := $Paper/SkillsPanel/Grid.get_child(i) as TextureButton
		_prepare_skill_card(skill_button)
		skill_button.pressed.connect(_open_skill_slot.bind(i))
	skill_scroll = ScrollContainer.new()
	skill_scroll.position = Vector2(0, 75)
	skill_scroll.size = Vector2(830, 450)
	skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	$Paper/SkillsPanel.add_child(skill_scroll)
	$Paper/SkillsPanel/Grid.reparent(skill_scroll)
	skill_scroll.name = "Scroll"
	$Paper/SkillsPanel/Scroll/Grid.position = Vector2.ZERO
	call_deferred("_restore_character_tab")
	_refresh_hero()
	_show_tab("属性")

func _refresh_hero() -> void:
	var hero: Dictionary = game_state.heroes[game_state.selected_hero]
	var combat: Dictionary = game_state.get_hero_combat_stats(game_state.selected_hero)
	$Paper/PortraitFrame/Portrait.texture = load(hero.head)
	$Paper/Name.text = hero.name
	$Paper/Overview.text = "等级  %d\n生命  %d / %d\n内力  %d / %d\n经验  %d / %d\n攻击  %d\n防御  %d\n暴击  %.1f%%" % [hero.level, combat.max_hp, combat.max_hp, combat.max_mp, combat.max_mp, hero.get("exp", 0), game_state.get_hero_experience_needed(hero.level), combat.attack, combat.defense, combat.crit]
	var condition := ""
	if game_state.selected_hero == 0: condition = "\n\n经脉状态：已续接" if game_state.Narrative.healed(game_state) else "\n\n经脉状态：尽断，暂不能出战"
	$Paper/BiographyPanel.text = str(hero.get("biography", "")) + condition
	var talent: Dictionary = hero.get("talent", {})
	$Paper/TalentsPanel/Name.text = str(talent.get("name", "暂无天赋"))
	$Paper/TalentsPanel/Description.text = str(talent.get("description", "该侠客尚无可用天赋。"))
	$Paper/WeaponStats.text = "拳掌    %d\n\n剑法    %d\n\n刀法    %d\n\n奇门    %d" % [combat.fist, combat.sword, combat.blade, combat.unorthodox]
	$Paper/BaseStats.text = "臂力    %d       福缘    %d\n\n身法    %d       根骨    %d\n\n悟性    %d       定力    %d" % [combat.strength, combat.luck, combat.agility, combat.constitution, combat.insight, combat.willpower]
	_refresh_equipment()
	_refresh_skills()
	for i in $Party.get_child_count():
		$Party.get_child(i).visible = game_state.hero_available(i)
		var index := i if i < game_state.heroes.size() else 0
		$Party.get_child(i).texture_normal = load(game_state.heroes[index].head)
		$Party.get_child(i).modulate = Color("#ffe78f") if index == game_state.selected_hero else Color.WHITE

func _select_party_hero(index: int) -> void:
	if index >= game_state.heroes.size() or not game_state.hero_available(index): return
	game_state.selected_hero = index
	_refresh_hero()

func _on_back_pressed() -> void:
	var path: String = game_state.character_return_scene
	game_state.character_return_scene = "res://scenes/roster.tscn"
	game_state.goto(path)

func _on_tab_pressed(tab_name: String) -> void:
	_show_tab(tab_name)

func _show_tab(tab_name: String) -> void:
	current_tab = tab_name
	game_state.character_tab = tab_name
	var attribute_nodes := [$Paper/WeaponTitle, $Paper/WeaponStats, $Paper/BaseTitle, $Paper/BaseStats]
	for node in attribute_nodes: node.visible = tab_name == "属性"
	$Paper/EquipmentPanel.visible = tab_name == "装备"
	$Paper/SkillsPanel.visible = tab_name == "技能"
	$Paper/TalentsPanel.visible = tab_name == "天赋"
	$Paper/BiographyPanel.visible = tab_name == "列传"

func _open_item(item_name: String) -> void:
	game_state.selected_item = item_name
	game_state.detail_return_scene = "res://scenes/character.tscn"
	game_state.goto("res://scenes/item_detail.tscn")

func _open_equipped_item(slot: String) -> void:
	var equipment: Dictionary = game_state.hero_equipment[game_state.selected_hero]
	var item_name: String = str(equipment.get(slot, ""))
	if item_name.is_empty():
		_show_equipment_choices(slot)
		return
	_open_item(item_name)

func _show_equipment_choices(slot: String) -> void:
	pending_equipment_slot = slot
	equipment_menu.clear()
	var added := {}
	for item in game_state.inventory:
		var item_name := str(item)
		if added.has(item_name) or not game_state.equipment_library.has(item_name): continue
		if str(game_state.equipment_library[item_name].get("slot", "")) != slot: continue
		equipment_menu.add_item(item_name)
		added[item_name] = true
	if equipment_menu.item_count == 0:
		return
	equipment_menu.position = get_viewport().get_mouse_position()
	equipment_menu.popup()

func _on_equipment_choice(index: int) -> void:
	if pending_equipment_slot.is_empty() or index < 0 or index >= equipment_menu.item_count: return
	var item_name := equipment_menu.get_item_text(index)
	game_state.equip_item(game_state.selected_hero, item_name)
	equipment_menu.hide()
	pending_equipment_slot = ""
	_refresh_hero()

func _refresh_equipment() -> void:
	var equipment: Dictionary = game_state.hero_equipment[game_state.selected_hero]
	var buttons := {
		"weapon": $Paper/EquipmentPanel/Weapon,
		"armor": $Paper/EquipmentPanel/Armor,
		"accessory": $Paper/EquipmentPanel/Accessory
	}
	for slot in buttons:
		var item_name: String = equipment.get(slot, "")
		buttons[slot].tooltip_text = item_name if not item_name.is_empty() else "未装备"
		buttons[slot].get_node("Name").text = item_name if not item_name.is_empty() else "未装备"
		buttons[slot].texture_normal = load(game_state.get_equipment_icon(item_name)) if not item_name.is_empty() else load(empty_slot_icons[slot])

func _open_skill(skill_name: String) -> void:
	game_state.selected_skill_name = skill_name
	game_state.selected_skill_kind = game_state.skill_library[skill_name].kind
	game_state.detail_return_scene = "res://scenes/character.tscn"
	game_state.goto("res://scenes/skill_detail.tscn")

func _open_skill_slot(index: int) -> void:
	var names := _skill_names()
	if index < 0 or index >= names.size(): return
	_open_skill(str(names[index]))

func _skill_names() -> Array:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	return loadout.learned.duplicate()

func _refresh_skills() -> void:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	var equipped := _skill_names()
	var grid := $Paper/SkillsPanel/Scroll/Grid
	$Paper/SkillsPanel/Hint.text = "已学%d个技能 · 已装备武学%d/4、心法%d/1\n勾号表示已装备；点击技能查看详情并装备、卸下或替换。" % [loadout.learned.size(), loadout.martial.size(), 0 if loadout.internal.is_empty() else 1]
	while grid.get_child_count() < equipped.size():
		var index := grid.get_child_count()
		var button := grid.get_child(0).duplicate(0)
		if button.has_node("EquippedBadge"): button.get_node("EquippedBadge").free()
		grid.add_child(button)
		button.pressed.connect(_open_skill_slot.bind(index))
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 30)
	var row_count := ceili(equipped.size() / 5.0)
	grid.custom_minimum_size = Vector2(802, row_count * 150 + maxi(0, row_count - 1) * 30)
	for i in grid.get_child_count():
		var button := grid.get_child(i)
		button.visible = i < equipped.size()
		if not button.visible: continue
		_prepare_skill_card(button)
		var skill_name: String = equipped[i]
		var skill: Dictionary = game_state.skill_library[skill_name]
		var level := int(loadout.levels.get(skill_name, 1))
		button.get_node("Icon").texture = load(skill.icon)
		button.tooltip_text = skill_name
		var detail := skill_name
		button.get_node("Level").text = "Lv.%d" % level
		var worn: bool = loadout.martial.has(skill_name) or loadout.internal == skill_name
		var badge := button.get_node_or_null("EquippedBadge") as Control
		if badge == null:
			badge = EquippedBadge.new()
			badge.name = "EquippedBadge"
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(badge)
		badge.anchor_left = 0.0
		badge.anchor_right = 0.0
		badge.position = Vector2(14, 4)
		badge.size = Vector2(32, 32)
		badge.visible = worn
		button.tooltip_text = skill_name + ("（已装备）" if worn else "（未装备）")
		button.get_node("Name").text = detail

func _prepare_skill_card(button: TextureButton) -> void:
	button.custom_minimum_size = Vector2(146, 150)
	var icon := button.get_node_or_null("Icon") as TextureRect
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon)
		button.move_child(icon, 0)
		icon.texture = button.texture_normal
	button.texture_normal = null
	icon.position = Vector2(14, 0)
	icon.size = Vector2(118, 118)
	var level_label := button.get_node_or_null("Level") as Label
	if level_label == null:
		level_label = Label.new()
		level_label.name = "Level"
		level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		level_label.add_theme_color_override("font_color", Color("ffe58a"))
		level_label.add_theme_color_override("font_outline_color", Color("1a0d08"))
		level_label.add_theme_constant_override("outline_size", 4)
		level_label.add_theme_font_size_override("font_size", 18)
		button.add_child(level_label)
	level_label.position = Vector2(76, 3)
	level_label.size = Vector2(54, 30)
	var label := button.get_node("Name") as Label
	label.position = Vector2(0, 121)
	label.size = Vector2(146, 29)
	label.add_theme_font_size_override("font_size", 18)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _restore_character_tab() -> void:
	if not initial_character_tab.is_empty(): _show_tab(initial_character_tab)
