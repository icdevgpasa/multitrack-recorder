// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'NagrajTo';

  @override
  String get songsTitle => 'Your songs';

  @override
  String get newSong => 'New song';

  @override
  String get noSongsYet => 'No songs yet.\nStart with “New song”.';

  @override
  String get deleteSongTooltip => 'Delete song';

  @override
  String deleteSongTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String get deleteSongBody => 'All recorded tracks will be deleted.';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tracks',
      one: '1 track',
    );
    return '$_temp0';
  }

  @override
  String defaultSongName(int number) {
    return 'Song $number';
  }

  @override
  String defaultTrackName(int number) {
    return 'Track $number';
  }

  @override
  String get noMicPermission =>
      'No access to the microphone.\nTurn it on in iOS Settings.';

  @override
  String audioStartFailed(String error) {
    return 'Couldn\'t start audio.\n$error';
  }

  @override
  String get recordFirstTrack =>
      'Record your first track.\nRecord the next ones while listening to the previous.';

  @override
  String get exporting => 'Exporting…';

  @override
  String get backToSongs => 'Songs';

  @override
  String get export => 'Export';

  @override
  String get exportTitle => 'Export';

  @override
  String get noCountIn => 'No count-in';

  @override
  String countInBars(int bars) {
    return 'Count-in $bars';
  }

  @override
  String get metronomeOff => 'Turn metronome off';

  @override
  String get metronomeOn => 'Turn metronome on';

  @override
  String get songName => 'Song name';

  @override
  String get trackName => 'Track name';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get nothingToExport => 'no tracks to export';

  @override
  String get exportMixM4a => 'Whole song (M4A)';

  @override
  String get exportMixM4aHint => 'Small file to send or listen to';

  @override
  String get exportMixWav => 'Whole song (WAV)';

  @override
  String get exportMixWavHint => 'Lossless, 24-bit';

  @override
  String get exportStems => 'Separate tracks (WAV)';

  @override
  String get exportStemsHint => 'Each track on its own, for your DAW';

  @override
  String get soloOn => 'Solo';

  @override
  String get soloOff => 'Turn solo off';

  @override
  String get mute => 'Mute';

  @override
  String get unmute => 'Unmute';

  @override
  String get rename => 'Rename';

  @override
  String get makeLouder => 'Make louder (normalize)';

  @override
  String get deleteTrack => 'Delete track';

  @override
  String waveformLabel(String name) {
    return 'Waveform of $name, tap to play from here';
  }

  @override
  String madeLouder(String name) {
    return '“$name” is louder now.';
  }

  @override
  String get alreadyLoud => 'This track is already loud enough.';

  @override
  String panLeft(int amount) {
    return 'L$amount';
  }

  @override
  String panRight(int amount) {
    return 'R$amount';
  }

  @override
  String get panCenter => 'C';

  @override
  String get master => 'Master';

  @override
  String get stop => 'Stop';

  @override
  String get play => 'Play';

  @override
  String get countingIn => 'Count-in…';

  @override
  String get recording => 'Recording…';

  @override
  String get record => 'Record';

  @override
  String get stopRecording => 'Stop recording';

  @override
  String micGainLabel(int db) {
    return 'Microphone gain $db dB';
  }

  @override
  String micGainTitle(int db) {
    return 'Microphone gain: +$db dB';
  }

  @override
  String get micGainHint =>
      'Play as loud as you will: the bar should reach yellow, but not red.';
}
