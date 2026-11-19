# Multitrack Recorder

Aplikacja mobilna dla muzyków: nagrywanie wielu ścieżek (jedna na drugiej),
a potem eksport całego utworu albo pojedynczych ścieżek. Najpierw iOS, Android później.

## Stos

- **UI:** Flutter (`lib/`)
- **Audio:** natywny silnik w lokalnym pluginie `packages/multitrack_engine`
  - iOS: `AVAudioEngine` (`ios/multitrack_engine/Sources/multitrack_engine/AudioEngine.swift`)
  - Android: Oboe (później, za tym samym API w Dart)

## Plan

1. **Rdzeń nagrywania** – nagrywanie z odsłuchem poprzednich ścieżek, metronom z odliczaniem, kompensacja opóźnienia. ✅ (wersja 1)
2. **Mikser i eksport** – głośność/panorama/mute/solo, lista projektów, eksport miksu i pojedynczych ścieżek.
3. **Wygląd i efekty wizualne** – przebiegi fali na żywo, wizualizator spektrum, animacje.
4. **Testy na urządzeniach i publikacja** – App Store, potem Google Play.

## Uruchomienie (Mac z Xcode)

```sh
flutter pub get
open ios/Runner.xcworkspace   # ustaw swój Team w Signing & Capabilities
flutter run                   # na podłączonym iPhonie
```

Nagrywanie najlepiej testować na prawdziwym iPhonie ze słuchawkami
(symulator ma inne opóźnienia, a bez słuchawek mikrofon zbierze odsłuch).

## Testy

```sh
flutter test
```
