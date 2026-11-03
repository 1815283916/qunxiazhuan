extends Control

@onready var game_state := get_node("/root/GameState")
var selected_equipped_slot := ""
var data := {
	"玄铁剑":{"type":"武器【稀有】", "icon":"res://assets/Items/moshenjian.jpg", "text":"重剑无锋，大巧不工。\n\n物品效果：\n攻击力 +28\n剑法技巧 +12\n暴击伤害 +15%"},
	"君子剑":{"type":"武器【普通】", "icon":"res://assets/Items/liquanqiang.jpg", "text":"剑身清亮，端正古雅。\n\n物品效果：\n攻击力 +16\n剑法技巧 +8"},
	"淑女剑":{"type":"武器【精良】", "icon":"res://assets/Items/dao3.jpg", "text":"轻灵秀雅，适合迅捷剑招。\n\n物品效果：\n攻击力 +14\n身法 +6"},
	"魔神剑":{"type":"武器【传说】", "icon":"res://assets/Items/moshenquantao.jpg", "text":"来历不明的古兵，剑意凛然。\n\n物品效果：\n攻击力 +45\n暴击率 +10%"},
	"粗布道袍":{"type":"衣物【普通】", "icon":"res://assets/Items/Dcubudaopao.jpg", "text":"结实耐用的粗布道袍。\n\n物品效果：\n防御力 +12\n生命上限 +80"},
	"乌蚕衣":{"type":"衣物【稀有】", "icon":"res://assets/Items/daopao.jpg", "text":"以乌蚕丝织成，柔韧异常。\n\n物品效果：\n防御力 +24\n韧性 +8"},
	"毒戒指":{"type":"饰品【稀有】", "icon":"res://assets/Items/jiezhi3.jpg", "text":"淬有奇毒的古朴戒指。\n\n物品效果：\n攻击有 15% 概率施加毒素。"},
	"宝玉":{"type":"饰品【精良】", "icon":"res://assets/Items/baoyu.jpg", "text":"温润通透的随身宝玉。\n\n物品效果：\n福缘 +8\n定力 +5"},
	"独孤九剑秘籍":{"type":"经书【绝学】", "icon":"res://assets/Items/Bdugujiujianjianpu.jpg", "text":"记载破尽天下招式的剑理。\n\n使用后可研习独孤九剑。"},
	"易筋经":{"type":"经书【绝学】", "icon":"res://assets/Items/Bkuihuabaodian.jpg", "text":"少林镇派内功典籍。\n\n使用后可研习上乘心法。"},
	"大还丹":{"type":"药品【稀有】", "icon":"res://assets/Items/dahuandan.jpg", "text":"药力浑厚的疗伤丹药。\n\n战斗中恢复大量生命与内力。"},
	"疗伤药":{"type":"药品【普通】", "icon":"res://assets/Items/caoyao.jpg", "text":"常见的江湖伤药。\n\n战斗中恢复少量生命。"}
}
var slots := {
	"玄铁剑":"weapon", "君子剑":"weapon", "淑女剑":"weapon", "魔神剑":"weapon",
	"粗布道袍":"armor", "乌蚕衣":"armor", "毒戒指":"accessory", "宝玉":"accessory"
}
var books := {"独孤九剑秘籍":"独孤九剑", "易筋经":"易筋经"}

func _ready() -> void:
	for item_name in game_state.equipment_library:
		slots[item_name] = str(game_state.equipment_library[item_name].slot)
	var info: Dictionary = data.get(game_state.selected_item, {})
	if game_state.equipment_library.has(game_state.selected_item):
		info = {"type":"装备", "icon":game_state.get_equipment_icon(game_state.selected_item), "text":"装备属性"}
	if info.is_empty(): info = {"type":"物品", "icon":"res://assets/Items/baoyu.jpg", "text":"暂无说明"}
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
		card.visible = i < game_state.heroes.size()
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
