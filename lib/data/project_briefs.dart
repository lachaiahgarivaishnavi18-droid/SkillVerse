import 'course_models.dart';

class ProjectBrief {
  const ProjectBrief({
    required this.course,
    required this.title,
    required this.requirements,
    required this.deliverables,
    required this.criteria,
    required this.relatedLessons,
  });

  final Course course;
  final String title;
  final List<String> requirements;
  final List<String> deliverables;
  final List<String> criteria;
  final List<Lesson> relatedLessons;

  String get objective =>
      course.capstoneProject.isNotEmpty ? course.capstoneProject : '.';
}

ProjectBrief? projectBriefFor(Course course) {
  final row = _details[course.id];
  if (row == null) return null;
  final [title, requirements, deliverables, criteria, keywords] = row.split(
    ' | ',
  );
  final related = <Lesson>{};
  for (final phrase in keywords.split(', ')) {
    final match = course.allLessons
        .where(
          (lesson) =>
              lesson.title.toLowerCase().contains(phrase) ||
              lesson.topics.any(
                (topic) => topic.toLowerCase().contains(phrase),
              ),
        )
        .firstOrNull;
    if (match != null) related.add(match);
  }
  return ProjectBrief(
    course: course,
    title: title,
    requirements: requirements.split(' / '),
    deliverables: deliverables.split(' / '),
    criteria: criteria.split(' / '),
    relatedLessons: related.toList(),
  );
}

const _details = {
  'python': 'Learning progress analyzer | Stream a CSV of learner records and report malformed rows with line numbers / Compute completion rates and handle empty totals explicitly | Command-line script and example report / Fixture CSV and tests for missing values and zero totals | Results agree with the fixture by hand / Errors preserve valid records and output is reproducible | files, functions, exceptions',
  'sql': 'Monthly sales mart | Build a table at order-line grain and reconcile daily totals to raw sales / Use a unique date key for a retry-safe load and rank customers deterministically | SQLite schema and seed script / Reporting queries and reconciliation notes | Repeating a load keeps row counts and totals unchanged / Ties and unmatched joins have documented behavior | keys, ranking, upsert',
  'machine-learning': 'Churn model evaluation | Split observations by prediction time and fit preprocessing on training data / Compare a baseline and candidate using metrics at a documented capacity | Reproducible training and evaluation code / Holdout metrics, threshold rationale, and monitoring plan | Features are available at scoring time / The chosen threshold respects capacity on validation | train, threshold, baselines',
  'data-science': 'Subscription retention investigation | Validate user identifiers and observation windows before computing retention / Quantify uncertainty and separate missing data from non-returning users | Reproducible notebook or script / Cohort table, data quality report, and decision memo | Eligibility and denominators reconcile to source records / Limitations and recommended action follow from the data | cohort, data quality, population',
  'artificial-intelligence': 'Dispatch planner | Model routes and hard constraints before comparing search strategies / Include an unreachable case, an explainable decision, and an escalation path | Planner with fixture graphs / Search comparison and failure review | Returned routes obey all constraints / Unreachable requests produce a reproducible fallback | search, constraints, evaluation',
  'data-structures-and-algorithms': 'Route and scheduling toolkit | Choose data structures appropriate to route lookups and task ordering / Benchmark increasing input sizes and document time and space costs | Toolkit source and reproducible benchmark / Tests for empty inputs, cycles, and equal priorities | Results match known fixtures / Complexity claims are supported by measurements | complexity, graph, priority',
  'technical-fundamentals': 'Reliable local endpoint | Document status codes and resource-level access for an endpoint / Test invalid inputs and record a recovery procedure | Local implementation and route contract / Boundary tests and a short incident runbook | Cross-account access is rejected by tests / The runbook includes a rollback or recovery check | http, validation, authorization',
  'databricks': 'Lakehouse ingestion pipeline | Load raw events into a staged and validated representation / Deduplicate by event key and verify retry behavior on the published table | Notebook or local Spark equivalent / Fixture events, quality checks, and reconciliation report | Replaying the fixture creates no duplicates / Control totals reconcile to the validated source | lakehouse, delta, merge',
  'pyspark': 'Distributed data quality report | Enforce a schema and isolate invalid rows / Aggregate at a defined grain and explain observed shuffle or skew | Runnable Spark job and a small input fixture / Row-count report and execution-plan notes | Valid and rejected rows reconcile to input size / Aggregates handle missing keys and duplicate records | schema, join, partition',
  'azure-devops': 'Repeatable delivery pipeline | Build one immutable artifact and promote the same artifact through stages / Define a validation gate and show recovery after a failed deployment | Pipeline YAML or a local demonstrator / Stage diagram, test evidence, and rollback checklist | The promoted artifact can be traced to a tested revision / A failed validation prevents promotion | delivery, artifacts, approvals',
  'git-and-github': 'Reviewable project workflow | Make a focused branch change and inspect its staged diff / Resolve a controlled conflict and record how the merged result was tested | Local repository with reviewable commits / Conflict notes and a reproducible verification command | Commits isolate intentional changes / Integrated behavior passes documented checks | commits, branches, merge',
  'statistics-and-mathematics-for-data-science': 'Experiment decision memo | Define the comparison and eligible sample before analyzing the outcome / Report uncertainty and account for repeated comparisons when applicable | Analysis notebook or script / Interval estimates and a decision memo | Estimates use the correct unit of analysis / The recommendation accounts for uncertainty and practical effect size | confidence, probability, comparison',
  'deep-learning': 'Neural model evaluation lab | Record tensor shapes and validate the training and inference paths / Compare candidate results with reproducible settings and a baseline | CPU-runnable training and evaluation code / Metrics and a failure-case review | Shapes and evaluation mode are checked / Test measurements are reproducible and separated from tuning | batch, gradients, evaluation',
  'generative-ai': 'Evidence-grounded answer evaluation | Define a fixed set of questions with expected evidence passages / Check unsupported claims and specify when the system should abstain | Evaluation fixtures and rubric / Scored examples with an error analysis | Claims are checked against their cited passages / Abstentions and missing evidence are counted explicitly | evidence, retrieval, evaluation',
  'cloud-computing': 'Resilient deployment design | Draw service boundaries and identify dependencies between zones / Document availability assumptions, recovery procedures, and cost trade-offs | Architecture diagram and deployment checklist / Failure simulation notes or a local walkthrough | Failure scenarios cover dependencies and routing / Recovery acceptance criteria are measurable | regions, responsibility, availability',
  'big-data-technologies': 'Partitioned analytics workload | Compare how two storage layouts affect a date-filtered query / Keep inputs equivalent and record the scan volume and plan | Repeatable query and fixture build scripts / Layout comparison with performance evidence | Results agree across layouts / Plan and scan evidence support the pruning claim | partition, columnar, formats',
  'data-analytics': 'Business KPI investigation | Define eligible users, reporting period, and metric grain / Reconcile the source and analyze a segmented change before recommending action | KPI contract and reproducible query or workbook / Dashboard mockup and decision memo | Numerators and denominators reconcile / The memo distinguishes findings from limitations | kpi, metrics, deduplication',
  'power-bi': 'Sales reporting model | Build facts and dimensions with documented relationships / Validate measures under date and category filters before publishing | PBIX or model specification and fixture workbook / Measure validation examples and report screenshots | Filter context changes the intended values / Totals reconcile to source data | fact, dimension, filter',
  'advanced-excel': 'Auditable reporting workbook | Build a structured table with validation and a lookup for banded inputs / Test missing keys and boundary values and summarize the outputs | Workbook with fixtures and formulas / Checks showing expected and actual values | Lookup behavior matches documented boundaries / Refreshing source data preserves formulas and totals | structured references, keys, validation',
};
