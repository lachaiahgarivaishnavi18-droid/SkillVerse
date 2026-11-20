import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_app/main.dart';
import 'package:learning_app/services/app_store.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official logo asset preserves the supplied image bytes', () async {
    final bytes = await rootBundle.load('assets/brand/skillverse_logo.png');
    expect(
      sha256.convert(bytes.buffer.asUint8List()).toString(),
      'd68d99dc5507db03b9a297b993e4da892cb32d7744cb05d0e1fd7b6b50c12054',
    );
  });

  testWidgets(
    'branding is centered and proportionate at Android viewport sizes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = await AppStore.create();
      for (final viewport in [
        const Size(320, 568),
        const Size(393, 851),
        const Size(800, 1280),
        const Size(740, 320),
      ]) {
        const density = 2.0;
        tester.view.devicePixelRatio = density;
        tester.view.physicalSize = viewport * density;
        for (final (screen, minimum, maximum) in [
          (const SplashScreen(), 240.0, 360.0),
          (
            AuthLandingPage(store: store, initialShowSignIn: true),
            244.0,
            264.0,
          ),
          (
            AuthLandingPage(store: store, initialShowSignIn: false),
            244.0,
            264.0,
          ),
          (WelcomePage(store: store), 240.0, 240.0),
          (
            Scaffold(
              body: HomePage(store: store, onSelectTab: (_) {}),
            ),
            60.0,
            60.0,
          ),
        ]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(MaterialApp(home: screen));
          await tester.pump(const Duration(milliseconds: 100));
          final logo = find.descendant(
            of: find.byType(SkillVerseBrand),
            matching: find.byType(Image),
          );
          expect(
            logo,
            findsOneWidget,
            reason: '$viewport / ${screen.runtimeType}',
          );
          final image = tester.widget<Image>(logo);
          expect(
            (image.image as AssetImage).assetName,
            'assets/brand/skillverse_logo.png',
          );
          expect(image.fit, BoxFit.contain);
          expect(image.color, isNull);
          final size = tester.getSize(logo);
          expect(size.width, size.height);
          expect(size.width, inInclusiveRange(minimum, maximum));
          if (screen is! Scaffold) {
            expect(
              tester.getCenter(logo).dx,
              closeTo(viewport.width / 2, 0.01),
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets('beta display name, navigation, and About use release metadata', (
    tester,
  ) async {
    const metadata = MethodChannel('skillverse/build');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(metadata, (call) async {
      expect(call.method, 'info');
      return {'version': '1.0.0', 'build': '2'};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(metadata, null));
    await tester.binding.setSurfaceSize(const Size(800, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'auth_accounts': '[{"fullName":"Beta test fixture","email":"beta@example.invalid","passwordHash":"fixture"}]',
      'auth_current_email': 'beta@example.invalid',
      'auth_session_active': true,
    });
    final store = await AppStore.create();
    await tester.pumpWidget(LearningApp(store: store));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Skillverse',
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    expect(find.text('Skillverse'), findsOneWidget);
    final navigation = find.byType(NavigationBar);
    for (final title in ['Home', 'Learn', 'Interview', 'Projects', 'Profile']) {
      expect(
        find.descendant(of: navigation, matching: find.text(title)),
        findsOneWidget,
      );
    }
    await tester.tap(
      find.descendant(of: navigation, matching: find.text('Profile')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Settings'), 250);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('About Skillverse'));
    await tester.tap(find.text('About Skillverse'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('1.0.0 (build 2)'), findsOneWidget);
    expect(
      find.textContaining('This build uses local accounts.'),
      findsOneWidget,
    );
  });
}
