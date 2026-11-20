part of 'main.dart';

void _openSingleQuestionPractice(
  BuildContext context,
  AppStore store,
  InterviewQuestion question,
) {
  final track = 'Question:${question.id}';
  _push(
    context,
    MockInterviewPage(
      store: store,
      category: question.category,
      mode: question.difficulty,
      track: track,
      timed: false,
      questions: [question],
      resume: store.interviewDraft(
        question.category,
        question.difficulty,
        track,
        timed: false,
      ),
    ),
  );
}

class _InterviewBookmark extends StatelessWidget {
  const _InterviewBookmark({required this.store, required this.question});

  final AppStore store;
  final InterviewQuestion question;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final saved = store.bookmarks.contains(question.id);
      return IconButton(
        tooltip: saved ? 'Remove bookmark' : 'Save question',
        icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
        onPressed: () async {
          try {
            await store.toggleBookmark(question.id);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not update bookmark. Try again.'),
                ),
              );
            }
          }
        },
      );
    },
  );
}

class _InterviewReference extends StatelessWidget {
  const _InterviewReference({
    required this.question,
    this.heading = 'Reference answer',
  });

  final InterviewQuestion question;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final concepts = interviewConceptsFor(question);
    final authoredRole = roleInterviewById.containsKey(question.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: heading),
        const SizedBox(height: 8),
        const _SectionHeading(title: 'Key points'),
        for (final point in interviewKeyPoints(question))
          SelectableText('• $point'),
        const SizedBox(height: 12),
        const _SectionHeading(title: 'Don’t miss'),
        if (concepts.isNotEmpty)
          Text(concepts.map((concept) => concept.label).join(' · ')),
        if (!authoredRole) SelectableText(question.explanation),
        if (question.example != null || question.code != null) ...[
          const SizedBox(height: 12),
          const _SectionHeading(title: 'Practical example'),
          if (question.example != null) SelectableText(question.example!),
          if (question.code != null) _CodeBlock(text: question.code!),
          if (question.output != null)
            Text('Expected result ${question.output}'),
        ],
        const SizedBox(height: 12),
        const _SectionHeading(title: 'Follow-up question'),
        SelectableText(interviewFollowUp(question)),
      ],
    );
  }
}

class _KeywordGuidanceCard extends StatelessWidget {
  const _KeywordGuidanceCard({required this.question, required this.answer});

  final InterviewQuestion question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final guidance = interviewGuidance(question, answer);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeading(title: 'Keyword guidance'),
            const Text(interviewGuidanceNotice),
            if (guidance.mentioned.isEmpty && guidance.missing.isEmpty)
              const Text('Use the reference points to review this answer.')
            else ...[
              const SizedBox(height: 8),
              if (guidance.mentioned.isNotEmpty)
                Text('Mentioned · ${guidance.mentioned.join(', ')}'),
              if (guidance.missing.isNotEmpty)
                Text('Worth adding · ${guidance.missing.join(', ')}')
              else
                const Text('All checklist concepts were mentioned.'),
            ],
          ],
        ),
      ),
    );
  }
}

class _InterviewAnswerComparison extends StatelessWidget {
  const _InterviewAnswerComparison({
    required this.previous,
    required this.current,
  });

  final String previous;
  final String current;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: const Text('Compare answers'),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text('Previous answer', style: Theme.of(context).textTheme.titleSmall),
        SelectableText(previous),
        const SizedBox(height: 12),
        Text('New answer', style: Theme.of(context).textTheme.titleSmall),
        SelectableText(current),
      ],
    ),
  );
}

class _InterviewStudyPlan extends StatelessWidget {
  const _InterviewStudyPlan({required this.store, required this.attempt});
  final AppStore store;
  final InterviewAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final cleanTopics = <String>{};
    final missingByTopic = <String, Set<String>>{};
    final reviewIds = <String>[];
    var skipped = 0;
    var checked = 0;
    for (final id in attempt.questionIds) {
      final question = _interviewById[id];
      if (question == null) continue;
      final response = attempt.responses[id];
      if (response == null || response.text.trim().isEmpty) {
        skipped++;
        continue;
      }
      final guidance = interviewGuidance(question, response.text);
      if (guidance.mentioned.isNotEmpty || guidance.missing.isNotEmpty) {
        checked++;
      }
      if (guidance.missing.isNotEmpty) {
        missingByTopic
            .putIfAbsent(question.topic, () => {})
            .addAll(guidance.missing);
        reviewIds.add(id);
      } else if (guidance.mentioned.isNotEmpty) {
        cleanTopics.add(question.topic);
      }
    }
    final weakTopics = missingByTopic.keys.toList()
      ..sort(
        (a, b) =>
            missingByTopic[b]!.length.compareTo(missingByTopic[a]!.length),
      );
    final strengths = cleanTopics.difference(missingByTopic.keys.toSet());
    final missed = {for (final topic in weakTopics) ...missingByTopic[topic]!};
    final priority = weakTopics.take(3).toSet();
    final planIds = reviewIds
        .where((id) => priority.contains(_interviewById[id]?.topic))
        .take(6)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const _SectionHeading(title: 'Study summary'),
        const Text(interviewGuidanceNotice),
        const SizedBox(height: 10),
        Text(
          checked == 0
              ? 'Strengths · Answer a question with a checklist to see concept coverage.'
              : strengths.isEmpty
              ? 'Strengths · No topic had complete checklist coverage in the answers checked.'
              : 'Strengths · ${strengths.take(4).join(', ')}',
        ),
        Text(
          checked == 0
              ? 'Weak topics · No checklist answers available to compare.'
              : weakTopics.isEmpty
              ? 'Weak topics · No missing concepts found in the answers checked.'
              : 'Weak topics · ${weakTopics.take(4).join(', ')}',
        ),
        if (missed.isNotEmpty)
          Text('Missed concepts · ${missed.take(12).join(', ')}'),
        if (skipped > 0) Text('Unanswered · $skipped'),
        const SizedBox(height: 10),
        const _SectionHeading(title: 'Suggested study plan'),
        Text(
          weakTopics.isNotEmpty
              ? 'Review ${priority.join(', ')} first. Redo the queued questions, cover the missed concepts, and try each follow-up aloud.'
              : skipped > 0
              ? 'Return to the unanswered questions and use their reference points to prepare a short response.'
              : 'Try a follow-up or another difficulty to check how well the concepts transfer.',
        ),
        if (planIds.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await store.addInterviewBookmarks(planIds);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Review questions added to the Study Queue.',
                      ),
                    ),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not update the Study Queue.'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Queue review questions'),
          ),
      ],
    );
  }
}
