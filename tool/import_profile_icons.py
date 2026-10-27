import json
import shutil
from pathlib import Path

project = Path(__file__).resolve().parents[1]
web = project.parent / 'web'
catalog = json.loads((web / 'src/features/illustrations/icon-catalog.json').read_text())
groups = {'system', 'attributes', 'interest-categories', 'interests', 'fantasy-categories', 'fantasies'}
target = project / 'assets/images/profile_icons'
target.mkdir(parents=True, exist_ok=True)
aliases = {}
for icon in catalog:
    if icon['group'] not in groups:
        continue
    key = icon['key']
    shutil.copyfile(web / f'public/images/icons/dott/{key}.avif', target / f'{key}.avif')
    for alias in [key, *icon['aliases']]:
        aliases[alias.strip().lower().replace('_', '-')] = key
lines = ['// Generated from the web Dott catalog by tool/import_profile_icons.py.',
         'const illustratedIconAliases = <String, String>{']
for alias, key in sorted(aliases.items()):
    lines.append(f'  {json.dumps(alias, ensure_ascii=False)}: {json.dumps(key)},')
lines.append('};\n')
(project / 'lib/design/illustrated_icon_catalog.dart').write_text('\n'.join(lines))
labels = {}
for language in ['en', 'tr', 'ar']:
    profile = json.loads((web / f'src/locales/{language}/common.json').read_text())['profile']
    labels[language] = {
        icon['key'].removeprefix('attribute-'): profile.get(
            {'education': 'education_level', 'kids_preference': 'kids'}.get(
                icon['key'].removeprefix('attribute-'), icon['key'].removeprefix('attribute-')
            ), icon['label']
        ) for icon in catalog if icon['group'] == 'attributes'
    }
(project / 'lib/design/profile_preference_labels.dart').write_text(
    '// Generated from the web profile translations by tool/import_profile_icons.py.\n'
    'const profileAttributeLabels = <String, Map<String, String>>'
    + json.dumps(labels, ensure_ascii=False, indent=2) + ';\n'
)
print(f'Imported {len(list(target.glob("*.avif")))} original icons and {len(aliases)} aliases.')
