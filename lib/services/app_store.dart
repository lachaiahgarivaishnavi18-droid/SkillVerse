import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_content.dart';
import '../data/course_models.dart';

class AuthAccount {
  const AuthAccount({
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.passwordHash,
  });

  final String fullName;
  final String email;
  final String mobile;
  final String passwordHash;

  // Existing accounts can derive the same ID without changing their login data.
  String get id => sha256.convert(utf8.encode(email.toLowerCase())).toString();

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

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.name,
    required this.score,
    required this.period,
    required this.badge,
  });

  final String name;
  final int score;
  final String period;
  final String badge;
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
  });

  final String id;
  final String subject;
  final DateTime completedAt;
  final Map<String, int> selections;
  final List<String> questionIds;
  final int durationSeconds;
  final String mode;
  final String? courseId;

  int get total => questionIds.length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'completedAt': completedAt.toIso8601String(),
    'selections': selections,
    'questionIds': questionIds,
    'durationSeconds': durationSeconds,
    'mode': mode,
    'courseId': courseId,
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
    );
  }
}

class StudentProject {
  const StudentProject({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.technologies,
    this.githubUrl = '',
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String technologies;
  final String githubUrl;

  Map<String, String> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'technologies': technologies,
    'githubUrl': githubUrl,
  };

  factory StudentProject.fromJson(Map<String, dynamic> json) => StudentProject(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    category: json['category'] as String,
    technologies: json['technologies'] as String,
    githubUrl: json['githubUrl'] as String? ?? '',
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

class AppStore extends ChangeNotifier {
  AppStore._(this._preferences) {
    _accounts = _readJsonList('auth_accounts', AuthAccount.fromJson);
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

  static Future<AppStore> create() async {
    final store = AppStore._(await SharedPreferences.getInstance());
    await store._migrateLegacyProgress();
    await store._migrateLegacyUserData();
    for (final course in courses) {
      await store._issueCertificate(course);
    }
    return store;
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

  String get displayName {
    final account = _currentAccount;
    if (account == null) return 'Learner';
    return _preferences.getString(_accountKey('display_name', account.id)) ??
        account.fullName;
  }

  String? get currentUserEmail => _currentAccount?.email;
  String? get currentUserId => _currentAccount?.id;
  bool get isAuthenticated => _currentAccount != null;
  Set<String> get bookmarks => _sessionProgress('bookmarks');
  Set<String> get completedLessons => _sessionProgress('completed_lessons');
  Set<String> get passedCourseAssessments =>
      _sessionProgress('passed_course_assessments');
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

  Future<void> signUp({
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
  }

  Future<void> signIn({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final trimmedEmail = email.trim();
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

  List<LeaderboardEntry> leaderboardFor(String period) {
    final now = DateTime.now();
    final entries = <LeaderboardEntry>[];
    final currentDisplayName = displayName;
    final userScore = attempts
        .where((attempt) {
          if (period == 'weekly') {
            return attempt.completedAt.isAfter(
              now.subtract(const Duration(days: 7)),
            );
          }
          if (period == 'monthly') {
            return attempt.completedAt.isAfter(
              now.subtract(const Duration(days: 30)),
            );
          }
          return true;
        })
        .fold<int>(0, (total, attempt) => total + _scoreForAttempt(attempt));
    entries.add(
      LeaderboardEntry(
        name: currentDisplayName,
        score: userScore,
        period: period,
        badge: 'You',
      ),
    );
    const sampleNames = [
      'Ava',
      'Noah',
      'Mia',
      'Ethan',
      'Isla',
      'Leo',
      'Zoe',
      'Omar',
      'Priya',
      'Daniel',
    ];
    for (var i = 0; i < sampleNames.length; i++) {
      final score =
          (period == 'global'
              ? 88 + i * 3
              : period == 'weekly'
              ? 70 + i * 5
              : 72 + i * 4) +
          (i * 2);
      entries.add(
        LeaderboardEntry(
          name: sampleNames[i],
          score: score,
          period: period,
          badge: '#${i + 1}',
        ),
      );
    }
    entries.sort((a, b) => b.score.compareTo(a.score));
    return entries.take(10).toList();
  }

  int _scoreForAttempt(TestAttempt attempt) {
    final questionById = {
      for (final question in [...quizQuestions, ...courseAssessmentQuestions])
        question.id: question,
    };
    if (attempt.questionIds.isEmpty) return 0;
    var correct = 0;
    for (final id in attempt.questionIds) {
      final question = questionById[id];
      if (question != null && attempt.selections[id] == question.answerIndex) {
        correct++;
      }
    }
    return ((100 * correct) / attempt.questionIds.length).round();
  }

  CourseCertificate? certificateFor(Course course) {
    if (!isAuthenticated) return null;
    final value = _preferences.getString(
      _sessionKey('certificate.${course.id}'),
    );
    return value == null
        ? null
        : CourseCertificate.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  bool isCourseComplete(Course course) =>
      certificateFor(course) != null ||
      (passedCourseAssessments.contains(course.id) &&
          course.allLessons.every(
            (lesson) => completedLessons.contains(lesson.id),
          ));

  double progressFor(Course course) {
    final lessons = course.allLessons;
    if (lessons.isEmpty) return 0;
    final completed = completedLessons;
    return lessons.where((lesson) => completed.contains(lesson.id)).length /
        lessons.length;
  }

  Lesson? continueLesson(Course course, {String? difficulty}) {
    final matching = course.allLessons.where(
      (lesson) => difficulty == null || lesson.difficulty.label == difficulty,
    );
    final incomplete = matching.where(
      (lesson) => !completedLessons.contains(lesson.id),
    );
    return incomplete.firstOrNull;
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
          attempt.courseId == course.id &&
          attempt.mode == 'exam' &&
          _scoreForAttempt(attempt) >= 70,
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
    final course = courses
        .where(
          (course) => course.allLessons.any((lesson) => lesson.id == lessonId),
        )
        .firstOrNull;
    if (course == null) throw ArgumentError('Unknown lesson.');
    await _addSessionProgress('completed_lessons', lessonId);
    if (currentUserId == accountId) {
      await _issueCertificate(course, completionTime: DateTime.now());
    }
  }

  Future<void> markCourseAssessmentPassed(String courseId) async {
    final course = courses.where((course) => course.id == courseId).firstOrNull;
    if (course == null) {
      throw ArgumentError('Unknown course.');
    }
    final eligible = attempts.any((attempt) => _passedFinal(course, attempt));
    if (!eligible) {
      throw StateError('Pass the complete final assessment first.');
    }
    final accountId = currentUserId;
    await _addSessionProgress('passed_course_assessments', courseId);
    if (currentUserId == accountId) await _issueCertificate(course);
  }

  bool _passedFinal(Course course, TestAttempt attempt) {
    final requiredIds = course.finalQuestions.map((q) => q.id).toSet();
    return attempt.courseId == course.id &&
        attempt.mode == 'exam' &&
        requiredIds.isNotEmpty &&
        attempt.questionIds.length == requiredIds.length &&
        attempt.questionIds.toSet().containsAll(requiredIds) &&
        _scoreForAttempt(attempt) >= 70;
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
    final key = _sessionKey('display_name');
    await _write(key, () => _preferences.setString(key, trimmedName));
    notifyListeners();
  }

  Future<void> saveAttempt(TestAttempt attempt) async {
    if (!isAuthenticated) return;
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
    final accountId = currentUserId;
    final key = _sessionKey(
      attempt.courseId == null ? 'test_attempts' : 'course_attempts',
    );
    await _writeAttempts(key, [
      attempt,
      ..._readJsonList(
        key,
        TestAttempt.fromJson,
      ).where((item) => item.id != attempt.id),
    ]);
    if (currentUserId == accountId &&
        course != null &&
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
