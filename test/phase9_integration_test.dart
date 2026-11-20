import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/course_discovery.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _account =
    '[{"fullName":"QA Learner","email":"qa@example.invalid","passwordHash":"fixture"}]';

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_accounts': _account,
      'auth_current_email': 'qa@example.invalid',
      'auth_session_active': true,
    }),
  );

  testWidgets(
    'catalog, lesson exercise, practice, and My Learning agree after reopening',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = await AppStore.create();
      final course = LearningGoal.sql.course;
      final module = course.learningModules.first;
      final lesson = module.lessons.first;
      await tester.pumpWidget(MaterialApp(home: MainScreen(store: store)));
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), course.title);
      await tester.pumpAndSettle();
      final courseTile = find.widgetWithText(ListTile, course.title);
      expect(courseTile, findsOneWidget);
      await _tapVisible(
        tester,
        find.descendant(
          of: courseTile,
          matching: find.byTooltip('Save course'),
        ),
      );
      await _tapVisible(tester, courseTile);
      final moduleTile = find.widgetWithText(ExpansionTile, module.title);
      await _tapVisible(
        tester,
        find.descendant(
          of: moduleTile,
          matching: find.widgetWithText(ListTile, module.title),
        ),
      );
      await _tapVisible(
        tester,
        find.descendant(
          of: moduleTile,
          matching: find.widgetWithText(ListTile, lesson.title),
        ),
      );
      await _tapVisible(tester, find.text('Show hints'));
      expect(find.text('Hint 1'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('Mark lesson complete'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await _tapVisible(
        tester,
        find.text('Practice questions · ${module.questions.length}'),
      );
      for (var index = 0; index < module.questions.length; index++) {
        final question = module.questions[index];
        await _tapVisible(
          tester,
          find.widgetWithText(ListTile, question.options[question.answerIndex]),
        );
        if (index < module.questions.length - 1) {
          await _tapVisible(
            tester,
            find.widgetWithText(OutlinedButton, 'Next'),
          );
        }
      }
      await _tapVisible(tester, find.text('See results'));
      expect(store.attempts.single.percentage, 100);
      expect(store.attempts.single.mode, 'modulePractice');

      await tester.pumpWidget(const SizedBox.shrink());
      await (await SharedPreferences.getInstance()).reload();
      final reopened = await AppStore.create();
      expect(reopened.completedLessons, contains(lesson.id));
      expect(reopened.lessonReadingOffset(lesson.id), greaterThan(0));
      expect(reopened.savedCourseIds, contains(course.id));
      expect(reopened.attempts.single.id, store.attempts.single.id);

      await tester.pumpWidget(MaterialApp(home: MainScreen(store: reopened)));
      await tester.tap(find.text('Learn'));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.text('My Learning'));
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text(course.title), findsNWidgets(2));
      expect(
        find.text('Finish a course and pass its final assessment.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a module quiz cannot submit after its original account signs out',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = await AppStore.create();
      final module = LearningGoal.sql.course.learningModules.first;
      await tester.pumpWidget(
        MaterialApp(
          home: ModuleQuizPage(module: module, store: store),
        ),
      );
      for (var index = 0; index < module.moduleQuizQuestions.length; index++) {
        final question = module.moduleQuizQuestions[index];
        await _tapVisible(
          tester,
          find.widgetWithText(ListTile, question.options.last),
        );
        if (index < module.moduleQuizQuestions.length - 1) {
          await _tapVisible(
            tester,
            find.widgetWithText(OutlinedButton, 'Next'),
          );
        }
      }
      await store.logout();
      await _tapVisible(tester, find.text('Submit quiz'));
      expect(find.textContaining('Your account changed'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getKeys().where((key) => key.endsWith('.test_attempts')),
        isEmpty,
      );
    },
  );

  testWidgets(
    'Settings reloads the Android reminder after resume and exports the saved goal activity',
    (tester) async {
      const reminders = MethodChannel('skillverse/reminders');
      const documents = MethodChannel('skillverse/lesson_files');
      final messenger = tester.binding.defaultBinaryMessenger;
      var nativeEnabled = false;
      final calls = <String>[];
      String? exportedText;
      messenger.setMockMethodCallHandler(reminders, (call) async {
        calls.add(call.method);
        if (call.method == 'set') {
          expect(call.arguments, {'enabled': true, 'hour': 19, 'minute': 0});
          nativeEnabled = true;
        }
        return {'enabled': nativeEnabled, 'hour': 19, 'minute': 0};
      });
      messenger.setMockMethodCallHandler(documents, (call) async {
        expect(call.method, 'saveText');
        expect(call.arguments['filename'], startsWith('skillverse-learning-'));
        exportedText = utf8.decode(call.arguments['bytes'] as Uint8List);
        return 'content://test/progress';
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(reminders, null);
        messenger.setMockMethodCallHandler(documents, null);
      });

      final store = await AppStore.create();
      final lesson = LearningGoal.sql.course.allLessons.first;
      await store.markLessonComplete(lesson.id);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProfilePage(store: store)),
        ),
      );
      await tester.scrollUntilVisible(find.text('Settings'), 320);
      await _tapVisible(tester, find.text('Settings'));
      expect(calls, ['get']);

      await _tapVisible(tester, find.text('Set goal'));
      await tester.enterText(find.byType(TextFormField), '1');
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('1 of 1 activities this week'),
        findsOneWidget,
      );
      expect((await AppStore.create()).weeklyLearningGoal, 1);

      await _tapVisible(tester, find.text('Daily learning reminder'));
      final reminder = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(reminder).value, isTrue);
      nativeEnabled = false;
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, ['get', 'set', 'get']);
      expect(tester.widget<SwitchListTile>(reminder).value, isFalse);

      await _tapVisible(tester, find.text('Export progress and activity'));
      expect(exportedText, contains('Skillverse learning report'));
      expect(exportedText, contains('Activity history'));
      expect(exportedText, contains(lesson.title));
      expect(exportedText, isNot(contains('qa@example.invalid')));
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );

  testWidgets(
    'earned PDF export uses the Android channel and shares the saved URI',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const documents = MethodChannel('skillverse/certificates');
      final messenger = tester.binding.defaultBinaryMessenger;
      final calls = <String>[];
      final store = await AppStore.create();
      final course = courses.singleWhere((item) => item.id == 'generative-ai');
      for (final lesson in course.allLessons) {
        await store.markLessonComplete(lesson.id);
      }
      expect(store.certificateFor(course), isNull);
      final questions = course.finalQuestions;
      await store.saveAttempt(
        TestAttempt(
          id: 'phase9-earned-in-fixture',
          subject: course.quizSubject ?? course.title,
          courseId: course.id,
          completedAt: DateTime.now(),
          selections: {for (final item in questions) item.id: item.answerIndex},
          questionIds: questions.map((item) => item.id).toList(),
          questions: questions,
          durationSeconds: 120,
        ),
      );
      final earned = store.certificateFor(course)!;
      const uri = 'content://test/earned-certificate';
      messenger.setMockMethodCallHandler(documents, (call) async {
        calls.add(call.method);
        final arguments = call.arguments as Map;
        if (call.method == 'savePdf') {
          expect(arguments['filename'], 'skillverse_${earned.id}.pdf');
          final bytes = arguments['bytes'] as Uint8List;
          expect(ascii.decode(bytes.take(4).toList()), '%PDF');
          expect(bytes.length, greaterThan(1000));
          return uri;
        }
        expect(arguments['uri'], uri);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(documents, null));

      await tester.pumpWidget(
        MaterialApp(home: CertificatesPage(store: store)),
      );
      await _tapVisible(tester, find.text(course.title));
      expect(find.text('Share PDF'), findsNothing);
      await _tapVisible(tester, find.text('Generate and save PDF'));
      expect(find.text('Certificate PDF saved.'), findsOneWidget);
      await _tapVisible(tester, find.text('Open PDF'));
      await _tapVisible(tester, find.text('Share PDF'));
      expect(calls, ['savePdf', 'renderPdf', 'sharePdf']);
      expect(store.certificateFor(course)!.toJson(), earned.toJson());
    },
    variant: const TargetPlatformVariant({TargetPlatform.android}),
  );
}
