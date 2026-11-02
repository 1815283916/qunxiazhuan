extends Control

@onready var game_state := get_node("/root/GameState")
var categories := {"武器":["玄铁剑","君子剑","淑女剑","魔神剑"], "防具":["粗布道袍","乌蚕衣"], "饰品":["毒戒指","宝玉"], "经书":["独孤九剑秘籍","易筋经"], "暗器":["飞蝗石","金蛇锥"]}
var item_icons := {
	"玄铁剑":"res://assets/Items/moshenjian.jpg", "君子剑":"res://assets/Items/liquanqiang.jpg",
	"淑女剑":"res://assets/Items/dao3.jpg", "魔神剑":"res://assets/Items/moshenquantao.jpg",
	"粗布道袍":"res://assets/Items/Dcubudaopao.jpg", "乌蚕衣":"res://assets/Items/daopao.jpg",
	"毒戒指":"res://assets/Items/jiezhi3.jpg", "宝玉":"res://assets/Items/baoyu.jpg",
	"独孤九剑秘籍":"res://assets/Items/Bdugujiujianjianpu.jpg", "易筋经":"res://assets/Items/Bkuihuabaodian.jpg"
}

func _ready() -> void:
	for button in $Categories.get_children():
		var category: String = button.tooltip_text if button is TextureButton else button.text
		button.pressed.connect(_show_category.bind(category))
	_show_category("武器")
	for card in $Items.get_children():
		card.pressed.connect(_open_item.bind(card))

func _show_category(category: String) -> void:
	var names: Array = []
	for item_name in categories.get(category, []):
		if game_state.inventory.has(item_name): names.append(item_name)
	$Title.text = category + "列表 【%d】" % names.size()
	for i in $Items.get_child_count():
		var card := $Items.get_child(i)
		card.visible = i < names.size()
		if card.visible:
			card.get_node("Name").text = names[i]
			card.get_node("Icon").texture = load(item_icons.get(names[i], "res://assets/Items/baoyu.jpg"))

func _on_close_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")

func _open_item(card: Button) -> void:
	game_state.selected_item = card.get_node("Name").text
	game_state.detail_return_scene = "res://scenes/inventory.tscn"
	game_state.goto("res://scenes/item_detail.tscn")
