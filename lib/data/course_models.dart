enum CourseDifficulty {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const CourseDifficulty(this.label);
  final String label;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.summary,
    required this.example,
    this.topics = const [],
    this.expectedOutput,
    this.exercise,
    this.difficulty = CourseDifficulty.beginner,
    this.industryUse,
  });

  final String id;
  final String title;
  final String summary;
  final String example;
  final List<String> topics;
  final String? expectedOutput;
  final String? exercise;
  final CourseDifficulty difficulty;
  final String? industryUse;
}

class CourseModule {
  const CourseModule({
    this.assignment = '',
    this.questions = const [],
    this.assessmentQuestions = const [],
    this.moduleQuizQuestions = const [],
    required this.title,
    required this.summary,
    required this.lessons,
  });

  final String title;
  final String summary;
  final List<Lesson> lessons;
  final String assignment;
  final List<QuizQuestion> questions;
  final List<QuizQuestion> assessmentQuestions;
  final List<QuizQuestion> moduleQuizQuestions;
}

class Course {
  const Course({
    required this.title,
    this.lessons = const [],
    this.modules = const [],
    this.description = '',
    this.objectives = const [],
    this.prerequisites = const [],
    required this.difficulty,
    this.duration = 'Self-paced',
    this.tools = const [],
    this.capstoneProject = '',
    this.quizSubject,
    this.stableId,
  });

  final String title;
  final List<Lesson> lessons;
  final List<CourseModule> modules;
  final String description;
  final List<String> objectives;
  final List<String> prerequisites;
  final CourseDifficulty difficulty;
  String get level => difficulty.label;
  final String duration;
  final List<String> tools;
  final String capstoneProject;
  final String? quizSubject;

  final String? stableId;
  String get id => stableId ?? title.toLowerCase().replaceAll(' ', '-');

  List<QuizQuestion> get finalQuestions => [
    for (final module in modules) ...module.assessmentQuestions,
  ];

  bool matchesLevel(String level) => difficulty.label == level;

  List<Lesson> get allLessons => lessons.isNotEmpty
      ? lessons
      : modules.expand((module) => module.lessons).toList(growable: false);

  List<String> get allTopics => allLessons
      .expand((lesson) => lesson.topics)
      .toSet()
      .toList(growable: false);

  int get topicCount => allTopics.length;

  List<CourseModule> get learningModules {
    if (modules.isNotEmpty) return modules;
    final details = switch (title) {
      'Python' => (
        'Python foundations',
        'Reusable Python code',
        'Learn values, variables and core language behavior.',
        'Apply functions and collections to small programs.',
      ),
      'SQL' => (
        'Queries and relationships',
        'Aggregation and analysis',
        'Select and combine relational data.',
        'Summarize records and reason about grouped results.',
      ),
      'Machine Learning' => (
        'Model development',
        'Model evaluation',
        'Prepare data and validate model behavior.',
        'Select metrics and avoid misleading evaluations.',
      ),
      'Data Science' => (
        'Data quality and exploration',
        'Communicating findings',
        'Inspect, validate and explore source data.',
        'Explain evidence, uncertainty and next steps.',
      ),
      'Artificial Intelligence' => (
        'Search and AI concepts',
        'Responsible evaluation',
        'Represent states, actions and possible solutions.',
        'Evaluate system behavior, safety and limitations.',
      ),
      'Data Structures and Algorithms' => (
        'Core data structures',
        'Complexity and application',
        'Choose structures for the operations a problem needs.',
        'Compare algorithmic growth and practical trade-offs.',
      ),
      _ => (
        'Systems fundamentals',
        'Engineering practice',
        'Understand protocols and common system concepts.',
        'Apply collaboration and security principles.',
      ),
    };
    final splitAt = lessons.length > 1 ? lessons.length - 1 : lessons.length;
    return [
      CourseModule(
        title: details.$1,
        summary: details.$3,
        lessons: lessons.take(splitAt).toList(growable: false),
      ),
      if (lessons.length > splitAt)
        CourseModule(
          title: details.$2,
          summary: details.$4,
          lessons: lessons.skip(splitAt).toList(growable: false),
        ),
    ];
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.subject,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.explanation,
    this.difficulty = 'Basic',
    this.topic = 'Fundamentals',
  });

  final String id;
  final String subject;
  final String prompt;
  final List<String> options;
  final int answerIndex;
  final String explanation;
  final String difficulty;
  final String topic;

  String get difficultyLabel => difficulty == 'Basic' ? 'Beginner' : difficulty;

  Map<String, Object> toJson() => {
    'id': id,
    'subject': subject,
    'prompt': prompt,
    'options': options,
    'answerIndex': answerIndex,
    'explanation': explanation,
    'difficulty': difficulty,
    'topic': topic,
  };

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = List<String>.from(json['options'] as List);
    final answerIndex = json['answerIndex'] as int;
    if (answerIndex < 0 || answerIndex >= options.length) {
      throw const FormatException('Invalid answer key');
    }
    return QuizQuestion(
      id: json['id'] as String,
      subject: json['subject'] as String,
      prompt: json['prompt'] as String,
      options: List.unmodifiable(options),
      answerIndex: answerIndex,
      explanation: json['explanation'] as String,
      difficulty: json['difficulty'] as String,
      topic: json['topic'] as String,
    );
  }
}
