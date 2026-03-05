import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Hayatify AR Drawing'**
  String get appTitle;

  /// No description provided for @appVersion.
  ///
  /// In en, this message translates to:
  /// **'Version 1.0.3 - Hayatify: AR Draw'**
  String get appVersion;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @noFavoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'No Favorites Yet'**
  String get noFavoritesTitle;

  /// No description provided for @noFavoritesDesc.
  ///
  /// In en, this message translates to:
  /// **'Leave a heart on your favorite designs!'**
  String get noFavoritesDesc;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join the magic AR world'**
  String get welcomeSubtitle;

  /// No description provided for @googleLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get googleLogin;

  /// No description provided for @appleLogin.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get appleLogin;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'Or'**
  String get or;

  /// No description provided for @guestLogin.
  ///
  /// In en, this message translates to:
  /// **'Start as Guest'**
  String get guestLogin;

  /// No description provided for @permissionError.
  ///
  /// In en, this message translates to:
  /// **'Camera and Microphone permissions are required. 📸🎤'**
  String get permissionError;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get getStarted;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Drawing History'**
  String get historyTitle;

  /// No description provided for @noHistoryDesc.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t completed any drawings yet.'**
  String get noHistoryDesc;

  /// No description provided for @historyCompleted.
  ///
  /// In en, this message translates to:
  /// **'Successfully completed'**
  String get historyCompleted;

  /// No description provided for @onb1Title.
  ///
  /// In en, this message translates to:
  /// **'Magic AR Drawing'**
  String get onb1Title;

  /// No description provided for @onb1Desc.
  ///
  /// In en, this message translates to:
  /// **'Fix your phone and transfer lines to your paper easily.'**
  String get onb1Desc;

  /// No description provided for @onb2Title.
  ///
  /// In en, this message translates to:
  /// **'Learn Step by Step'**
  String get onb2Title;

  /// No description provided for @onb2Desc.
  ///
  /// In en, this message translates to:
  /// **'Improve your skills with hundreds of templates.'**
  String get onb2Desc;

  /// No description provided for @onb3Title.
  ///
  /// In en, this message translates to:
  /// **'Gallery to Template'**
  String get onb3Title;

  /// No description provided for @onb3Desc.
  ///
  /// In en, this message translates to:
  /// **'Pick any photo from your gallery and start drawing instantly.'**
  String get onb3Desc;

  /// No description provided for @onb4Title.
  ///
  /// In en, this message translates to:
  /// **'Level Up'**
  String get onb4Title;

  /// No description provided for @onb4Desc.
  ///
  /// In en, this message translates to:
  /// **'Earn XP and turn from a \'Rookie\' to an \'Artist\'!'**
  String get onb4Desc;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navLearn.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get navLearn;

  /// No description provided for @navPro.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get navPro;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @drawingSchool.
  ///
  /// In en, this message translates to:
  /// **'Drawing School'**
  String get drawingSchool;

  /// No description provided for @drawingSchoolDesc.
  ///
  /// In en, this message translates to:
  /// **'Improve your drawing skills step by step and level up by earning XP.'**
  String get drawingSchoolDesc;

  /// No description provided for @freeAtelier.
  ///
  /// In en, this message translates to:
  /// **'Free Atelier'**
  String get freeAtelier;

  /// No description provided for @freeAtelierDesc.
  ///
  /// In en, this message translates to:
  /// **'Explore ready templates or draw from your own gallery.'**
  String get freeAtelierDesc;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'MY PROFILE'**
  String get profileTitle;

  /// No description provided for @rankLabel.
  ///
  /// In en, this message translates to:
  /// **'Rank'**
  String get rankLabel;

  /// No description provided for @rankRookie.
  ///
  /// In en, this message translates to:
  /// **'Rookie'**
  String get rankRookie;

  /// No description provided for @rankArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get rankArtist;

  /// No description provided for @rankMaster.
  ///
  /// In en, this message translates to:
  /// **'Apprentice'**
  String get rankMaster;

  /// No description provided for @rankExplorer.
  ///
  /// In en, this message translates to:
  /// **'Art Explorer'**
  String get rankExplorer;

  /// No description provided for @rankLegend.
  ///
  /// In en, this message translates to:
  /// **'Legendary Artist'**
  String get rankLegend;

  /// No description provided for @activities.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITIES'**
  String get activities;

  /// No description provided for @drawYourPhoto.
  ///
  /// In en, this message translates to:
  /// **'Draw Your Photo'**
  String get drawYourPhoto;

  /// No description provided for @myHistory.
  ///
  /// In en, this message translates to:
  /// **'My Drawing History'**
  String get myHistory;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get support;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @aboutUs.
  ///
  /// In en, this message translates to:
  /// **'About Us'**
  String get aboutUs;

  /// No description provided for @developmentLevel.
  ///
  /// In en, this message translates to:
  /// **'MY PROGRESS'**
  String get developmentLevel;

  /// No description provided for @congratsArtist.
  ///
  /// In en, this message translates to:
  /// **'Congrats, you are an Artist! 🎨'**
  String get congratsArtist;

  /// No description provided for @roadmapTitle.
  ///
  /// In en, this message translates to:
  /// **'MY PROGRESS JOURNEY'**
  String get roadmapTitle;

  /// No description provided for @xpToTarget.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP left to target'**
  String xpToTarget(int xp);

  /// No description provided for @totalXpDisplay.
  ///
  /// In en, this message translates to:
  /// **'{xp} TOTAL XP'**
  String totalXpDisplay(int xp);

  /// No description provided for @xpRequired.
  ///
  /// In en, this message translates to:
  /// **'{xp} XP REQUIRED'**
  String xpRequired(int xp);

  /// No description provided for @proTitle.
  ///
  /// In en, this message translates to:
  /// **'HAYATIFY PRO'**
  String get proTitle;

  /// No description provided for @proDesc.
  ///
  /// In en, this message translates to:
  /// **'Unlock all and draw unlimited'**
  String get proDesc;

  /// No description provided for @proSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove limits, set your art free!'**
  String get proSubtitle;

  /// No description provided for @feature1.
  ///
  /// In en, this message translates to:
  /// **'Access All Templates'**
  String get feature1;

  /// No description provided for @feature2.
  ///
  /// In en, this message translates to:
  /// **'Ad-Free Experience'**
  String get feature2;

  /// No description provided for @feature3.
  ///
  /// In en, this message translates to:
  /// **'Unlimited Drawing Time'**
  String get feature3;

  /// No description provided for @feature4.
  ///
  /// In en, this message translates to:
  /// **'Special Brush Tools'**
  String get feature4;

  /// No description provided for @buyButton.
  ///
  /// In en, this message translates to:
  /// **'GO PRO & START'**
  String get buyButton;

  /// No description provided for @cancelPolicy.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime you want.'**
  String get cancelPolicy;

  /// No description provided for @congratsPro.
  ///
  /// In en, this message translates to:
  /// **'Congrats! You are now a PRO member! 👑'**
  String get congratsPro;

  /// No description provided for @proMonthly.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY PLAN'**
  String get proMonthly;

  /// No description provided for @proYearly.
  ///
  /// In en, this message translates to:
  /// **'YEARLY PLAN'**
  String get proYearly;

  /// No description provided for @freeTrial.
  ///
  /// In en, this message translates to:
  /// **'7 Days Free'**
  String get freeTrial;

  /// No description provided for @proMember.
  ///
  /// In en, this message translates to:
  /// **'Pro Membership'**
  String get proMember;

  /// No description provided for @proBenefits.
  ///
  /// In en, this message translates to:
  /// **'Pro Benefits'**
  String get proBenefits;

  /// No description provided for @proBenefitsList.
  ///
  /// In en, this message translates to:
  /// **'• Unlimited access to premium templates\n• Ad-free experience\n• VIP Support\n• Early access to new features'**
  String get proBenefitsList;

  /// No description provided for @sketchTemplate.
  ///
  /// In en, this message translates to:
  /// **'Pencil Sketch'**
  String get sketchTemplate;

  /// No description provided for @sketchDesc.
  ///
  /// In en, this message translates to:
  /// **'Convert image to line art template'**
  String get sketchDesc;

  /// No description provided for @originalPhoto.
  ///
  /// In en, this message translates to:
  /// **'Original Photo'**
  String get originalPhoto;

  /// No description provided for @originalDesc.
  ///
  /// In en, this message translates to:
  /// **'Project the image as it is'**
  String get originalDesc;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'BEGINNER'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'INTERMEDIATE'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'ADVANCED'**
  String get difficultyHard;

  /// No description provided for @resumeDrawing.
  ///
  /// In en, this message translates to:
  /// **'Resume?'**
  String get resumeDrawing;

  /// No description provided for @resumeDesc.
  ///
  /// In en, this message translates to:
  /// **'Would you like to continue {title}?'**
  String resumeDesc(String title);

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get startOver;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @startDrawing.
  ///
  /// In en, this message translates to:
  /// **'Start Drawing'**
  String get startDrawing;

  /// No description provided for @sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sort;

  /// No description provided for @newest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get newest;

  /// No description provided for @oldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get oldest;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @drawYourOwn.
  ///
  /// In en, this message translates to:
  /// **'Draw Your Own Photo'**
  String get drawYourOwn;

  /// No description provided for @doneLabel.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get doneLabel;

  /// No description provided for @drawAgain.
  ///
  /// In en, this message translates to:
  /// **'DRAW AGAIN'**
  String get drawAgain;

  /// No description provided for @earnXp.
  ///
  /// In en, this message translates to:
  /// **'EARN +100 XP'**
  String get earnXp;

  /// No description provided for @stepsLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} Steps + Painting'**
  String stepsLabel(int count);

  /// No description provided for @templatesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} templates'**
  String templatesCount(int count);

  /// No description provided for @animals.
  ///
  /// In en, this message translates to:
  /// **'Animals'**
  String get animals;

  /// No description provided for @cars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get cars;

  /// No description provided for @anime.
  ///
  /// In en, this message translates to:
  /// **'Anime'**
  String get anime;

  /// No description provided for @cartoon.
  ///
  /// In en, this message translates to:
  /// **'Cartoon'**
  String get cartoon;

  /// No description provided for @flowers.
  ///
  /// In en, this message translates to:
  /// **'Flowers'**
  String get flowers;

  /// No description provided for @human.
  ///
  /// In en, this message translates to:
  /// **'Humans'**
  String get human;

  /// No description provided for @nature.
  ///
  /// In en, this message translates to:
  /// **'Nature'**
  String get nature;

  /// No description provided for @tattoo.
  ///
  /// In en, this message translates to:
  /// **'Tattoo'**
  String get tattoo;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help and Features'**
  String get helpTitle;

  /// No description provided for @magicAssistant.
  ///
  /// In en, this message translates to:
  /// **'MAGIC ASSISTANT'**
  String get magicAssistant;

  /// No description provided for @voiceCommands.
  ///
  /// In en, this message translates to:
  /// **'Voice Commands'**
  String get voiceCommands;

  /// No description provided for @voiceCommandsDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage the app without taking your hands off the paper! Just say these commands:'**
  String get voiceCommandsDesc;

  /// No description provided for @voiceCommandsList.
  ///
  /// In en, this message translates to:
  /// **'• \"Next\" / \"Back\"\n• \"Step 4\"\n• \"Lock\" / \"Unlock\"\n• \"Opacity 50\"\n• \"Grid 4\" / \"Grid Off\"\n• \"Mirror\"'**
  String get voiceCommandsList;

  /// No description provided for @toolsLabel.
  ///
  /// In en, this message translates to:
  /// **'TOOLS'**
  String get toolsLabel;

  /// No description provided for @toolArMode.
  ///
  /// In en, this message translates to:
  /// **'AR Mode'**
  String get toolArMode;

  /// No description provided for @toolArModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Projects the template onto paper using the camera. Fix your phone and draw by looking through the screen.'**
  String get toolArModeDesc;

  /// No description provided for @toolLock.
  ///
  /// In en, this message translates to:
  /// **'Screen Lock'**
  String get toolLock;

  /// No description provided for @toolLockDesc.
  ///
  /// In en, this message translates to:
  /// **'Prevents the template from shifting while drawing by freezing the screen.'**
  String get toolLockDesc;

  /// No description provided for @toolOpacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get toolOpacity;

  /// No description provided for @toolOpacityDesc.
  ///
  /// In en, this message translates to:
  /// **'Adjusts the transparency of the template on the camera feed.'**
  String get toolOpacityDesc;

  /// No description provided for @toolGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get toolGrid;

  /// No description provided for @toolGridDesc.
  ///
  /// In en, this message translates to:
  /// **'Adds guide lines for better proportions on paper.'**
  String get toolGridDesc;

  /// No description provided for @toolMirror.
  ///
  /// In en, this message translates to:
  /// **'Mirror Mode'**
  String get toolMirror;

  /// No description provided for @toolMirrorDesc.
  ///
  /// In en, this message translates to:
  /// **'Flips the template horizontally. Ideal for symmetry or tattoo designs.'**
  String get toolMirrorDesc;

  /// No description provided for @toolFlash.
  ///
  /// In en, this message translates to:
  /// **'Flash Support'**
  String get toolFlash;

  /// No description provided for @toolFlashDesc.
  ///
  /// In en, this message translates to:
  /// **'Turns on the flashlight to see the paper better in dark environments.'**
  String get toolFlashDesc;

  /// No description provided for @contentTemplatesLabel.
  ///
  /// In en, this message translates to:
  /// **'CONTENT & TEMPLATES'**
  String get contentTemplatesLabel;

  /// No description provided for @categoriesLabel.
  ///
  /// In en, this message translates to:
  /// **'Hundreds of Categories'**
  String get categoriesLabel;

  /// No description provided for @categoriesDesc.
  ///
  /// In en, this message translates to:
  /// **'Explore hundreds of templates from animals to cars.'**
  String get categoriesDesc;

  /// No description provided for @progressXpLabel.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS & XP'**
  String get progressXpLabel;

  /// No description provided for @howToEarnXp.
  ///
  /// In en, this message translates to:
  /// **'How to Earn XP?'**
  String get howToEarnXp;

  /// No description provided for @howToEarnXpDesc.
  ///
  /// In en, this message translates to:
  /// **'Earn +100 XP instantly when you complete (Finish) a drawing.'**
  String get howToEarnXpDesc;

  /// No description provided for @levelSystem.
  ///
  /// In en, this message translates to:
  /// **'Level System'**
  String get levelSystem;

  /// No description provided for @levelSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Collect XP to level up from a Rookie to a master Artist.'**
  String get levelSystemDesc;

  /// No description provided for @aboutSlogan.
  ///
  /// In en, this message translates to:
  /// **'Bring Your Drawings to Life!'**
  String get aboutSlogan;

  /// No description provided for @ourStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Our Story'**
  String get ourStoryTitle;

  /// No description provided for @ourStoryDesc.
  ///
  /// In en, this message translates to:
  /// **'We believe that an artist lies within everyone, but sometimes they just need a little guidance. Hayatify was born to make art accessible and fun for everyone by combining complex drawing techniques with Augmented Reality (AR) and AI.'**
  String get ourStoryDesc;

  /// No description provided for @ourMissionTitle.
  ///
  /// In en, this message translates to:
  /// **'Our Mission'**
  String get ourMissionTitle;

  /// No description provided for @ourMissionDesc.
  ///
  /// In en, this message translates to:
  /// **'We want to be more than just an app; we want to be a progress companion. Whether you\'re a rookie picking up a pencil for the first time or a master sharpening your skills, our passion is to accompany your art journey with voice commands, hundreds of templates, and our leveling system.'**
  String get ourMissionDesc;

  /// No description provided for @stayConnected.
  ///
  /// In en, this message translates to:
  /// **'Stay Connected'**
  String get stayConnected;

  /// No description provided for @visitWebsite.
  ///
  /// In en, this message translates to:
  /// **'Visit Our Website'**
  String get visitWebsite;

  /// No description provided for @followInstagram.
  ///
  /// In en, this message translates to:
  /// **'Follow Us on Instagram'**
  String get followInstagram;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Us for Support'**
  String get contactSupport;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;
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
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
