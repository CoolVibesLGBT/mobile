import 'dart:math' as math;
import '../l10n/l10n.dart';
import 'dart:async';
import '../core/chat_data.dart';
import '../core/geo.dart';
import '../core/attachments.dart';
import '../components/chat_input.dart';
import '../components/message_field.dart';
import '../components/chat_wallpaper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../design/app_design.dart';
import '../components/glass_surface.dart';
import 'profile.dart';
import '../core/api.dart';
import '../core/app_failure.dart';
import '../core/session.dart';
import '../core/realtime.dart';
import '../components/connection_status.dart';
import '../components/components.dart';
import '../components/workspace_menu.dart';
import '../components/chat_bubble.dart';
import '../components/message_preview.dart';
import '../components/chat_list_row.dart';
import 'app_forms.dart';
import 'settings.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});
  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final list = GlobalKey<RecordListState>();
  final mutedOverrides = <String, bool>{}, pinnedOverrides = <String, bool>{};

  @override
  Widget build(BuildContext context) => AppScaffold(
    extendBodyBehindAppBar: true,
    backgroundColor: AppPalette.of(context).row,
    appBar: AppHeader(
      leading: const WorkspaceMenuButton(),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.messages),
          if (connectionStatus(context) case final String status)
            Text(
              status,
              style: AppDesign.font(
                11,
                color: AppPalette.of(context).secondaryLabel,
              ),
            ),
        ],
      ),
      actions: [
        AppIconButton(
          tooltip: context.l10n.activity,
          icon: const Icon(Icons.notifications_none),
          onPressed: () => open(context, const ActivityScreen()),
        ),
        AppIconButton(
          tooltip: context.l10n.newMessage,
          icon: const Icon(Icons.edit_square),
          onPressed: () => open(context, const NewChatScreen()),
        ),
      ],
    ),
    body: ColoredBox(
      color: AppPalette.of(context).row,
      child: RecordList(
        key: list,
        action: 'chat.fetch_chats',
        itemBuilder: (context, chat, reload) {
          final id = chatEntityId(chat);
          final info = ChatRowInfo.of(context, chat);
          final muted = mutedOverrides[id] ?? info.muted;
          final pinned = pinnedOverrides[id] ?? info.pinned;
          return chatRow(
            context,
            chat,
            muted: muted,
            pinned: pinned,
            preview: (_) => ChatScreen(chat: chat, preview: true),
            onTap: () async {
              await open(context, ChatScreen(chat: chat));
              if (mounted) list.currentState?.reload();
            },
            // Local, like the source handleTogglePin.
            onPin: () => setState(() => pinnedOverrides[id] = !pinned),
            onMute: () async {
              setState(() => mutedOverrides[id] = !muted);
              try {
                await AppScope.of(context).api.call(
                  'chat.set_muted',
                  body: {'chat_id': id, 'muted': (!muted).toString()},
                );
              } catch (error) {
                if (mounted) {
                  setState(() => mutedOverrides[id] = muted);
                  if (context.mounted) {
                    await perform(context, () => Future<void>.error(error));
                  }
                }
              }
            },
            onDelete: () => perform(context, () async {
              await AppScope.of(
                context,
              ).api.call('chat.delete_chat_for_user', body: {'chat_id': id});
              reload();
            }),
          );
        },
      ),
    ),
  );
}

/// Muted/pinned state of a chat for the current user.
class ChatRowInfo {
  final bool muted, pinned;
  const ChatRowInfo(this.muted, this.pinned);
  factory ChatRowInfo.of(BuildContext context, Json chat) {
    final self = AppScope.of(context).user;
    final participant =
        (chat['participants'] is List
                ? (chat['participants'] as List).map(object)
                : const <Json>[])
            .where(
              (p) => userIdentities(
                object(p['user'] ?? p),
              ).intersection(userIdentities(self)).isNotEmpty,
            )
            .firstOrNull;
    const truthy = [true, 1, '1', 'true'];
    return ChatRowInfo(
      truthy.contains(participant?['is_muted'] ?? chat['is_muted']),
      truthy.contains(chat['is_pinned']),
    );
  }
}

/// One chat-list row for the Chats tab and the forward picker (Telegram
/// reuses ChatListNode in PeerSelectionController).
ChatListRow chatRow(
  BuildContext context,
  Json chat, {
  required VoidCallback onTap,
  bool muted = false,
  bool pinned = false,
  bool? selected,
  WidgetBuilder? preview,
  VoidCallback? onPin,
  VoidCallback? onMute,
  VoidCallback? onDelete,
}) {
  final self = AppScope.of(context).user;
  final peer = chatPeer(chat, self);
  final last = chatLastMessage(chat);
  final group = chat['type'] == 'group';
  final language = Localizations.localeOf(context).languageCode;
  final participant =
      (chat['participants'] is List
              ? (chat['participants'] as List).map(object)
              : const <Json>[])
          .where(
            (p) => userIdentities(
              object(p['user'] ?? p),
            ).intersection(userIdentities(self)).isNotEmpty,
          )
          .firstOrNull;
  final body = messagePreview(context, last);
  final authorName = !group
      ? ''
      : messageIsMine(last, self)
      ? context.l10n.you
      : messageAuthorName(last);
  return ChatListRow(
    key: ValueKey(chatEntityId(chat)),
    avatar: group ? chat : peer,
    conversationPreview: preview,
    name: chatTitle(chat, self, language: language),
    preview: authorName.isNotEmpty && body.isNotEmpty
        ? '$authorName: $body'
        : body,
    time: chatListDate(
      context,
      chat['last_message_timestamp'] ??
          last['created_at'] ??
          chat['updated_at'],
    ),
    unread:
        num.tryParse(
          string(
            participant?['unread_count'] ??
                chat['unread_count'] ??
                chat['unread'],
          ),
        )?.toInt() ??
        0,
    group: group,
    online:
        !group &&
        [true, 1, '1', 'true'].contains(peer['is_online'] ?? peer['online']),
    muted: muted,
    pinned: pinned,
    selected: selected,
    onTap: onTap,
    onPin: onPin,
    onMute: onMute,
    onDelete: onDelete,
  );
}

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});
  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  String query = '';
  final title = TextEditingController();
  final selected = <String, Json>{};
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(
      title: Text(context.l10n.newConversation),
      actions: [
        AppButton.text(
          onPressed: selected.isEmpty
              ? null
              : () => perform(context, () async {
                  final chat = await createConversation(
                    AppScope.of(context).api,
                    selected.keys.toList(),
                    title: title.text.trim(),
                  );
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ChatScreen(chat: chat),
                      ),
                    );
                  }
                }),
          child: Text(context.l10n.create),
        ),
      ],
    ),
    body: Column(
      children: [
        AppSearchField(
          placeholder: context.l10n.searchUsers,
          onSearch: (value) => setState(() => query = value),
        ),
        if (selected.length > 1)
          AppSection(
            children: [
              AppField(controller: title, label: context.l10n.groupTitle),
            ],
          ),
        Expanded(
          child: RecordList(
            action: query.isEmpty ? 'user.friend.fetch' : 'search.user.lookup',
            params: query.isEmpty ? {'scope': 'friends'} : {'query': query},
            itemBuilder: (context, raw, _) {
              final user = userRecord(raw);
              return PersonTile(
                person: user,
                selected: selected.containsKey(recordId(user)),
                onSelected: (v) => setState(() {
                  if (v == true) {
                    selected[recordId(user)] = user;
                  } else {
                    selected.remove(recordId(user));
                  }
                }),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// Messages chosen for forwarding (Telegram ChatInterfaceForwardOptionsState):
/// shown above the composer of the target chat until sent or cancelled.
class ChatForward {
  final String sourceChatId;
  final List<Json> messages;
  const ChatForward({required this.sourceChatId, required this.messages});
  List<String> get ids => messages.map(chatEntityId).toList();

  Future<List<Json>> sendTo(
    Api api,
    String target, {
    String comment = '',
  }) async {
    final response = await api.call(
      'chat.forward_messages',
      body: {
        'source_chat_id': sourceChatId,
        'chat_id': target,
        'message_ids[]': ids,
        if (comment.isNotEmpty) 'content': comment,
      },
    );
    final data = object(response['data']);
    final rows = data['messages'] ?? response['messages'];
    if (rows is! List || rows.isEmpty) {
      throw ApiException('Invalid forwarding response');
    }
    return rows.map(object).toList();
  }
}

class ChatScreen extends StatefulWidget {
  final Json chat;
  final bool preview;
  final ChatForward? forward;
  const ChatScreen({
    super.key,
    required this.chat,
    this.preview = false,
    this.forward,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final inputFocus = FocusNode();
  String? beforeEditing;
  final scroll = ScrollController();
  final footerKey = GlobalKey();
  double footerHeight = 90;
  final mediaExpansion = ValueNotifier(0.0);
  bool selecting = false, selectionBusy = false;
  final selectedIds = <String>{};
  late ChatForward? forwarding = widget.forward;

  /// Telegram multi-pin: every pinned message, oldest first, and the one the
  /// pinned bar shows (it steps back through history on each tap).
  final pinned = <Json>[];
  int pinnedIndex = -1;
  String? highlightedId;
  Timer? highlightTimer;

  /// The author's scheduled sends in this chat (Telegram calendar accessory).
  final scheduled = <Json>[];

  /// Composer self-destruct timer in seconds (0 = off), as on the web.
  int selfDestruct = 0;
  // Telegram secret-chat timer menu, longest first; 0 turns it off.
  static const selfDestructOptions = [3600, 1200, 300, 60, 0];
  Set<String> get pinnedIds => pinned.map(chatEntityId).toSet();

  /// ChatHistoryListNode selection pan: rows touched by the drag take the
  /// state opposite to the first row's.
  final rowKeys = <String, GlobalKey>{};
  bool? dragSelect;
  Json? messageAt(Offset global) {
    for (final m in messages) {
      final box =
          rowKeys[chatEntityId(m)]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (global.dy >= top && global.dy < top + box.size.height) return m;
    }
    return null;
  }

  void dragSelectAt(Offset global) {
    final m = messageAt(global);
    if (m == null || m['_job_id'] != null) return;
    final messageId = chatEntityId(m);
    dragSelect ??= !selectedIds.contains(messageId);
    final has = selectedIds.contains(messageId);
    if (has != dragSelect) {
      HapticFeedback.selectionClick();
      setState(() {
        if (dragSelect!) {
          selectedIds.add(messageId);
        } else {
          selectedIds.remove(messageId);
        }
      });
    }
  }

  List<Json> get selectedMessages => messages.reversed
      .where((m) => selectedIds.contains(chatEntityId(m)))
      .toList();
  void measureFooter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = footerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null &&
          box.hasSize &&
          (footerHeight - box.size.height).abs() > .5) {
        setState(() => footerHeight = box.size.height);
      }
    });
  }

  void selectMessage(Json message) {
    if (selectionBusy || message['_job_id'] != null) return;
    inputFocus.unfocus();
    HapticFeedback.selectionClick();
    setState(() {
      selecting = true;
      final messageId = chatEntityId(message);
      if (!selectedIds.add(messageId)) selectedIds.remove(messageId);
    });
  }

  void endSelection() => setState(() {
    selecting = false;
    selectedIds.clear();
  });

  /// Telegram forward: pick a chat, then its composer shows the forwarded
  /// messages and sends them with an optional comment.
  Future<void> forwardMessages(List<Json> chosen) async {
    if (chosen.isEmpty || selectionBusy) return;
    final draft = ChatForward(sourceChatId: id, messages: chosen);
    final result = await sheet<ForwardResult>(
      context,
      ForwardScreen(draft: draft),
    );
    if (!mounted || result == null) return;
    if (selecting) endSelection();
    final target = result.chat;
    if (target == null) {
      setState(
        () => merge(
          result.messages.where((m) => string(m['chat_id']) == id).toList(),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.forwardedToChats(result.sentCount)),
        ),
      );
      return;
    }
    if (chatEntityId(target) == id) {
      setState(() {
        cancelEditing();
        reply = null;
        forwarding = draft;
      });
      inputFocus.requestFocus();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(chat: target, forward: draft),
      ),
    );
  }

  Future<void> sendForward(ChatForward draft, String comment) async {
    final rows = await draft.sendTo(session!.api, id, comment: comment);
    if (!mounted) return;
    setState(() {
      merge(rows);
      forwarding = null;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> deleteSelection() => deleteMessages(selectedMessages);

  /// Telegram delete confirmation: "Delete for me" and, when every message
  /// is the user's own, "Delete for everyone".
  Future<void> deleteMessages(List<Json> chosen) async {
    if (chosen.isEmpty || selectionBusy) return;
    final allMine = chosen.every(
      (m) => messageIsMine(m, session!.user) && m['_job_id'] == null,
    );
    final action = await showInfoSheet<String>(
      context,
      AppConfirmationSheet(
        title: chosen.length == 1
            ? context.l10n.deleteMessage
            : context.l10n.deleteMessages(chosen.length),
        message: allMine
            ? context.l10n.deleteMessagesScopeInfo
            : context.l10n.deleteMessagesForMeInfo,
        actions: [
          AppConfirmationAction(
            label: context.l10n.deleteForMe,
            result: 'chat.delete_message_for_user',
          ),
          if (allMine)
            AppConfirmationAction(
              label: context.l10n.deleteForEveryone,
              result: 'chat.delete_message_for_all',
            ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    setState(() => selectionBusy = true);
    try {
      for (final message in chosen) {
        final messageId = chatEntityId(message);
        final job = session!.uploads.jobs
            .where((j) => j.id == message['_job_id'])
            .firstOrNull;
        if (job != null) {
          await session!.uploads.remove(job);
        } else {
          await session!.api.call(
            action,
            body: {'chat_id': id, 'message_id': messageId},
          );
        }
        if (!mounted) return;
        setState(() {
          messages.removeWhere((m) => chatEntityId(m) == messageId);
          selectedIds.remove(messageId);
        });
      }
      if (mounted && selecting) endSelection();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => selectionBusy = false);
    }
  }

  final messages = <Json>[];
  final attachments = AttachmentController();
  Timer? typingTimer;
  Timer? draftTimer;
  Future<void> draftWrites = Future<void>.value();
  DateTime lastTyping = DateTime.fromMillisecondsSinceEpoch(0);
  String? pendingClientId;
  StreamSubscription<Json>? uploadEvents;
  StreamSubscription<RealtimeEvent>? liveEvents;
  String get draftKey =>
      'coolvibes.chat.draft.${session?.user['public_id'] ?? session?.user['id']}.$id';
  String? cursor, error;
  Json? reply, editing, replyBeforeEditing;
  bool loading = false, sending = false, peerTyping = false;
  Session? session;
  String get id => chatEntityId(widget.chat);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      session = AppScope.of(context);
      liveEvents = session!.realtime.events.listen((update) {
        if (update.name == 'sync') {
          load();
        } else if (update.name == 'chat' || update.name == 'message') {
          event(update.data);
        }
      });
      if (!widget.preview) restoreDraft();
      uploadEvents = session!.uploads.completed.stream.listen(uploadCompleted);
      session!.uploads.addListener(uploadChanged);
      uploadChanged();
      load();
    });
  }

  Future<void> restoreDraft() async {
    if (session!.api.isPreview) return;
    final saved = await session!.api.storage.read(key: draftKey);
    if (mounted && input.text.isEmpty && saved != null) input.text = saved;
  }

  Future<void> saveDraft({bool clear = false}) {
    if (widget.preview || session == null || session!.api.isPreview) {
      return Future<void>.value();
    }
    final key = draftKey,
        value = editing != null ? beforeEditing ?? input.text : input.text;
    final storage = session!.api.storage;
    draftWrites = draftWrites
        .then(
          (_) => clear
              ? storage.delete(key: key)
              : storage.write(key: key, value: value),
        )
        .catchError((Object _) {});
    return draftWrites;
  }

  void changed(String value) {
    pendingClientId = null;
    draftTimer?.cancel();
    draftTimer = Timer(const Duration(milliseconds: 350), () {
      saveDraft();
    });
    if (DateTime.now().difference(lastTyping).inMilliseconds > 2000) {
      lastTyping = DateTime.now();
      session!.api
          .call('chat.typing', body: {'chat_id': id})
          .catchError((_) => <String, dynamic>{});
    }
  }

  void event(dynamic raw) {
    final data = socketPayload(raw);
    final payload = socketPayload(data['data'] ?? data);
    final message = socketPayload(payload['message'] ?? payload);
    final chatId = string(
      message['chat_id'] ??
          message['contentable_id'] ??
          payload['chat_id'] ??
          payload['chatID'] ??
          payload['chatId'] ??
          data['chat_id'] ??
          data['chatID'],
    );
    if (chatId != id) return;
    final action = string(data['action'] ?? payload['action']);
    if (action == 'chat.typing' || payload['typing'] != null) {
      final user = string(
        payload['user_id'] ?? payload['userID'] ?? payload['userId'],
      );
      if (userIdentities(session!.user).contains(user)) return;
      typingTimer?.cancel();
      setState(() => peerTyping = payload['typing'] == true);
      if (peerTyping) {
        typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => peerTyping = false);
        });
      }
      return;
    }
    if (action == 'chat.message_read') {
      final ids = (payload['message_ids'] as List? ?? []).map(string).toSet();
      setState(() {
        for (final m in messages) {
          if (ids.contains(chatEntityId(m))) m['status'] = 'read';
        }
      });
      return;
    }
    if (action == 'chat.pin_message' || action == 'chat.unpin_message') {
      load();
      return;
    }
    if (action == 'chat.message_expired') {
      final expired = string(payload['message_id'] ?? message['id']);
      setState(() => messages.removeWhere((m) => chatEntityId(m) == expired));
      return;
    }
    if (action == 'chat.delete_message_for_all' ||
        action == 'chat.delete_message') {
      final deleted = string(payload['message_id'] ?? message['id']);
      setState(() => messages.removeWhere((m) => chatEntityId(m) == deleted));
      return;
    }
    if (chatEntityId(message).isEmpty ||
        message['content'] == null &&
            message['attachments'] == null &&
            messageEmoticon(message) == null &&
            messageForwardOrigin(message) == null) {
      return;
    }
    if (mounted) {
      setState(() => merge([message]));
      markRead([message]);
    }
  }

  void merge(List<Json> incoming) {
    for (final message in incoming) {
      final index = messages.indexWhere(
        (m) =>
            chatEntityId(m) == chatEntityId(message) ||
            (message['client_id'] != null &&
                m['client_id'] == message['client_id']),
      );
      if (index < 0) {
        messages.add(message);
      } else {
        messages[index] = {...messages[index], ...message};
      }
    }
    messages.sort(
      (a, b) => string(b['created_at']).compareTo(string(a['created_at'])),
    );
  }

  /// ChatDetail normalizeMessage/replySnapshot: the quoted message comes
  /// from `parent`, or from the loaded history by `reply_to`/`parent_id`
  /// (optimistic sends and echoes that omit it). Its author reads "You"
  /// for own messages and the chat partner otherwise; hidden or view-once
  /// parents are not quoted.
  Json withReply(Json message, Json self, Json peer) {
    final ref = message['reply_to'] is Map
        ? object(message['reply_to'])
        : message['parent'] is Map
        ? object(message['parent'])
        : null;
    final parentId = string(
      ref == null
          ? message['reply_to'] ?? message['parent_id']
          : chatEntityId(ref),
    );
    if (parentId.isEmpty) return message;
    final loaded = messages
        .where((m) => chatEntityId(m) == parentId)
        .firstOrNull;
    final parent = {...?loaded, ...?ref};
    const yes = [true, 1, '1', 'true'];
    if (parent.isEmpty ||
        yes.contains(parent['content_hidden']) ||
        yes.contains(parent['view_once'])) {
      final rest = {...message}
        ..remove('reply_to')
        ..remove('parent');
      return rest;
    }
    final named = string(
      object(parent['user'])['displayname'] ??
          object(parent['user'])['username'] ??
          object(parent['author'])['displayname'] ??
          object(parent['author'])['username'] ??
          parent['author_name'],
    );
    return {
      ...message,
      'reply_to': {
        ...parent,
        if (named.isEmpty)
          'author_name': messageIsMine(parent, self)
              ? context.l10n.you
              : string(peer['displayname'] ?? peer['name'] ?? peer['username']),
      },
    };
  }

  Future<void> markRead(List<Json> rows) async {
    if (widget.preview || !mounted || !TickerMode.valuesOf(context).enabled) {
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final ids = rows
        .map(chatEntityId)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    try {
      await session!.api.call(
        'chat.message_read',
        body: {'chat_id': id, 'message_ids[]': ids},
      );
    } catch (_) {}
  }

  void setPinned(List<Json> rows) {
    final ids = rows.map(chatEntityId).toSet();
    pinned
      ..clear()
      ..addAll(rows);
    if (pinnedIndex < 0 || pinnedIndex >= pinned.length) {
      pinnedIndex = pinned.length - 1;
    }
    for (final m in messages) {
      m['pinned'] = ids.contains(chatEntityId(m));
    }
  }

  Future<void> loadScheduled() async {
    if (widget.preview) return;
    try {
      final result = await session!.api.call(
        'chat.fetch_scheduled_messages',
        body: {'chat_id': id},
      );
      final data = object(result['data']);
      final rows = (data['messages'] ?? result['messages']) as List? ?? [];
      if (mounted) {
        setState(() {
          scheduled
            ..clear()
            ..addAll(rows.map(object));
        });
      }
    } catch (_) {
      // Older services have no scheduled list; the accessory stays hidden.
    }
  }

  /// Telegram pinned bar tap: scroll to the shown pin (loading older pages
  /// when needed), flash it, then show the previous pin.
  Future<void> openPinned() async {
    if (pinned.isEmpty) return;
    final target = chatEntityId(
      pinned[pinnedIndex.clamp(0, pinned.length - 1)],
    );
    var pages = 0;
    while (!messages.any((m) => chatEntityId(m) == target) &&
        cursor != null &&
        pages++ < 20 &&
        mounted) {
      await load(older: true);
    }
    if (!mounted) return;
    final index = messages.indexWhere((m) => chatEntityId(m) == target);
    if (index >= 0 && scroll.hasClients) {
      final key = rowKeys[target];
      if (key?.currentContext == null) {
        await scroll.animateTo(
          (index * 64.0).clamp(0, scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        await WidgetsBinding.instance.endOfFrame;
      }
      final context = rowKeys[target]?.currentContext;
      if (context != null && context.mounted) {
        await Scrollable.ensureVisible(
          context,
          alignment: .5,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      highlightTimer?.cancel();
      setState(() => highlightedId = target);
      highlightTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => highlightedId = null);
      });
    }
    if (mounted && pinned.length > 1) {
      setState(
        () => pinnedIndex = (pinnedIndex - 1) < 0
            ? pinned.length - 1
            : pinnedIndex - 1,
      );
    }
  }

  /// Telegram secret/disappearing content: opening starts the timer.
  Future<void> openDisappearing(Json message) => perform(context, () async {
    final result = await session!.api.call(
      'chat.message.open',
      body: {'chat_id': id, 'message_id': chatEntityId(message)},
    );
    final data = object(result['data']);
    final opened = object(data['message'] ?? result['message'] ?? data);
    if (!mounted || chatEntityId(opened).isEmpty) return;
    setState(() => merge([opened]));
    scheduleExpiry(opened);
  });

  final expiryTimers = <String, Timer>{};
  void scheduleExpiry(Json message) {
    final at = DateTime.tryParse(string(message['expires_at']));
    if (at == null) return;
    final key = chatEntityId(message);
    expiryTimers[key]?.cancel();
    final wait = at.difference(DateTime.now());
    expiryTimers[key] = Timer(wait.isNegative ? Duration.zero : wait, () {
      if (mounted) {
        setState(() => messages.removeWhere((m) => chatEntityId(m) == key));
      }
    });
  }

  Future<void> chooseSchedule() async {
    final at = await sheet<DateTime>(context, const ScheduleMessageSheet());
    if (at != null && mounted) await send(scheduledAt: at);
  }

  String selfDestructLabel(int seconds) => switch (seconds) {
    0 => context.l10n.off,
    60 => context.l10n.n1Minute,
    300 => context.l10n.n5Minutes,
    1200 => context.l10n.n20Minutes,
    _ => context.l10n.n1Hour,
  };

  /// The timer menu items, the current one checked.
  List<AppMenuItem> selfDestructItems() => [
    for (final option in selfDestructOptions)
      AppMenuItem(
        title: selfDestructLabel(option),
        symbol: option == 0 ? 'xmark' : 'timer',
        checked: option == selfDestruct,
        separatorBefore: option == 0,
        onPressed: () => setState(() => selfDestruct = option),
      ),
  ];

  final selfDestructMenu = GlobalKey<AppContextMenuState>();
  void chooseSelfDestruct() => selfDestructMenu.currentState?.open();

  Future<void> load({bool older = false}) async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final res = await session!.api.call(
        'chat.fetch_messages',
        body: {
          'chat_id': id,
          'limit': 50,
          if (older && cursor != null) 'cursor': cursor,
        },
      );
      final page = RecordPage.parse(res);
      if (!mounted) return;
      final data = object(res['data']);
      final pins = data['pinned_messages'] ?? res['pinned_messages'];
      setState(() {
        merge(page.records);
        cursor = page.next;
        if (pins is List) setPinned(pins.map(object).toList());
      });
      if (!older) loadScheduled();
      markRead(page.records);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void uploadChanged() {
    if (!mounted || session == null) return;
    final self = session!.user;
    setState(() {
      for (final job in session!.uploads.jobs.where(
        (j) =>
            j.action == 'chat.send_message' &&
            string(j.fields['chat_id']) == id &&
            // Scheduled sends live in the scheduled list, not the history.
            string(j.fields['scheduled_at']).isEmpty &&
            j.status != 'done',
      )) {
        final existing = messages
            .where((m) => m['client_id'] == job.id)
            .firstOrNull;
        merge([
          {
            'id': existing?['id'] ?? 'local-${job.id}',
            'client_id': job.id,
            '_job_id': job.id,
            'author_id': self['public_id'] ?? self['id'],
            'content': job.fields['content'],
            if (job.fields['reply_to'] != null)
              'reply_to': job.fields['reply_to'],
            'status': job.status,
            'error': job.error,
            if (job.fields['location[lat]'] != null)
              'location': {
                'latitude': job.fields['location[lat]'],
                'longitude': job.fields['location[lng]'],
                'address': job.fields['location[address]'],
              },
            'created_at':
                existing?['created_at'] ??
                DateTime.now().toUtc().toIso8601String(),
            if (job.fields['extras'] != null) 'extras': job.fields['extras'],
            if (object(job.fields['extras'])['emoticon'] != null)
              'emoticon': object(job.fields['extras'])['emoticon'],
            if (job.files.isNotEmpty)
              'attachments': [
                for (final f in job.files)
                  {
                    'localPath': f['path'],
                    'file': {'name': f['name'], 'mime_type': f['mime']},
                    'duration': ?f['duration'],
                    'waveform': ?f['waveform'],
                  },
              ],
          },
        ]);
      }
    });
  }

  void uploadCompleted(Json event) {
    if (!mounted ||
        event['action'] != 'chat.send_message' ||
        string(object(event['fields'])['chat_id']) != id) {
      return;
    }
    final result = object(event['result']);
    final data = object(result['data']);
    final raw = object(data['message'] ?? result['message'] ?? data);
    if (chatEntityId(raw).isEmpty) {
      load();
      return;
    }
    if (string(raw['scheduled_at']).isNotEmpty ||
        string(object(event['fields'])['scheduled_at']).isNotEmpty) {
      setState(() => scheduled.add(raw));
      return;
    }
    // chatMessages merge: `replyTo: message.replyTo ?? previous.replyTo`.
    if (raw['parent'] is! Map) raw.remove('parent');
    setState(
      () => merge([
        {
          ...raw,
          'client_id': raw['client_id'] ?? event['job_id'],
          'status': raw['status'] ?? 'sent',
          '_job_id': null,
        },
      ]),
    );
    markRead([raw]);
  }

  Future<void> retry(Json message) async {
    final job = session!.uploads.jobs
        .where((j) => j.id == message['_job_id'])
        .firstOrNull;
    if (job != null) await session!.uploads.retry(job);
  }

  Future<void> enqueueMessage(
    Json body,
    List<Json> files, {
    String? clientId,
  }) async {
    final queue = session!.uploads;
    if (queue.owner.isEmpty) {
      await queue.attach(
        string(session!.user['public_id'] ?? session!.user['id']),
      );
    }
    final key = clientId ?? 'flutter-${DateTime.now().microsecondsSinceEpoch}';
    await queue.enqueue(
      action: 'chat.send_message',
      title: plainText(body['content']),
      fields: {...body, 'client_id': key},
      files: files,
      clientId: key,
    );
  }

  Future<void> sendEmoticon(Json value) => perform(
    context,
    () => enqueueMessage({
      'chat_id': id,
      'content': '',
      'extras': {'emoticon': value},
      if (reply != null) 'reply_to': chatEntityId(reply!),
    }, []),
  );
  Future<void> send({DateTime? scheduledAt}) async {
    if (widget.preview) return;
    final text = input.text.trim();
    if (forwarding != null && editing == null) {
      if (sending) return;
      final draft = forwarding!, original = input.text;
      setState(() {
        sending = true;
        error = null;
      });
      try {
        await sendForward(draft, text);
        if (!mounted) return;
        if (input.text == original) input.text = '';
        draftTimer?.cancel();
        await saveDraft(clear: input.text.isEmpty);
      } catch (e) {
        if (mounted) setState(() => error = '$e');
      } finally {
        if (mounted) setState(() => sending = false);
      }
      return;
    }
    if (sending ||
        (text.isEmpty && (editing != null || !attachments.hasContent))) {
      return;
    }
    final wasEditing = editing != null;
    final original = input.text;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      final body = <String, dynamic>{
        'chat_id': id,
        'content': text.isEmpty && attachments.location != null
            ? locationMapUrl(attachments.location!)
            : text,
        if (reply != null) 'reply_to': chatEntityId(reply!),
        if (!wasEditing) ...attachments.extraFields(),
        if (!wasEditing && selfDestruct > 0)
          'expires_in_seconds': '$selfDestruct',
        if (!wasEditing && scheduledAt != null)
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
      };
      if (editing != null) {
        body['message_id'] = chatEntityId(editing!);
        final result = await session!.api.call('chat.edit_message', body: body);
        final raw = object(
          object(result['data'])['message'] ??
              result['message'] ??
              result['data'],
        );
        if (!mounted) return;
        if (raw.isNotEmpty) setState(() => merge([raw]));
        await load();
      } else {
        final clientId = pendingClientId ??=
            'flutter-${DateTime.now().microsecondsSinceEpoch}';
        body['client_id'] = clientId;
        await enqueueMessage(
          body,
          attachments.files.map((f) => <String, dynamic>{...f}).toList(),
          clientId: clientId,
        );
      }
      if (!mounted) return;
      draftTimer?.cancel();
      if (input.text == original) {
        input.text = editing != null ? beforeEditing ?? '' : '';
      }
      await saveDraft(clear: input.text.isEmpty);
      if (!mounted) return;
      if (!wasEditing) attachments.clear();
      pendingClientId = null;
      setState(() {
        reply = wasEditing ? replyBeforeEditing : null;
        editing = null;
        beforeEditing = null;
        replyBeforeEditing = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> messageAction(Json message, String action) =>
      perform(context, () async {
        if (message['_job_id'] != null) {
          final job = session!.uploads.jobs
              .where((j) => j.id == message['_job_id'])
              .firstOrNull;
          if (job != null) await session!.uploads.remove(job);
          if (mounted) setState(() => messages.remove(message));
          return;
        }
        await session!.api.call(
          action,
          body: {'chat_id': id, 'message_id': chatEntityId(message)},
        );
        if (!mounted) return;
        setState(() {
          if (action.contains('delete')) {
            messages.remove(message);
          } else if (action == 'chat.pin_message') {
            pinned
              ..removeWhere((m) => chatEntityId(m) == chatEntityId(message))
              ..add(message);
            pinnedIndex = pinned.length - 1;
            message['pinned'] = true;
          } else {
            pinned.removeWhere((m) => chatEntityId(m) == chatEntityId(message));
            pinnedIndex = pinned.length - 1;
            message['pinned'] = false;
          }
        });
      });

  void cancelEditing() {
    if (editing != null) {
      input.text = beforeEditing ?? '';
      reply = replyBeforeEditing;
    }
    replyBeforeEditing = null;
    beforeEditing = null;
    editing = null;
  }

  void replyTo(Json message) {
    setState(() {
      cancelEditing();
      forwarding = null;
      reply = message;
    });
    inputFocus.requestFocus();
  }

  void editMessage(Json message) {
    setState(() {
      if (editing == null) {
        beforeEditing = input.text;
        replyBeforeEditing = reply;
      }
      reply = null;
      editing = message;
      input.text = messageContentText(
        message,
        language: Localizations.localeOf(context).languageCode,
      );
      input.selection = TextSelection.collapsed(offset: input.text.length);
    });
    inputFocus.requestFocus();
  }

  /// Telegram ChatInterfaceStateContextMenus order: Reply, Copy, Edit, Pin,
  /// Forward, (Try again), Delete, then Select after a separator.
  List<AppMenuItem> actionsFor(Json message) {
    final mine = messageIsMine(message, session!.user);
    final queued = message['_job_id'] != null;
    final text = messageContentText(
      message,
      language: Localizations.localeOf(context).languageCode,
    );
    return [
      if (!queued)
        AppMenuItem(
          title: context.l10n.reply2,
          symbol: 'arrowshape.turn.up.left',
          fallback: Icons.reply,
          onPressed: () => replyTo(message),
        ),
      if (text.isNotEmpty)
        AppMenuItem(
          title: context.l10n.copy,
          symbol: 'doc.on.doc',
          fallback: Icons.copy,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: text));
            HapticFeedback.lightImpact();
          },
        ),
      if (mine &&
          text.isNotEmpty &&
          messageEmoticon(message) == null &&
          !queued)
        AppMenuItem(
          title: context.l10n.edit,
          symbol: 'pencil',
          fallback: Icons.edit_outlined,
          onPressed: () => editMessage(message),
        ),
      if (!queued)
        AppMenuItem(
          title: message['pinned'] == true
              ? context.l10n.unpin
              : context.l10n.pin,
          symbol: message['pinned'] == true ? 'pin.slash' : 'pin',
          fallback: Icons.push_pin_outlined,
          onPressed: () => messageAction(
            message,
            message['pinned'] == true
                ? 'chat.unpin_message'
                : 'chat.pin_message',
          ),
        ),
      if (!queued)
        AppMenuItem(
          title: context.l10n.forward,
          symbol: 'arrowshape.turn.up.right',
          fallback: Icons.forward,
          onPressed: () => forwardMessages([message]),
        ),
      if (message['status'] == 'failed')
        AppMenuItem(
          title: context.l10n.tryAgain,
          symbol: 'arrow.clockwise',
          fallback: Icons.refresh,
          onPressed: () => retry(message),
        ),
      if (message['status'] != 'sending')
        AppMenuItem(
          title: context.l10n.deleteLabel,
          symbol: 'trash',
          fallback: Icons.delete_outline,
          destructive: true,
          onPressed: () => deleteMessages([message]),
        ),
      if (!queued)
        AppMenuItem(
          title: context.l10n.select,
          symbol: 'checkmark.circle',
          fallback: Icons.check_circle_outline,
          separatorBefore: true,
          onPressed: () => selectMessage(message),
        ),
    ];
  }

  static DateTime? _created(Json message) =>
      DateTime.tryParse(string(message['created_at']))?.toLocal();
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// messagesAreGrouped(): same sender, no emoticons, within 5 minutes, same day.
  bool grouped(Json? previous, Json? next) {
    if (previous == null || next == null) return false;
    final self = session!.user;
    if (messageIsMine(previous, self) != messageIsMine(next, self)) {
      return false;
    }
    if (!messageIsMine(previous, self)) {
      final a = object(previous['user'] ?? previous['sender']);
      final b = object(next['user'] ?? next['sender']);
      if (string(a['public_id'] ?? a['id'] ?? previous['user_id']) !=
          string(b['public_id'] ?? b['id'] ?? next['user_id'])) {
        return false;
      }
    }
    if (previous['emoticon'] != null || next['emoticon'] != null) return false;
    final from = _created(previous), to = _created(next);
    if (from == null || to == null) return false;
    final distance = to.difference(from);
    return !distance.isNegative &&
        distance <= const Duration(minutes: 5) &&
        _sameDay(from, to);
  }

  @override
  void dispose() {
    liveEvents?.cancel();
    uploadEvents?.cancel();
    highlightTimer?.cancel();
    for (final timer in expiryTimers.values) {
      timer.cancel();
    }
    session?.uploads.removeListener(uploadChanged);
    draftTimer?.cancel();
    saveDraft();
    typingTimer?.cancel();
    attachments.dispose();
    input.dispose();
    inputFocus.dispose();
    mediaExpansion.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final self = AppScope.of(context).user;
    final language = Localizations.localeOf(context).languageCode;
    final group = widget.chat['type'] == 'group';
    final title = chatTitle(widget.chat, self, language: language).isEmpty
        ? context.l10n.chat2
        : chatTitle(widget.chat, self, language: language);
    final peer = chatPeer(widget.chat, self);
    final onlineValue = peer['is_online'] ?? peer['online'];
    final online = [true, 1, '1', 'true'].contains(onlineValue);
    final status =
        connectionStatus(context) ??
        (group
            ? ''
            : peerTyping
            ? context.l10n.typing
            : online
            ? context.l10n.online
            : lastSeenLabel(context, peer['last_online']));
    final active = connectionStatus(context) == null && (peerTyping || online);
    void openPeer() => group
        ? open(context, GroupScreen(chat: widget.chat))
        : open(context, ProfileScreen(user: peer));
    final top =
        MediaQuery.paddingOf(context).top + AppDesign.headerInset(context);
    measureFooter();
    // The list reads its own inset below; keep `top` for the reversed list.
    return AppScaffold(
      extendBodyBehindAppBar: true,
      backgroundProgress: mediaExpansion,
      bottomOverlayHeight: footerHeight,
      bottomOverlay: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (_) {
          measureFooter();
          return false;
        },
        child: SizeChangedLayoutNotifier(
          key: footerKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: GestureDetector(
                    onTap: load,
                    child: Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: AppDesign.font(13, color: palette.destructive),
                    ),
                  ),
                ),
              // ChatMessageSelectionInputPanelNode: 40pt glass
              // circles, delete leading and forward trailing, 8pt plus
              // the composer side inset from the edges.
              if (!widget.preview && selecting)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Row(
                      children: [
                        AppIconButton(
                          glass: true,
                          dimension: 40,
                          tooltip: context.l10n.deleteSelectedMessages,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: selectionBusy || selectedMessages.isEmpty
                              ? null
                              : deleteSelection,
                        ),
                        const Spacer(),
                        if (selectionBusy)
                          const CircularProgressIndicator.adaptive(),
                        const Spacer(),
                        AppIconButton(
                          glass: true,
                          dimension: 40,
                          tooltip: context.l10n.forwardSelectedMessages,
                          icon: const Icon(Icons.forward),
                          onPressed: selectionBusy || selectedMessages.isEmpty
                              ? null
                              : () => forwardMessages(selectedMessages),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!widget.preview && !selecting)
                ChatInput(
                  focusNode: inputFocus,
                  onPanelExpansionChanged: (value) {
                    if (mounted) mediaExpansion.value = value;
                  },
                  controller: input,
                  attachments: attachments,
                  sending: sending,
                  editing: editing != null,
                  onSend: send,
                  hasExtraContent: forwarding != null && editing == null,
                  sendOptions: forwarding != null
                      ? const []
                      : [
                          AppMenuItem(
                            title: context.l10n.scheduleMessage,
                            symbol: 'calendar',
                            fallback: Icons.calendar_month_outlined,
                            onPressed: chooseSchedule,
                          ),
                          AppMenuItem(
                            title: context.l10n.selfDestructTimer2,
                            symbol: 'timer',
                            fallback: Icons.timer_outlined,
                            onPressed: chooseSelfDestruct,
                          ),
                        ],
                  // Show the timer only when active; it remains available
                  // in the send menu without squeezing the idle editor.
                  accessory: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (selfDestruct != 0)
                        AppContextMenu(
                          key: selfDestructMenu,
                          pressTrigger: true,
                          liftContent: false,
                          align: AppMenuAlign.right,
                          label: selfDestruct == 0
                              ? context.l10n.selfDestructTimer
                              : '${context.l10n.selfDestructTimer}: ${selfDestructLabel(selfDestruct)}',
                          items: selfDestructItems(),
                          child: SizedBox.square(
                            dimension: 44,
                            child: Icon(
                              selfDestruct == 0
                                  ? CupertinoIcons.timer
                                  : CupertinoIcons.timer_fill,
                              size: 24,
                              color: selfDestruct == 0
                                  ? palette.secondaryLabel
                                  : palette.accent,
                            ),
                          ),
                        ),
                      if (scheduled.isNotEmpty)
                        AppIconButton(
                          glass: false,
                          tooltip: context.l10n.scheduledMessages,
                          color: palette.secondaryLabel,
                          icon: const Icon(
                            Icons.calendar_month_outlined,
                            size: 22,
                          ),
                          onPressed: () async {
                            await open(
                              context,
                              ScheduledMessagesScreen(chat: widget.chat),
                            );
                            if (mounted) loadScheduled();
                          },
                        ),
                    ],
                  ),
                  onChanged: changed,
                  onSendEmoticon: sendEmoticon,
                  helper: editing != null
                      ? _ComposerHelper(
                          kind: _HelperKind.edit,
                          text: messageContentText(
                            editing!,
                            language: Localizations.localeOf(
                              context,
                            ).languageCode,
                          ),
                          onCancel: () => setState(cancelEditing),
                        )
                      : reply != null
                      ? _ComposerHelper(
                          kind: _HelperKind.reply,
                          name: messageIsMine(reply!, self)
                              ? context.l10n.you
                              : messageAuthorName(reply!).isNotEmpty
                              ? messageAuthorName(reply!)
                              : title,
                          text: messagePreview(context, reply!),
                          onCancel: () => setState(() => reply = null),
                        )
                      : forwarding != null
                      ? _ComposerHelper(
                          kind: _HelperKind.forward,
                          count: forwarding!.messages.length,
                          name: forwarding!.messages
                              .map(
                                (m) => messageIsMine(m, self)
                                    ? context.l10n.you
                                    : messageAuthorName(m).isNotEmpty
                                    ? messageAuthorName(m)
                                    : title,
                              )
                              .toSet()
                              .join(', '),
                          text: messagePreview(
                            context,
                            forwarding!.messages.first,
                          ),
                          onCancel: () => setState(() => forwarding = null),
                        )
                      : null,
                ),
            ],
          ),
        ),
      ),
      appBar: AppHeader(
        edge: AppHeaderEdge.none,
        surfaceRole: GlassSurfaceRole.input,
        leading: selecting ? const SizedBox.shrink() : null,
        // WorkspaceTitle (ChatDetail): the name and status in a 44pt glass
        // capsule with 12pt insets, the peer avatar in a 44pt glass circle.
        // Telegram selection title: "N Selected" with Cancel on the right.
        title: selecting
            ? Text(
                selectedMessages.isEmpty
                    ? context.l10n.selectMessages
                    : context.l10n.selected2(selectedMessages.length),
              )
            : GlassButton(
                color: palette.text,
                label: [title, status].where((v) => v.isNotEmpty).join(', '),
                expand: false,
                onPressed: openPeer,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: 44,
                    maxWidth: (MediaQuery.sizeOf(context).width - 152).clamp(
                      120,
                      600,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppDesign.font(
                            17,
                            weight: FontWeight.w600,
                            color: palette.text,
                          ),
                        ),
                        if (status.isNotEmpty)
                          Text(
                            status,
                            maxLines: 1,
                            style: AppDesign.font(
                              13,
                              color: active
                                  ? palette.accent
                                  : palette.secondaryLabel,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        actions: selecting
            ? [
                AppBarTextButton(
                  onPressed: selectionBusy ? null : endSelection,
                  child: Text(context.l10n.cancel2),
                ),
              ]
            : [
                AppIconButton(
                  tooltip: group
                      ? context.l10n.groupInfo
                      : context.l10n.profile,
                  onPressed: openPeer,
                  icon: Avatar(group ? widget.chat : peer, radius: 19),
                ),
              ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ChatWallpaper()),
          Positioned.fill(
            child: RawGestureDetector(
              gestures: {
                if (selecting)
                  HorizontalDragGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        HorizontalDragGestureRecognizer
                      >(HorizontalDragGestureRecognizer.new, (r) {
                        r
                          ..onStart = (d) {
                            dragSelect = null;
                            dragSelectAt(d.globalPosition);
                          }
                          ..onUpdate = (d) {
                            dragSelectAt(d.globalPosition);
                          }
                          ..onEnd = (_) {
                            dragSelect = null;
                          }
                          ..onCancel = () {
                            dragSelect = null;
                          };
                      }),
              },
              child: ListView.builder(
                controller: scroll,
                reverse: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  top:
                      top +
                      8 +
                      (pinned.isNotEmpty
                          ? 18 + MediaQuery.textScalerOf(context).scale(38)
                          : 0),
                  bottom: widget.preview ? 8 : footerHeight + 8,
                ),
                itemCount: messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == messages.length) {
                    if (cursor == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: loading
                            ? const CircularProgressIndicator.adaptive()
                            : AppButton.text(
                                size: AppButtonSize.small,
                                onPressed: () => load(older: true),
                                child: Text(context.l10n.loadEarlierMessages),
                              ),
                      ),
                    );
                  }
                  // The list is reversed: index + 1 is the older neighbour.
                  final m = messages[index];
                  final older = index + 1 < messages.length
                      ? messages[index + 1]
                      : null;
                  final newer = index > 0 ? messages[index - 1] : null;
                  final created = _created(m);
                  final olderCreated = older == null ? null : _created(older);
                  final showDay =
                      created != null &&
                      (olderCreated == null ||
                          !_sameDay(created, olderCreated));
                  return Column(
                    key: rowKeys.putIfAbsent(chatEntityId(m), GlobalKey.new),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showDay) ChatDaySeparator(date: created),
                      ChatBubble(
                        highlighted: highlightedId == chatEntityId(m),
                        onOpen: () => openDisappearing(m),
                        message: withReply(m, self, peer),
                        mine: messageIsMine(m, self),
                        group: group,
                        first: !grouped(older, m),
                        last: !grouped(m, newer),
                        actions: actionsFor(m),
                        selected: selecting
                            ? selectedIds.contains(chatEntityId(m))
                            : null,
                        onSelectionChanged:
                            selectionBusy || m['_job_id'] != null
                            ? null
                            : () => selectMessage(m),
                        onReply: () => replyTo(m),
                        onRetry: m['status'] == 'failed'
                            ? () => retry(m)
                            : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (pinned.isNotEmpty && !selecting && !widget.preview)
            Positioned(
              left: 8,
              right: 8,
              top: top + 4,
              child: ChatPinnedBar(
                pinned: pinned,
                index: pinnedIndex.clamp(0, pinned.length - 1),
                onTap: openPinned,
                onUnpin: () => messageAction(
                  pinned[pinnedIndex.clamp(0, pinned.length - 1)],
                  'chat.unpin_message',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _HelperKind { reply, edit, forward }

/// Telegram Reply/Edit/ForwardAccessoryPanelNode: accent glyph, a 2pt accent
/// rule, a 15pt medium accent title over one 15pt secondary line, close.
class _ComposerHelper extends StatelessWidget {
  final _HelperKind kind;
  final String name, text;
  final int count;
  final VoidCallback onCancel;
  const _ComposerHelper({
    required this.kind,
    required this.text,
    required this.onCancel,
    this.name = '',
    this.count = 1,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final (symbol, fallback) = switch (kind) {
      _HelperKind.edit => ('pencil', Icons.edit_outlined),
      _HelperKind.reply => ('arrowshape.turn.up.left', Icons.reply),
      _HelperKind.forward => ('arrowshape.turn.up.right', Icons.forward),
    };
    final title = switch (kind) {
      _HelperKind.edit => context.l10n.editMessage,
      _HelperKind.reply => context.l10n.replyTo(name),
      _HelperKind.forward =>
        count == 1
            ? context.l10n.forwardMessage
            : context.l10n.forwardMessages(count),
    };
    // ForwardAccessoryPanelNode: one message reads "Author: text", several
    // read "From: authors".
    final line = kind == _HelperKind.forward
        ? count == 1
              ? '$name: $text'
              : context.l10n.from(name)
        : text;
    final cancel = switch (kind) {
      _HelperKind.edit => context.l10n.cancelEditing,
      _HelperKind.reply => context.l10n.cancelReply,
      _HelperKind.forward => context.l10n.cancelForwarding,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4, end: 4, top: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Center(
              child: AppSymbol.icon(
                symbol,
                size: 22,
                color: palette.accent,
                fallback: fallback,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsetsDirectional.only(start: 8),
              decoration: BoxDecoration(
                border: BorderDirectional(
                  start: BorderSide(color: palette.accent, width: 2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesign.font(
                      15,
                      weight: FontWeight.w500,
                      color: palette.accent,
                    ),
                  ),
                  Text(
                    line.trim().isEmpty ? context.l10n.media : line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesign.font(15, color: palette.secondaryLabel),
                  ),
                ],
              ),
            ),
          ),
          AppIconButton(
            glass: false,
            tooltip: cancel,
            icon: const Icon(Icons.close, size: 22),
            color: palette.secondaryLabel,
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// helpers/chatPresence formatChatLastSeen with the Telegram thresholds.
String lastSeenLabel(BuildContext context, dynamic value) {
  DateTime? time;
  if (value is num) {
    time = DateTime.fromMillisecondsSinceEpoch(
      (value < 1e12 ? value * 1000 : value).toInt(),
    );
  } else if (value is String) {
    time = DateTime.tryParse(value)?.toLocal();
  }
  final now = DateTime.now();
  if (time == null || time.millisecondsSinceEpoch <= 0 || time.isAfter(now)) {
    return '';
  }
  final seconds = now.difference(time).inSeconds;
  if (seconds < 60) {
    return context.l10n.lastSeenJustNow;
  }
  if (seconds < 3600) {
    final count = seconds ~/ 60;
    return count == 1
        ? context.l10n.lastSeen1MinuteAgo
        : context.l10n.lastSeenMinutesAgo(count);
  }
  final sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  if (seconds < 86400 && sameDay) {
    final count = seconds ~/ 3600;
    return count == 1
        ? context.l10n.lastSeen1HourAgo
        : context.l10n.lastSeenHoursAgo(count);
  }
  final yesterday = now.subtract(const Duration(days: 1));
  final clock =
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  final day =
      time.year == yesterday.year &&
          time.month == yesterday.month &&
          time.day == yesterday.day
      ? context.l10n.yesterday
      : MaterialLocalizations.of(context).formatShortMonthDay(time);
  return context.l10n.lastSeenAt(day, clock);
}

typedef ForwardResult = ({Json? chat, List<Json> messages, int sentCount});

class ForwardScreen extends StatefulWidget {
  final ChatForward? draft;
  const ForwardScreen({super.key, this.draft});
  @override
  State<ForwardScreen> createState() => _ForwardScreenState();
}

class _ForwardScreenState extends State<ForwardScreen> {
  String query = '';
  bool multiple = false, sending = false;
  final selected = <String, Json>{};
  final delivered = <String>{};
  final messages = <Json>[];
  final comment = TextEditingController();
  AppFailure? failure;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  void pick(Json chat) {
    if (sending) return;
    final id = chatEntityId(chat);
    if (id.isEmpty || delivered.contains(id)) return;
    if (!multiple) {
      Navigator.pop<ForwardResult>(context, (
        chat: chat,
        messages: const [],
        sentCount: 0,
      ));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      if (selected.containsKey(id)) {
        selected.remove(id);
      } else {
        selected[id] = chat;
      }
    });
  }

  Future<void> send() async {
    final draft = widget.draft;
    if (sending || selected.isEmpty || draft == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final api = AppScope.of(context).api;
    final targets = selected.keys.toList();
    final text = comment.text.trim();
    setState(() {
      sending = true;
      failure = null;
    });
    for (final target in targets) {
      if (!mounted) break;
      try {
        final rows = await draft.sendTo(api, target, comment: text);
        if (!mounted) return;
        setState(() {
          messages.addAll(rows);
          delivered.add(target);
          selected.remove(target);
        });
      } catch (error) {
        if (!mounted) return;
        setState(() => failure ??= AppFailure.from(error));
      }
    }
    if (!mounted) return;
    setState(() => sending = false);
    if (selected.isEmpty) {
      HapticFeedback.lightImpact();
      Navigator.pop<ForwardResult>(context, (
        chat: null,
        messages: messages,
        sentCount: delivered.length,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = AppScope.of(context).user;
    final palette = AppPalette.of(context), l = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    return PopScope(
      canPop: !sending,
      child: AppScaffold(
        backgroundColor: palette.row,
        appBar: AppHeader(
          title: Text(multiple ? l.selected(selected.length) : l.forwardTo),
          actions: [
            if (widget.draft != null && delivered.isEmpty)
              AppButton.text(
                key: const ValueKey('forward.select'),
                onPressed: sending
                    ? null
                    : () => setState(() {
                        multiple = !multiple;
                        if (!multiple) selected.clear();
                      }),
                child: Text(multiple ? l.cancel : l.select),
              ),
          ],
        ),
        body: Column(
          children: [
            AppSearchField(
              placeholder: l.search,
              onChanged: (value) => setState(() => query = value.trim()),
              onSearch: (value) => setState(() => query = value.trim()),
            ),
            if (failure != null)
              ScreenStatus(
                compact: true,
                error: l.forwardPartialFailure(
                  delivered.length,
                  selected.length,
                ),
                actions: AppButton.text(
                  onPressed: () => showErrorSheet(context, failure!),
                  child: Text(l.errorDetails),
                ),
              ),
            Expanded(
              child: RecordList(
                action: 'chat.fetch_chats',
                filter: query.isEmpty && delivered.isEmpty
                    ? null
                    : (chat) =>
                          !delivered.contains(chatEntityId(chat)) &&
                          (query.isEmpty ||
                              chatTitle(
                                chat,
                                self,
                                language: language,
                              ).toLowerCase().contains(query.toLowerCase())),
                itemBuilder: (context, chat, reload) => AbsorbPointer(
                  absorbing: sending,
                  child: chatRow(
                    context,
                    chat,
                    muted: ChatRowInfo.of(context, chat).muted,
                    selected: multiple
                        ? selected.containsKey(chatEntityId(chat))
                        : null,
                    onTap: () => pick(chat),
                  ),
                ),
              ),
            ),
            if (multiple)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MessageField(
                        key: const ValueKey('forward.comment'),
                        controller: comment,
                        placeholder: l.forwardCommentPlaceholder,
                        enabled: !sending,
                        maxHeight: 100,
                      ),
                      const SizedBox(height: 8),
                      AppButton.filled(
                        key: const ValueKey('forward.send'),
                        variant: AppButtonVariant.accent,
                        loading: sending,
                        onPressed: selected.isEmpty || sending ? null : send,
                        child: Text(l.forwardToRecipients(selected.length)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GroupScreen extends StatelessWidget {
  final Json chat;
  const GroupScreen({super.key, required this.chat});
  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(
      title: Text(
        chatTitle(
          chat,
          AppScope.of(context).user,
          language: AppScope.of(context).locale.languageCode,
        ),
      ),
      actions: [
        AppIconButton(
          tooltip: context.l10n.edit,
          icon: const Icon(Icons.edit),
          onPressed: () => sheet(context, AppForms.group(context, chat)),
        ),
      ],
    ),
    body: RecordList(
      action: 'chat.participants.fetch',
      params: {'chat_id': chatEntityId(chat)},
      itemBuilder: (context, user, reload) => PersonTile(
        person: user,
        trailing: AppIconButton(
          tooltip: context.l10n.removeParticipant,
          icon: const Icon(Icons.person_remove_outlined),
          onPressed: () => perform(context, () async {
            await AppScope.of(context).api.call(
              'chat.participant.remove',
              body: {
                'chat_id': chatEntityId(chat),
                'participant_id': recordId(user),
              },
            );
            reload();
          }),
        ),
      ),
    ),
  );
}

/// Telegram ChatScheduleTimeController: a date and time wheel and one
/// "Send on …" button; returns the chosen time.
class ScheduleMessageSheet extends StatefulWidget {
  final DateTime? initial;
  const ScheduleMessageSheet({super.key, this.initial});
  @override
  State<ScheduleMessageSheet> createState() => _ScheduleMessageSheetState();
}

class _ScheduleMessageSheetState extends State<ScheduleMessageSheet> {
  late DateTime value =
      widget.initial ?? DateTime.now().add(const Duration(hours: 1));

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final now = DateTime.now();
    final localizations = MaterialLocalizations.of(context);
    final today = DateUtils.isSameDay(value, now);
    final day = today
        ? context.l10n.today2
        : localizations.formatMediumDate(value);
    final clock = localizations.formatTimeOfDay(
      TimeOfDay.fromDateTime(value),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return AppScaffold(
      backgroundColor: palette.row,
      appBar: AppHeader(title: Text(context.l10n.scheduleMessage)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              // The date-and-time wheels need about 540pt with localized
              // month names (Turkish); narrower screens scale them down
              // instead of overlapping the columns.
              child: LayoutBuilder(
                builder: (context, box) => FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: math.max(box.maxWidth, 540),
                    height: box.maxHeight,
                    child: CupertinoDatePicker(
                      initialDateTime: value,
                      minimumDate: now.add(const Duration(minutes: 1)),
                      maximumDate: now.add(const Duration(days: 365)),
                      use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
                      onDateTimeChanged: (next) => setState(() => value = next),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: AppButton.filled(
                size: AppButtonSize.large,
                variant: AppButtonVariant.accent,
                onPressed: () => Navigator.pop(context, value),
                child: Text(context.l10n.sendAt(day, clock)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Telegram "Scheduled Messages": the author's pending sends in a chat with
/// Send Now and Delete; nothing here reaches recipients until published.
class ScheduledMessagesScreen extends StatefulWidget {
  final Json chat;
  const ScheduledMessagesScreen({super.key, required this.chat});
  @override
  State<ScheduledMessagesScreen> createState() =>
      _ScheduledMessagesScreenState();
}

class _ScheduledMessagesScreenState extends State<ScheduledMessagesScreen> {
  final rows = <Json>[];
  bool loading = true;
  String? error;
  String get id => chatEntityId(widget.chat);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (loading && rows.isEmpty && error == null) load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await AppScope.of(
        context,
      ).api.call('chat.fetch_scheduled_messages', body: {'chat_id': id});
      final data = object(result['data']);
      if (!mounted) return;
      setState(() {
        rows
          ..clear()
          ..addAll(
            ((data['messages'] ?? result['messages']) as List? ?? []).map(
              object,
            ),
          );
      });
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> act(Json message, String action) => perform(context, () async {
    await AppScope.of(context).api.call(
      action,
      body: {'chat_id': id, 'message_id': chatEntityId(message)},
    );
    if (mounted) setState(() => rows.remove(message));
  });

  @override
  Widget build(BuildContext context) {
    final self = AppScope.of(context).user;
    return AppScaffold(
      extendBodyBehindAppBar: true,
      appBar: AppHeader(title: Text(context.l10n.scheduledMessages)),
      body: Stack(
        children: [
          const Positioned.fill(child: ChatWallpaper()),
          if (loading || error != null || rows.isEmpty)
            Center(
              child: ScreenStatus(
                loading: loading,
                error: error,
                retry: load,
                title: context.l10n.noScheduledMessages,
              ),
            )
          else
            ListView(
              padding: EdgeInsets.only(
                top:
                    MediaQuery.paddingOf(context).top +
                    AppDesign.headerInset(context) +
                    8,
                bottom: MediaQuery.paddingOf(context).bottom + 16,
              ),
              children: [
                for (final message in rows) ...[
                  if (DateTime.tryParse(string(message['scheduled_at']))
                      case final DateTime at)
                    ChatDaySeparator(date: at.toLocal()),
                  ChatBubble(
                    message: message,
                    mine: messageIsMine(message, self),
                    onReply: () {},
                    actions: [
                      AppMenuItem(
                        title: context.l10n.sendNow,
                        symbol: 'paperplane',
                        fallback: Icons.send,
                        onPressed: () =>
                            act(message, 'chat.send_scheduled_now'),
                      ),
                      AppMenuItem(
                        title: context.l10n.deleteLabel,
                        symbol: 'trash',
                        fallback: Icons.delete_outline,
                        destructive: true,
                        onPressed: () =>
                            act(message, 'chat.delete_message_for_all'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

/// Telegram ChatPinnedMessageTitlePanelNode: a glass bar under the header
/// with a segmented accent rule (one segment per pin, the shown one solid),
/// "Pinned Message #n", a one-line preview, and an unpin control.
class ChatPinnedBar extends StatelessWidget {
  final List<Json> pinned;
  final int index;
  final VoidCallback onTap, onUnpin;
  const ChatPinnedBar({
    super.key,
    required this.pinned,
    required this.index,
    required this.onTap,
    required this.onUnpin,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final message = pinned[index];
    final title = pinned.length > 1 && index < pinned.length - 1
        ? context.l10n.pinnedMessage(index + 1)
        : context.l10n.pinnedMessage2;
    // At most four visible segments, kept around the shown pin.
    final count = pinned.length.clamp(1, 4);
    final first = (index - count + 1).clamp(0, pinned.length - count);
    return GlassSurface(
      radius: 22,
      child: AppPressable(
        label: '$title, ${messagePreview(context, message)}',
        style: AppPressStyle.opacity,
        onPressed: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              const SizedBox(width: 14),
              SizedBox(
                width: 2,
                height: 34,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < count; i++) ...[
                      if (i > 0) const SizedBox(height: 2),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: first + i == index
                                ? palette.accent
                                : palette.accent.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      style: AppDesign.font(
                        14,
                        weight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                    Text(
                      messagePreview(context, message),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesign.font(14, color: palette.text),
                    ),
                  ],
                ),
              ),
              AppIconButton(
                glass: false,
                tooltip: context.l10n.unpin,
                color: palette.secondaryLabel,
                icon: const Icon(Icons.close, size: 20),
                onPressed: onUnpin,
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}
