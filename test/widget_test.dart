import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/course_models.dart';
import 'package:learning_app/data/quiz_bank.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'welcome, registration, explicit login, and logout work end to end',
    (tester) async {
      final store = await AppStore.create();
      await tester.pumpWidget(LearningApp(store: store));
      expect(find.byType(SplashScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomePage), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pumpAndSettle();
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jamie');
      await tester.enterText(fields.at(1), 'jamie@example.com');
      await tester.enterText(fields.at(3), 'secure-pass');
      await tester.enterText(fields.at(4), 'secure-pass');
      final terms = find.byType(CheckboxListTile);
      await tester.ensureVisible(terms);
      await tester.tap(terms);
      await tester.pumpAndSettle();
      final create = find.text('Create Account').last;
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(store.isAuthenticated, isFalse);
      expect(find.byType(MainScreen), findsNothing);
      expect(find.text('jamie@example.com'), findsOneWidget);
      await tester.enterText(fields.at(1), 'wrong-password');
      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Incorrect password.'), findsOneWidget);
      expect(store.isAuthenticated, isFalse);

      await tester.enterText(fields.at(1), 'secure-pass');
      await tester.ensureVisible(find.text('Login'));
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.byType(MainScreen), findsOneWidget);
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Logout'), 250);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      expect(store.isAuthenticated, isFalse);
      expect(find.byType(SignInForm), findsOneWidget);
      expect(find.byType(MainScreen), findsNothing);
    },
  );

  test('local account sign-in survives app-store reload and logout', () async {
    final store = await AppStore.create();
    await store.signUp(
      fullName: 'Taylor',
      email: 'taylor@example.com',
      mobile: '1234567890',
      password: 'secure-pass',
      confirmPassword: 'secure-pass',
    );
    expect(store.isAuthenticated, isFalse);
    final registered = await AppStore.create();
    expect(registered.isAuthenticated, isFalse);
    await registered.signIn(
      email: 'taylor@example.com',
      password: 'secure-pass',
      rememberMe: true,
    );

    final reloaded = await AppStore.create();
    expect(reloaded.isAuthenticated, isTrue);
    expect(reloaded.displayName, 'Taylor');
    await reloaded.logout();
    expect(reloaded.isAuthenticated, isFalse);
    final preferences = await SharedPreferences.getInstance();
    final completedCourse = courses.first;
    final accountId = reloaded.accounts.single.id;
    await preferences.setStringList(
      'account.$accountId.completed_lessons',
      completedCourse.allLessons.map((lesson) => lesson.id).toList(),
    );
    await preferences.setStringList(
      'account.$accountId.passed_course_assessments',
      [completedCourse.id],
    );
    await reloaded.signIn(
      email: 'taylor@example.com',
      password: 'secure-pass',
      rememberMe: true,
    );
    expect(reloaded.isAuthenticated, isTrue);
    expect(reloaded.certificateFor(completedCourse), isNotNull);
    expect(
      reloaded.certificateFor(completedCourse)!.completionDateKnown,
      isFalse,
    );
  });

  test('validates credentials and upgrades legacy password hashes', () async {
    const email = 'existing@example.com';
    SharedPreferences.setMockInitialValues({
      'auth_accounts': '[{"email":"existing@example.com","passwordHash":"8c33e661b0f45dd127186e69c3e6bd374a5c29bcc9c2538e6b9629945ea9818c"}]',
      'auth_current_email': email,
      'auth_session_active': false,
    });
    final store = await AppStore.create();
    expect(store.isAuthenticated, isFalse);
    await expectLater(
      _register(store, 'invalid @example.com'),
      throwsArgumentError,
    );
    await expectLater(
      _register(store, 'EXISTING@example.com'),
      throwsStateError,
    );
    await expectLater(
      store.resetPassword(
        email: email,
        currentPassword: 'wrong',
        newPassword: 'new-password',
      ),
      throwsStateError,
    );
    await store.signIn(
      email: email,
      password: 'secure-pass',
      rememberMe: false,
    );
    expect(store.accounts.single.passwordHash, startsWith('pbkdf2-sha256:'));
    await _register(store, 'second@example.com');
    expect(
      store.accounts.first.passwordHash,
      isNot(store.accounts.last.passwordHash),
    );
    await store.resetPassword(
      email: email,
      currentPassword: 'secure-pass',
      newPassword: 'new-password',
    );
    await expectLater(
      store.signIn(email: email, password: 'secure-pass', rememberMe: false),
      throwsStateError,
    );
    await store.signIn(
      email: email,
      password: 'new-password',
      rememberMe: false,
    );
    expect(store.currentUserEmail, email);
  });

  test('course progress is isolated across accounts and restarts', () async {
    final store = await AppStore.create();
    final course = courses.first;
    await _register(store, 'first@example.com');
    await store.toggleBookmark('first-bookmark');
    await store.saveProject(
      const StudentProject(
        id: 'first-project',
        title: 'First project',
        description: '',
        category: '',
        technologies: '',
      ),
    );
    await store.saveAttempt(
      TestAttempt(
        id: 'practice-attempt',
        subject: 'Python',
        completedAt: DateTime(2025),
        selections: const {},
        questionIds: const [],
        durationSeconds: 10,
      ),
    );
    final firstId = store.currentUserId;
    expect(store.completedLessonCount, 0);
    for (final lesson in course.allLessons.take(3)) {
      await store.markLessonComplete(lesson.id);
    }
    await store.updateDisplayName('First account');
    await store.logout();
    expect(store.currentUserId, isNull);
    expect(store.completedLessons, isEmpty);
    expect(store.passedCourseAssessments, isEmpty);
    expect(store.attempts, isEmpty);
    expect(store.displayName, 'Learner');
    expect(store.bookmarks, isEmpty);
    expect(store.projects, isEmpty);

    await _register(store, 'second@example.com');
    expect(store.currentUserId, isNot(firstId));
    expect(store.bookmarks, isEmpty);
    expect(store.projects, isEmpty);
    expect(store.completedLessonCount, 0);
    expect(store.passedCourseAssessments, isEmpty);
    expect(store.attempts, isEmpty);
    final secondLesson = course.allLessons.last.id;
    await store.markLessonComplete(secondLesson);

    final reloaded = await AppStore.create();
    expect(reloaded.completedLessons, {secondLesson});
    await reloaded.signIn(
      email: 'FIRST@example.com',
      password: 'secure-pass',
      rememberMe: false,
    );
    expect(reloaded.currentUserId, firstId);
    expect(reloaded.completedLessonCount, 3);
    expect(reloaded.completedLessons, isNot(contains(secondLesson)));
    expect(reloaded.passedCourseAssessments, isEmpty);
    expect(reloaded.attempts.map((attempt) => attempt.id), [
      'practice-attempt',
    ]);
    expect(reloaded.bookmarks, {'first-bookmark'});
    expect(reloaded.projects.single.id, 'first-project');
    expect(reloaded.displayName, 'First account');
    final restarted = await AppStore.create();
    expect(restarted.isAuthenticated, isFalse);
    expect(restarted.completedLessons, isEmpty);
  });

  for (final accountCount in [1, 2]) {
    test(
      'legacy course progress with $accountCount registered accounts',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_accounts':
              '[{"email":"first@example.com","passwordHash":"8c33e661b0f45dd127186e69c3e6bd374a5c29bcc9c2538e6b9629945ea9818c"}'
              '${accountCount == 2 ? ',{"email":"second@example.com"}' : ''}]',
          'auth_current_email': 'first@example.com',
          'auth_session_active': true,
          'completed_lessons': ['legacy-lesson'],
          'passed_course_assessments': ['legacy-course'],
        });
        final store = await AppStore.create();
        expect(
          store.completedLessons,
          accountCount == 1 ? {'legacy-lesson'} : isEmpty,
        );
        expect(
          store.passedCourseAssessments,
          accountCount == 1 ? {'legacy-course'} : isEmpty,
        );
        final originalId = store.currentUserId;
        final preferences = await SharedPreferences.getInstance();
        expect(preferences.getStringList('completed_lessons'), [
          'legacy-lesson',
        ]);
        await _register(store, 'new@example.com');
        expect(store.completedLessons, isEmpty);
        expect(store.passedCourseAssessments, isEmpty);
        expect(store.currentUserId, isNot(originalId));
      },
    );
  }

  testWidgets('catalog filters partition courses and combine with search', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await AppStore.create();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LearnPage(store: store)),
      ),
    );

    expect(
      courses.map((course) => course.id).toSet(),
      hasLength(courses.length),
    );
    expect(
      courses.map((course) => course.title).toSet(),
      hasLength(courses.length),
    );
    final search = find.byType(TextField);
    const examples = {
      'Beginner': 'Python Programming',
      'Intermediate': 'Machine Learning',
      'Advanced': 'Deep Learning',
    };

    for (final level in ['All', ...examples.keys]) {
      await tester.tap(find.widgetWithText(ChoiceChip, level));
      await tester.pumpAndSettle();
      for (final course in courses) {
        expect(
          find.text(course.title),
          level == 'All' || course.level == level
              ? findsOneWidget
              : findsNothing,
          reason: '$level / ${course.title}',
        );
      }
      for (final entry in examples.entries) {
        await tester.enterText(search, '  ${entry.value.toUpperCase()}  ');
        await tester.pumpAndSettle();
        expect(
          find.text(entry.value),
          level == 'All' || level == entry.key ? findsOneWidget : findsNothing,
          reason: '$level / ${entry.value}',
        );
      }
      await tester.enterText(search, 'no matching Skillverse course');
      await tester.pumpAndSettle();
      expect(find.text('No courses found'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pumpAndSettle();
    }
  });

  testWidgets('shows the dashboard and all five main destinations', (
    tester,
  ) async {
    final store = await AppStore.create();
    await _pumpAuthenticatedApp(tester, store);

    expect(find.text('Hello, Learner!'), findsOneWidget);
    final navigation = find.byType(NavigationBar);
    for (final label in ['Home', 'Learn', 'Interview', 'Projects', 'Profile']) {
      expect(
        find.descendant(of: navigation, matching: find.text(label)),
        findsOneWidget,
      );
    }
    final progress = find.byType(LinearProgressIndicator);
    await tester.scrollUntilVisible(progress, 250);
    expect(tester.widget<LinearProgressIndicator>(progress).value, 0);
  });

  testWidgets('course lessons and interview practice are reachable', (
    tester,
  ) async {
    final store = await AppStore.create();
    await _pumpAuthenticatedApp(tester, store);

    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(find.text('Learning courses'), findsOneWidget);
    expect(find.text('Python Programming'), findsOneWidget);

    await tester.tap(find.text('Interview'));
    await tester.pumpAndSettle();
    expect(find.text('Interview practice'), findsOneWidget);
    expect(find.text('Mock tests'), findsOneWidget);
  });

  testWidgets('courses opened from Profile have Material ancestors', (
    tester,
  ) async {
    final store = await AppStore.create();
    await _pumpAuthenticatedApp(tester, store);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My courses'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Learning courses'), findsOneWidget);

    await tester.tap(find.text('Python Programming').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Modules and lessons'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Modules and lessons'), findsOneWidget);
  });

  testWidgets('Databricks modules open their lesson content', (tester) async {
    final store = await AppStore.create();
    await _pumpAuthenticatedApp(tester, store);
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Databricks').hitTestable(),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Databricks').hitTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('1. Databricks and the Lakehouse'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('1. Databricks and the Lakehouse'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('What Databricks provides'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('What Databricks provides'), findsOneWidget);
    await tester.tap(find.text('What Databricks provides'));
    await tester.pumpAndSettle();
    expect(find.text('Topics'), findsOneWidget);
    expect(find.text('Account vs workspace'), findsOneWidget);
  });

  test('bookmarks, lesson progress, profile and attempts persist', () async {
    final store = await AppStore.create();
    await _register(store, 'taylor@example.com');
    await store.toggleBookmark(interviewQuestions.first.id);
    for (final lesson in courses.first.allLessons) {
      await store.markLessonComplete(lesson.id);
    }
    await _passFinal(store, courses.first);
    await store.updateDisplayName('Taylor');
    await store.saveAttempt(
      TestAttempt(
        id: 'attempt-1',
        subject: 'Python',
        completedAt: DateTime(2026, 1, 1),
        selections: const {'py-1': 1},
        questionIds: const ['py-1'],
        durationSeconds: 30,
      ),
    );

    final reloaded = await AppStore.create();
    expect(reloaded.bookmarks, contains(interviewQuestions.first.id));
    expect(
      reloaded.completedLessons,
      contains(courses.first.allLessons.first.id),
    );
    expect(reloaded.displayName, 'Taylor');
    expect(
      reloaded.attempts.map((attempt) => attempt.id),
      contains('attempt-1'),
    );
    expect(reloaded.isCourseComplete(courses.first), isTrue);
  });

  test(
    'priority courses have structured modules and usable assessment banks',
    () {
      for (final subject in ['Databricks', 'PySpark', 'Azure DevOps']) {
        final course = courses.singleWhere((course) => course.title == subject);
        expect(course.modules.length, greaterThanOrEqualTo(10));
        expect(course.allLessons.length, greaterThan(course.modules.length));
        expect(
          quizQuestions.where((question) => question.subject == subject).length,
          greaterThanOrEqualTo(100),
        );
      }
    },
  );

  test('Python course includes its beginner-to-advanced syllabus', () {
    final python = courses.singleWhere(
      (course) => course.title == 'Python Programming',
    );
    expect(python.modules.length, greaterThanOrEqualTo(15));
    expect(python.allLessons.length, greaterThanOrEqualTo(30));
    expect(
      python.allLessons.map((lesson) => lesson.title),
      containsAll([
        'Introduction to Python',
        'Virtual environments and pip',
        'Variables and assignment',
        'Creating and updating lists',
        'Defining functions and returning values',
        'Recursion and base cases',
        'Classes, objects, and constructors',
        'Inheritance and composition',
        'NumPy arrays and vectorization',
        'Pandas Series and DataFrames',
        'Plotting with Matplotlib',
        'Python interview questions and review',
      ]),
    );
    expect(
      python.allLessons.every(
        (lesson) =>
            lesson.summary.isNotEmpty &&
            lesson.example.isNotEmpty &&
            lesson.exercise != null,
      ),
      isTrue,
    );
  });

  test(
    'all major question banks have unique tagged questions per difficulty',
    () {
      for (final subject in quizBankSubjects) {
        final questions = quizQuestions
            .where((question) => question.subject == subject)
            .toList();
        expect(questions.length, greaterThanOrEqualTo(100), reason: subject);
        expect(
          questions.map((question) => question.prompt).toSet().length,
          greaterThanOrEqualTo(100),
          reason: subject,
        );
        expect(
          questions.every((question) => question.topic.isNotEmpty),
          isTrue,
        );
        expect(
          questions.every((question) => question.options.length == 4),
          isTrue,
        );
        expect(
          questions.every(
            (question) =>
                question.options.toSet().length == 4 &&
                question.answerIndex >= 0 &&
                question.answerIndex < question.options.length,
          ),
          isTrue,
        );
        for (final difficulty in ['Basic', 'Intermediate', 'Advanced']) {
          expect(
            questions
                .where((question) => question.difficulty == difficulty)
                .length,
            greaterThanOrEqualTo(50),
            reason: '$subject / $difficulty',
          );
        }
      }
    },
  );

  testWidgets('50-question test setup selects unique questions', (
    tester,
  ) async {
    final store = await AppStore.create();
    await tester.pumpWidget(
      MaterialApp(
        home: TestSetupPage(subject: 'Machine Learning', store: store),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('unique questions available for all levels'),
      findsOneWidget,
    );
    for (final count in [10, 20, 30, 50]) {
      final countLabel = find.text('$count Questions');
      await tester.scrollUntilVisible(
        countLabel,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(countLabel);
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(
        find.ancestor(of: countLabel, matching: find.byType(ChoiceChip)),
      );
      expect(chip.selected, isTrue);
    }
    await tester.scrollUntilVisible(
      find.text('Start exam'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Start exam'));
    await tester.pumpAndSettle();

    final testPage = tester.widget<MockTestPage>(find.byType(MockTestPage));
    expect(testPage.questions, hasLength(50));
    expect(
      testPage.questions.map((question) => question.id).toSet(),
      hasLength(50),
    );
  });

  testWidgets('practice mode reveals feedback after an answer is submitted', (
    tester,
  ) async {
    final store = await AppStore.create();
    final questions = quizQuestions
        .where((question) => question.subject == 'Databricks')
        .take(10)
        .toList();
    await tester.pumpWidget(
      MaterialApp(
        home: MockTestPage(
          subject: 'Databricks',
          questions: questions,
          store: store,
          mode: TestMode.practice,
        ),
      ),
    );

    await tester.tap(find.text(questions.first.options.first).first);
    await tester.pump();
    await tester.tap(find.text('Submit answer / Reveal answer'));
    await tester.pump();

    expect(find.text('Correct'), findsOneWidget);
    expect(find.text(questions.first.explanation), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('exam mode defers answers until confirmed submission', (
    tester,
  ) async {
    final store = await AppStore.create();
    await _register(store, 'exam@example.com');
    final questions = quizQuestions
        .where((question) => question.subject == 'Databricks')
        .take(10)
        .toList();
    await tester.pumpWidget(
      MaterialApp(
        home: MockTestPage(
          subject: 'Databricks',
          questions: questions,
          store: store,
          mode: TestMode.exam,
        ),
      ),
    );

    await tester.tap(find.text(questions.first.options.first).first);
    await tester.pump();
    expect(find.text(questions.first.explanation), findsNothing);

    for (var index = 0; index < questions.length - 1; index++) {
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pump();
    }
    await tester.ensureVisible(find.text('Submit exam'));
    await tester.tap(find.text('Submit exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit').last);
    await tester.pumpAndSettle();

    expect(find.text('10%'), findsOneWidget);
    final explanation = find.text(questions.first.explanation);
    await tester.scrollUntilVisible(
      explanation,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(explanation, findsOneWidget);
    expect(store.attempts.single.mode, 'exam');
    expect(store.attempts.single.questionIds, hasLength(10));
  });
}

Future<void> _pumpAuthenticatedApp(WidgetTester tester, AppStore store) async {
  await store.signUp(
    fullName: 'Learner',
    email: 'learner@example.com',
    mobile: '',
    password: 'learner-pass',
    confirmPassword: 'learner-pass',
  );
  await store.signIn(
    email: 'learner@example.com',
    password: 'learner-pass',
    rememberMe: true,
  );
  await tester.pumpWidget(LearningApp(store: store));
  await tester.pump(const Duration(milliseconds: 800));
  await tester.pumpAndSettle();
}

Future<void> _register(AppStore store, String email) async {
  await store.signUp(
    fullName: 'Taylor',
    email: email,
    mobile: '',
    password: 'secure-pass',
    confirmPassword: 'secure-pass',
  );
  await store.signIn(email: email, password: 'secure-pass', rememberMe: true);
}

Future<void> _passFinal(AppStore store, Course course) => store.saveAttempt(
  TestAttempt(
    id: 'final-${course.id}',
    subject: course.quizSubject!,
    completedAt: DateTime(2026, 11, 17),
    selections: {for (final q in course.finalQuestions) q.id: q.answerIndex},
    questionIds: course.finalQuestions.map((q) => q.id).toList(),
    durationSeconds: 30,
    mode: 'exam',
    courseId: course.id,
  ),
);
