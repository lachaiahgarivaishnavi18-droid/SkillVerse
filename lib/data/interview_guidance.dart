import 'interview_questions.dart';
import 'interview_roles.dart';

const interviewGuidanceNotice =
    'Rule-based keyword guidance checks for concept phrases and common synonyms. Review the reference to judge whether your reasoning is correct.';

class InterviewGuidance {
  const InterviewGuidance(this.mentioned, this.missing);

  final List<String> mentioned;
  final List<String> missing;
}

String _words(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

bool _mentions(String normalized, String term) =>
    ' $normalized '.contains(' ${_words(term)} ');

List<InterviewConcept> interviewConceptsFor(InterviewQuestion question) {
  if (roleInterviewById[question.id] case final entry?) return entry.concepts;

  final reference = _words('${question.answer} ${question.explanation}');
  final matched = [
    for (final concept in _referenceConcepts)
      if (concept.terms.any((term) => _mentions(reference, term))) concept,
  ].take(4).toList();
  if (matched.isNotEmpty) return matched;

  final topic = _words(question.topic);
  if (topic.isEmpty ||
      topic == 'fundamentals' ||
      !_mentions(reference, topic)) {
    return const [];
  }
  return [
    (label: question.topic, terms: [topic]),
  ];
}

InterviewGuidance interviewGuidance(InterviewQuestion question, String answer) {
  final normalized = _words(answer);
  final mentioned = <String>[];
  final missing = <String>[];
  for (final concept in interviewConceptsFor(question)) {
    final found = concept.terms.any((term) => _mentions(normalized, term));
    (found ? mentioned : missing).add(concept.label);
  }
  return InterviewGuidance(mentioned, missing);
}

String interviewFollowUp(InterviewQuestion question) {
  if (roleInterviewById[question.id] case final entry?) return entry.followUp;
  if (question.category == 'HR Interview Questions') {
    return 'What would you do differently in the same situation, and how would you measure the result?';
  }
  final concepts = interviewConceptsFor(question);
  final topic =
      concepts.firstOrNull?.label ??
      (question.topic == 'Fundamentals' ? 'this approach' : question.topic);
  return 'What boundary case would you test for $topic, and what result would you expect?';
}

List<String> interviewKeyPoints(InterviewQuestion question) {
  final points = question.answer.trim().split(
    RegExp(r'(?<=[.!?])\s+(?=[A-Z])|\n\s*\n'),
  );
  return points.where((point) => point.isNotEmpty).toList();
}

const _referenceConcepts = <InterviewConcept>[
  (
    label: 'NULL handling',
    terms: ['null', 'is null', 'missing value', 'missing values'],
  ),
  (
    label: 'Join cardinality',
    terms: ['fanout', 'one to many', 'join cardinality', 'join grain'],
  ),
  (
    label: 'Unique key',
    terms: ['primary key', 'unique key', 'unique identifier', 'business key'],
  ),
  (
    label: 'Window function',
    terms: ['window function', 'row_number', 'row number', 'partition by'],
  ),
  (
    label: 'Transaction',
    terms: ['transaction', 'transactions', 'atomic commit', 'atomicity'],
  ),
  (label: 'Index', terms: ['index', 'indexes', 'indexing']),
  (
    label: 'Idempotency',
    terms: ['idempotency', 'idempotent', 'retry safe', 'retry-safe'],
  ),
  (
    label: 'Validation split',
    terms: ['validation set', 'validation split', 'holdout', 'held out'],
  ),
  (
    label: 'Data leakage',
    terms: [
      'data leakage',
      'target leakage',
      'future information',
      'look-ahead',
    ],
  ),
  (label: 'Precision', terms: ['precision', 'positive predictive value']),
  (label: 'Recall', terms: ['recall', 'sensitivity', 'true positive rate']),
  (
    label: 'Regularization',
    terms: ['regularization', 'regularisation', 'l1 penalty', 'l2 penalty'],
  ),
  (
    label: 'Confidence interval',
    terms: [
      'confidence interval',
      'confidence intervals',
      'uncertainty interval',
    ],
  ),
  (
    label: 'Hash-based lookup',
    terms: ['hash table', 'hash map', 'hash set', 'hashing'],
  ),
  (
    label: 'Time complexity',
    terms: ['time complexity', 'big o', 'runtime complexity'],
  ),
  (label: 'Mutability', terms: ['mutable', 'immutable', 'mutability']),
  (
    label: 'Context manager',
    terms: ['context manager', 'with open', 'with statement'],
  ),
  (
    label: 'Authorization',
    terms: [
      'authorization',
      'authorisation',
      'access control',
      'permission check',
    ],
  ),
  (label: 'Backoff', terms: ['exponential backoff', 'retry backoff', 'jitter']),
  (
    label: 'Version control',
    terms: ['version control', 'source control', 'git'],
  ),
  (
    label: 'Partition pruning',
    terms: ['partition pruning', 'partition elimination'],
  ),
  (label: 'Shuffle', terms: ['shuffle', 'shuffling', 'shuffle partition']),
  (
    label: 'DataFrame',
    terms: ['dataframe', 'data frame', 'dataframes', 'data frames'],
  ),
  (
    label: 'Situation and actions',
    terms: ['star method', 'star format', 'situation task action result'],
  ),
  (label: 'Rollback', terms: ['rollback', 'roll back', 'revert']),
  (label: 'Grounding', terms: ['grounding', 'grounded', 'evidence citation']),
];
