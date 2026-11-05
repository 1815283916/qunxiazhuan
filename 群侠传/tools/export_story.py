"""Validate and export the adaptation of 剧情.txt into the playable story catalog."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from story_source import compile_dialogues

ROOT = Path(__file__).resolve().parents[1]


def export():
    source = ROOT.parent / '剧情.txt'
    if not source.is_file():
        source = ROOT.parent.parent / '剧情.txt'
    original = source.read_text(encoding='utf-8-sig')
    chapters = set(re.findall(r'场景\s*(\d{2})', original))
    if not {f'{i:02}' for i in range(1, 13)} <= chapters:
        raise ValueError('剧情.txt must contain all twelve source scenes')
    data = json.loads((ROOT / '配置表' / '剧情配置.json').read_text(encoding='utf-8'))
    data = compile_dialogues(data, original)
    locations = {loc['id']: loc for loc in data['locations']}
    ids = [node['id'] for node in data['nodes']]
    if len(locations) != len(data['locations']) or len(set(ids)) != len(ids):
        raise ValueError('duplicate location or story node')
    triggers = data['story_triggers']
    if set(triggers) != set(ids) or any(not isinstance(name, str) or not name.strip() for name in triggers.values()):
        raise ValueError('each story node must have a named interaction')
    for node in data['nodes']:
        if node['location'] not in locations or not 1 <= node['chapter'] <= 12:
            raise ValueError(f'invalid node: {node["id"]}')
        lines = data['dialogues'][node['id']]['lines']
        if not lines or any(len(line) != 2 or not all(line) for line in lines):
            raise ValueError(f'invalid dialogue: {node["id"]}')
        if node.get('battle') and node['battle'] not in data['encounters']:
            raise ValueError(f'unknown encounter: {node["id"]}')
        for hero in node.get('join', []) + node.get('leave', []):
            if not isinstance(hero, int) or not 0 <= hero < len(data['profiles']):
                raise ValueError('invalid story companion')
    for record in list(locations.values()) + list(data['encounters'].values()):
        if not (ROOT / record['background'].removeprefix('res://')).is_file():
            raise ValueError(f'missing background: {record["background"]}')
    for path in [data['world_map']['background'], *data.get('portraits', {}).values()]:
        if not (ROOT / path.removeprefix('res://')).is_file():
            raise ValueError(f'missing story artwork: {path}')
    regions = {region['id']: region for region in data['regions']}
    if len(regions) != len(data['regions']) or set(regions) & set(locations):
        raise ValueError('duplicate map region ID')
    for place in locations.values():
        if place['parent'] not in regions or not place.get('local_name'):
            raise ValueError(f'invalid parent region: {place["id"]}')
    for region in regions.values():
        if not any(place['parent'] == region['id'] for place in locations.values()):
            raise ValueError(f'empty region: {region["id"]}')
        if not (ROOT / region['background'].removeprefix('res://')).is_file():
            raise ValueError(f'missing region background: {region["id"]}')
        coords = region['map_position']
        width, height = data['world_map']['marker_size']
        if len(coords) != 2 or not 0 <= coords[0] <= 1600 - width or not 76 <= coords[1] <= 800 - height:
            raise ValueError(f'invalid map position: {region["id"]}')
    base = json.loads((ROOT / 'data' / 'configuration.json').read_text(encoding='utf-8'))
    if data.get('skills') or data.get('items'):
        raise ValueError('configure skills and items in the design workbooks')
    skills = base['skills']
    items = base['items']
    for encounter in data['encounters'].values():
        martial = encounter.get('martial', [])
        if (not isinstance(martial, list) or not 1 <= len(martial) <= 4
                or any(not isinstance(name, str) for name in martial) or len(set(martial)) != len(martial)):
            raise ValueError(f'invalid enemy martial loadout: {encounter["id"]}')
        if any(skills.get(name, {}).get('kind') != '武学' for name in martial):
            raise ValueError(f'unknown enemy martial skill: {encounter["id"]}')
        power = encounter.get('skill_power_percent', 100)
        if type(power) is not int or not 1 <= power <= 100:
            raise ValueError(f'invalid enemy skill power: {encounter["id"]}')
    for profile in data['profiles']:
        head = profile['head'] + ('' if '.' in profile['head'] else '.png')
        if not (ROOT / 'assets' / 'Heads' / head).is_file():
            raise ValueError(f'missing portrait: {head}')
    for catalog in [skills, items]:
        stable_ids = [record['id'] for record in catalog.values()]
        if len(stable_ids) != len(set(stable_ids)):
            raise ValueError('duplicate narrative configuration ID')
        for record in catalog.values():
            if not (ROOT / record['icon'].removeprefix('res://')).is_file():
                raise ValueError('missing narrative icon')
    for name in data['initial']['inventory']:
        if name not in items:
            raise ValueError(f'unknown initial item: {name}')
    for name in data['initial']['skills']['learned']:
        if name not in skills:
            raise ValueError(f'unknown initial skill: {name}')
    for node in data['nodes']:
        for name in node.get('items', []):
            if name not in items:
                raise ValueError(f'unknown reward item: {name}')
    if set(data['dialogues']) != set(ids):
        raise ValueError('orphan dialogue')
    if {node['chapter'] for node in data['nodes']} != set(range(1, 13)):
        raise ValueError('adaptation must cover all twelve chapters')
    data['source_sha256'] = hashlib.sha256(source.read_bytes()).hexdigest()
    return data


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    try:
        content = json.dumps(export(), ensure_ascii=False, indent=2) + '\n'
        target = ROOT / 'data' / 'story.json'
        if args.check:
            if not target.is_file() or target.read_text(encoding='utf-8') != content:
                raise ValueError('story export is out of date; run tools/export_story.py')
        else:
            target.write_text(content, encoding='utf-8', newline='\n')
        print('Story validated' if args.check else 'Story exported')
    except (ValueError, KeyError, OSError) as error:
        print(f'Story error: {error}', file=sys.stderr)
        sys.exit(1)
