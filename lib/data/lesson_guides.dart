import 'course_models.dart';

typedef LessonResource = ({String filename, String description, String text});

class LessonGuide {
  const LessonGuide({
    required this.objective,
    required this.practice,
    required this.hints,
    required this.solution,
    required this.mistake,
    this.example,
    this.output,
    this.input,
    this.resources = const [],
    this.solutionIsCode = false,
  });

  final String objective;
  final String practice;
  final List<String> hints;
  final String solution;
  final String mistake;
  final String? example;
  final String? output;
  final String? input;
  final List<LessonResource> resources;
  final bool solutionIsCode;
}

Set<String> get lessonGuideReferenceIds => {
  ..._guides.keys,
  ..._pythonExampleOutputs.keys,
};

List<String> _sentences(String text) =>
    text.trim().split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'));

String lessonRecap(Lesson lesson) => _sentences(lesson.summary).last;

String? lessonExpectedOutput(Lesson lesson, LessonGuide guide) =>
    guide.output ?? _pythonExampleOutputs[lesson.id] ?? lesson.expectedOutput;

const _pythonExampleOutputs = <String, String>{
  'python-installation': 'The installed Python version, then 4.',
  'python-virtual-environment': 'The package list includes requests and its installed dependencies. Versions depend on the environment.',
  'python-variables': 'Mina 5',
  'python-arithmetic-operators': '27 3 2',
  'python-comparison-logic': 'True',
  'python-conditional-design': '4.0\nNone',
  'python-for-loops': '1\n2\n3\nAva\nNoah',
  'python-while-loops': '3\n2\n1',
  'python-string-basics': 'S\nSkill\nesrevllikS',
  'python-dictionaries': 'tea 3\ncoffee 4\njuice 5',
  'python-function-arguments': 'Hello, Ava',
  'python-lambda': "[('Mina', 82), ('Ava', 91)]",
  'python-modules':
      'Running the file directly prints sql. Importing it produces no output.',
  'python-packages': 'The directory containing the running source file.',
  'python-exceptions': '21',
  'python-numpy-arrays': 'A mean of approximately 0.81.',
  'python-numpy-shapes': '[[11 22]\n [13 24]]',
  'python-pandas-dataframes': 'The two rows contain Ava (91) and Noah (84). The score column has an integer dtype.',
  'python-pandas-transform':
      'Both rows pass the filter. The group means are Ava 91.0 and Noah 84.0.',
  'python-matplotlib': 'A line chart with points at (1, 12), (2, 18), and (3, 21), titled Learner growth.',
  'python-visualization':
      'A scatter plot with points at (2, 60), (4, 75), and (6, 88).',
};

LessonGuide guideForLesson(Lesson lesson) {
  final topics = lesson.topics.isEmpty
      ? lesson.title
      : lesson.topics.take(2).join(' and ');
  return _guides[lesson.id] ??
      LessonGuide(
        objective:
            'Explain the main idea in “${lesson.title}” and support it with the worked example.',
        practice:
            'Summarize the rule or procedure taught in this lesson in your own words. '
            'Then cite one line, step, or value from the example that supports your explanation.',
        hints: [
          'Start with $topics.',
          'Trace the example in order. Point to the input or condition that determines the result.',
        ],
        solution:
            '${lesson.summary}\n\nEvidence from the example\n'
            '${_pythonExampleOutputs[lesson.id] ?? lesson.expectedOutput ?? lesson.example}',
        mistake:
            'Avoid giving a result without explaining how you reached it. '
            'In this lesson, check your reasoning against this rule\n${_sentences(lesson.summary).first}',
      );
}

String cleanLessonCode(String source) {
  var lines = source.replaceAll('\r\n', '\n').split('\n');
  if (lines.isNotEmpty && lines.first.trimLeft().startsWith('```')) {
    lines = lines.skip(1).toList();
    if (lines.isNotEmpty && lines.last.trim() == '```') lines.removeLast();
  }

  final numbered = RegExp(r'^\s*(\d+)\s*[|:] ?');
  final nonempty = lines.where((line) => line.trim().isNotEmpty).toList();
  if (nonempty.length > 1 &&
      List.generate(nonempty.length, (i) => i).every(
        (i) => numbered.firstMatch(nonempty[i])?.group(1) == '${i + 1}',
      )) {
    lines = lines.map((line) => line.replaceFirst(numbered, '')).toList();
  }

  final python = RegExp(r'^\s*(?:>>>|\.\.\.) ');
  if (lines.any((line) => line.trimLeft().startsWith('>>> '))) {
    lines = lines
        .where(python.hasMatch)
        .map((line) => line.replaceFirst(python, ''))
        .toList();
  } else {
    final shell = RegExp(
      r'^\s*(?:\$ |PS [^>\n]+> |[A-Za-z]:[\\/][^>\n]*> ?|sqlite> |\.\.\.> )',
    );
    if (lines.any(shell.hasMatch)) {
      lines = [
        for (var i = 0; i < lines.length; i++)
          if (shell.hasMatch(lines[i]))
            lines[i].replaceFirst(shell, '')
          else if (i > 0 && lines[i - 1].trimRight().endsWith(r'\'))
            lines[i],
      ];
    }
  }
  while (lines.isNotEmpty && lines.first.trim().isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.trim().isEmpty) {
    lines.removeLast();
  }
  return lines.join('\n');
}

const _learnerSchema = (
  filename: 'learner_schema.sql',
  description:
      'Run once in a fresh SQLite database before running the example.',
  text: '''
CREATE TABLE courses(id INTEGER PRIMARY KEY, title TEXT NOT NULL);
CREATE TABLE learners(
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL,
  score INTEGER NOT NULL,
  course_id INTEGER
);
INSERT INTO courses VALUES (1, 'SQL'), (2, 'Python');
INSERT INTO learners VALUES
  (1, 'Ava', 79, 1), (2, 'Noah', 80, 1), (3, 'Mina', 81, 1),
  (4, 'Ravi', 92, 2), (5, 'Isha', 74, 99), (6, 'Lin', 75, NULL);
''',
);

const _scoresCsv = (
  filename: 'scores.csv',
  description: 'Keep this dataset next to the Python starter file.',
  text: 'name,score\nAva,79\nNoah,80\nMina,81\nRavi,92\n',
);

const _guides = <String, LessonGuide>{
  'python-introduction': LessonGuide(
    objective:
        'Write a Python script that prints text and evaluates arithmetic.',
    practice: 'Print your name, then calculate and print the number of days in three weeks.',
    hints: [
      'Use print() once for each line.',
      'Put your name inside quotes and use multiplication for the number of days.',
    ],
    solution: 'print("Ava")\nprint(3 * 7)',
    solutionIsCode: true,
    output: 'Hello, Skillverse\n5',
    mistake: 'Writing print("3 * 7") prints the expression as text. Leave the expression unquoted to evaluate it.',
    resources: [
      (
        filename: 'hello_starter.py',
        description:
            'Save this script and replace the two values for the exercise.',
        text: 'print("Learner")\nprint(1 * 7)\n',
      ),
    ],
  ),
  'python-first-program': LessonGuide(
    objective:
        'Save and run a .py file, then identify and correct a misspelled name.',
    practice: 'Save the example as app.py. Change print to prnt, run the file again, and fix the error.',
    hints: [
      'Run python app.py from the directory containing the file.',
      'Read the last line of the traceback. NameError identifies a name Python cannot resolve.',
    ],
    solution: 'message = "Ready to learn"\nprint(message)',
    solutionIsCode: true,
    output: 'Ready to learn',
    mistake: 'A misspelled function name creates a NameError at execution. Check the traceback line before changing surrounding code.',
  ),
  'python-function-basics': LessonGuide(
    objective: 'Write a function that returns a value its caller can use.',
    practice: 'Define total_price(price, quantity) and use it to compute the price of three items at 12 each.',
    hints: [
      'Give the function two parameters.',
      'Return the product so the caller can store or print it.',
    ],
    solution: 'def total_price(price, quantity):\n    return price * quantity\n\nprint(total_price(12, 3))',
    solutionIsCode: true,
    input: 'values = [2, 4, 6]',
    output: '4.0',
    mistake: 'Printing inside the function displays a value but leaves the caller with None. Use return for values another function needs.',
  ),
  'python-file-handling': LessonGuide(
    objective: 'Read a local CSV file with a context manager and convert text fields before comparing them.',
    example: 'import csv\n\nwith open("scores.csv", encoding="utf-8", newline="") as source:\n    for row in csv.DictReader(source):\n        print(row["name"], int(row["score"]))',
    input: 'Four learners with scores 79, 80, 81 and 92 in scores.csv.',
    output: 'Ava 79\nNoah 80\nMina 81\nRavi 92',
    practice: 'Print only the names of learners with a score of at least 80.',
    hints: [
      'Use the CSV header to access name and score by name.',
      'Convert the score with int() before applying the inclusive threshold.',
    ],
    solution: 'import csv\n\nwith open("scores.csv", encoding="utf-8", newline="") as source:\n    for row in csv.DictReader(source):\n        if int(row["score"]) >= 80:\n            print(row["name"])',
    solutionIsCode: true,
    mistake: 'CSV fields are strings. Comparing them as strings can put "100" before "80". Convert numeric columns before comparing.',
    resources: [
      _scoresCsv,
      (
        filename: 'filter_scores.py',
        description:
            'Starter script that reads the CSV without applying a filter.',
        text: 'import csv\n\nwith open("scores.csv", encoding="utf-8", newline="") as source:\n    for row in csv.DictReader(source):\n        print(row["name"])\n',
      ),
    ],
  ),
  'sql-select': LessonGuide(
    objective: 'Project named columns and use an inclusive WHERE predicate.',
    input: 'Scores include 79, 80, 81, and 92. Use learner_schema.sql to create the data.',
    output: 'Noah 80\nMina 81\nRavi 92',
    example:
        'SELECT name, score\nFROM learners\nWHERE score >= 80\nORDER BY id;',
    practice: 'Return the names and scores for learners scoring from 80 through 81, ordered by score.',
    hints: [
      'Include both boundaries in the predicate.',
      'Use score BETWEEN 80 AND 81 and add ORDER BY score.',
    ],
    solution: 'SELECT name, score\nFROM learners\nWHERE score BETWEEN 80 AND 81\nORDER BY score;',
    solutionIsCode: true,
    mistake: 'Using > 80 drops Noah’s boundary value. Test scores just below, at, and above the threshold.',
    resources: [_learnerSchema],
  ),
  'sql-joins': LessonGuide(
    objective: 'Join two tables at the intended grain and identify unmatched learners.',
    input: 'Learners Isha and Lin have no matching course key.',
    example: 'SELECT l.name, c.title\nFROM learners AS l\nJOIN courses AS c ON c.id = l.course_id\nORDER BY l.id;',
    output: 'Ava SQL\nNoah SQL\nMina SQL\nRavi Python',
    practice: 'Return only the learners who have no matching course.',
    hints: [
      'Retain all learners with LEFT JOIN.',
      'After joining, keep rows where the course primary key is NULL.',
    ],
    solution: 'SELECT l.name\nFROM learners AS l\nLEFT JOIN courses AS c ON c.id = l.course_id\nWHERE c.id IS NULL\nORDER BY l.id;',
    solutionIsCode: true,
    mistake: 'An INNER JOIN discards unmatched learners. Use LEFT JOIN when absences are part of the result.',
    resources: [_learnerSchema],
  ),
  'sql-aggregate': LessonGuide(
    objective: 'Count records at course-group grain and filter grouped totals with HAVING.',
    input: 'Course ID 1 has three learners. Other course IDs and NULL have one each.',
    example: 'SELECT course_id, COUNT(*) AS learners\nFROM learners\nGROUP BY course_id\nHAVING COUNT(*) > 2;',
    output: 'course_id 1 · learners 3',
    practice: 'Count all learners per known course ID and include only groups with more than two learners.',
    hints: [
      'Restrict course_id to values that exist in courses; this also excludes NULL.',
      'Filter aggregate counts with HAVING after GROUP BY.',
    ],
    solution: 'SELECT course_id, COUNT(*) AS learners\nFROM learners\nWHERE course_id IN (SELECT id FROM courses)\nGROUP BY course_id\nHAVING COUNT(*) > 2;',
    solutionIsCode: true,
    mistake: 'COUNT(course_id) skips NULL values. Use COUNT(*) when the measure is the number of rows.',
    resources: [_learnerSchema],
  ),
  'sql-predicates-and-null-missing-comparisons': LessonGuide(
    objective: 'Use IS NULL to count rows with missing values.',
    input: 'The example supplies two rows: 5 and NULL.',
    practice: 'Count missing and known values separately in one query.',
    hints: [
      'COUNT(n) skips NULL values.',
      'Subtract COUNT(n) from COUNT(*) to count the missing values.',
    ],
    solution: 'WITH t(n) AS (VALUES (5), (NULL))\nSELECT COUNT(*) - COUNT(n) AS missing, COUNT(n) AS known FROM t;',
    solutionIsCode: true,
    mistake: 'The predicate n = NULL evaluates to unknown. Use n IS NULL to test for missing values.',
  ),
  'sql-window-analytics-ranking': LessonGuide(
    objective: 'Rank rows within each group and break ties deterministically.',
    input: 'Group A has two scores of 20 and one of 10. Each row has a distinct ID.',
    example:
        "WITH t(g, id, n) AS (VALUES ('A', 2, 20), ('A', 1, 20), ('A', 3, 10))\n"
        "SELECT id, n, ROW_NUMBER() OVER (PARTITION BY g ORDER BY n DESC, id) AS position\n"
        "FROM t ORDER BY position;",
    output: 'id 1, score 20, position 1\nid 2, score 20, position 2\nid 3, score 10, position 3',
    practice: 'Assign positions by descending score and break equal-score ties using the smallest ID first.',
    hints: [
      'PARTITION BY g restarts numbering for each group.',
      'Order by n DESC, then id ASC inside OVER.',
    ],
    solution: "WITH t(g, id, n) AS (VALUES ('A', 2, 20), ('A', 1, 20), ('A', 3, 10))\nSELECT id, ROW_NUMBER() OVER (PARTITION BY g ORDER BY n DESC, id) AS position\nFROM t ORDER BY position;",
    solutionIsCode: true,
    mistake: 'Ordering only by score leaves ties unspecified. Add a stable unique key to the window order.',
  ),
  'python-interview-review': LessonGuide(
    objective: 'Explain an approach, state its complexity, and test boundary cases during an interview.',
    input: 'Scores [79, 80, 92, 80] and an inclusive threshold of 80.',
    example: 'scores = [79, 80, 92, 80]\nthreshold = 80\nprint(scores[0] >= threshold)\nprint(scores[1] >= threshold)',
    output: 'False\nTrue',
    practice: 'Count the scores at or above the threshold. Explain time and space costs and test an empty list.',
    hints: [
      'Read each score once and compare it to the threshold.',
      'A running count avoids a second list. Use >= so 80 is included.',
    ],
    solution: 'def count_passes(scores, threshold):\n    return sum(score >= threshold for score in scores)\n\nassert count_passes([79, 80, 92, 80], 80) == 3\nassert count_passes([], 80) == 0\n# Time O(n), additional space O(1).',
    solutionIsCode: true,
    mistake: 'Skipping the exact boundary can hide an off-by-one error. Test the threshold, one value below it, and an empty input.',
    resources: [
      (
        filename: 'interview_scores.txt',
        description: 'Inputs to use for an offline interview rehearsal.',
        text: 'scores: 79 80 92 80\nthreshold: 80\nedge case: empty list\n',
      ),
    ],
  ),
  'technical-fundamentals-tests-and-debugging-threshold-tests': LessonGuide(
    objective: 'Design boundary tests that distinguish inclusive from exclusive comparisons.',
    input: 'Delivery is free for order totals of 100 or higher; smaller totals have a fee of 5.',
    practice: 'Give three boundary test inputs and their expected fees, then explain what defect they detect.',
    hints: [
      'Choose the closest whole-number totals below and above 100.',
      'Include 100 itself to distinguish >= from >.',
    ],
    solution: '99 → 5; 100 → 0; 101 → 0. The test at 100 fails if the code uses > 100. The neighboring tests verify both fee branches.',
    mistake: 'Testing only 25 and 300 cannot reveal a wrong decision at 100. Include the boundary and its immediate neighbors.',
  ),
  'technical-fundamentals-apis-and-durability-idempotency': LessonGuide(
    objective: 'Describe how an idempotency key prevents duplicate writes when requests are retried.',
    input: 'An order API commits an order but the client times out before it receives the response.',
    practice: 'Explain what the client sends on retry and how the server prevents a second order, even if retries overlap.',
    hints: [
      'Reuse the original request key when retrying the same logical operation.',
      'Record the key and the order outcome in one transaction with a uniqueness constraint.',
    ],
    solution: 'The client reuses the same key. The server atomically claims the key, writes the order, and records its result. A duplicate request with the same payload returns that stored result. Reject reuse with a different payload.',
    mistake: 'Generating a new key on every attempt defeats deduplication. Generate one key per logical operation and store it across retries.',
  ),
  'tf-http': LessonGuide(
    objective: 'Explain how HTTP methods, resource paths, and statuses describe an API interaction.',
    input: 'A read-only API exposes GET /courses/{id}. Course 7 exists and course 9 does not.',
    example: 'GET /courses/7 → 200 OK\nGET /courses/9 → 404 Not Found',
    output: 'The first response contains the course. The second communicates that the resource cannot be found.',

    practice: 'Describe the requests and expected status for courses 7 and 9. Explain why retrying the missing resource is unlikely to help.',
    hints: [
      'Use the same read method for both resource IDs.',
      'Distinguish the success status family from the missing-resource status.',
    ],
    solution: 'GET /courses/7 returns 200 OK with the course. GET /courses/9 returns 404 Not Found. A retry with the same request still targets a missing resource unless it is created.',
    mistake: 'Treating every failed request as retryable can amplify traffic. Separate a missing resource from a transient server failure.',
    resources: [
      (
        filename: 'course_api_cases.txt',
        description:
            'Practice describing requests and responses without a server.',
        text: 'Method: GET\nPath: /courses/7\nFixture: course 7 exists; course 9 does not.\n',
      ),
    ],
  ),
  'tf-git': LessonGuide(
    objective: 'Explain how to stage and inspect a focused change before creating a commit.',
    example: 'git add README.md\ngit diff --cached -- README.md\ngit commit -m "Clarify setup instructions"',
    output: 'A new commit containing the reviewed README change.',
    practice: 'In a local repository, stage a README edit and explain how to tell whether a later edit is included.',
    hints: [
      'The next commit records the index snapshot.',
      'Compare the staged and unstaged diffs for the same file.',
    ],
    solution: 'git add README.md\ngit diff --cached -- README.md\ngit diff -- README.md',
    solutionIsCode: true,
    mistake: 'Editing a staged file does not update the index. Stage it again if the later edit belongs in the same commit.',
  ),
  'tf-security': LessonGuide(
    objective: 'Distinguish authentication from resource-level authorization in an interview scenario.',
    input: 'Account B is signed in and requests a private record owned by account A.',
    practice: 'Describe the ownership check, safe error behavior, and one negative test.',
    hints: [
      'A valid session identifies the caller but gives no proof of record ownership.',
      'Use the authenticated subject when checking which records can be accessed.',
    ],
    solution: 'Scope the lookup to the authenticated account and the requested record. If no scoped record is found, return the same missing-resource response used for an absent record. Test that account B cannot retrieve account A’s ID even while signed in.',
    mistake: 'Trusting an owner ID supplied by the caller lets users change which records they can read. Derive the owner scope from the authenticated session.',
  ),
};
