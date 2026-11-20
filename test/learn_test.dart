import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning_app/curriculum_icon.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/data/course_models.dart';
import 'package:learning_app/data/lesson_guides.dart';
import 'package:learning_app/data/course_discovery.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';

const _accounts =
    '[{"fullName":"Alexandra Katherine Montgomery","email":"alex@example.com","passwordHash":"7110985e7c834fd1bd8d47120eea202fec188a977f7b7b01c82e6ae8099200be"},{"fullName":"Second Learner","email":"second@example.com","passwordHash":"7110985e7c834fd1bd8d47120eea202fec188a977f7b7b01c82e6ae8099200be"}]';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'auth_accounts': _accounts,
      'auth_current_email': 'alex@example.com',
      'auth_session_active': true,
    });
  });

  test('lessons have guides and copying removes transcript decorations', () {
    for (final course in courses) {
      for (final lesson in course.allLessons) {
        final guide = guideForLesson(lesson);
        expect(guide.objective, isNotEmpty, reason: lesson.id);
        expect(guide.hints, hasLength(2), reason: lesson.id);
        expect(guide.solution, isNotEmpty, reason: lesson.id);
        expect(guide.mistake, isNotEmpty, reason: lesson.id);
        expect(lessonRecap(lesson), isNotEmpty, reason: lesson.id);
      }
    }
    expect(
      cleanLessonCode(
        '1 | >>> def f():\n2 | ...     return 7\n3 | >>> f()\n4 | 7',
      ),
      'def f():\n    return 7\nf()',
    );
    expect(cleanLessonCode('sqlite> SELECT\n   ...> 7;\n7'), 'SELECT\n7;');
    expect(
      cleanLessonCode('PS C:\\project> python app.py\n7'),
      'python app.py',
    );
    expect(cleanLessonCode('def f():\n    return 7'), 'def f():\n    return 7');
    final sql = LearningGoal.sql.course.allLessons.first;
    expect(guideForLesson(sql).resources.single.filename, 'learner_schema.sql');
  });

  testWidgets(
    'lesson hints unlock in order and the reading offset survives reopening',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = await AppStore.create();
      final course = LearningGoal.sql.course;
      final lesson = course.allLessons.first;
      Widget app(AppStore current, String key) => MaterialApp(
        key: ValueKey(key),
        home: LessonPage(
          lesson: lesson,
          store: current,
          courseLessons: course.allLessons,
        ),
      );
      await tester.pumpWidget(app(store, 'first'));
      await tester.pumpAndSettle();
      expect(find.text('Learning objective'), findsOneWidget);
      final previous = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Previous lesson'),
      );
      expect(previous.onPressed, isNull);
      final scroll = find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.vertical,
      );
      final controller = tester
          .widget<SingleChildScrollView>(scroll)
          .controller!;
      controller.jumpTo(210);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final reopened = await AppStore.create();
      expect(reopened.lessonReadingOffset(lesson.id), 210);
      await tester.pumpWidget(app(reopened, 'reopened'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SingleChildScrollView>(scroll).controller!.offset,
        210,
      );

      final hints = find.text('Show hints');
      await tester.ensureVisible(hints);
      await tester.tap(hints);
      await tester.pumpAndSettle();
      expect(find.text('Hint 1'), findsOneWidget);
      expect(find.text('Show solution'), findsNothing);
      await tester.tap(find.text('Next hint'));
      await tester.pumpAndSettle();
      expect(find.text('Hint 2'), findsOneWidget);
      await tester.tap(find.text('Show solution'));
      await tester.pumpAndSettle();
      expect(find.text('Solution'), findsOneWidget);
      expect(
        find.textContaining('WHERE score BETWEEN 80 AND 81'),
        findsOneWidget,
      );
    },
  );

  test('discovery uses curriculum synonyms and valid prerequisite lessons', () {
    for (final course in courses) {
      expect(course.objectives, isNotEmpty, reason: course.id);
      expect(prerequisiteLessons(course), isNotEmpty, reason: course.id);
      expect(courseStudyTime(course), isNot('Self-paced'), reason: course.id);
      expect(
        matchesCourseSearch(course, 'pandas'),
        matchesCourseSearch(course, 'data frames'),
        reason: course.id,
      );
      expect(
        matchesCourseSearch(course, 'dataframes'),
        matchesCourseSearch(course, 'data frames'),
        reason: course.id,
      );
    }
    expect(
      courses.any((course) => matchesCourseSearch(course, 'pandas')),
      isTrue,
    );
  });

  testWidgets('discovery keeps search and filters across bottom navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await AppStore.create();
    await tester.pumpWidget(MaterialApp(home: MainScreen(store: store)));
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'data frames');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Beginner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Learn'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'data frames',
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Beginner'))
          .selected,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'no related course');
    await tester.pumpAndSettle();
    expect(find.text('No courses found'), findsOneWidget);
    await tester.tap(find.text('Clear search and filters'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All'))
          .selected,
      isTrue,
    );
  });

  testWidgets(
    'sample lessons leave progress untouched and Home resumes the actual lesson',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = await AppStore.create();
      await store.setLearningGoal(LearningGoal.sql);
      final course = LearningGoal.sql.course;
      final first = course.allLessons.first;
      await tester.pumpWidget(
        MaterialApp(
          home: CourseDetailPage(course: course, store: store),
        ),
      );
      await tester.tap(find.text('Preview course'));
      await tester.pumpAndSettle();
      final preview = find.byType(BottomSheet);
      await tester.tap(
        find.descendant(of: preview, matching: find.text(first.title)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LessonPage), findsOneWidget);
      expect(find.text('Mark lesson complete'), findsNothing);
      expect(store.hasStartedCourse(course), isFalse);
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('start'),
          home: Scaffold(
            body: HomePage(store: store, onSelectTab: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Learning'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next lesson'));
      await tester.pumpAndSettle();
      final second = course.allLessons[1];
      expect(store.continueLesson(course)?.id, second.id);
      await store.toggleSavedCourse(course);
      final reopened = await AppStore.create();
      expect(reopened.learningGoal, LearningGoal.sql);
      expect(reopened.savedCourseIds, contains(course.id));
      expect(reopened.continueLesson(course)?.id, second.id);
      await tester.pumpWidget(
        MaterialApp(
          key: const ValueKey('resume'),
          home: Scaffold(
            body: HomePage(store: reopened, onSelectTab: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(second.title), findsOneWidget);
      expect(find.text(moduleForLesson(course, second)!.title), findsOneWidget);
      expect(
        find.text('About ${estimatedLessonMinutes(second)} min'),
        findsOneWidget,
      );
      await tester.tap(find.text('Resume Learning'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<LessonPage>(find.byType(LessonPage)).lesson.id,
        second.id,
      );
    },
  );

  test(
    'all eighteen requested curricula contain complete structured content',
    () {
      const titles = [
        'Python Programming',
        'SQL',
        'Machine Learning',
        'Data Science',
        'Artificial Intelligence',
        'Data Structures and Algorithms',
        'Technical Fundamentals',
        'Statistics and Mathematics for Data Science',
        'Deep Learning',
        'Generative AI',
        'Data Analytics',
        'Power BI',
        'Advanced Excel',
        'Databricks',
        'PySpark',
        'Azure DevOps',
        'Cloud Computing',
        'Big Data Technologies',
      ];
      final lessonIds = <String>{};
      final questionIds = <String>{};
      for (final title in titles) {
        final course = courses.singleWhere((course) => course.title == title);
        expect(course.modules.length, greaterThanOrEqualTo(8), reason: title);
        expect(course.objectives.length, greaterThanOrEqualTo(2));
        expect(course.description, isNotEmpty);
        expect(course.prerequisites, isNotEmpty);
        expect(course.capstoneProject, isNotEmpty);
        expect(
          course.allLessons.map((lesson) => lesson.difficulty).toSet(),
          containsAll(CourseDifficulty.values),
          reason: title,
        );
        for (final module in course.modules) {
          expect(
            module.lessons.length,
            greaterThanOrEqualTo(2),
            reason: module.title,
          );
          expect(module.summary, isNotEmpty);
          expect(module.assignment, isNotEmpty);
          expect(module.questions, isNotEmpty);
          expect(module.assessmentQuestions, isNotEmpty);
          for (final lesson in module.lessons) {
            expect(lessonIds.add(lesson.id), isTrue, reason: lesson.id);
            expect(lesson.summary.length, greaterThan(60), reason: lesson.id);
            expect(lesson.example, isNotEmpty);
            expect(lesson.topics, isNotEmpty);
            expect(lesson.expectedOutput, isNotEmpty, reason: lesson.id);
            expect(lesson.exercise, isNotEmpty, reason: lesson.id);
            expect(lesson.industryUse, isNotEmpty, reason: lesson.id);
          }
          for (final question in [
            ...module.questions,
            ...module.assessmentQuestions,
          ]) {
            expect(questionIds.add(question.id), isTrue, reason: question.id);
            expect(question.options.toSet().length, question.options.length);
            expect(
              question.answerIndex,
              inInclusiveRange(0, question.options.length - 1),
            );
            expect(question.explanation, isNotEmpty);
          }
        }
      }
      expect(courses.any((course) => course.title == 'Git and GitHub'), isTrue);
      expect(courses.first.id, 'python');
      expect(
        courses
            .expand((course) => course.allLessons)
            .map((lesson) => lesson.id),
        containsAll([
          'sql-select',
          'ml-splits',
          'ds-cleaning',
          'ai-search',
          'ds-hash',
          'tf-http',
          'python-introduction',
          'dbx-intro',
        ]),
      );
    },
  );

  test(
    'progress, final gates and immutable certificates persist per account',
    () async {
      final store = await AppStore.create();
      final course = courses.singleWhere(
        (course) => course.title == 'Generative AI',
      );
      expect(store.progressFor(course), 0);
      expect(store.continueLesson(course)?.id, course.allLessons.first.id);
      await expectLater(store.saveAttempt(_attempt(course)), throwsStateError);
      await store.markLessonComplete(course.allLessons.first.id);
      expect(store.progressFor(course), 1 / course.allLessons.length);
      expect(store.continueLesson(course)?.id, course.allLessons[1].id);
      final advanced = store.continueLesson(course, difficulty: 'Advanced');
      expect(advanced?.difficulty, CourseDifficulty.advanced);
      for (final lesson in course.allLessons.skip(1)) {
        await store.markLessonComplete(lesson.id);
      }
      expect(store.continueLesson(course), isNull);
      await expectLater(
        store.markCourseAssessmentPassed(course.id),
        throwsStateError,
      );
      await store.saveAttempt(_attempt(course, correct: false));
      expect(store.certificateFor(course), isNull);
      await store.saveAttempt(_attempt(course, mode: 'practice'));
      expect(store.certificateFor(course), isNull);
      await store.saveAttempt(_attempt(course));
      final certificate = store.certificateFor(course)!;
      expect(certificate.studentName, 'Alexandra Katherine Montgomery');
      expect(certificate.completedAt, DateTime(2026, 11, 17));
      expect(certificate.id, startsWith('SV-'));
      expect(certificate.completionDateKnown, isTrue);
      await store.updateDisplayName('Changed nickname');
      await store.saveAttempt(_attempt(course, id: 'retake'));
      final reloaded = await AppStore.create();
      expect(reloaded.progressFor(course), 1);
      expect(reloaded.certificateFor(course)!.toJson(), certificate.toJson());
      await reloaded.logout();
      expect(reloaded.certificateFor(course), isNull);
      expect(reloaded.completedLessons, isEmpty);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('auth_current_email', 'second@example.com');
      await preferences.setBool('auth_session_active', true);
      final second = await AppStore.create();
      expect(second.progressFor(course), 0);
      expect(second.certificateFor(course), isNull);
      for (final lesson in course.allLessons) {
        await second.markLessonComplete(lesson.id);
      }
      await second.saveAttempt(_attempt(course));
      expect(second.certificateFor(course)!.id, isNot(certificate.id));
      expect(second.certificateFor(course)!.studentName, 'Second Learner');
      await preferences.setString('auth_current_email', 'alex@example.com');
      final firstAgain = await AppStore.create();
      expect(firstAgain.certificateFor(course)!.toJson(), certificate.toJson());
      final expanded = courses.singleWhere((course) => course.title == 'SQL');
      await preferences.setStringList(
        'account.${firstAgain.currentUserId}.completed_lessons',
        [
          ...firstAgain.completedLessons,
          ...expanded.allLessons
              .take(expanded.allLessons.length - 1)
              .map((lesson) => lesson.id),
        ],
      );
      await preferences.setStringList(
        'account.${firstAgain.currentUserId}.passed_course_assessments',
        [course.id, expanded.id],
      );
      final historicPass = TestAttempt(
        id: 'historic-pass',
        subject: expanded.quizSubject!,
        completedAt: DateTime(2000),
        selections: {
          for (final question in expanded.finalQuestions)
            question.id: question.answerIndex,
        },
        questionIds: expanded.finalQuestions
            .map((question) => question.id)
            .toList(),
        durationSeconds: 60,
        courseId: expanded.id,
      );
      await preferences.setString(
        'account.${firstAgain.currentUserId}.course_attempts',
        jsonEncode([historicPass.toJson()]),
      );
      final completionStart = DateTime.now();
      await firstAgain.markLessonComplete(expanded.allLessons.last.id);
      final expandedCertificate = firstAgain.certificateFor(expanded)!;
      expect(
        expandedCertificate.completedAt.isBefore(completionStart),
        isFalse,
      );
      expect(expandedCertificate.completionDateKnown, isTrue);
    },
  );

  testWidgets(
    'level selection reaches matching lessons and Continue Learning',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = await AppStore.create();
      final course = courses.singleWhere((course) => course.title == 'SQL');
      await tester.pumpWidget(
        MaterialApp(
          home: CourseDetailPage(
            course: course,
            store: store,
            initialDifficulty: 'Advanced',
          ),
        ),
      );
      await tester.tap(find.text('Continue Learning'));
      await tester.pumpAndSettle();
      final page = tester.widget<LessonPage>(find.byType(LessonPage));
      expect(page.lesson.difficulty, CourseDifficulty.advanced);
      expect(
        page.courseLessons.every(
          (lesson) => lesson.difficulty == CourseDifficulty.advanced,
        ),
        isTrue,
      );
      await tester.scrollUntilVisible(
        find.text('Mark lesson complete'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Mark lesson complete'));
      await tester.pumpAndSettle();
      expect(store.completedLessons, contains(page.lesson.id));
    },
  );

  test('all catalog levels resolve to packaged curriculum artwork', () async {
    final assets = <String>{};
    final courseAssets = <String>{};

    String check(CurriculumIcon icon) {
      final asset = icon.resolvedAsset;
      expect(asset, isNotNull, reason: icon.label);
      assets.add(asset!);
      return asset;
    }

    for (final course in courses) {
      expect(
        courseAssets.add(check(CurriculumIcon.course(course))),
        isTrue,
        reason: course.title,
      );
      for (final tool in course.tools) {
        check(CurriculumIcon(label: tool, contextLabels: [course.title]));
      }
      for (final module in course.learningModules) {
        check(CurriculumIcon.module(course, module));
        for (final lesson in module.lessons) {
          check(CurriculumIcon.lesson(course, module, lesson));
          for (final topic in lesson.topics) {
            check(CurriculumIcon.topic(lesson, topic));
          }
        }
      }
    }

    for (final category in [
      'All',
      'Beginner',
      'Intermediate',
      'Advanced',
      'Completed',
      'In progress',
      'Not started',
    ]) {
      check(CurriculumIcon(label: category));
    }
    check(const CurriculumIcon(label: 'Advanced TypeScript Patterns'));
    expect(
      CurriculumIcon.assetFor('Advanced TypeScript Patterns'),
      endsWith('brand-typescript.png'),
    );
    expect(
      CurriculumIcon.assetFor('HTTP client development'),
      endsWith('globe.png'),
    );
    expect(
      CurriculumIcon.assetFor(
        'Unfamiliar subject',
        contextLabels: ['Database systems'],
      ),
      endsWith('database.png'),
    );
    expect(CurriculumIcon.assetFor('Unfamiliar subject'), isNull);
    for (final asset in assets) {
      expect(
        (await rootBundle.load(asset)).lengthInBytes,
        greaterThan(0),
        reason: asset,
      );
    }
  });

  testWidgets('each course shows its own artwork in the catalog', (
    tester,
  ) async {
    final store = await AppStore.create();
    await tester.binding.setSurfaceSize(const Size(1100, 5000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LearnPage(store: store)),
      ),
    );
    await tester.pumpAndSettle();

    for (final course in courses) {
      final tile = find.widgetWithText(ListTile, course.title);
      expect(tile, findsOneWidget);
      final avatar = find.descendant(
        of: tile,
        matching: find.byType(CircleAvatar),
      );
      final image = tester.widget<Image>(
        find.descendant(of: avatar, matching: find.byType(Image)),
      );
      expect(
        (image.image as AssetImage).assetName,
        CurriculumIcon.course(course).resolvedAsset,
      );
      expect(image.fit, BoxFit.contain);
      expect(image.width, 24);
      expect(image.height, 24);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home adapts to width and opens an in-progress course', (
    tester,
  ) async {
    final store = await AppStore.create();
    final course = courses.first;
    await store.markLessonComplete(course.allLessons.first.id);
    var selected = 0;
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [320.0, 1200.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomePage(
              store: store,
              onSelectTab: (index) => selected = index,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(SkillVerseBrand)).width, 60);
      expect(find.text('Continue learning'), findsOneWidget);
      expect(find.text(course.title), findsOneWidget);
      expect(
        find.textContaining('1 of ${course.allLessons.length} lessons'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.text('Browse courses'));
    expect(selected, 1);
    await tester.tap(find.byTooltip('Open profile'));
    expect(selected, 4);
    await tester.tap(find.text(course.title));
    await tester.pumpAndSettle();
    expect(find.byType(CourseDetailPage), findsOneWidget);
  });

  test('every module has two unique four-option question banks', () {
    final ids = <String>{};
    final prompts = <String>{};
    for (final course in courses) {
      for (final module in course.learningModules) {
        final context = '${course.title} / ${module.title}';
        for (final bank in [module.questions, module.moduleQuizQuestions]) {
          expect(bank.length, greaterThanOrEqualTo(20), reason: context);
          expect(
            bank.map((question) => question.difficulty).toSet(),
            containsAll(CourseDifficulty.values.map((value) => value.label)),
            reason: context,
          );
          for (final question in bank) {
            final prompt = question.prompt.trim().toLowerCase().replaceAll(
              RegExp(r'\s+'),
              ' ',
            );
            expect(ids.add(question.id), isTrue, reason: question.id);
            expect(prompts.add(prompt), isTrue, reason: question.id);
            expect(question.options, hasLength(4), reason: question.id);
            expect(
              question.options
                  .map((option) => option.trim().toLowerCase())
                  .toSet(),
              hasLength(4),
              reason: question.id,
            );
            expect(
              question.options.every((option) => option.trim().isNotEmpty),
              isTrue,
            );
            expect(question.answerIndex, inInclusiveRange(0, 3));
            expect(question.explanation.trim(), isNotEmpty);
            expect(question.topic.trim(), isNotEmpty);
          }
        }
      }
    }
  });

  testWidgets(
    'practice checks answers and retains feedback during navigation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final module = courses
          .singleWhere((course) => course.title == 'SQL')
          .modules
          .first;
      final question = module.questions.first;
      await tester.pumpWidget(
        MaterialApp(home: ModuleQuizPage(module: module, practice: true)),
      );

      expect(find.text(question.prompt), findsOneWidget);
      final option = find.widgetWithText(
        ListTile,
        question.options[question.answerIndex],
      );
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Check answer'), 150);
      await tester.tap(find.text('Check answer'));
      await tester.pump();
      expect(find.text('Correct'), findsOneWidget);
      expect(find.text(question.explanation), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text(module.questions[1].prompt), findsOneWidget);
      await tester.tap(find.text('Previous'));
      await tester.pump();
      await tester.scrollUntilVisible(find.text(question.explanation), 150);
      expect(find.text(question.explanation), findsOneWidget);
      for (var i = 0; i < module.questions.length - 1; i++) {
        final next = find.text('Next').hitTestable();
        expect(next, findsOneWidget);
        await tester.tap(next);
        await tester.pump();
      }
      expect(find.textContaining('Question 20 of 20'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final results = find.widgetWithText(FilledButton, 'See results');
      expect(tester.widget<FilledButton>(results).onPressed, isNull);
    },
  );

  testWidgets('module quiz scores twenty answers, supports review and resets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await AppStore.create();
    final module = courses
        .singleWhere((course) => course.title == 'SQL')
        .modules
        .first;
    final questions = module.moduleQuizQuestions;
    await tester.pumpWidget(MaterialApp(home: ModuleQuizPage(module: module)));
    expect(find.textContaining('Question 1 of 20'), findsOneWidget);
    final submit = find.widgetWithText(FilledButton, 'Submit quiz');
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    for (var i = 0; i < questions.length; i++) {
      final question = questions[i];
      expect(find.text(question.prompt), findsOneWidget);
      final answer = i == 0
          ? (question.answerIndex + 1) % 4
          : question.answerIndex;
      final option = find.widgetWithText(ListTile, question.options[answer]);
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      expect(find.text(question.explanation), findsNothing);
      if (i == 1) {
        await tester.tap(find.text('Previous'));
        await tester.pump();
        final first = questions.first;
        expect(
          tester
              .widget<ListTile>(
                find.widgetWithText(
                  ListTile,
                  first.options[(first.answerIndex + 1) % 4],
                ),
              )
              .selected,
          isTrue,
        );
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
      if (i + 1 < questions.length) {
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
    }
    expect(find.textContaining('Question 20 of 20'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Next'))
          .onPressed,
      isNull,
    );
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Score 19 / 20 · 95%'), findsOneWidget);
    expect(find.text('Incorrect'), findsOneWidget);
    expect(find.text(questions.first.explanation), findsOneWidget);
    expect(
      find.text(
        'Correct answer · ${questions.first.options[questions.first.answerIndex]}',
      ),
      findsOneWidget,
    );
    expect(store.passedCourseAssessments, isEmpty);

    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(find.text('Results'), findsNothing);
    expect(find.text(questions.first.prompt), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
  });

  testWidgets('syllabus shortcuts and level filters keep modules reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = await AppStore.create();
    final course = courses.singleWhere((course) => course.title == 'SQL');
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailPage(course: course, store: store),
      ),
    );
    await tester.tap(find.text('8 modules'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Modules and lessons')).dy,
      lessThan(500),
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Advanced'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Advanced'));
    await tester.pumpAndSettle();
    expect(find.text(course.modules.first.title), findsNothing);
    expect(find.text(course.modules.last.title), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    final python = courses.first;
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailPage(course: python, store: store),
      ),
    );
    await tester.ensureVisible(find.text(python.duration));
    await tester.tap(find.text(python.duration));
    await tester.pumpAndSettle();
    final remaining = find.textContaining(
      'Approximate remaining time is 30 hours',
    );
    expect(remaining, findsOneWidget);
    Navigator.of(tester.element(remaining)).pop();
    await tester.pumpAndSettle();
    final topics = find.text('${python.topicCount} topics');
    await tester.ensureVisible(topics);
    await tester.tap(topics);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final topicTile = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.widgetWithText(ListTile, python.allTopics.first),
    );
    expect(topicTile, findsOneWidget);
    expect(
      find.descendant(of: topicTile, matching: find.byType(CurriculumIcon)),
      findsOneWidget,
    );
  });

  testWidgets('the complete final exam unlocks the Profile certificate list', (
    tester,
  ) async {
    final store = await AppStore.create();
    final course = courses.singleWhere(
      (course) => course.title == 'Generative AI',
    );
    for (final lesson in course.allLessons) {
      await store.markLessonComplete(lesson.id);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: CourseDetailPage(course: course, store: store),
      ),
    );
    await tester.ensureVisible(find.text('Start final assessment'));
    await tester.tap(find.text('Start final assessment'));
    await tester.pumpAndSettle();
    for (var index = 0; index < course.finalQuestions.length; index++) {
      final question = course.finalQuestions[index];
      final answer = find.text(question.options[question.answerIndex]);
      await tester.ensureVisible(answer);
      await tester.tap(answer);
      await tester.pump();
      if (index < course.finalQuestions.length - 1) {
        await tester.ensureVisible(find.text('Next'));
        await tester.tap(find.text('Next'));
        await tester.pump();
      }
    }
    await tester.ensureVisible(find.text('Submit exam'));
    await tester.tap(find.text('Submit exam'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit').last);
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsWidgets);
    expect(store.certificateFor(course), isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(home: CertificatesPage(store: store)));
    await tester.pumpAndSettle();
    expect(find.text(course.title), findsOneWidget);
    expect(
      find.textContaining('Alexandra Katherine Montgomery'),
      findsOneWidget,
    );
  });

  test('certificate PDF contains a valid export', () async {
    final certificate = CourseCertificate(
      id: 'SV-0123456789ABCDEF01234567',
      userId: 'test-user',
      studentName: 'Alexandra Katherine Montgomery',
      courseId: 'statistics',
      courseName: 'Statistics and Mathematics for Data Science',
      completedAt: DateTime(2026, 11, 17),
    );
    final bytes = await buildCertificatePdf(certificate);
    expect(utf8.decode(bytes.take(4).toList()), '%PDF');
    expect(bytes.length, greaterThan(1000));
    final directory = Directory('build/learn_qa')..createSync(recursive: true);
    File('${directory.path}/certificate-qa.pdf').writeAsBytesSync(bytes);
    final unicode = CourseCertificate(
      id: 'SV-UNICODE-TEST',
      userId: 'unicode-user',
      studentName: 'आशा शर्मा',
      courseId: 'statistics',
      courseName: certificate.courseName,
      completedAt: certificate.completedAt,
    );
    File('${directory.path}/certificate-unicode-qa.pdf')
        .writeAsBytesSync(await buildCertificatePdf(unicode));
  });
}

TestAttempt _attempt(
  Course course, {
  bool correct = true,
  String mode = 'exam',
  String id = 'final',
}) => TestAttempt(
  id: '$id-$mode-$correct',
  subject: course.quizSubject!,
  completedAt: DateTime(2026, 11, 17),
  selections: {
    for (final q in course.finalQuestions)
      q.id: correct ? q.answerIndex : (q.answerIndex + 1) % q.options.length,
  },
  questionIds: course.finalQuestions.map((q) => q.id).toList(),
  durationSeconds: 60,
  mode: mode,
  courseId: course.id,
);
