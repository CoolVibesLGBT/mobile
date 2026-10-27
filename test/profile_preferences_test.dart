import 'dart:async';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/illustrated_icon.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/profile_preferences.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/design/illustrated_icon_catalog.dart';
import 'package:coolvibes/screens/app_forms.dart';
import 'package:coolvibes/screens/preferences.dart';
import 'header_profile_edit_test.dart' as fixture;
import 'support/profile_api.dart';
import 'support/ui_driver.dart';

const choiceGroup = <String, dynamic>{
  '_kind': 'attributes',
  'tag': 'relationship_status',
  'allow_multiple': false,
  'items': [
    {
      'id': 'single',
      'bit_index': 17,
      'title': {'en': 'Single', 'tr': 'Bekâr'},
    },
    {
      'id': 'partner',
      'bit_index': 18,
      'title': {'en': 'Partnered', 'tr': 'İlişkisi var'},
    },
  ],
};
final firstChoice = object((choiceGroup['items'] as List).first);
final secondChoice = object((choiceGroup['items'] as List).last);

class PreferenceApi extends ProfileApi {
  Completer<void>? gate;
  Object? preferenceError;
  Json projection = {
    'selected_preference_bits': [18, 510],
  };
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (action != 'user.update_preferences') {
      return super.call(
        action,
        body: body,
        get: get,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        receiveTimeout: receiveTimeout,
      );
    }
    calls.add((action: action, body: Map.of(body)));
    await gate?.future;
    if (preferenceError != null) throw preferenceError!;
    return {
      'data': {'user': projection},
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('original AVIF illustrations decode in Flutter', () async {
    for (final name in [
      'system-user',
      'attribute-relationship_status',
      'interest-category-lifestyle',
      'fantasy-category-amusement',
    ]) {
      final data = await rootBundle.load(
        'assets/images/profile_icons/$name.avif',
      );
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      try {
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 256);
        expect(frame.image.height, 256);
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    }
  });

  test(
    'every imported illustration alias resolves to a packaged original',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      expect(illustratedIconAliases.values.toSet().length, 467);
      for (final key in illustratedIconAliases.values.toSet()) {
        expect(
          assets,
          contains('assets/images/profile_icons/$key.avif'),
          reason: key,
        );
      }
      expect(
        IllustratedIcon.keyFor('attribute_relationship_status'),
        'attribute-relationship_status',
      );
      expect(
        IllustratedIcon.keyFor('missing', fallback: 'system-user'),
        'system-user',
      );
    },
  );

  test(
    'single selection can be cleared and follows the server projection',
    () async {
      final api = PreferenceApi();
      final session = Session(api, persistPreferences: false)
        ..user = {
          'displayname': 'Retained',
          'selected_preference_bits': [17, 510],
        };
      addTearDown(session.dispose);
      await session.updatePreference(choiceGroup, secondChoice, true);
      expect(
        selectedPreferenceItems(session.user, choiceGroup).single['id'],
        'partner',
      );
      expect(isBitSet(preferenceFlagsOf(session.user), 510), isTrue);
      api.projection = {
        'selected_preference_bits': [510],
      };
      await session.updatePreference(choiceGroup, secondChoice, false);
      expect(selectedPreferenceItems(session.user, choiceGroup), isEmpty);
      expect(api.calls.last.body, {
        'id': 'partner',
        'bit_index': 18,
        'enabled': false,
      });
      expect(api.calls.where((c) => c.action == 'auth.user_info'), isEmpty);
      expect(session.user['displayname'], 'Retained');
    },
  );

  test(
    'in-flight preference writes cannot race and failures retain selections',
    () async {
      final api = PreferenceApi()..gate = Completer<void>();
      final session = Session(api, persistPreferences: false)
        ..user = {
          'selected_preference_bits': [17],
        };
      addTearDown(session.dispose);
      final pending = session.updatePreference(choiceGroup, secondChoice, true);
      expect(session.updatingPreferences, isTrue);
      await session.updatePreference(choiceGroup, firstChoice, false);
      expect(api.calls.length, 1);
      api.gate!.complete();
      await pending;
      expect(session.updatingPreferences, isFalse);
      api.preferenceError = ApiException('Offline');
      await expectLater(
        session.updatePreference(choiceGroup, firstChoice, true),
        throwsA(isA<ApiException>()),
      );
      expect(session.updatingPreferences, isFalse);
      expect(
        selectedPreferenceItems(session.user, choiceGroup).single['id'],
        'partner',
      );
    },
  );

  test(
    'late responses cannot change another account and partial flags replace stale bits',
    () async {
      final api = PreferenceApi()..gate = Completer<void>();
      final session = Session(api, persistPreferences: false)
        ..user = {
          'selected_preference_bits': [17],
        };
      addTearDown(session.dispose);
      final pending = session.updatePreference(choiceGroup, secondChoice, true);
      api.token = 'another-account';
      session.user = {'displayname': 'Another account'};
      api.gate!.complete();
      await pending;
      expect(session.user, {'displayname': 'Another account'});
      session.user = {
        'selected_preference_bits': [17],
      };
      api.projection = {
        'preferences_flags': serializePreferencesFlags(setBit(BigInt.zero, 18)),
      };
      await session.updatePreference(choiceGroup, secondChoice, true);
      expect(session.user.containsKey('selected_preference_bits'), isFalse);
      expect(
        selectedPreferenceItems(session.user, choiceGroup).single['id'],
        'partner',
      );
    },
  );

  testWidgets(
    'preference switches clear selections and errors show the shared error sheet',
    (tester) async {
      final api = PreferenceApi()
        ..projection = {'selected_preference_bits': <int>[]};
      final session = await fixture.mount(
        tester,
        const PreferencesScreen(kind: 'attributes'),
        api: api,
      );
      session.system = {
        'preferences': {
          'attributes': [choiceGroup],
        },
      };
      session.user = {
        'selected_preference_bits': [17],
      };
      session.notifyListeners();
      await pumpUI(tester);
      await fixture.visibleTap(tester, find.text('İlişki Durumu'));
      expect(find.byType(IllustratedIcon), findsWidgets);
      await fixture.visibleTap(
        tester,
        find.descendant(
          of: find.byType(AppChoiceRow),
          matching: find.text('Bekâr'),
        ),
      );
      expect(api.calls.last.body['enabled'], isFalse);
      final row = find.ancestor(
        of: find.descendant(
          of: find.byType(AppChoiceRow),
          matching: find.text('Bekâr'),
        ),
        matching: find.byType(AppChoiceRow),
      );
      expect(tester.widget<AppChoiceRow>(row).value, isFalse);
      api.preferenceError = ApiException('Unavailable', 503);
      await fixture.visibleTap(
        tester,
        find.descendant(
          of: find.byType(AppChoiceRow),
          matching: find.text('Bekâr'),
        ),
      );
      expect(find.byType(AppErrorSheet), findsOneWidget);
      expect(session.user['selected_preference_bits'], isEmpty);
      await fixture.finish(tester, session);
    },
  );

  testWidgets('offscreen profile fields still block invalid saves', (
    tester,
  ) async {
    final api = ProfileApi();
    api.self['displayname'] = '';
    final session = await fixture.mount(
      tester,
      Builder(builder: (context) => AppForms.profile(context, api.self)),
      api: api,
      width: 320,
      language: 'ar',
      scale: 2,
    );
    final form = tester.state<ActionFormState>(find.byType(ActionForm));
    await form.save();
    await pumpUI(tester);
    expect(api.calls.where((c) => c.action == 'user.update_profile'), isEmpty);
    await fixture.finish(tester, session);
  });

  testWidgets('saving another profile field preserves formatted web bio', (
    tester,
  ) async {
    final api = ProfileApi();
    api.self['bio'] =
        '<p>Hello <strong>world</strong> &amp; friends</p><p>Second line</p>';
    final session = await fixture.mount(
      tester,
      Builder(builder: (context) => AppForms.profile(context, api.self)),
      api: api,
    );
    final form = tester.state<ActionFormState>(find.byType(ActionForm));
    expect(form.controllers['bio']!.text, 'Hello world & friends\nSecond line');
    form.setValue('displayname', 'Updated name');
    await pumpUI(tester);
    await tester.tap(find.text('Kaydet'));
    await pumpUI(tester);
    final sent = api.calls
        .where((c) => c.action == 'user.update_profile')
        .single
        .body;
    expect(sent.containsKey('bio'), isFalse);
    expect(api.self['bio'], contains('<strong>world</strong>'));
    await fixture.finish(tester, session);
  });
}
