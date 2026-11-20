import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/exam_session.dart';
import 'package:learning_app/data/interview_attempt.dart';
import 'package:learning_app/data/learning_activity.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_accounts': '[{"fullName":"Learner","email":"learner@example.com","passwordHash":"fixture"}]',
      'auth_current_email': 'learner@example.com',
      'auth_session_active': true,
    });
  });

  test(
    'weekly goals count dated activity and preserve undated legacy history',
    () async {
      final store = await AppStore.create();
      final course = courses.first;
      final legacy = course.allLessons.first;
      final lesson = course.allLessons[1];
      final now = DateTime.now();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        'account.${store.currentUserId}.completed_lessons',
        [legacy.id],
      );
      await store.markLessonComplete(lesson.id);
      await store.markLessonComplete(lesson.id);
      final question = quizQuestions.first;
      for (final (id, date, mode) in [
        ('practice', now, 'practice'),
        ('quiz', now, 'exam'),
        (
          'previous-week',
          startOfLearningWeek(now).subtract(const Duration(seconds: 1)),
          'exam',
        ),
      ]) {
        await store.saveAttempt(
          TestAttempt(
            id: id,
            subject: question.subject,
            completedAt: date,
            durationSeconds: 20,
            questionIds: [question.id],
            selections: {question.id: question.answerIndex},
            questions: [question],
            mode: mode,
          ),
        );
      }
      await store.saveInterviewAttempt(
        InterviewAttempt(
          id: 'interview',
          category: 'Python',
          mode: 'Beginner',
          track: 'Standard',
          completedAt: now,
          durationSeconds: 30,
          questionIds: const [],
          responses: const {},
        ),
        store.currentUserId!,
      );
      await store.setWeeklyLearningGoal(5);
      final reloaded = await AppStore.create();
      expect(reloaded.weeklyLearningGoal, 5);
      expect(reloaded.weeklyActivityCount(DateTime.now()), 4);
      final activities = reloaded.learningActivity;
      expect(
        activities.map((entry) => entry.kind),
        containsAll([
          'Lesson completed',
          'Practice session',
          'Quiz',
          'Mock interview',
        ]),
      );
      expect(
        activities.where((entry) => entry.title == lesson.title),
        hasLength(1),
      );
      expect(activities.last.title, legacy.title);
      expect(activities.last.date, isNull);
      expect(
        reloaded.lessonProgress(course.learningModules.first.lessons).completed,
        2,
      );
    },
  );

  test('course reset only restarts selected active progress and keeps historical records', () async {
    final store = await AppStore.create();
    final sql = courses.firstWhere((course) => course.id == 'sql');
    final other = courses.firstWhere((course) => course.id == 'python');
    final first = sql.allLessons.first;
    final outside = other.allLessons.first;
    for (final lesson in sql.allLessons) {
      await store.markLessonComplete(lesson.id);
    }
    await store.markLessonComplete(outside.id);
    await store.recordLessonVisit(first);
    await store.recordLessonVisit(outside);
    await store.saveLessonReadingOffset(store.currentUserId!, first.id, 150);
    await store.saveLessonReadingOffset(store.currentUserId!, outside.id, 90);
    await store.toggleSavedCourse(sql);
    await store.setWeeklyLearningGoal(9);
    final questions = sql.finalQuestions;
    final now = DateTime.now();
    await store.saveAttempt(
      TestAttempt(
        id: 'past-final',
        subject: 'SQL',
        courseId: sql.id,
        completedAt: now,
        durationSeconds: 30,
        questionIds: questions.map((q) => q.id).toList(),
        selections: {for (final q in questions) q.id: q.answerIndex},
        questions: questions,
        version: assessmentVersion(questions),
        fullCourseAssessment: true,
      ),
    );
    expect(store.isCourseComplete(sql), isTrue);
    final certificateId = store.certificateFor(sql)!.id;
    await store.saveExamDraft(
      ExamDraft(
        id: 'active-sql',
        subject: 'SQL',
        courseId: sql.id,
        startedAt: now,
        deadline: now.add(const Duration(hours: 1)),
        questions: questions,
        version: assessmentVersion(questions),
        answers: {},
        marked: {},
        index: 0,
      ),
      store.currentUserId!,
    );
    final countBefore = store.learningActivity.length;

    await store.resetCourseProgress(sql);
    final reloaded = await AppStore.create();
    expect(reloaded.progressFor(sql), 0);
    expect(reloaded.hasStartedCourse(sql), isFalse);
    expect(reloaded.isCourseComplete(sql), isFalse);
    expect(reloaded.examDraft('SQL', sql.id), isNull);
    expect(reloaded.lessonReadingOffset(first.id), 0);
    expect(reloaded.lessonReadingOffset(outside.id), 90);
    expect(reloaded.completedLessons, contains(outside.id));
    expect(reloaded.savedCourseIds, contains(sql.id));
    expect(reloaded.weeklyLearningGoal, 9);
    expect(reloaded.certificateFor(sql)!.id, certificateId);
    expect(reloaded.attempts.single.id, 'past-final');
    expect(reloaded.learningActivity.length, countBefore);
    await expectLater(
      reloaded.markCourseAssessmentPassed(sql.id),
      throwsStateError,
    );
    await reloaded.markLessonComplete(first.id);
    expect(reloaded.completedLessons, contains(first.id));
    expect(reloaded.learningActivity.length, countBefore + 1);
  });

  testWidgets('result topic counts and missed practice use the saved choices', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await AppStore.create();
    final questions = quizQuestions
        .where((q) => q.subject == 'SQL')
        .take(3)
        .toList();
    final attempt = TestAttempt(
      id: 'result',
      subject: 'SQL',
      completedAt: DateTime.now(),
      durationSeconds: 12,
      questionIds: questions.map((q) => q.id).toList(),
      questions: questions,
      selections: {
        questions[0].id: questions[0].answerIndex,
        questions[1].id:
            (questions[1].answerIndex + 1) % questions[1].options.length,
      },
    );
    await store.saveAttempt(attempt);
    await tester.pumpWidget(
      MaterialApp(
        home: TestResultPage(
          attempt: attempt,
          questions: questions,
          store: store,
        ),
      ),
    );
    await tester.tap(find.text('Results by topic'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 incorrect'), findsWidgets);
    expect(find.textContaining('% accuracy'), findsWidgets);
    await tester.tap(find.text('Practice Missed Concepts'));
    await tester.pumpAndSettle();
    final practice = tester.widget<MockTestPage>(find.byType(MockTestPage));
    expect(practice.mode, TestMode.practice);
    expect(practice.questions.map((q) => q.id), [
      questions[1].id,
      questions[2].id,
    ]);
  });

  test(
    'topic results measure only actual answers for correct and incorrect',
    () {
      final question = quizQuestions.first;
      final result = topicResults([
        (question, question.answerIndex),
        (question, (question.answerIndex + 1) % question.options.length),
        (question, null),
      ]);
      expect(result[question.topic], (correct: 1, incorrect: 1, unanswered: 1));
    },
  );
}
