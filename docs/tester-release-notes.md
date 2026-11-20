# Skillverse beta tester release notes

## Phase 10 private beta candidate

- **Skillverse 1.0.0 (build 2)** uses the existing Android package ID, course data, navigation, and logo artwork. About Skillverse shows the installed version, build, and account mode.
- The connected candidate uses the configured Supabase project's public Android client settings. The package is for authorized beta testers. See the [README](../README.md) for installation, signing, and offline build instructions.
- Live Android installation and upgrade, TalkBack, incoming calls, reminder delivery, PDF open/share, and authenticated cross-device ranking require device sign-off before wider rollout.

## Verified for build 2

- Flutter analysis reported no issues and all 80 automated tests passed. Curriculum validation found zero invalid records or references.
- The release APK built successfully. Its version, package ID, launcher label, launcher resources, and splash resources were checked in the package. Its signing certificate matches the prior APK.
- The configured Supabase project reported email signup enabled. It rejected invalid sign-in credentials and denied an unauthenticated leaderboard request. Signed-in cloud testing still requires an authorized test account.
- The workstation emulator stayed offline during boot and was stopped when host storage became critically low. Android installation and launch still need a device check.
- APK SHA-256: `9A5375D4ADAF82AF370F9817FD85315BFA0F4DCED1247D825D3E8B5D1E270020`

## Android beta smoke test

1. Install or update the APK and verify the launcher label and icon, splash, login and signup branding, Home, all five bottom tabs, and the build shown in About.
2. With an authorized test account, sign up or sign in, sign out, and sign in again. If a second test account is available, check that its local learning history and saved interview answers are separate.
3. Search for SQL or Python, change level filters, save a course in My Learning, open a module and lesson, reveal an exercise hint, and mark the lesson complete. Reopen the app and check completion and the reading position.
4. Finish a practice session and a quiz. Start a timed exam, use Android Back to save or stay, then reopen it and check the deadline and score.
5. Open a role-based interview set. Compare a written answer with the reference and check that a bookmark reaches the Study Queue.
6. Check your weekly goal, enable a reminder, export progress, and save a project repository link. Open an earned certificate and use Android's PDF save, open, and share actions.
7. While signed in, turn on airplane mode. Try a bundled lesson, an interview, and the leaderboard. Restore connectivity and use two authorized accounts to confirm real rankings. Try Android Back, maximum text size, and TalkBack on the test devices.

## Phase 8

- Content and app bug reports are separate and previewable. A contextual report includes an exact content ID. The installed app version and build are included in each report.
- The first completed lesson offers one optional feedback action per local account. A permanent observation form is available under **Profile → Feedback and privacy**.
- Optional diagnostics count Flutter and unhandled Dart errors locally only after consent. Testers may review and copy the counts. Disable the feature to clear them.
- Lesson, exam, and mock interview checkpoints are exercised on lifecycle interruption. Timed exams use the stored deadline on return.
- A curriculum validation command checks IDs, required fields, answer indexes, explanations, and content references.

## Tester checklist

1. Start with a fresh or dedicated test account. Find and open a first lesson. Record which device and build you tested and, if you choose, note what helped you find, open, and complete the lesson. Skip reporting at any point. A coordinator collecting opt-in observations should record only the observations testers volunteer, count the responses received, and label the sample size. No participant identifiers are needed.
2. Complete that lesson, review the optional report, and close it without copying. Reopen the app and complete a second lesson. Check that the completion message does not offer it again.
3. Report a problem from a lesson or question. Check the content ID, version, build, and edited description on the preview. Compare it with an app bug report from Profile. Copy only a test report you intend to share. Leave email, passwords, and written answers out.
4. Verify diagnostics is off on a fresh account. Cancel its confirmation, then enable it and open the preview. Zero counts are valid if no errors occurred. Disable it and verify the counters are cleared. Use the automated diagnostics test for reproducible error-count coverage.
5. Open a long lesson, scroll, then interrupt it with an incoming call on a test phone or emulator. Answer or dismiss the call and return. Repeat while drafting a written interview answer and while a timed exam is underway. The written draft and selected exam answer should be recoverable. The exam should continue to use the original deadline.
6. Send the app to the background and force stop it via Android Settings or `adb shell am force-stop com.learningapp.learning_app`. Relaunch and sign into the same account if needed. Verify that durable completions, the prior lesson checkpoint, exam position and selections, and saved interview responses reopen. Repeat with an expired exam and check that opening it produces one saved result. Try immediate force stops as a separate timing edge case.
7. Sign out and switch to a different account. Check that drafts, histories, and diagnostic consent are separate. Return to the original account and confirm its saved state is still present. Clear app storage only on a disposable device or profile and verify that local data is erased.
8. On a cloud-configured build, use two registered test accounts. Complete a quiz and an interview, first offline and then online. Open the same leaderboard on both devices and check actual rank, deduplicated scoring, and UTC time tabs. Ask the project administrator to verify deletion with a disposable cloud account.

## Beta release criteria

- `flutter analyze`, `flutter test`, and `dart run tool/validate_curriculum.dart` pass on the release commit. The release APK builds and upgrades over the previous supported test build.
- Sign-in, course discovery, lesson completion, assessments, exams, mock interviews, project edits, and PDF save/open/share pass. Offline and cloud behavior are separately exercised.
- The interruption checklist passes on at least two Android device configurations, including a physical phone. Cover an incoming call, backgrounding, force stop, reopening, low-storage behavior, and expired exams. Any reproducible loss of durable progress or duplicate results blocks release.
- Cross-account privacy, sign-out, local deletion, consent withdrawal, and cloud account deletion are verified. Review actual report payloads to confirm that they contain only documented fields.
- Live TalkBack, large system text, keyboard and visible focus, contrast and non-color status cues, reduced motion, touch targets, and Android Back are checked on-device. A blocked core action or an inaccessible critical workflow blocks release.
- No unresolved release-blocking defects remain. Record test device, Android version, app version/build, and results. The release owner approves signing and distribution before shipping.

## Known limitations

- An immediate operating-system kill or power loss can interrupt a write. An edit made after the last successful checkpoint may need to be entered again. Foreground and background transitions checkpoint local work when Android gives the app time.
- Untimed standalone practice and module quiz selections, along with unsaved form fields, are kept in memory until submitted. Keep these screens open for temporary interruptions. A force stop can discard that unfinished input.
- Diagnostics are counts for recoverable or observed Flutter/Dart errors. They are not a native crash log, delivery service, or monitoring dashboard. Reports are handed off manually.
- Live rankings require configured Supabase. Account deletion requires an administrator for the cloud account, plus local storage cleanup for copies on the device. Local accounts and learning history have no cross-device restore.
- The private candidate uses the existing debug signer when no release keystore is supplied. The release owner must configure and verify a controlled signer before public distribution.
- A live incoming-call test, on-device TalkBack, and the full Android device matrix must still be signed off before beta distribution.
