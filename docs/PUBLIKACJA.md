# Publikacja NagrajTo w App Store

Nazwa: **NagrajTo** · bundle ID: `com.icdevgpasa.nagrajto` · wersja: `pubspec.yaml` → `version: 1.0.0+1`
(przed `+` wersja w sklepie; numer buildu fastlane ustawia sam na „ostatni w TestFlight + 1”).
Aplikacja jest tylko na iPhone'a (na iPadzie działa w trybie iPhone'a), więc wystarczą zrzuty 6,9".

Co jest w repo:

| Co | Gdzie |
|---|---|
| Teksty sklepu PL + EN (nazwa, podtytuł, opis, słowa kluczowe, tekst promocyjny, co nowego, URL-e) | `fastlane/metadata/<pl\|en-US>/` |
| Notatki dla recenzenta Apple | `fastlane/metadata/review_information/notes.txt` |
| Zrzuty ekranu 1320 × 2868, PL + EN | `fastlane/screenshots/<pl\|en-US>/` |
| Generator zrzutów (prawdziwe UI z danymi demo) | `screenshots/app_screens_test.dart` + `tool/frame_screenshots.py` |
| Build + upload | `fastlane/Fastfile` |
| Polityka prywatności | `docs/prywatnosc.md` (URL już w metadanych) |
| Ikona, opis użycia mikrofonu (PL/EN), privacy manifest, „brak szyfrowania” | `ios/Runner/` |

## 1. Jednorazowo: konto i narzędzia (Mac)

1. **Apple Developer Program**: https://developer.apple.com/programs/enroll/ (99 USD/rok, aktywacja do 48 h).
2. Xcode → *Settings → Accounts* → dodaj Apple ID.
3. `open ios/Runner.xcworkspace` → target **Runner** → *Signing & Capabilities* →
   zaznacz *Automatically manage signing* i wybierz swój **Team**. Zamknij Xcode.
4. fastlane: `brew install fastlane` (albo `bundle install` w katalogu repo).
5. Pillow do zrzutów (tylko gdy chcesz je generować od nowa): `pip3 install pillow`.

## 2. Jednorazowo: aplikacja w App Store Connect

1. https://appstoreconnect.apple.com → *Apps → + → New App*:
   iOS, nazwa **NagrajTo**, język główny **Polish**, bundle ID `com.icdevgpasa.nagrajto`
   (jeśli go nie ma na liście: https://developer.apple.com/account/resources/identifiers → +), SKU `nagrajto-ios`.
   Jeśli nazwa jest zajęta, zmień ją w `fastlane/metadata/*/name.txt` (np. „NagrajTo – Multitrack”).
2. **Klucz API** (żeby fastlane nie pytał o hasło i kody 2FA):
   *Users and Access → Integrations → App Store Connect API → +*, rola **App Manager**.
   Pobierz plik `AuthKey_XXXX.p8` (da się tylko raz) i włóż go do `fastlane/`.
   Skopiuj `fastlane/api_key.example.json` → `fastlane/api_key.json` i wpisz Key ID, Issuer ID i nazwę pliku.
   Oba pliki są w `.gitignore`, nie trafią na GitHuba.
3. W App Store Connect, w aplikacji, ustaw ręcznie (fastlane tego nie robi):
   - **App Privacy** → *Get Started* → „No, we do not collect data from this app” → *Publish*.
   - **Age Rating**: odpowiedz „nie” na wszystko → 4+.
   - **Pricing and Availability**: Free, wszystkie kraje (albo wybrane).
   - **App Review Information**: Twoje imię, nazwisko, telefon i e-mail kontaktowy
     (notatki dla recenzenta wgra fastlane).

## 3. Testy na iPhonie przed wysyłką

- [ ] Pierwsze uruchomienie pyta o mikrofon; po odmowie widać komunikat.
- [ ] Nagranie 3–4 ścieżek z metronomem i odliczaniem; ścieżki są równo w czasie
      (jeśli nie: Ustawienia audio → Kalibruj, osobno dla głośnika i każdych słuchawek).
- [ ] Odsłuch na żywo w słuchawkach przewodowych; na głośniku odsłuch się wycisza.
- [ ] Nagrywanie przez słuchawki przewodowe, AirPods i (jeśli masz) interfejs audio USB.
- [ ] Telefon dzwoni / alarm w trakcie nagrywania: aplikacja się nie wiesza, nagranie zostaje.
- [ ] Solo, mute, panorama, master słychać w odtwarzaniu i w eksporcie.
- [ ] Edycja ścieżki: przycięcie, fade, przesunięcie; „Przywróć oryginał” cofa wszystko.
- [ ] Eksport M4A, WAV i pojedynczych ścieżek; zapis do Plików i AirDrop.
- [ ] Długie nagranie (10+ minut): fala się rysuje, eksport kończy się poprawnie.
- [ ] Lista utworów: nowy, zmiana nazwy, usuwanie. Telefon po angielsku: wszystko po angielsku.

## 4. Wysyłka (z katalogu repo)

```sh
git pull
fastlane ios beta        # testy, build .ipa, upload do TestFlight (~10 min + ~20 min przetwarzania u Apple)
```

Sprawdź build w aplikacji **TestFlight** na swoim iPhonie. Gdy jest dobrze:

```sh
fastlane ios metadata    # wgrywa opisy PL/EN, notatki dla recenzenta i zrzuty ekranu
```

Potem w App Store Connect → wersja 1.0 → sekcja **Build** → wybierz build z TestFlight →
**Add for Review** → **Submit**. Recenzja trwa zwykle 1–2 dni. Po akceptacji kliknij *Release*
(ustawione jest ręczne wydanie).

Bez fastlane: `flutter build ipa --release`, potem plik z `build/ios/ipa/` przez aplikację
**Transporter**, a teksty i zrzuty wklejasz ręcznie z `fastlane/metadata` i `fastlane/screenshots`.

Kolejne wersje: podbij `version:` w `pubspec.yaml` (np. `1.0.1+1`), wpisz zmiany w
`fastlane/metadata/*/release_notes.txt`, potem `fastlane ios release` i *Submit* w App Store Connect.

## 5. Zrzuty ekranu

Gotowe są w `fastlane/screenshots/`. Żeby je odświeżyć po zmianach w UI:

```sh
fastlane ios screenshots
```

Renderuje prawdziwe ekrany aplikacji (studio, nagrywanie, eksport, lista utworów) z danymi demo,
w rozdzielczości iPhone'a 6,9", i dodaje podpisy. Podpisy zmienisz w `tool/frame_screenshots.py`,
dane demo w `screenshots/app_screens_test.dart`.

## 6. Najczęstsze powody odrzucenia (sprawdzone)

- Opis użycia mikrofonu: jest (PL i EN). ✓
- Polityka prywatności: URL w metadanych, plik w repo musi być publiczny (repo jest publiczne). ✓
- Szyfrowanie: `ITSAppUsesNonExemptEncryption = NO`, więc bez pytań o eksport. ✓
- Privacy manifest (`PrivacyInfo.xcprivacy`) w aplikacji i w pluginie audio. ✓
- Recenzent musi umieć coś nagrać bez instrukcji: notatki opisują to krok po kroku. ✓

## 7. Ikona

Generowana skryptem `tool/make_icon.py` (Python + Pillow) do `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
