import 'course_models.dart';
import 'interview_hr.dart';
import 'interview_scenarios.dart';

class InterviewQuestion {
  const InterviewQuestion({
    required this.id,
    required this.category,
    required this.difficulty,
    required this.question,
    required this.answer,
    required this.explanation,
    this.code,
    this.output,
    this.topic = 'Fundamentals',
    this.example,
  });

  final String id;
  final String category;
  final String difficulty;
  final String question;
  final String answer;
  final String explanation;
  final String topic;
  final String? example;
  final String? code;
  final String? output;
}

const interviewCategories = [
  'Python',
  'SQL',
  'Machine Learning',
  'Data Science',
  'Artificial Intelligence',
  'Deep Learning',
  'Statistics',
  'Data Structures and Algorithms',
  'Data Analytics',
  'Power BI',
  'Excel',
  'Databricks',
  'PySpark',
  'Azure DevOps',
  'Generative AI',
  'HR Interview Questions',
  'Technical Questions',
];

String _category(String category) => switch (category) {
  'Python Programming' => 'Python',
  'Statistics and Mathematics for Data Science' => 'Statistics',
  'Advanced Excel' => 'Excel',
  'HR and Interview Questions' => 'HR Interview Questions',
  'Technical Fundamentals' => 'Technical Questions',
  _ => category,
};

String _slug(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

const _legacyExamples = <String, String>{
  'py-gil': 'In standard GIL-enabled CPython, threads can wait on several HTTP requests concurrently, while CPU-bound Python loops may need multiple processes for parallelism.',
  'sql-join': 'A left join from customers to orders includes a customer with no orders, with NULL for the order ID.',
  'sql-index': 'An index on Orders(customer_id, created_at) may speed up customer history queries and add work to every order insert.',
  'ml-overfit': 'A deep tree has 99% training accuracy and 71% held-out accuracy. Try shallower trees and compare validation results.',
  'ml-leakage': 'A model that predicts a missed payment cannot use a collections status assigned after the payment deadline.',
  'ml-precision-recall': 'For document review, recall matters when missing a required clause is riskier than asking someone to review a false alert.',
  'ml-regularization':
      'An L1 penalty can set weak predictors to zero in a linear model.',
  'ml-crossval': 'Group customer transactions by customer so no customer appears in both training and validation within one fold.',
  'tech-http': 'GET /orders/42 reads an order. POST /orders submits a new order to be created.',
  'tech-api': 'Sending the same PUT with status shipped twice leaves the order in the same intended state.',
  'tech-index': 'A transfer debits one account and credits the other within one transaction, rolling back both when an update fails.',
  'tech-authz': 'Signing in establishes identity. A role check determines whether that identity can approve a refund.',
  'tech-cache': 'Delete an old inventory cache key after committing a stock change so the next read loads updated inventory.',
  'hr-conflict': 'We disagreed on how to sort overdue work, compared two views with support staff and adopted the one that highlighted urgent cases.',
  'hr-failure': 'I used a stale file for a report, alerted recipients, corrected the result and added a freshness check.',
  'hr-motivation': 'I enjoyed finding errors in club budget reports, and this role would let me develop that skill in recurring financial analysis.',
  'hr-priority': 'I explained the impact of two conflicting deadlines and agreed with the owners to deliver a validated summary before the detailed export.',
  'hr-feedback': 'A reviewer asked for clearer assumptions. I added a short assumptions block and checked in after the following review.',
};

List<InterviewQuestion> buildInterviewBank(
  List<InterviewQuestion> legacy,
  List<Course> courses,
) {
  final bank = [
    for (final q in legacy)
      InterviewQuestion(
        id: q.id,
        category: _category(q.category),
        topic: q.topic,
        difficulty: q.difficulty == 'Basic' ? 'Beginner' : q.difficulty,
        question: q.question,
        answer: q.answer,
        explanation: q.explanation,
        example: _legacyExamples[q.id],
        code: q.code,
        output: q.output,
      ),
    for (final entry in {
      ...interviewScenarios,
      'HR Interview Questions': hrScenarios,
    }.entries)
      for (final row in entry.value.trim().split('\n'))
        _scenario(entry.key, row),
    for (final course in courses)
      if (interviewCategories.contains(_category(course.title)))
        for (final module in course.learningModules) ...[
          for (final lesson in module.lessons)
            if (lesson.example.isNotEmpty && lesson.expectedOutput != null) ...[
              _lessonQuestion(_category(course.title), lesson),
              if (lesson.exercise?.isNotEmpty == true)
                _exerciseQuestion(_category(course.title), lesson),
            ],
          if (module.questions.isNotEmpty)
            _conceptQuestion(
              _category(course.title),
              module,
              module.questions.first,
            ),
          for (final question in module.assessmentQuestions)
            _conceptQuestion(_category(course.title), module, question),
        ],
  ];
  final prompts = <String>{};
  return List.unmodifiable(
    bank.where(
      (q) => prompts.add(
        q.question.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      ),
    ),
  );
}

InterviewQuestion _scenario(String category, String row) {
  final fields = row.split(' | ');
  if (fields.length != 6 || fields.any((field) => field.isEmpty)) {
    throw FormatException('Expected six interview question fields', row);
  }
  return InterviewQuestion(
    id: 'scenario-${_slug(category)}-${_slug(fields[2])}',
    category: category,
    difficulty: fields[0],
    topic: fields[1],
    question: fields[2],
    answer: fields[3],
    explanation: fields[4],
    example: fields[5],
  );
}

InterviewQuestion _lessonQuestion(
  String category,
  Lesson lesson,
) => InterviewQuestion(
  id: 'worked-${lesson.id}',
  category: category,
  difficulty: lesson.difficulty.label,
  topic: lesson.title,
  question:
      'Walk through the ${lesson.title} example below. What result should it produce, and why?',
  answer: '${lesson.expectedOutput}\n\n${lesson.summary}',
  explanation: lesson.summary.split(RegExp(r'(?<=\.)\s')).first,
  code: lesson.example,
  output: lesson.expectedOutput,
  example: lesson.industryUse,
);

InterviewQuestion _exerciseQuestion(String category, Lesson lesson) =>
    InterviewQuestion(
      id: 'applied-${lesson.id}',
      category: category,
      difficulty: lesson.difficulty.label,
      topic: lesson.title,
      question:
          'For ${lesson.title}, describe your approach to this task '
          'and how you would check it.\n\n${lesson.exercise}',
      answer:
          '${lesson.summary}\n\nFirst check the worked example against '
          'its expected result, then apply the same rule to the changed '
          'inputs in the task and explain what should stay true.',
      explanation:
          'Baseline check: ${lesson.expectedOutput}\n\n'
          'Use that known result to isolate the effect of the change.',
      example: lesson.industryUse,
      code: lesson.example,
    );

InterviewQuestion _conceptQuestion(
  String category,
  CourseModule module,
  QuizQuestion question,
) => InterviewQuestion(
  id: 'interview-concept-${question.id}',
  category: category,
  difficulty: question.difficulty == 'Basic' ? 'Beginner' : question.difficulty,
  topic: module.title,
  question: question.prompt,
  answer: question.options[question.answerIndex],
  explanation: question.explanation,
  example: module.assignment.isEmpty ? module.summary : module.assignment,
);
