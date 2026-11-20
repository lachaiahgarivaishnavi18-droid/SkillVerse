import 'course_models.dart';

class LessonCompletion {
  const LessonCompletion(this.lessonId, this.completedAt);

  final String lessonId;
  final DateTime completedAt;

  Map<String, Object> toJson() => {
    'lessonId': lessonId,
    'completedAt': completedAt.toIso8601String(),
  };

  factory LessonCompletion.fromJson(Map<String, dynamic> json) =>
      LessonCompletion(
        json['lessonId'] as String,
        DateTime.parse(json['completedAt'] as String),
      );
}

class LearningActivity {
  const LearningActivity({
    required this.title,
    required this.kind,
    this.date,
    this.detail,
  });

  final String title;
  final String kind;
  final DateTime? date;
  final String? detail;
}

DateTime startOfLearningWeek(DateTime date) {
  final local = date.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day - (local.weekday - DateTime.monday),
  );
}

typedef TopicResult = ({int correct, int incorrect, int unanswered});

Map<String, TopicResult> topicResults(Iterable<(QuizQuestion, int?)> answers) {
  final results = <String, TopicResult>{};
  for (final (question, selected) in answers) {
    final current =
        results[question.topic] ?? (correct: 0, incorrect: 0, unanswered: 0);
    results[question.topic] = (
      correct: current.correct + (selected == question.answerIndex ? 1 : 0),
      incorrect:
          current.incorrect +
          (selected != null && selected != question.answerIndex ? 1 : 0),
      unanswered: current.unanswered + (selected == null ? 1 : 0),
    );
  }
  return results;
}
