part of 'main.dart';

void _openCourseLesson(
  BuildContext context,
  AppStore store,
  Course course,
  Lesson lesson,
) => _push(
  context,
  LessonPage(store: store, lesson: lesson, courseLessons: course.allLessons),
);

void _openFinalAssessment(BuildContext context, AppStore store, Course course) {
  final draft = store.examDraft(course.quizSubject ?? course.title, course.id);
  if (draft != null) {
    _push(context, _resumeExam(draft, store));
    return;
  }
  _push(
    context,
    MockTestPage(
      subject: course.quizSubject ?? course.title,
      store: store,
      courseId: course.id,
      questions: course.finalQuestions,
      mode: TestMode.exam,
    ),
  );
}

Future<void> _chooseLearningGoal(
  BuildContext context,
  AppStore store, {
  bool start = false,
}) async {
  final selected = await showModalBottomSheet<LearningGoal>(
    context: context,
    sheetAnimationStyle: _sheetMotion(context),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionHeading(title: 'Choose your learning goal'),
            for (final goal in LearningGoal.values)
              ListTile(
                leading: CurriculumIcon.course(goal.course),
                title: Text(goal.label),
                subtitle: Text('${goal.course.title}\n${goal.reason}'),
                trailing: store.learningGoal == goal
                    ? const Icon(Icons.check, color: _blue)
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, goal),
              ),
          ],
        ),
      ),
    ),
  );
  if (selected == null || !context.mounted) return;
  try {
    await store.setLearningGoal(selected);
    if (start && context.mounted) {
      _openCourseLesson(
        context,
        store,
        selected.course,
        selected.course.allLessons.first,
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save your learning goal.')),
      );
    }
  }
}

class _ResumeLearning extends StatelessWidget {
  const _ResumeLearning({required this.store, required this.course});

  final AppStore store;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final lesson = store.continueLesson(course);
    final module = lesson == null ? null : moduleForLesson(course, lesson);
    final completed = (store.progressFor(course) * course.allLessons.length)
        .round();
    void openCourse() =>
        _push(context, CourseDetailPage(course: course, store: store));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Continue learning', style: TextStyle(color: Colors.white)),
        const SizedBox(height: 4),
        InkWell(
          onTap: openCourse,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Text(
                course.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ),
        if (lesson != null) ...[
          if (module != null)
            Text(
              module.title,
              style: const TextStyle(color: Color(0xFFE0E9FF)),
            ),
          Text(lesson.title, style: const TextStyle(color: Colors.white)),
          Text(
            'About ${estimatedLessonMinutes(lesson)} min',
            style: const TextStyle(color: Color(0xFFE0E9FF)),
          ),
        ] else ...[
          const Text('Final assessment', style: TextStyle(color: Colors.white)),
          Text(
            '${course.finalQuestions.length * _minutesPerTestQuestion} min time limit',
            style: const TextStyle(color: Color(0xFFE0E9FF)),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '$completed of ${course.allLessons.length} lessons completed',
          style: const TextStyle(color: Color(0xFFE0E9FF)),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          icon: const Icon(Icons.play_arrow),
          label: const Text('Resume Learning'),
          onPressed: lesson != null
              ? () => _openCourseLesson(context, store, course, lesson)
              : course.finalQuestions.isEmpty
              ? openCourse
              : () => _openFinalAssessment(context, store, course),
        ),
      ],
    );
  }
}

class _DiscoveryCourseTile extends StatelessWidget {
  const _DiscoveryCourseTile({required this.course, required this.store});

  final Course course;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final progress = store.progressFor(course);
    final completed = (progress * course.allLessons.length).round();
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _paleBlue,
          child: CurriculumIcon.course(course),
        ),
        title: Text(
          course.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${course.description}\n'
          '${course.level} · ${course.allLessons.length} lessons · '
          '$completed completed · ${(progress * 100).round()}%',
        ),
        trailing: _SaveCourseButton(course: course, store: store),
        onTap: () =>
            _push(context, CourseDetailPage(course: course, store: store)),
      ),
    );
  }
}

class _SaveCourseButton extends StatelessWidget {
  const _SaveCourseButton({required this.course, required this.store});

  final Course course;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final saved = store.savedCourseIds.contains(course.id);
    return IconButton(
      tooltip: saved ? 'Remove saved course' : 'Save course',
      icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
      onPressed: !store.isAuthenticated
          ? null
          : () async {
              try {
                await store.toggleSavedCourse(course);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not update saved courses.'),
                    ),
                  );
                }
              }
            },
    );
  }
}

class _MyLearningPage extends StatelessWidget {
  const _MyLearningPage({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Learning')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final saved = store.savedCourseIds;
        final groups = [
          (
            'In Progress',
            store.coursesInProgress,
            'Open a lesson to start a course.',
          ),
          (
            'Saved',
            courses.where((course) => saved.contains(course.id)),
            'Bookmark a course to find it here.',
          ),
          (
            'Completed',
            courses.where(store.isCourseComplete),
            'Finish a course and pass its final assessment.',
          ),
        ];
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            for (final (title, entries, emptyText) in groups) ...[
              _SectionHeading(title: title),
              const SizedBox(height: 8),
              if (entries.isEmpty) Text(emptyText),
              for (final course in entries)
                _DiscoveryCourseTile(course: course, store: store),
              const SizedBox(height: 20),
            ],
          ],
        );
      },
    ),
  );
}

void _showCoursePreview(BuildContext context, AppStore store, Course course) {
  final modules = course.learningModules;
  final sample = course.allLessons.take(2);
  final assessment = course.finalQuestions.length;
  showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: _sheetMotion(context),
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .85,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _SectionHeading(title: '${course.title} preview'),
            const SizedBox(height: 8),
            Text('Estimated duration · ${courseStudyTime(course)}'),
            const SizedBox(height: 16),
            const _SectionHeading(title: 'Sample lessons'),
            for (final lesson in sample)
              ListTile(
                leading: switch (moduleForLesson(course, lesson)) {
                  final module? => CurriculumIcon.lesson(
                    course,
                    module,
                    lesson,
                  ),
                  null => CurriculumIcon.course(course),
                },
                title: Text(lesson.title),
                subtitle: Text('About ${estimatedLessonMinutes(lesson)} min'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _push(
                  context,
                  LessonPage(lesson: lesson, store: store, preview: true),
                ),
              ),
            const SizedBox(height: 16),
            const _SectionHeading(title: 'Syllabus'),
            for (final module in modules)
              ListTile(
                title: Text(module.title),
                subtitle: Text(
                  '${module.lessons.length} lessons · ${module.summary}',
                ),
              ),
            const SizedBox(height: 16),
            const _SectionHeading(title: 'Assessment requirements'),
            const SizedBox(height: 8),
            Text(
              assessment == 0
                  ? 'This course has no final assessment.'
                  : 'Complete every lesson, then score at least 70% on the $assessment-question final assessment.',
            ),
          ],
        ),
      ),
    ),
  );
}
