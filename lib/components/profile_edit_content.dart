import 'package:flutter/cupertino.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/geo.dart';
import '../core/profile_data.dart';
import '../design/app_design.dart';
import '../screens/app_forms.dart';
import '../l10n/l10n.dart';
import '../screens/location_picker.dart';
import '../screens/preferences.dart';
import '../screens/profile_album.dart';
import 'components.dart';
import 'illustrated_icon.dart';
import 'profile_photo_editor.dart';
import 'glass_surface.dart';

/// ProfileEdit identity layout; ActionForm owns the draft, validation and save.
class ProfileEditContent extends StatefulWidget {
  final ActionFormState form;
  const ProfileEditContent({super.key, required this.form});
  @override
  State<ProfileEditContent> createState() => _ProfileEditContentState();
}

class _ProfileEditContentState extends State<ProfileEditContent> {
  ActionFormState get form => widget.form;
  String value(String key) => form.controllers[key]!.text;
  String tab = 'profile';
  Json? locationDraft;

  void selectTab(String next) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => tab = next);
    form.setSaveVisible(next == 'profile');
  }

  Future<void> birthday() async {
    final now = DateUtils.dateOnly(DateTime.now());
    final initial =
        DateTime.tryParse(value('date_of_birth')) ??
        DateTime(now.year - 18, now.month, now.day);
    var chosen = initial.isAfter(now) ? now : initial;
    final result = await sheet<DateTime>(
      context,
      Builder(
        builder: (context) => AppScaffold(
          appBar: AppHeader(
            title: Text(context.l10n.dateOfBirth),
            actions: [
              AppButton.text(
                onPressed: () => Navigator.pop(context, chosen),
                child: Text(context.l10n.save),
              ),
            ],
          ),
          body: Center(
            child: SizedBox(
              height: 250,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: chosen,
                maximumDate: now,
                onDateTimeChanged: (date) => chosen = date,
              ),
            ),
          ),
        ),
      ),
      fullSize: .55,
    );
    if (result != null && mounted) {
      form.setValue('date_of_birth', DateFormat('yyyy-MM-dd').format(result));
    }
  }

  Future<void> location() async {
    final point = await sheet<Json>(
      context,
      LocationPickerScreen(
        initial: locationDraft ?? object(AppScope.of(context).user['location']),
      ),
    );
    if (point == null || !mounted) return;
    locationDraft = {...point, ...?coordinatesOf(point)};
    final display = profileLocationLabel(point);
    form.setValue('location', display);
    form.extraValues.removeWhere((key, _) => key.startsWith('location['));
    form.setExtra({
      for (final key in [
        'latitude',
        'longitude',
        'country_code',
        'country',
        'city',
        'region',
        'timezone',
      ])
        if (locationDraft![key] != null) 'location[$key]': locationDraft![key],
      'location[display]': display,
      'location[address]': point['address'] ?? display,
      'location[contentable_type]': 'users',
    });
  }

  Map<String, String> get privacy => {
    'public': context.l10n.profilePrivacyPublic,
    'followers_only': context.l10n.profilePrivacyFollowers,
    'friends_only': context.l10n.profilePrivacyFriends,
    'mutuals_only': context.l10n.profilePrivacyMutuals,
    'private': context.l10n.profilePrivacyPrivate,
  };

  Future<void> choosePrivacy() async {
    final selected = await sheet<String>(
      context,
      AppScaffold(
        appBar: AppHeader(title: Text(context.l10n.profilePrivacy)),
        body: ListView(
          children: [
            AppSection(
              footer: context.l10n.profilePrivacyHelp,
              children: [
                for (final entry in privacy.entries)
                  AppChoiceRow(
                    title: Text(entry.value),
                    value: value('privacy_level') == entry.key,
                    onChanged: (_) => Navigator.of(
                      context,
                      rootNavigator: true,
                    ).pop(entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) form.setValue('privacy_level', selected);
  }

  Widget detail(
    String title,
    String icon,
    VoidCallback action, {
    String? value,
    Key? key,
  }) => AppRow(
    key: key,
    leading: IllustratedIcon(icon),
    title: Text(title),
    value: value,
    onTap: form.busy ? null : action,
  );

  Widget photos(Json user) {
    final l = context.l10n, palette = AppPalette.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: AppDesign.font(
          14,
          weight: FontWeight.w500,
          color: palette.secondaryLabel,
        ),
      ),
    );
    const camera = GlassSurface(
      radius: 22,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: AppSymbol(
            'camera',
            fallback: Icons.camera_alt_outlined,
            size: 20,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(l.profileCoverPhoto),
          AppPressable(
            key: const ValueKey('profile.edit.cover'),
            label: l.profileCoverPhoto,
            onPressed: form.busy
                ? null
                : () => editProfilePhoto(context, ProfilePhotoKind.cover),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                AppDesign.profileEditCoverRadius,
              ),
              child: SizedBox(
                height: AppDesign.profileEditCoverHeight,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(source: profileCover(user), fit: BoxFit.cover),
                    const PositionedDirectional(
                      top: 16,
                      end: 16,
                      child: camera,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          label(l.profileImage),
          Row(
            children: [
              AppPressable(
                key: const ValueKey('profile.edit.avatar'),
                label: l.profileSetPhoto,
                onPressed: form.busy
                    ? null
                    : () => editProfilePhoto(context, ProfilePhotoKind.avatar),
                child: Stack(
                  children: [
                    Avatar(
                      user,
                      radius: AppDesign.profileEditAvatarDiameter / 2,
                    ),
                    const PositionedDirectional(
                      bottom: 0,
                      end: 0,
                      child: camera,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  l.profileImageHint,
                  style: AppDesign.font(14, color: palette.secondaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context), l = context.l10n;
    final date = DateTime.tryParse(value('date_of_birth'));
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: photos(session.user)),
        PinnedHeaderSliver(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: AppSegments<String>(
              key: const ValueKey('profile.edit.tabs'),
              contentSized: true,
              selected: tab,
              onChanged: selectTab,
              values: {
                'profile': Text(l.profileInfo),
                'attributes': Text(l.attributes),
                'interests': Text(l.interests),
                'fantasies': Text(l.fantasies),
              },
            ),
          ),
        ),
        if (tab != 'profile')
          PreferencesSliver(kind: tab)
        else
          SliverToBoxAdapter(
            child: Column(
              children: [
                AppSection(
                  footer: l.profileIdentityHelp,
                  children: [
                    form.field(
                      'username',
                      prefix: '@',
                      placeholder: l.username,
                    ),
                    form.field(
                      'displayname',
                      placeholder: l.profileDisplayName,
                    ),
                    form.field('email', placeholder: 'name@example.com'),
                  ],
                ),
                AppSection(
                  title: l.bio,
                  footer: l.profileBioHelp,
                  children: [
                    form.field(
                      'bio',
                      showLabel: false,
                      placeholder: l.bio,
                      minLines: 3,
                    ),
                  ],
                ),
                AppSection(
                  title: l.profilePersonalDetails,
                  children: [
                    detail(
                      l.location,
                      'system-mappin',
                      location,
                      key: const ValueKey('profile.edit.location'),
                      value: value('location').isEmpty
                          ? l.profileNotSet
                          : value('location'),
                    ),
                    detail(
                      l.dateOfBirth,
                      'system-calendar',
                      birthday,
                      key: const ValueKey('profile.edit.birthdate'),
                      value: date == null
                          ? l.profileNotSet
                          : DateFormat.yMMMd(
                              Localizations.localeOf(context).toLanguageTag(),
                            ).format(date),
                    ),
                    form.field('website', placeholder: 'example.com'),
                  ],
                ),
                AppSection(
                  footer: l.profilePrivacyHelp,
                  children: [
                    detail(
                      l.profilePrivacy,
                      'system-lock',
                      choosePrivacy,
                      value: privacy[value('privacy_level')] ?? l.profileNotSet,
                    ),
                  ],
                ),
                AppSection(
                  children: [
                    detail(
                      l.changePassword,
                      'system-shield',
                      () => open(context, AppForms.password(context)),
                    ),
                    detail(
                      l.privatePhotos,
                      'system-image',
                      () => open(context, const AlbumScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
