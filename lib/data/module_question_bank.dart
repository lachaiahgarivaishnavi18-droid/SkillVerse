import 'course_models.dart';
import 'opening_module_cases.dart';

/// Builds the module banks from the bundled syllabus and worked examples.
///
/// Each question type checks a different piece of course material. Course
/// finals keep their original IDs, options, and answer indices.
List<CourseModule> buildModuleQuestionBanks(
  Course course,
  List<CourseModule> modules,
) {
  final lessons = modules.expand((module) => module.lessons).toList();
  final previous = modules
      .expand((module) => [...module.questions, ...module.assessmentQuestions])
      .toList();
  return List.unmodifiable([
    for (var i = 0; i < modules.length; i++)
      _populate(course, modules, i, lessons, previous),
  ]);
}

CourseModule _populate(
  Course course,
  List<CourseModule> modules,
  int index,
  List<Lesson> lessons,
  List<QuizQuestion> previous,
) {
  final module = modules[index];
  final bank = _ModuleBank(course, module, index, lessons, modules, previous);
  final local = module.lessons;
  final glossary = local.where((lesson) => lesson.topics.length > 1).toList();
  final practice = [
    for (final q in module.questions) bank.keepOriginal(q),
    for (var i = 0; i < 2; i++) ...[
      bank.principle(local[i]),
      bank.example(local[(i + 1) % local.length]),
      bank.useCase(local[(i + 2) % local.length]),
      bank.vocabulary(glossary[i]),
    ],
    bank.assignment(),
    if (module.questions.isEmpty) bank.gitPractice(index),
    if (index == 0 && openingModuleCases.containsKey(course.id))
      bank.openingCase(),
    ...bank.reviewCases(
      index == 0 && openingModuleCases.containsKey(course.id)
          ? _practiceReviews.take(_practiceReviews.length - 1)
          : _practiceReviews,
      mode: 'practice',
    ),
  ];
  final quiz = [
    for (var i = 0; i < 2; i++) ...[
      bank.result(local[i]),
      bank.reasoning(local[(i + 1) % local.length]),
      bank.exercise(local[(i + 2) % local.length]),
      bank.companionTopic(glossary[i]),
    ],
    bank.objective(),
    bank.workflow(),
    ...bank.reviewCases(_quizReviews, mode: 'quiz'),
  ];

  return CourseModule(
    title: module.title,
    summary: module.summary,
    assignment: module.assignment,
    lessons: module.lessons,
    questions: List.unmodifiable(practice),
    moduleQuizQuestions: List.unmodifiable(quiz),
    assessmentQuestions: module.assessmentQuestions,
  );
}

// Each case compares two distinct facts from the module. These pairings cover
// different review decisions without copying single-lesson questions between banks.
enum _Evidence { rule, guidance, outcome, exercise, application }

typedef _Review = (_Evidence, _Evidence, CourseDifficulty);
const _b = CourseDifficulty.beginner;
const _i = CourseDifficulty.intermediate;
const _a = CourseDifficulty.advanced;

const _practiceReviews = <_Review>[
  (_Evidence.rule, _Evidence.outcome, _b),
  (_Evidence.application, _Evidence.rule, _i),
  (_Evidence.outcome, _Evidence.guidance, _i),
  (_Evidence.exercise, _Evidence.application, _i),
  (_Evidence.guidance, _Evidence.exercise, _a),
  (_Evidence.rule, _Evidence.guidance, _i),
  (_Evidence.application, _Evidence.outcome, _b),
  (_Evidence.outcome, _Evidence.exercise, _i),
  (_Evidence.exercise, _Evidence.rule, _a),
  (_Evidence.guidance, _Evidence.application, _a),
];

const _quizReviews = <_Review>[
  (_Evidence.outcome, _Evidence.outcome, _b),
  (_Evidence.guidance, _Evidence.rule, _i),
  (_Evidence.application, _Evidence.guidance, _i),
  (_Evidence.rule, _Evidence.exercise, _a),
  (_Evidence.exercise, _Evidence.outcome, _i),
  (_Evidence.rule, _Evidence.rule, _b),
  (_Evidence.guidance, _Evidence.outcome, _i),
  (_Evidence.application, _Evidence.exercise, _a),
  (_Evidence.outcome, _Evidence.rule, _i),
  (_Evidence.exercise, _Evidence.guidance, _a),
];

class _ModuleBank {
  _ModuleBank(
    this.course,
    this.module,
    int index,
    this.lessons,
    this.modules,
    this.previous,
  ) : prefix = '${course.id}-module-bank-${index + 1}';

  final Course course;
  final CourseModule module;
  final String prefix;
  final List<Lesson> lessons;
  final List<CourseModule> modules;
  final List<QuizQuestion> previous;

  String get _context => '${course.title} · ${module.title}';

  QuizQuestion keepOriginal(QuizQuestion question) {
    final options = [...question.options];
    if (options.length == 3) {
      final distractors = previous.expand(
        (q) => [
          for (var i = 0; i < q.options.length; i++)
            if (i != q.answerIndex) q.options[i],
        ],
      );
      options.add(
        _distractors(question.prompt, options, distractors, 1).single,
      );
    }
    return QuizQuestion(
      id: question.id,
      subject: question.subject,
      prompt: question.prompt,
      options: List.unmodifiable(options),
      answerIndex: question.answerIndex,
      explanation: question.explanation,
      difficulty: question.difficulty == 'Basic'
          ? 'Beginner'
          : question.difficulty,
      topic: module.title,
    );
  }

  QuizQuestion principle(Lesson lesson) => _lessonQuestion(
    'principle',
    lesson,
    CourseDifficulty.beginner,
    'Which statement best describes the core idea in “${lesson.title}”?',
    _principle(lesson),
    _principle,
    lesson.summary,
  );

  QuizQuestion example(Lesson lesson) => _lessonQuestion(
    'example',
    lesson,
    CourseDifficulty.intermediate,
    'Which worked example would you use to demonstrate “${lesson.title}”?',
    lesson.example,
    (item) => item.example,
    'This example demonstrates the lesson’s main idea. ${_principle(lesson)}',
  );

  QuizQuestion useCase(Lesson lesson) => _lessonQuestion(
    'use',
    lesson,
    CourseDifficulty.intermediate,
    'Where would you apply “${lesson.title}” in a project?',
    _application(lesson),
    _application,
    '${lesson.industryUse} ${_principle(lesson)}',
  );

  String _application(Lesson lesson) {
    final context = lesson.industryUse!;
    if (lessons.where((item) => item.industryUse == context).length == 1) {
      return context;
    }
    return '$context ${_principle(lesson)}';
  }

  QuizQuestion vocabulary(Lesson lesson) => _question(
    'vocabulary-${lesson.id}',
    lesson.title,
    CourseDifficulty.beginner,
    'Which term belongs to the foundational vocabulary for “${lesson.title}”?',
    lesson.topics.first,
    lessons.expand((item) => item.topics),
    '${lesson.topics.first} is one of the concepts introduced in this lesson. ${_principle(lesson)}',
    excluded: lesson.topics.skip(1),
  );

  QuizQuestion result(Lesson lesson) => _lessonQuestion(
    'result',
    lesson,
    CourseDifficulty.intermediate,
    'What result should the “${lesson.title}” example demonstrate?\n\n${lesson.example}',
    lesson.expectedOutput!,
    (item) => item.expectedOutput!,
    'The expected result is ${lesson.expectedOutput}\n\n${lesson.summary}',
  );

  QuizQuestion reasoning(Lesson lesson) => _lessonQuestion(
    'reasoning',
    lesson,
    CourseDifficulty.advanced,
    'Given this starting point for “${lesson.title}”, which follow-up rule should guide your work?\n\n${_principle(lesson)}',
    _reasoning(lesson),
    _reasoning,
    '${_principle(lesson)} ${_reasoning(lesson)}',
  );

  QuizQuestion exercise(Lesson lesson) => _lessonQuestion(
    'exercise',
    lesson,
    CourseDifficulty.advanced,
    'You have run the example for “${lesson.title}”. Which follow-up exercise tests whether you can apply the skill yourself?',
    lesson.exercise!,
    (item) => item.exercise!,
    'The follow-up exercise is “${lesson.exercise}” It checks the skill described here: ${lesson.summary}',
  );

  QuizQuestion companionTopic(Lesson lesson) => _question(
    'companion-${lesson.id}',
    lesson.title,
    CourseDifficulty.beginner,
    'A review of “${lesson.title}” already includes ${lesson.topics.first}. Which additional concept belongs in the same review?',
    lesson.topics.last,
    lessons.expand((item) => item.topics),
    'This lesson groups ${lesson.topics.first} with ${lesson.topics.last}. ${lesson.summary}',
    excluded: lesson.topics.take(lesson.topics.length - 1),
  );

  QuizQuestion assignment() => _question(
    'assignment',
    module.title,
    CourseDifficulty.advanced,
    'Which hands-on deliverable would demonstrate the combined skills in this module?',
    _assignment(module),
    [...modules.map(_assignment), ...lessons.map((lesson) => lesson.exercise!)],
    'The module covers this objective: ${module.summary} The deliverable puts that objective into practice.',
  );

  QuizQuestion objective() => _question(
    'objective',
    module.title,
    CourseDifficulty.beginner,
    'Which learning objective is the focus of this module?',
    module.summary,
    [...modules.map((item) => item.summary), ...lessons.map(_principle)],
    'This module focuses on the following objective: ${module.summary}',
  );

  QuizQuestion workflow() {
    final first = module.lessons.first;
    final second = module.lessons[1];
    final otherLessons = lessons.where(
      (lesson) => !module.lessons.contains(lesson),
    );
    String pair(Lesson a, Lesson b) => '${a.title} + ${b.title}';
    return _question(
      'workflow',
      module.title,
      CourseDifficulty.advanced,
      'You are planning the module deliverable below. Which pair of lesson topics should you combine first?\n\n${_assignment(module)}',
      pair(first, second),
      [
        for (final other in otherLessons) ...[
          pair(first, other),
          pair(other, second),
        ],
      ],
      'Start with ${first.title} and ${second.title}. ${module.summary}',
    );
  }

  QuizQuestion gitPractice(int index) {
    final (prompt, answer, alternates, explanation) = index == 0
        ? (
            'You changed README.md and a source file. How do you commit only the README change if nothing is staged yet?',
            'Stage README.md, inspect the staged diff, then commit.',
            [
              'Use git commit -am so Git picks only documentation.',
              'Stage both files and inspect only the unstaged diff.',
              'Use git log before staging and commit without checking the index.',
            ],
            'A commit records the index. Staging only README.md and checking git diff --cached confirms which changes will enter the commit.',
          )
        : (
            'You want to inspect upstream history without integrating it into your current branch. What should you do?',
            'Run git fetch and inspect the remote-tracking branch with git log.',
            [
              'Run git pull so upstream changes are added to the current branch.',
              'Run git push to overwrite the remote-tracking branch.',
              'Delete your remote and inspect only the current branch.',
            ],
            'Fetch updates remote-tracking references. It does not merge or rebase the fetched commits into your current branch.',
          );
    return _question(
      'git-practice',
      module.title,
      CourseDifficulty.intermediate,
      prompt,
      answer,
      alternates,
      explanation,
    );
  }

  QuizQuestion openingCase() {
    final (prompt, answer, distractors, explanation) =
        openingModuleCases[course.id]!;
    return _question(
      'opening-case',
      module.title,
      CourseDifficulty.intermediate,
      prompt,
      answer,
      distractors,
      explanation,
    );
  }

  Iterable<QuizQuestion> reviewCases(
    Iterable<_Review> reviews, {
    required String mode,
  }) sync* {
    final first = module.lessons[module.lessons.length - 2];
    final second = module.lessons.last;
    final offset = prefix.codeUnits.fold(0, (sum, value) => sum + value);
    for (final (i, (firstKind, secondKind, difficulty)) in reviews.indexed) {
      final answerIndex = (offset + i + (mode == 'quiz' ? 1 : 0)) % 4;
      final firstMatches = answerIndex == 0 || answerIndex == 2;
      final secondMatches = answerIndex == 1 || answerIndex == 2;
      final (firstClaim, firstActual) = _reviewClaim(
        first,
        firstKind,
        firstMatches,
      );
      final (secondClaim, secondActual) = _reviewClaim(
        second,
        secondKind,
        secondMatches,
      );
      final firstLabel = _reviewLabel(firstKind, first);
      final secondLabel = _reviewLabel(secondKind, second);
      yield QuizQuestion(
        id: '$prefix-$mode-review-${i + 1}',
        subject: course.quizSubject ?? course.title,
        topic: '${first.title} and ${second.title}',
        difficulty: difficulty.label,
        prompt:
            '$_context\n\n'
            'Two notes were recorded while reviewing a module project. '
            'Which notes match the lesson material?\n\n'
            'I. $firstLabel\n${_reviewNote(firstKind, first, firstClaim)}\n\n'
            'II. $secondLabel\n${_reviewNote(secondKind, second, secondClaim)}',
        options: const [
          'Only note I matches',
          'Only note II matches',
          'Both notes match',
          'Neither note matches',
        ],
        answerIndex: answerIndex,
        explanation:
            'I. ${firstMatches ? 'Correct' : 'Incorrect'}. '
            '$firstLabel\n$firstActual\n\n'
            'II. ${secondMatches ? 'Correct' : 'Incorrect'}. '
            '$secondLabel\n$secondActual',
      );
    }
  }

  String _reviewNote(_Evidence kind, Lesson lesson, String claim) =>
      kind == _Evidence.outcome
      ? '${lesson.example}\n\nClaimed result: $claim'
      : claim;

  (String, String) _reviewClaim(Lesson lesson, _Evidence kind, bool matches) {
    final actual = _reviewValue(kind, lesson);
    if (matches) return (actual, actual);
    final alternatives = lessons
        .where((item) => !module.lessons.contains(item))
        .map((item) => _reviewValue(kind, item));
    return (
      _distractors('${lesson.title} $actual', [actual], alternatives, 1).single,
      actual,
    );
  }

  String _reviewValue(_Evidence kind, Lesson lesson) => switch (kind) {
    _Evidence.rule => _principle(lesson),
    _Evidence.guidance => _reasoning(lesson),
    _Evidence.outcome => lesson.expectedOutput!,
    _Evidence.exercise => lesson.exercise!,
    _Evidence.application => _application(lesson),
  };

  String _reviewLabel(_Evidence kind, Lesson lesson) => switch (kind) {
    _Evidence.rule => 'Core rule for “${lesson.title}”',
    _Evidence.guidance => 'Design guidance for “${lesson.title}”',
    _Evidence.outcome => 'Expected outcome of the “${lesson.title}” example',
    _Evidence.exercise => 'Follow-up task for “${lesson.title}”',
    _Evidence.application => 'Project use of “${lesson.title}”',
  };

  QuizQuestion _lessonQuestion(
    String kind,
    Lesson lesson,
    CourseDifficulty difficulty,
    String stem,
    String answer,
    String Function(Lesson) field,
    String explanation,
  ) => _question(
    '$kind-${lesson.id}',
    lesson.title,
    difficulty,
    stem,
    answer,
    lessons.where((item) => item.id != lesson.id).map(field),
    explanation,
  );

  QuizQuestion _question(
    String suffix,
    String topic,
    CourseDifficulty difficulty,
    String stem,
    String answer,
    Iterable<String> pool,
    String explanation, {
    Iterable<String> excluded = const [],
  }) {
    final id = '$prefix-$suffix';
    final answerIndex = id.codeUnits.fold(0, (sum, value) => sum + value) % 4;
    final options = _distractors(
      '$topic $answer',
      [answer, ...excluded],
      pool,
      3,
    )..insert(answerIndex, answer);
    return QuizQuestion(
      id: id,
      subject: course.quizSubject ?? course.title,
      prompt: '$_context\n\n$stem',
      options: List.unmodifiable(options),
      answerIndex: answerIndex,
      explanation: explanation,
      difficulty: difficulty.label,
      topic: topic,
    );
  }
}

List<String> _distractors(
  String context,
  Iterable<String> excluded,
  Iterable<String> pool,
  int count,
) {
  String normalize(String value) => value.trim().toLowerCase();
  final seen = excluded.map(normalize).toSet();
  final keywords = _keywords(context);
  final candidates = <({String text, int overlap, int index})>[];
  for (final value in pool) {
    if (value.trim().isEmpty || !seen.add(normalize(value))) continue;
    candidates.add((
      text: value,
      overlap: _keywords(value).intersection(keywords).length,
      index: candidates.length,
    ));
  }
  candidates.sort((a, b) {
    final comparison = b.overlap.compareTo(a.overlap);
    return comparison != 0 ? comparison : a.index.compareTo(b.index);
  });
  if (candidates.length < count) {
    throw StateError('Not enough alternate answers for $context');
  }
  return candidates.take(count).map((candidate) => candidate.text).toList();
}

Set<String> _keywords(String value) =>
    RegExp(r'[a-z0-9]{4,}')
        .allMatches(value.toLowerCase())
        .map((match) => match.group(0)!)
        .toSet();

final _sentenceBreak = RegExp(r'(?<=[.!?;])\s+');

String _principle(Lesson lesson) => lesson.summary.split(_sentenceBreak).first;

String _reasoning(Lesson lesson) {
  final parts = lesson.summary.split(_sentenceBreak);
  if (parts.length > 1) return parts.skip(1).join(' ');
  if (lesson.id == 'python-interview-review') {
    return 'Support each comparison with a small example, such as a tuple containing a list to show why immutability alone does not guarantee hashability.';
  }
  return 'Validate the behavior before relying on the example. ${lesson.exercise}';
}

String _assignment(CourseModule module) {
  if (module.assignment.isNotEmpty) return module.assignment;
  return switch (module.title) {
    '1. Git Foundations' => 'Build a local repository with two focused commits and a merged feature branch. Verify the final history and explain which changes stayed unstaged.',
    '2. GitHub Collaboration' => 'Publish a feature branch, open a pull request with test evidence, and document how it was updated after review.',
    _ => throw StateError('Missing module assignment for ${module.title}'),
  };
}
