import 'interview_questions.dart';

enum InterviewRole {
  pythonDeveloper('Python Developer'),
  dataAnalyst('Data Analyst'),
  dataEngineer('Data Engineer'),
  machineLearningEngineer('Machine Learning Engineer');

  const InterviewRole(this.label);
  final String label;
}

typedef InterviewConcept = ({String label, List<String> terms});

class RoleInterviewQuestion {
  const RoleInterviewQuestion({
    required this.role,
    required this.question,
    required this.concepts,
    required this.followUp,
  });

  final InterviewRole role;
  final InterviewQuestion question;
  final List<InterviewConcept> concepts;
  final String followUp;
}

final roleInterviewQuestions = List<RoleInterviewQuestion>.unmodifiable([
  for (final entry in _roleRows.entries)
    for (final row in entry.value.trim().split('\n')) _parse(entry.key, row),
]);

final roleInterviewById = Map<String, RoleInterviewQuestion>.unmodifiable({
  for (final entry in roleInterviewQuestions) entry.question.id: entry,
});

List<InterviewQuestion> roleQuestionsFor(
  InterviewRole role,
  String difficulty,
) => roleInterviewQuestions
    .where(
      (entry) => entry.role == role && entry.question.difficulty == difficulty,
    )
    .map((entry) => entry.question)
    .toList();

bool matchesInterviewRole(InterviewQuestion question, InterviewRole role) {
  final entry = roleInterviewById[question.id];
  if (entry != null) return entry.role == role;
  final categories = switch (role) {
    InterviewRole.pythonDeveloper => [
      'Python',
      'Data Structures and Algorithms',
      'Technical Questions',
    ],
    InterviewRole.dataAnalyst => [
      'SQL',
      'Data Analytics',
      'Statistics',
      'Power BI',
      'Excel',
    ],
    InterviewRole.dataEngineer => [
      'SQL',
      'Databricks',
      'PySpark',
      'Azure DevOps',
      'Technical Questions',
    ],
    InterviewRole.machineLearningEngineer => [
      'Machine Learning',
      'Deep Learning',
      'Statistics',
      'Artificial Intelligence',
      'Data Science',
    ],
  };
  return categories.contains(question.category);
}

RoleInterviewQuestion _parse(InterviewRole role, String row) {
  final [
    id,
    category,
    difficulty,
    topic,
    prompt,
    answer,
    example,
    concepts,
    followUp,
  ] = row.split(
    ' | ',
  );
  return RoleInterviewQuestion(
    role: role,
    question: InterviewQuestion(
      id: 'role-v1-$id',
      category: category,
      difficulty: difficulty,
      topic: topic,
      question: prompt,
      answer: answer,
      explanation: 'Apply the approach to the concrete case and explain the trade-off or failure mode.',
      example: example,
    ),
    concepts: [
      for (final part in concepts.split('; '))
        (label: part.split('~').first, terms: part.split('~')),
    ],
    followUp: followUp,
  );
}

const _roleRows = {
  InterviewRole.pythonDeveloper: r'''
python-event-lookup | Python | Beginner | Collection selection | A Python event processor receives repeated event IDs. How would you detect a duplicate immediately without retaining the payloads? | Maintain a set of seen IDs. Check membership before adding each ID. Set lookup is expected constant time for ordinary hashable keys, and space grows with the number of distinct IDs. | For IDs a, b, a, add a and b, then report the second a as a duplicate. Keep only IDs in the set. | Set~hash set~seen IDs; Membership~look up~lookup~contains; Distinct IDs~unique IDs~different IDs | How would you bound memory if the stream never stops?
python-text-parse | Python | Beginner | Input validation | A CSV parser converts an age column with int(). How would you handle blank cells and malformed values while keeping the valid rows? | Normalize whitespace, decide how to represent missing values, and catch ValueError around that conversion only. Record a row number or safe identifier for rejected values so they can be corrected. | An empty cell becomes None under a nullable schema. The value unknown is recorded as invalid, while 42 is converted and kept. | ValueError~value error~conversion error; Missing values~blank~empty~nullable; Row number~row identifier~log invalid~reject list | How would the rules differ if negative ages must also be rejected?
python-default-cache | Python | Intermediate | Function state | A function uses a list as its default argument. When called twice with no list, the second caller unexpectedly sees the first result. Explain the cause and fix. | Default arguments are evaluated once when the function is defined. Mutating a default list shares changes across calls. Use None as a sentinel, then create a fresh list inside the function when the caller omits a list. | def add(item, items=None): allocate [] if items is None, then append the item and return the list. Two omitted lists remain independent. | Evaluated once~definition time~defined once~created once; Shared mutable state~same list~mutable default~shared list; None sentinel~use None~default to None~fresh list | When would intentional shared state be better expressed as an instance attribute?
python-stream-json | Python | Intermediate | Streaming input | A job reads a large newline-delimited JSON file and exhausts memory before writing any results. How would you redesign input handling? | Open the file with a context manager and iterate over its lines. Decode and process each record as it arrives. Emit results incrementally or write bounded batches, and report malformed lines separately. | Use with open(path) as file, then enumerate(file, 1) and json.loads(line) for each nonblank line. | Iterate over lines~line by line~streaming~generator; Context manager~with open~with statement; Bounded batches~incremental output~buffer size~bounded memory | What changes if the input is a single JSON array spanning the whole file?
python-concurrent-api | Python | Advanced | Concurrency limits | A Python service fans out to an upstream API. Increasing concurrency makes timeouts worse and sometimes duplicates writes. Design a safer approach. | Bound in-flight requests with a semaphore or worker pool. Apply per-call and overall deadlines, and retry transient failures with bounded exponential backoff and jitter. Retry writes only when they are idempotent or carry a stable idempotency key. | Limit an async client to 20 outstanding requests. A timed-out create request uses the same operation key if retried. | Bounded concurrency~semaphore~worker pool~limit in flight; Deadline~timeout~time budget; Backoff~jitter~exponential backoff; Idempotency key~idempotent~deduplicate retries | How would you test that cancelling the parent operation also cancels pending child work?
python-lock-contention | Python | Advanced | Shared state | Many threads update a shared in-memory cache. Correctness failures disappear with one lock, but latency grows sharply. Where should you investigate? | Measure lock hold and wait times. Keep expensive I/O or computation outside the critical section, and protect multi-step state changes. If keys are independent, consider per-key locks or an ownership design that prevents conflicting writes. | Fetch a missing value outside the global lock, then recheck under the appropriate key lock before publishing it. Use a per-key in-flight record when duplicate fetches are undesirable. | Lock contention~lock wait~hold time; Critical section~lock scope~outside the lock; Per-key locking~per key lock~lock striping~single writer | How would you avoid a cache stampede without blocking reads for unrelated keys?
''',
  InterviewRole.dataAnalyst: r'''
analyst-retention | Data Analytics | Beginner | Retention metrics | A dashboard divides day-30 retained users by all sign-ups, including last week's sign-ups. Explain the mistake and correct the denominator. | Define a cohort by signup date and calculate day-30 retention only for people whose observation window has reached day 30. State the qualifying activity and date rules used in the numerator. | If 80 of 100 users have reached day 30 and 24 of those return, the rate is 24 divided by 80, or 30%. | Eligible cohort~cohort~eligible users; Observation window~30 days~day 30~follow up; Qualifying activity~returned~active event | How would you handle late-arriving activity data near the reporting cutoff?
analyst-excel | Excel | Beginner | Spreadsheet references | A weekly report multiplies each amount by a rate stored in B1. After filling the formula down, the calculations use B2 and B3. How do you fix and validate it? | Anchor the rate cell with an absolute reference and leave the amount row relative. Recalculate a known example and check a formula further down to make sure both references behave as intended. | If amounts start in A4, use =A4*$B$1. The next row becomes =A5*$B$1. | Absolute reference~absolute cell~fixed reference~anchor~b 1; Relative reference~relative amount~row changes; Check known example~sample calculation~verify~spot check | When would you use a mixed reference such as B$1?
analyst-join | SQL | Intermediate | Join reconciliation | The dashboard's revenue rose after adding a customer segment column through a join. How can you tell whether the increase is real or a query bug? | Compare source and joined revenue at the same order grain and date window. Check if customer keys repeat in the segment data, increasing the joined row count. Resolve the correct segment per order before rejoining and reconcile the totals. | An order worth 40 joins to two historical segment rows and contributes 80. Use the order date to choose the applicable segment version. | Grain~order level~one row per order; Duplicate keys~fanout~one to many~cardinality; Reconcile totals~compare sums~before and after | How would you keep orders whose customers lack a segment?
analyst-experiment | Statistics | Intermediate | Experiment reporting | An experiment reports 4.1% conversion in control and 4.5% in treatment. What would you include in a decision memo? | Report the 0.4 percentage-point absolute difference, sample sizes, and an uncertainty interval. Check assignment and instrumentation, then compare the result with a business-relevant effect threshold and guardrails. | If the uncertainty interval includes near-zero uplift, explain that the measured lift is compatible with little benefit even if the point estimate looks promising. | Percentage points~absolute difference~0 4 points; Uncertainty interval~confidence interval~credible interval; Sample size~number of users~group counts; Guardrail~practical significance~business impact | How would repeated looks at conversion during the experiment alter the analysis?
analyst-weighted-kpi | Data Analytics | Advanced | Weighted aggregation | A regional report averages store conversion percentages. Large stores dominate traffic, and the reported percentage disagrees with the transaction-level value. Which number should you publish and why? | For the overall visitor-level KPI, divide total conversions by total eligible visits. This is a weighted average of store rates with visits as weights. Report equal-weight store performance separately if stakeholders need it. | For stores with 1 conversion out of 10 and 50 out of 100, the overall rate is 51 out of 110, about 46.4%. Averaging 10% and 50% gives 30%. | Ratio of sums~total conversions~aggregate numerator; Weighted average~traffic weighted~visit weights; Denominator~total visits~eligible visits | How would your report treat a store that logged zero eligible visits?
analyst-funnel | Data Analytics | Advanced | Funnel integrity | Mobile checkout completion appears to fall after a new instrumented step launches. Describe a way to separate a real funnel change from measurement artifacts. | Build ordered event sequences for a stable user or session identifier and a fixed conversion window. Compare pre/post event volumes and instrumentation across app versions and platforms. Reconcile completed checkouts with independent order records. | If logged completion events drop only for one Android version but recorded orders do not, audit that version's completion event before interpreting the dashboard as a behavioral change. | Event sequence~ordered events~step order; Conversion window~time window~fixed window; Instrumentation~tracking~event logging; Independent records~order records~reconcile~ground truth | How would you handle users who abandon checkout on mobile and finish on desktop?
''',
  InterviewRole.dataEngineer: r'''
engineer-grain | SQL | Beginner | Data modeling | An order can contain multiple products. A downstream report needs revenue per product. What should one row of your fact table represent? | Use one row per order line with a stable line ID or a unique order-and-line key. Store the product, quantity, and unit price or line amount at that grain, then sum line revenue by product. | Order 17 has two lines. The two rows retain distinct line IDs and can be aggregated without counting the order header twice. | Order line~line item~one row per line; Unique key~primary key~order and line~line id; Line revenue~quantity times price~line amount | How would you represent a partly refunded line in a revenue fact table?
engineer-csv-contract | Data Science | Beginner | Input contracts | A daily ingestion job receives CSV files from a partner. One date column switches formats and downstream reports show missing dates. What should the pipeline do? | Validate the input schema and date format before publishing. Parse using a defined contract and quarantine failing records or the whole file according to policy. Log rejection counts and notify the source owner. | Parse a required ISO date explicitly and fail or isolate rows containing an unsupported format rather than turning an entire column into silent NULLs. | Schema~data contract~schema validation; Quarantine~reject~dead letter~isolate; Monitor~alert~rejection counts~logging | How would you roll out a new accepted date format without breaking historical loads?
engineer-retry | Databricks | Intermediate | Retry-safe loading | A distributed job writes a daily customer batch twice after losing its final acknowledgement. Design a retry-safe load. | Make the sink write idempotent using a stable business key and a deterministic source. Deduplicate within the batch before applying a transactional merge or atomic partition replacement. Record completion only after the write succeeds. | Merge the newest row per customer ID into a Delta table. Restarting the same batch updates the same customer rows. | Idempotent~retry safe~idempotency; Stable key~business key~customer id; Merge~upsert~partition replacement; Deduplicate~deduplication~latest row | What tie-breaker would you use when two updates have the same timestamp?
engineer-skew | PySpark | Intermediate | Distributed joins | Most Spark join tasks finish quickly, but one task holds up the stage. How would you diagnose and address skew without guessing? | Compare task time, shuffle records, and key frequencies. Confirm whether a hot key creates an oversized partition. Consider a broadcast join if a side is small, or use adaptive skew handling or salting while keeping the join's intended semantics. | If one merchant has 40% of rows and the dimension is small enough, broadcast the dimension to avoid shuffling the fact table. | Hot key~key skew~skew~key frequency; Shuffle metrics~shuffle records~task metrics; Broadcast~salting~adaptive query execution~aqe | How would you verify that a salting solution does not duplicate or drop results?
engineer-late-data | PySpark | Advanced | Stream completeness | A streaming aggregation must accept mobile events that can arrive hours late. Describe your windowing and correction policy. | Use event-time windows, choose a watermark based on observed lateness and business tolerance, and define what happens after it expires. Store late records or support a controlled replay so affected aggregates can be corrected without double-counting. | Set a six-hour watermark if supported by observed delays. Route later records to a correction path that upserts the affected window totals. | Event time~event timestamp~event time windows; Watermark~allowed lateness~lateness threshold; Replay~backfill~late records~correction; Upsert~idempotent~deduplicate | How would you explain the completeness-versus-latency trade-off to dashboard users?
engineer-backfill | Technical Questions | Advanced | Backfill isolation | A historical backfill and the live pipeline can touch the same destination partitions. What controls keep published data consistent? | Isolate work in staging, specify ownership of affected partitions, and publish via a transactional replacement or versioned promotion. Reconcile row counts and key totals before promotion, and retain a rollback path. | Backfill three months into staging, verify checks by date, and promote each compatible partition with controlled concurrent writes. | Staging~isolated table~shadow table; Partition ownership~lock~coordinate writes~write isolation; Atomic publish~transactional replacement~versioned promotion; Reconciliation~row count~control totals | What would you do if new records arrive for a partition while you validate the backfill?
''',
  InterviewRole.machineLearningEngineer: r'''
mle-leakage | Machine Learning | Beginner | Prediction-time features | A churn model uses whether the customer closed the account during the month being predicted. Explain why offline performance looks better than deployment performance. | The feature contains future information about the label. Build features as of the prediction timestamp and validate using only data available then, with a realistic time-based split if records are temporal. | At the start of May, use April activity to predict May churn. An account closure later in May cannot be an input for that prediction. | Leakage~future information~target leakage; Prediction timestamp~prediction time~as of~available at inference; Time split~temporal split~time based validation | How would you test a feature view for accidental look-ahead?
mle-rare-events | Machine Learning | Beginner | Imbalanced evaluation | Only 1% of payments are fraudulent. A model reports 99% accuracy. What should you check before recommending it? | Compare with the baseline that predicts no fraud. Review a confusion matrix, precision and recall for fraud, and the operational cost of false alarms and missed cases. | On 1,000 payments with 10 frauds, the all-legitimate baseline gets 99% accuracy but catches none of the 10. | Baseline~majority class~predict no fraud; Precision~positive predictive value; Recall~sensitivity~true positive rate; Confusion matrix~false positives~false negatives | How would you compare models if reviewers can inspect only 30 alerts per day?
mle-time-validation | Machine Learning | Intermediate | Grouped split | Multiple observations belong to the same customer and the objective is to predict behavior for new customers. How should you construct train and validation sets? | Group examples by customer before splitting, keeping each customer entirely in one split. Preserve any needed time ordering, fit preprocessing only within training, and check group overlap explicitly. | Put every interaction for customer A in training and every interaction for customer B in validation. An ordinary random row split could put both in each set. | Group split~grouped split~groupkfold~group k fold; Customer overlap~same customer~entity overlap~disjoint groups; Fit on training~train only~training only~pipeline | How would you revise the split if deployment also predicts a future month?
mle-skew | Machine Learning | Intermediate | Training-serving parity | A feature has the same name in training and serving, but online predictions differ for the same input. How would you isolate the cause? | Compare point-in-time raw records and derived values for known entities. Verify schema, defaults, time windows, and transformation versions. Add a parity test and monitor feature distributions after deployment. | Send the same customer timestamp to offline and online pipelines and compare the count of transactions in the prior seven days, including boundary rules. | Training-serving skew~train serving skew~feature parity~parity test; Point-in-time~as of~same timestamp; Transformation version~same preprocessing~schema~default values | What would you log to debug parity without exposing sensitive feature values?
mle-serving-rollout | Technical Questions | Advanced | Safe model rollout | You need to release a fraud model while limiting harm if its decisions differ too much from the previous version. Outline a rollout and rollback plan. | Start with shadow traffic to check latency and decision differences without acting. Move to a small canary with decision, system, and outcome guardrails. Define alert thresholds, retain the previous model version, and rehearse rollback. | Compare decisions in shadow mode, then route 5% of eligible traffic to the candidate and stop the rollout if a predefined false-alert proxy or latency limit worsens. | Shadow~shadow traffic~shadow mode; Canary~canary deployment~small rollout~gradual rollout; Guardrail~slo~alert threshold~monitoring; Rollback~previous version~revert | Which outcome metrics remain useful if verified fraud labels take weeks to arrive?
mle-drift-labels | Machine Learning | Advanced | Delayed outcomes | Production feature distributions move after a seasonal event, but labels are delayed. What should trigger investigation, and how would you decide whether retraining is justified? | Monitor feature and score distributions by segment against seasonal baselines and check for broken inputs. Use interim operational signals to triage, then compare labeled performance once outcomes mature. Validate any retrained model on realistic temporal holdouts before rollout. | A jump in one region's missing income field is likely a data-quality issue. A gradual shift with valid data may justify new training only once later labels confirm worse performance. | Distribution drift~data drift~feature drift~score drift; Segment~cohort~by region~slice; Delayed labels~label delay~outcome delay~mature labels; Temporal validation~time based holdout~time split | Why does input drift alone fail to establish that the relationship between inputs and the target changed?
''',
};
