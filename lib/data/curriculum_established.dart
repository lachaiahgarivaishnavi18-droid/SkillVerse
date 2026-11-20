const establishedModules = {
  'Python': r'''
Run a named script and compare a syntax error with a runtime error. | Hello, Skillverse then 5 | Ready to learn | Automation scripts provide a repeatable entry point for a business task.
? What executes Python statements? | The interpreter | A CSV header | A database index | The interpreter evaluates Python source instructions.
? What file extension conventionally identifies Python source? | .py | .sql | .pdf | The interpreter runs source files commonly named with .py.
Create a project environment, record dependencies and reproduce setup in a clean environment. | Interpreter version then 4 | Activated environment and installed package versions | Isolated environments make analytics jobs reproducible across machines.
? What does a virtual environment isolate? | Project package installations | Every network port | All source code history | An environment keeps project dependencies separate.
? What should accompany reproducible dependency installation? | An explicit version record and setup instructions | Only the IDE theme | A screenshot of the desktop | Package versions and environment assumptions affect behavior.
Build a typed input parser and explain why unknown differs from zero. | Mina 5 | count=12, ratio=.75, active=True, missing=None; no printed output | Data ingestion converts external strings and preserves missingness.
? What does assignment bind? | A name to an object | A permanent fixed type | A database primary key | Python names refer to objects and can be rebound.
? Which value represents an explicit missing result? | None | 0 always | Empty tuple always | None is distinct from numeric zero and empty collections.
Implement price, tax and eligibility expressions with boundary tests. | 27 3 2 | True | Pricing workflows combine arithmetic and eligibility rules.
? What is 17//5? | 3 | 3.4 | 2 | Floor division yields the integral floor of the quotient.
? Which expression includes age 18 and excludes 65? | 18 <= age < 65 | 18 < age <= 65 | age == 65 | Chained comparison expresses the exact interval.
Implement shipping costs with negative-weight rejection and free-shipping boundaries. | grade is B; add print(grade) to display it | divide(8,2) gives 4.0; divide(8,0) gives None | Validation branches prevent invalid billing calculations.
? In an if/elif chain, how many matching branch bodies run? | At most one | Every true branch | Exactly two | Evaluation selects the first true branch.
? Why use a guard clause for an invalid denominator? | Stop invalid input before normal calculation | Hide all exceptions | Change the return type randomly | Early handling makes the ordinary path easier to verify.
Write a bounded retry loop and a record-processing loop with termination tests. | Iterated values follow the supplied range; inspect the printed sequence | break stops the loop; continue skips the current remainder | Batch automation must terminate and handle failed records deliberately.
? What does continue do? | Advances to the next iteration | Exits the function | Restarts the entire program | The remaining statements in that iteration are skipped.
? What must a while loop maintain to terminate? | Progress toward a false condition or an explicit exit | A nonempty comment | An increasing filename | Its state or control flow must eventually stop iteration.
Normalize customer identifiers and extract fields without modifying source strings. | String operations return normalized or sliced values; strings remain unchanged | A formatted message includes substituted values | Customer matching normalizes text under documented rules.
? Are Python strings mutable in place? | No | Yes | Only inside lists | String operations produce new string values.
? What should text normalization preserve for audit? | Original source text where needed | Only the last character | The editor color | Audit and correction may require the original representation.
Create and update score lists; compare aliasing with a shallow copy. | Appended and indexed list values reflect the shown mutations | Tuple values remain immutable | Application state needs intentional copying and ordering.
? Which collection supports append? | list | tuple | str | Lists are mutable sequences.
? What does assigning b=a do for a list? | Refers to the same list | Deep-copies nested values | Sorts a | Assignment binds another name to the existing object.
Count categories with a dictionary and deduplicate stable IDs with a set. | Duplicate set elements appear once | Dictionary lookups return the stored value for a key | Data preparation groups records and identifies unique keys.
? What is required of dictionary keys? | Hashability | Numeric type only | Mutable list type | Keys must have stable hashing behavior.
? Which collection directly expresses membership without duplicate entries? | set | list with no checks | A formatted string | Sets represent distinct hashable members.
Refactor repeated calculations into functions with documented empty-input behavior. | 4.0 | Hello, Ava | Shared analysis functions reduce inconsistent repeated logic.
? What does return do? | Sends a value to the caller and exits the function | Prints automatically | Defines a global variable | Return ends the current call with its result.
? When are function default arguments evaluated? | At definition time | At every line in the body | Only at import failure | Mutable defaults can persist across calls.
Sort records by multiple keys and compare recursive and iterative factorial. | [('Mina',82),('Ava',91)] | factorial(5) gives 120; negative input raises ValueError | Ranked reports and recursive traversals need explicit boundaries.
? What belongs in every terminating recursive path? | A reachable base case | An infinite loop | A network request | Recursive progress must reach a nonrecursive result.
? Why prefer def for complex callbacks? | Clear named multi-step behavior | Lambda cannot accept input | It changes all data to text | Lambda is intended for small expressions.
Split normalization into a reusable module and document installation. | sql when executed as the entry script | The source module's directory path | Teams share reusable packages without unintended command execution.
? What does the main guard prevent during import? | Unwanted command-line entry behavior | Importing definitions | All syntax checking | Guarded entry code runs when invoked as the main module.
? What does a package provide? | A namespace grouping modules | A database transaction | A terminal session | Packages organize reusable modules and imports.
Stream a UTF-8 file and report malformed numeric inputs explicitly. | notes.txt contains Practice every day followed by a newline | 21 | File-processing jobs need cleanup and meaningful parse failures.
? What does a with file context guarantee on normal exceptions? | The file is closed on exit | Data validation is unnecessary | Every error is swallowed | The context manager performs cleanup.
? Which exceptions should be caught? | Those the code can meaningfully handle | All errors without reporting | Only keyboard shortcuts | Narrow handlers avoid hiding programming failures.
Implement a Course class and validate score updates through a deliberate interface. | Course('SQL').describe() returns Course: SQL | Score(.8).percentage returns 80.0 | Domain objects keep related state and invariants together.
? What initializes an instance's attributes? | __init__ | print | import | The initializer sets up instance state.
? What is the purpose of a validating property? | Maintain an object's invariants | Encrypt every field | Replace unit tests | Controlled access can reject invalid state changes.
Model optional assessments with composition and two report types sharing summary(). | TimedCourse('SQL',60) stores title and minutes | render_summary(Lesson()) returns Lesson content | Shared behavioral contracts enable extensible reporting.
? What relationship is composition useful for? | An object using another object's service | Every unrelated subtype | A copied filename | Composition expresses has-a dependencies.
? What does duck-typed polymorphism rely on? | Supported operations | An identical class name | Global variables | Callers depend on behavior rather than a mandatory inheritance tree.
Normalize a score array and document broadcast dimensions. | .81 | [[11,22],[13,24]] | Vectorized numeric processing supports efficient feature transformations.
? What does an array's shape describe? | Axis dimensions | File encoding | Package version | Shape is the tuple of dimension lengths.
? Why check broadcasting before an array operation? | Compatible shapes may still express the wrong alignment | Broadcasting always fails | It changes all integers to strings | Shape compatibility does not guarantee intended semantics.
Create a customer DataFrame and report grouped means plus missing counts. | Two learner rows; learner text type and score integer type | With the preceding df both scores pass and grouped means are Ava91 and Noah84 | Tabular analysis validates data before producing grouped summaries.
? What is a DataFrame? | A labeled table | A single scalar | An operating system process | DataFrames hold labeled columns and rows.
? What should precede blind missing-value replacement? | Investigation of missingness and domain meaning | Sorting chart colors | Removing every row unconditionally | Imputation depends on why data is missing.
Plot a time series and scatter relationship with units and missing-period notes. | A line through (1,12),(2,18),(3,21); call plt.show() to display | A scatterplot of practice sessions and scores | Reports need labeled charts that match comparison type.
? What chart shows a numeric distribution? | Histogram | A single KPI tile | A repository tree | Histograms show counts across numeric bins.
? What should chart axes communicate? | Variable names and units | Only decorative labels | File permissions | Labels make the comparison interpretable.
Deliver the validated analyzer with a sample file, tests, assumptions and a failure report. | completion_rate(3,4) returns .75; total zero raises ValueError | unique_words('SQL sql Python') returns {'sql','python'} with set order unspecified | A capstone joins parsing, analysis, testing and communication into a maintainable tool.
? Which check protects a completion-rate denominator? | Require a positive total | Always return 100% | Divide by zero | The function rejects undefined totals.
? Why separate parsing, analysis and output? | Each behavior becomes independently testable | To remove validation | To hide assumptions | Focused functions support clear contracts and tests.
''',
  'Databricks': r'''
Map identity, storage and job owners in a retail lakehouse design. | Workspace organizes notebooks and compute; account manages wider configuration | Open table storage serves SQL, Spark and BI | Enterprise lakehouse adoption needs clear ownership and workload boundaries.
? What differs from a workspace? | The account-level identity and cloud configuration | A notebook cell | A lesson title | Accounts and workspaces have different administration scopes.
? What does a lakehouse combine? | Open storage with table management and analytical access | Only local spreadsheets | No governance | Table capabilities and low-cost object storage support multiple workloads.
Choose interactive and scheduled compute, documenting dependency versions and cost limits. | Notebook sections separate setup, validation and outputs | Isolated job compute differs from interactive development | Platform teams avoid uncontrolled dependencies and idle compute.
? What is a reasonable development compute practice? | Stop idle resources | Keep all resources running forever | Omit library versions | Idle compute can incur unnecessary cost.
? What should distinguish a scheduled job environment? | Intentional runtime and dependency configuration | A different font | A copied password in every notebook | Reproducible execution needs explicit environment assumptions.
Create a small distributed aggregation and annotate transformations and actions. | Spark builds transformation plans before actions | An action materializes the required result | Engineers reason about distributed execution before scaling jobs.
? What triggers lazy Spark work? | An action | A variable name | A markdown title | Actions request computed results.
? Why avoid collecting a large result to the driver? | Driver memory is bounded | Collect always adds workers | It deletes source partitions | Collection moves data into one process.
Parameterize a notebook, remove embedded credentials and document run inputs. | Parameters select the intended source or period | Version-controlled helpers support repeatable runs | Production notebooks need controlled inputs and traceable revisions.
? Where should secrets be sourced? | An approved secret-management mechanism | A committed literal | A shared screenshot | Secrets must be protected and independently rotated.
? Why parameterize a run date? | Reprocessing becomes explicit and repeatable | It guarantees fresh data | It removes source validation | Parameters separate execution scope from program edits.
Design an idempotent Delta merge and compare its history after a retry. | Delta transaction metadata tracks committed table changes | MERGE updates or inserts matching keys under its conditions | Incremental pipelines need consistent table writes and recoverable history.
? What does a transaction log support in Delta tables? | Consistent committed table state | Arbitrary cloud permissions | Automatic correctness of all business logic | Metadata describes valid table versions and file actions.
? Why deduplicate a source before a key-based merge? | Multiple source matches can be ambiguous or invalid | Sorting all output fixes every conflict | It makes keys unnecessary | A merge must have a deliberate rule per matched target.
Build a SQL aggregate, inspect its plan and document filter assumptions. | SQL queries produce scoped table results | Plans expose scan and exchange choices | BI workloads need governed tables and measurable query performance.
? What should a SQL subtotal be reconciled against? | Same-grain source under the same filters | An unrelated dashboard | A title count | Matching scope is necessary for a valid control.
? Why inspect query plans? | Identify expensive execution stages | Replace permissions | Rename table columns | Plans reveal how the engine intends to compute a result.
Specify bronze, silver and gold contracts and quarantine invalid records. | Bronze retains raw inputs for replay | Silver validation precedes business-level gold metrics | Retail data quality and lineage depend on stage contracts.
? Where should original ingest records remain recoverable? | Bronze | Only a chart | Only a job title | Raw retention enables corrected reprocessing.
? What must accepted and quarantined counts reconcile to? | Original input count at matching scope | Number of notebooks | Number of users | Every input should have an explained disposition.
Schedule a parameterized job with retry bounds, notifications and recovery steps. | A job has owned tasks, inputs and dependencies | Retry and timeout rules bound failed operations | Reliable orchestration needs operational ownership.
? What makes a repeated write safe? | Idempotent key or replacement semantics | Unlimited retries | Appending identical totals | Retry safety is a state consistency property.
? What belongs in a job failure alert? | Run ID, failing task and owner | Only a screenshot | Every credential | Actionable diagnostics identify where and who should investigate.
Define least-privilege catalog access and a lineage review for sensitive data. | Catalog schemas and tables organize governed assets | Grants constrain permitted operations and principals | Regulated analytics needs controlled discovery and access.
? What should a workload identity receive? | Only required resource actions | Global administration by default | Every user's permissions | Least privilege narrows unintended access.
? What does lineage explain? | Which sources and transformations produced an output | Whether all metrics are correct automatically | The notebook theme | Traceability supports audits and incident diagnosis.
Design a watermark, checkpoint and MLflow experiment handoff for the capstone. | Streaming uses durable progress and explicit late-event policy | Experiment artifacts include parameters, metrics and model context | Production data and ML workloads require replay and reproducibility.
? What preserves stream progress across compatible restarts? | A durable checkpoint | Deleting source offsets | The current display tab | Checkpoints store query progress and state.
? What should accompany a model metric for reproducibility? | Data, parameters and artifact versions | Only the best number | An output color | Reproduction requires the experiment context.
''',
  'PySpark': r'''
Validate Python input parsing and modularize the transformation entry point. | Python helpers transform explicit inputs | Unit tests cover malformed and empty records | PySpark jobs depend on correct local parsing as well as distributed logic.
? What should a reusable transformation accept? | Explicit inputs and a documented contract | Only hidden global state | A screenshot | Explicit dependencies make behavior testable.
? Why test empty input? | It is a valid batch boundary in many pipelines | It guarantees schema is irrelevant | It removes need for tests | Empty batches often reveal aggregation and schema assumptions.
Sketch driver, executors and partitions for a grouped computation. | Driver coordinates distributed execution | Executors process tasks on partitions | Spark architecture explains memory and failure boundaries.
? Which process coordinates Spark execution? | Driver | Browser stylesheet | A CSV header | The driver constructs and coordinates execution.
? Where does collecting all rows place their data? | Driver memory | Automatically in unlimited distributed storage | In the UI only | Collection centralizes rows and can exhaust the driver.
Compare an RDD map with a DataFrame transform and preserve deterministic output checks. | RDD transformations are lazy | Actions request distributed results | Legacy Spark code may require understanding lower-level APIs.
? What is an RDD transformation's usual immediate effect? | Defines a new lazy computation | Executes every result immediately | Updates cloud permissions | Evaluation is generally deferred until an action.
? Why prefer an applicable DataFrame expression over opaque Python record code? | Engine optimization and structured execution | It guarantees every query is faster | It changes all rows to text | Structured expressions expose operations to the optimizer.
Create a typed DataFrame and reject incompatible source values. | Explicit schema fixes intended field types | Projections select and derive named columns | Data contracts prevent silent inference changes.
? Why specify a schema for stable ingestion? | Keep types and required fields deliberate | To hide parse errors | To avoid names | Inference can change with sample contents.
? What should happen to an incompatible source row? | An explicit reject or quarantine under policy | Silent fabricated values | Always count as valid | Invalid data needs a recorded disposition.
Clean nulls and duplicates with documented keys and survivor rules. | Null handling follows field meaning | Deduplication uses stable business keys | Cleaning should preserve legitimate repeated transactions.
? What must guide null replacement? | Domain meaning and missingness | Only column order | A universal zero rule | Missing values do not always mean zero.
? What distinguishes duplicates from equal amounts? | Business identity | Same amount only | Similar color | Legitimate events can share values.
Aggregate after projection and inspect shuffle boundaries. | Filters and projections narrow input | Grouped aggregates may exchange data by key | Resource-efficient jobs reduce unnecessary distributed payload.
? What often introduces an exchange? | Grouping by keys across partitions | Renaming a variable | Writing documentation | Related keys must be colocated for many aggregate stages.
? Why project needed columns early? | Reduce unnecessary data movement | Eliminate all network work | Guarantee no spill | Narrower rows can reduce exchange and serialization cost.
Compute deterministic per-customer rank and running totals. | Windows retain detail rows while adding group context | Unique tie-breakers stabilize ranking | Time-series and CRM pipelines need reproducible survivors.
? What keeps ROW_NUMBER stable for equal timestamps? | A unique secondary sort key | Random input order | LIMIT alone | A total ordering prevents arbitrary ties.
? How does a window differ from GROUP BY? | It can retain each input row | It always removes detail | It requires string keys | Window values attach to rows instead of collapsing groups.
Compare built-in expressions with a Python UDF and justify any repartition. | Built-in expressions expose logical work to Spark | Partition changes affect task distribution and shuffle | Advanced jobs should profile rather than guess at optimizations.
? What is a useful first choice for a supported transformation? | Built-in Spark expression | Arbitrary Python UDF by default | Driver-side row loop | Native expressions expose operations to optimization.
? What should justify repartitioning? | Measured distribution or downstream needs | An arbitrary larger number | A logo change | Partition changes can incur shuffles and should address a real bottleneck.
Define event-time windows, late handling and a unique durable checkpoint. | Windows use the chosen clock and watermark policy | Checkpoint recovery depends on compatible query and sink semantics | Streaming analytics needs explicit restart behavior.
? Which time describes actual occurrence? | Event time | Processing arrival time always | Dashboard rendering time | Event time originates with the business event.
? Does a checkpoint alone make any external API exactly once? | No, sink effects need compatible guarantees | Yes for every API | Only if output is text | Recovery progress and external side effects are separate.
Profile skew and spill, then publish a retry-safe partitioned capstone. | Skew creates long-running partitions | Capstone controls reconcile input, accepted and served records | Production tuning needs both correctness and measured resource evidence.
? What can explain one slow task with much more data than peers? | Key skew | A title change | Too few comments | Uneven keys cause uneven partition work.
? What should be checked after a performance change? | Output correctness and realistic runtime metrics | Only the elapsed time once | Only row colors | Faster execution is insufficient if semantics changed.
''',
  'Azure DevOps': r'''
Map a change from backlog to production and name each approval owner. | Delivery connects planning, source, build and release | Automation requires reviewable operational responsibility | Teams improve delivery by understanding flow and feedback.
? What should delivery automation include besides execution? | Feedback and accountable ownership | Only commands with no checks | Shared unrestricted credentials | Operational responsibility and evidence guide reliable releases.
? What is a useful measure of a delivery improvement? | Observed lead time and failure outcomes | More YAML lines | More screenshots | Improvement concerns flow and reliability.
Design a project structure and permissions matrix for two teams. | Organizations contain projects and team resources | Role assignments govern permitted actions | Shared platforms need deliberate isolation and ownership.
? What should determine project permission scope? | Required team responsibilities | Default admin for everyone | Display name length | Role scope should match work duties.
? Why assign owners to service connections? | Credentials and access require maintenance | To make every user owner | To remove checks | Connection privileges and rotation need accountability.
Write a backlog item with acceptance criteria and trace it to changes. | Work items capture a measurable outcome | Boards expose progress, dependencies and blocked work | Engineering work needs verifiable acceptance and visibility.
? What makes an acceptance criterion useful? | Observable pass or fail behavior | Only a vague goal | A preferred color | Review needs a verifiable outcome.
? Why connect a work item to source changes? | Traceability of delivered behavior | It compiles the code | It grants administrator access | The link ties intent to implementation and validation.
Create a short-lived branch with reviewed changes and protected target policies. | Git branches isolate a scoped change | Reviews and checks protect shared branches | Collaboration needs testable integrated changes.
? What should protect a shared release branch? | Required reviews and appropriate checks | Direct unrestricted writes | Only a naming convention | Policies enforce the agreed integration evidence.
? What follows manual merge conflict resolution? | Run integrated checks | Assume removing markers proves correctness | Delete all prior commits | Resolved syntax can still combine behaviors incorrectly.
Author a small YAML pipeline with explicit triggers and dependencies. | A pipeline arranges jobs and steps on agents | Dependencies constrain execution order | Repeatable builds reduce manual release variability.
? What should a pipeline dependency express? | A prerequisite job or artifact | A random display order | A user password | Dependencies connect required execution stages.
? Why keep pipeline configuration versioned? | Review and reproduce delivery changes | To expose secrets | To prevent any update | Build behavior is part of the code's change history.
Publish test results and a build artifact, then gate promotion on checks. | Build output becomes a versioned deployable artifact | Test results provide pass and failure evidence | Release promotion should use the artifact already verified.
? What should be promoted through environments? | The verified immutable artifact | A fresh unverified rebuild each time | A developer's workspace files | Consistent artifacts preserve the link between tests and release.
? What should a failed mandatory test do? | Stop promotion until resolved | Be hidden | Mark the deployment successful | Gates enforce required quality evidence.
Compare hosted and self-hosted agents and restrict environment deployment permissions. | Agents execute jobs with configured tools and identities | Environments support scoped approvals and checks | Runtime machines and deployment targets need separate trust controls.
? What risk deserves attention on self-hosted agents? | Persistence of data and credentials between jobs | Only icon rendering | The pipeline name | Reused machines can retain sensitive state and artifacts.
? Why use environment checks? | Control when and who can deploy | Remove source reviews | Avoid all test execution | Checks enforce target-specific deployment policy.
Publish a package version and demonstrate a consumer's pinned dependency. | Feeds organize package distribution | Versioning makes dependencies reproducible | Teams share build outputs under controlled permissions.
? What helps reproduce a consumer build? | Pinned tested package versions | Always newest untested dependency | Removing metadata | Explicit versions fix the dependency selection.
? Who should publish to a production package feed? | Authorized build identities | Every unauthenticated user | Anyone with a screenshot | Publishing affects downstream consumers and needs scoped access.
Review a service connection, secret rotation and an infrastructure plan. | Secrets are sourced from protected mechanisms | Reviewed infrastructure plans expose intended changes | Delivery authority should be limited and auditable.
? Where should pipeline secrets stay out of? | Committed source and logs | An approved secret store | Scoped identity services | Source and logs are widely retained and copied.
? What deserves review in an infrastructure plan? | Deletes and replacements of stateful resources | Only formatting | Only pipeline duration | Replacement may disrupt or lose persisted state.
Define deployment health signals and a tested rollback decision. | Observability combines errors, latency and resource signals | A runbook gives the owner specific recovery steps | Operators need measurable evidence after a release.
? What makes a rollback trigger actionable? | A measurable threshold and responsible owner | An aesthetic preference | A long filename | The team needs a decision rule and authority to act.
? Why review tail latency? | The mean can hide slow-request groups | It is the same as CPU count | It replaces error monitoring | Tail metrics reveal concentrated user impact.
Deliver a multi-stage capstone with tests, artifacts, approvals and recovery evidence. | Stages promote tested versioned output | Release evidence ties a revision to checks and environment results | Industry delivery requires both automation and accountable promotion.
? What should identify a deployed artifact? | An immutable version linked to a source revision | A reused unnamed file | A current screen color | Traceable identity supports diagnosis and rollback.
? What belongs in a capstone handoff? | Setup, test evidence and recovery instructions | Only a screenshot | Only a success label | Other engineers must be able to reproduce and operate it.
''',
};
