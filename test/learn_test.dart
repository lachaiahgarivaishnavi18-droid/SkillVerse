import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/course_models.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';

const _accounts =
    '[{"fullName":"Alexandra Katherine Montgomery","email":"alex@example.com","passwordHash":"7110985e7c834fd1bd8d47120eea202fec188a977f7b7b01c82e6ae8099200be"},{"fullName":"Second Learner","email":"second@example.com","passwordHash":"7110985e7c834fd1bd8d47120eea202fec188a977f7b7b01c82e6ae8099200be"}]';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_accounts': _accounts,
      'auth_current_email': 'alex@example.com',
      'auth_session_active': true,
    });
  });

  test(
    'all eighteen requested curricula contain complete structured content',
    () {
      const titles = [
        'Python Programming',
        'SQL',
        'Machine Learning',
        'Data Science',
        'Artificial Intelligence',
        'Data Structures and Algorithms',
        'Technical Fundamentals',
        'Statistics and Mathematics for Data Science',
        'Deep Learning',
        'Generative AI',
        'Data Analytics',
        'Power BI',
        'Advanced Excel',
        'Databricks',
        'PySpark',
        'Azure DevOps',
        'Cloud Computing',
        'Big Data Technologies',
      ];
      final lessonIds = <String>{};
      final questionIds = <String>{};
      for (final title in titles) {
        final course = courses.singleWhere((course) => course.title == title);
        expect(course.modules.length, greaterThanOrEqualTo(8), reason: title);
        expect(course.objectives.length, greaterThanOrEqualTo(2));
        expect(course.description, isNotEmpty);
        expect(course.prerequisites, isNotEmpty);
        expect(course.capstoneProject, isNotEmpty);
        for (final level in CourseDifficulty.values) {
          expect(
            course.matchesLevel(level.label),
            isTrue,
            reason: '$title / $level',
          );
        }
        for (final module in course.modules) {
          expect(
            module.lessons.length,
            greaterThanOrEqualTo(2),
            reason: module.title,
          );
          expect(module.summary, isNotEmpty);
          expect(module.assignment, isNotEmpty);
          expect(module.questions, isNotEmpty);
          expect(module.assessmentQuestions, isNotEmpty);
          for (final lesson in module.lessons) {
            expect(lessonIds.add(lesson.id), isTrue, reason: lesson.id);
            expect(lesson.summary.length, greaterThan(60), reason: lesson.id);
            expect(lesson.example, isNotEmpty);
            expect(lesson.topics, isNotEmpty);
            expect(lesson.expectedOutput, isNotEmpty, reason: lesson.id);
            expect(lesson.exercise, isNotEmpty, reason: lesson.id);
            expect(lesson.industryUse, isNotEmpty, reason: lesson.id);
          }
          for (final question in [
            ...module.questions,
            ...module.assessmentQuestions,
          ]) {
            expect(questionIds.add(question.id), isTrue, reason: question.id);
            expect(question.options.toSet().length, question.options.length);
            expect(
              question.answerIndex,
              inInclusiveRange(0, question.options.length - 1),
            );
            expect(question.explanation, isNotEmpty);
          }
        }
      }
      expect(courses.any((course) => course.title == 'Git and GitHub'), isTrue);
      expect(courses.first.id, 'python');
      expect(
        courses
            .expand((course) => course.allLessons)
            .map((lesson) => lesson.id),
        containsAll([
          'sql-select',
          'ml-splits',
          'ds-cleaning',
          'ai-search',
          'ds-hash',
          'tf-http',
          'python-introduction',
          'dbx-intro',
        ]),
      );
    },
  );

  test(
    'progress, final gates and immutable certificates persist per account',
    () async {
      final store = await AppStore.create();
      final course = courses.singleWhere(
        (course) => course.title == 'Generative AI',
      );
      expect(store.progressFor(course), 0);
      expect(store.continueLesson(course)?.id, course.allLessons.first.id);
      await expectLater(store.saveAttempt(_attempt(course)), throwsStateError);
      await store.markLessonComplete(course.allLessons.first.id);
      expect(store.progressFor(course), 1 / course.allLessons.length);
      expect(store.continueLesson(course)?.id, course.allLessons[1].id);
      final advanced = store.continueLesson(course, difficulty: 'Advanced');
      expect(advanced?.difficulty, CourseDifficulty.advanced);
      for (final lesson in course.allLessons.skip(1)) {
        await store.markLessonComplete(lesson.id);
      }
      expect(store.continueLesson(course), isNull);
      await expectLater(
        store.markCourseAssessmentPassed(course.id),
        throwsStateError,
      );
      await store.saveAttempt(_attempt(course, correct: false));
      expect(store.certificateFor(course), isNull);
      await store.saveAttempt(_attempt(course, mode: 'practice'));
      expect(store.certificateFor(course), isNull);
      await store.saveAttempt(_attempt(course));
      final certificate = store.certificateFor(course)!;
      expect(certificate.studentName, 'Alexandra Katherine Montgomery');
      expect(certificate.completedAt, DateTime(2026, 11, 17));
      expect(certificate.id, startsWith('SV-'));
      expect(certificate.completionDateKnown, isTrue);
      await store.updateDisplayName('Changed nickname');
      await store.saveAttempt(_attempt(course, id: 'retake'));
      final reloaded = await AppStore.create();
      expect(reloaded.progressFor(course), 1);
      expect(reloaded.certificateFor(course)!.toJson(), certificate.toJson());
      await reloaded.logout();
      expect(reloaded.certificateFor(course), isNull);
      expect(reloaded.completedLessons, isEmpty);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_current_email', 'second@example.com');
      await preferences.setBool('auth_session_active', true);
      final second = await AppStore.create();
      expect(second.progressFor(course), 0);
      expect(second.certificateFor(course), isNull);
      for (final lesson in course.allLessons) {
        await second.markLessonComplete(lesson.id);
      }
      await second.saveAttempt(_attempt(course));
      expect(second.certificateFor(course)!.id, isNot(certificate.id));
      expect(second.certificateFor(course)!.studentName, 'Second Learner');
      await preferences.setString('auth_current_email', 'alex@example.com');
      final firstAgain = await AppStore.create();
      expect(firstAgain.certificateFor(course)!.toJson(), certificate.toJson());
      final expanded = courses.singleWhere((course) => course.title == 'SQL');
      await preferences.setStringList(
        'account.${firstAgain.currentUserId}.completed_lessons',
        [
          ...firstAgain.completedLessons,
          ...expanded.allLessons
              .take(expanded.allLessons.length - 1)
              .map((lesson) => lesson.id),
        ],
      );
      await preferences.setStringList(
        'account.${firstAgain.currentUserId}.passed_course_assessments',
        [course.id, expanded.id],
      );
      final historicPass = TestAttempt(
        id: 'historic-pass',
        subject: expanded.quizSubject!,
        completedAt: DateTime(2000),
        selections: {
          for (final question in expanded.finalQuestions)
            question.id: question.answerIndex,
        },
        questionIds: expanded.finalQuestions
            .map((question) => question.id)
            .toList(),
        durationSeconds: 60,
        courseId: expanded.id,
      );
      await preferences.setString(
        'account.${firstAgain.currentUserId}.course_attempts',
        jsonEncode([historicPass.toJson()]),
      );
      final completionStart = DateTime.now();
      await firstAgain.markLessonComplete(expanded.allLessons.last.id);
      final expandedCertificate = firstAgain.certificateFor(expanded)!;
      expect(
        expandedCertificate.completedAt.isBefore(completionStart),
        isFalse,
      );
      expect(expandedCertificate.completionDateKnown, isTrue);
    },
  );

  testWidgets(
    'level selection reaches matching lessons and Continue Learning',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = await AppStore.create();
      final course = courses.singleWhere((course) => course.title == 'SQL');
      await tester.pumpWidget(
        MaterialApp(
          home: CourseDetailPage(
            course: course,
            store: store,
            initialDifficulty: 'Advanced',
          ),
        ),
      );
      await tester.tap(find.text('Continue Learning'));
      await tester.pumpAndSettle();
      final page = tester.widget<LessonPage>(find.byType(LessonPage));
      expect(page.lesson.difficulty, CourseDifficulty.advanced);
      expect(
        page.courseLessons.every(
          (lesson) => lesson.difficulty == CourseDifficulty.advanced,
        ),
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.text('Mark lesson complete'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Mark lesson complete'));
      await tester.pumpAndSettle();
      expect(store.completedLessons, contains(page.lesson.id));
    },
  );

  testWidgets('module quiz shows feedback and supports retry', (tester) async {
    final store = await AppStore.create();
    final course = courses.singleWhere((course) => course.title == 'SQL');
    final module = course.modules.first;
    final question = module.questions.first;
    await tester.pumpWidget(MaterialApp(home: ModuleQuizPage(module: module)));
    await tester.tap(find.text(question.options[question.answerIndex]));
    await tester.pump();
    await tester.tap(find.text('Check answers'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text(question.explanation), findsOneWidget);
    expect(store.passedCourseAssessments, isEmpty);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Correct'), findsNothing);
  });

  testWidgets('syllabus shortcuts and level filters keep modules reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await AppStore.create();
    final course = courses.singleWhere((course) => course.title == 'SQL');
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailPage(course: course, store: store),
      ),
    );
    await tester.tap(find.text('8 modules'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Modules and lessons')).dy,
      lessThan(500),
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Advanced'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Advanced'));
    await tester.pumpAndSettle();
    expect(find.text(course.modules.first.title), findsNothing);
    expect(find.text(course.modules.last.title), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final python = courses.first;
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailPage(course: python, store: store),
      ),
    );
    await tester.ensureVisible(find.text(python.duration));
    await tester.tap(find.text(python.duration));
    await tester.pumpAndSettle();
    final remaining = find.textContaining(
      'Approximate remaining time is 30 hours',
    );
    expect(remaining, findsOneWidget);
    Navigator.of(tester.element(remaining)).pop();
    await tester.pumpAndSettle();
    final topics = find.text('${python.topicCount} topics');
    await tester.ensureVisible(topics);
    await tester.tap(topics);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(python.allTopics.join(', ')), findsOneWidget);
  });

  testWidgets('the complete final exam unlocks the Profile certificate list', (
    tester,
  ) async {
    final store = await AppStore.create();
    final course = courses.singleWhere(
      (course) => course.title == 'Generative AI',
    );
    for (final lesson in course.allLessons) {
      await store.markLessonComplete(lesson.id);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailPage(course: course, store: store),
      ),
    );
    await tester.ensureVisible(find.text('Start final assessment'));
    await tester.tap(find.text('Start final assessment'));
    await tester.pumpAndSettle();
    for (var index = 0; index < course.finalQuestions.length; index++) {
      final question = course.finalQuestions[index];
      final answer = find.text(question.options[question.answerIndex]);
      await tester.ensureVisible(answer);
      await tester.tap(answer);
      await tester.pump();
      if (index < course.finalQuestions.length - 1) {
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
    }
    await tester.ensureVisible(find.text('Submit exam'));
    await tester.tap(find.text('Submit exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit').last);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);
    expect(store.certificateFor(course), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: CertificatesPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text(course.title), findsOneWidget);
    expect(
      find.textContaining('Alexandra Katherine Montgomery'),
      findsOneWidget,
    );
  });

  test('certificate PDF contains a valid export', () async {
    final certificate = CourseCertificate(
      id: 'SV-0123456789ABCDEF01234567',
      userId: 'test-user',
      studentName: 'Alexandra Katherine Montgomery',
      courseId: 'statistics',
      courseName: 'Statistics and Mathematics for Data Science',
      completedAt: DateTime(2026, 11, 17),
    );
    final bytes = await buildCertificatePdf(certificate);
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
    final directory = Directory('build/learn_qa')..createSync(recursive: true);
    File('${directory.path}/certificate-qa.pdf').writeAsBytesSync(bytes);
    final unicode = CourseCertificate(
      id: 'SV-UNICODE-TEST',
      userId: 'unicode-user',
      studentName: 'आशा शर्मा',
      courseId: 'statistics',
      courseName: certificate.courseName,
      completedAt: certificate.completedAt,
    );
    File('${directory.path}/certificate-unicode-qa.pdf')
        .writeAsBytesSync(await buildCertificatePdf(unicode));
  });
}

TestAttempt _attempt(
  Course course, {
  bool correct = true,
  String mode = 'exam',
  String id = 'final',
}) => TestAttempt(
  id: '$id-$mode-$correct',
  subject: course.quizSubject!,
  completedAt: DateTime(2026, 11, 17),
  selections: {
    for (final q in course.finalQuestions)
      q.id: correct ? q.answerIndex : (q.answerIndex + 1) % q.options.length,
  },
  questionIds: course.finalQuestions.map((q) => q.id).toList(),
  durationSeconds: 60,
  mode: mode,
  courseId: course.id,
);
