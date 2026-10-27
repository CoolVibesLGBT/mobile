import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import '../components/components.dart';
import '../core/api.dart';
import 'composer.dart';
import '../components/profile_edit_content.dart';
import '../core/session.dart';
import '../core/profile_data.dart';

/// Canonical business form definitions, shared by production and debug routes.
abstract final class AppForms {
  static Json postPayload({
    required String text,
    Json attachments = const {},
    String? parentPostId,
    Json? articleDocument,
  }) => {
    'content': articleDocument ?? lexical(text),
    'audience': 'public',
    ...attachments,
    'parentPostId': ?parentPostId,
  };
  static Widget profile(BuildContext context, Json user) => ActionForm(
    title: context.l10n.editProfile,
    action: 'user.update_profile',
    fields: {
      'displayname': context.l10n.profileDisplayName,
      'username': context.l10n.username,
      'email': context.l10n.email,
      'bio': context.l10n.about,
      'website': context.l10n.website,
      'date_of_birth': context.l10n.dateOfBirth,
      'location': context.l10n.location,
      'privacy_level': context.l10n.profilePrivacy,
    },
    initial: {
      ...user,
      'bio': profileBioText(user['bio']),
      'location': profileLocationLabel(user['location']),
      'privacy_level': user['privacy_level'] ?? 'public',
      if (user['date_of_birth'] != null)
        'date_of_birth': string(user['date_of_birth']).split('T').first,
    },
    requiredFields: const {'displayname'},
    sliverContent: true,
    contentBuilder: (_, form) => ProfileEditContent(form: form),
    onSaved: AppScope.of(context).refreshUser,
    transform: (body) => {...body}
      ..remove('location')
      ..removeWhere(
        (key, value) =>
            (key == 'bio' && string(value) == profileBioText(user['bio'])) ||
            ((key == 'username' || key == 'email') &&
                string(value).toLowerCase() == string(user[key]).toLowerCase()),
      ),
  );
  static Widget password(BuildContext context) => ActionForm(
    title: context.l10n.changePassword,
    action: 'user.update_profile',
    fields: {
      'current_password': context.l10n.currentPassword,
      'new_password': context.l10n.newPassword,
      'new_password_confirmation': context.l10n.confirmNewPassword,
    },
  );
  static Widget group(BuildContext context, Json chat) => ActionForm(
    title: context.l10n.editGroup,
    action: 'chat.group.update',
    fields: {
      'title': context.l10n.title,
      'description': context.l10n.description,
    },
    initial: chat,
    requiredFields: const {'title'},
    extra: {
      'chat_id': recordId(chat),
      'visibility': chat['visibility'] ?? 'private',
      'remove_avatar': false,
    },
  );
  static Widget comment(BuildContext context, Json place) =>
      ComposerScreen(replyTo: recordId(place));
  static Widget classified(BuildContext context, {required bool offers}) =>
      ComposerScreen(kind: offers ? 'job_offer' : 'job_search');
}
