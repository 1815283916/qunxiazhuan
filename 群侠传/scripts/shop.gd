extends Control

@onready var game_state := get_node("/root/GameState")
var mode := "buy"
var goods_grid: GridContainer
var goods_scroll: ScrollContainer
var goods: Array[Dictionary] = []

func _ready() -> void:
	for name in game_state.item_library:
		var item: Dictionary = game_state.item_library[name]
		if item.shop: goods.append({"name":name, "price":item.buy_price, "sell_price":item.sell_price, "icon":item.icon})
	goods_grid = $ShopPanel/Goods
	_make_goods_scrollable()
	$Mode/Buy.pressed.connect(_set_mode.bind("buy"))
	$Mode/Sell.pressed.connect(_set_mode.bind("sell"))
	for i in goods_grid.get_child_count():
		goods_grid.get_child(i).pressed.connect(_on_good_pressed.bind(i))
	_set_mode("buy")

func _set_mode(next_mode: String) -> void:
	mode = next_mode
	$Mode/Buy.modulate = Color("#fff0b0") if mode == "buy" else Color.WHITE
	$Mode/Sell.modulate = Color("#fff0b0") if mode == "sell" else Color.WHITE
	$Notice.text = "客官需要买点什么？" if mode == "buy" else "选择背包物品出售，按标价回收。"
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
			if data.is_empty(): continue
			visible_goods.append(data)
	while goods_grid.get_child_count() < visible_goods.size():
		var extra := goods_grid.get_child(0).duplicate(0) as Button
		goods_grid.add_child(extra)
		extra.pressed.connect(_on_good_pressed.bind(goods_grid.get_child_count() - 1))
	for i in goods_grid.get_child_count():
		var card := goods_grid.get_child(i)
		card.visible = i < visible_goods.size()
		if not card.visible: continue
		var data: Dictionary = visible_goods[i]
		card.get_node("Icon").texture = load(_icon_for(str(data.name), str(data.get("icon", ""))))
		card.get_node("Name").text = "%s × %d" % [data.name, game_state.inventory.count(data.name)] if mode == "sell" else data.name
		card.get_node("Price").text = "%d 两" % (int(data.price) if mode == "buy" else int(data.sell_price))
	goods_grid.custom_minimum_size = Vector2(goods_scroll.size.x - 24.0, ceili(float(visible_goods.size()) / 3.0) * 230.0)
	_refresh_money()

func _find_good(item_name: String) -> Dictionary:
	var item: Dictionary = game_state.item_library.get(item_name, {})
	if item.is_empty() or item.get("kind", "") == "任务品": return {}
	return {"name":item_name, "price":item.buy_price, "sell_price":item.sell_price, "icon":item.icon}

func _icon_for(item_name: String, fallback: String) -> String:
	if game_state.equipment_library.has(item_name): return game_state.get_equipment_icon(item_name)
	return str(game_state.item_library.get(item_name, {}).get("icon", fallback))

func _on_good_pressed(index: int) -> void:
	var visible_names: Array[String] = []
	if mode == "buy":
		for data in goods: visible_names.append(data.name)
	else:
		for item_name in game_state.inventory:
			if not _find_good(item_name).is_empty() and not visible_names.has(item_name): visible_names.append(item_name)
	if index < 0 or index >= visible_names.size(): return
	var item_name: String = visible_names[index]
	var data: Dictionary = _find_good(item_name)
	if data.is_empty(): return
	var price: int = int(data.price)
	if mode == "buy":
		if game_state.money < price:
			$Notice.text = "银两不足"
			return
		game_state.money -= price
		game_state.inventory.append(item_name)
		$Notice.text = "购得：" + item_name
	else:
		if not game_state.inventory.has(item_name): return
		game_state.inventory.erase(item_name)
		var sell_price: int = int(data.sell_price)
		game_state.money += sell_price
		$Notice.text = "售出：%s，获得%d两" % [item_name, sell_price]
	_refresh_goods()

func _refresh_money() -> void:
	$Money.text = "银两  %d" % game_state.money

func _on_leave_pressed() -> void:
	game_state.goto("res://scenes/location.tscn")

func _make_goods_scrollable() -> void:
	goods_scroll = ScrollContainer.new()
	goods_scroll.name = "GoodsScroll"
	goods_scroll.position = goods_grid.position
	goods_scroll.size = goods_grid.size
	goods_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	goods_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	goods_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	$ShopPanel.add_child(goods_scroll)
	$ShopPanel.move_child(goods_scroll, goods_grid.get_index())
	goods_grid.reparent(goods_scroll)
	goods_grid.position = Vector2.ZERO
	goods_grid.size = Vector2(goods_scroll.size.x - 24.0, 0.0)
