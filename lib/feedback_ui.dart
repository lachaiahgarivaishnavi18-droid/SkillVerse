part of 'main.dart';

void _installOptionalDiagnostics(AppStore store) {
  void record(DiagnosticSource source) {
    unawaited(store.recordDiagnostic(source).catchError((Object _) {}));
  }

  final flutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    record(DiagnosticSource.framework);
    flutterHandler?.call(details);
  };
  final dispatcher = PlatformDispatcher.instance;
  final dartHandler = dispatcher.onError;
  dispatcher.onError = (error, stack) {
    record(DiagnosticSource.dart);
    return dartHandler?.call(error, stack) ?? false;
  };
}

class _ReportContentButton extends StatelessWidget {
  const _ReportContentButton(this.contentId);
  final String contentId;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Report a content problem',
    onPressed: () =>
        _reportProblem(context, FeedbackKind.content, contentId: contentId),
    icon: const Icon(Icons.outlined_flag),
  );
}

Future<void> _reportProblem(
  BuildContext context,
  FeedbackKind kind, {
  String? contentId,
  Map<DiagnosticSource, int> diagnostics = const {},
}) async {
  final build = await AppBuild.read();
  if (!context.mounted) return;
  var description = '';
  final review =
      kind == FeedbackKind.diagnostics ||
      await showDialog<bool>(
            context: context,
            animationStyle: _sheetMotion(context),
            barrierDismissible: false,
            builder: (dialog) => StatefulBuilder(
              builder: (context, update) => _GuardUnsaved(
                dirty: description.trim().isNotEmpty,
                child: AlertDialog(
                  scrollable: true,
                  title: Text(kind.label),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 12,
                    children: [
                      if (contentId != null) Text('Content ID · $contentId'),
                      Text(switch (kind) {
                        FeedbackKind.content => 'Describe the incorrect answer, explanation, or course material and how it should be corrected.',
                        FeedbackKind.appBug => 'Describe what you did, what you expected, and what happened. You can include repeatable steps.',
                        FeedbackKind.firstLesson => 'What helped you start your first lesson? Mention any difficulty finding, opening, or completing it.',
                        FeedbackKind.diagnostics => '',
                      }),
                      const Text(
                        'Leave out passwords, email addresses, and private answers. You can review the report before copying it.',
                      ),
                      TextFormField(
                        initialValue: description,
                        onChanged: (value) => update(() => description = value),
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 1500,
                        decoration: const InputDecoration(
                          labelText: 'Describe what happened',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.maybePop(dialog),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: description.trim().isEmpty
                          ? null
                          : () => Navigator.pop(dialog, true),
                      child: const Text('Review report'),
                    ),
                  ],
                ),
              ),
            ),
          ) ==
          true;
  if (!review || !context.mounted) return;
  final report = buildFeedbackReport(
    kind: kind,
    build: build,
    description: description,
    contentId: contentId,
    diagnostics: diagnostics,
  );
  await showDialog<void>(
    context: context,
    animationStyle: _sheetMotion(context),
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: const Text('Review your report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          const Text(
            'Copy the report only if you want to share it with your tester coordinator or support contact. Skillverse does not send it.',
          ),
          SelectableText(report),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Close'),
        ),
        FilledButton.icon(
          onPressed: () async {
            try {
              await Clipboard.setData(ClipboardData(text: report));
              if (!dialog.mounted) return;
              Navigator.pop(dialog);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Report copied. You can paste it into your chosen support channel.',
                    ),
                  ),
                );
              }
            } catch (_) {
              if (dialog.mounted) {
                // Leave the report selectable if the clipboard is unavailable.
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not copy. Select the report text to copy it manually.',
                    ),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy report'),
        ),
      ],
    ),
  );
}

class _FeedbackPage extends StatelessWidget {
  const _FeedbackPage({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Feedback and privacy')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionHeading(title: 'Report a problem'),
          _FeatureTile(
            icon: Icons.bug_report_outlined,
            title: 'Report an app bug',
            subtitle: 'Crashes, navigation, layout, or performance',
            onTap: () => _reportProblem(context, FeedbackKind.appBug),
          ),
          const ListTile(
            leading: Icon(Icons.outlined_flag),
            title: Text('Course and question content'),
            subtitle: Text(
              'Use the Report a content problem button on the course, lesson, or question to include its ID.',
            ),
          ),
          _FeatureTile(
            icon: Icons.rate_review_outlined,
            title: 'Share a first-lesson observation',
            subtitle: 'Optional feedback about finding, opening, or completing your first lesson',
            onTap: () => _reportProblem(context, FeedbackKind.firstLesson),
          ),
          const SizedBox(height: 16),
          const _SectionHeading(title: 'Optional crash diagnostics'),
          if (store.isAuthenticated)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Count app errors on this device'),
              subtitle: const Text(
                'Off by default. When enabled, Skillverse counts Flutter framework errors and unhandled Dart errors for this account. It stores no error text, stack traces, account identifiers in the report, or written answers. Turning it off clears these counts.',
              ),
              value: store.diagnosticsEnabled,
              onChanged: (enabled) async {
                final owner = store.currentUserId;
                if (owner == null) return;
                if (enabled) {
                  final accepted = await showDialog<bool>(
                    context: context,
                    animationStyle: _sheetMotion(context),
                    builder: (dialog) => AlertDialog(
                      scrollable: true,
                      title: const Text('Enable local error counts?'),
                      content: const Text(
                        'Skillverse will keep counts on this device. You decide whether to review and copy a report. Nothing is sent automatically.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialog, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialog, true),
                          child: const Text('Enable counts'),
                        ),
                      ],
                    ),
                  );
                  if (accepted != true || !context.mounted) return;
                }
                if (owner != store.currentUserId) return;
                try {
                  await store.setDiagnosticsEnabled(enabled);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not update diagnostics. Try again.',
                        ),
                      ),
                    );
                  }
                }
              },
            )
          else
            const Text(
              'Sign in to manage optional diagnostics for your local account data.',
            ),
          if (store.diagnosticsEnabled)
            OutlinedButton.icon(
              onPressed: () => _reportProblem(
                context,
                FeedbackKind.diagnostics,
                diagnostics: store.diagnosticCounts,
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Review diagnostic counts'),
            ),
          const SizedBox(height: 16),
          const _SectionHeading(title: 'Where your data lives'),
          const ListTile(
            title: Text('On this device'),
            subtitle: Text(
              'Lessons, reading positions, saved courses, bookmarks, drafts, written answers, results history, projects, goals, reminders, and certificate records stay on this device. Offline accounts and their credentials are local. Reports are only copied when you choose.',
            ),
          ),
          const ListTile(
            title: Text('Synced on cloud builds'),
            subtitle: Text(
              'Supabase stores cloud account details and the profile name. Completed scoring submissions use question IDs, selected quiz options, and reviewed interview completion indicators to award points. Rankings show names and points. Written interview responses stay on this device.',
            ),
          ),
          const ListTile(
            title: Text('Signing out and deleting data'),
            subtitle: Text(
              'Signing out ends this session. Your local progress and queued results remain for your next sign-in to the same account. Clearing Skillverse storage in Android Settings removes all of its on-device data. Exported files and reports you already shared are separate copies. To delete a cloud account and its shared ranking data, contact your Skillverse administrator. Cloud deletion does not erase copies on your devices.',
            ),
          ),
        ],
      ),
    ),
  );
}
