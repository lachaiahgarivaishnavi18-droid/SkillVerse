# Skillverse

Skillverse is an offline-first Flutter learning app for Android. It includes a course catalog, structured lessons and practice files, topic quizzes, resumable timed exams, interview practice, learning goals, projects, and course completion PDFs.

## Install the private Android beta

The Phase 10 candidate is Skillverse **1.0.0, build 2** with Android package ID `com.learningapp.learning_app`. The APK requires Android API 24 or later, targets API 36, and includes ARM64, ARMv7, and x86-64 builds.

1. Copy the built `app-release.apk` to your Android phone. Open it from Files and allow installs from that source if Android asks.
2. Choose **Update** if Android recognizes the earlier APK. If Android reports a signing conflict, keep the existing install and use a spare test device or obtain an APK signed with the matching key. Uninstalling the existing app or clearing its storage erases local learning data.
3. Launch **Skillverse**, open **Profile → Settings → About Skillverse**, and check the version and build. Follow the [beta tester checklist](docs/tester-release-notes.md).

## What works offline

- Use an existing local or cached account session to browse bundled courses, read lessons, practice, take quizzes, and draft interviews.
- Learning progress, reading position, bookmarked questions, attempts, written responses, projects, goals, and certificate records stay on the current device.
- On builds with Supabase configured, signing in, creating an account, updating the cloud profile, and fetching live rankings require a connection. Scoring submissions can queue offline and sync when another result is submitted or the leaderboard opens.
- Android can generate certificate PDFs locally. The destination or app you choose to share with may require a connection.

## Feedback and data

Use **Profile → Feedback and privacy** for app bugs, first-lesson observations, and optional diagnostics. The flag button on content opens a separate report with the relevant course, lesson, quiz question, or interview question ID. Reports also include the installed version and build number. Review the report, then copy it only if you want to send it to your tester coordinator or support contact.

After the first saved lesson completion, the completion message offers a one-time, optional feedback action. There is no background event collection, automatic report delivery, or feedback server. Diagnostics are off by default and require explicit confirmation. While enabled they keep account-scoped counts of Flutter framework and unhandled Dart errors on the device. They contain no stack traces, exception messages, routing history, credentials, or written learning content. Turning diagnostics off clears the counts. They cannot measure native crashes, operating-system kills, or errors before Flutter starts.

Cloud builds sync Supabase account details and profile names. For scoring, the app submits question IDs with selected multiple-choice indexes or reviewed written-interview completion indicators. The full result history and written text remain local. The server calculates points and ranks. Rankings show names and scores without email addresses.

Signing out ends the local session. Account-scoped drafts, history, and pending scoring submissions remain for the next sign-in on the same device. Clearing app storage in Android Settings removes all local Skillverse accounts and progress on that device. Android backup rules exclude Skillverse shared preferences. Exported documents, copied reports, and information already shared with a recipient have separate lifetimes. A Skillverse administrator must delete a Supabase account to remove its linked profile and leaderboard data. Cloud deletion does not remove copies already stored on learners' devices.

## Setup and build

Use an Android-capable Flutter SDK compatible with the Dart constraint in `pubspec.yaml`, Android SDK platform tools, and the JDK used by the Android Gradle configuration. Check the toolchain with `flutter doctor -v` and use the repository's locked package versions.

```sh
flutter pub get
flutter analyze
flutter test
dart run tool/validate_curriculum.dart
flutter run
flutter build apk --release
```

The release APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The Android app requests internet access and uses notification and boot permissions for learning reminders. It asks for notification permission when you turn reminders on. Documents use Android's file picker.

### Android signing

If `android/key.properties` exists, Gradle uses the release keystore it points to. Provide `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` in that local file. Use an absolute keystore path or a path relative to `android/`. Keep the keystore and properties file outside source control and away from APK handoffs. When the file is absent, Gradle uses the existing debug signer for private APK testing. Configure a controlled release signer before any public distribution and verify upgrade compatibility before changing the signing identity.

### Supabase configuration

Use the existing project for a shared beta across devices.

1. Enable the Email provider. The configured project permits signup without verifying email ownership. If you enable email confirmation, configure SMTP and allow the redirect `com.learningapp.learningapp://auth/confirmed`.
2. Apply unapplied files in `supabase/migrations` in filename order. The scoring catalog migration is required for real assessment and quiz credit. After changing question IDs or answers, regenerate the catalog with `dart run tool/export_leaderboard_catalog.dart` and apply the SQL as a new migration.
3. Save an ignored local config file at `supabase/.temp/skillverse-app.json` with the keys `SUPABASE_URL` (the project's HTTPS URL) and `SUPABASE_PUBLISHABLE_KEY` (the project's `sb_publishable_` key). These are public client settings and are included in the connected APK. Keep privileged keys, database passwords, and personal access tokens out of this file and out of the app.

```sh
flutter build apk --release --dart-define-from-file=supabase/.temp/skillverse-app.json
```

To test local accounts without any backend, omit the define file and leave both settings unset. Live rankings then show an unavailable message. Supply both client settings for a connected build.

All devices participating in a shared leaderboard must use the same project. Local accounts and progress do not migrate into Supabase. Global is all-time, Weekly starts Monday at midnight UTC, and Monthly starts at midnight UTC on the first day. Deferred credits count when the server awards them. The same credited question and source earn points once.

See [tester release notes](docs/tester-release-notes.md) for verification instructions, beta exit criteria, and known limitations.
