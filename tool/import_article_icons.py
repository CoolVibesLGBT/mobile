import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

source = Path(sys.argv[1] if len(sys.argv) > 1 else '/Users/ersanyakit/Downloads/Telegram-iOS-master')
root = Path(__file__).resolve().parents[1]
catalog = source / 'submodules/TelegramUI/Images.xcassets'
icons = {
    'add': 'Chat/Context Menu/Add',
    'list': 'RichText/ToolList',
    'table': 'RichText/ToolTable',
    'attach': 'RichText/ToolAttach',
    'emoji': 'RichText/ToolEmoji',
    'bold': 'RichText/ToolBold',
    'italic': 'RichText/ToolItalic',
    'strike': 'RichText/ToolStrike',
    'underline': 'RichText/ToolUnderline',
    'spoiler': 'RichText/ToolSpoiler',
    'link': 'RichText/ToolLink',
    'quote': 'RichText/ToolQuote',
    'send': 'Chat/Input/Text/SendIcon',
    'close': 'Navigation/Close',
    'undo': 'Media Editor/Undo',
    'redo': 'Media Editor/Redo',
    'keyboard': 'Media Editor/Close',
    'heading': 'Chat/Context Menu/FormatHeading',
    **{f'h{i}': f'Chat/Context Menu/FormatHeading{i}' for i in range(1, 7)},
    'text': 'Chat/Context Menu/FormatText',
    'bullet': 'Chat/Context Menu/FormatBulletList',
    'number': 'Chat/Context Menu/FormatNumberList',
    'checklist': 'Chat/Context Menu/FormatChecklist',
    'blockquote': 'Chat/Context Menu/FormatQuote',
    'code': 'Chat/Context Menu/FormatCode',
}
out = root / 'assets/images/article'
out.mkdir(parents=True, exist_ok=True)
manifest = {}
for name, relative in icons.items():
    folder = catalog / f'{relative}.imageset'
    entries = json.loads((folder / 'Contents.json').read_text())['images']
    pdf = folder / next(entry['filename'] for entry in entries if entry.get('filename', '').endswith('.pdf'))
    target = out / f'{name}.svg'
    subprocess.run(['pdftocairo', '-svg', str(pdf), str(target)], check=True)
    svg = ET.parse(target).getroot()
    box = [float(value) for value in svg.attrib['viewBox'].split()]
    manifest[name] = {'source': str(pdf.relative_to(source)), 'sha256': hashlib.sha256(pdf.read_bytes()).hexdigest(), 'width': box[2], 'height': box[3]}
    print(f'{name}: {box[2]:g} × {box[3]:g}')
(out / 'sources.json').write_text(json.dumps(manifest, indent=2) + '\n')
