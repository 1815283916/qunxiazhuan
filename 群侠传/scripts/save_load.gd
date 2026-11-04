extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	for i in 4:
		get_node("Slots/Slot%d/Save" % (i + 1)).pressed.connect(_save.bind(i + 1))
		get_node("Slots/Slot%d/Load" % (i + 1)).pressed.connect(_load.bind(i + 1))
	$AutoLoad.pressed.connect(_load.bind(0))
	_refresh_slots()

func _save(slot: int) -> void:
	var err: int = game_state.save_slot(slot)
	$Notice.text = "存档%d保存成功" % slot if err == OK else "保存失败"
	_refresh_slots()

func _load(slot: int) -> void:
	var err: int = game_state.load_slot(slot)
	if err == OK:
		game_state.goto("res://scenes/world_map.tscn")
	elif err == ERR_FILE_UNRECOGNIZED:
		$Notice.text = "该存档版本不兼容，请选择其他存档"
	else:
		$Notice.text = "该存档位为空或无法读取"

func _refresh_slots() -> void:
	var automatic := ConfigFile.new()
	var has_auto: bool = automatic.load(game_state.get_save_path(0)) == OK
	$AutoLoad.disabled = not has_auto
	$AutoInfo.text = "自动档：%s · %s" % [automatic.get_value("progress", "saved_at", ""), automatic.get_value("progress", "scene", "")] if has_auto else "自动档：暂无（可在设置中开启，独立保存）"
	for slot in 4:
		var cfg := ConfigFile.new()
		var err: int = cfg.load(game_state.get_save_path(slot + 1))
		var info := get_node("Slots/Slot%d/Info" % (slot + 1)) as Label
		if err != OK:
			info.text = "存档%d\n空存档" % (slot + 1)
			continue
		var hero_name: String = str(cfg.get_value("player", "lead_name", game_state.heroes[0].name))
		var hero_id: String = str(cfg.get_value("references", "selected_hero", ""))
		for hero in game_state.heroes:
			if hero.id == hero_id: hero_name = hero.name
		var location: String = str(cfg.get_value("progress", "location", "未知地区"))
		var scene_name: String = str(cfg.get_value("progress", "scene", "未知地点"))
		var saved_at: String = str(cfg.get_value("progress", "saved_at", "旧版存档"))
		var saved_money: int = int(cfg.get_value("player", "money", 0))
		info.text = "存档%d  %s\n%s\n%s · %s\n银两：%d" % [slot + 1, saved_at, hero_name, location, scene_name, saved_money]

func _on_close_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
