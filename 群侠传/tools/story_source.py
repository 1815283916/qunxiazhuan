"""Import the expanded twelve-scene script without paraphrasing its dialogue."""
import re


def read_expanded(text):
    starts = list(re.finditer(r'^场景01：', text, re.M))
    if not starts:
        raise ValueError('missing expanded source scene 01')
    start = starts[-1].start()
    chapter = 0
    chapters = {}
    for line_number, line in enumerate(text[start:].splitlines(), text[:start].count('\n') + 1):
        heading = re.match(r'场景(\d+)：', line)
        if heading:
            chapter = int(heading[1])
        match = re.match(r'【([^】]+)】(.*)', line)
        if match:
            chapters.setdefault(chapter, []).append({'speaker': match[1], 'text': match[2], 'line': line_number})
    if set(chapters) != set(range(1, 13)):
        raise ValueError('expanded source must contain twelve scenes')
    return chapters


def compile_dialogues(data, original):
    chapters = read_expanded(original)
    dialogues = dict(data.get('dialogues', {}))
    used = set()
    edits = data.get('source_edits', {})
    manifest = []
    for node in data['nodes']:
        if 'source_span' not in node:
            continue
        chapter = node['chapter']
        span = node['source_span']
        records = chapters[chapter]
        if not 0 <= span['start'] < span['stop'] <= len(records):
            raise ValueError(f'invalid source span: {node["id"]}')
        lines, source_lines = [], []
        for index in range(span['start'], span['stop']):
            key = f'{chapter}:{index}'
            if key in used:
                raise ValueError(f'duplicate source record: {key}')
            used.add(key)
            record = records[index]
            display = edits.get(key, record)
            if key in edits:
                if not edits[key].get('reason'):
                    raise ValueError(f'undocumented source edit: {key}')
                manifest.append({'record': key, 'line': record['line'], 'reason': edits[key]['reason']})
            lines.append([display['speaker'], display['text']])
            source_lines.append(record['line'])
        dialogues[node['id']] = {'lines': lines, 'source_lines': source_lines}
    expected = {f'{chapter}:{i}' for chapter, rows in chapters.items() for i in range(len(rows))}
    if used != expected:
        raise ValueError(f'unbound source records: {sorted(expected - used)}')
    if set(edits) - expected:
        raise ValueError('source edit refers to a nonexistent record')
    data['dialogues'] = dialogues
    data['source_coverage'] = {'records': len(expected), 'bound': len(used), 'adjusted': len(edits), 'chapters': 12, 'adjustments': manifest}
    return data
