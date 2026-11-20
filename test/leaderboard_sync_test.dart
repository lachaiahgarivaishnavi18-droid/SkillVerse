import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/interview_attempt.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:learning_app/main.dart';
import 'package:material_ui/material_ui.dart';
import 'package:learning_app/services/skillverse_cloud.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'leaderboard submissions survive offline restart and stay account-scoped',
    () async {
      SharedPreferences.setMockInitialValues({});
      final firstBackend = await _Backend.withSession('first');
      final firstStore = await AppStore.create(cloud: firstBackend);
      firstBackend.offline = true;
      final now = DateTime.now();
      await firstStore.saveAttempt(
        TestAttempt(
          id: 'attempt',
          subject: 'Python',
          completedAt: now,
          selections: {'quiz-id': 2, 'outside-attempt': 0},
          questionIds: ['quiz-id', 'unanswered'],
          durationSeconds: 10,
        ),
      );
      await firstStore.saveInterviewAttempt(
        InterviewAttempt(
          id: 'interview',
          category: 'Python',
          mode: 'Beginner',
          track: '',
          completedAt: now,
          durationSeconds: 10,
          questionIds: ['reviewed', 'unreviewed', 'blank'],
          responses: {
            'reviewed': const InterviewResponse('private response', false),
            'unreviewed': const InterviewResponse('not reviewed', null),
            'blank': const InterviewResponse(' ', true),
          },
        ),
        'first',
      );
      await firstStore.saveModuleQuizPoints({'module-id': 1});
      await expectLater(firstStore.syncLeaderboardResults(), throwsStateError);
      firstStore.dispose();
      await firstBackend.client.dispose();

      final otherBackend = await _Backend.withSession('other');
      final otherStore = await AppStore.create(cloud: otherBackend);
      await otherStore.syncLeaderboardResults();
      expect(otherBackend.submissions, isEmpty);
      otherStore.dispose();
      await otherBackend.client.dispose();

      final backend = await _Backend.withSession('first');
      final store = await AppStore.create(cloud: backend);
      await store.syncLeaderboardResults();
      expect(
        backend.submissions.map((result) => [result.$1, result.$2, result.$3]),
        unorderedEquals([
          [
            'first',
            'quiz',
            {'quiz-id': 2},
          ],
          [
            'first',
            'quiz',
            {'module-id': 1},
          ],
          [
            'first',
            'mock_interview',
            {'reviewed': true},
          ],
        ]),
      );
      await store.syncLeaderboardResults();
      expect(backend.submissions, hasLength(3));
      store.dispose();
      await backend.client.dispose();
    },
  );

  testWidgets(
    'ranking reads survive a failed upload and retry keeps the outbox',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = (await tester.runAsync(
        () => _Backend.withSession('first'),
      ))!;
      final store = await AppStore.create(cloud: backend);
      backend.offline = true;
      backend.rankingsOffline = true;
      await store.saveModuleQuizPoints({'module-id': 1});
      await tester.pumpWidget(MaterialApp(home: LeaderboardPage(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('Could not load rankings.'), findsOneWidget);
      expect(find.textContaining(' pts'), findsNothing);

      backend.rankingsOffline = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Live rankings'), findsOneWidget);
      expect(
        find.text('Some saved results are waiting to sync.'),
        findsOneWidget,
      );
      expect(find.text('You · #2'), findsOneWidget);
      expect(find.text('4 pts'), findsOneWidget);
      expect(backend.submissions, isEmpty);
      expect(backend.periods, ['global', 'global']);

      backend.offline = false;
      await tester.tap(find.byTooltip('Retry syncing saved results'));
      await tester.pumpAndSettle();
      expect(
        find.text('Some saved results are waiting to sync.'),
        findsNothing,
      );
      expect(backend.submissions.single.$3, {'module-id': 1});
      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      expect(backend.periods.last, 'weekly');
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(backend.periods.last, 'monthly');
      expect(backend.submissions, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
      await tester.pump();
      await tester.runAsync(backend.client.dispose);
    },
  );
}

class _Backend implements SkillverseCloud {
  _Backend(this.client);

  @override
  final SupabaseClient client;
  bool offline = false;
  bool rankingsOffline = false;
  final periods = <String>[];

  @override
  Future<List<LeaderboardEntry>> leaderboard(String period) async {
    periods.add(period);
    if (rankingsOffline) throw StateError('offline');
    return const [
      LeaderboardEntry(name: 'Test account', points: 4, rank: 2, isYou: true),
    ];
  }

  final submissions = <(String, String, Map<String, dynamic>)>[];

  static Future<_Backend> withSession(String id) async {
    final backend = _Backend(
      SupabaseClient(
        'https://example.invalid',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    await backend.client.auth.setInitialSession(
      jsonEncode({
        'access_token': 'test-token',
        'token_type': 'bearer',
        'user': {'id': id, 'email': '$id@example.invalid'},
      }),
    );
    return backend;
  }

  @override
  Future<void> submitResult(
    String ownerId,
    String source,
    Map<String, dynamic> answers,
  ) async {
    if (offline) throw StateError('offline');
    submissions.add((ownerId, source, answers));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
