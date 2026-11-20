/// Applied checks for the introductory module of each catalog course.
/// Choices are listed with the correct answer first before bank rotation.
const openingModuleCases = <String, (String, String, List<String>, String)>{
  'python': (
    'A file named grades.py contains print(2 + 3). What happens when you run python grades.py from its directory?',
    'The interpreter evaluates the expression and prints 5.',
    [
      'The interpreter displays print(2 + 3) as literal text.',
      'Python writes 5 into grades.py.',
      'Nothing is displayed because the expression is not assigned.',
    ],
    'The command executes the source file. The addition is evaluated before print displays its argument.',
  ),
  'sql': (
    'Order 41 has lines 1 and 2, and line numbers restart for each order. Which primary key preserves one row per order line?',
    'A composite key on (order_id, line_number).',
    ['order_id alone.', 'line_number alone.', 'The amount paid for the line.'],
    'Neither component is unique by itself. The ordered pair identifies one line within one order without collapsing orders or items.',
  ),
  'machine-learning': (
    'Only 2% of accounts churn. Your first classifier achieves 98% accuracy without ever predicting churn. What is the next useful check?',
    'Compare it with the always-stay baseline and measure recall for churn.',
    [
      'Deploy because the accuracy exceeds 95%.',
      'Train on the held-out labels to increase accuracy.',
      'Remove stay accounts from the test set and keep reporting accuracy for the original population.',
    ],
    'An always-stay baseline also scores 98% on this distribution. Churn recall is zero, so accuracy hides the failure to identify the target cases.',
  ),
  'data-science': (
    'A retention analysis is meant to decide whether to extend onboarding. What should the team specify before pulling event data?',
    'The eligible signup cohort, retention observation window and decision criterion.',
    [
      'Only which chart library to use.',
      'A retention definition tuned after seeing the largest result.',
      'The retention count without a denominator or exposure window.',
    ],
    'A decision and an eligible population establish what the data can answer. A fixed observation window keeps groups with unequal follow-up from being compared as if they had equal time to return.',
  ),
  'artificial-intelligence': (
    'A delivery agent can earn points by reaching a customer quickly, but a candidate route violates a mandatory access rule. How should the agent treat that route?',
    'Remove the route from the feasible action set before scoring feasible routes.',
    [
      'Accept the route if its estimated reward is high enough.',
      'Measure the access violation only after deployment.',
      'Always choose the first available route regardless of its constraints.',
    ],
    'A hard rule defines feasibility. Objective scores only rank actions that satisfy the rule.',
  ),
  'data-structures-and-algorithms': (
    'An algorithm inspects each input item once, then inspects every ordered pair of input items. Which term dominates growth as the input gets large?',
    'The pair scan, which is quadratic in the input length.',
    [
      'The first scan, which makes the entire algorithm linear.',
      'A logarithmic term caused by using two passes.',
      'A constant term because the code does not allocate a new collection.',
    ],
    'The two phases cost n and n² operations respectively. Dropping lower-order terms gives O(n²) time.',
  ),
  'technical-fundamentals': (
    'A caller requests an existing resource using GET, but its ID does not exist. Which HTTP status accurately reports that outcome?',
    '404 Not Found.',
    [
      '200 OK with a fabricated record.',
      '201 Created.',
      '204 No Content for a successful deletion.',
    ],
    '404 reports that the target resource was not found. A successful retrieval or creation status would misrepresent the outcome.',
  ),
  'databricks': (
    'A company needs the same governed data available to notebooks and SQL analytics. Which design uses lakehouse capabilities?',
    'Store data in shared object storage with managed tables and govern access to those tables.',
    [
      'Duplicate the data separately for every notebook.',
      'Store the only copy inside a notebook output cell.',
      'Replace table access control with a shared storage password.',
    ],
    'A lakehouse layers table management and analytical access over shared storage. Separate copies or shared passwords undermine consistency and governance.',
  ),
  'pyspark': (
    'A transformation receives strings such as "42" and "unknown" in a numeric field. Where can a fast, focused test verify the desired behavior?',
    'Test the Python parsing helper directly with valid, invalid and empty inputs.',
    [
      'Run the full distributed job for every parsing edge case.',
      'Check only how many Spark executors are running.',
      'Assume casting always succeeds because one sample was numeric.',
    ],
    'A local helper test isolates parsing behavior before checking distributed integration. It exercises malformed data without depending on cluster setup.',
  ),
  'azure-devops': (
    'Deployment failed after a last-minute production-only edit. Which DevOps change improves traceability and reproducibility?',
    'Promote the same versioned artifact through environments with recorded approvals.',
    [
      'Rebuild a different artifact by hand for each environment.',
      'Overwrite the version label each time a file changes.',
      'Remove the deployment record to speed up the next run.',
    ],
    'Promoting a single versioned artifact makes it possible to verify what was tested and what reached production.',
  ),
  'git-and-github': (
    'You staged file A, then edited both A and B again without staging. What will a plain git commit record?',
    'The staged snapshot of A, without the later unstaged edits.',
    [
      'The latest working-tree versions of A and B.',
      'Both versions of A and the latest version of B.',
      'Nothing, because making an unstaged edit clears the index.',
    ],
    'A plain commit records the index. Unstaged changes remain in the working tree and do not replace the staged snapshot.',
  ),
  'statistics-and-mathematics-for-data-science': (
    'Five resolution times are 2, 3, 4, 5 and 36 minutes. What is the median?',
    '4 minutes.',
    ['5 minutes.', '10 minutes.', '36 minutes.'],
    'The median of a sorted list with five values is the third value. The unusually large final value affects the mean more strongly.',
  ),
  'deep-learning': (
    'An input tensor has shape [32, 128], where axis 0 indexes samples. What shape results from taking the mean over axis 0 without retaining that axis?',
    '[128].',
    ['[32].', '[32, 128].', '[1, 128].'],
    'Reducing over the 32 samples leaves one mean per feature. The reduced axis is removed unless keepdim is enabled.',
  ),
  'generative-ai': (
    'An application has an 8,000-token total context budget and reserves 1,000 tokens for output. The system instructions and user message use 2,000 tokens. What budget remains for retrieved evidence?',
    '5,000 tokens.',
    ['6,000 tokens.', '7,000 tokens.', '8,000 tokens.'],
    'Subtract both reserved output and the already-used input from the total budget. 8,000 − 1,000 − 2,000 leaves 5,000 tokens.',
  ),
  'cloud-computing': (
    'A service must remain available after one availability zone fails. Which deployment directly addresses this requirement?',
    'Run healthy instances in at least two zones and route requests away from failed instances.',
    [
      'Run two instances on different hosts in the same zone only.',
      'Run the largest available instance without a replica.',
      'Make daily backups without providing live failover.',
    ],
    'Separate zones provide independent failure boundaries. Health-aware routing sends traffic to surviving instances during a zone outage.',
  ),
  'big-data-technologies': (
    'A batch job scans three fields from a wide dataset. Which file property helps it avoid reading unrelated fields?',
    'Columnar storage with separate column chunks.',
    [
      'A long filename that lists field names.',
      'One text line per complete record.',
      'A larger object count without a change in record layout.',
    ],
    'A columnar reader can select chunks for relevant fields rather than reading every value in each record.',
  ),
  'data-analytics': (
    'Of 100 tickets, 20 were excluded by the SLA eligibility rules and 60 eligible tickets met the SLA. What rate should the dashboard report?',
    '75% of eligible tickets.',
    [
      '60% of eligible tickets.',
      '80% of eligible tickets.',
      '100% because excluded cases do not count as failures.',
    ],
    'The denominator is 100 − 20 = 80 eligible tickets. Dividing 60 by 80 gives 75%.',
  ),
  'power-bi': (
    'A monthly source refresh sometimes produces amounts as text. Where should you set and check the column type during preparation?',
    'In a repeatable Power Query transformation before loading the model.',
    [
      'Manually change the formatting of one visual after every refresh.',
      'Rename the column to Amount and assume that changes its data type.',
      'Sort the text values alphabetically before loading the model.',
    ],
    'Setting the type in Power Query makes the transformation repeatable and lets you detect invalid values before measures depend on the column.',
  ),
  'advanced-excel': (
    'A reconciliation formula should include new transactions added to an Excel Table next month. Which reference is most appropriate?',
    'A structured reference to the table’s Amount column.',
    [
      'A fixed reference such as A2:A100 chosen from the current row count.',
      'A reference to the header cell alone.',
      'A manually typed total that never reads the table.',
    ],
    'Structured references follow the table as it expands, so an added transaction is included without editing a hard-coded range.',
  ),
};
