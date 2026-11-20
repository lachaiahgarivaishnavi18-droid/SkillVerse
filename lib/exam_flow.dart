part of 'main.dart';

Future<bool> _confirmTestExit(
  BuildContext context, {
  required bool canResume,
}) async {
  return await showDialog<bool>(
        context: context,
        animationStyle: _sheetMotion(context),
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(canResume ? 'Leave this exam?' : 'Leave this test?'),
          content: Text(
            canResume
                ? 'Your answers will stay on this device. The deadline still applies.'
                : 'Your answers on this screen will be lost.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep working'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(canResume ? 'Save and leave' : 'Leave test'),
            ),
          ],
        ),
      ) ==
      true;
}

class _SavedExamTile extends StatelessWidget {
  const _SavedExamTile({
    required this.draft,
    required this.store,
    this.onChanged,
  });

  final ExamDraft draft;
  final AppStore store;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      title: Text('Resume exam · ${draft.subject}'),
      subtitle: Text(
        draft.remainingAt(DateTime.now()) == Duration.zero
            ? 'Deadline passed · Review your result'
            : '${draft.answers.length} of ${draft.questions.length} answered',
      ),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _resumeExam(draft, store)),
        );
        onChanged?.call();
      },
      trailing: IconButton(
        tooltip: 'Discard saved exam',
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          final accepted = await showDialog<bool>(
            context: context,
            animationStyle: _sheetMotion(context),
            builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Discard saved exam?'),
              content: const Text(
                'Your unfinished answers will be removed from this device.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep exam'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard exam'),
                ),
              ],
            ),
          );
          if (accepted != true || !context.mounted) return;
          try {
            await store.discardExamDraft(draft);
            onChanged?.call();
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not discard the saved exam.'),
                ),
              );
            }
          }
        },
      ),
    ),
  );
}

MockTestPage _resumeExam(ExamDraft draft, AppStore store) => MockTestPage(
  subject: draft.subject,
  questions: draft.questions,
  store: store,
  mode: TestMode.exam,
  courseId: draft.courseId,
  draft: draft,
);

List<QuizQuestion> _selectTestQuestions(
  List<QuizQuestion> available,
  int count,
) {
  final shuffled = List<QuizQuestion>.of(available)..shuffle();
  final preferred = <QuizQuestion>[];
  final fallback = <QuizQuestion>[];
  final seenConcepts = <String>{};
  for (final question in shuffled) {
    final id = question.id;
    if (!id.startsWith('bank-') ||
        seenConcepts.add(id.substring(0, id.lastIndexOf('-')))) {
      preferred.add(question);
    } else {
      fallback.add(question);
    }
  }
  // Surface the authored scenarios before legacy definition variants.
  return [
    ...preferred.where((q) => q.id.startsWith('case-v1-')),
    ...preferred.where((q) => !q.id.startsWith('case-v1-')),
    ...fallback,
  ].take(count).toList()..shuffle();
}
