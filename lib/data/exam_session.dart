import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'course_models.dart';

String assessmentVersion(List<QuizQuestion> questions) => sha256
    .convert(utf8.encode(jsonEncode(questions.map((q) => q.toJson()).toList())))
    .toString();

class ExamDraft {
  const ExamDraft({
    required this.id,
    required this.subject,
    required this.startedAt,
    required this.deadline,
    required this.questions,
    required this.version,
    required this.answers,
    required this.marked,
    required this.index,
    this.courseId,
    this.fullCourseAssessment = false,
  });

  final String id;
  final String subject;
  final String? courseId;
  final DateTime startedAt;
  final DateTime deadline;
  final List<QuizQuestion> questions;
  final String version;
  final Map<String, int> answers;
  final Set<int> marked;
  final int index;
  final bool fullCourseAssessment;

  Duration remainingAt(DateTime now) {
    final remaining = deadline.difference(now);
    final duration = deadline.difference(startedAt);
    if (remaining.isNegative) return Duration.zero;
    return remaining > duration ? duration : remaining;
  }

  ExamDraft withProgress(
    Map<String, int> answers,
    Set<int> marked,
    int index,
  ) => ExamDraft(
    id: id,
    subject: subject,
    courseId: courseId,
    startedAt: startedAt,
    deadline: deadline,
    questions: questions,
    version: version,
    answers: Map.of(answers),
    marked: Set.of(marked),
    index: index,
    fullCourseAssessment: fullCourseAssessment,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'subject': subject,
    'courseId': courseId,
    'startedAt': startedAt.toIso8601String(),
    'deadline': deadline.toIso8601String(),
    'questions': questions.map((q) => q.toJson()).toList(),
    'version': version,
    'answers': answers,
    'marked': marked.toList(),
    'index': index,
    'fullCourseAssessment': fullCourseAssessment,
  };

  factory ExamDraft.fromJson(Map<String, dynamic> json) {
    final questions = (json['questions'] as List)
        .map((item) => QuizQuestion.fromJson(item as Map<String, dynamic>))
        .toList();
    if (questions.isEmpty || assessmentVersion(questions) != json['version']) {
      throw const FormatException('Invalid saved assessment');
    }
    final startedAt = DateTime.parse(json['startedAt'] as String);
    final deadline = DateTime.parse(json['deadline'] as String);
    if (!deadline.isAfter(startedAt)) {
      throw const FormatException('Invalid exam deadline');
    }
    final rawAnswers = Map<String, int>.from(json['answers'] as Map);
    return ExamDraft(
      id: json['id'] as String,
      subject: json['subject'] as String,
      courseId: json['courseId'] as String?,
      startedAt: startedAt,
      deadline: deadline,
      questions: questions,
      version: json['version'] as String,
      answers: {
        for (final q in questions)
          if (rawAnswers[q.id] case final choice?
              when choice >= 0 && choice < q.options.length)
            q.id: choice,
      },
      marked: (json['marked'] as List)
          .cast<int>()
          .where((i) => i >= 0 && i < questions.length)
          .toSet(),
      index: (json['index'] as int).clamp(0, questions.length - 1),
      fullCourseAssessment: json['fullCourseAssessment'] == true,
    );
  }
}
