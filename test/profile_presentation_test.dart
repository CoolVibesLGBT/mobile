import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/components.dart';
import 'package:coolvibes/components/profile_header.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/screens/profile.dart';
import 'package:coolvibes/screens/chat.dart';
import 'package:coolvibes/screens/media.dart';
import 'package:coolvibes/screens/settings.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'support/profile_api.dart';
import 'support/ui_driver.dart';

final profileTabs = find.byKey(const ValueKey('profile.tabs'));
Finder headerControl(String label) => find.descendant(
  of: find.byType(ProfileHeader),
  matching: find.byWidgetPredicate(
    (w) => w is AppIconButton && w.tooltip == label,
  ),
);

Future<Session> mountProfile(
  WidgetTester tester,
  ProfileApi api, {
  bool own = false,
  bool dark = false,
  String language = 'tr',
  double scale = 1,
  Size size = const Size(390, 844),
  String initialTab = 'about',
}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.viewPadding = const FakeViewPadding(top: 177, bottom: 102);
  tester.view.padding = const FakeViewPadding(top: 177, bottom: 102);
  addTearDown(tester.view.reset);
  final session = Session(api, persistPreferences: false)
    ..ready = true
    ..user = api.self
    ..system = previewSystem
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
          child: ProfileScreen(
            user: own ? null : previewPeer,
            initialTab: initialTab,
          ),
        ),
      ),
    ),
  );
  await pumpUI(tester);
  return session;
}

Future<void> finishProfile(WidgetTester tester, Session session) async {
  await tester.pumpWidget(const SizedBox());
  await pumpUI(tester);
  session.dispose();
  expect(tester.takeException(), isNull);
}

Future<void> revealTabs(WidgetTester tester) async {
  for (var i = 0; i < 10 && profileTabs.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -350));
    await pumpUI(tester);
  }
  expect(profileTabs.hitTestable(), findsOneWidget);
}

Future<void> chooseTab(WidgetTester tester, String label) async {
  await revealTabs(tester);
  final target = find.descendant(of: profileTabs, matching: find.text(label));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await pumpUI(tester);
}

void main() {
  testWidgets(
    'profile edit retains failed changes and refreshes after saving',
    (tester) async {
      final api = ProfileApi()
        ..updateError = ApiException('Cannot save right now');
      api.self['date_of_birth'] = '1994-05-06T00:00:00Z';
      final session = await mountProfile(tester, api, own: true);
      await tester.tap(headerControl('Düzenle'));
      await pumpUI(tester);
      final name = find
          .descendant(
            of: find.byKey(const ValueKey('form.displayname')),
            matching: find.byType(TextField),
          )
          .first;
      await tester.ensureVisible(name);
      await tester.enterText(name, 'Yeni isim');
      await tester.tap(find.text('Kaydet'));
      await pumpUI(tester);
      expect(find.text('Cannot save right now'), findsOneWidget);
      expect(tester.widget<TextField>(name).controller!.text, 'Yeni isim');
      api.updateError = null;
      await tester.tap(find.text('Kaydet'));
      await pumpUI(tester);
      expect(find.byType(ActionForm), findsNothing);
      expect(find.text('Yeni isim'), findsOneWidget);
      expect(session.user['displayname'], 'Yeni isim');
      final saved = api.calls
          .where((c) => c.action == 'user.update_profile')
          .last;
      expect(saved.body['displayname'], 'Yeni isim');
      expect(saved.body['date_of_birth'], '1994-05-06');
      expect(saved.body.containsKey('username'), isFalse);
      await finishProfile(tester, session);
    },
  );

  testWidgets('album owner moves public media and deletes only private media', (
    tester,
  ) async {
    final api = ProfileApi();
    final session = await mountProfile(
      tester,
      api,
      own: true,
      initialTab: 'media',
    );
    await revealTabs(tester);
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -650));
    await pumpUI(tester);
    Finder photos() => find.descendant(
      of: find.byType(AlbumScreen),
      matching: find.byType(AppContextMenu),
    );
    final labels = tester.element(find.byType(AlbumScreen)).l10n;
    final public = tester.widget<AppContextMenu>(photos().first);
    expect(public.items.any((i) => i.title == labels.deleteLabel), isFalse);
    await tester.ensureVisible(photos().first);
    await pumpUI(tester);
    await tester.longPress(photos().first);
    await pumpUI(tester);
    await tester.tap(find.text(labels.profileMakePrivate));
    await pumpUI(tester);
    final move = api.calls.where((c) => c.action == 'user.photos.move').single;
    expect(move.body, {'photo_id': '41', 'destination': 'private'});
    expect(api.publicPhotos, isEmpty);
    final firstPrivate = tester.widget<AppContextMenu>(photos().first);
    expect(
      firstPrivate.items.any((i) => i.title == labels.deleteLabel),
      isTrue,
    );
    firstPrivate.items
        .firstWhere((i) => i.title == labels.deleteLabel)
        .onPressed!();
    await pumpUI(tester);
    await tester.tap(find.text(labels.deleteLabel).last);
    await pumpUI(tester);
    expect(
      api.calls
          .where((c) => c.action == 'user.private_photos.delete')
          .single
          .body['photo_id'],
      '42',
    );
    expect(api.privatePhotos.map(recordId), ['41']);
    await finishProfile(tester, session);
  });

  testWidgets(
    'album partial failure is visible and permission denial clears cached photos',
    (tester) async {
      final api = ProfileApi()..access = 'approved';
      final session = await mountProfile(tester, api, initialTab: 'media');
      await revealTabs(tester);
      final list = find.descendant(
        of: find.byType(AlbumScreen),
        matching: find.byType(RecordList),
      );
      RecordListState album() => tester.state<RecordListState>(list);
      expect(album().records.length, 2);
      api.publicError = ApiException.connection('Public album offline');
      await album().reload();
      await pumpUI(tester);
      expect(album().records.map(recordId), ['42']);
      expect(find.text('Public album offline'), findsOneWidget);
      api.privateError = ApiException('Album forbidden', 403);
      await album().reload();
      await pumpUI(tester);
      expect(album().records, isEmpty);
      expect(album().error, 'Album forbidden');
      await finishProfile(tester, session);
    },
  );

  testWidgets(
    'photo access uses real request/viewer IDs for approve and revoke',
    (tester) async {
      final api = ProfileApi();
      final session = await mountProfile(
        tester,
        api,
        own: true,
        initialTab: 'media',
      );
      await revealTabs(tester);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -650));
      await pumpUI(tester);
      final labels = tester.element(find.byType(AlbumScreen)).l10n;
      await tester.ensureVisible(find.text(labels.photoAccessRequests));
      await tester.tap(find.text(labels.photoAccessRequests));
      await pumpUI(tester);
      expect(find.byType(ActivityScreen), findsOneWidget);
      expect(find.text('Ege'), findsOneWidget);
      Finder control(String label) => find.byWidgetPredicate(
        (w) => w is AppIconButton && w.tooltip == label,
      );
      await tester.tap(control(labels.approve));
      await pumpUI(tester);
      expect(
        api.calls
            .where((c) => c.action == 'user.private_photos.access.respond')
            .single
            .body,
        {'request_id': '71', 'decision': 'approved'},
      );
      expect(control(labels.approve), findsNothing);
      await tester.tap(control(labels.profileRevokeAccess));
      await pumpUI(tester);
      await tester.tap(find.text(labels.profileRevokeAccess).last);
      await pumpUI(tester);
      expect(
        api.calls
            .where((c) => c.action == 'user.private_photos.access.revoke')
            .single
            .body,
        {'viewer_id': '1002'},
      );
      expect(find.text(labels.profileAccessDenied), findsOneWidget);
      await finishProfile(tester, session);
    },
  );
  for (final variant in [
    (false, 'tr', 1.0),
    (true, 'tr', 1.0),
    (false, 'ar', 2.0),
  ]) {
    final (dark, language, scale) = variant;
    testWidgets(
      'profile keeps one header and pinned glass tabs: $dark/$language/$scale',
      (tester) async {
        final api = ProfileApi();
        final session = await mountProfile(
          tester,
          api,
          dark: dark,
          language: language,
          scale: scale,
          size: scale == 1 ? const Size(390, 844) : const Size(320, 568),
        );
        expect(find.byType(ProfileHeader), findsOneWidget);
        final avatar = find.descendant(
          of: find.byType(ProfileHeader),
          matching: find.byType(Avatar),
        );
        expect(tester.getSize(avatar), const Size(100, 100));
        expect(tester.getTopLeft(avatar).dy, closeTo(81, 1));
        for (final button in tester.widgetList<AppIconButton>(
          find.descendant(
            of: find.byType(ProfileHeader),
            matching: find.byType(AppIconButton),
          ),
        )) {
          expect(button.dimension, 56);
          expect(button.glass, isTrue);
        }
        await revealTabs(tester);
        for (var i = 0; i < 5 && tester.getTopLeft(profileTabs).dy > 106; i++) {
          await tester.drag(
            find.byType(NestedScrollView),
            const Offset(0, -400),
          );
          await pumpUI(tester);
        }
        expect(tester.getTopLeft(profileTabs).dy, closeTo(105, 1));
        final labels = tester.widget<AppSegments<String>>(profileTabs).values;
        await chooseTab(tester, (labels['posts']! as Text).data!);
        final before = tester.getTopLeft(profileTabs).dy;
        final firstRequests = api.calls
            .where((c) => c.action == 'user.fetch.posts')
            .length;
        expect(firstRequests, 1);
        await chooseTab(tester, (labels['likes']! as Text).data!);
        await chooseTab(tester, (labels['posts']! as Text).data!);
        expect(
          api.calls.where((c) => c.action == 'user.fetch.posts').length,
          firstRequests,
        );
        expect(tester.getTopLeft(profileTabs).dy, closeTo(before, 1));
        expect(find.byType(ProfileHeader, skipOffstage: false), findsOneWidget);
        expect(
          tester.widget<AppSegments<String>>(profileTabs).selected,
          'posts',
        );
        expect(
          api.calls
              .where((c) => c.action == 'user.fetch.posts')
              .single
              .body['user_id'],
          '1002',
        );
        await finishProfile(tester, session);
      },
    );
  }

  testWidgets(
    'follow is single flight, preserves peer and unlocks follower posts',
    (tester) async {
      final api = ProfileApi()..followGate = Completer<void>();
      api.peer['privacy_level'] = 'followers_only';
      final session = await mountProfile(tester, api);
      await chooseTab(tester, 'Gönderiler');
      expect(api.calls.where((c) => c.action == 'user.fetch.posts'), isEmpty);
      final scroll = tester
          .widget<NestedScrollView>(find.byType(NestedScrollView))
          .controller!;
      scroll.jumpTo(0);
      await pumpUI(tester);
      await tester.tap(headerControl('Takip et'));
      await tester.pump();
      await tester.tap(headerControl('Takip et'));
      expect(
        api.calls.where((c) => c.action == 'user.follow.toggle').length,
        1,
      );
      final busy = tester.widget<AppIconButton>(headerControl('Takip et'));
      expect(busy.onPressed, isNull);
      expect(busy.glass, isTrue);
      api.followGate!.complete();
      await pumpUI(tester);
      expect(
        find.descendant(
          of: find.byType(ProfileInfoRow),
          matching: find.text('@ege'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ProfileInfoRow),
          matching: find.text('@deniz'),
        ),
        findsNothing,
      );
      expect(headerControl('Takip ediliyor'), findsOneWidget);
      await chooseTab(tester, 'Gönderiler');
      expect(
        api.calls.where((c) => c.action == 'user.fetch.posts'),
        isNotEmpty,
      );
      expect(
        api.calls
            .where((c) => c.action == 'user.follow.toggle')
            .single
            .body['followee_id'],
        '1002',
      );
      await finishProfile(tester, session);
    },
  );

  testWidgets('message opens the real conversation using the peer UUID', (
    tester,
  ) async {
    final api = ProfileApi();
    api.peer['id'] = '9fde2ab7-837c-491f-9185-ea071214802b';
    final session = await mountProfile(tester, api);
    await tester.tap(headerControl('Mesaj'));
    await pumpUI(tester);
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(
      api.calls
          .where((c) => c.action == 'chat.create')
          .single
          .body['participant_ids[]'],
      [api.peer['id']],
    );
    Navigator.of(tester.element(find.byType(ChatScreen))).pop();
    await pumpUI(tester);
    expect(find.text('@ege'), findsOneWidget);
    await finishProfile(tester, session);
  });

  testWidgets(
    'album requests once, distinguishes pending and removes revoked media',
    (tester) async {
      final api = ProfileApi()..accessGate = Completer<void>();
      final session = await mountProfile(tester, api, initialTab: 'media');
      await revealTabs(tester);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await pumpUI(tester);
      final request = find.text('Erişim iste');
      await tester.ensureVisible(request);
      await tester.tap(request);
      await tester.pump();
      await tester.tap(request);
      expect(
        api.calls
            .where((c) => c.action == 'user.private_photos.access.request')
            .length,
        1,
      );
      api.accessGate!.complete();
      await pumpUI(tester);
      expect(request, findsNothing);
      RecordListState album() => tester.state<RecordListState>(
        find.descendant(
          of: find.byType(AlbumScreen),
          matching: find.byType(RecordList),
        ),
      );
      expect(album().records.map(recordId), ['41']);
      api.access = 'approved';
      session.invalidateMedia();
      await pumpUI(tester);
      expect(album().records.map(recordId), ['41', '42']);
      expect(request, findsNothing);
      final photo = find
          .descendant(
            of: find.byType(AlbumScreen),
            matching: find.byType(AppImage),
          )
          .last;
      await tester.ensureVisible(photo);
      await tester.tap(photo);
      await pumpUI(tester);
      expect(find.byType(MediaScreen), findsOneWidget);
      api.access = 'denied';
      session.invalidateMedia();
      await pumpUI(tester);
      expect(find.byType(MediaScreen), findsNothing);
      expect(album().records.map(recordId), ['41']);
      expect(request, findsOneWidget);
      await finishProfile(tester, session);
    },
  );

  testWidgets(
    'profile errors do not expose stale peer data and retry recovers',
    (tester) async {
      final api = ProfileApi()
        ..profileError = ApiException('Profile unavailable', 403);
      final session = await mountProfile(tester, api);
      expect(find.byType(ProfileHeader), findsNothing);
      expect(find.text('Profile unavailable'), findsOneWidget);
      api.profileError = null;
      final state = tester.widget<ScreenStatus>(find.byType(ScreenStatus));
      state.retry!();
      await pumpUI(tester);
      expect(find.text('@ege'), findsOneWidget);
      await finishProfile(tester, session);
    },
  );

  testWidgets('nested profile posts paginate and keep rows while refreshing', (
    tester,
  ) async {
    final api = ProfileApi()..paging = true;
    final session = await mountProfile(
      tester,
      api,
      own: true,
      initialTab: 'posts',
    );
    await revealTabs(tester);
    for (
      var i = 0;
      i < 10 &&
          api.calls.where((c) => c.action == 'user.fetch.posts').length < 2;
      i++
    ) {
      await tester.drag(find.byType(NestedScrollView), const Offset(0, -600));
      await pumpUI(tester);
    }
    final pages = api.calls
        .where((c) => c.action == 'user.fetch.posts')
        .toList();
    expect(pages.length, 2);
    expect(pages.last.body['cursor'], 'next');
    final list = tester.state<RecordListState>(find.byType(RecordList));
    expect(list.records.length, 24);
    final refreshing = list.reload();
    expect(list.records.length, 24);
    await refreshing;
    await pumpUI(tester);
    expect(list.records.length, 12);
    await finishProfile(tester, session);
  });
}
