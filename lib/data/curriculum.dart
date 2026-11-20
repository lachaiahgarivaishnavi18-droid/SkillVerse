import 'course_models.dart';
import 'module_question_bank.dart';
import 'curriculum_analytics.dart';
import 'curriculum_engineering.dart';
import 'curriculum_ml.dart';
import 'curriculum_systems.dart';
import 'curriculum_neural.dart';
import 'curriculum_infrastructure.dart';
import 'curriculum_reporting.dart';
import 'curriculum_established.dart';

final _syllabi = {
  ...analyticsSyllabi,
  ...engineeringSyllabi,
  ...mlSyllabi,
  ...systemsSyllabi,
  ...neuralSyllabi,
  ...infrastructureSyllabi,
  ...reportingSyllabi,
};

List<Course> buildCurriculum(List<Course> existing) {
  final pending = Map.of(_syllabi);
  return [
    for (final course in existing)
      _expand(course, pending.remove(course.title)),
    for (final entry in pending.entries)
      _expand(
        Course(title: entry.key, difficulty: _catalogDifficulty(entry.key)),
        entry.value,
      ),
  ];
}

// Catalog difficulty reflects prerequisites and the overall project scope.
CourseDifficulty _catalogDifficulty(String title) => switch (title) {
  'Statistics and Mathematics for Data Science' ||
  'Data Analytics' => CourseDifficulty.beginner,
  'Power BI' || 'Cloud Computing' => CourseDifficulty.intermediate,
  'Advanced Excel' ||
  'Deep Learning' ||
  'Generative AI' ||
  'Big Data Technologies' => CourseDifficulty.advanced,
  _ => throw ArgumentError.value(title, 'title', 'Assign a catalog difficulty'),
};

Course _expand(Course source, String? syllabus) {
  final authored = syllabus == null ? null : _parse(source, syllabus);
  final legacy = establishedModules[source.title];
  final modules =
      authored?.modules ??
      (legacy != null
          ? _enrichEstablished(source, legacy)
          : source.learningModules);
  return Course(
    title: source.title == 'Python' ? 'Python Programming' : source.title,
    stableId: source.id,
    description: authored?.description ?? source.description,
    difficulty: source.difficulty,
    duration: authored == null ? source.duration : 'Self-paced',
    objectives: authored?.objectives ?? source.objectives,
    prerequisites: authored?.prerequisites ?? source.prerequisites,
    tools: authored?.tools ?? source.tools,
    capstoneProject: authored?.capstone ?? source.capstoneProject,
    quizSubject: source.quizSubject ?? source.title,
    modules: buildModuleQuestionBanks(source, modules),
  );
}

typedef _Syllabus = ({
  String description,
  List<String> objectives,
  List<String> prerequisites,
  List<String> tools,
  String capstone,
  List<CourseModule> modules,
});

List<String> _fields(String row, int length) {
  final fields = row.split(' | ');
  if (fields.length != length || fields.any((field) => field.isEmpty)) {
    throw FormatException('Expected $length curriculum fields', row);
  }
  return fields;
}

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-|-$'), '');

CourseDifficulty _stage(int index, int count) {
  if (index * 3 < count) return CourseDifficulty.beginner;
  if (index * 3 < count * 2) return CourseDifficulty.intermediate;
  return CourseDifficulty.advanced;
}

_Syllabus _parse(Course source, String syllabus) {
  final sections = syllabus.trim().split('\n# ');
  final metadata = _fields(sections.first, 7);
  final modules = <CourseModule>[];
  final placements = _legacyModuleIndexes[source.title];
  for (var i = 1; i < sections.length; i++) {
    final rows = sections[i].trim().split('\n');
    final header = _fields(rows.first, 3);
    final difficulty = _stage(i - 1, sections.length - 1);
    final moduleId = '${source.id}-${_slug(header[0])}';
    final lessons = <Lesson>[
      for (var j = 0; j < source.lessons.length; j++)
        if (placements?[j] == i - 1)
          _enrichLegacyLesson(source.lessons[j], difficulty, header[1]),
      for (final row in rows.skip(1).takeWhile((row) => !row.startsWith('? ')))
        _parseLesson(moduleId, difficulty, row),
    ];
    final questions = rows.where((row) => row.startsWith('? ')).toList();
    if (questions.length != 2 || lessons.length < 2) {
      throw FormatException('Incomplete course module', header[0]);
    }
    modules.add(
      CourseModule(
        title: '$i. ${header[0]}',
        summary: header[1],
        assignment: header[2],
        lessons: List.unmodifiable(lessons),
        questions: [
          _parseQuestion(source, moduleId, difficulty, questions[0], false),
        ],
        assessmentQuestions: [
          _parseQuestion(source, moduleId, difficulty, questions[1], true),
        ],
      ),
    );
  }
  return (
    description: metadata[0],
    objectives: metadata.sublist(1, 4),
    prerequisites: [metadata[4]],
    tools: metadata[5].split(', '),
    capstone: metadata[6],
    modules: List.unmodifiable(modules),
  );
}

const _legacyModuleIndexes = {
  'SQL': [0, 2, 3],
  'Machine Learning': [0, 2, 3],
  'Data Science': [1, 2, 7],
  'Artificial Intelligence': [1, 6, 7],
  'Data Structures and Algorithms': [1, 2, 0],
  'Technical Fundamentals': [0, 2, 6],
};

Lesson _parseLesson(String moduleId, CourseDifficulty difficulty, String row) {
  final fields = _fields(row, 7);
  return Lesson(
    id: '$moduleId-${_slug(fields[0])}',
    title: fields[0],
    summary: fields[1],
    topics: fields[2].split('; '),
    example: fields[3].replaceAll(r'\n', '\n'),
    expectedOutput: fields[4],
    industryUse: fields[5],
    exercise: fields[6],
    difficulty: difficulty,
  );
}

QuizQuestion _parseQuestion(
  Course course,
  String moduleId,
  CourseDifficulty level,
  String row,
  bool finalExam,
) {
  final fields = _fields(row.substring(2), 5);
  final options = fields.sublist(1, 4);
  final correct = options.removeAt(0);
  final answerIndex =
      moduleId.codeUnits.fold(finalExam ? 1 : 0, (a, b) => a + b) % 3;
  options.insert(answerIndex, correct);
  return QuizQuestion(
    id: '$moduleId-${finalExam ? 'final' : 'practice'}',
    subject: course.quizSubject ?? course.title,
    prompt: fields[0],
    options: List.unmodifiable(options),
    answerIndex: answerIndex,
    explanation: fields[4],
    difficulty: level == CourseDifficulty.beginner ? 'Basic' : level.label,
  );
}

List<CourseModule> _enrichEstablished(Course course, String content) {
  final rows = content.trim().split('\n');
  if (rows.length != course.modules.length * 3) {
    throw FormatException('Check module assessments for ${course.title}');
  }
  return [
    for (var i = 0; i < course.modules.length; i++)
      _establishedModule(course, i, rows.sublist(i * 3, i * 3 + 3)),
  ];
}

CourseModule _establishedModule(Course course, int index, List<String> rows) {
  final module = course.modules[index];
  final id = '${course.id}-module-${index + 1}';
  final level = module.title.startsWith('Beginner')
      ? CourseDifficulty.beginner
      : module.title.startsWith('Intermediate')
      ? CourseDifficulty.intermediate
      : module.title.startsWith('Advanced')
      ? CourseDifficulty.advanced
      : _stage(index, course.modules.length);
  final details = _fields(rows[0], 4);
  return CourseModule(
    title: module.title,
    summary: module.summary,
    lessons: [
      for (var i = 0; i < module.lessons.length; i++)
        _enrichLegacyLesson(
          module.lessons[i],
          level,
          details[3],
          expected: details[i == 0 ? 1 : 2],
        ),
    ],
    assignment: details[0],
    questions: [_parseQuestion(course, id, level, rows[1], false)],
    assessmentQuestions: [_parseQuestion(course, id, level, rows[2], true)],
  );
}

Lesson _enrichLegacyLesson(
  Lesson lesson,
  CourseDifficulty difficulty,
  String use, {
  String? expected,
}) => Lesson(
  id: lesson.id,
  title: lesson.title,
  summary: lesson.summary,
  example: lesson.example,
  topics: lesson.topics.isEmpty ? [lesson.title] : lesson.topics,
  expectedOutput:
      _legacyOutcomes[lesson.id] ?? lesson.expectedOutput ?? expected,
  exercise: lesson.exercise ?? _legacyExercises[lesson.id],
  difficulty: difficulty,
  industryUse: use,
);

const _legacyOutcomes = {
  'python-types': '12 0.75 True None',
  'python-if-else': 'B',
  'python-conditional-design': '4.0 then None on separate lines.',
  'python-recursion': '120',
  'python-classes-objects': 'Course: SQL',
  'python-encapsulation': '80.0',
  'python-inheritance': 'SQL 60',
  'python-polymorphism': 'Lesson content',
  'python-capstone': '0.75',
  'python-for-loops': '1, 2, 3, Ava and Noah, each on a separate line.',
  'python-while-loops': '3, 2, 1 on separate lines.',
  'python-string-basics': 'S, Skill and esrevllikS on separate lines.',
  'python-string-methods': 'PYTHON | SQL',
  'python-lists': '[81, 90, 88]',
  'python-tuples': '4 7 [4, 6]',
  'python-sets': "{'sql'} then {'python'}",
  'python-dictionaries': 'tea 3, coffee 4, juice 5 on separate lines.',
  'sql-select': 'Names and scores of learners whose score is at least 80; source table learners must exist.',
  'sql-joins': 'Related rows are combined using their matching key.',
  'sql-aggregate': 'One result per group with its aggregate value.',
  'ml-splits': 'Distinct training, validation and final test data.',
  'ml-overfit':
      'Compare train and validation quality to identify a generalization gap.',
  'ml-metrics': 'Calculate the metric for the stated operational cost.',
  'ds-cleaning': 'Invalid and missing inputs are reported before analysis.',
  'ds-eda': 'The selected summaries describe numeric data shape.',
  'ds-communication':
      'A scoped finding with an explicit limitation and action.',
  'ai-search': 'A sequence of permitted states and actions toward the goal.',
  'ai-ethics': 'A risk review covering the affected stakeholders.',
  'ai-evaluation': 'A task-specific evaluation with held-out scenarios.',
  'ds-hash': 'Hash-based lookup finds a stored value for a matching key.',
  'ds-stack-queue': 'Stack is LIFO; queue is FIFO.',
  'ds-complexity': 'Operation growth is expressed in relation to input size.',
  'tf-http': 'A response status and body under the requested method.',
  'tf-git': 'A reviewed source change recorded in version history.',
  'tf-security': 'Only validated and authorized actions are allowed.',
};
const _legacyExercises = {
  'sql-select': 'Create five learners with names and scores including 79, 80 and 81, then verify which names the predicate selects.',
  'sql-joins': 'Build learners and courses with one unmatched learner course_id, then compare inner and left joins.',
  'sql-aggregate': 'Count learners by course, verify groups with more than two learners, and test a NULL course_id.',
  'ml-splits': 'Design a time-based training, validation and test split and check dates do not overlap.',
  'ml-overfit': 'Compare training and validation curves for a shallow and an unrestricted tree.',
  'ml-metrics': 'Calculate precision and recall for TP12, FP4 and FN8 and justify a priority.',
  'ds-cleaning': 'Create a table with duplicate IDs and a missing amount, then produce an exception list.',
  'ds-eda': 'Compare mean, median and range for a dataset containing one large outlier.',
  'ds-communication': 'Write a finding with population, effect size, uncertainty and an owned next action.',
  'ai-search': 'Implement BFS for a four-node cyclic graph and return the path or an unreachable result.',
  'ai-ethics': 'List who can be harmed by a routing error and define an escalation policy.',
  'ai-evaluation': 'Construct ten held-out cases including unsupported and ambiguous requests.',
  'ds-hash': 'Count event frequencies with a dictionary and state time and space complexity.',
  'ds-stack-queue': 'Simulate three incoming tasks using a stack and a deque; compare processing order.',
  'ds-complexity': 'Measure linear and quadratic functions at n=100,200,400 and compare growth.',
  'tf-http': 'Document success, missing-resource and invalid-input responses for a local endpoint.',
  'tf-git':
      'Stage a focused local change and inspect the diff before committing.',
  'tf-security': 'Test account ownership and input validation for an endpoint using bound SQL parameters.',
};
