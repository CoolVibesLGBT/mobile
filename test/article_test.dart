import 'dart:convert';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/article_content.dart';
import 'package:coolvibes/components/article_editor.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/article.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/contract_api.dart';
import 'support/ui_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'selection formatting, replacement, emoji and IME retain valid styles',
    () {
      final input = ArticleTextController('Merhaba 👋 dünya');
      input.selection = const TextSelection(baseOffset: 0, extentOffset: 7);
      input.apply((m) => m.copy(format: 1));
      input.value = input.value.copyWith(
        text: 'Merhaba 👋 güzel dünya',
        selection: const TextSelection.collapsed(offset: 16),
        composing: const TextRange(start: 11, end: 16),
      );
      expect(input.marks.length, input.text.length);
      expect(input.marks.take(7).every((m) => m.format == 1), isTrue);
      expect(plainText({'children': input.nodes}), input.text);
      input.dispose();
    },
  );
  testWidgets(
    'headings, lists, links, tables and history survive document round trip',
    (tester) async {
      final doc = ArticleController();
      doc.insert('Başlık');
      doc.block('h1');
      doc.insert('\n');
      doc.insert('İlk madde');
      doc.block('check');
      doc.input.selection = TextSelection(
        baseOffset: 0,
        extentOffset: doc.input.text.length,
      );
      doc.format(1);
      doc.link('https://example.com');
      doc.input.selection = TextSelection.collapsed(
        offset: doc.input.text.length,
      );
      doc.insert('\nİkinci madde');
      doc.addTable();
      doc.insert('Hücre');
      doc.tableAction('row');
      doc.insert('Yeni satır');
      doc.tableAction('column');
      doc.insert('Yeni sütun');
      final serialized = jsonEncode(doc.document);
      final copy = ArticleController()..restore(object(jsonDecode(serialized)));
      expect(jsonEncode(copy.document), serialized);
      expect(copy.text, doc.text);
      expect(doc.table!.rows.length, 3);
      doc.tableAction('deleteRow');
      expect(doc.table!.rows.length, 2);
      doc.undo();
      expect(doc.blocks.where((b) => b.type == 'table').single.rows.length, 3);
      doc.redo();
      expect(doc.blocks.where((b) => b.type == 'table').single.rows.length, 2);
      await tester.pump();
      doc.dispose();
      copy.dispose();
    },
  );
  testWidgets(
    'article uses the production send queue and formatted content renders',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ContractApi();
      final session = Session(api, persistPreferences: false)
        ..ready = true
        ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: Builder(
            builder: (context) => AppScaffold(
              body: AppButton.text(
                onPressed: () => sheet(context, const ComposerScreen()),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await pumpUI(tester);
      final editor = tester.widget<ArticleEditor>(find.byType(ArticleEditor));
      final first = find.byType(TextField).first;
      await tester.enterText(first, 'Flutter makalesi');
      await tester.pump();
      editor.controller.input.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 7,
      );
      await tester.pump();
      await tapUI(
        tester,
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Kalın',
        ),
      );
      await pumpUI(tester);
      expect(
        editor.controller.input.marks.take(7).every((m) => m.format == 1),
        isTrue,
      );
      editor.controller.input.selection = TextSelection.collapsed(
        offset: editor.controller.input.text.length,
      );
      await pumpUI(tester);
      await tapUI(
        tester,
        find.byWidgetPredicate((w) => w is AppContextMenu && w.label == 'Ekle'),
      );
      await pumpUI(tester);
      await tester.tap(find.text('Başlık'));
      await pumpUI(tester);
      for (var level = 1; level <= 6; level++) {
        expect(
          find.byWidgetPredicate(
            (w) => w is AppSymbol && w.name == 'textformat.h$level',
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('Geri'));
      await pumpUI(tester);
      await tester.tap(find.text('Başlık'));
      await pumpUI(tester);
      await tester.tap(find.text('Başlık 1'));
      await pumpUI(tester);
      expect(editor.controller.active!.type, 'h1');
      await tapUI(
        tester,
        find.byWidgetPredicate(
          (w) => w is AppIconButton && w.tooltip == 'Tablo',
        ),
      );
      await pumpUI(tester);
      final cell = find.byWidgetPredicate(
        (w) => w is TextField && w.controller == editor.controller.input,
      );
      await tester.enterText(cell, 'Tablo içeriği');
      await pumpUI(tester);
      expect(editor.controller.table, isNotNull);
      expect(editor.controller.text, contains('Tablo içeriği'));
      final document = editor.controller.document;
      await tapUI(tester, find.byKey(const ValueKey('article.send')));
      await pumpUI(tester);
      expect(api.createdPosts, hasLength(1));
      expect(api.createdPosts.single['content'], document);
      expect(find.byType(ComposerScreen), findsNothing);
      await tester.pumpWidget(
        CoolvibesApp(
          session: session,
          home: AppScaffold(
            body: ArticleContent(content: {'tr': jsonEncode(document)}),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(RichText), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
