extends Control

@onready var game_state := get_node("/root/GameState")
var mode := "buy"
var goods := [
	{"name":"大还丹", "price":180, "icon":"res://assets/Items/dahuandan.jpg"},
	{"name":"疗伤药", "price":60, "icon":"res://assets/Items/caoyao.jpg"},
	{"name":"君子剑", "price":520, "icon":"res://assets/Items/liquanqiang.jpg"},
	{"name":"毒戒指", "price":350, "icon":"res://assets/Items/jiezhi3.jpg"},
	{"name":"独孤九剑秘籍", "price":900, "icon":"res://assets/Items/Bdugujiujianjianpu.jpg"},
	{"name":"粗布道袍", "price":220, "icon":"res://assets/Items/Dcubudaopao.jpg"}
]

func _ready() -> void:
	$Mode/Buy.pressed.connect(_set_mode.bind("buy"))
	$Mode/Sell.pressed.connect(_set_mode.bind("sell"))
	for i in $ShopPanel/Goods.get_child_count():
		$ShopPanel/Goods.get_child(i).pressed.connect(_on_good_pressed.bind(i))
	_set_mode("buy")

func _set_mode(next_mode: String) -> void:
	mode = next_mode
	$Mode/Buy.modulate = Color("#fff0b0") if mode == "buy" else Color.WHITE
	$Mode/Sell.modulate = Color("#fff0b0") if mode == "sell" else Color.WHITE
	$Notice.text = "客官需要买点什么？" if mode == "buy" else "选择物品出售，可获得半价银两。"
	_refresh_goods()

func _refresh_goods() -> void:
	var visible_goods: Array[Dictionary] = []
	if mode == "buy":
		for data in goods: visible_goods.append(data)
	else:
		var seen: Array[String] = []
		for item_name in game_state.inventory:
			if seen.has(item_name): continue
			seen.append(item_name)
			var data: Dictionary = _find_good(item_name)
			if data.is_empty(): data = {"name":item_name, "price":20, "icon":"res://assets/Items/caoyao.jpg"}
			visible_goods.append(data)
	for i in $ShopPanel/Goods.get_child_count():
		var card := $ShopPanel/Goods.get_child(i)
		card.visible = i < visible_goods.size()
		if not card.visible: continue
		var data: Dictionary = visible_goods[i]
		card.get_node("Icon").texture = load(data.icon)
		card.get_node("Name").text = "%s × %d" % [data.name, game_state.inventory.count(data.name)] if mode == "sell" else data.name
		card.get_node("Price").text = "%d 两" % (int(data.price) if mode == "buy" else maxi(1, int(data.price / 2.0)))
	_refresh_money()

func _find_good(item_name: String) -> Dictionary:
	for data in goods:
		if data.name == item_name: return data
	return {}

func _on_good_pressed(index: int) -> void:
	var visible_names: Array[String] = []
	if mode == "buy":
		for data in goods: visible_names.append(data.name)
	else:
		for item_name in game_state.inventory:
			if not visible_names.has(item_name): visible_names.append(item_name)
	if index < 0 or index >= visible_names.size(): return
	var item_name: String = visible_names[index]
	var data: Dictionary = _find_good(item_name)
	var price: int = int(data.get("price", 20))
	if mode == "buy":
		if game_state.money < price:
			$Notice.text = "银两不足"
			return
		game_state.money -= price
		game_state.inventory.append(item_name)
		$Notice.text = "购得：" + item_name
	else:
		for equipment in game_state.hero_equipment:
			if item_name in equipment.values():
				$Notice.text = "装备中的物品不能出售"
				return
		if not game_state.inventory.has(item_name): return
		game_state.inventory.erase(item_name)
		var sell_price: int = maxi(1, int(price / 2.0))
		game_state.money += sell_price
		$Notice.text = "售出：%s，获得%d两" % [item_name, sell_price]
	_refresh_goods()

func _refresh_money() -> void:
	$Money.text = "银两  %d" % game_state.money

func _on_leave_pressed() -> void:
	game_state.goto("res://scenes/location.tscn")
