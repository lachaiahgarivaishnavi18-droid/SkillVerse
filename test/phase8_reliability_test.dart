import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/feedback_report.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../tool/validate_curriculum.dart' show validateCurriculum;

void main() {
  const buildChannel = MethodChannel('skillverse/build');
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_accounts':
          '[{"fullName":"Tester","email":"first@example.invalid","passwordHash":"test-fixture"},'
          '{"fullName":"Second","email":"second@example.invalid","passwordHash":"test-fixture"}]',
      'auth_current_email': 'first@example.invalid',
      'auth_session_active': true,
    }),
  );

  test('the bundled curriculum is structurally valid', () {
    final result = validateCurriculum();
    expect(result.errors, isEmpty, reason: result.errors.join('\n'));
  });

  test(
    'diagnostics require consent, survive reopening, and clear on withdrawal',
    () async {
      final store = await AppStore.create();
      await store.recordDiagnostic(DiagnosticSource.framework);
      expect(store.diagnosticsEnabled, isFalse);
      expect(store.diagnosticCounts, isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getKeys().where((key) => key.contains('diagnostics')),
        isEmpty,
      );
      await store.setDiagnosticsEnabled(true);
      await store.recordDiagnostic(DiagnosticSource.framework);
      await store.recordDiagnostic(DiagnosticSource.dart);
      final reopened = await AppStore.create();
      expect(reopened.diagnosticCounts, {
        DiagnosticSource.framework: 1,
        DiagnosticSource.dart: 1,
      });
      final report = buildFeedbackReport(
        kind: FeedbackKind.diagnostics,
        build: const AppBuild('1.8.0', '83'),
        description: '',
        diagnostics: reopened.diagnosticCounts,
      );
      expect(report, contains('Flutter framework errors: 1'));
      expect(report, contains('Unhandled Dart errors: 1'));
      expect(report, isNot(contains('example.invalid')));
      await reopened.setDiagnosticsEnabled(false);
      await reopened.recordDiagnostic(DiagnosticSource.dart);
      expect(reopened.diagnosticCounts, isEmpty);
      expect(
        preferences.getKeys().where((key) => key.contains('diagnostics_count')),
        isEmpty,
      );
      await reopened.setDiagnosticsEnabled(true);
      expect(
        reopened.diagnosticCounts.values.every((value) => value == 0),
        isTrue,
      );
      await reopened.logout();
      expect(reopened.diagnosticsEnabled, isFalse);
      await reopened.recordDiagnostic(DiagnosticSource.dart);
      await preferences.setString(
        'auth_current_email',
        'second@example.invalid',
      );
      await preferences.setBool('auth_session_active', true);
      expect((await AppStore.create()).diagnosticsEnabled, isFalse);
    },
  );

  testWidgets(
    'a content report identifies its build and content before explicit copy',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        buildChannel,
        (_) async => {'version': '1.8.0', 'build': '83'},
      );
      String? copied;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = call.arguments['text'] as String;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(buildChannel, null);
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      final store = await AppStore.create();
      final lesson = courses.first.allLessons.first;
      await tester.pumpWidget(
        MaterialApp(
          home: LessonPage(lesson: lesson, store: store),
        ),
      );
      await tester.tap(find.byTooltip('Report a content problem'));
      await tester.pumpAndSettle();
      expect(find.text('Course or question content'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField),
        'The expected output skips the first row.',
      );
      await tester.pump();
      final review = find.text('Review report');
      await tester.ensureVisible(review);
      await tester.tap(review);
      await tester.pumpAndSettle();
      expect(copied, isNull);
      final payload = tester
          .widget<SelectableText>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(SelectableText),
            ),
          )
          .data!;
      expect(payload, contains('App version: 1.8.0'));
      expect(payload, contains('Build: 83'));
      expect(payload, contains('Content ID: ${lesson.id}'));
      expect(payload, contains('The expected output skips the first row.'));
      await tester.tap(find.text('Copy report'));
      await tester.pumpAndSettle();
      expect(copied, payload);
      final bug = buildFeedbackReport(
        kind: FeedbackKind.appBug,
        build: const AppBuild('1.8.0', '83'),
        description: 'Back closes the wrong page.',
      );
      expect(bug, contains('Type: App bug'));
      expect(bug, isNot(contains('Content ID')));
    },
  );

  testWidgets(
    'only the first completed lesson offers feedback across reopening',
    (tester) async {
      var store = await AppStore.create();
      final lessons = courses.first.allLessons;
      await tester.pumpWidget(
        MaterialApp(
          home: LessonPage(lesson: lessons[0], store: store),
        ),
      );
      await tester.tap(find.text('Mark lesson complete'));
      await tester.pumpAndSettle();
      expect(find.text('Give feedback'), findsOneWidget);
      expect(store.completedLessons, contains(lessons[0].id));
      await tester.pumpWidget(const SizedBox.shrink());
      store = await AppStore.create();
      expect(
        await store.claimFirstLessonFeedback(
          store.currentUserId!,
          lessons[0].id,
        ),
        isFalse,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LessonPage(lesson: lessons[1], store: store),
        ),
      );
      await tester.tap(find.text('Mark lesson complete'));
      await tester.pumpAndSettle();
      expect(find.text('Lesson marked complete.'), findsOneWidget);
      expect(find.text('Give feedback'), findsNothing);
    },
  );

  testWidgets(
    'focus loss checkpoints lesson reading and an immediate interview edit',
    (tester) async {
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final store = await AppStore.create();
      final lesson = courses.first.allLessons.first;
      await tester.pumpWidget(
        MaterialApp(
          home: LessonPage(lesson: lesson, store: store),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .singleWhere((view) => view.scrollDirection == Axis.vertical)
          .controller!;
      final expected = scroll.position.maxScrollExtent / 2;
      expect(expected, greaterThan(0));
      scroll.jumpTo(expected);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        (await AppStore.create()).lessonReadingOffset(lesson.id),
        expected,
      );
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());

      final question = interviewQuestions.first;
      const track = 'phase8-interruption';
      Widget screen(AppStore current) => MaterialApp(
        home: MockInterviewPage(
          store: current,
          category: question.category,
          mode: question.difficulty,
          track: track,
          questions: [question],
          timed: false,
          resume: current.interviewDraft(
            question.category,
            question.difficulty,
            track,
            timed: false,
          ),
        ),
      );
      await tester.pumpWidget(screen(store));
      await tester.enterText(
        find.byType(TextField),
        'A draft typed just before the call',
      );
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final reopened = await AppStore.create();
      final draft = reopened.interviewDraft(
        question.category,
        question.difficulty,
        track,
        timed: false,
      );
      expect(draft?.answers[question.id], 'A draft typed just before the call');
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(screen(reopened));
      expect(find.text('A draft typed just before the call'), findsOneWidget);
    },
  );

  testWidgets(
    'backgrounding and reopening an active exam keeps its answers and deadline',
    (tester) async {
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final store = await AppStore.create();
      final questions = quizQuestions
          .where((question) => question.subject == 'SQL')
          .take(2)
          .toList();
      Widget screen(AppStore current) => MaterialApp(
        home: MockTestPage(
          subject: 'SQL',
          questions: questions,
          store: current,
          mode: TestMode.exam,
          draft: current.examDraft('SQL', null),
        ),
      );
      await tester.pumpWidget(screen(store));
      await tester.pump();
      final initial = store.examDraft('SQL', null)!;
      final answer = find.text(questions.first.options.first);
      await tester.ensureVisible(answer);
      await tester.tap(answer);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      final reopened = await AppStore.create();
      final restored = reopened.examDraft('SQL', null)!;
      expect(restored.deadline, initial.deadline);
      expect(restored.answers[questions.first.id], 0);
      expect(reopened.attempts, isEmpty);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(screen(reopened));
      await tester.pump();
      expect(find.textContaining('Question 1 of 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
