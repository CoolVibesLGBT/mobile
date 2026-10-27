import gzip
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import urllib.error
import urllib.request


def main():
    token = os.environ.get('TELEGRAM_BOT_TOKEN')
    if not token and len(sys.argv) == 2:
        match = re.search(r'^TELEGRAM_BOT_TOKEN\s*=\s*(.+)$', Path(sys.argv[1]).read_text(), re.M)
        if match:
            token = match.group(1).strip().strip('\"\'')
    if not token:
        raise ValueError('Set TELEGRAM_BOT_TOKEN or supply the project env path')

    def api(method, data):
        request = urllib.request.Request(
            f'https://api.telegram.org/bot{token}/{method}',
            data=json.dumps(data).encode(),
            headers={'Content-Type': 'application/json'},
        )
        result = json.load(urllib.request.urlopen(request, timeout=20))
        if not result.get('ok'):
            raise ValueError('Telegram public asset request failed')
        return result['result']

    root = Path(__file__).resolve().parents[1]
    target = root / 'assets/animations/emoji_search'
    target.mkdir(parents=True, exist_ok=True)
    pack = api('getStickerSet', {'name': 'EmojiCategories'})
    names = ['love', 'like', 'dislike', 'party', 'laugh', 'surprised', 'sad', 'angry', 'neutral', 'thinking', 'playful']
    manifest = {'source': 'https://t.me/addemoji/EmojiCategories', 'icons': {}}
    for name, sticker in zip(names, pack['stickers']):
        if not sticker['is_animated']:
            raise ValueError('Expected original TGS artwork')
        file = api('getFile', {'file_id': sticker['file_id']})
        with urllib.request.urlopen(f'https://api.telegram.org/file/bot{token}/{file["file_path"]}', timeout=20) as response:
            compressed = response.read(2 * 1024 * 1024 + 1)
        if len(compressed) > 2 * 1024 * 1024:
            raise ValueError('Unexpected asset size')
        data = gzip.decompress(compressed)
        animation = json.loads(data)
        (target / f'{name}.json').write_bytes(data)
        manifest['icons'][name] = {
            'emoji': sticker.get('emoji', ''),
            'sha256': hashlib.sha256(data).hexdigest(),
            'width': animation['w'], 'height': animation['h'],
        }
        print(f'{name}: {len(data)} bytes')
    source = Path('/Users/ersanyakit/Downloads/Telegram-iOS-master')
    animations = source / 'submodules/TelegramUI/Resources/Animations'
    manifest['transitions'] = {}
    for name in ['emoji_search_to_arrow', 'emoji_arrow_to_search']:
        path = animations / f'{name}.tgs'
        data = gzip.decompress(path.read_bytes())
        (target / f'{name}.json').write_bytes(data)
        manifest['transitions'][name] = {
            'source': str(path.relative_to(source)),
            'sha256': hashlib.sha256(data).hexdigest(),
        }
    (target / 'sources.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    try:
        main()
    except urllib.error.HTTPError as error:
        sys.exit(f'Telegram asset request failed ({error.code})')
    except Exception as error:
        sys.exit(f'Emoji import failed: {type(error).__name__}')
