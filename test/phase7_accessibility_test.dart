import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/data/app_content.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _largeViewport(Widget screen) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(2), disableAnimations: true),
    child: child!,
  ),
  home: screen,
);

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'auth_accounts': '[{"fullName":"Accessibility Learner","email":"access@example.com","passwordHash":"fixture"}]',
      'auth_current_email': 'access@example.com',
      'auth_session_active': true,
    }),
  );

  testWidgets('large text remains usable on phone, tablet and landscape', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final store = await AppStore.create();
    final course = courses.first;
    for (final size in [
      const Size(320, 568),
      const Size(800, 1280),
      const Size(700, 320),
    ]) {
      tester.view.physicalSize = size;
      for (final screen in [
        AuthLandingPage(store: store, initialShowSignIn: false),
        MainScreen(store: store),
        Scaffold(body: LearnPage(store: store)),
        CourseDetailPage(course: course, store: store),
        LeaderboardPage(store: store),
        ProjectsPage(store: store),
        Scaffold(body: ProfilePage(store: store)),
        LessonPage(
          lesson: course.allLessons.first,
          store: store,
          courseLessons: course.allLessons,
        ),
        ModuleQuizPage(module: course.modules.first, store: store),
        InterviewQuestionsPage(store: store, savedOnly: true),
        MockTestPage(
          subject: course.title,
          questions: course.finalQuestions.take(2).toList(),
          store: store,
          mode: TestMode.practice,
        ),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(_largeViewport(screen));
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$size / ${screen.runtimeType}',
        );
      }
    }
  });

  testWidgets('sign-up controls have labels, tap targets and keyboard order', (
    tester,
  ) async {
    final store = await AppStore.create();
    await tester.pumpWidget(
      MaterialApp(
        home: AuthLandingPage(store: store, initialShowSignIn: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Skillverse logo'), findsOneWidget);
    final fields = find.byType(EditableText);
    await tester.ensureVisible(fields.first);
    await tester.tap(fields.first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester.widget<EditableText>(fields.at(1)).focusNode.hasFocus,
      isTrue,
    );
    final icon = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.semanticLabel == 'Show password',
    );
    final toggle = find.ancestor(of: icon, matching: find.byType(IconButton));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(toggle).label, 'Show password');
    final size = tester.getSize(toggle);
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(toggle);
    await tester.pump();
    expect(
      tester
          .getSemantics(
            find.ancestor(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is Icon && widget.semanticLabel == 'Hide password',
              ),
              matching: find.byType(IconButton),
            ),
          )
          .label,
      'Hide password',
    );
  });

  testWidgets('Android-style Back keeps or discards project edits explicitly', (
    tester,
  ) async {
    final store = await AppStore.create();
    await tester.pumpWidget(_largeViewport(ProjectsPage(store: store)));
    await tester.tap(find.byTooltip('Add project').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Private draft');
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave this screen?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Private draft'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Private draft'), findsNothing);
    expect(store.projects, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back returns a primary destination to Home', (tester) async {
    final store = await AppStore.create();
    await tester.pumpWidget(MaterialApp(home: MainScreen(store: store)));
    await tester.tap(find.text('Learn').last);
    await tester.pumpAndSettle();
    expect(find.text('Learning courses'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('exam question grid exposes status alongside a visible icon', (
    tester,
  ) async {
    final store = await AppStore.create();
    final course = courses.first;
    await tester.pumpWidget(
      MaterialApp(
        home: MockTestPage(
          subject: 'SQL',
          questions: course.finalQuestions.take(2).toList(),
          store: store,
          mode: TestMode.exam,
        ),
      ),
    );
    await tester.pump();
    final question = find.bySemanticsLabel(
      RegExp('Question 1, current, unanswered'),
    );
    await tester.ensureVisible(question);
    expect(question, findsOneWidget);
    expect(find.byIcon(Icons.arrow_right), findsOneWidget);
    final button = find.ancestor(
      of: question,
      matching: find.byType(OutlinedButton),
    );
    expect(tester.getSize(button).shortestSide, greaterThanOrEqualTo(48));
  });

  testWidgets('large lesson code can scroll sideways and remains selectable', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    final store = await AppStore.create();
    final lesson = courses
        .firstWhere((course) => course.id == 'sql')
        .allLessons
        .first;
    await tester.pumpWidget(
      _largeViewport(LessonPage(lesson: lesson, store: store)),
    );
    await tester.pumpAndSettle();
    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(horizontal, findsOneWidget);
    await tester.ensureVisible(horizontal);
    await tester.pumpAndSettle();
    final scroll = tester.widget<SingleChildScrollView>(horizontal).controller!;
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    final top = tester.getTopLeft(horizontal);
    await tester.dragFrom(top + const Offset(220, 6), const Offset(-96, 0));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(
      find.descendant(of: horizontal, matching: find.byType(SelectableText)),
      findsOneWidget,
    );
  });

  testWidgets(
    'shared theme provides readable text contrast and reduced-motion startup',
    (tester) async {
      final store = await AppStore.create();
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            disableAnimations: true,
            highContrast: true,
          );
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(LearningApp(store: store));
      await tester.pump();
      expect(find.byType(SplashScreen), findsNothing);
      final context = tester.element(find.byType(HomePage));
      final theme = Theme.of(context);
      double ratio(Color first, Color second) {
        final a = first.computeLuminance();
        final b = second.computeLuminance();
        return (math.max(a, b) + .05) / (math.min(a, b) + .05);
      }

      expect(
        ratio(theme.colorScheme.onSurface, theme.scaffoldBackgroundColor),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        ratio(theme.colorScheme.onPrimary, theme.colorScheme.primary),
        greaterThanOrEqualTo(4.5),
      );
      await tester.pump(const Duration(milliseconds: 700));
    },
  );
}
