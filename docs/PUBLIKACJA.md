# Publikacja NagrajTo (iOS)

Nazwa: **NagrajTo** · identyfikator: `com.icdevgpasa.nagrajto` · wersja: `pubspec.yaml` → `version: 1.0.0+1`
(część przed `+` to wersja w sklepie, po `+` numer buildu; każdy upload musi mieć wyższy numer buildu).

## 1. Konto Apple

1. Apple Developer Program: https://developer.apple.com/programs/enroll/ (99 USD rocznie).
2. W Xcode: *Settings → Accounts* dodaj Apple ID.
3. `open ios/Runner.xcworkspace` → target **Runner** → *Signing & Capabilities* → wybierz swój **Team**.
   Identyfikator możesz tam zmienić, ale tylko przed pierwszą publikacją.

## 2. Testy na iPhonie (przed wysyłką)

Na prawdziwym urządzeniu, najlepiej ze słuchawkami i bez:

- [ ] Pierwsze uruchomienie pyta o mikrofon; po odmowie widać komunikat.
- [ ] Nagranie 3–4 ścieżek z metronomem i odliczaniem; ścieżki są równo w czasie
      (jeśli każda kolejna jest przesunięta, trzeba skalibrować opóźnienie: daj znać o ile).
- [ ] Nagrywanie przez słuchawki przewodowe, AirPods i (jeśli masz) interfejs audio USB.
- [ ] Telefon dzwoni / przychodzi alarm w trakcie nagrywania: aplikacja się nie wiesza.
- [ ] Solo, mute, panorama, master słychać w odtwarzaniu i w eksporcie.
- [ ] Eksport M4A, WAV i pojedynczych ścieżek; zapis do Plików i AirDrop.
- [ ] Długie nagranie (10+ minut): fala się rysuje, eksport kończy się poprawnie.
- [ ] Lista utworów: nowy, zmiana nazwy, usuwanie.
- [ ] Ikona i ekran startowy wyglądają dobrze; tryb „Ogranicz ruch” zatrzymuje animacje tła.

## 3. Build i wysyłka

```sh
flutter clean && flutter pub get
flutter build ipa --release
```

Plik `.ipa` ląduje w `build/ios/ipa/`. Wyślij go aplikacją **Transporter** (Mac App Store)
albo przez Xcode: *Window → Organizer → Distribute App*.

## 4. App Store Connect

1. https://appstoreconnect.apple.com → *Apps → +* → New App
   (platforma iOS, nazwa NagrajTo, język główny polski, bundle ID jak wyżej, SKU np. `nagrajto-ios`).
2. **TestFlight**: po przetworzeniu buildu (ok. 15–30 min) dodaj siebie i znajomych muzyków jako testerów
   wewnętrznych. Zewnętrzni testerzy wymagają krótkiej recenzji Apple.
3. **App Privacy**: „Data Not Collected” (aplikacja niczego nie wysyła; nagrania zostają na telefonie).
4. **Polityka prywatności (URL)** jest wymagana nawet bez zbierania danych. Gotowy tekst jest w
   [`docs/prywatnosc.md`](prywatnosc.md); można go opublikować np. przez GitHub Pages.
5. Kategoria: **Music**. Ocena wiekowa: 4+.
6. Zrzuty ekranu: wymagane dla 6,9" (1320 × 2868). Najprościej z symulatora iPhone 16 Pro Max:
   `flutter run` na symulatorze, potem ⌘S w symulatorze. Pokaż: listę utworów, studio z 3–4 ścieżkami
   podczas odtwarzania (fale + spektrum), nagrywanie (czerwona karta), okno eksportu.

## 5. Teksty do sklepu

**Podtytuł (max 30 znaków):** Wielościeżkowe studio

**Słowa kluczowe (max 100 znaków):**
`nagrywanie,ścieżki,multitrack,muzyka,gitara,looper,metronom,demo,próba,zespół,dyktafon,wokal`

**Opis (PL):**

> NagrajTo to wielościeżkowe studio w kieszeni. Nagraj gitarę, potem bas, wokal i drugi głos,
> słuchając w słuchawkach tego, co już nagrałeś. Każda ścieżka trafia równo w czas dzięki
> automatycznej kompensacji opóźnienia.
>
> • Nagrywanie kolejnych ścieżek z odsłuchem poprzednich
> • Metronom z odliczaniem i regulacją tempa
> • Mikser: głośność, panorama, solo i wyciszenie każdej ścieżki
> • Przebiegi fali na żywo, wizualizator spektrum i tło, które pulsuje w rytm muzyki
> • Eksport całego utworu (M4A lub WAV) albo każdej ścieżki osobno do dalszej pracy w DAW
> • Udostępnianie przez AirDrop, Pliki i komunikatory
>
> Nagrania zostają na Twoim telefonie. Bez kont, bez reklam, bez śledzenia.

**Description (EN):**

> NagrajTo is a multitrack studio in your pocket. Record guitar, then bass, vocals and harmonies
> while listening to everything you've already laid down. Automatic latency compensation keeps
> every take in time.
>
> • Overdub new tracks while hearing the previous ones
> • Metronome with count-in and adjustable tempo
> • Mixer: volume, pan, solo and mute per track
> • Live waveforms, a spectrum visualizer and a background that pulses with your music
> • Export the full song (M4A or WAV) or every track separately for your DAW
> • Share via AirDrop, Files and messaging apps
>
> Your recordings stay on your phone. No accounts, no ads, no tracking.

**Uwagi dla recenzenta (Review Notes):**

> The app records audio with the microphone. To test: tap "Nowy utwór", tap the red record button,
> play or sing for a few seconds, tap it again. Repeat to add more tracks. The share icon (top right)
> exports the song. No login is required.

## 6. Ikona

Ikona jest generowana skryptem `tool/make_icon.py` (Python + Pillow). Żeby ją zmienić,
popraw skrypt i wygeneruj rozmiary ponownie albo podmień `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
