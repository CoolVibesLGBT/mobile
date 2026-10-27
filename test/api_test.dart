import 'package:coolvibes/core/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads nested records and opaque server cursors', () {
    final page = RecordPage.parse({
      'data': {
        'messages': [
          {'id': '1', 'content': 'hello'},
        ],
        'pagination': {'next_cursor': 'opaque/next=='},
      },
    });
    expect(page.records.single['id'], '1');
    expect(page.next, 'opaque/next==');
  });
  test('round trips paragraphs through the existing Lexical contract', () {
    const text = 'Hello Coolvibes\nİstanbul مرحبا';
    expect(plainText(lexical(text)), text);
  });
  test('does not manufacture continuation cursors', () {
    expect(
      RecordPage.parse({
        'data': [
          {'id': 1},
        ],
      }).next,
      isNull,
    );
  });
}
