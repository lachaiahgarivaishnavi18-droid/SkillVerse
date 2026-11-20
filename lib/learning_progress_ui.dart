part of 'main.dart';

class _WeeklyGoalCard extends StatelessWidget {
  const _WeeklyGoalCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final target = store.weeklyLearningGoal;
    final count = store.weeklyActivityCount(DateTime.now());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _SectionHeading(title: 'Weekly learning goal'),
                ),
                TextButton(
                  onPressed: () => _editWeeklyGoal(context, store),
                  child: Text(target == null ? 'Set goal' : 'Edit goal'),
                ),
              ],
            ),
            Text(
              target == null
                  ? '$count activities completed this week'
                  : '$count of $target activities this week${count >= target ? ' · Goal reached' : ''}',
            ),
            if (target != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: (count / target).clamp(0.0, 1.0)),
            ],
            const SizedBox(height: 6),
            const Text(
              'Counts lessons, practice sessions, quizzes, assessments, and interviews from Monday.',
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editWeeklyGoal(BuildContext context, AppStore store) async {
  var input = store.weeklyLearningGoal?.toString() ?? '';
  final form = GlobalKey<FormState>();
  final action = await showDialog<int>(
    context: context,
    animationStyle: _sheetMotion(context),
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Weekly learning goal'),
      content: Form(
        key: form,
        child: TextFormField(
          initialValue: input,
          onChanged: (value) => input = value,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Activities per week'),
          validator: (text) {
            final number = int.tryParse(text?.trim() ?? '');
            return number == null || number < 1 || number > 100
                ? 'Enter a number from 1 to 100.'
                : null;
          },
        ),
      ),
      actions: [
        if (store.weeklyLearningGoal != null)
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Remove goal'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, int.parse(input.trim()));
            }
          },
          child: const Text('Save goal'),
        ),
      ],
    ),
  );
  if (action == null || !context.mounted) return;
  try {
    await store.setWeeklyLearningGoal(action == 0 ? null : action);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the weekly goal.')),
      );
    }
  }
}

class _LearningActivityPage extends StatelessWidget {
  const _LearningActivityPage({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Activity history'),
      actions: [
        IconButton(
          tooltip: 'Export progress and activity',
          icon: const Icon(Icons.download_outlined),
          onPressed: () => _exportLearningProgress(context, store),
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.learningActivity;
        if (items.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            title: 'No learning activity yet',
            subtitle: 'Complete a lesson, quiz, practice session, or mock interview to start your history.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text(item.title),
                subtitle: Text(
                  [
                    item.kind,
                    _activityDate(context, item.date),
                    ?item.detail,
                  ].join(' · '),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

String _activityDate(BuildContext context, DateTime? date) {
  if (date == null) return 'Date unavailable';
  final local = date.toLocal();
  return '${MaterialLocalizations.of(context).formatMediumDate(local)} · ${TimeOfDay.fromDateTime(local).format(context)}';
}

Future<void> _exportLearningProgress(
  BuildContext context,
  AppStore store,
) async {
  final now = DateTime.now();
  final report = StringBuffer('Skillverse learning report\n')
    ..writeln('Exported ${_activityDate(context, now)}')
    ..writeln()
    ..writeln('Course and module progress');
  final completedCourses = store.passedCourseAssessments;
  final completed = store.completedLessons;
  for (final course in courses) {
    final progress = store.lessonProgress(
      course.allLessons,
      completedIds: completed,
    );
    final assessment = course.finalQuestions.isEmpty
        ? ''
        : completedCourses.contains(course.id)
        ? ' · Final assessment passed'
        : ' · Final assessment pending';
    report.writeln(
      '${course.title} — ${progress.completed} of ${progress.total} lessons$assessment',
    );
    for (final module in course.learningModules) {
      final moduleProgress = store.lessonProgress(
        module.lessons,
        completedIds: completed,
      );
      report.writeln(
        '  ${module.title} — ${moduleProgress.completed} of ${moduleProgress.total} lessons',
      );
    }
  }
  report
    ..writeln()
    ..writeln('Activity history');
  final activity = store.learningActivity;
  if (activity.isEmpty) report.writeln('No learning activity recorded.');
  for (final entry in activity) {
    report.writeln(
      [
        _activityDate(context, entry.date),
        entry.kind,
        entry.title,
        ?entry.detail,
      ].join(' · '),
    );
  }

  try {
    final filename =
        'skillverse-learning-${now.toIso8601String().split('T').first}.txt';
    if (_usesAndroidServices) {
      final saved = await const MethodChannel('skillverse/lesson_files')
          .invokeMethod<String>('saveText', {
            'filename': filename,
            'bytes': Uint8List.fromList(utf8.encode(report.toString())),
          });
      if (saved == null) return;
    } else {
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/skillverse-learning-${now.microsecondsSinceEpoch}.txt',
      );
      await file.writeAsString(report.toString(), flush: true);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Learning report saved.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export your learning report.')),
      );
    }
  }
}

Future<void> _confirmCourseReset(
  BuildContext context,
  AppStore store,
  Course course,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    animationStyle: _sheetMotion(context),
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('Reset course progress?'),
      content: Text(
        'Restart ${course.title} from its first lesson. The final assessment will lock again. Your past activity, results, and earned certificates remain available.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Reset this course'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await store.resetCourseProgress(course);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${course.title} progress reset.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not reset course progress.')),
      );
    }
  }
}

Iterable<(QuizQuestion, int?)> _attemptAnswers(
  Iterable<TestAttempt> attempts,
) sync* {
  for (final attempt in attempts) {
    for (final question in attempt.reviewQuestions) {
      yield (question, attempt.selections[question.id]);
    }
  }
}

List<QuizQuestion> _missedQuestions(Iterable<TestAttempt> attempts) {
  final seen = <String>{};
  return [
    for (final (question, selected) in _attemptAnswers(attempts))
      if (seen.add(question.id) && selected != question.answerIndex) question,
  ];
}

class _TopicResults extends StatelessWidget {
  const _TopicResults({required this.results});

  final Map<String, TopicResult> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: const Text('Results by topic'),
      children: [
        for (final entry in results.entries)
          ListTile(
            title: Text(entry.key),
            subtitle: Text(
              '${entry.value.correct} correct · ${entry.value.incorrect} incorrect · ${entry.value.unanswered} unanswered',
            ),
            trailing: Text(
              entry.value.correct + entry.value.incorrect == 0
                  ? 'No answers'
                  : '${(100 * entry.value.correct / (entry.value.correct + entry.value.incorrect)).round()}% accuracy',
            ),
          ),
      ],
    );
  }
}

void _practiceMissed(
  BuildContext context,
  AppStore store,
  List<QuizQuestion> questions,
) {
  _push(
    context,
    MockTestPage(
      subject: 'Missed concepts',
      questions: questions.take(20).toList(),
      store: store,
      mode: TestMode.practice,
    ),
  );
}

class _ResultNextStep extends StatelessWidget {
  const _ResultNextStep({required this.store, required this.attempt});

  final AppStore store;
  final TestAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final missed = _missedQuestions([attempt]);
    final course = courses
        .where(
          (course) =>
              course.id == attempt.courseId ||
              course.quizSubject == attempt.subject,
        )
        .firstOrNull;
    final nextLesson = course == null ? null : store.continueLesson(course);
    final (
      String message,
      String label,
      VoidCallback action,
    ) = missed.isNotEmpty
        ? (
            'Retry up to ${math.min(20, missed.length)} missed or unanswered questions from this result.',
            'Practice Missed Concepts',
            () => _practiceMissed(context, store, missed),
          )
        : nextLesson != null
        ? (
            'Continue with ${nextLesson.title}.',
            'Continue learning',
            () => _openCourseLesson(context, store, course!, nextLesson),
          )
        : attempt.courseId != null && course != null
        ? (
            'Review your course completion and assessment options.',
            'View course progress',
            () =>
                _push(context, CourseDetailPage(course: course, store: store)),
          )
        : (
            'Try another set to check your understanding.',
            'Choose another test',
            () => _push(
              context,
              attempt.subject == 'Missed concepts'
                  ? MockTestTopicsPage(store: store)
                  : TestSetupPage(subject: attempt.subject, store: store),
            ),
          );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(title: 'Next learning action'),
            const SizedBox(height: 6),
            Text(message),
            TextButton.icon(
              onPressed: action,
              icon: const Icon(Icons.arrow_forward),
              label: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleProgress extends StatelessWidget {
  const _ModuleProgress({required this.summary, required this.progress});

  final String summary;
  final ({int completed, int total}) progress;

  @override
  Widget build(BuildContext context) {
    final ratio = progress.total == 0
        ? 0.0
        : progress.completed / progress.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary),
        const SizedBox(height: 6),
        Text(
          '${progress.completed} of ${progress.total} lessons · ${(ratio * 100).round()}%',
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: ratio),
      ],
    );
  }
}
