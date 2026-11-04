extends Control

@onready var game_state := get_node("/root/GameState")
var selected_equipped_slot := ""
var slots := {}
var books := {}

func _ready() -> void:
	for item_name in game_state.equipment_library:
		slots[item_name] = str(game_state.equipment_library[item_name].slot)
	for name in game_state.item_library:
		if game_state.item_library[name].kind == "秘籍": books[name] = game_state.item_library[name].skill_id
	var item: Dictionary = game_state.item_library.get(game_state.selected_item, {})
	var info := {"type":item.get("kind", "物品"), "icon":item.get("icon", "res://assets/Items/baoyu.jpg"), "text":item.get("description", "暂无说明")}
	if not item.is_empty():
		if item.kind == "药品": info.text += "\n恢复气血 %d、内力 %d" % [item.heal_hp, item.heal_mp]
		info.text += "\n获取：%s\n买价 %d 两 · 卖价 %d 两" % [item.source, item.buy_price, item.sell_price]
	$Paper/ItemIcon.texture = load(info.icon)
	$Paper/ItemName.text = game_state.selected_item
	$Paper/ItemType.text = info.type
	$Paper/Description.text = info.text
	if slots.has(game_state.selected_item): $Paper/Description.text += _equipment_bonus_text(game_state.selected_item)
	$Paper/Equip.visible = slots.has(game_state.selected_item) or books.has(game_state.selected_item)
	_refresh_equip_button()
	$Paper/Equip/Label.text = "研 习" if books.has(game_state.selected_item) else "装 备"
	call_deferred("_refresh_equip_button")
	for i in $Paper/LearnerPanel/Grid.get_child_count():
		var card := $Paper/LearnerPanel/Grid.get_child(i)
		card.visible = i < game_state.heroes.size() and game_state.hero_available(i)
		if not card.visible: continue
		card.get_node("Portrait").texture = load(game_state.heroes[i].head)
		card.get_node("Name").text = game_state.heroes[i].name
		card.pressed.connect(_select_target_hero.bind(i))

func _on_equip_pressed() -> void:
	if not selected_equipped_slot.is_empty():
		$Paper/Notice.text = game_state.unequip_item(game_state.selected_hero, selected_equipped_slot)
		game_state.goto(game_state.detail_return_scene)
		return
	if not slots.has(game_state.selected_item) and not books.has(game_state.selected_item):
		$Paper/Notice.text = "此物品不能直接装备"
		return
	$Paper/LearnerPanel.visible = not $Paper/LearnerPanel.visible
	$Paper/LearnerPanel/LearnerTitle.text = "请选择研习秘籍的侠客" if books.has(game_state.selected_item) else "请选择装备此物品的侠客"
	$Paper/Notice.text = "选择目标侠客"

func _select_target_hero(hero_index: int) -> void:
	if hero_index < 0 or hero_index >= game_state.heroes.size(): return
	game_state.selected_hero = hero_index
	if books.has(game_state.selected_item):
		$Paper/Notice.text = game_state.learn_from_book(hero_index, game_state.selected_item)
	else:
		$Paper/Notice.text = game_state.equip_item(hero_index, game_state.selected_item)
	$Paper/LearnerPanel.visible = false
	if not books.has(game_state.selected_item): game_state.goto(game_state.detail_return_scene)

func _on_close_pressed() -> void:
	game_state.goto(game_state.detail_return_scene)

func _refresh_equip_button() -> void:
	selected_equipped_slot = ""
	$Paper/Equip.disabled = false
	if slots.has(game_state.selected_item):
		var slot: String = slots[game_state.selected_item]
		var equipment: Dictionary = game_state.hero_equipment[game_state.selected_hero]
		if equipment.get(slot, "") == game_state.selected_item:
			selected_equipped_slot = slot
		else:
			for hero_index in game_state.hero_equipment.size():
				var other_equipment: Dictionary = game_state.hero_equipment[hero_index]
				if other_equipment.get(slot, "") == game_state.selected_item:
					$Paper/Equip.disabled = true
					$Paper/Equip/Label.text = "已装备"
					return
	$Paper/Equip/Label.text = "研习" if books.has(game_state.selected_item) else "卸下" if not selected_equipped_slot.is_empty() else "装备"

func _equipment_bonus_text(item_name: String) -> String:
	var item: Dictionary = game_state.equipment_library.get(item_name, {})
	var labels := {
		"attack":"攻击", "defense":"防御", "hp":"生命上限", "speed":"速度",
		"crit":"暴击率", "crit_damage":"暴击伤害", "poison":"中毒概率",
		"agility":"身法", "luck":"福缘", "willpower":"定力", "fist":"拳掌",
		"sword":"剑法", "blade":"刀法", "unorthodox":"奇门"
	}
	var lines: Array[String] = ["\n\n实际属性加成"]
	for key in labels:
		var amount := int(item.get(key, 0))
		if amount == 0: continue
		var suffix := "%" if key in ["crit", "crit_damage", "poison"] else ""
		lines.append("%s %+d%s" % [labels[key], amount, suffix])
	return "\n".join(lines)
