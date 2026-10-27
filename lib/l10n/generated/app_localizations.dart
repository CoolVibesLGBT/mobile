import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @connection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connection;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @yourAccountCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Your account could not be loaded.'**
  String get yourAccountCouldNotBeLoaded;

  /// No description provided for @checkYourConnectionAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkYourConnectionAndTryAgain;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @enterAValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get enterAValidEmail;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @file.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get file;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecording;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeLocation.
  ///
  /// In en, this message translates to:
  /// **'Remove location'**
  String get removeLocation;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @recents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get recents;

  /// No description provided for @chooseFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from Library'**
  String get chooseFromLibrary;

  /// No description provided for @youGaveAccessToSelectedPhotos.
  ///
  /// In en, this message translates to:
  /// **'You gave access to selected photos only.'**
  String get youGaveAccessToSelectedPhotos;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @allowPhotoAccessToSeeYour.
  ///
  /// In en, this message translates to:
  /// **'Allow photo access to see your recent photos here.'**
  String get allowPhotoAccessToSeeYour;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @mediaCouldNotBeAddedTry.
  ///
  /// In en, this message translates to:
  /// **'Media could not be added. Try again.'**
  String get mediaCouldNotBeAddedTry;

  /// No description provided for @selected.
  ///
  /// In en, this message translates to:
  /// **'{length} selected'**
  String selected(Object length);

  /// No description provided for @hideWithSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Hide with spoiler'**
  String get hideWithSpoiler;

  /// No description provided for @video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get video;

  /// No description provided for @photo.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photo;

  /// No description provided for @media.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get media;

  /// No description provided for @tapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view'**
  String get tapToView;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @forwardedFrom.
  ///
  /// In en, this message translates to:
  /// **'Forwarded from'**
  String get forwardedFrom;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @messageNotSentTapToRetry.
  ///
  /// In en, this message translates to:
  /// **'Message not sent. Tap to retry.'**
  String get messageNotSentTapToRetry;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @shareAThoughtWinQuestionOr.
  ///
  /// In en, this message translates to:
  /// **'Share a thought, win, question or vibe...'**
  String get shareAThoughtWinQuestionOr;

  /// No description provided for @attachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get attachments;

  /// No description provided for @stopRecording2.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecording2;

  /// No description provided for @voiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice message'**
  String get voiceMessage;

  /// No description provided for @emojiStickersAndGifs.
  ///
  /// In en, this message translates to:
  /// **'Emoji, stickers and GIFs'**
  String get emojiStickersAndGifs;

  /// No description provided for @typeAMessage.
  ///
  /// In en, this message translates to:
  /// **'Type a message'**
  String get typeAMessage;

  /// No description provided for @showKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Show keyboard'**
  String get showKeyboard;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @deleteLabel.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteLabel;

  /// No description provided for @unreadMessages.
  ///
  /// In en, this message translates to:
  /// **'{name}, {unread} unread messages'**
  String unreadMessages(Object name, Object unread);

  /// No description provided for @unpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpin;

  /// No description provided for @pin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get pin;

  /// No description provided for @removeTag.
  ///
  /// In en, this message translates to:
  /// **'Remove tag: {name}'**
  String removeTag(Object name);

  /// No description provided for @dragToSelect.
  ///
  /// In en, this message translates to:
  /// **'Drag to select'**
  String get dragToSelect;

  /// No description provided for @vibeSelected.
  ///
  /// In en, this message translates to:
  /// **'VIBE SELECTED'**
  String get vibeSelected;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'RESET'**
  String get reset;

  /// No description provided for @publicPost.
  ///
  /// In en, this message translates to:
  /// **'Public post'**
  String get publicPost;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @liveConnectionCouldNotBeVerified.
  ///
  /// In en, this message translates to:
  /// **'Live connection could not be verified'**
  String get liveConnectionCouldNotBeVerified;

  /// No description provided for @waitingForConnection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection…'**
  String get waitingForConnection;

  /// No description provided for @changeLocation.
  ///
  /// In en, this message translates to:
  /// **'Change location'**
  String get changeLocation;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @sticker.
  ///
  /// In en, this message translates to:
  /// **'Sticker'**
  String get sticker;

  /// No description provided for @mapCouldNotLoadCheckYour.
  ///
  /// In en, this message translates to:
  /// **'Map could not load. Check your connection.'**
  String get mapCouldNotLoadCheckYour;

  /// No description provided for @mapIsUnavailableOnThisDevice.
  ///
  /// In en, this message translates to:
  /// **'Map is unavailable on this device'**
  String get mapIsUnavailableOnThisDevice;

  /// No description provided for @zoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// No description provided for @zoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// No description provided for @openLocationInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open location in Maps'**
  String get openLocationInMaps;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @like.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get like;

  /// No description provided for @dislike.
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get dislike;

  /// No description provided for @attributes.
  ///
  /// In en, this message translates to:
  /// **'Attributes'**
  String get attributes;

  /// No description provided for @fantasies.
  ///
  /// In en, this message translates to:
  /// **'Fantasies'**
  String get fantasies;

  /// No description provided for @noFantasiesAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No fantasies added yet.'**
  String get noFantasiesAddedYet;

  /// No description provided for @interests.
  ///
  /// In en, this message translates to:
  /// **'Interests'**
  String get interests;

  /// No description provided for @noInterestsAddedYet.
  ///
  /// In en, this message translates to:
  /// **'No interests added yet.'**
  String get noInterestsAddedYet;

  /// No description provided for @online2.
  ///
  /// In en, this message translates to:
  /// **'online'**
  String get online2;

  /// No description provided for @statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verified;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noItemsHereYet.
  ///
  /// In en, this message translates to:
  /// **'No items here yet.'**
  String get noItemsHereYet;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @spoilerTapToReveal.
  ///
  /// In en, this message translates to:
  /// **'Spoiler. Tap to reveal'**
  String get spoilerTapToReveal;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get dateOfBirth;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmNewPassword;

  /// No description provided for @editGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit group'**
  String get editGroup;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @comment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @thisIsHowYourChatsWill.
  ///
  /// In en, this message translates to:
  /// **'This is how your chats will look.'**
  String get thisIsHowYourChatsWill;

  /// No description provided for @yourMessagesYourColors.
  ///
  /// In en, this message translates to:
  /// **'Your messages, your colors.'**
  String get yourMessagesYourColors;

  /// No description provided for @colorTheme.
  ///
  /// In en, this message translates to:
  /// **'Color theme'**
  String get colorTheme;

  /// No description provided for @cancel2.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel2;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @selectedColor.
  ///
  /// In en, this message translates to:
  /// **'Selected color'**
  String get selectedColor;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Hue'**
  String get hue;

  /// No description provided for @saturation.
  ///
  /// In en, this message translates to:
  /// **'Saturation'**
  String get saturation;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @hexColor.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get hexColor;

  /// No description provided for @enterAColorLike3390ec.
  ///
  /// In en, this message translates to:
  /// **'Enter a color like #3390EC.'**
  String get enterAColorLike3390ec;

  /// No description provided for @acceptTheTermsToContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept the terms to continue'**
  String get acceptTheTermsToContinue;

  /// No description provided for @unableToReachTheServiceCheck.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the service. Check your connection and try again.'**
  String get unableToReachTheServiceCheck;

  /// No description provided for @registrationFailedPleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Registration failed. Please try again.'**
  String get registrationFailedPleaseTryAgain;

  /// No description provided for @loginFailedPleaseCheckYourCredentials.
  ///
  /// In en, this message translates to:
  /// **'Login failed. Please check your credentials.'**
  String get loginFailedPleaseCheckYourCredentials;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get complete;

  /// No description provided for @joinCoolvibesToday.
  ///
  /// In en, this message translates to:
  /// **'Join CoolVibes today.'**
  String get joinCoolvibesToday;

  /// No description provided for @enterYourCredentialsToContinue.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to continue.'**
  String get enterYourCredentialsToContinue;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @nicknameEmail.
  ///
  /// In en, this message translates to:
  /// **'Nickname / Email'**
  String get nicknameEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @referralCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Referral Code (Optional)'**
  String get referralCodeOptional;

  /// No description provided for @iAm18OrOlderAnd.
  ///
  /// In en, this message translates to:
  /// **'I am 18 or older and accept the terms and privacy policy'**
  String get iAm18OrOlderAnd;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verification;

  /// No description provided for @messages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get messages;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @newMessage.
  ///
  /// In en, this message translates to:
  /// **'New Message'**
  String get newMessage;

  /// No description provided for @newConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get newConversation;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search users'**
  String get searchUsers;

  /// No description provided for @groupTitle.
  ///
  /// In en, this message translates to:
  /// **'Group title'**
  String get groupTitle;

  /// No description provided for @deleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get deleteMessage;

  /// No description provided for @deleteMessages.
  ///
  /// In en, this message translates to:
  /// **'Delete {length} messages?'**
  String deleteMessages(Object length);

  /// No description provided for @deleteForMe.
  ///
  /// In en, this message translates to:
  /// **'Delete for me'**
  String get deleteForMe;

  /// No description provided for @deleteForEveryone.
  ///
  /// In en, this message translates to:
  /// **'Delete for everyone'**
  String get deleteForEveryone;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @n10Seconds.
  ///
  /// In en, this message translates to:
  /// **'10 seconds'**
  String get n10Seconds;

  /// No description provided for @n1Minute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get n1Minute;

  /// No description provided for @n1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get n1Hour;

  /// No description provided for @n1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get n1Day;

  /// No description provided for @n1Week.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get n1Week;

  /// No description provided for @selfDestructTimer.
  ///
  /// In en, this message translates to:
  /// **'Self-Destruct Timer'**
  String get selfDestructTimer;

  /// No description provided for @newMessagesDisappearThisLongAfter.
  ///
  /// In en, this message translates to:
  /// **'New messages disappear this long after they are opened.'**
  String get newMessagesDisappearThisLongAfter;

  /// No description provided for @reply2.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply2;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @forward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get forward;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @chat2.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat2;

  /// No description provided for @typing.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typing;

  /// No description provided for @selectMessages.
  ///
  /// In en, this message translates to:
  /// **'Select Messages'**
  String get selectMessages;

  /// No description provided for @selected2.
  ///
  /// In en, this message translates to:
  /// **'{length} Selected'**
  String selected2(Object length);

  /// No description provided for @groupInfo.
  ///
  /// In en, this message translates to:
  /// **'Group Info'**
  String get groupInfo;

  /// No description provided for @loadEarlierMessages.
  ///
  /// In en, this message translates to:
  /// **'Load earlier messages'**
  String get loadEarlierMessages;

  /// No description provided for @deleteSelectedMessages.
  ///
  /// In en, this message translates to:
  /// **'Delete selected messages'**
  String get deleteSelectedMessages;

  /// No description provided for @forwardSelectedMessages.
  ///
  /// In en, this message translates to:
  /// **'Forward selected messages'**
  String get forwardSelectedMessages;

  /// No description provided for @scheduleMessage.
  ///
  /// In en, this message translates to:
  /// **'Schedule Message'**
  String get scheduleMessage;

  /// No description provided for @selfDestructTimer2.
  ///
  /// In en, this message translates to:
  /// **'Self-Destruct Timer'**
  String get selfDestructTimer2;

  /// No description provided for @scheduledMessages.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Messages'**
  String get scheduledMessages;

  /// No description provided for @editMessage.
  ///
  /// In en, this message translates to:
  /// **'Edit Message'**
  String get editMessage;

  /// No description provided for @replyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String replyTo(Object name);

  /// No description provided for @forwardMessage.
  ///
  /// In en, this message translates to:
  /// **'Forward Message'**
  String get forwardMessage;

  /// No description provided for @forwardMessages.
  ///
  /// In en, this message translates to:
  /// **'Forward {count} Messages'**
  String forwardMessages(Object count);

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From: {name}'**
  String from(Object name);

  /// No description provided for @cancelEditing.
  ///
  /// In en, this message translates to:
  /// **'Cancel editing'**
  String get cancelEditing;

  /// No description provided for @cancelReply.
  ///
  /// In en, this message translates to:
  /// **'Cancel reply'**
  String get cancelReply;

  /// No description provided for @cancelForwarding.
  ///
  /// In en, this message translates to:
  /// **'Cancel forwarding'**
  String get cancelForwarding;

  /// No description provided for @lastSeenJustNow.
  ///
  /// In en, this message translates to:
  /// **'last seen just now'**
  String get lastSeenJustNow;

  /// No description provided for @lastSeen1MinuteAgo.
  ///
  /// In en, this message translates to:
  /// **'last seen 1 minute ago'**
  String get lastSeen1MinuteAgo;

  /// No description provided for @lastSeenMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'last seen {count} minutes ago'**
  String lastSeenMinutesAgo(Object count);

  /// No description provided for @lastSeen1HourAgo.
  ///
  /// In en, this message translates to:
  /// **'last seen 1 hour ago'**
  String get lastSeen1HourAgo;

  /// No description provided for @lastSeenHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'last seen {count} hours ago'**
  String lastSeenHoursAgo(Object count);

  /// No description provided for @lastSeenAt.
  ///
  /// In en, this message translates to:
  /// **'last seen {day} at {clock}'**
  String lastSeenAt(Object day, Object clock);

  /// No description provided for @forwardTo.
  ///
  /// In en, this message translates to:
  /// **'Forward to…'**
  String get forwardTo;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @removeParticipant.
  ///
  /// In en, this message translates to:
  /// **'Remove participant'**
  String get removeParticipant;

  /// No description provided for @today2.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get today2;

  /// No description provided for @sendAt.
  ///
  /// In en, this message translates to:
  /// **'Send {day} at {clock}'**
  String sendAt(Object day, Object clock);

  /// No description provided for @noScheduledMessages.
  ///
  /// In en, this message translates to:
  /// **'No scheduled messages'**
  String get noScheduledMessages;

  /// No description provided for @sendNow.
  ///
  /// In en, this message translates to:
  /// **'Send Now'**
  String get sendNow;

  /// No description provided for @pinnedMessage.
  ///
  /// In en, this message translates to:
  /// **'Pinned Message #{value}'**
  String pinnedMessage(Object value);

  /// No description provided for @pinnedMessage2.
  ///
  /// In en, this message translates to:
  /// **'Pinned Message'**
  String get pinnedMessage2;

  /// No description provided for @classifieds.
  ///
  /// In en, this message translates to:
  /// **'Classifieds'**
  String get classifieds;

  /// No description provided for @createListing.
  ///
  /// In en, this message translates to:
  /// **'Create listing'**
  String get createListing;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @seeking.
  ///
  /// In en, this message translates to:
  /// **'Seeking'**
  String get seeking;

  /// No description provided for @enterATitle.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get enterATitle;

  /// No description provided for @addAPhotoOrText.
  ///
  /// In en, this message translates to:
  /// **'Add a photo or text'**
  String get addAPhotoOrText;

  /// No description provided for @whatIsOnYourMind.
  ///
  /// In en, this message translates to:
  /// **'What is on your mind?'**
  String get whatIsOnYourMind;

  /// No description provided for @shareACheckIn.
  ///
  /// In en, this message translates to:
  /// **'Share a check-in…'**
  String get shareACheckIn;

  /// No description provided for @writeAComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment…'**
  String get writeAComment;

  /// No description provided for @newStory.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get newStory;

  /// No description provided for @newListing.
  ///
  /// In en, this message translates to:
  /// **'New listing'**
  String get newListing;

  /// No description provided for @createPost.
  ///
  /// In en, this message translates to:
  /// **'Create post'**
  String get createPost;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// No description provided for @separateWithCommas.
  ///
  /// In en, this message translates to:
  /// **'Separate with commas'**
  String get separateWithCommas;

  /// No description provided for @label.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get label;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @addDetail.
  ///
  /// In en, this message translates to:
  /// **'Add detail'**
  String get addDetail;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @yourLocationIsUnavailableCheckLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location is unavailable. Check location permission and try again.'**
  String get yourLocationIsUnavailableCheckLocation;

  /// No description provided for @columns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columns;

  /// No description provided for @columns2.
  ///
  /// In en, this message translates to:
  /// **'{count} columns'**
  String columns2(Object count);

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @grid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get grid;

  /// No description provided for @list.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @map2.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map2;

  /// No description provided for @list2.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get list2;

  /// No description provided for @checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get checkIn;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get people;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @places.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get places;

  /// No description provided for @searchCoolvibes.
  ///
  /// In en, this message translates to:
  /// **'Search CoolVibes'**
  String get searchCoolvibes;

  /// No description provided for @findPeoplePostsEventsAndPlaces.
  ///
  /// In en, this message translates to:
  /// **'Find people, posts, events and places.'**
  String get findPeoplePostsEventsAndPlaces;

  /// No description provided for @searchCouldNotBeCompleted.
  ///
  /// In en, this message translates to:
  /// **'Search could not be completed.'**
  String get searchCouldNotBeCompleted;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @searchPeoplePostsAndPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search people, posts and places'**
  String get searchPeoplePostsAndPlaces;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @matches.
  ///
  /// In en, this message translates to:
  /// **'Matches'**
  String get matches;

  /// No description provided for @drawing.
  ///
  /// In en, this message translates to:
  /// **'Drawing'**
  String get drawing;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @use.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get use;

  /// No description provided for @couldNotLoadStickers.
  ///
  /// In en, this message translates to:
  /// **'Could not load stickers'**
  String get couldNotLoadStickers;

  /// No description provided for @couldNotLoadGifsTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Could not load GIFs. Try again.'**
  String get couldNotLoadGifsTryAgain;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @searchGifs.
  ///
  /// In en, this message translates to:
  /// **'Search GIFs'**
  String get searchGifs;

  /// No description provided for @searchEmoji.
  ///
  /// In en, this message translates to:
  /// **'Search emoji'**
  String get searchEmoji;

  /// No description provided for @searchStickers.
  ///
  /// In en, this message translates to:
  /// **'Search stickers'**
  String get searchStickers;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @stickers.
  ///
  /// In en, this message translates to:
  /// **'Stickers'**
  String get stickers;

  /// No description provided for @deleteLastCharacter.
  ///
  /// In en, this message translates to:
  /// **'Delete last character'**
  String get deleteLastCharacter;

  /// No description provided for @addStory.
  ///
  /// In en, this message translates to:
  /// **'Add Story'**
  String get addStory;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @report.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get report;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @viewAllComments.
  ///
  /// In en, this message translates to:
  /// **'View all {comments} comments'**
  String viewAllComments(Object comments);

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minAgo.
  ///
  /// In en, this message translates to:
  /// **'{inMinutes} min ago'**
  String minAgo(Object inMinutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{inHours} hours ago'**
  String hoursAgo(Object inHours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{inDays} days ago'**
  String daysAgo(Object inDays);

  /// No description provided for @comments2.
  ///
  /// In en, this message translates to:
  /// **'Comments ({length})'**
  String comments2(Object length);

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get noCommentsYet;

  /// No description provided for @placesCouldNotBeLoaded.
  ///
  /// In en, this message translates to:
  /// **'Places could not be loaded.'**
  String get placesCouldNotBeLoaded;

  /// No description provided for @allowLocationAccessToUseYour.
  ///
  /// In en, this message translates to:
  /// **'Allow location access to use your current location.'**
  String get allowLocationAccessToUseYour;

  /// No description provided for @selectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected location'**
  String get selectedLocation;

  /// No description provided for @teleportToThisArea.
  ///
  /// In en, this message translates to:
  /// **'Teleport to this area'**
  String get teleportToThisArea;

  /// No description provided for @sendMyCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Send My Current Location'**
  String get sendMyCurrentLocation;

  /// No description provided for @sendSelectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Send Selected Location'**
  String get sendSelectedLocation;

  /// No description provided for @searchPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search places'**
  String get searchPlaces;

  /// No description provided for @sendLocation.
  ///
  /// In en, this message translates to:
  /// **'Send Location'**
  String get sendLocation;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get locating;

  /// No description provided for @nearbyPlaces.
  ///
  /// In en, this message translates to:
  /// **'NEARBY PLACES'**
  String get nearbyPlaces;

  /// No description provided for @morePlaces.
  ///
  /// In en, this message translates to:
  /// **'More places'**
  String get morePlaces;

  /// No description provided for @noPlacesFound.
  ///
  /// In en, this message translates to:
  /// **'No places found'**
  String get noPlacesFound;

  /// No description provided for @searchPlaces2.
  ///
  /// In en, this message translates to:
  /// **'Search Places'**
  String get searchPlaces2;

  /// No description provided for @ofLabel.
  ///
  /// In en, this message translates to:
  /// **'{value} of {length}'**
  String ofLabel(Object value, Object length);

  /// No description provided for @playPause.
  ///
  /// In en, this message translates to:
  /// **'Play / pause'**
  String get playPause;

  /// No description provided for @couldNotOpenFile.
  ///
  /// In en, this message translates to:
  /// **'Could not open file'**
  String get couldNotOpenFile;

  /// No description provided for @audioCouldNotBePlayed.
  ///
  /// In en, this message translates to:
  /// **'Audio could not be played'**
  String get audioCouldNotBePlayed;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @places2.
  ///
  /// In en, this message translates to:
  /// **'Places'**
  String get places2;

  /// No description provided for @nearbyPlaces2.
  ///
  /// In en, this message translates to:
  /// **'Nearby places'**
  String get nearbyPlaces2;

  /// No description provided for @comment2.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get comment2;

  /// No description provided for @website2.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website2;

  /// No description provided for @profilePreferences.
  ///
  /// In en, this message translates to:
  /// **'Profile preferences'**
  String get profilePreferences;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @profileUsernameIsMissing.
  ///
  /// In en, this message translates to:
  /// **'Profile username is missing'**
  String get profileUsernameIsMissing;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @blockUnblock.
  ///
  /// In en, this message translates to:
  /// **'Block / unblock'**
  String get blockUnblock;

  /// No description provided for @changeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change avatar'**
  String get changeAvatar;

  /// No description provided for @block.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get block;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @likes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @requestAccess.
  ///
  /// In en, this message translates to:
  /// **'Request access'**
  String get requestAccess;

  /// No description provided for @privatePhotos.
  ///
  /// In en, this message translates to:
  /// **'Private photos'**
  String get privatePhotos;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @photoAccessRequests.
  ///
  /// In en, this message translates to:
  /// **'Photo access requests'**
  String get photoAccessRequests;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get friends;

  /// No description provided for @legal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get legal;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @logOut2.
  ///
  /// In en, this message translates to:
  /// **'Log Out?'**
  String get logOut2;

  /// No description provided for @areYouSureYouWantTo.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? You will need to login again to access your profile.'**
  String get areYouSureYouWantTo;

  /// No description provided for @accessRequests.
  ///
  /// In en, this message translates to:
  /// **'Access requests'**
  String get accessRequests;

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @deny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get deny;

  /// No description provided for @manageYourPremiumSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage your Premium subscription'**
  String get manageYourPremiumSubscription;

  /// No description provided for @openAccount.
  ///
  /// In en, this message translates to:
  /// **'Open account'**
  String get openAccount;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @uploads.
  ///
  /// In en, this message translates to:
  /// **'Uploads'**
  String get uploads;

  /// No description provided for @metricFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get metricFollowers;

  /// No description provided for @metricFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get metricFollowing;

  /// No description provided for @metricViewsReceived.
  ///
  /// In en, this message translates to:
  /// **'Views Received'**
  String get metricViewsReceived;

  /// No description provided for @metricDislikesReceived.
  ///
  /// In en, this message translates to:
  /// **'Dislikes Received'**
  String get metricDislikesReceived;

  /// No description provided for @metricLikesGiven.
  ///
  /// In en, this message translates to:
  /// **'Likes Given'**
  String get metricLikesGiven;

  /// No description provided for @metricViewsGiven.
  ///
  /// In en, this message translates to:
  /// **'Views Given'**
  String get metricViewsGiven;

  /// No description provided for @metricDislikesGiven.
  ///
  /// In en, this message translates to:
  /// **'Dislikes Given'**
  String get metricDislikesGiven;

  /// No description provided for @metricBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked Users'**
  String get metricBlockedUsers;

  /// No description provided for @accentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accentColor;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @messageTextSize.
  ///
  /// In en, this message translates to:
  /// **'Message Text Size'**
  String get messageTextSize;

  /// No description provided for @chatWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Chat Wallpaper'**
  String get chatWallpaper;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @messageColors.
  ///
  /// In en, this message translates to:
  /// **'Message colors'**
  String get messageColors;

  /// No description provided for @messageGradient.
  ///
  /// In en, this message translates to:
  /// **'Message gradient'**
  String get messageGradient;

  /// No description provided for @resetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetToDefaults;

  /// No description provided for @resetAppearance.
  ///
  /// In en, this message translates to:
  /// **'Reset Appearance'**
  String get resetAppearance;

  /// No description provided for @gradient.
  ///
  /// In en, this message translates to:
  /// **'Gradient'**
  String get gradient;

  /// No description provided for @setColor.
  ///
  /// In en, this message translates to:
  /// **'Set Color'**
  String get setColor;

  /// No description provided for @addColor.
  ///
  /// In en, this message translates to:
  /// **'Add Color'**
  String get addColor;

  /// No description provided for @removeColor.
  ///
  /// In en, this message translates to:
  /// **'Remove Color'**
  String get removeColor;

  /// No description provided for @rotateGradient.
  ///
  /// In en, this message translates to:
  /// **'Rotate Gradient'**
  String get rotateGradient;

  /// No description provided for @pattern.
  ///
  /// In en, this message translates to:
  /// **'Pattern'**
  String get pattern;

  /// No description provided for @intensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get intensity;

  /// No description provided for @chooseAnImageUpTo20.
  ///
  /// In en, this message translates to:
  /// **'Choose an image up to 20 MB.'**
  String get chooseAnImageUpTo20;

  /// No description provided for @uploadWallpaper.
  ///
  /// In en, this message translates to:
  /// **'Upload Wallpaper'**
  String get uploadWallpaper;

  /// No description provided for @blurWallpaperImage.
  ///
  /// In en, this message translates to:
  /// **'Blur Wallpaper Image'**
  String get blurWallpaperImage;

  /// No description provided for @themeClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get themeClassic;

  /// No description provided for @themeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get themeNight;

  /// No description provided for @themeDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get themeDay;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get themeSystemDefault;

  /// No description provided for @emojiCategorySmileysPeople.
  ///
  /// In en, this message translates to:
  /// **'Smileys & People'**
  String get emojiCategorySmileysPeople;

  /// No description provided for @emojiCategoryAnimalsNature.
  ///
  /// In en, this message translates to:
  /// **'Animals & Nature'**
  String get emojiCategoryAnimalsNature;

  /// No description provided for @emojiCategoryFoodDrink.
  ///
  /// In en, this message translates to:
  /// **'Food & Drink'**
  String get emojiCategoryFoodDrink;

  /// No description provided for @emojiCategoryTravelPlaces.
  ///
  /// In en, this message translates to:
  /// **'Travel & Places'**
  String get emojiCategoryTravelPlaces;

  /// No description provided for @emojiCategoryActivities.
  ///
  /// In en, this message translates to:
  /// **'Activities'**
  String get emojiCategoryActivities;

  /// No description provided for @emojiCategoryObjectsSymbols.
  ///
  /// In en, this message translates to:
  /// **'Objects & Symbols'**
  String get emojiCategoryObjectsSymbols;

  /// No description provided for @emojiCategoryFlags.
  ///
  /// In en, this message translates to:
  /// **'Flags'**
  String get emojiCategoryFlags;

  /// No description provided for @radarActionDislike.
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get radarActionDislike;

  /// No description provided for @matchFilterLiked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get matchFilterLiked;

  /// No description provided for @matchFilterPassed.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get matchFilterPassed;

  /// No description provided for @uploadStatusUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploadStatusUploaded;

  /// No description provided for @uploadStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued'**
  String get uploadStatusQueued;

  /// No description provided for @uploadStatusUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading'**
  String get uploadStatusUploading;

  /// No description provided for @uploadStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get uploadStatusFailed;

  /// No description provided for @profileFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollow;

  /// No description provided for @profileFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowing;

  /// No description provided for @n5Minutes.
  ///
  /// In en, this message translates to:
  /// **'5 Minutes'**
  String get n5Minutes;

  /// No description provided for @n20Minutes.
  ///
  /// In en, this message translates to:
  /// **'20 Minutes'**
  String get n20Minutes;

  /// No description provided for @voiceSlideToCancel.
  ///
  /// In en, this message translates to:
  /// **'Slide to cancel · Slide up to lock'**
  String get voiceSlideToCancel;

  /// No description provided for @voiceRecordingLocked.
  ///
  /// In en, this message translates to:
  /// **'Recording locked'**
  String get voiceRecordingLocked;

  /// No description provided for @chooseLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose Location'**
  String get chooseLocation;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current Location'**
  String get currentLocation;

  /// No description provided for @article.
  ///
  /// In en, this message translates to:
  /// **'Article'**
  String get article;

  /// No description provided for @articlePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Start writing…'**
  String get articlePlaceholder;

  /// No description provided for @redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get redo;

  /// No description provided for @articleBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get articleBold;

  /// No description provided for @articleItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get articleItalic;

  /// No description provided for @articleUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get articleUnderline;

  /// No description provided for @articleStrike.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get articleStrike;

  /// No description provided for @articleSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get articleSpoiler;

  /// No description provided for @articleLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get articleLink;

  /// No description provided for @articleParagraph.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get articleParagraph;

  /// No description provided for @articleHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get articleHeading;

  /// No description provided for @articleQuote.
  ///
  /// In en, this message translates to:
  /// **'Blockquote'**
  String get articleQuote;

  /// No description provided for @articleCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get articleCode;

  /// No description provided for @articleList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get articleList;

  /// No description provided for @articleBullets.
  ///
  /// In en, this message translates to:
  /// **'Bullets'**
  String get articleBullets;

  /// No description provided for @articleNumbered.
  ///
  /// In en, this message translates to:
  /// **'Numbered'**
  String get articleNumbered;

  /// No description provided for @articleChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get articleChecklist;

  /// No description provided for @articleTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get articleTable;

  /// No description provided for @articleAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get articleAddRow;

  /// No description provided for @articleAddColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get articleAddColumn;

  /// No description provided for @articleDeleteRow.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get articleDeleteRow;

  /// No description provided for @articleDeleteColumn.
  ///
  /// In en, this message translates to:
  /// **'Delete column'**
  String get articleDeleteColumn;

  /// No description provided for @articleDeleteTable.
  ///
  /// In en, this message translates to:
  /// **'Delete table'**
  String get articleDeleteTable;

  /// No description provided for @articleRemoveLink.
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get articleRemoveLink;

  /// No description provided for @articleInvalidLink.
  ///
  /// In en, this message translates to:
  /// **'Enter an http, https, mailto or tel link.'**
  String get articleInvalidLink;

  /// No description provided for @articleKeyboard.
  ///
  /// In en, this message translates to:
  /// **'Keyboard'**
  String get articleKeyboard;

  /// No description provided for @expandEmojiPanel.
  ///
  /// In en, this message translates to:
  /// **'Expand emoji panel'**
  String get expandEmojiPanel;

  /// No description provided for @collapseEmojiPanel.
  ///
  /// In en, this message translates to:
  /// **'Collapse emoji panel'**
  String get collapseEmojiPanel;

  /// No description provided for @profileUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get profileUnblock;

  /// No description provided for @profileUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This profile is unavailable.'**
  String get profileUnavailable;

  /// No description provided for @profileJoined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get profileJoined;

  /// No description provided for @profileActivityPrivate.
  ///
  /// In en, this message translates to:
  /// **'This profile’s activity is private.'**
  String get profileActivityPrivate;

  /// No description provided for @profilePublicPhotos.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get profilePublicPhotos;

  /// No description provided for @profileMakePublic.
  ///
  /// In en, this message translates to:
  /// **'Show on profile'**
  String get profileMakePublic;

  /// No description provided for @profileMakePrivate.
  ///
  /// In en, this message translates to:
  /// **'Move to private album'**
  String get profileMakePrivate;

  /// No description provided for @profilePublicPhotoNotice.
  ///
  /// In en, this message translates to:
  /// **'This photo will be visible on your profile.'**
  String get profilePublicPhotoNotice;

  /// No description provided for @profilePrivateUploadNotice.
  ///
  /// In en, this message translates to:
  /// **'New photos are added to your private album.'**
  String get profilePrivateUploadNotice;

  /// No description provided for @profileAccessPending.
  ///
  /// In en, this message translates to:
  /// **'Your access request is pending.'**
  String get profileAccessPending;

  /// No description provided for @profileAlbumLocked.
  ///
  /// In en, this message translates to:
  /// **'Request permission to view this album.'**
  String get profileAlbumLocked;

  /// No description provided for @profileRevokeAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get profileRevokeAccess;

  /// No description provided for @profileAccessApproved.
  ///
  /// In en, this message translates to:
  /// **'Can view your private photos'**
  String get profileAccessApproved;

  /// No description provided for @profileAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access not granted'**
  String get profileAccessDenied;

  /// No description provided for @profileSetPhoto.
  ///
  /// In en, this message translates to:
  /// **'Set New Photo'**
  String get profileSetPhoto;

  /// No description provided for @profileIdentityHelp.
  ///
  /// In en, this message translates to:
  /// **'Enter your name and add an optional profile photo.'**
  String get profileIdentityHelp;

  /// No description provided for @profileBioHelp.
  ///
  /// In en, this message translates to:
  /// **'You can add a few lines about yourself.'**
  String get profileBioHelp;

  /// No description provided for @profileDetails.
  ///
  /// In en, this message translates to:
  /// **'Profile details'**
  String get profileDetails;

  /// No description provided for @profileNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNotSet;

  /// No description provided for @profilePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Level'**
  String get profilePrivacy;

  /// No description provided for @profilePrivacyPublic.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get profilePrivacyPublic;

  /// No description provided for @profilePrivacyFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers only'**
  String get profilePrivacyFollowers;

  /// No description provided for @profilePrivacyFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends only'**
  String get profilePrivacyFriends;

  /// No description provided for @profilePrivacyMutuals.
  ///
  /// In en, this message translates to:
  /// **'Mutual followers only'**
  String get profilePrivacyMutuals;

  /// No description provided for @profilePrivacyPrivate.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get profilePrivacyPrivate;

  /// No description provided for @profilePrivacyHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose who can see your profile. Only public profiles appear in Nearby and Radar. Your private album requires separate approval.'**
  String get profilePrivacyHelp;

  /// No description provided for @profileCoverPhoto.
  ///
  /// In en, this message translates to:
  /// **'Cover Photo'**
  String get profileCoverPhoto;

  /// No description provided for @menuCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get menuCommunity;

  /// No description provided for @menuAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get menuAccount;

  /// No description provided for @profileDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get profileDisplayName;

  /// No description provided for @profilePersonalDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get profilePersonalDetails;

  /// No description provided for @profilePhotoAdjust.
  ///
  /// In en, this message translates to:
  /// **'Drag to reposition. Pinch to zoom.'**
  String get profilePhotoAdjust;

  /// No description provided for @authWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your next connection starts here.'**
  String get authWelcomeTitle;

  /// No description provided for @authWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Already a member? Log in to your account. New to CoolVibes? Create your account and start meeting the community.'**
  String get authWelcomeSubtitle;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLoginTitle;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authRegisterTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use the username and password you chose when you created your account.'**
  String get authLoginSubtitle;

  /// No description provided for @authRegisterChoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New here? Choose your username and password, then complete a quick security check.'**
  String get authRegisterChoiceSubtitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how people will find you. Create a username and password, confirm your password, then continue to the security check.'**
  String get authRegisterSubtitle;

  /// No description provided for @authAccountNote.
  ///
  /// In en, this message translates to:
  /// **'For adults aged 18 and over. Your profile, your identity, your pace.'**
  String get authAccountNote;

  /// No description provided for @authContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// No description provided for @authBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get authBack;

  /// No description provided for @authNickname.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get authNickname;

  /// No description provided for @authNicknamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your username'**
  String get authNicknamePlaceholder;

  /// No description provided for @authPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authPasswordPlaceholder;

  /// No description provided for @authConfirmPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Confirm your password'**
  String get authConfirmPasswordPlaceholder;

  /// No description provided for @authReferralPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter an invite code, if you have one'**
  String get authReferralPlaceholder;

  /// No description provided for @authNicknameHint.
  ///
  /// In en, this message translates to:
  /// **'At least 3 characters: lowercase letters (a–z), numbers, or underscores (_).'**
  String get authNicknameHint;

  /// No description provided for @authNicknameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Username must be at least 3 characters.'**
  String get authNicknameTooShort;

  /// No description provided for @authNicknameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Use only lowercase letters (a–z), numbers, and underscores (_).'**
  String get authNicknameInvalid;

  /// No description provided for @authSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get authSigningIn;

  /// No description provided for @authCreatingAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating account...'**
  String get authCreatingAccount;

  /// No description provided for @profilePhotoRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate left'**
  String get profilePhotoRotate;

  /// No description provided for @profilePhotoMirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror photo'**
  String get profilePhotoMirror;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @errorDetails.
  ///
  /// In en, this message translates to:
  /// **'Error details'**
  String get errorDetails;

  /// No description provided for @errorConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t connect'**
  String get errorConnectionTitle;

  /// No description provided for @errorStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'Session couldn’t be saved'**
  String get errorStorageTitle;

  /// No description provided for @errorRegistrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration couldn’t be completed'**
  String get errorRegistrationTitle;

  /// No description provided for @errorRequestTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t complete this action'**
  String get errorRequestTitle;

  /// No description provided for @errorServerMessage.
  ///
  /// In en, this message translates to:
  /// **'The server couldn’t process your request. Please try again shortly.'**
  String get errorServerMessage;

  /// No description provided for @errorUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'This username is already in use. Choose another one, or sign in if the account is yours.'**
  String get errorUsernameTaken;

  /// No description provided for @errorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'This email is already in use. Sign in with your existing account.'**
  String get errorEmailTaken;

  /// No description provided for @errorReferral.
  ///
  /// In en, this message translates to:
  /// **'The referral code isn’t valid. Check it or leave the optional field empty.'**
  String get errorReferral;

  /// No description provided for @errorCaptcha.
  ///
  /// In en, this message translates to:
  /// **'Verification couldn’t be completed. Please try again.'**
  String get errorCaptcha;

  /// No description provided for @errorInvalidInput.
  ///
  /// In en, this message translates to:
  /// **'Some information wasn’t accepted. Check the form and try again.'**
  String get errorInvalidInput;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a little before trying again.'**
  String get errorRateLimited;

  /// No description provided for @errorForbidden.
  ///
  /// In en, this message translates to:
  /// **'This action isn’t available for your account.'**
  String get errorForbidden;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'This content is no longer available.'**
  String get errorNotFound;

  /// No description provided for @errorStorageMessage.
  ///
  /// In en, this message translates to:
  /// **'The device couldn’t access secure session storage. Reopen the app. If this continues, the app’s Keychain configuration needs to be corrected.'**
  String get errorStorageMessage;

  /// No description provided for @errorUnexpectedMessage.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Your entered information is still here. Please try again.'**
  String get errorUnexpectedMessage;

  /// No description provided for @errorAccountCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get errorAccountCreatedTitle;

  /// No description provided for @errorAccountCreatedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your account was created, but sign-in couldn’t finish on this device. Continue to sign in with the same information.'**
  String get errorAccountCreatedMessage;

  /// No description provided for @forwardCommentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a comment…'**
  String get forwardCommentPlaceholder;

  /// No description provided for @forwardToRecipients.
  ///
  /// In en, this message translates to:
  /// **'Forward to {count} chats'**
  String forwardToRecipients(int count);

  /// No description provided for @forwardPartialFailure.
  ///
  /// In en, this message translates to:
  /// **'Sent to {sent} chats. {remaining} chats couldn’t be completed. Only these remain selected.'**
  String forwardPartialFailure(int sent, int remaining);

  /// No description provided for @forwardedToChats.
  ///
  /// In en, this message translates to:
  /// **'Forwarded to {count} chats'**
  String forwardedToChats(int count);

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Your account will be deleted and you will be signed out. Are you sure you want to continue?'**
  String get deleteAccountConfirmation;

  /// No description provided for @deleteMessagesScopeInfo.
  ///
  /// In en, this message translates to:
  /// **'You can delete these messages just for you or for everyone.'**
  String get deleteMessagesScopeInfo;

  /// No description provided for @deleteMessagesForMeInfo.
  ///
  /// In en, this message translates to:
  /// **'These messages will only be removed from your view of the conversation.'**
  String get deleteMessagesForMeInfo;

  /// No description provided for @profileInfo.
  ///
  /// In en, this message translates to:
  /// **'Profile Info'**
  String get profileInfo;

  /// No description provided for @profileImage.
  ///
  /// In en, this message translates to:
  /// **'Profile Image'**
  String get profileImage;

  /// No description provided for @profileImageHint.
  ///
  /// In en, this message translates to:
  /// **'Click the camera icon to upload a new image'**
  String get profileImageHint;

  /// No description provided for @chatViewOncePhoto.
  ///
  /// In en, this message translates to:
  /// **'View-once photo'**
  String get chatViewOncePhoto;

  /// No description provided for @chatHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Hidden message'**
  String get chatHiddenMessage;

  /// No description provided for @placeDetails.
  ///
  /// In en, this message translates to:
  /// **'Place details'**
  String get placeDetails;

  /// No description provided for @placeDetailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This place could not be loaded.'**
  String get placeDetailsUnavailable;

  /// No description provided for @placeDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get placeDirections;

  /// No description provided for @placeCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get placeCall;

  /// No description provided for @placeContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get placeContact;

  /// No description provided for @placePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get placePhone;

  /// No description provided for @placeNoContact.
  ///
  /// In en, this message translates to:
  /// **'No contact information available.'**
  String get placeNoContact;

  /// No description provided for @placeAddedBy.
  ///
  /// In en, this message translates to:
  /// **'Added by'**
  String get placeAddedBy;

  /// No description provided for @placeDislike.
  ///
  /// In en, this message translates to:
  /// **'Dislike'**
  String get placeDislike;

  /// No description provided for @placeReactionSaved.
  ///
  /// In en, this message translates to:
  /// **'Your reaction was saved.'**
  String get placeReactionSaved;

  /// No description provided for @premiumSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover more. Stand out. Expand your Coolvibes experience.'**
  String get premiumSubtitle;

  /// No description provided for @premiumActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Premium membership is active'**
  String get premiumActiveTitle;

  /// No description provided for @premiumActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Enjoy Premium benefits with this account.'**
  String get premiumActiveBody;

  /// No description provided for @premiumBenefits.
  ///
  /// In en, this message translates to:
  /// **'Premium benefits'**
  String get premiumBenefits;

  /// No description provided for @premiumLiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Live broadcasts'**
  String get premiumLiveTitle;

  /// No description provided for @premiumLiveBody.
  ///
  /// In en, this message translates to:
  /// **'Host your own broadcast and request to join live rooms.'**
  String get premiumLiveBody;

  /// No description provided for @premiumNearbyTitle.
  ///
  /// In en, this message translates to:
  /// **'More ways to discover'**
  String get premiumNearbyTitle;

  /// No description provided for @premiumNearbyBody.
  ///
  /// In en, this message translates to:
  /// **'Explore Bubble and Dome views in Nearby.'**
  String get premiumNearbyBody;

  /// No description provided for @premiumVisibilityTitle.
  ///
  /// In en, this message translates to:
  /// **'Priority visibility'**
  String get premiumVisibilityTitle;

  /// No description provided for @premiumVisibilityBody.
  ///
  /// In en, this message translates to:
  /// **'Stand out across supported discovery surfaces.'**
  String get premiumVisibilityBody;

  /// No description provided for @premiumBadgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium badge'**
  String get premiumBadgeTitle;

  /// No description provided for @premiumBadgeBody.
  ///
  /// In en, this message translates to:
  /// **'Show your membership badge on supported surfaces.'**
  String get premiumBadgeBody;

  /// No description provided for @premiumAccountNote.
  ///
  /// In en, this message translates to:
  /// **'Review current plans, prices and membership options on your account page.'**
  String get premiumAccountNote;

  /// No description provided for @premiumTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms and privacy'**
  String get premiumTerms;

  /// No description provided for @premiumExplore.
  ///
  /// In en, this message translates to:
  /// **'Explore Premium'**
  String get premiumExplore;

  /// No description provided for @premiumManage.
  ///
  /// In en, this message translates to:
  /// **'Manage membership'**
  String get premiumManage;

  /// No description provided for @classifiedDetails.
  ///
  /// In en, this message translates to:
  /// **'Listing details'**
  String get classifiedDetails;

  /// No description provided for @classifiedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This listing could not be loaded. Please try again.'**
  String get classifiedUnavailable;

  /// No description provided for @classifiedIntro.
  ///
  /// In en, this message translates to:
  /// **'Community listings for work, roommates and new opportunities.'**
  String get classifiedIntro;

  /// No description provided for @classifiedSearch.
  ///
  /// In en, this message translates to:
  /// **'Search listings'**
  String get classifiedSearch;

  /// No description provided for @classifiedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No listings yet'**
  String get classifiedEmpty;

  /// No description provided for @classifiedEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Share the first listing with the community.'**
  String get classifiedEmptyBody;

  /// No description provided for @classifiedNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching listings'**
  String get classifiedNoResults;

  /// No description provided for @classifiedSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Try another title or keyword.'**
  String get classifiedSearchHint;

  /// No description provided for @classifiedIncompleteDetail.
  ///
  /// In en, this message translates to:
  /// **'Enter both a label and a value for each detail.'**
  String get classifiedIncompleteDetail;

  /// No description provided for @classifiedCreateHint.
  ///
  /// In en, this message translates to:
  /// **'Add a title and details, then write your description below.'**
  String get classifiedCreateHint;

  /// No description provided for @classifiedTitleHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Looking for a roommate'**
  String get classifiedTitleHint;

  /// No description provided for @classifiedExtraDetails.
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get classifiedExtraDetails;

  /// No description provided for @classifiedDetailHint.
  ///
  /// In en, this message translates to:
  /// **'Add details such as location, price or working arrangements.'**
  String get classifiedDetailHint;

  /// No description provided for @classifiedLabelHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Location'**
  String get classifiedLabelHint;

  /// No description provided for @classifiedValueHint.
  ///
  /// In en, this message translates to:
  /// **'For example: Central London'**
  String get classifiedValueHint;

  /// No description provided for @classifiedDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your listing…'**
  String get classifiedDescriptionHint;

  /// No description provided for @legalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Documents could not be loaded. Please try again.'**
  String get legalUnavailable;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationTitle;

  /// No description provided for @notificationReactions.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get notificationReactions;

  /// No description provided for @notificationPeople.
  ///
  /// In en, this message translates to:
  /// **'Follows and friends'**
  String get notificationPeople;

  /// No description provided for @notificationGifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get notificationGifts;

  /// No description provided for @notificationOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get notificationOther;

  /// No description provided for @notificationFilter.
  ///
  /// In en, this message translates to:
  /// **'Notification type'**
  String get notificationFilter;

  /// No description provided for @notificationUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notificationUnread;

  /// No description provided for @notificationEmpty.
  ///
  /// In en, this message translates to:
  /// **'No notifications here'**
  String get notificationEmpty;

  /// No description provided for @notificationEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'New activity in this category will appear here.'**
  String get notificationEmptyBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
