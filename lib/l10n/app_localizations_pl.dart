// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appTitle => 'NagrajTo';

  @override
  String get songsTitle => 'Twoje utwory';

  @override
  String get newSong => 'Nowy utwór';

  @override
  String get noSongsYet =>
      'Nie masz jeszcze żadnego utworu.\nZacznij od „Nowy utwór”.';

  @override
  String get deleteSongTooltip => 'Usuń utwór';

  @override
  String deleteSongTitle(String name) {
    return 'Usunąć „$name”?';
  }

  @override
  String get deleteSongBody => 'Wszystkie nagrane ścieżki zostaną usunięte.';

  @override
  String get cancel => 'Anuluj';

  @override
  String get delete => 'Usuń';

  @override
  String get save => 'Zapisz';

  @override
  String trackCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ścieżki',
      many: '$count ścieżek',
      few: '$count ścieżki',
      one: '1 ścieżka',
    );
    return '$_temp0';
  }

  @override
  String defaultSongName(int number) {
    return 'Utwór $number';
  }

  @override
  String defaultTrackName(int number) {
    return 'Ścieżka $number';
  }

  @override
  String get noMicPermission =>
      'Brak dostępu do mikrofonu.\nWłącz go w Ustawieniach iOS.';

  @override
  String audioStartFailed(String error) {
    return 'Nie udało się uruchomić audio.\n$error';
  }

  @override
  String get recordFirstTrack =>
      'Nagraj pierwszą ścieżkę.\nKolejne nagrasz, słuchając poprzednich.';

  @override
  String get exporting => 'Eksportuję…';

  @override
  String get backToSongs => 'Utwory';

  @override
  String get export => 'Eksportuj';

  @override
  String get exportTitle => 'Eksport';

  @override
  String get noCountIn => 'Bez odliczania';

  @override
  String countInBars(int bars) {
    return 'Odliczanie $bars';
  }

  @override
  String get metronomeOff => 'Wyłącz metronom';

  @override
  String get metronomeOn => 'Włącz metronom';

  @override
  String get songName => 'Nazwa utworu';

  @override
  String get trackName => 'Nazwa ścieżki';

  @override
  String exportFailed(String error) {
    return 'Eksport nie wyszedł: $error';
  }

  @override
  String get nothingToExport => 'brak ścieżek do eksportu';

  @override
  String get exportMixM4a => 'Cały utwór (M4A)';

  @override
  String get exportMixM4aHint => 'Mały plik do wysłania lub odsłuchu';

  @override
  String get exportMixWav => 'Cały utwór (WAV)';

  @override
  String get exportMixWavHint => 'Bez strat jakości, 24 bit';

  @override
  String get exportStems => 'Pojedyncze ścieżki (WAV)';

  @override
  String get exportStemsHint => 'Każda ścieżka osobno, do dalszej pracy w DAW';

  @override
  String get soloOn => 'Solo';

  @override
  String get soloOff => 'Wyłącz solo';

  @override
  String get mute => 'Wycisz';

  @override
  String get unmute => 'Włącz dźwięk';

  @override
  String get rename => 'Zmień nazwę';

  @override
  String get makeLouder => 'Podgłośnij (normalizuj)';

  @override
  String get deleteTrack => 'Usuń ścieżkę';

  @override
  String waveformLabel(String name) {
    return 'Przebieg ścieżki $name, dotknij, aby odtworzyć od tego miejsca';
  }

  @override
  String madeLouder(String name) {
    return 'Ścieżka „$name” jest teraz głośniejsza.';
  }

  @override
  String get alreadyLoud => 'Ta ścieżka jest już wystarczająco głośna.';

  @override
  String panLeft(int amount) {
    return 'L$amount';
  }

  @override
  String panRight(int amount) {
    return 'P$amount';
  }

  @override
  String get panCenter => 'C';

  @override
  String get master => 'Master';

  @override
  String get stop => 'Stop';

  @override
  String get play => 'Odtwórz';

  @override
  String get countingIn => 'Odliczanie…';

  @override
  String get recording => 'Nagrywanie…';

  @override
  String get record => 'Nagrywaj';

  @override
  String get stopRecording => 'Zatrzymaj nagrywanie';

  @override
  String micGainLabel(int db) {
    return 'Wzmocnienie mikrofonu $db dB';
  }

  @override
  String micGainTitle(int db) {
    return 'Wzmocnienie mikrofonu: +$db dB';
  }

  @override
  String get micGainHint =>
      'Zagraj najgłośniej jak będziesz grać: pasek powinien dochodzić do żółtego, ale nie do czerwonego.';

  @override
  String get audioSettings => 'Ustawienia audio';

  @override
  String get monitoringTitle => 'Odsłuch na żywo';

  @override
  String get monitoringHint =>
      'Słyszysz swój instrument w słuchawkach podczas nagrywania. Tylko ze słuchawkami: na głośniku byłoby sprzężenie.';

  @override
  String get monitoringBlocked => 'Podłącz słuchawki, żeby się słyszeć.';

  @override
  String get monitoringBluetooth =>
      'Słuchawki Bluetooth dodają wyraźne opóźnienie; do odsłuchu najlepsze są przewodowe.';

  @override
  String get monitorVolume => 'Głośność';

  @override
  String get monitorReverb => 'Pogłos';

  @override
  String get monitoringOn => 'Włącz odsłuch';

  @override
  String get monitoringOff => 'Wyłącz odsłuch';

  @override
  String get calibrationTitle => 'Kalibracja opóźnienia';

  @override
  String get calibrationHint =>
      'Sprawia, że nowe ścieżki trafiają idealnie w czas. Skalibruj raz dla każdego wyjścia, którego używasz.';

  @override
  String currentOutput(String name) {
    return 'Wyjście: $name';
  }

  @override
  String get notCalibrated => 'Jeszcze nie skalibrowane';

  @override
  String calibratedOffset(String ms) {
    return 'Korekta: $ms ms';
  }

  @override
  String get calibrate => 'Kalibruj';

  @override
  String get calibrating => 'Nasłuchuję kliknięć…';

  @override
  String get resetCalibration => 'Resetuj';

  @override
  String get calibrationHowTo =>
      'Zachowaj ciszę przez 4 sekundy. Głośnik: zostaw telefon na stole i podgłośnij. Słuchawki: przyłóż słuchawkę do mikrofonu telefonu (dolna krawędź).';

  @override
  String get start => 'Start';

  @override
  String calibrationDone(String ms) {
    return 'Skalibrowane: opóźnienie $ms ms.';
  }

  @override
  String get calibrationFailed =>
      'Nie słychać kliknięć. Podgłośnij i spróbuj ponownie.';
}
