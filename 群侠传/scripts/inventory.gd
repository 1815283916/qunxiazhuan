extends Control

@onready var game_state := get_node("/root/GameState")

const CATEGORY_ORDER := ["All", "Equipment", "Books", "Consumables", "Special", "Tasks"]
const CATEGORY_LABELS := {
	"All": "全部", "Equipment": "装备", "Books": "秘籍",
	"Consumables": "消耗品", "Special": "特殊", "Tasks": "任务品"
}
const BOOK_ITEMS := ["独孤九剑秘籍", "易筋经"]
const CONSUMABLE_ITEMS := ["大还丹", "疗伤药"]

var current_category := "All"
var item_grid: GridContainer
var item_scroll: ScrollContainer
var item_template: Button
var item_icons := {
	"玄铁剑":"res://assets/Items/moshenjian.jpg", "君子剑":"res://assets/Items/liquanqiang.jpg",
	"淑女剑":"res://assets/Items/dao3.jpg", "魔神剑":"res://assets/Items/moshenquantao.jpg",
	"粗布道袍":"res://assets/Items/Dcubudaopao.jpg", "乌蚕衣":"res://assets/Items/daopao.jpg",
	"毒戒指":"res://assets/Items/jiezhi3.jpg", "宝玉":"res://assets/Items/baoyu.jpg",
	"独孤九剑秘籍":"res://assets/Items/Bdugujiujianjianpu.jpg", "易筋经":"res://assets/Items/Bkuihuabaodian.jpg",
	"大还丹":"res://assets/Items/dahuandan.jpg", "疗伤药":"res://assets/Items/caoyao.jpg"
}

func _ready() -> void:
	for item_name in game_state.equipment_library:
		item_icons[item_name] = game_state.get_equipment_icon(item_name)
	item_grid = $Items
	item_template = item_grid.get_node("ItemTemplate")
	_make_item_grid_scrollable()
	for category in CATEGORY_ORDER:
		$Categories.get_node(category).pressed.connect(_show_category.bind(category))
	_show_category("All")

func _show_category(category: String) -> void:
	current_category = category
	for child in item_grid.get_children():
		if child.name != "ItemTemplate": child.queue_free()
	var names := _visible_items()
	$Title.text = "物品列表【%d】" % names.size()
	$Status.text = "%s  ·  共 %d 件物品（含已装备）" % [CATEGORY_LABELS[category], _owned_item_count()]
	$Empty.visible = names.is_empty()
	for category_name in CATEGORY_ORDER:
		var button := $Categories.get_node(category_name) as Button
		button.add_theme_color_override("font_color", Color("ffe026") if category_name == category else Color("ebe7d8"))
	for item_name in names:
		_add_item_card(item_name)
	item_grid.custom_minimum_size = Vector2(item_scroll.size.x - 24.0, ceili(float(names.size()) / 7.0) * 196.0)

func _visible_items() -> Array[String]:
	var names: Array[String] = []
	for item_name in _owned_item_names():
		if not _matches_category(item_name): continue
		if not names.has(item_name): names.append(item_name)
	return names

func _owned_item_names() -> Array[String]:
	var names: Array[String] = []
	for item in game_state.inventory:
		var item_name := str(item)
		if not names.has(item_name): names.append(item_name)
	return names

func _matches_category(item_name: String) -> bool:
	match current_category:
		"All": return true
		"Equipment": return game_state.equipment_library.has(item_name)
		"Books": return item_name in BOOK_ITEMS
		"Consumables": return item_name in CONSUMABLE_ITEMS
		"Special", "Tasks": return false
	return false

func _add_item_card(item_name: String) -> void:
	var card := item_template.duplicate() as Button
	card.name = "Item_%s" % item_name
	card.visible = true
	card.get_node("Name").text = item_name
	card.get_node("Icon").texture = load(item_icons.get(item_name, "res://assets/Items/baoyu.jpg"))
	var count: int = _item_total_count(item_name)
	card.get_node("Count").text = "×%d" % count if count > 1 else ""
	card.get_node("Equipped").visible = _is_equipped(item_name)
	card.tooltip_text = "%s × %d" % [item_name, count]
	card.pressed.connect(_open_item.bind(item_name))
	item_grid.add_child(card)

func _is_equipped(item_name: String) -> bool:
	for equipment in game_state.hero_equipment:
		if item_name in equipment.values(): return true
	return false

func _item_total_count(item_name: String) -> int:
	return game_state.inventory.count(item_name)

func _owned_item_count() -> int:
	return game_state.inventory.size()

func _on_close_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")

func _open_item(item_name: String) -> void:
	game_state.selected_item = item_name
	game_state.detail_return_scene = "res://scenes/inventory.tscn"
	game_state.goto("res://scenes/item_detail.tscn")

func _make_item_grid_scrollable() -> void:
	item_scroll = ScrollContainer.new()
	item_scroll.name = "ItemsScroll"
	item_scroll.position = item_grid.position
	item_scroll.size = item_grid.size
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	item_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(item_scroll)
	move_child(item_scroll, item_grid.get_index())
	item_grid.reparent(item_scroll)
	item_grid.position = Vector2.ZERO
	item_grid.size = Vector2(item_scroll.size.x - 24.0, 0.0)
