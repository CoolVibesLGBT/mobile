import 'dart:ui' show Tristate, CheckedState;
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/components/components.dart';
import 'header_profile_edit_test.dart' as fixture;
import 'support/ui_driver.dart';

void main() {
  for (final language in ['tr', 'ar']) {
    testWidgets('switch row toggles once from label and control: $language', (
      tester,
    ) async {
      var value = false, enabled = true;
      final changes = <bool>[];
      late StateSetter update;
      final semantics = tester.ensureSemantics();
      final session = await fixture.mount(
        tester,
        AppScaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: AppChoiceRow(
                  title: const Text('Profile visibility preference'),
                  value: value,
                  onChanged: !enabled
                      ? null
                      : (next) => setState(() {
                          value = next!;
                          changes.add(value);
                        }),
                ),
              );
            },
          ),
        ),
        language: language,
        width: 320,
        scale: 2,
        dark: language == 'ar',
      );
      expect(find.byType(CupertinoCheckbox), findsNothing);
      final control = find.byType(AppSwitch);
      expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('Profile visibility preference'));
      await pumpUI(tester);
      expect(changes, [true]);
      await tester.tap(control);
      await pumpUI(tester);
      expect(changes, [true, false]);
      final data = tester
          .getSemantics(find.bySemanticsLabel('Profile visibility preference'))
          .getSemanticsData();
      expect(data.flagsCollection.isToggled, Tristate.isFalse);
      expect(data.flagsCollection.isChecked, CheckedState.none);
      update(() => enabled = false);
      await pumpUI(tester);
      expect(
        tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).onChanged,
        isNull,
      );
      await tester.tap(find.text('Profile visibility preference'));
      await pumpUI(tester);
      expect(changes, [true, false]);
      await fixture.finish(tester, session);
      semantics.dispose();
    });
  }
}
