import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/project_briefs.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_accounts': '[{"fullName":"Phase Six Learner","email":"learner@example.com","passwordHash":"fixture"}]',
      'auth_current_email': 'learner@example.com',
      'auth_session_active': true,
    }),
  );

  test(
    'each project brief maps to real curriculum and usable deliverables',
    () {
      for (final course in courses) {
        final brief = projectBriefFor(course);
        expect(brief, isNotNull, reason: course.id);
        expect(brief!.requirements, isNotEmpty);
        expect(brief.deliverables, isNotEmpty);
        expect(brief.criteria, isNotEmpty);
        expect(brief.relatedLessons, isNotEmpty, reason: course.id);
        expect(brief.relatedLessons.every(course.allLessons.contains), isTrue);
      }
    },
  );

  test(
    'repository URLs are safe and legacy links survive deletion and Undo',
    () async {
      final store = await AppStore.create();
      final project = StudentProject.fromJson({
        'id': 'portfolio',
        'title': 'Portfolio',
        'description': 'Reproducible analysis',
        'category': 'Python',
        'technologies': 'pandas',
        'githubUrl': 'https://gitlab.com/learner/analysis',
        'courseId': 'python',
        'topic': 'Files',
      });
      expect(project.repositoryUrl, 'https://gitlab.com/learner/analysis');
      for (final value in [
        'file:///secret',
        'javascript:alert(1)',
        'https://name:password@example.com',
      ]) {
        expect(StudentProject.repositoryUri(value), isNull);
      }
      final owner = store.currentUserId!;
      await store.saveProject(project);
      await store.deleteProject(project.id);
      expect(store.projects, isEmpty);
      await store.restoreDeletedProject(project, 'different-account');
      expect(store.projects, isEmpty);
      await store.restoreDeletedProject(project, owner);
      await store.restoreDeletedProject(project, owner);
      final reopened = await AppStore.create();
      expect(reopened.projects.single.toJson(), project.toJson());
    },
  );

  testWidgets('certificate preview edits leave the earned record intact', (
    tester,
  ) async {
    final store = await AppStore.create();
    final course = courses.firstWhere((value) => value.id == 'generative-ai');
    for (final lesson in course.allLessons) {
      await store.markLessonComplete(lesson.id);
    }
    expect(store.certificateFor(course), isNull);
    final questions = course.finalQuestions;
    await store.saveAttempt(
      TestAttempt(
        id: 'phase6-real-final',
        subject: course.quizSubject ?? course.title,
        completedAt: DateTime.now(),
        selections: {
          for (final question in questions) question.id: question.answerIndex,
        },
        questionIds: questions.map((question) => question.id).toList(),
        questions: questions,
        durationSeconds: 200,
        fullCourseAssessment: true,
        courseId: course.id,
      ),
    );
    final record = store.certificateFor(course)!;
    await tester.pumpWidget(MaterialApp(home: CertificatesPage(store: store)));
    await tester.tap(find.text(course.title));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Updated Display Name',
    );
    await tester.enterText(find.byType(TextFormField).last, 'My printed title');
    await tester.pump();
    expect(find.text('Updated Display Name'), findsWidgets);
    expect(find.text('Recorded course · ${course.title}'), findsOneWidget);
    expect(store.certificateFor(course)!.toJson(), record.toJson());
  });

  testWidgets('profile milestones reflect saved lessons only', (tester) async {
    final store = await AppStore.create();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfilePage(store: store)),
      ),
    );
    expect(find.text('0 of 6 earned'), findsOneWidget);
    await store.markLessonComplete(courses.first.allLessons.first.id);
    await tester.pumpAndSettle();
    expect(find.text('1 of 6 earned'), findsOneWidget);
    await tester.tap(find.text('Learning milestones'));
    await tester.pumpAndSettle();
    expect(find.text('First lesson'), findsOneWidget);
    expect(find.byTooltip('Earned'), findsOneWidget);
  });

  testWidgets('offline leaderboards do not show invented rankings', (
    tester,
  ) async {
    final store = await AppStore.create();
    await tester.pumpWidget(MaterialApp(home: LeaderboardPage(store: store)));
    for (final tab in ['Global', 'Weekly', 'Monthly']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text('Rankings unavailable'), findsOneWidget);
      expect(find.textContaining(' pts'), findsNothing);
    }
  });
}
