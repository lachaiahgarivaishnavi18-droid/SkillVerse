import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'skillverse_cloud.dart';

import '../data/feedback_report.dart';
import '../data/app_content.dart';
import '../data/course_models.dart';
import '../data/exam_session.dart';
import '../data/learning_activity.dart';
import '../data/course_discovery.dart';
import '../data/interview_attempt.dart';

class AuthAccount {
  const AuthAccount({
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.passwordHash,
    this.cloudId,
  });

  final String fullName;
  final String email;
  final String mobile;
  final String passwordHash;
  final String? cloudId;

  // Existing accounts can derive the same ID without changing their login data.
  String get id =>
      cloudId ?? sha256.convert(utf8.encode(email.toLowerCase())).toString();

  Map<String, String> toJson() => {
    'fullName': fullName,
    'email': email,
    'mobile': mobile,
    'passwordHash': passwordHash,
  };

  factory AuthAccount.fromJson(Map<String, dynamic> json) => AuthAccount(
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    mobile: json['mobile'] as String? ?? '',
    passwordHash: json['passwordHash'] as String? ?? '',
  );
}

class TestAttempt {
  const TestAttempt({
    required this.id,
    required this.subject,
    required this.completedAt,
    required this.selections,
    required this.questionIds,
    required this.durationSeconds,
    this.mode = 'exam',
    this.courseId,
    this.moduleTitle,
    this.questions = const [],
    this.version,
    this.fullCourseAssessment = false,
  });

  final String id;
  final String subject;
  final DateTime completedAt;
  final Map<String, int> selections;
  final List<String> questionIds;
  final int durationSeconds;
  final String mode;
  final String? courseId;
  final String? moduleTitle;

  final List<QuizQuestion> questions;
  final String? version;
  final bool fullCourseAssessment;

  int get total => questionIds.length;

  List<QuizQuestion> get reviewQuestions {
    if (questions.isNotEmpty) return questions;
    return questionIds
        .map((id) => _historicQuizQuestions[id])
        .whereType<QuizQuestion>()
        .toList();
  }

  int get percentage {
    if (total == 0) return 0;
    final correct = reviewQuestions
        .where((q) => selections[q.id] == q.answerIndex)
        .length;
    return (100 * correct / total).round();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'completedAt': completedAt.toIso8601String(),
    'selections': selections,
    'questionIds': questionIds,
    'durationSeconds': durationSeconds,
    'mode': mode,
    'courseId': courseId,
    if (moduleTitle != null) 'moduleTitle': moduleTitle,
    if (questions.isNotEmpty)
      'questions': questions.map((q) => q.toJson()).toList(),
    'version': version,
    'fullCourseAssessment': fullCourseAssessment,
  };

  factory TestAttempt.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'] as String;
    final selections = (json['selections'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, value as int),
    );
    final savedQuestionIds = (json['questionIds'] as List<dynamic>?)
        ?.cast<String>()
        .toList();
    final questionIds =
        savedQuestionIds ??
        quizQuestions
            .where(
              (question) =>
                  !question.id.startsWith('case-v1-') &&
                  question.subject ==
                      (subject == 'Technical Fundamentals'
                          ? 'Technical Questions'
                          : subject),
            )
            .map((question) => question.id)
            .toList();
    return TestAttempt(
      id: json['id'] as String,
      subject: subject,
      completedAt: DateTime.parse(json['completedAt'] as String),
      selections: selections,
      questionIds: questionIds.isEmpty ? selections.keys.toList() : questionIds,
      durationSeconds: json['durationSeconds'] as int,
      mode: json['mode'] as String? ?? 'exam',
      courseId: json['courseId'] as String?,
      moduleTitle: json['moduleTitle'] as String?,
      questions:
          (json['questions'] as List?)
              ?.map(
                (item) => QuizQuestion.fromJson(item as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      version: json['version'] as String?,
      fullCourseAssessment: json['fullCourseAssessment'] == true,
    );
  }
}

final _historicQuizQuestions = {
  for (final question in [...quizQuestions, ...courseAssessmentQuestions])
    question.id: question,
};

class StudentProject {
  const StudentProject({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.technologies,
    String githubUrl = '',
    String? repositoryUrl,
    this.courseId,
    this.topic,
  }) : repositoryUrl = repositoryUrl ?? githubUrl;

  final String id;
  final String title;
  final String description;
  final String category;
  final String technologies;
  final String repositoryUrl;
  final String? courseId;
  final String? topic;

  String get githubUrl => repositoryUrl;

  static Uri? repositoryUri(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.authority.contains('@')) {
      return null;
    }
    return uri;
  }

  Map<String, String> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'technologies': technologies,
    'repositoryUrl': repositoryUrl,
    'courseId': ?courseId,
    'topic': ?topic,
  };

  factory StudentProject.fromJson(Map<String, dynamic> json) => StudentProject(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    technologies: json['technologies'] as String,
    repositoryUrl:
        json['repositoryUrl'] as String? ?? json['githubUrl'] as String? ?? '',
    courseId: json['courseId'] as String?,
    topic: json['topic'] as String?,
  );
}

class CourseCertificate {
  const CourseCertificate({
    required this.id,
    required this.userId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.completedAt,
    this.completionDateKnown = true,
  });

  final String id;
  final String userId;
  final String studentName;
  final String courseId;
  final String courseName;
  // For timestamp-free legacy records this holds the restoration date.
  final DateTime completedAt;
  final bool completionDateKnown;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'studentName': studentName,
    'courseId': courseId,
    'courseName': courseName,
    'completedAt': completedAt.toIso8601String(),
    'completionDateKnown': completionDateKnown,
  };

  factory CourseCertificate.fromJson(Map<String, dynamic> json) =>
      CourseCertificate(
        id: json['id'] as String,
        userId: json['userId'] as String,
        studentName: json['studentName'] as String,
        courseId: json['courseId'] as String,
        courseName: json['courseName'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
        completionDateKnown: json['completionDateKnown'] as bool? ?? true,
      );
}

final _lessonsById = {
  for (final course in courses)
    for (final lesson in course.allLessons)
      lesson.id: (course: course, lesson: lesson),
};

class AppStore extends ChangeNotifier {
  AppStore._(this._preferences, this.cloud) {
    _accounts = _readJsonList('auth_accounts', AuthAccount.fromJson);
    if (cloud case final backend?) {
      _applyCloudSession(backend.client.auth.currentUser);
      _authSubscription = backend.client.auth.onAuthStateChange.listen((event) {
        final user = event.session?.user;
        if (user == null || user.id == currentUserId) {
          _applyCloudSession(user);
        }
      }, onError: (Object _) {});
      return;
    }
    final savedEmail = _preferences.getString('auth_current_email');
    if (_preferences.getBool('auth_session_active') == true &&
        savedEmail != null) {
      final account = _accountForEmail(savedEmail);
      if (account != null && account.passwordHash.isNotEmpty) {
        _currentAccount = account;
      }
    }
  }

  final SharedPreferences _preferences;
  late List<AuthAccount> _accounts;
  AuthAccount? _currentAccount;

  final SkillverseCloud? cloud;
  StreamSubscription<AuthState>? _authSubscription;

  void _applyCloudSession(User? user) {
    final email = user?.email;
    _currentAccount = user == null || email == null
        ? null
        : AuthAccount(
            cloudId: user.id,
            fullName:
                (user.userMetadata?['full_name'] as String?)?.trim() ?? '',
            email: email,
            mobile: '',
            passwordHash: '',
          );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  static Future<AppStore> create({SkillverseCloud? cloud}) async {
    final store = AppStore._(await SharedPreferences.getInstance(), cloud);
    await store._migrateLegacyProgress();
    await store._migrateLegacyUserData();
    await store._snapshotLegacyAttempts();
    for (final course in courses) {
      await store._issueCertificate(course);
    }
    return store;
  }

  final _writingDiagnostics = <String>{};

  bool get diagnosticsEnabled =>
      isAuthenticated &&
      _preferences.getBool(_sessionKey('diagnostics_consent')) == true;

  Map<DiagnosticSource, int> get diagnosticCounts => {
    if (diagnosticsEnabled)
      for (final source in DiagnosticSource.values)
        source:
            _preferences.getInt(
              _sessionKey('diagnostics_count.${source.name}'),
            ) ??
            0,
  };

  Future<void> setDiagnosticsEnabled(bool enabled) async {
    final owner = currentUserId;
    if (owner == null) return;
    final key = _accountKey('diagnostics_consent', owner);
    await _write(key, () => _preferences.setBool(key, enabled));
    if (!enabled) {
      for (final source in DiagnosticSource.values) {
        final counter = _accountKey('diagnostics_count.${source.name}', owner);
        await _write(counter, () => _preferences.remove(counter));
      }
    }
    notifyListeners();
  }

  Future<void> recordDiagnostic(DiagnosticSource source) async {
    final owner = currentUserId;
    if (owner == null || !diagnosticsEnabled) return;
    final key = _accountKey('diagnostics_count.${source.name}', owner);
    final previous = _preferences.getInt(key) ?? 0;
    if (previous >= 999 || !_writingDiagnostics.add(key)) return;
    try {
      await _write(key, () => _preferences.setInt(key, previous + 1));
    } finally {
      _writingDiagnostics.remove(key);
    }
  }

  Future<bool> claimFirstLessonFeedback(String owner, String lessonId) async {
    if (currentUserId != owner ||
        !completedLessonIdsEver.contains(lessonId) ||
        completedLessonIdsEver.length != 1) {
      return false;
    }
    final key = _accountKey('first_lesson_feedback_seen', owner);
    if (_preferences.getBool(key) == true) return false;
    await _write(key, () => _preferences.setBool(key, true));
    return currentUserId == owner;
  }

  String _accountKey(String key, String userId) => 'account.$userId.$key';

  String _sessionKey(String key) {
    final userId = currentUserId;
    return userId == null ? key : _accountKey(key, userId);
  }

  Future<void> _migrateLegacyProgress() async {
    const ownerKey = 'legacy_progress_owner';
    if (_preferences.containsKey(ownerKey)) return;
    // Global data has no owner metadata. Only migrate it when there is one
    // existing account. Otherwise keep the original data as an archive.
    final owner = _accounts.length == 1 ? _accounts.single : null;
    if (owner != null) {
      for (final key in ['completed_lessons', 'passed_course_assessments']) {
        final legacy = _preferences.getStringList(key);
        final target = _accountKey(key, owner.id);
        if (legacy != null && !_preferences.containsKey(target)) {
          await _writeStringList(target, legacy);
        }
      }
      final attempts = _readJsonList(
        'test_attempts',
        TestAttempt.fromJson,
      ).where((attempt) => attempt.courseId != null).toList();
      final attemptsKey = _accountKey('course_attempts', owner.id);
      if (attempts.isNotEmpty && !_preferences.containsKey(attemptsKey)) {
        await _writeAttempts(attemptsKey, attempts);
      }
      final legacyName = _preferences.getString('display_name');
      if (legacyName != null) {
        final target = _accountKey('display_name', owner.id);
        if (!_preferences.containsKey(target)) {
          await _write(
            target,
            () => _preferences.setString(target, legacyName),
          );
        }
      }
    }
    await _write(
      ownerKey,
      () => _preferences.setString(ownerKey, owner?.id ?? ''),
    );
  }

  Future<void> _migrateLegacyUserData() async {
    const migratedKey = 'legacy_user_data_migrated';
    if (_preferences.getBool(migratedKey) == true) return;
    if (_accounts.length == 1) {
      final ownerId = _accounts.single.id;
      final bookmarksKey = _accountKey('bookmarks', ownerId);
      final bookmarks = _preferences.getStringList('bookmarks');
      if (bookmarks != null && !_preferences.containsKey(bookmarksKey)) {
        await _writeStringList(bookmarksKey, bookmarks);
      }
      final projectsKey = _accountKey('projects', ownerId);
      final projects = _preferences.getString('projects');
      if (projects != null && !_preferences.containsKey(projectsKey)) {
        await _write(
          projectsKey,
          () => _preferences.setString(projectsKey, projects),
        );
      }
      final attemptsKey = _accountKey('test_attempts', ownerId);
      final attempts = _readJsonList(
        'test_attempts',
        TestAttempt.fromJson,
      ).where((attempt) => attempt.courseId == null).toList();
      if (attempts.isNotEmpty && !_preferences.containsKey(attemptsKey)) {
        await _writeAttempts(attemptsKey, attempts);
      }
    }
    await _write(migratedKey, () => _preferences.setBool(migratedKey, true));
  }

  String get displayName => profileName.isEmpty ? 'Learner' : profileName;

  String get profileName {
    final account = _currentAccount;
    if (account == null) return '';
    if (cloud != null) return account.fullName;
    return _preferences.getString(_accountKey('display_name', account.id)) ??
        account.fullName;
  }

  String? get currentUserEmail => _currentAccount?.email;
  String? get currentUserId => _currentAccount?.id;
  bool get isAuthenticated => _currentAccount != null;
  Set<String> get bookmarks => _sessionProgress('bookmarks');
  Set<String> get reviewedInterviewQuestions =>
      _sessionProgress('reviewed_interview_questions');

  Future<void> markInterviewQuestionReviewed(String id) =>
      _addSessionProgress('reviewed_interview_questions', id);

  List<InterviewAttempt> get interviewAttempts => isAuthenticated
      ? List.unmodifiable(
          _readJsonList(
            _sessionKey('interview_attempts'),
            InterviewAttempt.fromJson,
          ),
        )
      : const [];

  String _interviewDraftKey(
    String category,
    String mode,
    String track,
    bool timed,
  ) => _sessionKey(
    'interview_draft.${jsonEncode([category, mode, track, if (!timed) 'untimed'])}',
  );

  InterviewDraft? interviewDraft(
    String category,
    String mode,
    String track, {
    bool timed = true,
  }) {
    if (!isAuthenticated) return null;
    final encoded = _preferences.getString(
      _interviewDraftKey(category, mode, track, timed),
    );
    if (encoded == null) return null;
    try {
      final draft = InterviewDraft.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      if (interviewAttempts.any((attempt) => attempt.id == draft.id)) {
        return null;
      }
      return draft;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> saveInterviewDraft(
    String ownerId,
    String category,
    String mode,
    String track,
    InterviewDraft draft, {
    bool timed = true,
  }) async {
    if (currentUserId != ownerId) return;
    final key = _interviewDraftKey(category, mode, track, timed);
    await _write(
      key,
      () => _preferences.setString(key, jsonEncode(draft.toJson())),
    );
  }

  final _resultSync = <String, Future<void>>{};

  String _resultPrefix(String ownerId) =>
      _accountKey('leaderboard_result.', ownerId);

  Future<void> _queueLeaderboardResult(
    String ownerId,
    String source,
    String resultId,
    Map<String, Object> answers,
  ) async {
    if (cloud == null || answers.isEmpty) return;
    final key = '${_resultPrefix(ownerId)}$source.$resultId';
    await _write(
      key,
      () => _preferences.setString(
        key,
        jsonEncode({'source': source, 'answers': answers}),
      ),
    );
    // Keep local completion usable offline. The next attempt or leaderboard
    // visit retries from disk if delivery fails.
    unawaited(_flushAfterCompletion());
  }

  Future<void> _flushAfterCompletion() async {
    try {
      await syncLeaderboardResults();
    } catch (_) {
      // The outbox entry remains on disk, and the leaderboard offers Retry.
    }
  }

  Future<void> syncLeaderboardResults() async {
    final backend = cloud;
    final ownerId = currentUserId;
    if (backend == null || ownerId == null) return;
    final previous = _resultSync[ownerId];
    final next = () async {
      if (previous != null) {
        try {
          await previous;
        } catch (_) {
          // Retry the same durable entries.
        }
      }
      final prefix = _resultPrefix(ownerId);
      final keys = _preferences.getKeys().where(
        (key) => key.startsWith(prefix),
      );
      for (final key in keys) {
        if (ownerId != currentUserId) return;
        final queued = _preferences.getString(key);
        if (queued == null) continue;
        final result = jsonDecode(queued) as Map<String, dynamic>;
        await backend.submitResult(
          ownerId,
          result['source'] as String,
          result['answers'] as Map<String, dynamic>,
        );
        if (_preferences.getString(key) == queued) {
          await _write(key, () => _preferences.remove(key));
        }
      }
    }();
    _resultSync[ownerId] = next;
    try {
      await next;
    } finally {
      if (identical(_resultSync[ownerId], next)) _resultSync.remove(ownerId);
    }
  }

  Future<void> saveModuleQuizPoints(Map<String, int> selections) async {
    final ownerId = currentUserId;
    if (ownerId == null) return;
    await _queueLeaderboardResult(
      ownerId,
      'quiz',
      DateTime.now().microsecondsSinceEpoch.toString(),
      selections,
    );
  }

  Future<void> saveInterviewAttempt(
    InterviewAttempt attempt,
    String ownerId,
  ) async {
    if (currentUserId != ownerId) {
      throw StateError('The active account changed.');
    }
    final draft = interviewDraft(
      attempt.category,
      attempt.mode,
      attempt.track,
      timed: attempt.timed,
    );
    final draftKey = _interviewDraftKey(
      attempt.category,
      attempt.mode,
      attempt.track,
      attempt.timed,
    );
    final key = _sessionKey('interview_attempts');
    await _write(
      key,
      () => _preferences.setString(
        key,
        jsonEncode([
          attempt.toJson(),
          for (final item in _readJsonList(key, InterviewAttempt.fromJson))
            if (item.id != attempt.id) item.toJson(),
        ]),
      ),
    );
    await _queueLeaderboardResult(ownerId, 'mock_interview', attempt.id, {
      for (final id in attempt.questionIds)
        if (attempt.responses[id] case final response?
            when response.correct != null && response.text.trim().isNotEmpty)
          id: true,
    });
    if (currentUserId == ownerId && draft?.id == attempt.id) {
      // A saved result also supersedes the draft if the cleanup cannot complete.
      try {
        await _preferences.remove(draftKey);
      } catch (_) {
        // History takes precedence over stale drafts.
      }
    }
    notifyListeners();
  }

  List<LessonCompletion> get _datedLessons => isAuthenticated
      ? _readJsonList(
          _sessionKey('lesson_completions'),
          LessonCompletion.fromJson,
        )
      : const [];

  DateTime? _courseReset(String courseId) {
    final value = _preferences.getString(_sessionKey('course_reset.$courseId'));
    return value == null ? null : DateTime.tryParse(value);
  }

  bool _isCurrentCourseRecord(String courseId, DateTime? date) {
    final reset = _courseReset(courseId);
    return reset == null || (date != null && date.isAfter(reset));
  }

  Set<String> get completedLessonIdsEver => {
    ..._sessionProgress('completed_lessons'),
    ..._datedLessons.map((entry) => entry.lessonId),
  };

  Set<String> get completedLessons => {
    for (final id in _sessionProgress('completed_lessons'))
      if (_isCurrentCourseRecord(_lessonsById[id]?.course.id ?? '', null)) id,
    for (final entry in _datedLessons)
      if (_isCurrentCourseRecord(
        _lessonsById[entry.lessonId]?.course.id ?? '',
        entry.completedAt,
      ))
        entry.lessonId,
  };

  Set<String> get passedCourseAssessments => {
    for (final id in _sessionProgress('passed_course_assessments'))
      if (_isCurrentCourseRecord(id, _coursePassDate(id))) id,
  };

  DateTime? _coursePassDate(String courseId) {
    final value = _preferences.getString(
      _sessionKey('course_pass_date.$courseId'),
    );
    return value == null ? null : DateTime.tryParse(value);
  }

  List<LearningActivity> get learningActivity {
    final dated = _datedLessons;
    final datedIds = dated.map((entry) => entry.lessonId).toSet();
    LearningActivity lessonActivity(String id, DateTime? date) {
      final entry = _lessonsById[id];
      return LearningActivity(
        title: entry?.lesson.title ?? id,
        kind: 'Lesson completed',
        date: date,
        detail: entry?.course.title,
      );
    }

    final activity = [
      for (final entry in dated)
        lessonActivity(entry.lessonId, entry.completedAt),
      for (final id in _sessionProgress('completed_lessons'))
        if (!datedIds.contains(id)) lessonActivity(id, null),
      for (final attempt in attempts)
        LearningActivity(
          title: attempt.moduleTitle ?? attempt.subject,
          kind: switch (attempt.mode) {
            'practice' || 'modulePractice' => 'Practice session',
            _ => attempt.courseId == null ? 'Quiz' : 'Final assessment',
          },
          date: attempt.completedAt,
          detail: '${attempt.percentage}% score',
        ),
      for (final attempt in interviewAttempts)
        LearningActivity(
          title: attempt.category,
          kind: 'Mock interview',
          date: attempt.completedAt,
          detail: attempt.correct + attempt.incorrect == 0
              ? 'Unscored'
              : '${attempt.score}% self-assessed',
        ),
    ];
    activity.sort((a, b) {
      if (a.date == null) return b.date == null ? 0 : 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return activity;
  }

  int? get weeklyLearningGoal => isAuthenticated
      ? _preferences.getInt(_sessionKey('weekly_learning_goal'))
      : null;

  int weeklyActivityCount(DateTime now) {
    final start = startOfLearningWeek(now);
    return learningActivity.where((activity) {
      final date = activity.date;
      return date != null && !date.isBefore(start) && !date.isAfter(now);
    }).length;
  }

  Future<void> setWeeklyLearningGoal(int? target) async {
    if (!isAuthenticated) return;
    if (target != null && (target < 1 || target > 100)) {
      throw ArgumentError.value(target, 'target', 'Choose 1–100 activities.');
    }
    final key = _sessionKey('weekly_learning_goal');
    await _write(
      key,
      () => target == null
          ? _preferences.remove(key)
          : _preferences.setInt(key, target),
    );
    notifyListeners();
  }

  Future<void> resetCourseProgress(Course course) async {
    if (!isAuthenticated) return;
    if (!courses.any((item) => item.id == course.id)) {
      throw ArgumentError.value(course.id, 'course', 'Unknown course');
    }
    final key = _sessionKey('course_reset.${course.id}');
    final reset = DateTime.now().toUtc().toIso8601String();
    await _write(key, () => _preferences.setString(key, reset));
    notifyListeners();
  }

  List<TestAttempt> get attempts {
    if (!isAuthenticated) return const [];
    final all = [
      ..._readJsonList(_sessionKey('test_attempts'), TestAttempt.fromJson),
      ..._readJsonList(_sessionKey('course_attempts'), TestAttempt.fromJson),
    ]..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return List.unmodifiable(all);
  }

  List<StudentProject> get projects => isAuthenticated
      ? List.unmodifiable(
          _readJsonList(_sessionKey('projects'), StudentProject.fromJson),
        )
      : const [];
  List<AuthAccount> get accounts => List.unmodifiable(_accounts);

  int get completedLessonCount => completedLessons.length;

  Set<String> _sessionProgress(String key) => isAuthenticated
      ? Set.unmodifiable(_readStringSet(_sessionKey(key)))
      : const {};

  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    final pattern = RegExp(
      r"^[a-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$%&'*+/=?^_`{|}~-]+)*@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$",
      caseSensitive: false,
    );
    return pattern.hasMatch(email) ? null : 'Enter a valid email address.';
  }

  static const _passwordIterations = 600000;

  // PBKDF2-HMAC-SHA256, one 32-byte block with a per-account random salt.
  static List<int> _derivePassword(String password, List<int> salt) {
    final hmac = Hmac(sha256, utf8.encode(password));
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.of(block);
    for (var round = 1; round < _passwordIterations; round++) {
      block = hmac.convert(block).bytes;
      for (var byte = 0; byte < result.length; byte++) {
        result[byte] ^= block[byte];
      }
    }
    return result;
  }

  static String _hashPassword(String password) {
    final random = Random.secure();
    final salt = List.generate(16, (_) => random.nextInt(256));
    final digest = _derivePassword(password, salt);
    return 'pbkdf2-sha256:${base64Encode(salt)}:${base64Encode(digest)}';
  }

  static bool _matchesPassword(String password, String stored) {
    final parts = stored.split(':');
    if (parts.length == 1) {
      return sha256.convert(utf8.encode(password)).toString() == stored;
    }
    if (parts.length != 3 || parts.first != 'pbkdf2-sha256') return false;
    final expected = base64Decode(parts[2]);
    final actual = _derivePassword(password, base64Decode(parts[1]));
    if (expected.length != actual.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  AuthAccount? _accountForEmail(String email) {
    for (final account in _accounts) {
      if (account.email.toLowerCase() == email.toLowerCase()) {
        return account;
      }
    }
    return null;
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
    required String confirmPassword,
  }) async {
    final trimmedName = fullName.trim();
    final trimmedEmail = email.trim();
    final trimmedMobile = mobile.trim();
    final trimmedPassword = password.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(
        fullName,
        'fullName',
        'Full name cannot be empty.',
      );
    }
    final emailError = validateEmail(trimmedEmail);
    if (emailError != null) throw ArgumentError(emailError);
    if (trimmedPassword.length < 6) {
      throw ArgumentError('Password must be at least 6 characters.');
    }
    if (password != confirmPassword) {
      throw ArgumentError('Passwords do not match.');
    }
    if (trimmedName.length > 120) {
      throw ArgumentError('Use at most 120 characters for your full name.');
    }
    if (cloud case final backend?) {
      return backend.signUp(trimmedName, trimmedEmail, password);
    }
    if (_accountForEmail(trimmedEmail) != null) {
      throw StateError('An account already exists for this email.');
    }
    final account = AuthAccount(
      fullName: trimmedName,
      email: trimmedEmail,
      mobile: trimmedMobile,
      passwordHash: _hashPassword(password),
    );
    _accounts = [account, ..._accounts];
    await _persistAccounts();
    return false;
  }

  Future<void> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final trimmedEmail = email.trim();
    if (cloud case final backend?) {
      final emailError = validateEmail(trimmedEmail);
      if (emailError != null) throw ArgumentError(emailError);
      _applyCloudSession(
        await backend.signIn(trimmedEmail, password, rememberMe),
      );
      return;
    }
    final account = _accountForEmail(trimmedEmail);
    if (account == null) {
      final emailError = validateEmail(trimmedEmail);
      if (emailError != null) throw ArgumentError(emailError);
      throw StateError('No account found for this email.');
    }
    if (!_matchesPassword(password, account.passwordHash)) {
      throw StateError('Incorrect password.');
    }
    final verified = account.passwordHash.startsWith('pbkdf2-sha256:')
        ? account
        : await _replacePassword(account, password);
    await _activateSession(verified, persistLogin: rememberMe);
  }

  Future<void> resetPassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    if (cloud case final backend?) {
      await backend.changePassword(email.trim(), currentPassword, newPassword);
      return;
    }
    final account = _accountForEmail(email.trim());
    if (account == null ||
        !_matchesPassword(currentPassword, account.passwordHash)) {
      throw StateError('Incorrect email or current password.');
    }
    if (newPassword.trim().length < 6) {
      throw ArgumentError('Password must be at least 6 characters.');
    }
    await _replacePassword(account, newPassword);
  }

  Future<AuthAccount> _replacePassword(
    AuthAccount account,
    String password,
  ) async {
    final updated = AuthAccount(
      fullName: account.fullName,
      email: account.email,
      mobile: account.mobile,
      passwordHash: _hashPassword(password),
    );
    _accounts = _accounts
        .map((item) => item.id == account.id ? updated : item)
        .toList();
    await _persistAccounts();
    if (currentUserId == updated.id) _currentAccount = updated;
    return updated;
  }

  Future<void> _persistAccounts() => _write(
    'auth_accounts',
    () => _preferences.setString(
      'auth_accounts',
      jsonEncode(_accounts.map((item) => item.toJson()).toList()),
    ),
  );

  Future<void> logout() async {
    if (cloud case final backend?) {
      await backend.client.auth.signOut(scope: SignOutScope.local);
      _applyCloudSession(null);
      return;
    }
    await _write(
      'auth_current_email',
      () => _preferences.remove('auth_current_email'),
    );
    await _write(
      'auth_session_active',
      () => _preferences.setBool('auth_session_active', false),
    );
    _currentAccount = null;
    notifyListeners();
  }

  Future<void> _activateSession(
    AuthAccount account, {
    required bool persistLogin,
  }) async {
    if (persistLogin) {
      await _write(
        'auth_current_email',
        () => _preferences.setString('auth_current_email', account.email),
      );
      await _write(
        'auth_session_active',
        () => _preferences.setBool('auth_session_active', true),
      );
    } else {
      await _write(
        'auth_current_email',
        () => _preferences.remove('auth_current_email'),
      );
      await _write(
        'auth_session_active',
        () => _preferences.setBool('auth_session_active', false),
      );
    }
    _currentAccount = account;
    for (final course in courses) {
      await _issueCertificate(course);
    }
    notifyListeners();
  }

  CourseCertificate? certificateFor(Course course) {
    if (!isAuthenticated) return null;
    final value = _preferences.getString(
      _sessionKey('certificate.${course.id}'),
    );
    if (value == null) return null;
    final certificate = CourseCertificate.fromJson(
      jsonDecode(value) as Map<String, dynamic>,
    );
    return certificate.userId == currentUserId &&
            certificate.courseId == course.id
        ? certificate
        : null;
  }

  bool isCourseComplete(Course course) =>
      (_courseReset(course.id) == null && certificateFor(course) != null) ||
      (passedCourseAssessments.contains(course.id) &&
          course.allLessons.every(
            (lesson) => completedLessons.contains(lesson.id),
          ));

  Set<String> get savedCourseIds => _sessionProgress('saved_courses');

  LearningGoal? get learningGoal {
    if (!isAuthenticated) return null;
    final name = _preferences.getString(_sessionKey('learning_goal'));
    return LearningGoal.values.where((goal) => goal.name == name).firstOrNull;
  }

  Future<void> setLearningGoal(LearningGoal goal) async {
    if (!isAuthenticated) return;
    final key = _sessionKey('learning_goal');
    await _write(key, () => _preferences.setString(key, goal.name));
    notifyListeners();
  }

  Future<void> toggleSavedCourse(Course course) async {
    if (!isAuthenticated) return;
    final key = _sessionKey('saved_courses');
    final saved = _readStringSet(key);
    if (!saved.add(course.id)) saved.remove(course.id);
    await _writeStringList(key, saved.toList());
    notifyListeners();
  }

  Map<String, dynamic> get _lessonVisitRecords {
    if (!isAuthenticated) return {};
    final value = _preferences.getString(_sessionKey('course_lesson_visits'));
    return value == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Map<String, String> get _lessonVisits => {
    for (final entry in _lessonVisitRecords.entries)
      if (entry.value case final String legacy
          when _isCurrentCourseRecord(entry.key, null))
        entry.key: legacy
      else if (entry.value case final Map visit
          when _isCurrentCourseRecord(
            entry.key,
            DateTime.tryParse(visit['date'] as String? ?? ''),
          ))
        entry.key: visit['lessonId'] as String,
  };

  String _readingPositionKey(String lessonId) {
    final course = _lessonsById[lessonId]?.course;
    final reset = course == null ? null : _courseReset(course.id);
    return reset == null
        ? 'lesson_position.$lessonId'
        : 'lesson_position.$lessonId.${reset.microsecondsSinceEpoch}';
  }

  double lessonReadingOffset(String lessonId) {
    if (!isAuthenticated) return 0;
    final offset = _preferences.getDouble(
      _sessionKey(_readingPositionKey(lessonId)),
    );
    return offset != null && offset.isFinite && offset >= 0 ? offset : 0;
  }

  Future<void> saveLessonReadingOffset(
    String accountId,
    String lessonId,
    double offset,
  ) async {
    if (currentUserId != accountId || !offset.isFinite || offset < 0) return;
    final key = _accountKey(_readingPositionKey(lessonId), accountId);
    if (_preferences.getDouble(key) == offset) return;
    await _write(key, () => _preferences.setDouble(key, offset));
  }

  Future<void> recordLessonVisit(Lesson lesson) async {
    if (!isAuthenticated) return;
    final course = courses
        .where((item) => item.allLessons.any((entry) => entry.id == lesson.id))
        .firstOrNull;
    if (course == null) return;
    final key = _sessionKey('course_lesson_visits');
    final visits = _lessonVisits;
    if (visits.keys.lastOrNull == course.id && visits[course.id] == lesson.id) {
      return;
    }
    final records = _lessonVisitRecords..remove(course.id);
    records[course.id] = {
      'lessonId': lesson.id,
      'date': DateTime.now().toUtc().toIso8601String(),
    };
    await _write(key, () => _preferences.setString(key, jsonEncode(records)));
    notifyListeners();
  }

  bool hasStartedCourse(Course course) =>
      _lessonVisits.containsKey(course.id) ||
      course.allLessons.any((lesson) => completedLessons.contains(lesson.id));

  List<Course> get coursesInProgress {
    final recent = _lessonVisits.keys.toList().reversed;
    final byId = {for (final course in courses) course.id: course};
    final ordered = {for (final id in recent) ?byId[id], ...courses};
    return ordered
        .where(
          (course) => !isCourseComplete(course) && hasStartedCourse(course),
        )
        .toList();
  }

  ({int completed, int total}) lessonProgress(
    Iterable<Lesson> lessons, {
    Set<String>? completedIds,
  }) {
    final completed = completedIds ?? completedLessons;
    return (
      completed: lessons
          .where((lesson) => completed.contains(lesson.id))
          .length,
      total: lessons.length,
    );
  }

  double progressFor(Course course) {
    final progress = lessonProgress(course.allLessons);
    return progress.total == 0 ? 0 : progress.completed / progress.total;
  }

  Lesson? continueLesson(Course course, {String? difficulty}) {
    final lessons = course.allLessons;
    final lastId = _lessonVisits[course.id];
    final visited = lessons.indexWhere((lesson) => lesson.id == lastId);
    final ordered = visited < 0
        ? lessons
        : [...lessons.skip(visited), ...lessons.take(visited)];
    final completed = completedLessons;
    return ordered
        .where(
          (lesson) =>
              !completed.contains(lesson.id) &&
              (difficulty == null || lesson.difficulty.label == difficulty),
        )
        .firstOrNull;
  }

  Future<void> _issueCertificate(
    Course course, {
    DateTime? completionTime,
  }) async {
    final account = _currentAccount;
    if (account == null || certificateFor(course) != null) return;
    if (!passedCourseAssessments.contains(course.id) ||
        !course.allLessons.every(
          (lesson) => completedLessons.contains(lesson.id),
        )) {
      return;
    }
    final passedAttempts = attempts.where(
      (attempt) =>
          _isCurrentCourseRecord(course.id, attempt.completedAt) &&
          _passedFinal(course, attempt),
    );
    final completedAt =
        completionTime ??
        passedAttempts.firstOrNull?.completedAt ??
        DateTime.now();
    final certificate = CourseCertificate(
      id: 'SV-${sha256.convert(utf8.encode('${account.id}:${course.id}')).toString().substring(0, 24).toUpperCase()}',
      userId: account.id,
      studentName: account.fullName,
      courseId: course.id,
      courseName: course.title,
      completedAt: completedAt,
      completionDateKnown: completionTime != null || passedAttempts.isNotEmpty,
    );
    final key = _accountKey('certificate.${course.id}', account.id);
    await _write(
      key,
      () => _preferences.setString(key, jsonEncode(certificate.toJson())),
    );
  }

  Set<String> _readStringSet(String key) =>
      _preferences.getStringList(key)?.toSet() ?? <String>{};

  List<T> _readJsonList<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
  ) {
    final value = _preferences.getString(key);
    if (value == null || value.isEmpty) return <T>[];
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw FormatException('Stored $key data is not a list.');
    }
    return decoded
        .map((item) => decode(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> addInterviewBookmarks(Iterable<String> ids) async {
    if (!isAuthenticated) return;
    final key = _sessionKey('bookmarks');
    final saved = _readStringSet(key)..addAll(ids);
    await _writeStringList(key, saved.toList());
    notifyListeners();
  }

  Future<void> toggleBookmark(String questionId) async {
    if (!isAuthenticated) return;
    final key = _sessionKey('bookmarks');
    final bookmarks = _readStringSet(key);
    if (!bookmarks.add(questionId)) bookmarks.remove(questionId);
    await _writeStringList(key, bookmarks.toList());
    notifyListeners();
  }

  Future<void> markLessonComplete(String lessonId) async {
    final accountId = currentUserId;
    final course = _lessonsById[lessonId]?.course;
    if (course == null) throw ArgumentError('Unknown lesson.');
    if (accountId == null || completedLessons.contains(lessonId)) return;
    final completedAt = DateTime.now().toUtc();
    final key = _sessionKey('lesson_completions');
    final entries = [..._datedLessons, LessonCompletion(lessonId, completedAt)];
    await _write(key, () => _preferences.setString(key, jsonEncode(entries)));
    if (currentUserId == accountId) {
      await _issueCertificate(course, completionTime: completedAt);
    }
    notifyListeners();
  }

  Future<void> markCourseAssessmentPassed(String courseId) async {
    final course = courses.where((course) => course.id == courseId).firstOrNull;
    if (course == null) {
      throw ArgumentError('Unknown course.');
    }
    final eligible = attempts
        .where(
          (attempt) =>
              _isCurrentCourseRecord(courseId, attempt.completedAt) &&
              _passedFinal(course, attempt),
        )
        .firstOrNull;
    if (eligible == null) {
      throw StateError('Pass the complete final assessment first.');
    }
    final accountId = currentUserId;
    final dateKey = _sessionKey('course_pass_date.$courseId');
    await _write(
      dateKey,
      () => _preferences.setString(
        dateKey,
        eligible.completedAt.toIso8601String(),
      ),
    );
    if (currentUserId != accountId) return;
    await _addSessionProgress('passed_course_assessments', courseId);
    if (currentUserId == accountId) await _issueCertificate(course);
  }

  bool _passedFinal(Course course, TestAttempt attempt) {
    final requiredIds = course.finalQuestions.map((q) => q.id).toSet();
    return attempt.courseId == course.id &&
        attempt.mode == 'exam' &&
        ((attempt.fullCourseAssessment && attempt.questions.isNotEmpty) ||
            (requiredIds.isNotEmpty &&
                attempt.questionIds.length == requiredIds.length &&
                attempt.questionIds.toSet().containsAll(requiredIds))) &&
        attempt.percentage >= 70;
  }

  Future<void> _addSessionProgress(String key, String value) async {
    if (!isAuthenticated) return;
    final target = _sessionKey(key);
    final progress = _readStringSet(target)..add(value);
    await _writeStringList(target, progress.toList());
    notifyListeners();
  }

  Future<void> updateDisplayName(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name cannot be empty.');
    }
    if (!isAuthenticated) return;
    if (trimmedName.length > 120) {
      throw ArgumentError('Use at most 120 characters for your full name.');
    }
    if (cloud case final backend?) {
      final response = await backend.client.auth.updateUser(
        UserAttributes(data: {'full_name': trimmedName}),
      );
      if (response.user?.id == currentUserId) _applyCloudSession(response.user);
      return;
    }
    final key = _sessionKey('display_name');
    await _write(key, () => _preferences.setString(key, trimmedName));
    notifyListeners();
  }

  TestAttempt _freezeAttempt(TestAttempt attempt) {
    if (attempt.questions.isNotEmpty) return attempt;
    final review = attempt.reviewQuestions;
    if (review.isEmpty) return attempt;
    return TestAttempt(
      id: attempt.id,
      subject: attempt.subject,
      completedAt: attempt.completedAt,
      selections: attempt.selections,
      questionIds: attempt.questionIds,
      durationSeconds: attempt.durationSeconds,
      mode: attempt.mode,
      courseId: attempt.courseId,
      moduleTitle: attempt.moduleTitle,
      questions: review,
      version: assessmentVersion(review),
      fullCourseAssessment: isFullCourseAssessment(attempt.courseId, review),
    );
  }

  Future<void> _snapshotLegacyAttempts() async {
    const marker = 'assessment_snapshots_v1';
    if (_preferences.getBool(marker) == true) return;
    for (final key in _preferences.getKeys()) {
      if (!key.startsWith('account.') ||
          !(key.endsWith('.test_attempts') ||
              key.endsWith('.course_attempts'))) {
        continue;
      }
      final List<TestAttempt> saved;
      try {
        saved = _readJsonList(key, TestAttempt.fromJson);
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
      final frozen = saved.map(_freezeAttempt).toList();
      if (frozen.asMap().entries.any(
        (entry) => !identical(entry.value, saved[entry.key]),
      )) {
        await _writeAttempts(key, frozen);
      }
    }
    await _write(marker, () => _preferences.setBool(marker, true));
  }

  String _examKey(
    String owner,
    String subject,
    String? courseId,
  ) => _accountKey(
    'exam_draft.${courseId == null ? 'subject.$subject' : 'course.$courseId'}',
    owner,
  );

  ExamDraft? _readExam(String key) {
    final saved = _preferences.getString(key);
    if (saved == null) return null;
    try {
      final draft = ExamDraft.fromJson(
        jsonDecode(saved) as Map<String, dynamic>,
      );
      final courseId = draft.courseId;
      return courseId == null ||
              _isCurrentCourseRecord(courseId, draft.startedAt)
          ? draft
          : null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  ExamDraft? examDraft(String subject, String? courseId) {
    final owner = currentUserId;
    return owner == null ? null : _readExam(_examKey(owner, subject, courseId));
  }

  List<ExamDraft> get examDrafts {
    final owner = currentUserId;
    if (owner == null) return [];
    final prefix = _accountKey('exam_draft.', owner);
    return [
      for (final key in _preferences.getKeys())
        if (key.startsWith(prefix)) ?_readExam(key),
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  Future<void> saveExamDraft(ExamDraft draft, String owner) async {
    if (currentUserId != owner) throw StateError('The exam account changed.');
    final key = _examKey(owner, draft.subject, draft.courseId);
    final existing = _readExam(key);
    if (existing != null && existing.id != draft.id) {
      throw StateError('Another exam is already saved for this subject.');
    }
    await _write(
      key,
      () => _preferences.setString(key, jsonEncode(draft.toJson())),
    );
    if (existing == null) notifyListeners();
  }

  Future<void> discardExamDraft(ExamDraft draft) async {
    final owner = currentUserId;
    if (owner == null) return;
    final key = _examKey(owner, draft.subject, draft.courseId);
    if (_readExam(key)?.id != draft.id) return;
    await _write(key, () => _preferences.remove(key));
    notifyListeners();
  }

  bool isFullCourseAssessment(String? courseId, List<QuizQuestion> questions) {
    if (courseId == null) return false;
    final course = courses.where((course) => course.id == courseId).firstOrNull;
    if (course == null || course.finalQuestions.isEmpty) return false;
    return assessmentVersion(course.finalQuestions) ==
        assessmentVersion(questions);
  }

  final _attemptWrites = <String, Future<void>>{};

  Future<void> saveAttempt(TestAttempt attempt) async {
    final accountId = currentUserId;
    if (accountId == null) return;
    final key = _accountKey('attempt.${attempt.id}', accountId);
    final active = _attemptWrites[key];
    if (active != null) return active;
    final write = _saveAttempt(attempt, accountId);
    _attemptWrites[key] = write;
    try {
      await write;
    } finally {
      _attemptWrites.remove(key);
    }
  }

  Future<void> _saveAttempt(TestAttempt attempt, String accountId) async {
    final course = courses
        .where((course) => course.id == attempt.courseId)
        .firstOrNull;
    if (attempt.courseId != null &&
        (course == null ||
            !course.allLessons.every(
              (lesson) => completedLessons.contains(lesson.id),
            ))) {
      throw StateError(
        'Complete all course lessons before the final assessment.',
      );
    }
    final key = _sessionKey(
      attempt.courseId == null ? 'test_attempts' : 'course_attempts',
    );
    final saved = _readJsonList(key, TestAttempt.fromJson);
    final previous = saved.where((item) => item.id == attempt.id).firstOrNull;
    if (previous == null) {
      attempt = _freezeAttempt(attempt);
      await _writeAttempts(key, [attempt, ...saved]);
    } else {
      attempt = previous;
    }
    if (attempt.mode != 'modulePractice') {
      await _queueLeaderboardResult(
        accountId,
        course == null ? 'quiz' : 'assessment',
        attempt.id,
        {for (final id in attempt.questionIds) id: ?attempt.selections[id]},
      );
    }
    if (currentUserId == accountId &&
        course != null &&
        _isCurrentCourseRecord(course.id, attempt.completedAt) &&
        _passedFinal(course, attempt)) {
      await markCourseAssessmentPassed(course.id);
    }
    notifyListeners();
  }

  Future<void> _writeAttempts(String key, List<TestAttempt> attempts) => _write(
    key,
    () => _preferences.setString(
      key,
      jsonEncode(attempts.map((item) => item.toJson()).toList()),
    ),
  );

  Future<void> saveProject(StudentProject project) async {
    if (!isAuthenticated) return;
    if (project.repositoryUrl.trim().isNotEmpty &&
        StudentProject.repositoryUri(project.repositoryUrl) == null) {
      throw ArgumentError('Enter a valid HTTP or HTTPS repository address.');
    }
    final key = _sessionKey('projects');
    final projects = _readJsonList(key, StudentProject.fromJson);
    final index = projects.indexWhere((item) => item.id == project.id);
    if (index < 0) {
      projects.insert(0, project);
    } else {
      projects[index] = project;
    }
    await _persistProjects(key, projects);
    notifyListeners();
  }

  Future<void> deleteProject(String id) async {
    if (!isAuthenticated) return;
    final key = _sessionKey('projects');
    final projects = _readJsonList(key, StudentProject.fromJson)
      ..removeWhere((project) => project.id == id);
    await _persistProjects(key, projects);
    notifyListeners();
  }

  Future<void> restoreDeletedProject(
    StudentProject project,
    String ownerId,
  ) async {
    if (currentUserId != ownerId ||
        projects.any((existing) => existing.id == project.id)) {
      return;
    }
    final key = _accountKey('projects', ownerId);
    final stored = _readJsonList(key, StudentProject.fromJson);
    await _persistProjects(key, [project, ...stored]);
    notifyListeners();
  }

  Future<void> _persistProjects(String key, List<StudentProject> projects) =>
      _write(
        key,
        () => _preferences.setString(
          key,
          jsonEncode(projects.map((project) => project.toJson()).toList()),
        ),
      );

  Future<void> _writeStringList(String key, List<String> value) =>
      _write(key, () => _preferences.setStringList(key, value));

  Future<void> _write(String key, Future<bool> Function() operation) async {
    if (!await operation()) {
      throw StateError('Could not persist $key on this device.');
    }
  }
}
