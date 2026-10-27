import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/core/appearance.dart';

/// The Dart port must resolve every base x preset x cloud theme x custom
/// colour exactly like the source TypeScript (fixture generated from it).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('resolveTheme matches the source for all 93 cases', () async {
    await AppearanceCatalog.load();
    final cases = jsonDecode(File('test/fixtures/appearance-cases.json').readAsStringSync()) as List;
    var failures = <String>[];
    for (final item in cases) {
      final sel = item['selection'] as Map;
      final messages = sel['messages'] as Map?;
      final resolved = resolveTheme(
        BaseTheme.values.byName(item['base']),
        ThemeSelection(
          preset: sel['preset'],
          theme: sel['theme'],
          messages: messages == null ? null : MessageColors(messages['accent'], List<String>.from(messages['colors'])),
        ),
      );
      final out = item['out'] as Map;
      final actual = {
        'accent': resolved.accent, 'surface': resolved.surface, 'background': resolved.background,
        'text': resolved.text, 'secondary': resolved.secondary, 'border': resolved.border,
        'incoming': resolved.incoming, 'outgoing': resolved.outgoing, 'thumbnailOutgoing': resolved.thumbnailOutgoing,
        'outgoingText': resolved.outgoingText, 'outgoingPrimary': resolved.outgoingPrimary, 'outgoingMeta': resolved.outgoingMeta,
        'accentText': resolved.accentText, 'input': resolved.input, 'pinned': resolved.pinned, 'highlight': resolved.highlight,
        'outgoingStops': resolved.outgoingStops,
        'wallpaper': {
          'kind': resolved.wallpaper.kind, 'colors': resolved.wallpaper.colors, 'pattern': resolved.wallpaper.pattern,
          'intensity': resolved.wallpaper.intensity, 'source': resolved.wallpaper.source,
        },
      };
      for (final key in out.keys) {
        final expected = jsonEncode(out[key]).toLowerCase().replaceAll('.0', '');
        final got = jsonEncode(actual[key]).toLowerCase().replaceAll('.0', '');
        if (expected != got) failures.add('${item['base']} ${jsonEncode(sel)} $key: expected $expected got $got');
      }
    }
    expect(failures, isEmpty, reason: failures.take(15).join('\n'));
  });
}
