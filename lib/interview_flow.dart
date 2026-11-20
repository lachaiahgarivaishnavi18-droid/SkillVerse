part of 'main.dart';

const _interviewModes = ['Beginner', 'Intermediate', 'Advanced'];
const _interviewTracks = ['Service-based', 'Product-based', 'Fresher'];
final _interviewById = {
  for (final question in interviewQuestions) question.id: question,
};

class MockInterviewTopicsPage extends StatefulWidget {
  const MockInterviewTopicsPage({
    super.key,
    required this.store,
    this.companyPractice = false,
  });

  final AppStore store;
  final bool companyPractice;

  @override
  State<MockInterviewTopicsPage> createState() =>
      _MockInterviewTopicsPageState();
}

class _MockInterviewTopicsPageState extends State<MockInterviewTopicsPage> {
  String _mode = 'Beginner';
  String _track = 'Service-based';
  bool _timed = true;

  String get _selectedDifficulty =>
      _trackForSession == 'Fresher' ? 'Beginner' : _mode;

  void _openCategory(String category, List<InterviewQuestion> pool) {
    final mode = _selectedDifficulty;
    final track = _trackForSession;
    final draft = widget.store.interviewDraft(
      category,
      mode,
      track,
      timed: _timed,
    );
    pool.shuffle();
    final remaining = {for (final question in pool) question.id: question};
    final restored = <InterviewQuestion>[
      for (final id in draft?.questionIds ?? const <String>[])
        ?remaining.remove(id),
    ];
    _push(
      context,
      MockInterviewPage(
        store: widget.store,
        category: category,
        mode: mode,
        track: track,
        resume: draft,
        timed: _timed,
        questions: [
          ...restored,
          ...remaining.values.where((q) => _matchesInterviewTrack(q, track)),
          ...remaining.values.where((q) => !_matchesInterviewTrack(q, track)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.companyPractice ? 'Company practice' : 'Mock interviews',
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.companyPractice) ...[
          const Text(
            'Each track reflects a role profile. Questions are practice material.',
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final track in _interviewTracks)
                ChoiceChip(
                  label: Text(track),
                  selected: _track == track,
                  onSelected: (_) => setState(() => _track = track),
                ),
            ],
          ),
          Text(switch (_track) {
            'Service-based' =>
              'Focus on client delivery, support and dependable execution.',
            'Product-based' =>
              'Focus on design trade-offs, scale and product outcomes.',
            _ => 'Focus on core concepts and first-project experience.',
          }),
          const SizedBox(height: 12),
        ],
        const _SectionHeading(title: 'Interview mode'),
        Wrap(
          spacing: 8,
          children: [
            for (final mode in _interviewModes)
              ChoiceChip(
                label: Text(mode),
                selected: _selectedDifficulty == mode,
                onSelected: _trackForSession == 'Fresher'
                    ? null
                    : (_) => setState(() => _mode = mode),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            for (final timed in [true, false])
              ChoiceChip(
                label: Text(timed ? 'Timed' : 'Untimed'),
                selected: _timed == timed,
                onSelected: (_) => setState(() => _timed = timed),
              ),
          ],
        ),
        if (!widget.companyPractice)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Role-based sets'),
            children: [
              for (final role in InterviewRole.values)
                _FeatureTile(
                  icon: Icons.work_outline,
                  title: role.label,
                  subtitle:
                      '${roleQuestionsFor(role, _selectedDifficulty).length} ${_selectedDifficulty.toLowerCase()} questions',
                  onTap: () => _openCategory(
                    role.label,
                    roleQuestionsFor(role, _selectedDifficulty),
                  ),
                ),
            ],
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Write an answer, compare it with the reference, then score it yourself. Timed practice shows elapsed time. Each session uses only the selected difficulty.',
          ),
        ),
        for (final category in interviewCategories)
          Builder(
            builder: (context) {
              final pool = _interviewQuestionsFor(
                category,
                _selectedDifficulty,
              );
              return _FeatureTile(
                icon: Icons.record_voice_over_outlined,
                title: category,
                subtitle: '${pool.length} questions',
                onTap: () {
                  if (pool.isNotEmpty) _openCategory(category, pool);
                },
              );
            },
          ),
      ],
    ),
  );

  String get _trackForSession => widget.companyPractice ? _track : 'Standard';
}

List<InterviewQuestion> _interviewQuestionsFor(
  String category,
  String difficulty,
) => interviewQuestions
    .where((q) => q.category == category && q.difficulty == difficulty)
    .toList();

bool _matchesInterviewTrack(InterviewQuestion question, String track) {
  final topic = question.topic.toLowerCase();
  return switch (track) {
    'Service-based' => RegExp(
      r'client|delivery|documentation|reliability|quality|governance|build|'
      r'rollout|rollback|maintenance|clean|reconcil|oversight|report|support',
    ).hasMatch(topic),
    'Product-based' => RegExp(
      r'design|performance|search|execution|memory|graph|forecast|'
      r'evaluation|threshold|metric|funnel|retention|attribution|strategy',
    ).hasMatch(topic),
    _ => true,
  };
}

class MockInterviewPage extends StatefulWidget {
  const MockInterviewPage({
    super.key,
    required this.store,
    required this.category,
    required this.mode,
    required this.track,
    required this.questions,
    this.resume,
    this.timed = true,
  });

  final AppStore store;
  final String category;
  final String mode;
  final String track;
  final List<InterviewQuestion> questions;
  final InterviewDraft? resume;
  final bool timed;

  @override
  State<MockInterviewPage> createState() => _MockInterviewPageState();
}

class _MockInterviewPageState extends State<MockInterviewPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _stopwatch = Stopwatch()..start();
  final _drafts = <String, String>{};
  final _responses = <String, InterviewResponse>{};
  final _previous = <String, String>{};
  final _priorSessions = <String, String>{};
  late final String? _owner;
  late final _id =
      widget.resume?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
  late final AppLifecycleListener _lifecycle;
  Timer? _draftTimer;
  bool _finished = false;
  int get _totalSeconds =>
      (widget.resume?.durationSeconds ?? 0) + _stopwatch.elapsed.inSeconds;
  Timer? _ticker;
  final _elapsed = ValueNotifier(0);
  int _index = 0;
  bool _saving = false;
  bool _confirmingFinish = false;

  InterviewQuestion get _question => widget.questions[_index];
  InterviewResponse? get _response => _responses[_question.id];

  @override
  void initState() {
    super.initState();
    // Capture the account at session start.
    _owner = widget.store.currentUserId;
    final questionIds = widget.questions.map((q) => q.id).toSet();
    for (final attempt in widget.store.interviewAttempts) {
      for (final entry in attempt.responses.entries) {
        if (questionIds.contains(entry.key) &&
            entry.value.text.trim().isNotEmpty) {
          _priorSessions.putIfAbsent(entry.key, () => entry.value.text);
        }
      }
    }
    final resume = widget.resume;
    if (resume != null) {
      _previous.addAll(resume.previousAnswers);
      final availableIds = widget.questions.map((q) => q.id).toSet();
      _drafts.addEntries(
        resume.answers.entries.where(
          (entry) => availableIds.contains(entry.key),
        ),
      );
      _responses.addEntries(
        resume.responses.entries.where(
          (entry) => availableIds.contains(entry.key),
        ),
      );
      if (resume.questionIndex >= 0 &&
          resume.questionIndex < resume.questionIds.length) {
        final currentId = resume.questionIds[resume.questionIndex];
        final restoredIndex = widget.questions.indexWhere(
          (q) => q.id == currentId,
        );
        if (restoredIndex != -1) _index = restoredIndex;
      }
      _controller.text = _response?.text ?? _drafts[_question.id] ?? '';
    }
    _elapsed.value = _totalSeconds;
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) _flushDraft();
      },
    );
    if (widget.timed) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        _elapsed.value = _totalSeconds;
      });
    }
  }

  @override
  void dispose() {
    _flushDraft();
    _lifecycle.dispose();
    _ticker?.cancel();
    _stopwatch.stop();
    _elapsed.dispose();
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      _drafts[_question.id] = _controller.text;
      _index = index;
      _controller.text = _response?.text ?? _drafts[_question.id] ?? '';
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _scheduleDraft();
  }

  void _redo(InterviewResponse response) {
    setState(() {
      _previous[_question.id] = response.text;
      _responses.remove(_question.id);
      _drafts.remove(_question.id);
      _controller.clear();
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _flushDraft();
  }

  String? _previousAnswer(String id) => _previous[id] ?? _priorSessions[id];

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 350), _flushDraft);
  }

  void _flushDraft() => unawaited(
    _saveDraft().catchError((Object _) {
      // A later edit or an explicit exit can retry the checkpoint.
    }),
  );

  Future<void> _saveDraft() async {
    _draftTimer?.cancel();
    if (_finished || _saving || _owner == null) return;
    final answers = Map<String, String>.of(_drafts);
    if (_response == null) answers[_question.id] = _controller.text;
    answers.removeWhere((_, value) => value.trim().isEmpty);
    if (answers.isEmpty &&
        _responses.isEmpty &&
        _previous.isEmpty &&
        _index == 0 &&
        widget.resume == null) {
      return;
    }
    final draft = InterviewDraft(
      id: _id,
      questionIds: widget.questions.map((q) => q.id).toList(),
      questionIndex: _index,
      durationSeconds: _totalSeconds,
      answers: answers,
      responses: Map.of(_responses),
      previousAnswers: Map.of(_previous),
    );
    await widget.store.saveInterviewDraft(
      _owner,
      widget.category,
      widget.mode,
      widget.track,
      draft,
      timed: widget.timed,
    );
  }

  Future<void> _finish() async {
    if (_saving || _confirmingFinish || _finished) return;
    _confirmingFinish = true;
    final unscored =
        widget.questions.length -
        _responses.values.where((r) => r.correct != null).length;
    final accepted = await showDialog<bool>(
      context: context,
      animationStyle: _sheetMotion(context),
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Finish interview?'),
        content: Text(
          unscored == 0
              ? 'Save your results to your interview history.'
              : '$unscored questions have no self-rating. They will be saved as unscored.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep practicing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Finish and save'),
          ),
        ],
      ),
    );
    _confirmingFinish = false;
    if (!mounted || accepted != true) return;
    _drafts[_question.id] = _controller.text;
    _draftTimer?.cancel();
    setState(() => _saving = true);
    _stopwatch.stop();
    final attempt = InterviewAttempt(
      id: _id,
      category: widget.category,
      mode: widget.mode,
      track: widget.track,
      completedAt: DateTime.now(),
      durationSeconds: _totalSeconds,
      timed: widget.timed,
      questionIds: widget.questions.map((q) => q.id).toList(),
      responses: {
        ..._responses,
        for (final entry in _drafts.entries)
          if (!_responses.containsKey(entry.key) &&
              entry.value.trim().isNotEmpty)
            entry.key: InterviewResponse(
              entry.value,
              null,
              previousText: _previousAnswer(entry.key),
            ),
      },
    );
    try {
      final owner = _owner;
      if (owner == null) throw StateError('Sign in to save interviews.');
      await widget.store.saveInterviewAttempt(attempt, owner);
      _finished = true;
    } catch (_) {
      if (!mounted) return;
      _stopwatch.start();
      setState(() => _saving = false);
      _scheduleDraft();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save this interview. Try again.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            InterviewSummaryPage(store: widget.store, attempt: attempt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _question;
    final response = _response;
    final timer = widget.timed
        ? ValueListenableBuilder(
            valueListenable: _elapsed,
            builder: (context, seconds, _) => Text(
              _largeText(context)
                  ? 'Elapsed time ${_formatDuration(seconds)}'
                  : _formatDuration(seconds),
              semanticsLabel: 'Elapsed time ${_formatDuration(seconds)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          )
        : const Text('Untimed');
    return _GuardUnsaved(
      busy: _saving,
      dirty:
          !_finished &&
          (_index != 0 ||
              _drafts.isNotEmpty ||
              _responses.isNotEmpty ||
              _controller.text.trim().isNotEmpty ||
              widget.resume != null),
      beforeLeave: _saveDraft,
      leaveLabel: 'Save and leave',
      message: 'Your draft will be saved on this device. You can resume this interview later.',
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.category),
          actions: [
            _InterviewBookmark(store: widget.store, question: question),
            _ReportContentButton(question.id),
            if (!_largeText(context))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: timer),
              ),
          ],
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          children: [
            if (_largeText(context)) timer,
            LinearProgressIndicator(
              semanticsLabel: 'Interview question progress',
              value: (_index + 1) / widget.questions.length,
            ),
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                'Question ${_index + 1} of ${widget.questions.length} · ${question.difficulty}',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              question.question,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (question.code != null &&
                (question.id.startsWith('worked-') ||
                    question.id.startsWith('applied-')))
              _CodeBlock(text: question.code!),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              onChanged: (_) {
                setState(() {});
                _scheduleDraft();
              },
              readOnly: response != null || _saving,
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Your answer',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            if (response == null)
              ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, value, _) => FilledButton(
                  onPressed: _saving || value.text.trim().isEmpty
                      ? null
                      : () {
                          FocusScope.of(context).unfocus();
                          setState(
                            () => _responses[question.id] = InterviewResponse(
                              value.text.trim(),
                              null,
                              previousText: _previousAnswer(question.id),
                            ),
                          );
                          _scheduleDraft();
                        },
                  child: const Text('Submit answer'),
                ),
              )
            else ...[
              _KeywordGuidanceCard(question: question, answer: response.text),
              const SizedBox(height: 12),
              _InterviewReference(question: question),
              if (response.previousText case final previous?)
                _InterviewAnswerComparison(
                  previous: previous,
                  current: response.text,
                ),
              OutlinedButton.icon(
                onPressed: _saving ? null : () => _redo(response),
                icon: const Icon(Icons.replay),
                label: const Text('Redo question'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Compare your reasoning and result with the reference. For HR questions, check whether your own example demonstrates the same qualities.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final correct in [true, false])
                    ChoiceChip(
                      label: Text(correct ? 'Correct' : 'Needs improvement'),
                      selected: response.correct == correct,
                      onSelected: _saving
                          ? null
                          : (_) {
                              setState(
                                () =>
                                    _responses[question.id] = InterviewResponse(
                                      response.text,
                                      correct,
                                      previousText: response.previousText,
                                    ),
                              );
                              _scheduleDraft();
                            },
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: _saving || _index == 0
                      ? null
                      : () => _go(_index - 1),
                  child: const Text('Previous'),
                ),
                OutlinedButton(
                  onPressed: _saving || _index + 1 == widget.questions.length
                      ? null
                      : () => _go(_index + 1),
                  child: const Text('Next'),
                ),
                FilledButton(
                  onPressed: _saving ? null : _finish,
                  child: Text(_saving ? 'Saving…' : 'Finish interview'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InterviewSummaryPage extends StatelessWidget {
  const InterviewSummaryPage({
    super.key,
    required this.store,
    required this.attempt,
  });

  final AppStore store;
  final InterviewAttempt attempt;

  @override
  Widget build(BuildContext context) {
    final role = InterviewRole.values
        .where((role) => role.label == attempt.category)
        .firstOrNull;
    final compatible = [
      for (final id in attempt.questionIds)
        if (_interviewById[id] case final question?
            when (role == null
                    ? question.category == attempt.category
                    : roleInterviewById[id]?.role == role) &&
                question.difficulty == attempt.mode)
          question,
    ];
    final questions = compatible.length == attempt.questionIds.length
        ? compatible
        : role == null
        ? _interviewQuestionsFor(attempt.category, attempt.mode)
        : roleQuestionsFor(role, attempt.mode);
    return Scaffold(
      appBar: AppBar(title: const Text('Interview summary')),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: attempt.questionIds.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeading(title: '${attempt.category} · ${attempt.mode}'),
                Text(
                  attempt.correct + attempt.incorrect == 0
                      ? 'No self-ratings yet'
                      : '${attempt.score}% self-assessed score',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  '${attempt.correct} correct · ${attempt.incorrect} incorrect · ${attempt.unanswered} unscored',
                ),
                Text(
                  attempt.timed
                      ? 'Elapsed time ${_formatDuration(attempt.durationSeconds)}'
                      : 'Untimed practice',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: questions.isEmpty
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => MockInterviewPage(
                              store: store,
                              category: attempt.category,
                              mode: attempt.mode,
                              track: attempt.track,
                              timed: attempt.timed,
                              questions: questions,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.replay),
                  label: const Text('Retry interview'),
                ),
                _InterviewStudyPlan(store: store, attempt: attempt),
              ],
            );
          }
          final id = attempt.questionIds[index - 1];
          final question = _interviewById[id];
          final response = attempt.responses[id];
          final status = switch (response?.correct) {
            true => 'Correct',
            false => 'Incorrect',
            null => 'Unscored',
          };
          return Card(
            child: ExpansionTile(
              title: Text(question?.question ?? 'Question $index'),
              subtitle: Text(status),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionHeading(title: 'Your answer'),
                SelectableText(response?.text ?? 'No answer recorded'),
                const SizedBox(height: 10),
                if (question != null) ...[
                  _InterviewReference(question: question),
                  if (response != null)
                    _KeywordGuidanceCard(
                      question: question,
                      answer: response.text,
                    ),
                  if (response?.previousText case final previous?)
                    _InterviewAnswerComparison(
                      previous: previous,
                      current: response!.text,
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.replay),
                    label: const Text('Redo question'),
                    onPressed: () =>
                        _openSingleQuestionPractice(context, store, question),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class InterviewHistoryPage extends StatelessWidget {
  const InterviewHistoryPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Interview history and progress')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final attempts = store.interviewAttempts;
        final reviewed = store.reviewedInterviewQuestions;
        final practiced = {
          ...reviewed,
          for (final attempt in attempts)
            for (final entry in attempt.responses.entries)
              if (entry.value.correct != null) entry.key,
        };
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: attempts.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeading(title: 'Question coverage'),
                  Text(
                    '${practiced.where(_interviewById.containsKey).length} of ${interviewQuestions.length} reviewed or scored',
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        practiced.where(_interviewById.containsKey).length /
                        interviewQuestions.length,
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    title: const Text('Coverage by category'),
                    children: [
                      for (final category in interviewCategories)
                        ListTile(
                          title: Text(category),
                          trailing: Text(
                            '${practiced.where((id) => _interviewById[id]?.category == category).length} / ${interviewQuestions.where((q) => q.category == category).length}',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _SectionHeading(title: 'Completed interviews'),
                  if (attempts.isEmpty)
                    const Text('Completed sessions will appear here.'),
                ],
              );
            }
            final attempt = attempts[index - 1];
            final date = MaterialLocalizations.of(context)
                .formatMediumDate(attempt.completedAt.toLocal());
            return _FeatureTile(
              title: attempt.correct + attempt.incorrect == 0
                  ? '${attempt.category} · Unscored'
                  : '${attempt.category} · ${attempt.score}%',
              subtitle: '${attempt.mode} · ${attempt.track} · $date',
              icon: Icons.history,
              onTap: () => _push(
                context,
                InterviewSummaryPage(store: store, attempt: attempt),
              ),
            );
          },
        );
      },
    ),
  );
}
