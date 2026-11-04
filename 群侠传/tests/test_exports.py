"""Reject configuration changes that previously produced broken runtime data."""
import copy
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
import export_config
import export_story


class ExportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tables = {name: export_config.workbook(name) for name in ["武学", "心法", "装备", "人物属性", "成长规则", "物品"]}

    def reject(self, table, mutate):
        tables = copy.deepcopy(self.tables)
        mutate(tables[table])
        with patch.object(export_config, "workbook", side_effect=tables.__getitem__):
            with self.assertRaises(ValueError):
                export_config.export()

    def test_formula_matches_its_rule(self):
        self.reject("成长规则", lambda rows: rows[1].update(当前值="5×人物悟性"))

    def test_duplicate_stable_id(self):
        self.reject("装备", lambda rows: rows[1].update(装备ID=rows[0]["装备ID"]))

    def test_orphan_skill_level(self):
        self.reject("人物属性", lambda rows: rows[0].update(武学等级=rows[0]["武学等级"] + "|不存在:1"))

    def test_impossible_probability(self):
        self.reject("装备", lambda rows: rows[0].update(暴击率="101"))

    def test_inconsistent_internal_growth(self):
        self.reject("心法", lambda rows: rows[0].update(每级经验需求="等级×999"))

    def test_missing_asset(self):
        self.reject("武学", lambda rows: rows[0].update(图标资源="res://assets/does-not-exist.png"))

    def test_unknown_book_skill_id(self):
        self.reject("物品", lambda rows: rows[-1].update(技能ID="skill_missing"))

    def test_sell_price_exceeds_buy_price(self):
        self.reject("物品", lambda rows: rows[0].update(卖价="999999"))

    def test_medicine_effect_on_equipment(self):
        self.reject("物品", lambda rows: rows[0].update(恢复气血="30"))

    def test_story_covers_twelve_chapters(self):
        data = export_story.export()
        self.assertEqual({node["chapter"] for node in data["nodes"]}, set(range(1, 13)))
        self.assertEqual(len(data["nodes"]), 25)
        self.assertEqual(len(data["locations"]), 17)

    def test_story_rejects_invalid_location(self):
        data = export_story.export()
        data["nodes"][0]["location"] = "missing"
        with patch.object(export_story.json, "loads", return_value=data):
            with self.assertRaises(ValueError):
                export_story.export()

    def test_story_rejects_missing_parent_region(self):
        data = export_story.export()
        data["locations"][0]["parent"] = "missing_region"
        with patch.object(export_story.json, "loads", return_value=data):
            with self.assertRaisesRegex(ValueError, "invalid parent region"):
                export_story.export()

    def test_region_ids_cannot_shadow_locations(self):
        data = export_story.export()
        data["regions"][0]["id"] = data["locations"][0]["id"]
        with patch.object(export_story.json, "loads", return_value=data):
            with self.assertRaisesRegex(ValueError, "duplicate map region ID"):
                export_story.export()

    def test_complete_source_is_bound_once(self):
        data = export_story.export()
        self.assertGreater(data["source_coverage"]["records"], 400)
        self.assertEqual(data["source_coverage"]["bound"], data["source_coverage"]["records"])
        self.assertTrue(any("代爹跟你结为八拜之交" in line[1] for line in data["dialogues"]["tavern_after"]["lines"]))
        self.assertTrue(any("花露的香味经久不散" in line[1] for line in data["dialogues"]["yanzi"]["lines"]))
        self.assertTrue(any("忽必烈" in line[1] for line in data["dialogues"]["yamen"]["lines"]))
        self.assertTrue(any("我是胡一刀的妻子" in line[1] for line in data["dialogues"]["rebirth"]["lines"]))

    def test_missing_source_span_cannot_silently_drop_dialogue(self):
        data = export_story.export()
        data["nodes"][0]["source_span"]["start"] = 1
        with patch.object(export_story.json, "loads", return_value=data):
            with self.assertRaisesRegex(ValueError, "unbound source records"):
                export_story.export()

    def test_story_has_no_six_meridians_reward(self):
        data = export_story.export()
        self.assertEqual(data["encounters"]["tianlong"]["count"], 6)
        self.assertTrue(any("向来不传外人" in line[1] for line in data["dialogues"]["six_monks_after"]["lines"]))


if __name__ == "__main__":
    unittest.main()
