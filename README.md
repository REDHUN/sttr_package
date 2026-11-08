# VoiceNote

VoiceNote is a Flutter Android/iOS voice-notes application that records a WAV
file and streams a live speech-to-text transcript through one microphone path.
It uses `stt_record: ^0.0.8`, Provider, SQLite metadata storage, and app-private
document storage for finalized audio.

## Requirements

- Flutter stable 3.44.8 or a compatible stable Flutter release.
- Dart SDK 3.12.2 or newer within the `pubspec.yaml` constraint.
- Android API 24+; Android 13+ (API 33+) is the most reliable capture mode for
  `stt_record` 0.0.8.
- iOS 13.0+ and a real device for reliable speech-recognition testing.
- Java 17 and the Android toolchain supplied by the Flutter project template.
- Xcode/CocoaPods on macOS for iOS builds. iOS builds cannot be produced on
  this Windows development environment.

## Run

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run
```

For an Android debug APK:

```bash
flutter build apk --debug
```

## Architecture

The project follows a feature-first MVVM structure:

```text
lib/
  app/                         # providers, app theme, navigation shell
  core/
    errors/                    # explicit application exceptions
    storage/                   # SQLite, WAV validation/copy, draft recovery
    theme/                     # Material 3 light/dark themes
    utils/                     # duration, date, and file-size formatters
  features/
    recording/
      data/                    # SpeechCaptureService + stt_record adapter
      domain/                  # immutable recording model/state machine
      presentation/            # recording page and ChangeNotifier view model
    recordings/
      data/                    # SQLite recording repository
      domain/                  # saved recording model
      presentation/            # searchable history and detail editor
    playback/
      data/                    # share integration
      presentation/            # just_audio playback ChangeNotifier
    settings/
      presentation/            # local theme/language preferences
  shared/widgets/              # reusable UI cards, meter, transcript panel
```

`SpeechCaptureService` is the replaceable boundary around `stt_record`. The
recording view model owns the recording state machine, command serialization,
event subscriptions, active-time clock, bounded level samples, transcript draft
checkpoints, and final save coordination. Widgets do not own microphone,
persistence, or playback resources.

### State flow

```text
idle
  -> requestingPermission -> starting -> recording
  -> paused <-> recording
  -> stopping -> saving -> completed
  -> error
```

Duplicate commands are ignored while an asynchronous command is running.
Transcript events replace the current snapshot because `stt_record` emits the
full accumulated transcript rather than an incremental segment. Events are
tagged to the current session so late events from an old session are ignored.

## Storage and recovery

- `sqflite` stores searchable recording metadata and transcript text in
  `voicenote.sqlite`.
- Finalized WAV files are copied asynchronously into the app-private documents
  directory under `VoiceNote/recordings/`.
- The WAV header and non-empty `data` payload are validated before the database
  row is committed.
- A small JSON transcript draft is checkpointed about every five seconds and
  after failures. It can recover useful text after an interrupted save, but the
  app does not promise recovery of an unfinished native audio file after process
  termination.
- WAV bytes are never loaded into Dart memory as a whole; validation reads only
  the fixed header and file operations use asynchronous file APIs.

## Platform setup

### Android

`android/app/src/main/AndroidManifest.xml` declares:

- `RECORD_AUDIO`
- `POST_NOTIFICATIONS`

`stt_record` contributes its own foreground-service, microphone foreground
service type, speech-recognizer query, provider, and service declarations via
manifest merging. The app does not duplicate those service declarations.
The plugin starts its minimal foreground service only when the app asks for the
system notification; VoiceNote starts recording from the foreground and
enables that notification on Android.

No broad storage permission is requested. Audio is stored in app-private
documents storage. On Android 13+, the plugin may request notification access
alongside microphone access; denying notifications should not be treated as
granting microphone access.

The plugin documents these Android limitations:

- API 33+ is the most reliable mode because it supports recognizer audio
  injection.
- API 31–32 injection is best effort and can be ignored by a speech engine.
- API 30 and earlier may produce incomplete or empty WAV files because the
  fallback buffer callback is not guaranteed by every device/service.

### iOS

`ios/Podfile` sets iOS 13.0. `ios/Runner/Info.plist` includes:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

Speech recognition and microphone permission are requested only from the
user-triggered recording flow. Test on a real iPhone/iPad because simulator
audio and recognizer availability are not representative.

## Tests

The test suite covers:

- valid and invalid recording-state transitions;
- serialized rapid starts;
- transcript snapshot replacement without duplicate text;
- stale events after a discarded session;
- pause/resume duration accounting excluding paused time;
- valid WAV persistence, empty audio, and failed file copies;
- transcript draft preservation after an audio save failure;
- provider/view-model subscription cleanup;
- a basic Material 3 VoiceNote workspace smoke test.

Run them with:

```bash
flutter test
```

## Real-device checklist

- Deny microphone and speech-recognition permission, then grant it from system
  settings and retry.
- Try English (India) when reported, Malayalam when reported, and a locale the
  platform does not support.
- Start, pause, resume, stop, discard, and repeat rapidly.
- Confirm transcript snapshots do not duplicate words.
- Verify the saved WAV plays, seeks, exports, and survives an app restart.
- Exercise a phone call, Bluetooth route change, audio focus interruption, and
  background/foreground transition.
- Test Android API 30 or earlier specifically for empty/incomplete audio.
- Test a long session against the platform recognizer’s practical limits.
- Test insufficient storage or a missing temporary file and confirm the draft
  transcript remains visible.
- Test deleting one recording and clearing the full library.

## Verification status for this workspace

Verified locally on Windows:

- `flutter pub get` passed with `stt_record 0.0.8` resolved.
- `dart format lib test` passed.
- `flutter analyze` passed with no issues.
- `flutter test` passed.
- Flutter stable 3.44.8 / Dart 3.12.2 is installed.

Real-device-only or unavailable here:

- microphone permissions, platform recognizer availability, live transcripts,
  actual amplitude values, interruptions, Android audio injection behavior,
  background foreground-service behavior, iOS speech recognition, and audio
  export UI;
- iOS build/signing, because this workspace is being developed on Windows and
  Xcode is not available.

VoiceNote intentionally does not promise offline recognition, unlimited
transcription, automatic language detection, or continuous background
transcription. Those behaviors are controlled by the platform recognition
provider and the limitations of `stt_record 0.0.8`.
