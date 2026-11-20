import 'dart:math' as math;

import 'app_content.dart';
import 'course_models.dart';

enum LearningGoal {
  sql('SQL', 'sql', 'Start by selecting, filtering, and combining rows.'),
  python(
    'Python',
    'python',
    'Start by running a program and working with values.',
  ),
  dataInterview(
    'Data Interview',
    'data-analytics',
    'Practice explaining business metrics, data quality, and analytical findings.',
  );

  const LearningGoal(this.label, this.courseId, this.reason);
  final String label;
  final String courseId;
  final String reason;

  Course get course => courses.firstWhere((course) => course.id == courseId);
}

CourseModule? moduleForLesson(Course course, Lesson lesson) => course
    .learningModules
    .where((module) => module.lessons.any((item) => item.id == lesson.id))
    .firstOrNull;

int estimatedLessonMinutes(Lesson lesson) {
  final words = RegExp(r'\S+').allMatches(lesson.summary).length;
  final exampleLines = '\n'.allMatches(lesson.example).length + 1;
  return math.max(
    3,
    (words / 150).ceil() +
        (exampleLines / 4).ceil() +
        (lesson.exercise == null ? 1 : 4),
  );
}

String courseStudyTime(Course course) {
  if (course.duration != 'Self-paced') return course.duration;
  final minutes = course.allLessons.fold<int>(
    0,
    (total, lesson) => total + estimatedLessonMinutes(lesson),
  );
  return minutes < 60
      ? 'About $minutes min of lessons'
      : 'About ${(minutes / 60).ceil()} hr of lessons';
}

String _normalize(String text) => text
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim()
    .replaceAll(RegExp(r'\bdata\s*frames?\b'), 'dataframe');

final _searchContent = {
  for (final course in courses)
    course.id: _normalize(
      [
        course.title,
        course.description,
        ...course.tools,
        for (final module in course.learningModules) module.title,
        for (final lesson in course.allLessons) ...[
          lesson.title,
          ...lesson.topics,
        ],
      ].join(' '),
    ),
};

bool matchesCourseSearch(Course course, String query) {
  final terms = _normalize(query);
  if (terms.isEmpty) return true;
  final content = _searchContent[course.id] ?? '';
  return terms.split(' ').every((term) {
    if (term == 'pandas' || term == 'dataframe') {
      return content.contains('pandas') || content.contains('dataframe');
    }
    return content.contains(term);
  });
}

List<String> relatedCourseTopics(String query) {
  const common = [
    'SQL',
    'Python',
    'DataFrames',
    'Statistics',
    'Data Analytics',
  ];
  final normalized = _normalize(query);
  final matchingCourses = courses.where(
    (course) => matchesCourseSearch(course, query),
  );
  final related = <String>{
    if (normalized.isNotEmpty) ...matchingCourses.map((course) => course.title),
    for (final topic in common)
      if (_normalize(topic) != normalized) topic,
  };
  return related.take(4).toList();
}

List<String> prerequisiteLessonIds(Course course) => switch (course.id) {
  'python' => ['python-introduction'],
  'sql' || 'databricks' || 'power-bi' => ['sql-select'],
  'machine-learning' || 'data-science' => [
    'python-variables',
    'statistics-and-mathematics-for-data-science-descriptive-statistics-center-and-skew',
  ],
  'artificial-intelligence' => [
    'python-variables',
    'statistics-and-mathematics-for-data-science-probability-and-evidence-conditional-probability',
  ],
  'data-structures-and-algorithms' => [
    'python-function-basics',
    'python-for-loops',
  ],
  'technical-fundamentals' || 'git-and-github' => ['python-installation'],
  'pyspark' || 'big-data-technologies' => ['python-variables', 'sql-select'],
  'azure-devops' => ['python-installation', 'git-snapshots'],
  'statistics-and-mathematics-for-data-science' => ['python-variables'],
  'deep-learning' => ['python-variables', 'ml-splits'],
  'generative-ai' => ['python-variables', 'tf-http'],
  'cloud-computing' => ['tf-http', 'python-installation'],
  'data-analytics' => ['sql-select'],
  'advanced-excel' => [
    'advanced-excel-tables-and-validation-structured-references',
  ],
  _ => <String>[],
};
List<({Course course, Lesson lesson})> prerequisiteLessons(Course course) => [
  for (final id in prerequisiteLessonIds(course))
    for (final source in courses)
      for (final lesson in source.allLessons)
        if (lesson.id == id) (course: source, lesson: lesson),
];
