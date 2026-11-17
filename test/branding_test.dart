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

  testWidgets('official logo fits splash, auth, and home on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final store = await AppStore.create();
    for (final screen in <Widget>[
      const SplashScreen(),
      WelcomePage(store: store),
      AuthLandingPage(store: store, initialShowSignIn: true),
      AuthLandingPage(store: store, initialShowSignIn: false),
      Scaffold(
        body: HomePage(store: store, onSelectTab: (_) {}),
      ),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pump(const Duration(milliseconds: 100));
      final logo = find.descendant(
        of: find.byType(SkillVerseBrand),
        matching: find.byType(Image),
      );
      expect(logo, findsOneWidget);
      final image = tester.widget<Image>(logo);
      expect(
        (image.image as AssetImage).assetName,
        'assets/brand/skillverse_logo.png',
      );
      expect(image.fit, BoxFit.contain);
      expect(image.color, isNull);
      final size = tester.getSize(logo);
      expect(size.width, size.height);
      expect(tester.takeException(), isNull);
    }
  });
}
