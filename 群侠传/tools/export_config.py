"""Validate the five design workbooks and export runtime JSON. Python stdlib only."""
import argparse
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def workbook(name):
    with zipfile.ZipFile(ROOT / "配置表" / (name + ".xlsx")) as book:
        shared = []
        if "xl/sharedStrings.xml" in book.namelist():
            shared = ["".join(t.text or "" for t in row.findall(".//m:t", NS))
                      for row in ET.fromstring(book.read("xl/sharedStrings.xml"))]
        sheet = ET.fromstring(book.read("xl/worksheets/sheet1.xml"))
        rows = []
        for row in sheet.find("m:sheetData", NS):
            values = {}
            for cell in row:
                column = 0
                for letter in re.match(r"[A-Z]+", cell.attrib["r"])[0]:
                    column = column * 26 + ord(letter) - 64
                value = cell.find("m:v", NS)
                if cell.get("t") == "inlineStr":
                    text = "".join(t.text or "" for t in cell.findall(".//m:t", NS))
                elif cell.get("t") == "s":
                    text = shared[int(value.text)]
                else:
                    text = value.text if value is not None else ""
                values[column - 1] = text.strip()
            if values:
                rows.append([values.get(i, "") for i in range(max(values) + 1)])
        headers = rows[0]
        result = [dict(zip(headers, row + [""] * (len(headers) - len(row)))) for row in rows[1:] if row[0]]
        id_key = headers[0]
        ids = [row[id_key] for row in result]
        if len(set(ids)) != len(ids):
            raise ValueError(f"{name}: duplicate ID")
        return result


def integer(value):
    number = int(value)
    if number < 0:
        raise ValueError(f"negative value: {value}")
    return number


def resource(path, directory=False, sequence=True):
    if not path.startswith("res://") or ".." in Path(path[6:]).parts:
        raise ValueError(f"invalid resource path: {path}")
    target = ROOT / path[6:]
    if not target.resolve().is_relative_to(ROOT.resolve()):
        raise ValueError(f"resource escapes project: {path}")
    if not (target.is_dir() if directory else target.is_file()):
        raise ValueError(f"missing resource: {path}")
    if directory and sequence and not any((target / filename).is_file() for filename in ["1.png", "01.png"]):
        raise ValueError(f"missing effect frames: {path}")
    return path


def insert(library, name, data):
    if name in library:
        raise ValueError(f"duplicate name: {name}")
    library[name] = data


STATUS_IDS = set(
    "wound internal_wound combo evasion poison paralysis chill focus fury haste root stun "
    "blind attack_up defense_up attack_down defense_down harmony mana_regen heal_regen berserk guard".split()
)

MARTIAL_GEOMETRY = {
    "剑系": ("方向", "line", 1, 4),
    "刀法": ("方向", "fan", 1, 2),
    "拳掌": ("选格", "single", 3, 0),
    "奇门": ("选格", "cross", 2, 2),
}
MARTIAL_COOLDOWN = 2


def skill_effects(value):
    effects = []
    for entry in filter(None, value.split(";")):
        phase, status, stacks, duration = (part.strip() for part in entry.split("|"))
        if phase not in {"self", "hit", "self_on_hit"} or status not in STATUS_IDS:
            raise ValueError(f"unknown status or trigger: {entry}")
        stacks, duration = integer(stacks), integer(duration)
        if stacks < 1 or duration < 1:
            raise ValueError(f"status stacks and duration must be positive: {entry}")
        effects.append([phase, status, stacks, duration])
    return effects


def export():
    skills, equipment = {}, {}
    internals = workbook("心法")
    for row in workbook("武学"):
        school = row["类型"]
        if school not in MARTIAL_GEOMETRY:
            raise ValueError(f"unknown martial school: {row['名称']} / {school}")
        mode, shape, distance, reach = MARTIAL_GEOMETRY[school]
        configured_geometry = (row["施展方式"], row["形状代码"], integer(row["释放范围"]), integer(row["命中深度"]))
        if configured_geometry != (mode, shape, distance, reach):
            raise ValueError(f"attack geometry must match its martial school: {row['名称']}")
        if integer(row["冷却"]) != MARTIAL_COOLDOWN:
            raise ValueError(f"cooldown must match the shared martial template: {row['名称']}")
        damage = integer(row["基础威力"])
        if damage < 1:
            raise ValueError(f"martial skill must have positive damage: {row['名称']}")
        effect_path = row["武学特效资源"]
        insert(skills, row["名称"], {
            "id": row["武学ID"], "kind": "武学", "school": school,
            "cost": integer(row["消耗内力"]), "damage": damage, "damage_growth": integer(row["威力成长"]),
            "range": distance, "shape": shape, "pattern": row["范围说明"],
            "target_mode": "direction" if mode == "方向" else "tile", "reach": reach,
            "cooldown": MARTIAL_COOLDOWN, "effects": skill_effects(row["状态效果"]),
            "icon": resource(row["图标资源"]), "effect": resource(effect_path, True) if effect_path else "", "description": row["描述"],
        })
    for row in internals:
        if row["类型"] != "心法":
            raise ValueError(f"invalid internal skill kind: {row['名称']}")
        if row["战斗被动"] not in {"", "swift", "reflect", "inner"}:
            raise ValueError(f"unknown internal passive: {row['名称']}")
        insert(skills, row["名称"], {
            "id": row["心法ID"], "kind": row["类型"], "school": row["门派"],
            "attack_bonus": integer(row["每级攻击加成"]), "defense_bonus": integer(row["每级防御加成"]),
            "passive": row["战斗被动"],
            "icon": resource(row["图标资源"]), "description": row["描述"],
        })
    equipment_labels = ["攻击", "防御", "生命上限", "速度", "暴击率", "暴击伤害", "中毒概率", "身法", "福缘", "定力", "拳掌", "剑法", "刀法", "奇门"]
    equipment_keys = ["attack", "defense", "hp", "speed", "crit", "crit_damage", "poison", "agility", "luck", "willpower", "fist", "sword", "blade", "unorthodox"]
    for row in workbook("装备"):
        if row["装备槽"] not in ["weapon", "armor", "accessory"]:
            raise ValueError(f"unknown equipment slot: {row['装备槽']}")
        if any(integer(row[label]) > 100 for label in ["暴击率", "中毒概率"]):
            raise ValueError(f"probability exceeds 100: {row['名称']}")
        insert(equipment, row["名称"], {"id": row["装备ID"], "slot": row["装备槽"], "icon": resource(row["图标资源"]),
                                     **{key: integer(row[label]) for key, label in zip(equipment_keys, equipment_labels)}})
    growth_rows = {r["规则ID"]: r["当前值"] for r in workbook("成长规则")}
    growth = {}
    rule_patterns = {
        "hero_level_cap": r"\d+", "skill_level_cap": r"\d+",
        "hero_level_attack": r"\d+", "hero_level_speed": r"\d+", "hero_level_defense": r"\d+",
        "hero_level_exp": r"当前等级×\d+", "skill_level_exp": r"当前等级×\d+",
        "battle_skill_exp": r"\d+×人物悟性", "battle_internal_exp": r"\d+×人物悟性",
    }
    if set(growth_rows) != set(rule_patterns):
        raise ValueError("missing or unknown growth rule IDs")
    for key, value in growth_rows.items():
        if not re.fullmatch(rule_patterns[key], value):
            raise ValueError(f"unsupported growth expression: {key} = {value}")
        numbers = re.findall(r"\d+", value)
        if len(numbers) != 1:
            raise ValueError(f"unsupported growth rule: {key} = {value}")
        growth[key] = int(numbers[0])
        if growth[key] <= 0:
            raise ValueError(f"growth value must be positive: {key}")
    for row in internals:
        if integer(row["最高等级"]) != growth["skill_level_cap"] or row["每级经验需求"] not in [f"等级×{growth['skill_level_exp']}", f"当前等级×{growth['skill_level_exp']}"]:
            raise ValueError(f"internal progression disagrees with growth table: {row['名称']}")
    heroes, stats, loadouts = [], [], []
    for row in workbook("人物属性"):
        level = integer(row["初始等级"])
        if not 1 <= level <= growth["hero_level_cap"]:
            raise ValueError(f"invalid hero level: {row['姓名']}")
        talent_id = row["天赋ID"]
        talent_name = row["天赋名称"]
        talent_description = row["天赋说明"]
        talent_attack = integer(row["战斗攻击加成%"])
        if not re.fullmatch(r"[a-z][a-z0-9_]*", talent_id) or not talent_name or not talent_description:
            raise ValueError(f"invalid talent configuration: {row['姓名']}")
        if not 0 <= talent_attack <= 100:
            raise ValueError(f"invalid battle attack talent bonus: {row['姓名']}")
        heroes.append({"id": row["人物ID"], "name": row["姓名"], "head": resource(row["头像资源"]),
                       "model": resource(row["战斗模型资源"], directory=True, sequence=False),
                       "level": level, "exp": 0, "attack": integer(row["基础攻击"]), "speed": integer(row["基础身法"]), "defense": integer(row["基础防御"]),
                       "talent": {"id": talent_id, "name": talent_name, "description": talent_description,
                                  "battle_attack_percent": talent_attack}})
        stat_keys = ["strength", "agility", "insight", "luck", "constitution", "willpower", "fist", "sword", "blade", "unorthodox"]
        stat_labels = ["臂力", "身法属性", "悟性", "福缘", "根骨", "定力", "拳掌", "剑法", "刀法", "奇门"]
        stats.append({key: integer(row[label]) for key, label in zip(stat_keys, stat_labels)})
        martial = [s for s in row["初始武学"].split("|") if s]
        if len(set(martial)) != len(martial) or len(martial) > 4:
            raise ValueError(f"invalid martial loadout: {row['姓名']}")
        internal = row["初始心法"]
        levels = {}
        for item in filter(None, row["武学等级"].split("|")):
            name, value = item.rsplit(":", 1)
            levels[name] = integer(value)
        levels[internal] = integer(row["心法等级"])
        if any(name not in skills or skills[name]["kind"] != "武学" for name in martial):
            raise ValueError(f"unknown martial reference: {row['姓名']}")
        if internal not in skills or skills[internal]["kind"] != "心法":
            raise ValueError(f"unknown internal reference: {row['姓名']}")
        for name in martial + [internal]:
            if not 1 <= levels.get(name, 0) <= growth["skill_level_cap"]:
                raise ValueError(f"invalid skill level: {row['姓名']} / {name}")
        if set(levels) != set(martial + [internal]):
            raise ValueError(f"orphan skill level reference: {row['姓名']}")
        loadouts.append({"martial": martial, "internal": internal, "levels": levels, "exp": {}})
    if len(heroes) != 6:
        raise ValueError("the current roster UI requires exactly six heroes")
    all_ids = [v["id"] for v in [*heroes, *skills.values(), *equipment.values()]]
    if len(all_ids) != len(set(all_ids)):
        raise ValueError("IDs must be unique across all tables")
    if any(not re.fullmatch(r"[a-z][a-z0-9_]*", id) for id in all_ids):
        raise ValueError("IDs must be nonempty lowercase identifiers")
    items = {}
    skill_ids = {skill["id"] for skill in skills.values()}
    item_ids = set()
    for row in workbook("物品"):
        name, item_id, kind = row["名称"], row["物品ID"], row["分类"]
        if item_id in item_ids or not re.fullmatch(r"[a-z][a-z0-9_]*", item_id):
            raise ValueError(f"invalid or duplicate item ID: {item_id}")
        item_ids.add(item_id)
        if kind not in ["装备", "秘籍", "药品", "任务品"]:
            raise ValueError(f"unknown item category: {name}")
        buy, sell, shop = integer(row["买价"]), integer(row["卖价"]), integer(row["商店出售"])
        hp, mp = integer(row["恢复气血"]), integer(row["恢复内力"])
        if sell > buy or shop not in [0, 1]:
            raise ValueError(f"invalid item price or shop flag: {name}")
        if kind == "装备" and (name not in equipment or equipment[name]["id"] != item_id):
            raise ValueError(f"item equipment reference mismatch: {name}")
        if kind == "秘籍" and row["技能ID"] not in skill_ids:
            raise ValueError(f"unknown book skill reference: {name}")
        if kind != "秘籍" and row["技能ID"]:
            raise ValueError(f"unexpected skill reference: {name}")
        if kind == "药品" and hp + mp <= 0 or kind != "药品" and hp + mp > 0:
            raise ValueError(f"invalid medicine effects: {name}")
        insert(items, name, {"id":item_id, "kind":kind, "buy_price":buy, "sell_price":sell,
                            "shop":bool(shop), "icon":resource(row["图标资源"]), "skill_id":row["技能ID"],
                            "heal_hp":hp, "heal_mp":mp, "source":row["获取途径"], "description":row["描述"]})
    if not set(equipment).issubset(items):
        raise ValueError("equipment missing from item catalog")
    return {"heroes": heroes, "hero_stats": stats, "hero_skills": loadouts, "skills": skills, "equipment": equipment, "growth": growth, "items":items}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify generated JSON is up to date without writing")
    args = parser.parse_args()
    try:
        content = json.dumps(export(), ensure_ascii=False, indent=2) + "\n"
        target = ROOT / "data" / "configuration.json"
        if args.check:
            if not target.is_file() or target.read_text(encoding="utf-8") != content:
                raise ValueError("runtime configuration is out of date; run tools/export_config.py")
        else:
            target.parent.mkdir(exist_ok=True)
            temporary = target.with_suffix(".json.tmp")
            temporary.write_text(content, encoding="utf-8", newline="\n")
            temporary.replace(target)
        print("Configuration validated" if args.check else "Configuration exported")
    except (ValueError, KeyError, OSError, zipfile.BadZipFile) as error:
        print(f"Configuration error: {error}", file=sys.stderr)
        sys.exit(1)
