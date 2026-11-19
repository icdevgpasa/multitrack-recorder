import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

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
    Locale('en'),
    Locale('pl'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NagrajTo'**
  String get appTitle;

  /// No description provided for @songsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your songs'**
  String get songsTitle;

  /// No description provided for @newSong.
  ///
  /// In en, this message translates to:
  /// **'New song'**
  String get newSong;

  /// No description provided for @noSongsYet.
  ///
  /// In en, this message translates to:
  /// **'No songs yet.\nStart with “New song”.'**
  String get noSongsYet;

  /// No description provided for @deleteSongTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete song'**
  String get deleteSongTooltip;

  /// No description provided for @deleteSongTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteSongTitle(String name);

  /// No description provided for @deleteSongBody.
  ///
  /// In en, this message translates to:
  /// **'All recorded tracks will be deleted.'**
  String get deleteSongBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @trackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 track} other{{count} tracks}}'**
  String trackCount(int count);

  /// No description provided for @defaultSongName.
  ///
  /// In en, this message translates to:
  /// **'Song {number}'**
  String defaultSongName(int number);

  /// No description provided for @defaultTrackName.
  ///
  /// In en, this message translates to:
  /// **'Track {number}'**
  String defaultTrackName(int number);

  /// No description provided for @noMicPermission.
  ///
  /// In en, this message translates to:
  /// **'No access to the microphone.\nTurn it on in iOS Settings.'**
  String get noMicPermission;

  /// No description provided for @audioStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start audio.\n{error}'**
  String audioStartFailed(String error);

  /// No description provided for @recordFirstTrack.
  ///
  /// In en, this message translates to:
  /// **'Record your first track.\nRecord the next ones while listening to the previous.'**
  String get recordFirstTrack;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exporting;

  /// No description provided for @backToSongs.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get backToSongs;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportTitle;

  /// No description provided for @noCountIn.
  ///
  /// In en, this message translates to:
  /// **'No count-in'**
  String get noCountIn;

  /// No description provided for @countInBars.
  ///
  /// In en, this message translates to:
  /// **'Count-in {bars}'**
  String countInBars(int bars);

  /// No description provided for @metronomeOff.
  ///
  /// In en, this message translates to:
  /// **'Turn metronome off'**
  String get metronomeOff;

  /// No description provided for @metronomeOn.
  ///
  /// In en, this message translates to:
  /// **'Turn metronome on'**
  String get metronomeOn;

  /// No description provided for @songName.
  ///
  /// In en, this message translates to:
  /// **'Song name'**
  String get songName;

  /// No description provided for @trackName.
  ///
  /// In en, this message translates to:
  /// **'Track name'**
  String get trackName;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @nothingToExport.
  ///
  /// In en, this message translates to:
  /// **'no tracks to export'**
  String get nothingToExport;

  /// No description provided for @exportMixM4a.
  ///
  /// In en, this message translates to:
  /// **'Whole song (M4A)'**
  String get exportMixM4a;

  /// No description provided for @exportMixM4aHint.
  ///
  /// In en, this message translates to:
  /// **'Small file to send or listen to'**
  String get exportMixM4aHint;

  /// No description provided for @exportMixWav.
  ///
  /// In en, this message translates to:
  /// **'Whole song (WAV)'**
  String get exportMixWav;

  /// No description provided for @exportMixWavHint.
  ///
  /// In en, this message translates to:
  /// **'Lossless, 24-bit'**
  String get exportMixWavHint;

  /// No description provided for @exportStems.
  ///
  /// In en, this message translates to:
  /// **'Separate tracks (WAV)'**
  String get exportStems;

  /// No description provided for @exportStemsHint.
  ///
  /// In en, this message translates to:
  /// **'Each track on its own, for your DAW'**
  String get exportStemsHint;

  /// No description provided for @soloOn.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get soloOn;

  /// No description provided for @soloOff.
  ///
  /// In en, this message translates to:
  /// **'Turn solo off'**
  String get soloOff;

  /// No description provided for @mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get mute;

  /// No description provided for @unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmute;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @makeLouder.
  ///
  /// In en, this message translates to:
  /// **'Make louder (normalize)'**
  String get makeLouder;

  /// No description provided for @deleteTrack.
  ///
  /// In en, this message translates to:
  /// **'Delete track'**
  String get deleteTrack;

  /// No description provided for @waveformLabel.
  ///
  /// In en, this message translates to:
  /// **'Waveform of {name}, tap to play from here'**
  String waveformLabel(String name);

  /// No description provided for @madeLouder.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is louder now.'**
  String madeLouder(String name);

  /// No description provided for @alreadyLoud.
  ///
  /// In en, this message translates to:
  /// **'This track is already loud enough.'**
  String get alreadyLoud;

  /// No description provided for @panLeft.
  ///
  /// In en, this message translates to:
  /// **'L{amount}'**
  String panLeft(int amount);

  /// No description provided for @panRight.
  ///
  /// In en, this message translates to:
  /// **'R{amount}'**
  String panRight(int amount);

  /// No description provided for @panCenter.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get panCenter;

  /// No description provided for @master.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get master;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @countingIn.
  ///
  /// In en, this message translates to:
  /// **'Count-in…'**
  String get countingIn;

  /// No description provided for @recording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get recording;

  /// No description provided for @record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get record;

  /// No description provided for @stopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get stopRecording;

  /// No description provided for @micGainLabel.
  ///
  /// In en, this message translates to:
  /// **'Microphone gain {db} dB'**
  String micGainLabel(int db);

  /// No description provided for @micGainTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone gain: +{db} dB'**
  String micGainTitle(int db);

  /// No description provided for @micGainHint.
  ///
  /// In en, this message translates to:
  /// **'Play as loud as you will: the bar should reach yellow, but not red.'**
  String get micGainHint;

  /// No description provided for @audioSettings.
  ///
  /// In en, this message translates to:
  /// **'Audio settings'**
  String get audioSettings;

  /// No description provided for @monitoringTitle.
  ///
  /// In en, this message translates to:
  /// **'Hear yourself (monitoring)'**
  String get monitoringTitle;

  /// No description provided for @monitoringHint.
  ///
  /// In en, this message translates to:
  /// **'Hear your instrument in the headphones while recording. Headphones only: on the speaker it would howl.'**
  String get monitoringHint;

  /// No description provided for @monitoringBlocked.
  ///
  /// In en, this message translates to:
  /// **'Plug in headphones to hear yourself.'**
  String get monitoringBlocked;

  /// No description provided for @monitoringBluetooth.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth headphones add a noticeable delay; wired ones are best for monitoring.'**
  String get monitoringBluetooth;

  /// No description provided for @monitorVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get monitorVolume;

  /// No description provided for @monitorReverb.
  ///
  /// In en, this message translates to:
  /// **'Reverb'**
  String get monitorReverb;

  /// No description provided for @monitoringOn.
  ///
  /// In en, this message translates to:
  /// **'Turn monitoring on'**
  String get monitoringOn;

  /// No description provided for @monitoringOff.
  ///
  /// In en, this message translates to:
  /// **'Turn monitoring off'**
  String get monitoringOff;

  /// No description provided for @calibrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Latency calibration'**
  String get calibrationTitle;

  /// No description provided for @calibrationHint.
  ///
  /// In en, this message translates to:
  /// **'Makes new takes land exactly in time. Calibrate once for each output you use.'**
  String get calibrationHint;

  /// No description provided for @currentOutput.
  ///
  /// In en, this message translates to:
  /// **'Output: {name}'**
  String currentOutput(String name);

  /// No description provided for @notCalibrated.
  ///
  /// In en, this message translates to:
  /// **'Not calibrated yet'**
  String get notCalibrated;

  /// No description provided for @calibratedOffset.
  ///
  /// In en, this message translates to:
  /// **'Correction: {ms} ms'**
  String calibratedOffset(String ms);

  /// No description provided for @calibrate.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get calibrate;

  /// No description provided for @calibrating.
  ///
  /// In en, this message translates to:
  /// **'Listening for clicks…'**
  String get calibrating;

  /// No description provided for @resetCalibration.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetCalibration;

  /// No description provided for @calibrationHowTo.
  ///
  /// In en, this message translates to:
  /// **'Be quiet for 4 seconds. Speaker: leave the phone on the table, volume up. Headphones: hold an earpiece right against the phone\'s microphone (bottom edge).'**
  String get calibrationHowTo;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @calibrationDone.
  ///
  /// In en, this message translates to:
  /// **'Calibrated: round trip {ms} ms.'**
  String calibrationDone(String ms);

  /// No description provided for @calibrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t hear the clicks. Turn the volume up and try again.'**
  String get calibrationFailed;

  /// No description provided for @editTrack.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editTrack;

  /// No description provided for @editTrackTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit: {name}'**
  String editTrackTitle(String name);

  /// No description provided for @trimTitle.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get trimTitle;

  /// No description provided for @trimHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the ends to cut silence or mistakes at the start and end.'**
  String get trimHint;

  /// No description provided for @fadeIn.
  ///
  /// In en, this message translates to:
  /// **'Fade in'**
  String get fadeIn;

  /// No description provided for @fadeOut.
  ///
  /// In en, this message translates to:
  /// **'Fade out'**
  String get fadeOut;

  /// No description provided for @shiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Move in time'**
  String get shiftTitle;

  /// No description provided for @shiftHint.
  ///
  /// In en, this message translates to:
  /// **'Line the take up with the beat. Positive is later.'**
  String get shiftHint;

  /// No description provided for @shiftValue.
  ///
  /// In en, this message translates to:
  /// **'{value} ms'**
  String shiftValue(String value);

  /// No description provided for @beatShort.
  ///
  /// In en, this message translates to:
  /// **'beat'**
  String get beatShort;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @restoreOriginal.
  ///
  /// In en, this message translates to:
  /// **'Restore original'**
  String get restoreOriginal;

  /// No description provided for @editFailed.
  ///
  /// In en, this message translates to:
  /// **'Nothing would be left of the track.'**
  String get editFailed;

  /// No description provided for @editApplied.
  ///
  /// In en, this message translates to:
  /// **'Changes saved to \"{name}\".'**
  String editApplied(String name);
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
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
