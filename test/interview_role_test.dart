import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/interview_guidance.dart';
import 'package:learning_app/data/interview_roles.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_accounts': '[{"fullName":"Interview Learner","email":"interview@example.com","passwordHash":"local-fixture"}]',
      'auth_current_email': 'interview@example.com',
      'auth_session_active': true,
    });
  });

  test(
    'curated role sets have original prompts and checked concept phrases',
    () {
      final ids = <String>{};
      final prompts = <String>{};
      for (final entry in roleInterviewQuestions) {
        expect(ids.add(entry.question.id), isTrue);
        expect(prompts.add(entry.question.question), isTrue);
        expect(entry.question.answer, isNotEmpty);
        expect(entry.question.example, isNotEmpty);
        expect(entry.followUp, isNotEmpty);
        expect(entry.concepts.length, greaterThanOrEqualTo(3));
      }
      for (final role in InterviewRole.values) {
        for (final level in ['Beginner', 'Intermediate', 'Advanced']) {
          expect(roleQuestionsFor(role, level), hasLength(2));
        }
      }
      final rare = roleInterviewById['role-v1-mle-rare-events']!.question;
      final feedback = interviewGuidance(
        rare,
        'The majority-class baseline is misleading. Report positive predictive value, sensitivity, and false positives.',
      );
      expect(feedback.mentioned, [
        'Baseline',
        'Precision',
        'Recall',
        'Confusion matrix',
      ]);
      expect(feedback.missing, isEmpty);
      final lookup = roleInterviewById['role-v1-python-event-lookup']!.question;
      expect(
        interviewGuidance(lookup, 'I will reset the list.').missing,
        contains('Set'),
      );
      expect(
        interviewGuidance(lookup, 'A hash-set supports lookup.').mentioned,
        containsAll(['Set', 'Membership']),
      );
    },
  );

  testWidgets(
    'untimed role practice compares a redo and saves study guidance',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = await AppStore.create();
      await tester.pumpWidget(
        MaterialApp(home: MockInterviewTopicsPage(store: store)),
      );
      await tester.tap(find.text('Untimed'));
      await tester.tap(find.text('Role-based sets'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Python Developer'));
      await tester.pumpAndSettle();
      final page = tester.widget<MockInterviewPage>(
        find.byType(MockInterviewPage),
      );
      expect(page.timed, isFalse);
      expect(page.questions, hasLength(2));
      expect(
        page.questions.every(
          (q) => roleInterviewById[q.id]?.role == InterviewRole.pythonDeveloper,
        ),
        isTrue,
      );
      final question = page.questions.first;
      expect(find.text('Untimed'), findsOneWidget);
      await tester.tap(find.byTooltip('Save question'));
      await tester.enterText(find.byType(TextField), 'Original explanation');
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Keyword guidance'),
        140,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Keyword guidance'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Follow-up question'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Follow-up question'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Redo question'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Redo question'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'A revised explanation with additional detail.',
      );
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Compare answers'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Compare answers'));
      await tester.pumpAndSettle();
      expect(find.text('Original explanation'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Finish interview'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Finish interview'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish and save'));
      await tester.pumpAndSettle();
      expect(find.text('Suggested study plan'), findsOneWidget);
      expect(find.textContaining('Missed concepts'), findsOneWidget);
      final reopened = await AppStore.create();
      expect(reopened.bookmarks, contains(question.id));
      final attempt = reopened.interviewAttempts.single;
      expect(attempt.timed, isFalse);
      expect(
        attempt.responses[question.id]?.previousText,
        'Original explanation',
      );
      expect(
        attempt.responses[question.id]?.text,
        'A revised explanation with additional detail.',
      );
      expect(attempt.responses[question.id]?.correct, isNull);
    },
  );

  testWidgets('study queue filters existing bookmarks by role and topic', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await AppStore.create();
    final python = roleInterviewById['role-v1-python-event-lookup']!.question;
    final ml = roleInterviewById['role-v1-mle-rare-events']!.question;
    await store.addInterviewBookmarks([python.id, ml.id]);
    await tester.pumpWidget(
      MaterialApp(home: InterviewQuestionsPage(store: store, savedOnly: true)),
    );
    await tester.tap(find.text('Role · All'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(PopupMenuItem<String>, 'Python Developer'),
    );
    await tester.pumpAndSettle();
    expect(find.text(python.question), findsOneWidget);
    expect(find.text(ml.question), findsNothing);
    await tester.tap(find.text('Topic · All'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PopupMenuItem<String>, python.topic));
    await tester.pumpAndSettle();
    expect(find.text('Topic · ${python.topic}'), findsOneWidget);
    expect(find.text('1 question'), findsOneWidget);
  });
}
