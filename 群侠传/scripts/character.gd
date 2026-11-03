extends Control

@onready var game_state := get_node("/root/GameState")
var current_tab := "属性"
var item_icons := {
	"玄铁剑":"res://assets/Items/moshenjian.jpg", "君子剑":"res://assets/Items/liquanqiang.jpg",
	"淑女剑":"res://assets/Items/dao3.jpg", "魔神剑":"res://assets/Items/moshenquantao.jpg",
	"粗布道袍":"res://assets/Items/Dcubudaopao.jpg", "乌蚕衣":"res://assets/Items/daopao.jpg",
	"毒戒指":"res://assets/Items/jiezhi3.jpg", "宝玉":"res://assets/Items/baoyu.jpg"
}
var empty_slot_icons := {
	"weapon":"res://assets/UI/zbk_wuqi.png",
	"armor":"res://assets/UI/zbk_fangju.png",
	"accessory":"res://assets/UI/zbk_shipin.png"
}
var equipment_menu: PopupMenu
var pending_equipment_slot := ""
var initial_character_tab := ""

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
		$Paper/SkillsPanel/Grid.get_child(i).pressed.connect(_open_skill_slot.bind(i))
	call_deferred("_restore_character_tab")
	_refresh_hero()
	_show_tab("属性")

func _refresh_hero() -> void:
	var hero: Dictionary = game_state.heroes[game_state.selected_hero]
	var combat: Dictionary = game_state.get_hero_combat_stats(game_state.selected_hero)
	$Paper/PortraitFrame/Portrait.texture = load(hero.head)
	$Paper/Name.text = hero.name
	$Paper/Overview.text = "等级  %d\n生命  %d / %d\n内力  %d / %d\n经验  %d / %d\n攻击  %d\n韧性  %d\n防御  %d\n暴击  %.1f%%" % [hero.level, combat.max_hp, combat.max_hp, combat.max_mp, combat.max_mp, hero.get("exp", 0), hero.level * 200, combat.attack, combat.speed, combat.defense, combat.crit]
	$Paper/WeaponStats.text = "拳掌    %d\n\n剑法    %d\n\n刀法    %d\n\n奇门    %d" % [combat.fist, combat.sword, combat.blade, combat.unorthodox]
	$Paper/BaseStats.text = "臂力    %d       福缘    %d\n\n身法    %d       根骨    %d\n\n悟性    %d       定力    %d" % [combat.strength, combat.luck, combat.agility, combat.constitution, combat.insight, combat.willpower]
	_refresh_equipment()
	_refresh_skills()
	for i in $Party.get_child_count():
		var index := i if i < game_state.heroes.size() else 0
		$Party.get_child(i).texture_normal = load(game_state.heroes[index].head)
		$Party.get_child(i).modulate = Color("#ffe78f") if index == game_state.selected_hero else Color.WHITE

func _select_party_hero(index: int) -> void:
	if index >= game_state.heroes.size(): return
	game_state.selected_hero = index
	_refresh_hero()

func _on_back_pressed() -> void:
	game_state.goto("res://scenes/roster.tscn")

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
		buttons[slot].texture_normal = load(item_icons[item_name]) if item_icons.has(item_name) else load(empty_slot_icons[slot])

func _open_skill(skill_name: String) -> void:
	game_state.selected_skill_name = skill_name
	game_state.selected_skill_kind = "心法" if skill_name == "九阳神功" else "武学"
	game_state.detail_return_scene = "res://scenes/character.tscn"
	game_state.goto("res://scenes/skill_detail.tscn")

func _open_skill_slot(index: int) -> void:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	var equipped: Array = loadout.martial.duplicate()
	equipped.append(loadout.internal)
	if index < 0 or index >= equipped.size(): return
	_open_skill(str(equipped[index]))

func _refresh_skills() -> void:
	var loadout: Dictionary = game_state.hero_skills[game_state.selected_hero]
	var equipped: Array = loadout.martial.duplicate()
	equipped.append(loadout.internal)
	var grid := $Paper/SkillsPanel/Grid
	for i in grid.get_child_count():
		var button := grid.get_child(i)
		button.visible = i < equipped.size()
		if not button.visible: continue
		var skill_name: String = equipped[i]
		var skill: Dictionary = game_state.skill_library[skill_name]
		button.texture_normal = load(skill.icon)
		button.tooltip_text = skill_name
		button.get_node("Name").text = "%s\nLv.%d" % [skill_name, loadout.levels.get(skill_name, 1)]

func _restore_character_tab() -> void:
	if not initial_character_tab.is_empty(): _show_tab(initial_character_tab)
