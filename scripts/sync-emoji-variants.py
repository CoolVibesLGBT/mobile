#!/usr/bin/env python3
"""Merge skin-tone sequences from the supplied Telegram iOS emoji1.txt."""
import json
import re
import sys
from pathlib import Path
source = Path(sys.argv[1])
target = Path(__file__).resolve().parent.parent / 'assets/data/telegram-emoji.json'
data = json.loads(target.read_text())
canonical = lambda text: text.replace('\ufe0f', '')
def untoned(text):
    return canonical(''.join(c for c in text if not 0x1f3fb <= ord(c) <= 0x1f3ff))
aliases = {'🫱\u200d🫲': '🤝', '👩\u200d🤝\u200d👨': '👫',
    '👩\u200d🤝\u200d👩': '👭', '👨\u200d🤝\u200d👨': '👬',
    '🧑\u200d❤\u200d🧑': '💑', '🧑\u200d❤\u200d💋\u200d🧑': '💏'}
entries = {canonical(e['emoji']): e for e in data['entries']}
existing = {canonical(v) for e in data['entries'] for v in [e['emoji'], *e.get('tones', [])]}
added = 0
for variant in re.findall(r'"([^"\n]+)"', source.read_text()):
    if canonical(variant) in existing:
        continue
    base = untoned(variant)
    entry = entries.get(aliases.get(base, base))
    if entry is None:
        raise ValueError(f'Unmapped Telegram emoji: {variant}')
    entry.setdefault('tones', []).append(variant)
    existing.add(canonical(variant))
    added += 1
data['variantSource'] = 'Telegram-iOS/submodules/TelegramUI/Resources/emoji1.txt'
target.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')
print(f'Added {added} variants; {len(existing)} unique emoji sequences')
