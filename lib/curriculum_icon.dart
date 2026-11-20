import 'package:material_ui/material_ui.dart';

import 'data/course_models.dart';

/// Matches visible subject names before consulting their syllabus context.
/// All artwork is bundled, so resolving a new title never needs a network call.
class CurriculumIcon extends StatelessWidget {
  const CurriculumIcon({
    super.key,
    required this.label,
    this.contextLabels = const [],
    this.size = 24,
  });

  factory CurriculumIcon.course(Course course) => CurriculumIcon(
    label: course.title,
    contextLabels: [course.id, ...course.tools, course.description],
  );

  factory CurriculumIcon.module(Course course, CourseModule module) =>
      CurriculumIcon(
        label: module.title,
        contextLabels: [
          ...module.lessons.map((lesson) => lesson.title),
          module.summary,
          course.title,
        ],
      );

  factory CurriculumIcon.lesson(
    Course course,
    CourseModule module,
    Lesson lesson,
  ) => CurriculumIcon(
    label: lesson.title,
    contextLabels: [
      ...lesson.topics,
      lesson.summary,
      module.title,
      course.title,
    ],
  );

  factory CurriculumIcon.topic(Lesson lesson, String topic) => CurriculumIcon(
    label: topic,
    contextLabels: [lesson.title, ...lesson.topics, lesson.summary, lesson.id],
    size: 18,
  );

  String? get resolvedAsset => assetFor(label, contextLabels: contextLabels);

  final String label;
  final Iterable<String> contextLabels;
  final double size;

  static String? assetFor(
    String label, {
    Iterable<String> contextLabels = const [],
  }) =>
      _brand(label) ??
      _subject(label) ??
      contextLabels.map(_subject).nonNulls.firstOrNull ??
      contextLabels.map(_brand).nonNulls.firstOrNull;

  @override
  Widget build(BuildContext context) {
    final asset = resolvedAsset;
    if (asset != null) {
      return Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
    }

    final words = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final initials = words
        .take(2)
        .map((word) => word.characters.first)
        .join()
        .toUpperCase();
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(size / 5),
        ),
        child: Text(
          initials.isEmpty ? '–' : initials,
          maxLines: 1,
          style: TextStyle(
            color: colors.onSecondaryContainer,
            fontSize: size * .44,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _normalize(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

String _asset(String name) => 'assets/course_icons/$name.png';

String? _brand(String label) {
  final name = _normalize(label);
  for (final (pattern, artwork) in _brands) {
    if (pattern.hasMatch(name)) {
      return artwork == 'python'
          ? 'assets/brand/python-logo-only.png'
          : _asset('brand-$artwork');
    }
  }
  return null;
}

String? _subject(String label) {
  final name = _normalize(label);
  for (final (pattern, artwork) in _subjects) {
    if (pattern.hasMatch(name)) return _asset(artwork);
  }
  return null;
}

List<(RegExp, String)> _rules(Map<String, String> entries) => [
  for (final entry in entries.entries)
    (RegExp('\\b(?:${entry.key})\\b'), entry.value),
];

final _brands = _rules({
  r'git and github|github': 'github',
  r'azure devops|azure boards|azure repos|azure pipelines|azure artifacts':
      'azuredevops',
  r'power bi': 'powerbi',
  r'excel': 'excel',
  r'databricks': 'databricks',
  r'pyspark|apache spark|spark (?:sql|architecture|fundamentals|jobs|plans)':
      'apachespark',
  r'sqlite': 'sqlite',
  r'postgres|postgresql': 'postgresql',
  r'microsoft sql server|sql server': 'microsoftsqlserver',
  r'mongodb': 'mongodb',
  r'apache kafka|kafka': 'apachekafka',
  r'azure': 'azure',
  r'git': 'git',
  r'numpy': 'numpy',
  r'pandas': 'pandas',
  r'pytorch|torch': 'pytorch',
  r'tensorflow': 'tensorflow',
  r'scikit learn|sklearn': 'scikitlearn',
  r'matplotlib': 'matplotlib',
  r'jupyter': 'jupyter',
  r'mlflow': 'mlflow',
  r'docker': 'docker',
  r'kubernetes|k8s': 'kubernetes',
  r'terraform': 'terraform',
  r'openjdk|java': 'openjdk',
  r'javascript|node js': 'javascript',
  r'typescript': 'typescript',
  r'rust': 'rust',
  r'golang|go programming|^go$': 'go',
  r'vs code|visual studio code': 'vscode',
  r'python': 'python',
});

final _subjects = _rules({
  r'^all$|catalog': 'layers',
  r'^beginner$|not started': 'leaf',
  r'^intermediate$|in progress': 'activity',
  r'^advanced$': 'gauge',
  r'^completed$': 'circle-check',
  r'data structures and algorithms|complexity': 'workflow',
  r'statistics and mathematics|descriptive statistics': 'sigma',
  r'machine learning': 'brain-circuit',
  r'generative ai|generation|prompts?|llm|language models?|tokens|structured responses':
      'sparkles',
  r'deep learning|neural|tensors?|convolution|attention|lstm|recurrent|forward passes':
      'network',
  r'artificial intelligence|responsible ai': 'brain',
  r'data science|exploratory analysis|eda': 'microscope',
  r'data analytics|insight delivery|analytical': 'chart-no-axes-combined',
  r'big data|distributed batch|distributed execution|executors|worker nodes':
      'server',
  r'cloud computing|availability zones': 'cloud',
  r'technical fundamentals|cli|terminal|shell|command line|interpreter':
      'terminal',
  r'baseline classifiers?|decisiontreeclassifier|dummyregressor|underfitting|overfitting|generalization|unsupervised|binary target|linear prediction|centroids?|precision and recall|recall at k|false positive|class imbalance|rare class|calibration':
      'brain-circuit',
  r'affine maps|dot products?|dot product|axes|axis|broadcasting|binary logits|frozen parameters|dropout|batch dimensions|automatic differentiation':
      'network',
  r'^statistics$|bayesian|binomial|bernoulli|gamma|median|quartiles?|skew|variance|variability|alpha|bonferroni|censoring|residuals|randomization|lift definitions|absolute lift':
      'sigma',
  r'weighted rates|pooled rates|descriptive comparisons|robust summaries|tail summaries|unit conversions|control totals?|reconciliation|scoped totals|weighted percentages':
      'chart-no-axes-combined',
  r'aggregates?|aggregations?|countifs|sumifs|count|counts and division|calculate|divide|decimal division|floor division|denominator|arithmetic|precedence|goal seek|formula tracing':
      'calculator',
  r'conditional statements|conditional groups|conditional summaries|nested conditions|guard clauses?|if elif and else|else|case|boolean masks|coalesce|exists|blank|empty state':
      'brackets',
  r'exact match|exact and band lookups|searching and sorting|stable sorting|two pointers|lower bounds':
      'search',
  r'group by|having|cte|projection|aliases|semijoins|upserts?|atomic changes|atomicity|begin|index plans?|bound parameters|selecting rows':
      'database',
  r'bfs|bst|dag|topological|breadth first|a star|feasible selection|shortest paths?|amortization|memoization|tabulation|two pointer':
      'route',
  r'reproducibility|seeded samples|tests and debugging|unittest|fixtures?|boundary cases|preservation properties|guardrails':
      'flask-conical',
  r'checkpoints|backfills?|retry jitter|backoff|idempotency|idempotent consumers|backfill procedures|compaction':
      'rotate-ccw',
  r'ci cd|devops|sdlc|etl|elt|data engineering|transforms?|transformations?|unpivot|append and merge|lazy computation|shuffle|shuffles':
      'workflow',
  r'medallion data design|bronze|silver|gold|columnar formats|volume estimates|volume and formats|compression|delta|parquet':
      'hard-drive',
  r'address ranges|cidr|gateway|egress|regions and zones|iaas|2xx|4xx|5xx|status families':
      'globe',
  r'access and inputs|allowlist|credentials|grants|enforcement|secure application|blast radius|data minimization|shared responsibility':
      'shield-check',
  r'communicating findings|recommendations|reliable reporting|drillthrough|freshness states|comparable exposure|attribution':
      'chart-column',
  r'collections|heapq|grouped records|grouping and aggregates|frequency maps|structured references|fact and dimension|cardinality|buckets?':
      'table',
  r'virtual environments|pip|artifacts|rolling compatibility|actions reduce and persistence|canary|agents and environments':
      'package',
  r'remote tracking|remotes and synchronization|fetch|staging snapshots|head|conflicts|upstream|pull|push':
      'git-branch',
  r'temporal splits|comparable periods|age|horizons?|chronology|deadlines?':
      'calendar-days',
  r'driver|executor tasks|broadcast choice|parallelism|autoscaling|cache|concurrency|profiling|growth rates':
      'cpu',
  r'expected utility|forward chaining|policy|actions?|labels versus rewards|bounded exploration|discounted return|constraints and proxies|evaluating ai systems':
      'brain',
  r'few shot|abstain|abstention|rubrics and slices|boundary examples|chunk metadata|fallback reasons|golden set':
      'sparkles',
  r'status|exit codes|tracing|diagnostics|service signals|coverage|freshness|accuracy':
      'activity',
  r'generators?|default arguments|format specifier|iterators?|kwargs|args|docstrings':
      'calculator',
  r'excel|spreadsheets?|pivottables?|pivot tables?|workbooks?|worksheets?|dynamic arrays|power query':
      'sheet',
  r'security|privacy|permissions?|least privilege|authentication|authorization|identity|secrets?|rls|row level security|compliance|fairness|trust':
      'shield-check',
  r'losses?|gradients?|calculus|backpropagation|optimization|derivatives?':
      'sigma',
  r'probability|distributions?|sampling|uncertainty|confidence intervals?|hypotheses|intervals and tests':
      'chart-scatter',
  r'regression|correlation|forecast|moving averages?|trend|time series':
      'chart-line',
  r'metrics|kpis?|thresholds?|performance|benchmark|latency|runtime reliability|capacity|service levels|objectives':
      'gauge',
  r'monitoring|observability|telemetry|logs?|alerts?|drift|incident':
      'activity',
  r'networking|subnets?|vpc|dns|endpoints?|http|protocols?|apis?|requests?':
      'globe',
  r'containers?|images and registries|orchestration': 'container',
  r'costs?|budgets?|billing|spend': 'wallet',
  r'disaster recovery|recovery|backup|restore|checkpoint|rollback|replay':
      'rotate-ccw',
  r'deployments?|releases?|serving|production|delivery|artifact|packages?|dependencies|versions?':
      'package',
  r'boards|work items|backlog|sprints?|assignments?|capstone|projects?|handoff|review checklist':
      'clipboard-list',
  r'branches?|commits?|version control|merging|source control': 'git-branch',
  r'pull requests?|code review': 'git-pull-request',
  r'streaming|messages?|messaging|events?|watermarks?|queues?|backpressure':
      'cable',
  r'ingestion|sources?|imports?|extract|refresh': 'download',
  r'storage|lakehouses?|data lake|delta lake|parquet|partitions?|files and formats|disk':
      'hard-drive',
  r'joins|relations|relationships|dimensional modeling|fact tables?|star schema|grain|keys?':
      'key-round',
  r'filters?|predicates?|null|where|select|filter context|cleaning|deduplication|cohorts?|funnels?':
      'funnel',
  r'tables?|schemas?|tabular|dataframes?|matrix|arrays?|lists?|stacks?':
      'table',
  r'sql|database|transactions?|query|indexes': 'database',
  r'linear algebra|vectors?|matrices|geometry': 'binary',
  r'trees?|hierarchies|heaps?': 'list-tree',
  r'graph|routes?|paths?|traversal|feasibility|heuristics|scheduling|shortest|planning':
      'route',
  r'ordered|sort|binary search|retrieval|ranking|search|lookup': 'search',
  r'segments?|clustering|classification|predictors?|supervised|baselines?|features?|model selection':
      'brain-circuit',
  r'agents?|inference|decisions?|belief|rules?|reasoning|reward|policies|learning signals':
      'brain',
  r'hash|dictionar(?:y|ies)|sets|mapping': 'hash',
  r'loops?|iteration|recursion|retries|epochs?|cycles?': 'repeat',
  r'functions?|lambda|decorators?|dax|measures?|calculation|aggregate|aggregation|ratios?|expressions?|operators?':
      'calculator',
  r'json|yaml|serialization|formatting|strings?|text processing': 'braces',
  r'variables?|types?|mutability|tuples?|values?|scope': 'variable',
  r'experiments?|ab tests?|testing|verification|validation|quality|assertions?|checks?|acceptance':
      'flask-conical',
  r'debug|exceptions?|errors?|failures?|troubleshoot': 'bug',
  r'time|calendars?|schedules?|windows?|dates?|retention': 'calendar-days',
  r'visual|plots?|charts?|reports?|dashboards?|scorecards?|bar|histogram':
      'chart-column',
  r'images?|vision|pixels?|photos?': 'image',
  r'files?|folders?|directories|repository|repositories|notebooks?|documents?|reading|writing':
      'files',
  r'config|setup|settings|installation|environment|workspace|geography|organizations?':
      'settings',
  r'agents|compute|processes?|runtime|threads?|rdd|memory|cpu|gpu|execution|parallel':
      'cpu',
  r'pipeline|transform|automation|orchestrat|composition|shaping|reshape|stages?|workflows?':
      'workflow',
  r'governance|contracts?|audit|lineage|responsib|assurance|grounding|citations?|evidence':
      'shield-check',
  r'evaluation|assessment|review|comparison|trade offs|scenarios?|sensitivity|limits?':
      'scale',
  r'object oriented|inheritance|classes?|polymorphism|objects?|encapsulation|programming|modul(?:e|es|ar)|code':
      'code-xml',
  r'input|keyboard|interactive|user prompts?|communication': 'keyboard',
  r'foundations?|fundamentals?|introduction|overview|language|prerequisites?':
      'book-open',
});
