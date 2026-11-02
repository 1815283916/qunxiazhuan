extends Control

@onready var game_state := get_node("/root/GameState")

func _ready() -> void:
	for i in 4:
		get_node("Slots/Slot%d/Save" % (i + 1)).pressed.connect(_save.bind(i + 1))
		get_node("Slots/Slot%d/Load" % (i + 1)).pressed.connect(_load.bind(i + 1))
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
		$Notice.text = "存档%d版本不兼容，请使用当前版本重新存档" % slot
	else:
		$Notice.text = "该存档位为空或无法读取"

func _refresh_slots() -> void:
	for slot in 4:
		var cfg := ConfigFile.new()
		var err: int = cfg.load("user://qunxia_slot_%d.cfg" % (slot + 1))
		var info := get_node("Slots/Slot%d/Info" % (slot + 1)) as Label
		if err != OK:
			info.text = "存档%d\n空存档" % (slot + 1)
			continue
		var hero_name: String = str(cfg.get_value("player", "lead_name", "宇文逸"))
		var location: String = str(cfg.get_value("progress", "location", "未知地区"))
		var scene_name: String = str(cfg.get_value("progress", "scene", "未知地点"))
		var saved_at: String = str(cfg.get_value("progress", "saved_at", "旧版存档"))
		var saved_money: int = int(cfg.get_value("player", "money", 0))
		info.text = "存档%d  %s\n%s\n%s · %s\n银两：%d" % [slot + 1, saved_at, hero_name, location, scene_name, saved_money]

func _on_close_pressed() -> void:
	game_state.goto("res://scenes/world_map.tscn")
