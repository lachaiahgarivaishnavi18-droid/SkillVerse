class InterviewResponse {
  const InterviewResponse(this.text, this.correct, {this.previousText});

  final String text;
  final bool? correct;
  final String? previousText;

  Map<String, dynamic> toJson() => {
    'text': text,
    'correct': correct,
    if (previousText != null) 'previousText': previousText,
  };

  factory InterviewResponse.fromJson(Map<String, dynamic> json) =>
      InterviewResponse(
        json['text'] as String,
        json['correct'] as bool?,
        previousText: json['previousText'] as String?,
      );
}

class InterviewAttempt {
  const InterviewAttempt({
    required this.id,
    required this.category,
    required this.mode,
    required this.track,
    required this.completedAt,
    required this.durationSeconds,
    required this.questionIds,
    required this.responses,
    this.timed = true,
  });

  final String id;
  final String category;
  final String mode;
  final String track;
  final DateTime completedAt;
  final int durationSeconds;
  final bool timed;
  final List<String> questionIds;
  final Map<String, InterviewResponse> responses;

  int get correct =>
      responses.values.where((item) => item.correct == true).length;
  int get incorrect =>
      responses.values.where((item) => item.correct == false).length;
  int get unanswered => questionIds.length - correct - incorrect;
  int get score =>
      questionIds.isEmpty ? 0 : (100 * correct / questionIds.length).round();

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'mode': mode,
    'track': track,
    'completedAt': completedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'timed': timed,
    'questionIds': questionIds,
    'responses': responses.map(
      (id, response) => MapEntry(id, response.toJson()),
    ),
  };

  factory InterviewAttempt.fromJson(Map<String, dynamic> json) =>
      InterviewAttempt(
        id: json['id'] as String,
        category: json['category'] as String,
        mode: json['mode'] as String,
        track: json['track'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
        durationSeconds: json['durationSeconds'] as int,
        timed: json['timed'] as bool? ?? true,
        questionIds: (json['questionIds'] as List).cast<String>(),
        responses: (json['responses'] as Map<String, dynamic>).map(
          (id, value) => MapEntry(
            id,
            InterviewResponse.fromJson(value as Map<String, dynamic>),
          ),
        ),
      );
}

class InterviewDraft {
  const InterviewDraft({
    required this.id,
    required this.questionIds,
    required this.questionIndex,
    required this.durationSeconds,
    required this.answers,
    required this.responses,
    this.previousAnswers = const {},
  });

  final String id;
  final List<String> questionIds;
  final int questionIndex;
  final int durationSeconds;
  final Map<String, String> answers;
  final Map<String, String> previousAnswers;
  final Map<String, InterviewResponse> responses;

  Map<String, dynamic> toJson() => {
    'id': id,
    'questionIds': questionIds,
    'questionIndex': questionIndex,
    'durationSeconds': durationSeconds,
    'answers': answers,
    'previousAnswers': previousAnswers,
    'responses': responses.map((key, value) => MapEntry(key, value.toJson())),
  };

  factory InterviewDraft.fromJson(Map<String, dynamic> json) => InterviewDraft(
    id: json['id'] as String,
    questionIds: List<String>.from(json['questionIds'] as List),
    questionIndex: json['questionIndex'] as int,
    durationSeconds: json['durationSeconds'] as int,
    answers: Map<String, String>.from(json['answers'] as Map),
    previousAnswers: Map<String, String>.from(
      json['previousAnswers'] as Map? ?? const {},
    ),
    responses: (json['responses'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        InterviewResponse.fromJson(value as Map<String, dynamic>),
      ),
    ),
  );
}
