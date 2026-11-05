extends RefCounted

const STATUS_COLOR := Color("#ffd95c")

const LABELS := {
	"wound":"重伤", "internal_wound":"内伤", "combo":"连击", "evasion":"飘逸",
	"poison":"中毒", "paralysis":"麻痹", "chill":"寒冷", "focus":"凝神",
	"fury":"狂战", "haste":"神速", "root":"定身", "stun":"晕眩", "blind":"致盲",
	"attack_up":"攻击提高", "defense_up":"防御提高", "attack_down":"攻击弱化",
	"defense_down":"防御弱化", "harmony":"天人合一", "mana_regen":"归元",
	"heal_regen":"恢复", "berserk":"入魔", "guard":"坚守"
}
const CAPS := {"combo":5, "evasion":3, "poison":11, "paralysis":5, "chill":5,
	"focus":3, "haste":5, "attack_up":5, "defense_up":5, "attack_down":5,
	"defense_down":5, "mana_regen":3, "heal_regen":3}
const NEGATIVE := ["wound", "internal_wound", "poison", "paralysis", "chill", "root",
	"stun", "blind", "attack_down", "defense_down", "berserk"]

static func layers(unit: Dictionary, id: String) -> int:
	return int(unit.get("statuses", {}).get(id, {}).get("layers", 0))

static func scaled(unit: Dictionary, id: String, first: int, step: int) -> int:
	var count := layers(unit, id)
	return first + (count - 1) * step if count > 0 else 0

static func interval(unit: Dictionary) -> int:
	var speed_bonus := scaled(unit, "haste", 30, 5)
	if unit.get("passive", "") != "swift":
		speed_bonus -= scaled(unit, "paralysis", 30, 5) + scaled(unit, "chill", 20, 3)
	return maxi(30, ceili(100.0 * unit.action_delay / clampi(100 + speed_bonus, 55, 150)))

static func movement(unit: Dictionary) -> int:
	if layers(unit, "root") > 0: return 0
	return maxi(1, int(unit.move_range) - (1 if unit.get("passive", "") == "reflect" else 0))

static func apply(unit: Dictionary, id: String, stacks: int, duration: int, now: int) -> bool:
	if not unit.alive or not LABELS.has(id) or stacks < 1 or duration < 1: return false
	if id in NEGATIVE and layers(unit, "harmony") > 0: return false
	if id == "poison" and unit.get("poison_immune", false): return false
	if id == "stun" and unit.get("stun_recovery", false): return false
	if unit.get("passive", "") == "swift" and id in ["paralysis", "root"]: return false
	var old_interval := interval(unit)
	if not unit.has("statuses"): unit.statuses = {}
	var statuses: Dictionary = unit.statuses
	var previous: Dictionary = statuses.get(id, {})
	unit.status_revision = int(unit.get("status_revision", 0)) + 1
	statuses[id] = {
		"layers": mini(int(CAPS.get(id, 1)), int(previous.get("layers", 0)) + stacks),
		"duration": maxi(duration, int(previous.get("duration", 0))),
		"revision": unit.status_revision
	}
	if id == "harmony":
		for negative in NEGATIVE: statuses.erase(negative)
	var remaining := int(unit.next_action) - now
	var new_interval := interval(unit)
	if remaining > 0 and old_interval != new_interval:
		unit.next_action = now + ceili(float(remaining * new_interval) / old_interval)
	return true

static func consume(unit: Dictionary, id: String) -> void:
	if layers(unit, id) <= 0: return
	unit.statuses[id].layers -= 1
	if layers(unit, id) == 0: unit.statuses.erase(id)

static func restore(unit: Dictionary, hp: int, mp: int) -> void:
	unit.hp = mini(unit.max_hp, int(unit.hp) + hp / (2 if layers(unit, "wound") > 0 else 1))
	unit.mp = mini(unit.max_mp, int(unit.mp) + mp / (2 if layers(unit, "internal_wound") > 0 else 1))

static func lose_hp(unit: Dictionary, amount: int) -> int:
	var lost := mini(int(unit.hp), maxi(0, amount))
	unit.hp -= lost
	unit.alive = unit.hp > 0
	if lost > 0: unit.took_damage = true
	return lost

static func begin(unit: Dictionary, log_entries: Array) -> void:
	unit.action_number = int(unit.get("action_number", 0)) + 1
	unit.used_skills = []
	unit.turn_statuses = {}
	unit.swift_boost = false
	unit.swift_focus = false
	unit.bonus_attack = false
	unit.skipped_turn = false
	for id in unit.get("statuses", {}):
		unit.turn_statuses[id] = unit.statuses[id].revision
	if layers(unit, "poison") > 0:
		var percent := scaled(unit, "poison", 5, 2)
		var lost := lose_hp(unit, maxi(1, int(unit.hp) * percent / 100))
		log_entries.append("%s毒发，损失%d气血" % [unit.name, lost])
	if not unit.alive: return
	var old_hp: int = unit.hp
	var old_mp: int = unit.mp
	unit.mp = maxi(0, int(unit.mp) - int(unit.max_mp) * scaled(unit, "chill", 5, 2) / 100)
	if unit.mp < old_mp: log_entries.append("%s寒冷，损失%d内力" % [unit.name, old_mp - unit.mp])
	old_mp = unit.mp
	restore(unit, int(unit.max_hp) * layers(unit, "heal_regen") * 5 / 100, int(unit.max_mp) * layers(unit, "mana_regen") * 5 / 100)
	if unit.hp != old_hp or unit.mp != old_mp:
		log_entries.append("%s恢复%d气血、%d内力" % [unit.name, unit.hp - old_hp, unit.mp - old_mp])
	if layers(unit, "stun") > 0:
		unit.skipped_turn = true
		unit.stun_recovery = true
		log_entries.append("%s晕眩，跳过行动" % unit.name)
	elif unit.get("passive", "") == "swift" and unit.action_number > 1 and not unit.get("took_damage", false):
		unit.swift_boost = true
		unit.swift_focus = true
		log_entries.append("%s触发无伤心法" % unit.name)

static func finish(unit: Dictionary, now: int) -> void:
	var statuses: Dictionary = unit.get("statuses", {})
	unit.swift_boost = false
	unit.swift_focus = false
	for id in unit.get("turn_statuses", {}):
		if statuses.get(id, {}).get("revision", -1) != unit.turn_statuses[id]: continue
		statuses[id].duration -= 1
		if statuses[id].duration <= 0: statuses.erase(id)
	if not unit.get("skipped_turn", false): unit.stun_recovery = false
	unit.took_damage = false
	unit.bonus_attack = false
	unit.next_action = now + interval(unit)

static func cooldown(unit: Dictionary, name: String) -> int:
	return maxi(0, int(unit.get("cooldowns", {}).get(name, 0)) - int(unit.get("action_number", 0)))

static func cast_mode(skill: Dictionary) -> String:
	return str(skill.get("target_mode", "direction" if skill.get("shape") in ["line", "fan"] else "tile"))

static func cast_text(skill: Dictionary) -> String:
	return "相邻格定方向" if cast_mode(skill) == "direction" else "%d格内选格" % int(skill.get("range", 0))

static func hit_text(skill: Dictionary) -> String:
	match skill.get("shape", "single"):
		"line": return "前方直线%d格" % int(skill.get("reach", skill.range))
		"fan": return "前方%d排，每排3格" % int(skill.get("reach", 2))
		"cross": return "十字%d格" % (1 + 4 * int(skill.get("reach", 2)))
	return "单体"

static func can_use(unit: Dictionary, name: String, skill: Dictionary) -> bool:
	return unit.mp >= skill.cost and cooldown(unit, name) == 0 and not unit.get("used_skills", []).has(name)

static func spend(unit: Dictionary, name: String, skill: Dictionary) -> void:
	unit.mp -= skill.cost
	if not unit.has("cooldowns"): unit.cooldowns = {}
	if not unit.has("used_skills"): unit.used_skills = []
	unit.cooldowns[name] = int(unit.get("action_number", 0)) + int(skill.get("cooldown", 0))
	unit.used_skills.append(name)

static func attack(unit: Dictionary) -> float:
	var attack_stacks := layers(unit, "attack_up")
	if unit.get("swift_boost", false): attack_stacks = mini(5, attack_stacks + 3)
	var boost := 20 + 5 * (attack_stacks - 1) if attack_stacks > 0 else 0
	var percent := 100 + boost - scaled(unit, "attack_down", 20, 5)
	if layers(unit, "guard") > 0: percent -= 30
	return float(unit.attack) * maxf(0.0, percent / 100.0)

static func defense(unit: Dictionary) -> float:
	var percent := 100 + scaled(unit, "defense_up", 20, 5) - scaled(unit, "defense_down", 20, 5)
	if layers(unit, "guard") > 0: percent += 50
	return float(unit.defense) * maxf(0.0, percent / 100.0)

static func focused(unit: Dictionary) -> bool:
	return unit.get("swift_focus", false) or layers(unit, "focus") > 0

static func consume_focus(unit: Dictionary) -> void:
	if unit.get("swift_focus", false): unit.swift_focus = false
	else: consume(unit, "focus")

static func hit_chance(target: Dictionary, focused: bool, accuracy: float = 90.0) -> float:
	var aim := accuracy + (50.0 if focused else 0.0)
	var dodge := 50.0 if layers(target, "evasion") > 0 else 0.0
	return clampf(aim - dodge, 10.0, 100.0)

static func impact(source: Dictionary, target: Dictionary, power: float, critical: bool, spent_mp: int = 0) -> Dictionary:
	var berserk := layers(source, "berserk") > 0
	var multiplier := float(source.get("crit_damage", 150)) / 100.0 + (0.3 if berserk else 0.0)
	var damage := power * (multiplier if critical else 1.0)
	if source.get("passive", "") == "inner":
		var capacity := maxi(1, maxi(int(source.max_mp), int(target.max_mp)))
		damage += power * clampf(float(source.mp - spent_mp - target.mp) / capacity * 0.5, 0.0, 0.25)
	damage *= 100.0 / (100.0 + defense(target))
	if layers(source, "fury") > 0: damage *= 1.3
	if layers(target, "fury") > 0: damage *= 1.2
	if layers(target, "harmony") > 0: damage *= 0.5
	var reflection := floori(damage * 0.5) if target.get("passive", "") == "reflect" else 0
	if target.get("passive", "") == "reflect": damage *= 0.7
	var incoming := maxi(1, floori(damage))
	var blocked := 0
	if target.get("passive", "") == "inner":
		blocked = mini(int(target.mp), incoming * 60 / 100)
	return {"hp":mini(int(target.hp), incoming - blocked), "mp":blocked, "reflect":reflection}

static func strike(source: Dictionary, target: Dictionary, power: float, focused: bool, hostile: bool, log_entries: Array, accuracy: float = 90.0) -> int:
	var roll := randf() * 100.0
	if roll >= hit_chance(target, focused, accuracy):
		if layers(target, "evasion") > 0 and roll < minf(100.0, accuracy + (50.0 if focused else 0.0)):
			consume(target, "evasion")
		log_entries.append("%s未命中%s" % [source.name, target.name])
		return 0
	var critical := layers(source, "berserk") > 0 or randf() * 100.0 < clampf(float(source.get("crit", 0)) + (50.0 if focused else 0.0), 0.0, 85.0)
	var result := impact(source, target, power, critical)
	var blocked: int = result.mp
	if blocked > 0:
		target.mp -= blocked
		log_entries.append("%s消耗%d内力抵挡伤害" % [target.name, blocked])
	var lost := lose_hp(target, result.hp)
	log_entries.append("%s%s对%s造成%d点伤害" % ["暴击！" if critical else "", source.name, target.name, lost])
	if hostile and result.reflect > 0 and source.alive:
		var reflected := lose_hp(source, result.reflect)
		log_entries.append("%s反伤，%s损失%d气血" % [target.name, source.name, reflected])
	return lost

static func status_label(name: String, level: int, rounds: int) -> String:
	return "%s%d级（%d回合）" % [name, level, rounds]

static func martial_effect_label(effect: Array) -> String:
	return status_label(LABELS[effect[1]], effect[2], effect[3]) + ("（敌）" if effect[0] == "hit" else "（我）")

static func highlight_status(value: String) -> String:
	return "[color=#%s]%s[/color]" % [STATUS_COLOR.to_html(false), value]

static func status_text(unit: Dictionary, separator: String = " · ") -> String:
	var names: Array[String] = []
	for id in unit.get("statuses", {}):
		var state: Dictionary = unit.statuses[id]
		names.append(status_label(LABELS[id], state.layers, state.duration))
	if unit.get("swift_boost", false): names.append(status_label("无伤攻势", 3, 1))
	if unit.get("swift_focus", false) and layers(unit, "focus") == 0: names.append(status_label("凝神", 1, 1))
	if unit.get("poison_turns", 0) > 0 and layers(unit, "poison") == 0:
		names.append(status_label("中毒", 1, unit.poison_turns))
	return separator.join(names)
