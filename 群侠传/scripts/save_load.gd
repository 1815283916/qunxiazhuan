extends Control

@onready var game_state := get_node("/root/GameState")
var pending_delete_slot := -1
var deleted_auto_save := false

func _ready() -> void:
	for i in 4:
		get_node("Slots/Slot%d/Save" % (i + 1)).pressed.connect(_save.bind(i + 1))
		get_node("Slots/Slot%d/Save" % (i + 1)).disabled = not game_state.session_started
		get_node("Slots/Slot%d/Load" % (i + 1)).pressed.connect(_load.bind(i + 1))
		get_node("Slots/Slot%d/Delete" % (i + 1)).pressed.connect(_request_delete.bind(i + 1))
	$AutoLoad.pressed.connect(_load.bind(0))
	$AutoDelete.pressed.connect(_request_delete.bind(0))
	$DeleteConfirm.confirmed.connect(_confirm_delete)
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

func _request_delete(slot: int) -> void:
	pending_delete_slot = slot
	$DeleteConfirm.dialog_text = "确定删除自动存档？" if slot == 0 else "确定删除存档%d？" % slot
	$DeleteConfirm.popup_centered()

func _confirm_delete() -> void:
	if pending_delete_slot < 0: return
	var slot := pending_delete_slot
	pending_delete_slot = -1
	var err: int = game_state.delete_save(slot)
	if err == OK and slot == 0: deleted_auto_save = true
	$Notice.text = ("已删除自动存档" if slot == 0 else "已删除存档%d" % slot) if err == OK else "删除存档失败"
	_refresh_slots()

func _saved_hero(cfg: ConfigFile) -> Dictionary:
	var hero_index := clampi(int(cfg.get_value("player", "selected_hero", 0)), 0, game_state.heroes.size() - 1)
	var hero_id := str(cfg.get_value("references", "selected_hero", ""))
	for i in game_state.heroes.size():
		if game_state.heroes[i].id == hero_id: hero_index = i
	return game_state.heroes[hero_index]

func _refresh_slots() -> void:
	var automatic := ConfigFile.new()
	var has_auto: bool = automatic.load(game_state.get_save_path(0)) == OK
	$AutoLoad.disabled = not has_auto
	$AutoDelete.disabled = not has_auto
	$AutoPortrait.visible = has_auto
	if has_auto: $AutoPortrait.texture = load(str(_saved_hero(automatic).head))
	$AutoInfo.text = "自动档：%s · %s" % [automatic.get_value("progress", "saved_at", ""), automatic.get_value("progress", "scene", "")] if has_auto else "自动档：暂无（可在设置中开启，独立保存）"
	for slot in 4:
		var cfg := ConfigFile.new()
		var err: int = cfg.load(game_state.get_save_path(slot + 1))
		var info := get_node("Slots/Slot%d/Info" % (slot + 1)) as Label
		var portrait := get_node("Slots/Slot%d/Portrait" % (slot + 1)) as TextureRect
		var load_button := get_node("Slots/Slot%d/Load" % (slot + 1)) as Button
		var delete_button := get_node("Slots/Slot%d/Delete" % (slot + 1)) as Button
		portrait.visible = err == OK
		load_button.disabled = err != OK
		delete_button.disabled = err != OK
		if err != OK:
			info.text = "存档%d\n空存档" % (slot + 1)
			continue
		var saved_hero := _saved_hero(cfg)
		portrait.texture = load(str(saved_hero.head))
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
	# 删除自动档后返回地图时不立即重建它；下一个真正存档点仍会正常自动保存。
	if not game_state.session_started:
		game_state.goto("res://scenes/main_menu.tscn")
	elif deleted_auto_save:
		get_tree().change_scene_to_file("res://scenes/world_map.tscn")
	else:
		game_state.goto("res://scenes/world_map.tscn")
