# Command Play

Offline, fully voice-controlled media player for Windows and Android (Flutter + media_kit/libmpv + Vosk + SQLite FTS5).
Research and product spec: [`docs/VOICE_MEDIA_PLAYER.md`](docs/VOICE_MEDIA_PLAYER.md).

**Status:** v0.1.0. Release builds for Windows and Android (arm64/arm32) compile and run. Windows has been tested on a real library.

## Set up on a new machine
1. Install the Flutter SDK (3.50+ stable), plus:
   - **Windows builds:** Visual Studio Build Tools with "Desktop development with C++", and Windows **Developer Mode** turned on.
   - **Android builds:** the Android SDK and JDK 17, then `flutter doctor --android-licenses`.
2. Download the offline speech model (about 40 MB, not stored in git) into `assets/models/`.
   See [`assets/models/README.txt`](assets/models/README.txt) for the link.
3. Fetch packages and run the tests:
   ```bash
   flutter pub get
   flutter test
   ```
4. Run or build:
   ```bash
   flutter run -d windows
   flutter build windows --release
   flutter build apk --release --split-per-abi --target-platform android-arm64,android-arm
   ```

## Layout
```
lib/
  core/       intent.dart, action_specs.dart (every feature + example phrases),
              action_registry.dart, wiring.dart (specs -> real behaviour)
  voice/      nlu.dart (offline rule-based parser), vosk_voice_input.dart (mic -> Vosk),
              voice_controller.dart (text -> NLU -> action -> TTS, noise/echo filtering)
  playback/   playback_service.dart (media_kit wrapper: queue, resume, errors)
  library/    library_service.dart (scan, SQLite FTS5 + fuzzy search, clean titles),
              thumbnail_service.dart (offline thumbnails + durations)
  ui/         theme.dart (black / light purple / white), logo.dart, widgets.dart,
              home_page.dart (library), player_page.dart (immersive player)
test/         parser, voice-parity, title-cleaning, real-speech (Vosk) and logo-render tests
third_party/  vosk_flutter, patched for Android Gradle Plugin 8+ (namespace, SDK levels)
docs/         research and spec
```

## The one rule
Every capability needs an `ActionSpec` with at least 3 example phrases, plus a handler in `wiring.dart`.
Buttons, keyboard and voice all go through the same registry, and `test/nlu_test.dart` fails if any example phrase doesn't parse to its action.

## Useful commands
- Regenerate the icon PNGs from the logo painter: `RENDER_LOGO=1 flutter test test/render_logo_test.dart`, then `dart run flutter_launcher_icons`.
- Real-speech test: set `VOSK_MODEL_DIR` (an unzipped model) and `VOSK_WAV_DIR` (16 kHz WAVs), then `flutter test test/vosk_speech_test.dart`.

## Android build notes
- `android/build.gradle.kts` makes every plugin compile against Android SDK 36 or newer, because some older plugins pin outdated SDK versions.
- Release APKs are signed with Flutter's debug key. Add your own keystore before publishing to Google Play.

## Next steps
1. Wake word ("Hey Play") and continuous listening mode.
2. Lower the media volume while the mic is listening.
3. Subtitle, audio-track, chapter, A-B loop and equaliser voice actions (add specs first).
4. Tag reading (artist and album) for music, plus playlists and bookmarks.
5. Lock-screen and media-key controls (audio_service).
6. Move from `package:flutter/material.dart` to `material_ui` (deprecated in Flutter 3.47+).
