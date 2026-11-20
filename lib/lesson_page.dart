part of 'main.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({
    super.key,
    required this.lesson,
    required this.store,
    this.courseLessons = const [],
    this.preview = false,
  });

  final Lesson lesson;
  final AppStore store;
  final List<Lesson> courseLessons;
  final bool preview;

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  late final String? _account = widget.preview
      ? null
      : widget.store.currentUserId;
  late final ScrollController _scroll;
  late final AppLifecycleListener _lifecycle;
  Timer? _saveTimer;
  double? _pendingOffset;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    final account = _account;
    _scroll = ScrollController(
      initialScrollOffset: account == null
          ? 0
          : widget.store.lessonReadingOffset(widget.lesson.id),
      keepScrollOffset: false,
    )..addListener(_onScroll);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) unawaited(_savePosition());
      },
    );
    if (account != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || widget.store.currentUserId != account) return;
        try {
          await widget.store.recordLessonVisit(widget.lesson);
        } catch (_) {
          _showMessage('Could not save your resume point.');
        }
      });
    }
  }

  void _onScroll() {
    if (_account == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    _pendingOffset = position.pixels.clamp(0.0, position.maxScrollExtent);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _savePosition);
  }

  Future<void> _savePosition() async {
    _saveTimer?.cancel();
    final account = _account;
    final offset = _pendingOffset;
    if (account == null || offset == null) return;
    _pendingOffset = null;
    try {
      await widget.store.saveLessonReadingOffset(
        account,
        widget.lesson.id,
        offset,
      );
    } catch (_) {
      _pendingOffset ??= offset;
      _showMessage('Could not save your reading position.');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_savePosition());
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final owner = _account;
    if (owner == null || widget.store.currentUserId != owner) return;
    setState(() => _completing = true);
    try {
      await widget.store.markLessonComplete(widget.lesson.id);
      if (!mounted) return;
      var offerFeedback = false;
      try {
        offerFeedback = await widget.store.claimFirstLessonFeedback(
          owner,
          widget.lesson.id,
        );
      } catch (_) {
        // Completion is already saved even if this optional prompt cannot be recorded.
      }
      if (!mounted || widget.store.currentUserId != owner) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: const Text('Lesson marked complete.'),
          action: offerFeedback
              ? SnackBarAction(
                  label: 'Give feedback',
                  onPressed: () => _reportProblem(
                    context,
                    FeedbackKind.firstLesson,
                    contentId: widget.lesson.id,
                  ),
                )
              : null,
        ),
      );
    } catch (_) {
      _showMessage('Could not mark this lesson complete.');
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  void _openNeighbor(Lesson lesson) {
    unawaited(_savePosition());
    _push(
      context,
      LessonPage(
        lesson: lesson,
        store: widget.store,
        courseLessons: widget.courseLessons,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final guide = guideForLesson(lesson);
    final output = lessonExpectedOutput(lesson, guide);
    final index = widget.courseLessons.indexWhere(
      (item) => item.id == lesson.id,
    );
    final example = cleanLessonCode(guide.example ?? lesson.example);

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title),
        actions: [_ReportContentButton(lesson.id)],
      ),
      bottomNavigationBar: widget.preview
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: ListenableBuilder(
                  listenable: widget.store,
                  builder: (context, _) {
                    final completed = widget.store.completedLessons.contains(
                      lesson.id,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (index >= 0)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: index > 0
                                      ? () => _openNeighbor(
                                          widget.courseLessons[index - 1],
                                        )
                                      : null,
                                  child: const Text(
                                    'Previous lesson',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      index + 1 < widget.courseLessons.length
                                      ? () => _openNeighbor(
                                          widget.courseLessons[index + 1],
                                        )
                                      : null,
                                  child: const Text(
                                    'Next lesson',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        FilledButton.icon(
                          onPressed: completed || _completing
                              ? null
                              : _complete,
                          icon: const Icon(Icons.check),
                          label: Text(
                            completed
                                ? 'Lesson complete'
                                : 'Mark lesson complete',
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
      body: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_largeText(context)) _SectionHeading(title: lesson.title),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: Text(lesson.difficulty.label)),
            ),
            const _LessonSection(title: 'Learning objective'),
            Text(guide.objective),
            const _LessonSection(title: 'Explanation'),
            Text(lesson.summary, style: const TextStyle(fontSize: 16)),
            if (lesson.topics.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Topics', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 6,
                children: [
                  for (final topic in lesson.topics) Chip(label: Text(topic)),
                ],
              ),
            ],
            const _LessonSection(title: 'Example'),
            _LessonCopyBlock(text: example),
            if (guide.input case final String input) ...[
              const _LessonSection(title: 'Sample input'),
              SelectableText(input),
            ],
            if (output != null) ...[
              const _LessonSection(title: 'Expected output'),
              SelectableText(output),
            ],
            if (guide.resources.isNotEmpty) ...[
              const _LessonSection(title: 'Offline practice files'),
              for (final resource in guide.resources)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(resource.filename),
                  subtitle: Text(resource.description),
                  onTap: () => _showResource(context, resource),
                  trailing: IconButton(
                    tooltip: 'Save ${resource.filename}',
                    onPressed: () => _saveResource(context, resource),
                    icon: const Icon(Icons.download),
                  ),
                ),
            ],
            const _LessonSection(title: 'Exercise'),
            Text(guide.practice),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showLessonHints(context, guide),
                icon: const Icon(Icons.lightbulb_outline),
                label: const Text('Show hints'),
              ),
            ),
            if (lesson.exercise case final String extension) ...[
              const SizedBox(height: 10),
              Text('Apply it', style: Theme.of(context).textTheme.titleSmall),
              Text(extension),
            ],
            const _LessonSection(title: 'Common mistake'),
            Text(guide.mistake),
            if (lesson.industryUse case final String industry) ...[
              const _LessonSection(title: 'Industry application'),
              Text(industry),
            ],
            const _LessonSection(title: 'Recap'),
            Text(lessonRecap(lesson)),
          ],
        ),
      ),
    );
  }
}

class _LessonSection extends StatelessWidget {
  const _LessonSection({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 6),
    child: _SectionHeading(title: title),
  );
}

class _LessonCopyBlock extends StatelessWidget {
  const _LessonCopyBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard.')),
              );
            }
          },
        ),
      ),
      _CodeBlock(text: text),
    ],
  );
}

Future<void> _showLessonHints(BuildContext context, LessonGuide guide) async {
  var shown = 1;
  var solutionVisible = false;
  await showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: _sheetMotion(context),
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, update) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .80,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _SectionHeading(title: 'Exercise hints'),
              const SizedBox(height: 12),
              Text(guide.practice),
              for (var i = 0; i < shown; i++) ...[
                _LessonSection(title: 'Hint ${i + 1}'),
                Text(guide.hints[i]),
              ],
              const SizedBox(height: 12),
              if (shown < guide.hints.length)
                OutlinedButton(
                  onPressed: () => update(() => shown++),
                  child: const Text('Next hint'),
                )
              else if (!solutionVisible)
                OutlinedButton(
                  onPressed: () => update(() => solutionVisible = true),
                  child: const Text('Show solution'),
                )
              else ...[
                const _LessonSection(title: 'Solution'),
                if (guide.solutionIsCode)
                  _LessonCopyBlock(text: cleanLessonCode(guide.solution))
                else
                  SelectableText(guide.solution),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showResource(
  BuildContext context,
  LessonResource resource,
) async {
  await showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: _sheetMotion(context),
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .8,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeading(title: resource.filename),
            Text(resource.description),
            _LessonCopyBlock(text: resource.text),
            OutlinedButton.icon(
              onPressed: () => _saveResource(context, resource),
              icon: const Icon(Icons.download),
              label: const Text('Save file'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _saveResource(
  BuildContext context,
  LessonResource resource,
) async {
  try {
    if (Platform.isAndroid) {
      final saved = await const MethodChannel('skillverse/lesson_files')
          .invokeMethod<String>('saveText', {
            'filename': resource.filename,
            'bytes': Uint8List.fromList(utf8.encode(resource.text)),
          });
      if (saved == null) return;
    } else {
      final downloads =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      await File('${downloads.path}/${resource.filename}')
          .writeAsString(resource.text, flush: true);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Saved ${resource.filename}.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save this practice file.')),
      );
    }
  }
}
