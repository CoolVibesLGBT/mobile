import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/classified_card.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/realtime.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/classifieds.dart';
import 'package:coolvibes/screens/composer.dart';
import 'package:coolvibes/screens/feed.dart';
import 'package:coolvibes/screens/legal.dart';
import 'package:coolvibes/screens/notifications.dart';
import 'package:coolvibes/screens/premium.dart';
import 'package:coolvibes/screens/profile.dart';
import 'support/contract_api.dart';
import 'support/ui_driver.dart';
import 'realtime_test.dart' show TestSocket;

final listing = <String, dynamic>{
  'public_id': 'listing-42',
  'post_kind': 'job_offer',
  'title': {
    'tr': 'Barista aranıyor',
    'en': 'Barista wanted',
    'ar': 'مطلوب باريستا',
  },
  'content': {'en': jsonEncode(lexical('Coffee and community.'))},
  'extras': {
    'metadata': [
      {'key': 'Şehir', 'value': 'İstanbul'},
    ],
  },
  'author': previewPeer,
  'created_at': DateTime.now()
      .subtract(const Duration(hours: 1))
      .toIso8601String(),
  'children': <Json>[],
};
final notice = <String, dynamic>{
  'id': 'notification-42',
  'sender': {...previewPeer, 'displayname': 'Ada'},
  'type': 'comment',
  'is_read': false,
  'message': {'tr': 'Gönderine yorum yaptı.', 'en': 'Commented on your post.'},
  'payload': jsonEncode({
    'data': {'post_id': 'post-42'},
  }),
  'created_at': DateTime.now()
      .subtract(const Duration(minutes: 3))
      .toIso8601String(),
};

class SecondaryApi extends ContractApi {
  final requests = <({String action, Json body})>[];
  List<Json> notices = [
    notice,
    {
      ...notice,
      'id': 'read-follow',
      'type': 'follow',
      'is_read': true,
      'message': 'Seni takip etti.',
      'payload': <String, dynamic>{},
    },
  ];
  List<Json> listings = [listing];
  Json? detail;
  bool offline = false;
  Completer<Json>? submission;
  Completer<Json>? detailRequest;
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    requests.add((action: action, body: {...body}));
    if (offline &&
        (action.startsWith('classifieds.') ||
            action == 'user.fetch.notifications')) {
      throw ApiException.connection('Offline fixture');
    }
    if (action == 'user.fetch.notifications') {
      return {
        'data': {'notifications': notices},
      };
    }
    if (action == 'classifieds.offers' || action == 'classifieds.search') {
      return {
        'data': {
          'posts': action.endsWith('offers')
              ? listings
              : [
                  {
                    ...listing,
                    'public_id': 'seeking-42',
                    'post_kind': 'job_search',
                    'title': 'İş arıyorum',
                  },
                ],
        },
      };
    }
    if (action == 'classifieds.get') {
      return detailRequest?.future ?? Future.value({'data': detail ?? listing});
    }
    if (action == 'post.create' && submission != null) {
      final result = await submission!.future;
      if (result['fixture_error'] != null) {
        throw ApiException.connection(string(result['fixture_error']));
      }
      return result;
    }
    return super.call(
      action,
      body: body,
      get: get,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      receiveTimeout: receiveTimeout,
    );
  }
}

Future<Session> mount(
  WidgetTester tester,
  Widget home,
  SecondaryApi api, {
  String language = 'tr',
  double scale = 1,
  bool dark = false,
  bool premium = false,
  AppRealtime? realtime,
}) async {
  final session = Session(api, persistPreferences: false, realtime: realtime)
    ..ready = true
    ..user = {...previewSelf, 'is_premium': premium}
    ..locale = Locale(language)
    ..themeMode = dark ? ThemeMode.dark : ThemeMode.light;
  await tester.pumpWidget(
    CoolvibesApp(
      session: session,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: home,
        ),
      ),
    ),
  );
  await pumpUI(tester);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await pumpUI(tester);
  return session;
}

Future<void> close(WidgetTester tester, Session session) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  session.dispose();
}

Finder input(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);
Finder button(String label) => find.byWidgetPredicate(
  (w) => w is AppButton && w.child is Text && (w.child as Text).data == label,
);
Future<void> reveal(WidgetTester tester, Finder target) async {
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await pumpUI(tester);
}

void main() {
  setUp(() {
    for (final language in ['tr', 'en', 'ar']) {
      rootBundle.evict('assets/data/legal-$language.json');
    }
  });
  testWidgets(
    'classified realtime refresh preserves the focused comment draft',
    (tester) async {
      final socket = TestSocket();
      final realtime = AppRealtime(createSocket: (_, _) => socket);
      final api = SecondaryApi();
      final session = await mount(
        tester,
        ClassifiedScreen(post: listing),
        api,
        realtime: realtime,
      );
      realtime.connect(url: 'http://fixture.invalid', token: 'fixture');
      socket.receive('auth:ack', {'success': true});
      await pumpUI(tester);
      final editor = find.descendant(
        of: find.byType(ComposerScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(editor, 'Taslağım kaybolmamalı');
      final state = tester.state(find.byType(ComposerScreen));
      final field = tester.widget<TextField>(editor);
      api.detailRequest = Completer<Json>();
      socket.receive('post', {'action': 'post.changed'});
      await pumpUI(tester);
      expect(tester.state(find.byType(ComposerScreen)), same(state));
      expect(field.controller!.text, 'Taslağım kaybolmamalı');
      expect(field.focusNode!.hasFocus, isTrue);
      api.detailRequest!.complete({'data': listing});
      await pumpUI(tester);
      expect(tester.state(find.byType(ComposerScreen)), same(state));
      expect(field.controller!.text, 'Taslağım kaybolmamalı');
      await close(tester, session);
    },
  );
  testWidgets(
    'notifications use sender, unread filter, post target and realtime refresh',
    (tester) async {
      final socket = TestSocket();
      final realtime = AppRealtime(createSocket: (_, _) => socket);
      final api = SecondaryApi();
      final session = await mount(
        tester,
        const NotificationsScreen(),
        api,
        realtime: realtime,
      );
      expect(find.text('Ada'), findsNWidgets(2));
      expect(find.text('Gönderine yorum yaptı.'), findsOneWidget);
      await tapUI(tester, find.text('Okunmamış'));
      await pumpUI(tester);
      expect(find.text('Seni takip etti.'), findsNothing);
      await tapUI(tester, find.text('Gönderine yorum yaptı.'));
      await pumpUI(tester);
      expect(
        tester
            .widget<PostDetailScreen>(find.byType(PostDetailScreen))
            .post['public_id'],
        'post-42',
      );
      Navigator.of(tester.element(find.byType(PostDetailScreen))).pop();
      await pumpUI(tester);
      realtime.connect(url: 'http://fixture.invalid', token: 'fixture');
      socket.receive('auth:ack', {'success': true});
      await pumpUI(tester);
      api.notices = [
        {...notice, 'id': 'notification-new', 'message': 'Yeni canlı bildirim'},
      ];
      socket.receive('notification', {'id': 'notification-new'});
      await pumpUI(tester);
      expect(find.text('Yeni canlı bildirim'), findsOneWidget);
      expect(find.text('Gönderine yorum yaptı.'), findsNothing);
      await close(tester, session);
    },
  );

  testWidgets(
    'notification category menu filters and follow opens actual sender',
    (tester) async {
      final session = await mount(
        tester,
        const NotificationsScreen(),
        SecondaryApi(),
      );
      await tapUI(tester, find.byType(AppContextMenu));
      await pumpUI(tester);
      await tapUI(tester, find.text('Takipler ve arkadaşlıklar'));
      await pumpUI(tester);
      expect(find.text('Gönderine yorum yaptı.'), findsNothing);
      await tapUI(tester, find.text('Seni takip etti.'));
      await pumpUI(tester);
      expect(
        tester
            .widget<ProfileScreen>(find.byType(ProfileScreen))
            .user?['displayname'],
        'Ada',
      );
      await close(tester, session);
    },
  );

  testWidgets('notifications distinguish offline retry from empty inbox', (
    tester,
  ) async {
    final api = SecondaryApi()..offline = true;
    final session = await mount(tester, const NotificationsScreen(), api);
    expect(find.text('Offline fixture'), findsOneWidget);
    api
      ..offline = false
      ..notices = [];
    tester
        .widgetList<ScreenStatus>(find.byType(ScreenStatus))
        .firstWhere((w) => w.retry != null)
        .retry!();
    await pumpUI(tester);
    expect(find.text('Offline fixture'), findsNothing);
    expect(find.byType(NotificationRow), findsNothing);
    expect(find.byType(ScreenStatus), findsOneWidget);
    await close(tester, session);
  });

  testWidgets(
    'classifieds translate, search metadata, open exact detail and switch kind',
    (tester) async {
      final api = SecondaryApi();
      final session = await mount(tester, const ClassifiedsScreen(), api);
      expect(find.text('Barista aranıyor'), findsOneWidget);
      await tester.enterText(input('classified.search'), 'İstanbul');
      await pumpUI(tester);
      expect(find.byType(ClassifiedCard), findsOneWidget);
      await tester.enterText(input('classified.search'), 'Berlin');
      await pumpUI(tester);
      expect(find.byType(ClassifiedCard), findsNothing);
      await tester.enterText(input('classified.search'), '');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpUI(tester);
      await tapUI(tester, find.text('Barista aranıyor'));
      await pumpUI(tester);
      expect(
        api.requests.lastWhere((r) => r.action == 'classifieds.get').body,
        {'post_id': 'listing-42'},
      );
      expect(
        find.text('Coffee and community.', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(ComposerScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ClassifiedScreen))).pop();
      await pumpUI(tester);
      tester
          .widget<AppSegments<bool>>(find.byType(AppSegments<bool>))
          .onChanged(false);
      await pumpUI(tester);
      expect(find.text('İş arıyorum'), findsOneWidget);
      expect(api.requests.last.action, 'classifieds.search');
      await close(tester, session);
    },
  );

  testWidgets(
    'wrong classified detail never renders a different record and retries',
    (tester) async {
      final api = SecondaryApi()..detail = {...listing, 'public_id': 'wrong'};
      final session = await mount(tester, ClassifiedScreen(post: listing), api);
      expect(find.byType(ClassifiedCard), findsNothing);
      api.detail = listing;
      tester.widget<ScreenStatus>(find.byType(ScreenStatus)).retry!();
      await pumpUI(tester);
      expect(find.text('Barista aranıyor'), findsOneWidget);
      await close(tester, session);
    },
  );

  testWidgets(
    'classified creation validates metadata and preserves content on failed submission',
    (tester) async {
      final api = SecondaryApi()..submission = Completer<Json>();
      final session = await mount(tester, const ClassifiedsScreen(), api);
      tester
          .widget<AppIconButton>(
            find.byWidgetPredicate(
              (w) => w is AppIconButton && w.tooltip == 'İlan oluştur',
            ),
          )
          .onPressed!();
      await pumpUI(tester);
      await tester.enterText(input('classified.title'), 'Tasarımcı aranıyor');
      final composer = find.byType(ComposerScreen);
      final fields = find.descendant(
        of: composer,
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.last, 'Uzaktan çalışma fırsatı.');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpUI(tester);
      await tapUI(tester, find.text('Detay ekle'));
      await pumpUI(tester);
      await tester.enterText(input('classified.label.0'), 'Şehir');
      await tapUI(tester, find.byKey(const ValueKey('classified.publish')));
      await pumpUI(tester);
      expect(api.requests.where((r) => r.action == 'post.create'), isEmpty);
      await tester.enterText(input('classified.value.0'), 'İstanbul');
      FocusManager.instance.primaryFocus?.unfocus();
      await pumpUI(tester);
      await tapUI(tester, find.byKey(const ValueKey('classified.publish')));
      await pumpUI(tester);
      final request = api.requests.singleWhere(
        (r) => r.action == 'post.create',
      );
      expect(request.body['kind'], 'job_offer');
      expect(object(request.body['extras'])['title'], 'Tasarımcı aranıyor');
      expect(object(request.body['extras'])['metadata'], [
        {'key': 'Şehir', 'value': 'İstanbul'},
      ]);
      api.submission!.complete({'fixture_error': 'Submission offline'});
      await pumpUI(tester);
      expect(find.text('Tasarımcı aranıyor'), findsOneWidget);
      expect(find.text('Uzaktan çalışma fırsatı.'), findsOneWidget);
      expect(find.text('Submission offline'), findsOneWidget);
      api.submission = Completer<Json>();
      await tapUI(tester, find.byKey(const ValueKey('classified.publish')));
      await pumpUI(tester);
      api.submission!.complete({'success': true, 'data': listing});
      await pumpUI(tester);
      expect(find.byType(ComposerScreen), findsNothing);
      expect(
        api.requests.where((r) => r.action == 'classifieds.offers').length,
        greaterThan(1),
      );
      await close(tester, session);
    },
  );

  testWidgets(
    'legal center opens original document and table of contents jumps',
    (tester) async {
      final api = SecondaryApi();
      final session = await mount(tester, const LegalScreen(), api);
      final row = find.byKey(const ValueKey('legal.document.privacy'));
      await reveal(tester, row);
      await tapUI(tester, row);
      await pumpUI(tester);
      expect(
        tester.widget<LegalDetail>(find.byType(LegalDetail)).documentId,
        'privacy',
      );
      final data =
          jsonDecode(await rootBundle.loadString('assets/data/legal-tr.json'))
              as Json;
      final section = object(
        object(object(data['pages'])['privacy'])['sections'][0],
      );
      expect(find.text(string(section['body'])), findsOneWidget);
      await tapUI(tester, find.byType(AppContextMenu));
      await pumpUI(tester);
      await tapUI(tester, find.text('Veri paylaşımı').last);
      await pumpUI(tester);
      final heading = find.text('Veri paylaşımı');
      expect(
        tester.getTopLeft(heading).dy,
        greaterThan(tester.getBottomLeft(find.byType(AppHeader)).dy),
      );
      expect(tester.getTopLeft(heading).dy, lessThan(500));
      expect(api.requests, isEmpty);
      await close(tester, session);
    },
  );

  testWidgets('unknown legal document gives an honest unavailable state', (
    tester,
  ) async {
    final session = await mount(
      tester,
      const LegalDetail(documentId: 'missing'),
      SecondaryApi(),
    );
    expect(find.text('Aradığın belgeye ulaşılamıyor.'), findsOneWidget);
    await close(tester, session);
  });

  for (final language in ['tr', 'ar']) {
    testWidgets(
      'secondary screens fit narrow large text and $language direction',
      (tester) async {
        tester.view.physicalSize = const Size(320, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final home in <Widget>[
          const PremiumScreen(),
          const LegalScreen(),
          const LegalDetail(documentId: 'privacy'),
          const NotificationsScreen(),
          const ClassifiedsScreen(),
          ClassifiedScreen(post: listing),
          const ComposerScreen(kind: 'job_offer'),
        ]) {
          final session = await mount(
            tester,
            home,
            SecondaryApi(),
            language: language,
            scale: 2,
            dark: language == 'ar',
          );
          expect(tester.takeException(), isNull, reason: '$home in $language');
          final scrolls = find.byType(Scrollable);
          if (scrolls.evaluate().isNotEmpty) {
            await tester.drag(scrolls.first, const Offset(0, -450));
            await pumpUI(tester);
          }
          await close(tester, session);
        }
      },
    );
  }

  testWidgets(
    'premium shows account entitlement and opens local legal center',
    (tester) async {
      final api = SecondaryApi();
      final session = await mount(
        tester,
        const PremiumScreen(),
        api,
        premium: true,
      );
      expect(find.byKey(const ValueKey('premium.active')), findsOneWidget);
      expect(button('Üyeliği yönet'), findsOneWidget);
      final legal = find.byKey(const ValueKey('premium.legal'));
      await reveal(tester, legal);
      await tapUI(tester, legal);
      await pumpUI(tester);
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(api.requests, isEmpty);
      await close(tester, session);
    },
  );

  testWidgets(
    'premium account action prevents double launch and displays failures',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final pending = Completer<bool>();
      var launches = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'launch');
        expect(call.arguments['url'], 'https://coolvibes.lgbt/premium');
        launches++;
        return pending.future;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final session = await mount(
        tester,
        const PremiumScreen(),
        SecondaryApi(),
      );
      final account = find.byKey(const ValueKey('premium.account'));
      await tapUI(tester, account);
      await pumpUI(tester);
      expect(tester.widget<AppButton>(account).onPressed, isNull);
      expect(launches, 1);
      pending.complete(false);
      await pumpUI(tester);
      expect(find.byType(AppInfoSheet), findsOneWidget);
      await close(tester, session);
    },
    skip: const bool.fromEnvironment('NATIVE_HOST_TOUCH'),
  );
}
