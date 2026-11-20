import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/interview_attempt.dart';
import 'package:learning_app/data/interview_questions.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> signIn(AppStore store, String email) async {
    await store.signUp(
      fullName: 'Test Learner',
      email: email,
      mobile: '',
      password: 'sample-pass',
      confirmPassword: 'sample-pass',
    );
    await store.signIn(email: email, password: 'sample-pass', rememberMe: true);
  }

  test(
    'interview questions cover all categories and have unique IDs and prompts',
    () {
      final ids = <String>{};
      final prompts = <String>{};
      for (final category in interviewCategories) {
        final questions = interviewQuestions.where(
          (q) => q.category == category,
        );
        expect(questions.length, greaterThanOrEqualTo(50), reason: category);
        expect(
          questions.map((q) => q.difficulty).toSet(),
          containsAll(['Beginner', 'Intermediate', 'Advanced']),
          reason: category,
        );
      }
      for (final question in interviewQuestions) {
        expect(ids.add(question.id), isTrue, reason: question.id);
        expect(
          prompts.add(question.question.trim().toLowerCase()),
          isTrue,
          reason: question.question,
        );
        expect(question.answer, isNotEmpty);
        expect(question.explanation, isNotEmpty);
        expect(question.example ?? question.code, isNotEmpty);
      }
    },
  );

  testWidgets(
    'question bank combines filters and search, and bookmarks appear in saved questions',
    (tester) async {
      final store = await AppStore.create();
      await signIn(store, 'reader@example.com');
      await tester.pumpWidget(
        MaterialApp(home: InterviewQuestionsPage(store: store)),
      );
      await tester.tap(find.textContaining('Category'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'SQL'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Difficulty'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PopupMenuItem<String>, 'Intermediate'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'most recent invoice');
      await tester.pumpAndSettle();
      const prompt =
          'How can you retain exactly the most recent invoice per customer?';
      expect(find.text(prompt), findsOneWidget);
      await tester.tap(find.text(prompt));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save question'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Remove bookmark'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('saved'),
          home: InterviewQuestionsPage(store: store, savedOnly: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(prompt), findsOneWidget);
      expect(find.text('1 question'), findsOneWidget);
    },
  );

  testWidgets('all categories open the exact selected difficulty and count', (
    tester,
  ) async {
    final store = await AppStore.create();
    await tester.binding.setSurfaceSize(const Size(1100, 3300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: MockInterviewTopicsPage(store: store)),
    );
    for (final difficulty in ['Beginner', 'Intermediate', 'Advanced']) {
      final chip = find.widgetWithText(ChoiceChip, difficulty);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      for (final category in interviewCategories) {
        final expected = interviewQuestions
            .where((q) => q.category == category && q.difficulty == difficulty)
            .map((q) => q.id)
            .toSet();
        final tile = find.widgetWithText(ListTile, category);
        expect(
          find.descendant(
            of: tile,
            matching: find.text('${expected.length} questions'),
          ),
          findsOneWidget,
          reason: '$category / $difficulty',
        );
        await tester.tap(tile);
        await tester.pumpAndSettle();
        final session = tester.widget<MockInterviewPage>(
          find.byType(MockInterviewPage),
        );
        expect(session.mode, difficulty);
        expect(session.questions.map((q) => q.id).toSet(), expected);
        expect(session.questions, hasLength(expected.length));
        expect(
          find.text('Question 1 of ${expected.length} · $difficulty'),
          findsOneWidget,
        );
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      }
    }
  });

  testWidgets('random practice and company tracks open interview questions', (
    tester,
  ) async {
    final store = await AppStore.create();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InterviewHubPage(store: store)),
      ),
    );
    await tester.scrollUntilVisible(find.text('Random practice'), 150);
    await tester.tap(find.text('Random practice'));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionDetailPage), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Company practice'), 150);
    await tester.tap(find.text('Company practice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Product-based'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Python'));
    await tester.pumpAndSettle();
    final count = interviewQuestions
        .where((q) => q.category == 'Python' && q.difficulty == 'Advanced')
        .length;
    expect(find.text('Question 1 of $count · Advanced'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fresher'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Python'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp(r'^Question 1 of [0-9]+ · Beginner$')),
      findsOneWidget,
    );
  });

  testWidgets(
    'written mock preserves drafts, scores answers, saves and retries',
    (tester) async {
      final store = await AppStore.create();
      await signIn(store, 'learner@example.com');
      final questions = interviewQuestions
          .where((q) => q.category == 'HR Interview Questions')
          .take(2)
          .toList();
      await tester.pumpWidget(
        MaterialApp(
          home: MockInterviewPage(
            store: store,
            category: 'HR Interview Questions',
            mode: 'Beginner',
            track: 'Standard',
            questions: questions,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining(RegExp(r'^\d+:\d{2}$')), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'My first written answer');
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text(questions[1].question), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 400));
      final checkpoint = store.interviewDraft(
        'HR Interview Questions',
        'Beginner',
        'Standard',
      );
      expect(checkpoint?.questionIndex, 1);
      expect(
        checkpoint?.answers[questions.first.id],
        'My first written answer',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: MockInterviewPage(
            store: store,
            category: 'HR Interview Questions',
            mode: 'Beginner',
            track: 'Standard',
            questions: questions,
            resume: store.interviewDraft(
              'HR Interview Questions',
              'Beginner',
              'Standard',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(questions[1].question), findsOneWidget);

      await tester.tap(find.text('Previous'));
      await tester.pump();
      expect(find.text('My first written answer'), findsOneWidget);
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();
      expect(find.text('Reference answer'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Correct'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Correct'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Finish interview'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Finish interview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish and save'));
      await tester.pumpAndSettle();
      expect(find.text('50% self-assessed score'), findsOneWidget);
      expect(
        store.interviewAttempts.single.responses[questions.first.id]?.text,
        'My first written answer',
      );
      await tester.tap(find.text('Retry interview'));
      await tester.pumpAndSettle();
      expect(find.text(questions.first.question), findsOneWidget);
      expect(find.text('My first written answer'), findsNothing);
      expect(
        store.interviewDraft('HR Interview Questions', 'Beginner', 'Standard'),
        isNull,
      );
    },
  );

  test(
    'history, bookmarks and question coverage persist and are account scoped',
    () async {
      final store = await AppStore.create();
      await signIn(store, 'first@example.com');
      final originalOwner = store.currentUserId!;
      final question = interviewQuestions.first;
      await store.toggleBookmark(question.id);
      await store.markInterviewQuestionReviewed(question.id);
      final attempt = InterviewAttempt(
        id: 'attempt-1',
        category: question.category,
        mode: question.difficulty,
        track: 'Standard',
        completedAt: DateTime(2026, 1, 1),
        durationSeconds: 60,
        questionIds: [question.id],
        responses: {question.id: const InterviewResponse('A response', true)},
      );
      await store.saveInterviewDraft(
        originalOwner,
        question.category,
        'Intermediate',
        'Standard',
        InterviewDraft(
          id: 'unfinished',
          questionIds: [question.id],
          questionIndex: 0,
          durationSeconds: 16,
          answers: {question.id: 'Unsubmitted response'},
          responses: const {},
        ),
      );
      await store.saveInterviewAttempt(attempt, originalOwner);
      final reopened = await AppStore.create();
      expect(reopened.bookmarks, {question.id});
      expect(reopened.reviewedInterviewQuestions, {question.id});
      expect(reopened.interviewAttempts.single.score, 100);
      final draft = reopened.interviewDraft(
        question.category,
        'Intermediate',
        'Standard',
      );
      expect(draft?.answers[question.id], 'Unsubmitted response');
      expect(draft?.durationSeconds, 16);
      expect(
        reopened.interviewDraft(question.category, 'Beginner', 'Standard'),
        isNull,
      );

      await reopened.logout();
      await signIn(reopened, 'second@example.com');
      expect(reopened.bookmarks, isEmpty);
      expect(reopened.reviewedInterviewQuestions, isEmpty);
      expect(reopened.interviewAttempts, isEmpty);
      expect(
        reopened.interviewDraft(question.category, 'Intermediate', 'Standard'),
        isNull,
      );
      await expectLater(
        reopened.saveInterviewAttempt(attempt, originalOwner),
        throwsStateError,
      );
      await reopened.logout();
      await reopened.signIn(
        email: 'first@example.com',
        password: 'sample-pass',
        rememberMe: true,
      );
      expect(reopened.interviewAttempts.single.id, attempt.id);
    },
  );
}
