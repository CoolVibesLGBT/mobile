import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coolvibes/app.dart';
import 'package:coolvibes/components/chat_list_row.dart';
import 'package:coolvibes/components/message_preview.dart';
import 'package:coolvibes/core/api.dart';
import 'package:coolvibes/core/realtime.dart';
import 'package:coolvibes/core/session.dart';
import 'package:coolvibes/debug/preview_api.dart';
import 'package:coolvibes/l10n/l10n.dart';
import 'package:coolvibes/screens/chat.dart';
import 'realtime_test.dart' show TestSocket;
import 'support/ui_driver.dart';

Json attachment(String mime, {String? name}) => {
  'id': 'last',
  'content': <String, dynamic>{},
  'media': <Json>[],
  'attachments': [
    {
      'file': {'mime_type': mime, 'url': '/static/fixture', 'name': ?name},
    },
  ],
};

class LastMessageApi extends PreviewApi {
  List<Json> chats = [
    {...previewChat, 'last_message': attachment('audio/mp4')},
  ];
  int listCalls = 0;
  LastMessageApi() : super(PreviewState.populated);
  @override
  Future<Json> call(
    String action, {
    Json body = const {},
    bool get = false,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    Duration? receiveTimeout,
  }) async {
    if (action == 'chat.fetch_chats') {
      listCalls++;
      return {
        'data': {'chats': chats},
      };
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

void main() {
  for (final language in ['tr', 'en', 'ar']) {
    testWidgets(
      'last message renders text, media and protected labels in $language',
      (tester) async {
        final session =
            Session(PreviewApi(PreviewState.empty), persistPreferences: false)
              ..ready = true
              ..user = previewSelf
              ..locale = Locale(language);
        late BuildContext context;
        await tester.pumpWidget(
          CoolvibesApp(
            session: session,
            home: Builder(
              builder: (value) {
                context = value;
                return const SizedBox();
              },
            ),
          ),
        );
        final l = context.l10n;
        final cases = <(Json, String)>[
          ({'content': lexical('Merhaba\n\nCoolvibes')}, 'Merhaba Coolvibes'),
          ({'content': jsonEncode(lexical('JSON message'))}, 'JSON message'),
          (
            {
              'content': jsonEncode({'fr': 'Bonjour'}),
            },
            'Bonjour',
          ),
          (
            {
              'content': {language: '', 'fr': 'Bonjour'},
            },
            'Bonjour',
          ),
          (
            {
              'content': {language: 'Yerel', 'en': 'Fallback'},
            },
            language == 'en' ? 'Fallback' : 'Yerel',
          ),
          (attachment('image/jpeg'), l.photo),
          (attachment('video/mp4'), l.video),
          (attachment('audio/mp4'), l.voiceMessage),
          (attachment('application/pdf', name: 'Plan.pdf'), 'Plan.pdf'),
          (attachment('application/octet-stream'), l.file),
          (attachment('image/gif'), 'GIF'),
          (
            {
              ...attachment('image/jpeg'),
              'content': {'en': 'Caption'},
            },
            'Caption',
          ),
          (
            {
              'content': '',
              'attachments': [
                {
                  'file': {'url': '/voice.m4a'},
                },
              ],
            },
            l.voiceMessage,
          ),
          (
            {
              'content': '',
              'emoticon': {'kind': 'gif', 'url': '/animation.gif'},
            },
            'GIF',
          ),
          (
            {
              'content': '',
              'extras': jsonEncode({
                'emoticon': {
                  'kind': 'sticker',
                  'url': '/sticker.webp',
                  'emoji': '🦆',
                },
              }),
            },
            '${l.sticker} 🦆',
          ),
          (
            {
              'content': 'https://maps.google.com/?q=41,29',
              'location': {'latitude': 41, 'longitude': 29},
            },
            l.location,
          ),
          (
            {
              ...attachment('image/jpeg'),
              'view_once': true,
              'content': 'private caption',
            },
            l.chatViewOncePhoto,
          ),
          (
            {
              ...attachment('video/mp4'),
              'content_hidden': 'true',
              'content': 'private text',
            },
            l.chatHiddenMessage,
          ),
          ({'id': 'redacted', 'content': {}}, l.message),
          ({}, ''),
        ];
        for (var index = 0; index < cases.length; index++) {
          final (message, expected) = cases[index];
          final chat = {...previewChat, 'last_message': message};
          expect(
            chatRow(context, chat, onTap: () {}).preview,
            expected,
            reason: 'case $index',
          );
          expect(
            messagePreview(context, message),
            expected,
            reason: 'shared case $index',
          );
        }
        expect(
          chatRow(context, {
            ...previewChat,
            'type': 'group',
            'last_message': {
              ...attachment('audio/mp4'),
              'author_id': previewSelf['public_id'],
            },
          }, onTap: () {}).preview,
          '${l.you}: ${l.voiceMessage}',
        );
        expect(
          chatRow(context, {
            ...previewChat,
            'type': 'group',
            'last_message': {
              'content': 'Hello',
              'sender': {'displayname': 'Ege'},
            },
          }, onTap: () {}).preview,
          'Ege: Hello',
        );
        for (final chat in [
          {'last_message_text': 'Old API'},
          {'last_message': 'Old API'},
          {
            'last_message': jsonEncode({'content': 'Old API'}),
          },
        ]) {
          expect(chatRow(context, chat, onTap: () {}).preview, 'Old API');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      },
    );
  }

  testWidgets(
    'socket send, edit and delete refresh previews and order; typing does not',
    (tester) async {
      final api = LastMessageApi(), socket = TestSocket();
      final realtime = AppRealtime(createSocket: (_, _) => socket);
      final session =
          Session(api, persistPreferences: false, realtime: realtime)
            ..ready = true
            ..user = previewSelf;
      await tester.pumpWidget(
        CoolvibesApp(session: session, home: const ChatsScreen()),
      );
      await pumpUI(tester);
      expect(find.text('Sesli mesaj'), findsOneWidget);
      realtime.connect(url: 'http://socket.test', token: 'test');
      socket.receive('auth:ack', {'success': true});
      await pumpUI(tester);
      final before = api.listCalls;
      socket.receive('chat', {
        'action': 'chat.typing',
        'chat_id': previewChat['id'],
      });
      await pumpUI(tester);
      expect(api.listCalls, before);
      api.chats = [
        {
          ...previewChat,
          'id': 'second',
          'public_id': '3002',
          'last_message': {'content': 'Yeni mesaj'},
        },
        {...previewChat, 'last_message': attachment('audio/mp4')},
      ];
      socket.receive(
        'chat',
        jsonEncode({
          'action': 'chat.send_message',
          'message': {'id': 'new'},
        }),
      );
      await pumpUI(tester);
      expect(
        tester
            .widgetList<ChatListRow>(find.byType(ChatListRow))
            .map((row) => row.preview),
        ['Yeni mesaj', 'Sesli mesaj'],
      );
      api.chats = [
        {
          ...api.chats.first,
          'last_message': {'content': 'Düzenlendi'},
        },
      ];
      socket.receive('chat', {'action': 'chat.edit_message'});
      await pumpUI(tester);
      expect(find.text('Düzenlendi'), findsOneWidget);
      expect(find.text('Yeni mesaj'), findsNothing);
      api.chats = [
        {...api.chats.first, 'last_message': null},
      ];
      socket.receive('chat', {'action': 'chat.delete_messages'});
      await pumpUI(tester);
      expect(
        tester.widget<ChatListRow>(find.byType(ChatListRow)).preview,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    },
  );
}
