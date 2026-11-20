part of 'main.dart';

Future<void> _browseProjectBriefs(BuildContext context, AppStore store) =>
    showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: _sheetMotion(context),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) => FractionallySizedBox(
        heightFactor: .8,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Project briefs',
              style: Theme.of(sheet).textTheme.headlineSmall,
            ),
            for (final course in courses)
              if (projectBriefFor(course) case final brief?)
                ListTile(
                  title: Text(brief.title),
                  subtitle: Text(course.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showProjectBrief(sheet, store, brief),
                ),
          ],
        ),
      ),
    );

Future<void> _showProjectBrief(
  BuildContext context,
  AppStore store,
  ProjectBrief brief,
) => showModalBottomSheet<void>(
  context: context,
  sheetAnimationStyle: _sheetMotion(context),
  isScrollControlled: true,
  useSafeArea: true,
  builder: (sheet) => FractionallySizedBox(
    heightFactor: .86,
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(brief.title, style: Theme.of(sheet).textTheme.headlineSmall),
        _BriefSection('Objective', [brief.objective]),
        _BriefSection('Requirements', brief.requirements),
        _BriefSection('Expected deliverables', brief.deliverables),
        _BriefSection('Evaluation criteria', brief.criteria),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.school_outlined),
          title: Text(brief.course.title),
          onTap: () => _push(
            sheet,
            CourseDetailPage(course: brief.course, store: store),
          ),
        ),
        if (brief.relatedLessons.isNotEmpty)
          Text('Related lessons', style: Theme.of(sheet).textTheme.titleMedium),
        for (final lesson in brief.relatedLessons)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.menu_book_outlined),
            title: Text(lesson.title),
            onTap: () => _openCourseLesson(sheet, store, brief.course, lesson),
          ),
        FilledButton.icon(
          onPressed: () => _editProject(sheet, store, brief: brief),
          icon: const Icon(Icons.add),
          label: const Text('Start a project'),
        ),
      ],
    ),
  ),
);

class _BriefSection extends StatelessWidget {
  const _BriefSection(this.title, this.items);
  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(items.length == 1 ? item : '• $item'),
          ),
      ],
    ),
  );
}

Future<void> _editProject(
  BuildContext context,
  AppStore store, {
  StudentProject? project,
  ProjectBrief? brief,
}) async {
  final owner = store.currentUserId;
  if (owner == null) return;
  final formKey = GlobalKey<FormState>();
  var title = project?.title ?? brief?.title ?? '';
  var description = project?.description ?? brief?.objective ?? '';
  var category = project?.category ?? brief?.course.title ?? 'Python';
  var technologies = project?.technologies ?? brief?.course.title ?? '';
  var repository = project?.repositoryUrl ?? '';
  var courseId = project?.courseId ?? brief?.course.id ?? '';
  var topic = project?.topic ?? brief?.relatedLessons.firstOrNull?.title ?? '';
  final categories = {
    ...courses.map((course) => course.title),
    category,
    'Other',
  };

  final initial = (
    title,
    description,
    category,
    technologies,
    repository,
    courseId,
    topic,
  );
  var saving = false;
  await showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: _sheetMotion(context),
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => StatefulBuilder(
      builder: (context, update) {
        final course = courses
            .where((course) => course.id == courseId)
            .firstOrNull;
        final topics = {
          '',
          ...?course?.allTopics,
          ...?course?.allLessons.map((lesson) => lesson.title),
          if (course != null) topic,
        };
        return _GuardUnsaved(
          busy: saving,
          dirty:
              (
                title,
                description,
                category,
                technologies,
                repository,
                courseId,
                topic,
              ) !=
              initial,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        tooltip: 'Close project editor',
                        onPressed: saving
                            ? null
                            : () => Navigator.maybePop(sheet),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    Text(
                      project == null ? 'Add project' : 'Edit project',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    TextFormField(
                      initialValue: title,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Project title',
                      ),
                      onChanged: (value) => update(() => title = value),
                      validator: (value) => value!.trim().isEmpty
                          ? 'Enter a project title'
                          : null,
                    ),
                    TextFormField(
                      initialValue: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      onChanged: (value) => update(() => description = value),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final name in categories)
                          DropdownMenuItem(value: name, child: Text(name)),
                      ],
                      onChanged: (value) => update(() => category = value!),
                    ),
                    TextFormField(
                      initialValue: technologies,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Technologies',
                      ),
                      onChanged: (value) => update(() => technologies = value),
                    ),
                    TextFormField(
                      initialValue: repository,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Repository URL (optional)',
                        hintText: 'https://github.com/owner/repository',
                      ),
                      onChanged: (value) => update(() => repository = value),
                      validator: (value) =>
                          value!.trim().isNotEmpty &&
                              StudentProject.repositoryUri(value) == null
                          ? 'Enter a valid HTTP or HTTPS address'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: course?.id ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Linked course',
                      ),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('None')),
                        for (final item in courses)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.title),
                          ),
                      ],
                      onChanged: (value) => update(() {
                        courseId = value!;
                        topic = '';
                      }),
                    ),
                    if (course != null)
                      DropdownButtonFormField<String>(
                        key: ValueKey(course.id),
                        initialValue: topic,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Linked topic',
                        ),
                        items: [
                          for (final item in topics)
                            DropdownMenuItem(
                              value: item,
                              child: Text(
                                item.isEmpty ? 'None' : item,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (value) => update(() => topic = value!),
                      ),
                    FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              if (store.currentUserId != owner) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Sign in to the original account to save this project.',
                                    ),
                                  ),
                                );
                                return;
                              }
                              update(() => saving = true);
                              try {
                                await store.saveProject(
                                  StudentProject(
                                    id:
                                        project?.id ??
                                        DateTime.now().microsecondsSinceEpoch
                                            .toString(),
                                    title: title.trim(),
                                    description: description.trim(),
                                    category: category,
                                    technologies: technologies.trim(),
                                    repositoryUrl: repository.trim(),
                                    courseId: courseId.isEmpty
                                        ? null
                                        : courseId,
                                    topic: topic.isEmpty ? null : topic,
                                  ),
                                );
                                if (sheet.mounted) Navigator.pop(sheet);
                              } catch (_) {
                                if (!context.mounted) return;
                                update(() => saving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Could not save the project. Your edits are still here. Try again.',
                                    ),
                                  ),
                                );
                              }
                            },
                      child: Text(saving ? 'Saving project…' : 'Save project'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _showProject(
  BuildContext context,
  AppStore store,
  StudentProject project,
) => showModalBottomSheet<void>(
  context: context,
  sheetAnimationStyle: _sheetMotion(context),
  useSafeArea: true,
  isScrollControlled: true,
  builder: (sheet) {
    final uri = StudentProject.repositoryUri(project.repositoryUrl);
    final course = courses
        .where((item) => item.id == project.courseId)
        .firstOrNull;
    final lesson = course?.allLessons
        .where(
          (item) =>
              item.title == project.topic ||
              item.topics.contains(project.topic),
        )
        .firstOrNull;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(project.title, style: Theme.of(sheet).textTheme.headlineSmall),
          Text(
            [
              project.category,
              if (project.technologies.isNotEmpty) project.technologies,
            ].join(' · '),
          ),
          Text(project.description),
          if (project.repositoryUrl.isNotEmpty)
            SelectableText(project.repositoryUrl),
          if (uri != null)
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  if (await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  )) {
                    return;
                  }
                } on Exception catch (_) {
                  // The installed browser may reject the URL.
                }
                if (sheet.mounted) {
                  ScaffoldMessenger.of(sheet).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open the repository.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open repository'),
            ),
          if (course != null)
            TextButton(
              onPressed: () =>
                  _push(sheet, CourseDetailPage(course: course, store: store)),
              child: Text(course.title),
            ),
          if (course != null && lesson != null)
            TextButton(
              onPressed: () => _openCourseLesson(sheet, store, course, lesson),
              child: Text(project.topic!),
            ),
        ],
      ),
    );
  },
);

Future<void> _confirmDelete(
  BuildContext context,
  AppStore store,
  StudentProject project,
) async {
  final owner = store.currentUserId;
  if (owner == null) return;
  final messenger = ScaffoldMessenger.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    animationStyle: _sheetMotion(context),
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: const Text('Delete project?'),
      content: Text('Remove “${project.title}” from your saved projects?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialog, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true || store.currentUserId != owner) return;
  try {
    await store.deleteProject(project.id);
    if (!messenger.mounted || store.currentUserId != owner) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Project deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await store.restoreDeletedProject(project, owner);
            } on Exception catch (_) {
              if (messenger.mounted && store.currentUserId == owner) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Could not restore the project.'),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  } on Exception catch (_) {
    if (messenger.mounted && store.currentUserId == owner) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete the project.')),
      );
    }
  }
}

class _LearningMilestones extends StatelessWidget {
  const _LearningMilestones({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final lessons = store.completedLessonIdsEver;
    final earnedModule = courses
        .expand((course) => course.modules)
        .any(
          (module) =>
              module.lessons.isNotEmpty &&
              module.lessons.every((lesson) => lessons.contains(lesson.id)),
        );
    final answeredQuiz = store.attempts.any(
      (attempt) =>
          attempt.mode != 'practice' &&
          attempt.mode != 'modulePractice' &&
          attempt.reviewQuestions.any((question) {
            final index = attempt.selections[question.id];
            return index != null &&
                index >= 0 &&
                index < question.options.length;
          }),
    );
    final completedInterview = store.interviewAttempts.any(
      (attempt) => attempt.responses.values.any(
        (response) => response.text.trim().isNotEmpty,
      ),
    );
    final now = DateTime.now();
    final days = {
      for (final activity in store.learningActivity)
        if (activity.date case final date? when !date.isAfter(now))
          DateUtils.dateOnly(date.toLocal()),
    };
    final milestones = [
      (
        'First lesson',
        'Complete one lesson.',
        Icons.menu_book_outlined,
        lessons.isNotEmpty,
      ),
      (
        'Module complete',
        'Complete every lesson in a module.',
        Icons.view_module_outlined,
        earnedModule,
      ),
      (
        'Quiz attempt',
        'Submit a quiz or assessment with an answer.',
        Icons.quiz_outlined,
        answeredQuiz,
      ),
      (
        'Interview practice',
        'Finish a mock interview with a written answer.',
        Icons.record_voice_over_outlined,
        completedInterview,
      ),
      (
        'Course complete',
        'Meet all requirements for a course completion record.',
        Icons.workspace_premium_outlined,
        courses.any((course) => store.certificateFor(course) != null),
      ),
      (
        'Three learning days',
        'Record activity on three different dates.',
        Icons.event_available_outlined,
        days.length >= 3,
      ),
    ];
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.emoji_events_outlined),
        title: const Text('Learning milestones'),
        subtitle: Text(
          '${milestones.where((item) => item.$4).length} of ${milestones.length} earned',
        ),
        children: [
          for (final (title, requirement, icon, earned) in milestones)
            ListTile(
              leading: Icon(icon),
              title: Text(title),
              subtitle: Text(requirement),
              trailing: Tooltip(
                message: earned ? 'Earned' : 'Locked',
                child: Icon(
                  earned ? Icons.check_circle_outline : Icons.lock_outline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
