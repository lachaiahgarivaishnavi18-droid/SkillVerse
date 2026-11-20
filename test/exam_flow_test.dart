import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/exam_session.dart';
import 'package:learning_app/data/quiz_bank.dart';
import 'package:learning_app/data/scenario_quiz_questions.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const email = 'exam@example.com';
  const accounts =
      '[{"fullName":"Exam Learner","email":"exam@example.com","passwordHash":"local-fixture"}]';
  final questions = quizQuestions
      .where((q) => q.subject == 'SQL')
      .take(2)
      .toList();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_accounts': accounts,
      'auth_current_email': email,
      'auth_session_active': true,
    });
  });

  test(
    'authored scenarios cover existing test subjects without repeated prompts',
    () {
      expect(
        scenarioQuizQuestions.map((q) => q.subject).toSet(),
        containsAll(quizBankSubjects),
      );
      expect(
        scenarioQuizQuestions.map((q) => q.id).toSet(),
        hasLength(scenarioQuizQuestions.length),
      );
      expect(
        scenarioQuizQuestions.map((q) => q.prompt).toSet(),
        hasLength(scenarioQuizQuestions.length),
      );
      expect(
        scenarioQuizQuestions.every(
          (q) => q.options.toSet().length == 4 && q.explanation.isNotEmpty,
        ),
        isTrue,
      );
    },
  );

  test('saved versions use original choices and repeated submissions write one result', () async {
    final store = await AppStore.create();
    final question = questions.first;
    final updated = question.toJson()
      ..['answerIndex'] = (question.answerIndex + 1) % question.options.length;
    final now = DateTime.now();
    final attempt = TestAttempt(
      id: 'same-exam',
      subject: question.subject,
      completedAt: now,
      selections: {question.id: question.answerIndex},
      questionIds: [question.id],
      durationSeconds: 15,
      questions: [question],
      version: assessmentVersion([question]),
    );
    final changed = TestAttempt.fromJson(
      attempt.toJson()..['questions'] = [updated],
    );
    expect(attempt.percentage, 100);
    expect(changed.percentage, 0);
    await Future.wait([store.saveAttempt(attempt), store.saveAttempt(attempt)]);
    await store.saveAttempt(changed);
    final reloaded = await AppStore.create();
    expect(reloaded.attempts.single.percentage, 100);
    expect(reloaded.attempts.single.version, attempt.version);
  });

  testWidgets(
    'leave confirmation saves an exam and resume restores its screen',
    (tester) async {
      final store = await AppStore.create();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => MockTestPage(
                      subject: 'SQL',
                      questions: questions,
                      store: store,
                      mode: TestMode.exam,
                    ),
                  ),
                ),
                child: const Text('Begin fixture exam'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Begin fixture exam'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(RadioListTile<int>).at(questions.first.answerIndex),
      );
      await tester.pump();
      await tester.tap(find.text('Review'));
      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Leave this exam?'), findsOneWidget);
      await tester.tap(find.text('Keep working'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Question 2 of 2'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save and leave'));
      await tester.pumpAndSettle();
      expect(find.text('Begin fixture exam'), findsOneWidget);

      final reopened = await AppStore.create();
      final draft = reopened.examDraft('SQL', null)!;
      expect(draft.index, 1);
      expect(draft.answers[questions.first.id], questions.first.answerIndex);
      expect(draft.marked, contains(0));
      expect(
        draft.deadline.difference(draft.startedAt),
        const Duration(minutes: 4),
      );
      expect(
        draft.remainingAt(draft.startedAt.add(const Duration(minutes: 1))),
        const Duration(minutes: 3),
      );

      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('history'),
          home: TestHistoryPage(store: reopened),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resume exam · SQL'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Question 2 of 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('an expired saved exam is submitted once on reopening', (
    tester,
  ) async {
    final store = await AppStore.create();
    final start = DateTime.now().subtract(const Duration(minutes: 5));
    final draft = ExamDraft(
      id: 'expired-exam',
      subject: 'SQL',
      startedAt: start,
      deadline: start.add(const Duration(minutes: 4)),
      questions: questions,
      version: assessmentVersion(questions),
      answers: {questions.first.id: questions.first.answerIndex},
      marked: {},
      index: 1,
    );
    await store.saveExamDraft(draft, store.currentUserId!);
    await tester.pumpWidget(MaterialApp(home: TestHistoryPage(store: store)));
    await tester.tap(find.text('Resume exam · SQL'));
    await tester.pumpAndSettle();
    expect(find.text('Test results'), findsOneWidget);
    expect(store.attempts.single.percentage, 50);
    expect(store.attempts.single.completedAt, draft.deadline);
    expect(store.examDrafts, isEmpty);
  });

  testWidgets('practice stays active after its former time limit', (
    tester,
  ) async {
    final store = await AppStore.create();
    await tester.pumpWidget(
      MaterialApp(
        home: MockTestPage(
          subject: 'SQL',
          questions: questions.take(1).toList(),
          store: store,
          mode: TestMode.practice,
        ),
      ),
    );
    await tester.pump(const Duration(minutes: 3));
    expect(find.text('Untimed practice'), findsOneWidget);
    expect(find.byType(MockTestPage), findsOneWidget);
    expect(store.attempts, isEmpty);
  });
}
